# Tests for ship_gates.sh. gh is faked; git runs on a real repository.

DEFS='
  def review($s; $l; $t): {state: $s, author: {__typename: $t, login: $l}};
  def review($s; $l): review($s; $l; "User");
  def thread($resolved; $l): {isResolved: $resolved, comments: {nodes: [{url: "https://example.test/\($l)", author: {login: $l}}]}};
  def comment($b): {body: $b};
  def file($p): {path: $p};
'

# Create a repository with settings, green checks, and an initial commit.
setup() {
    git init -q repo
    cd repo || exit 1
    git config user.name test
    git config user.email test@example.test
    mkdir .sdlc
    default_settings='{}'
    printf '%s\n' "${1:-$default_settings}" > .sdlc/settings.json
    fake_gh "pr checks" 0 '[{"name": "ci", "bucket": "pass"}]'
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
          reviews: [review("APPROVED"; "lead")],
          threads: [],
          decision: "APPROVED",
          files: [file("src/app.txt")],
          comments: [comment(":robot: [qa] pass\nCommit: \($head)\nDate: 2026-11-26T10:00:00Z\n\n### Checks\n- cmd -> ok")]
        } + $extra) as $o
        | {data: {repository: {pullRequest: {
            headRefOid: $o.head, reviewDecision: $o.decision, author: {login: "dev"},
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
