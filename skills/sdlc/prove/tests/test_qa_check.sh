# Tests for qa_check.sh. Git is faked; no repository is needed.

HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
OLD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
ROOT=$(pwd -P)
TASK="$ROOT/.sdlc/task/5"
LATER=''
mkdir -p "$TASK"

# Write a QA.md whose newest run has the commit and result, above an older passing run.
write_qa() {
    printf '## Run 2026-11-20T10:00:00Z\nCommit: %s\nResult: %s\n### Steps\n- cmd -> ok\n\n## Assumptions\n- the app runs on the default port\n\n## Run 2026-11-19T10:00:00Z\nCommit: %s\nResult: pass\n### Steps\n- cmd -> ok\n' \
        "${1:-$HEAD}" "${2:-pass}" "$HEAD" > "$TASK/QA.md"
}

# Fake a repository whose root is the argument, with HEAD and OLD, where OLD is an ancestor of HEAD.
repo() {
    fake_git "rev-parse HEAD" 0 "$HEAD"
    fake_git "rev-parse --show-toplevel" 0 "${1:-$ROOT}"
    fake_git "rev-parse --verify --quiet $HEAD^{commit}" 0 "$HEAD"
    fake_git "rev-parse --verify --quiet $OLD^{commit}" 0 "$OLD"
    fake_git "merge-base $OLD $HEAD" 0 "$OLD"
    fake_git "rev-list $OLD..$HEAD" 0
}

# Fake one commit after OLD: its number, its SDLC-Docs-Only trailer value, and the files it changes. Call oldest first.
later_commit() {
    sha=$(printf '%040x' "$1")
    fake_git "log -1 --format=%(trailers:key=SDLC-Docs-Only,valueonly) $sha" 0 "$2"
    shift 2
    fake_git "diff --name-only $sha^1 $sha" 0 "$(printf '%s\n' "$@")"
    LATER="$sha
$LATER"
    fake_git "rev-list $OLD..$HEAD" 0 "$LATER"
}

# Fail the test unless the check passes for the commit.
assert_passes() {
    output=$("$SH" "$SCRIPTS/qa_check.sh" "$TASK") || { printf '%s\n' "$output"; exit 1; }
    assert_eq "$output" "QA check passed: pass recorded for $1"
}

# Fail the test unless the check exits 1 with the reason in its output.
assert_fails() {
    output=$("$SH" "$SCRIPTS/qa_check.sh" "$TASK")
    assert_eq $? 1
    assert_contains "$output" "$1"
}

test_pass_for_head() {
    repo
    write_qa
    assert_passes "$HEAD"
}

test_missing_file() {
    repo
    assert_fails "does not exist"
}

test_no_run_section() {
    repo
    printf '# QA\nnothing yet\n' > "$TASK/QA.md"
    assert_fails "no '## Run' section"
}

test_missing_commit_line() {
    repo
    printf '## Run 2026-11-20\nResult: pass\n' > "$TASK/QA.md"
    assert_fails "no 'Commit:' line"
}

test_newest_run_failed() {
    repo
    write_qa "$HEAD" fail
    assert_fails "'fail', not 'pass'"
}

test_older_pass_does_not_count() {
    repo
    write_qa "$OLD" fail
    assert_fails "'fail'"
}

test_unknown_commit() {
    repo
    fake_git "rev-parse --verify --quiet dddddddddddddddddddddddddddddddddddddddd^{commit}" 1
    write_qa dddddddddddddddddddddddddddddddddddddddd
    assert_fails "does not have"
}

test_stale_commit_with_code_change() {
    repo
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/5/QA.md
    later_commit 2 '' src/app.py
    assert_fails "also changes src/app.py"
}

test_old_commit_with_only_task_folder_changes() {
    repo
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/5/QA.md
    assert_passes "$OLD"
}

test_docs_only_trailer_commit_is_accepted() {
    repo
    write_qa "$OLD"
    later_commit 1 true docs/guide.md README.md
    assert_passes "$OLD"
}

test_commit_without_trailer_outside_task_folder_is_rejected() {
    repo
    write_qa "$OLD"
    later_commit 1 '' docs/guide.md
    assert_fails "also changes docs/guide.md"
}

test_mix_of_task_folder_and_docs_only_commits_is_accepted() {
    repo
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/5/QA.md
    later_commit 2 true docs/guide.md
    later_commit 3 '' .sdlc/task/5/QA.md
    assert_passes "$OLD"
}

test_mix_with_one_plain_code_commit_is_rejected() {
    repo
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/5/QA.md
    later_commit 2 true docs/guide.md
    later_commit 3 '' src/app.py
    output=$("$SH" "$SCRIPTS/qa_check.sh" "$TASK")
    assert_eq "$output" "QA check failed: the newest run is for $OLD, but HEAD $HEAD also changes src/app.py"
}

test_other_task_folder_is_not_exempt() {
    repo
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/50/QA.md
    assert_fails "also changes"
}

test_commit_not_ancestor() {
    repo
    fake_git "merge-base $OLD $HEAD" 0 cccccccccccccccccccccccccccccccccccccccc
    write_qa "$OLD"
    assert_fails "not an ancestor"
}

test_folder_outside_repository_needs_exact_head() {
    mkdir -p "$ROOT/elsewhere"
    repo "$ROOT/elsewhere"
    write_qa "$OLD"
    later_commit 1 '' .sdlc/task/5/QA.md
    assert_fails "also changes"
}

test_exit_codes() {
    repo
    write_qa "$HEAD" fail
    assert_fails "'fail', not 'pass'"
    "$SH" "$SCRIPTS/qa_check.sh" 2> /dev/null
    assert_eq $? 1
}
