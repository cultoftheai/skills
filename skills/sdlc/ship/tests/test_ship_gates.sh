# Tests for ship_gates.sh. gh is faked; git runs on a real repository.

COLLAB_API='api repos/{owner}/{repo}/collaborators?affiliation=all&permission=push&per_page=100'

DEFS='
  def review($s; $l; $t): {state: $s, author: {__typename: $t, login: $l}};
  def review($s; $l): review($s; $l; "User");
  def thread($resolved; $l): {isResolved: $resolved, comments: {nodes: [{url: "https://example.test/\($l)", author: {login: $l}}]}};
  def comment($b; $l; $t; $m): {body: $b, isMinimized: $m, author: {__typename: $t, login: $l}};
  def comment($b; $l; $t): comment($b; $l; $t; false);
  def comment($b; $l): comment($b; $l; "User"; false);
  def comment($b): comment($b; "dev"; "User"; false);
  def file($p): {path: $p};
'

# Make the fake gh answer the collaborators endpoint with exit code (default 0) and output.
fake_collaborators() {
    if [ $# -eq 1 ]; then
        fake_gh "$COLLAB_API" 0 "$1"
    else
        fake_gh "$COLLAB_API" "$1" "$2"
    fi
}

# Create a repository with settings, green checks, two writers, and an initial commit.
setup() {
    git init -q repo
    cd repo || exit 1
    git config user.name test
    git config user.email test@example.test
    mkdir .sdlc
    default_settings='{}'
    printf '%s\n' "${1:-$default_settings}" > .sdlc/settings.json
    fake_gh "pr checks" 0 '[{"name": "ci", "bucket": "pass"}]'
    fake_collaborators '[{"login":"dev","type":"User","permissions":{"push":true}},{"login":"lead","type":"User","permissions":{"push":true}}]'
}

# Commit a new file at each path. Optional first arg "--trailer <key: val>" adds a git trailer.
commit_files() {
    trailer=''
    if [ "${1:-}" = --trailer ]; then
        trailer=$2
        shift 2
    fi
    for path in "$@"; do
        mkdir -p "$(dirname "$path")"
        echo "$path" > "$path"
        git add "$path"
    done
    if [ -n "$trailer" ]; then
        git commit -qm "Add $*" --trailer "$trailer"
    else
        git commit -qm "Add $*"
    fi
}

# Build an Official QA PR comment body. Usage: qa_comment <pass|fail> <sha> [prefix]
qa_comment() {
    printf '%s [qa] %s\nCommit: %s\nDate: 2026-11-26T10:00:00Z\n\n### Checks\n- cmd -> ok' \
        "${3:-:robot:}" "$1" "$2"
}

# Make the fake gh answer the GraphQL query with a PR by "dev" at HEAD with an Official QA pass.
fake_pr() {
    fake_gh "api graphql" 0 "$(jq -cn --arg head "$(git rev-parse HEAD)" "$DEFS (${1:-null}) as \$extra | "'
        ({
          head: $head,
          author: {login: "dev"},
          reviews: [review("APPROVED"; "lead")],
          threads: [],
          decision: "APPROVED",
          files: [file("src/app.txt")],
          comments: [comment(":robot: [qa] pass\nCommit: \($head)\nDate: 2026-11-26T10:00:00Z\n\n### Checks\n- cmd -> ok")]
        } + $extra) as $o
        | {data: {repository: {pullRequest: {
            headRefOid: $o.head, reviewDecision: $o.decision, author: $o.author,
            files: {nodes: $o.files},
            comments: {nodes: $o.comments},
            latestOpinionatedReviews: {nodes: $o.reviews},
            reviewThreads: {nodes: $o.threads}}}}}')"
}

# Set up a repo with one committed file and a passing PR at HEAD. Usage: ready_pr [jq object for fake_pr]
ready_pr() {
    setup
    commit_files src/app.txt
    fake_pr "${1:-null}"
}

# Set up a solo-maintainer repo with one committed file and an unreviewed PR by "dev" (decision null).
solo_pr() {
    setup
    commit_files src/app.txt
    fake_collaborators '[{"login":"dev","type":"User","permissions":{"push":true}}]'
    extra=${1:-'{}'}
    fake_pr "({reviews: [], decision: null} + ($extra))"
}

# Print the line of the named gate from a run for PR 12.
gate_line() {
    "$SH" "$GATES" 12 | grep "^$1: "
}

test_person_approval_passes() {
    ready_pr
    assert_eq "$(gate_line approval)" "approval: pass - approved by lead"
}

test_bot_approval_does_not_count() {
    ready_pr '{reviews: [review("APPROVED"; "ci-app"; "Bot")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_author_approval_does_not_count() {
    ready_pr '{reviews: [review("APPROVED"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_no_review_fails() {
    ready_pr '{reviews: []}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_changes_requested_fails() {
    ready_pr '{reviews: [review("APPROVED"; "lead"), review("CHANGES_REQUESTED"; "qa")]}'
    assert_eq "$(gate_line approval)" "approval: fail - changes requested by qa"
}

test_review_required_fails() {
    ready_pr '{decision: "REVIEW_REQUIRED"}'
    assert_eq "$(gate_line approval)" "approval: fail - GitHub review decision is REVIEW_REQUIRED"
}

test_no_branch_protection_passes() {
    ready_pr '{decision: null}'
    assert_eq "$(gate_line approval)" "approval: pass - approved by lead"
}

test_green_checks_pass() {
    ready_pr
    assert_eq "$(gate_line checks)" "checks: pass - 1 green"
    assert_contains "$(cat "$TEST_TMP/gh.log")" "pr checks 12 --json name,bucket"
}

test_failed_check_fails() {
    ready_pr
    fake_gh "pr checks" 1 '[{"name": "ci", "bucket": "pass"}, {"name": "lint", "bucket": "fail"}]'
    assert_eq "$(gate_line checks)" "checks: fail - failed: lint"
}

test_pending_check_fails() {
    ready_pr
    fake_gh "pr checks" 8 '[{"name": "ci", "bucket": "pending"}]'
    assert_eq "$(gate_line checks)" "checks: fail - pending: ci"
}

test_skipped_check_passes() {
    ready_pr
    fake_gh "pr checks" 0 '[{"name": "ci", "bucket": "pass"}, {"name": "deploy", "bucket": "skipping"}]'
    assert_eq "$(gate_line checks)" "checks: pass - 2 green"
}

test_no_checks_passes() {
    ready_pr
    fake_gh "pr checks" 1 "no checks reported on the 'x' branch"
    assert_eq "$(gate_line checks)" "checks: pass - no checks reported"
}

test_unreadable_checks_fail() {
    ready_pr
    fake_gh "pr checks" 1 "HTTP 502"
    assert_eq "$(gate_line checks)" "checks: fail - cannot read checks: HTTP 502"
}

test_thread_answered_by_author_passes() {
    ready_pr '{threads: [thread(false; "dev")]}'
    assert_eq "$(gate_line threads)" "threads: pass - no unanswered thread"
}

test_resolved_thread_passes() {
    ready_pr '{threads: [thread(true; "lead")]}'
    assert_eq "$(gate_line threads)" "threads: pass - no unanswered thread"
}

test_reviewer_last_fails() {
    ready_pr '{threads: [thread(false; "lead"), thread(false; "dev")]}'
    assert_eq "$(gate_line threads)" "threads: fail - 1 unanswered: https://example.test/lead"
}

test_official_qa_pass_for_head_passes() {
    ready_pr
    assert_eq "$(gate_line qa)" "qa: pass - Official QA passed for $(git rev-parse HEAD)"
}

test_custom_review_prefix_is_respected() {
    setup '{"review": {"prefix": "[bot]"}}'
    commit_files src/app.txt
    head=$(git rev-parse HEAD)
    fake_pr "$(jq -cn --arg c "$(qa_comment pass "$head" '[bot]')" "$DEFS"' {comments: [comment($c)]}')"
    assert_eq "$(gate_line qa)" "qa: pass - Official QA passed for $head"
    fake_pr "$(jq -cn --arg c "$(qa_comment pass "$head" ':robot:')" "$DEFS"' {comments: [comment($c)]}')"
    assert_eq "$(gate_line qa)" "qa: fail - no Official QA comment found; run prove 12 first"
}

test_local_head_must_be_pr_head() {
    ready_pr '{head: "bbbb"}'
    assert_eq "$(gate_line qa)" "qa: fail - local HEAD $(git rev-parse HEAD) is not the PR head bbbb"
}

test_missing_qa_comment_fails() {
    ready_pr '{comments: [comment("Looks good!")]}'
    assert_eq "$(gate_line qa)" "qa: fail - no Official QA comment found; run prove 12 first"
}

test_newest_qa_comment_fail_fails() {
    setup
    commit_files src/app.txt
    head=$(git rev-parse HEAD)
    fake_pr "$(jq -cn --arg c1 "$(qa_comment pass "$head")" --arg c2 "$(qa_comment fail "$head")" \
        "$DEFS"' {comments: [comment($c1), comment($c2)]}')"
    assert_eq "$(gate_line qa)" "qa: fail - newest Official QA comment for $head is 'fail', not 'pass'"
}

test_qa_comment_without_commit_line_fails() {
    ready_pr '{comments: [comment(":robot: [qa] pass\nDate: 2026-11-26T10:00:00Z")]}'
    assert_eq "$(gate_line qa)" "qa: fail - newest Official QA comment has no 'Commit:' line"
}

test_qa_comment_unknown_commit_fails() {
    ready_pr '{comments: [comment(":robot: [qa] pass\nCommit: dddddddddddddddddddddddddddddddddddddddd")]}'
    assert_eq "$(gate_line qa)" \
        "qa: fail - newest Official QA comment names commit dddddddddddddddddddddddddddddddddddddddd, which this repository does not have"
}

test_stale_qa_with_later_code_change_fails() {
    setup
    commit_files src/app.txt
    old=$(git rev-parse HEAD)
    commit_files src/more.txt
    fake_pr "$(jq -cn --arg c "$(qa_comment pass "$old")" "$DEFS"' {comments: [comment($c)]}')"
    assert_eq "$(gate_line qa)" \
        "qa: fail - newest Official QA pass is for $old, but PR head $(git rev-parse HEAD) also changes src/more.txt"
}

test_docs_only_and_spec_archive_trailers_keep_qa_valid() {
    setup
    commit_files src/app.txt
    old=$(git rev-parse HEAD)
    commit_files --trailer "SDLC-Docs-Only: true" README.md
    commit_files --trailer "SDLC-Spec-Archive: true" .sdlc/specs/archived/12-task.md
    fake_pr "$(jq -cn --arg c "$(qa_comment pass "$old")" "$DEFS"' {comments: [comment($c)]}')"
    assert_eq "$(gate_line qa)" "qa: pass - Official QA passed for $old"
}

test_specs_only_later_commit_keeps_qa_valid() {
    setup '{"specs": {"path": "docs/specs"}}'
    commit_files src/app.txt
    old=$(git rev-parse HEAD)
    commit_files docs/specs/12-task.md
    fake_pr "$(jq -cn --arg c "$(qa_comment pass "$old")" "$DEFS"' {comments: [comment($c)]}')"
    assert_eq "$(gate_line qa)" "qa: pass - Official QA passed for $old"
}

test_spec_or_design_only_pr_skips_app_qa() {
    ready_pr '{comments: [], files: [file(".sdlc/specs/94-handle-review.md")]}'
    assert_eq "$(gate_line qa)" "qa: pass - spec/design-only PR; no app QA required"
}

test_all_gates_pass() {
    ready_pr
    output=$("$SH" "$GATES" 12) || { printf '%s\n' "$output"; exit 1; }
    assert_eq "$(printf '%s\n' "$output" | cut -d' ' -f1-2 | tr '\n' ,)" "approval: pass,checks: pass,threads: pass,qa: pass,"
}

test_one_failed_gate_fails() {
    ready_pr '{reviews: []}'
    "$SH" "$GATES" 12 > /dev/null
    assert_eq $? 1
}

test_bad_argument_fails() {
    "$SH" "$GATES" 2> /dev/null
    assert_eq $? 1
    "$SH" "$GATES" '#12' 2> /dev/null
    assert_eq $? 1
}

test_unreadable_pr_fails() {
    setup
    fake_gh "api graphql" 1 "not found"
    output=$("$SH" "$GATES" 12)
    assert_eq $? 1
    assert_eq "$output" "ship_gates failed: cannot read PR #12: not found"
}

test_missing_settings_fails() {
    output=$("$SH" "$GATES" 12)
    assert_eq $? 1
    assert_eq "$output" "ship_gates failed: cannot read .sdlc/settings.json"
}

test_solo_detection_ignores_bots_and_read_triage_users() {
    solo_pr '{comments: [comment("LGTM"; "dev")]}'
    fake_collaborators '[{"login":"dev","type":"User","permissions":{"push":true}},{"login":"dependabot","type":"Bot","permissions":{"push":true}},{"login":"reader","type":"User","permissions":{"push":false,"pull":true}},{"login":"triager","type":"User","permissions":{"push":false,"triage":true}}]'
    assert_eq "$(gate_line approval)" "approval: pass - approved by dev (solo approval)"
}

test_solo_detection_rejects_external_and_bot_pr_authors() {
    solo_pr '{author: {login: "outsider"}, comments: [comment("/approve"; "outsider")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
    fake_collaborators '[{"login":"dev","type":"User","permissions":{"push":true}},{"login":"ci-app","type":"Bot","permissions":{"push":true}}]'
    fake_pr '{author: {login: "ci-app"}, reviews: [], decision: null, comments: [comment("LGTM"; "ci-app"; "Bot")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
    fake_collaborators '[{"login":"ci-app","type":"Bot","permissions":{"push":true}}]'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_solo_detection_fails_closed_on_error_non_array_and_page_limit() {
    solo_pr '{comments: [comment("LGTM"; "dev")]}'
    fake_collaborators 1 "HTTP 403"
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
    fake_collaborators '{"message":"forbidden"}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
    fake_collaborators "$(jq -cn '[{login:"dev",type:"User",permissions:{push:true}}] + [range(99) | {login:"b\(.)",type:"Bot",permissions:{push:true}}]')"
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_solo_author_approval_comments_pass() {
    solo_pr
    for body in "LGTM" "/approve" "Approved!" "$(printf '  \r\n  approve.  \r\nmore notes')" ":robot: [approval] approved in chat by @dev"; do
        fake_pr "$(jq -cn --arg body "$body" "$DEFS"' {reviews: [], decision: null, comments: [comment($body; "dev")]}')"
        assert_eq "$(gate_line approval)" "approval: pass - approved by dev (solo approval)"
    done
}

test_solo_custom_review_prefix_approval_comment() {
    setup '{"review": {"prefix": "[bot]"}}'
    commit_files src/app.txt
    fake_collaborators '[{"login":"dev","type":"User","permissions":{"push":true}}]'
    fake_pr '{reviews: [], decision: null, comments: [comment("[bot] [approval] approved in chat by @dev"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: pass - approved by dev (solo approval)"
    fake_pr '{reviews: [], decision: null, comments: [comment(":robot: [approval] approved in chat by @dev"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no solo approval from dev"
}

test_solo_non_approval_comments_fail() {
    solo_pr
    assert_eq "$(gate_line approval)" "approval: fail - no solo approval from dev"
    for expr in \
        'comment("Looks good, ready to merge"; "dev")' \
        'comment("Note\n/approve"; "dev")' \
        'comment("LGTM"; "dev"; "User"; true)' \
        'comment("LGTM"; "other")' \
        'comment("LGTM"; "dev"; "Bot")'; do
        fake_pr "{reviews: [], decision: null, comments: [$expr]}"
        assert_eq "$(gate_line approval)" "approval: fail - no solo approval from dev"
    done
}

test_solo_changes_requested_still_fails() {
    solo_pr '{reviews: [review("CHANGES_REQUESTED"; "qa")], decision: "CHANGES_REQUESTED", comments: [comment("LGTM"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - changes requested by qa"
    if grep -q collaborators "$TEST_TMP/gh.log"; then
        printf 'expected collaborators not to be called\n'
        exit 1
    fi
}

test_solo_review_required_still_fails() {
    solo_pr '{decision: "REVIEW_REQUIRED", comments: [comment("LGTM"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - GitHub review decision is REVIEW_REQUIRED"
    fake_pr '{reviews: [], decision: "REVIEW_REQUIRED", comments: []}'
    assert_eq "$(gate_line approval)" "approval: fail - GitHub review decision is REVIEW_REQUIRED"
    fake_pr '{reviews: [], decision: "CHANGES_REQUESTED", comments: [comment("LGTM"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - GitHub review decision is CHANGES_REQUESTED"
}

test_multi_maintainer_author_approval_comment_fails() {
    ready_pr '{reviews: [], decision: null, comments: [comment("LGTM"; "dev"), comment(":robot: [approval] approved in chat by @dev"; "dev")]}'
    assert_eq "$(gate_line approval)" "approval: fail - no approval from a person"
}

test_existing_human_approval_skips_collaborators_api() {
    ready_pr
    assert_eq "$(gate_line approval)" "approval: pass - approved by lead"
    if grep -q collaborators "$TEST_TMP/gh.log"; then
        printf 'expected collaborators not to be called\n'
        exit 1
    fi
}
