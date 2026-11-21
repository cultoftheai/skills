# Tests for ship_gates.sh. gh and qa_check.sh are faked; git runs on a real repository.

DEFS='
  def review($s; $l; $t): {state: $s, author: {__typename: $t, login: $l}};
  def review($s; $l): review($s; $l; "User");
  def thread($resolved; $l): {isResolved: $resolved, comments: {nodes: [{url: "https://example.test/\($l)", author: {login: $l}}]}};
'

# Create a repository whose settings put task folders in the path, with green checks and a passing QA check.
setup() {
    git init -q repo
    cd repo || exit 1
    git config user.name test
    git config user.email test@example.test
    mkdir .sdlc
    printf '{"task": {"path": "%s"}}\n' "${1:-.sdlc/task}" > .sdlc/settings.json
    fake_gh "pr checks" 0 '[{"name": "ci", "bucket": "pass"}]'
    fake_script qa_check.sh 0 "QA check passed"
}

# Commit a new file at each path.
commit_files() {
    for path in "$@"; do
        mkdir -p "$(dirname "$path")"
        echo "$path" > "$path"
        git add "$path"
    done
    git commit -qm "Add $*"
}

# Commit the removal of the path.
commit_removal() {
    git rm -rq "$1"
    git commit -qm "Remove $1"
}

# Make the fake gh answer the GraphQL query with a PR by "dev" at HEAD that closes #7. Usage: fake_pr [jq object of head, reviews, threads, issues, decision]
fake_pr() {
    fake_gh "api graphql" 0 "$(jq -cn --arg head "$(git rev-parse HEAD)" "$DEFS (${1:-null}) as \$extra | "'
        ({head: $head, reviews: [review("APPROVED"; "lead")], threads: [], issues: [7], decision: "APPROVED"} + $extra) as $o
        | {data: {repository: {pullRequest: {
            headRefOid: $o.head, reviewDecision: $o.decision, author: {login: "dev"},
            closingIssuesReferences: {nodes: [$o.issues[] | {number: .}]},
            latestOpinionatedReviews: {nodes: $o.reviews},
            reviewThreads: {nodes: $o.threads}}}}}')"
}

# Set up a PR whose task folder has QA.md at HEAD. Usage: ready_pr [jq object for fake_pr]
ready_pr() {
    setup
    commit_files .sdlc/task/7/QA.md
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

test_runs_qa_check_on_task_folder() {
    ready_pr
    assert_eq "$(gate_line qa)" "qa: pass - QA check passed"
    assert_eq "$(script_calls qa_check.sh)" "$(pwd -P) .sdlc/task/7"
}

test_task_path_comes_from_settings() {
    setup docs/tasks/
    commit_files docs/tasks/7/QA.md
    fake_pr
    assert_eq "$(gate_line qa)" "qa: pass - QA check passed"
    assert_eq "$(script_calls qa_check.sh)" "$(pwd -P) docs/tasks/7"
}

test_local_head_must_be_pr_head() {
    ready_pr '{head: "bbbb"}'
    assert_eq "$(gate_line qa)" "qa: fail - local HEAD $(git rev-parse HEAD) is not the PR head bbbb"
    assert_eq "$(script_calls qa_check.sh)" ""
}

test_qa_check_failure_fails() {
    ready_pr
    fake_script qa_check.sh 1 "QA check failed: stale"
    assert_eq "$(gate_line qa)" "qa: fail - QA check failed: stale"
}

test_no_issue_checks_xs_evidence() {
    ready_pr '{issues: []}'
    assert_eq "$(gate_line qa)" "qa: pass - QA check passed"
    assert_eq "$(script_calls qa_check.sh)" "$(pwd -P) .git/sdlc/qa"
}

test_missing_qa_fails() {
    setup
    commit_files src/app.txt
    fake_pr
    assert_eq "$(gate_line qa)" "qa: fail - .sdlc/task/7/QA.md does not exist; run prove first"
}

test_removed_folder_checks_commit_before_removal() {
    setup
    commit_files .sdlc/task/7/QA.md .sdlc/task/7/SPEC.md
    commit_removal .sdlc/task/7
    fake_pr
    assert_eq "$(gate_line qa)" "qa: pass - QA check passed"
    tree=$(script_calls qa_check.sh | cut -d' ' -f1)
    assert_eq "$(script_calls qa_check.sh | cut -d' ' -f2)" ".sdlc/task/7"
    [ "$tree" != "$(pwd -P)" ] || { echo "qa_check.sh ran in the repository, not in a worktree"; exit 1; }
    [ ! -e "$tree" ] || { echo "the worktree $tree was not removed"; exit 1; }
    assert_eq "$(git worktree list | wc -l | tr -d ' ')" 1
}

test_code_change_after_removal_fails() {
    setup
    commit_files .sdlc/task/7/QA.md
    commit_removal .sdlc/task/7
    commit_files src/app.txt
    fake_pr
    assert_eq "$(gate_line qa)" "qa: fail - QA.md was removed and later commits change src/app.txt"
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
