# Tests for on_merge.sh. gh and stage.sh are faked.

# Make the fake gh answer "gh pr view" with the state, closed issues, and optional body. The base branch is main.
pr() {
    fake_gh "pr view" 0 "$(jq -cn --arg state "$1" --arg issues "${2:-}" --arg body "${3:-}" \
        '{state: $state, body: $body, baseRefName: "main",
          closingIssuesReferences: [$issues | split(" ")[] | select(. != "") | {number: tonumber}]}')"
}

# Make the fake gh find no open cleanup PR and open a new one.
no_open_cleanup_pr() {
    fake_gh "pr list" 0 "[]"
    fake_gh "pr create" 0 "https://github.com/o/r/pull/13"
}

test_sets_done_on_the_closed_issue() {
    pr MERGED 7
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2-)" "7 done"
    assert_contains "$(cat "$TEST_TMP/gh.log")" "pr view 12 --json state,closingIssuesReferences"
}

test_handles_every_closed_issue() {
    pr MERGED "7 8"
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7, #8."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2- | tr '\n' ,)" "7 done,8 done,"
}

test_open_pr_fails_and_changes_nothing() {
    pr OPEN 7
    output=$("$SH" "$ON_MERGE" 12)
    assert_eq $? 1
    assert_eq "$output" "PR #12 is OPEN, not MERGED"
    assert_eq "$(script_calls stage.sh)" ""
}

test_no_issue_is_nothing_to_do() {
    pr MERGED
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "PR #12 closes no issue. Nothing to do."
    assert_eq "$(script_calls stage.sh)" ""
}

test_failed_step_fails_but_runs_the_rest() {
    pr MERGED "7 8"
    fake_script stage.sh 1 boom
    output=$("$SH" "$ON_MERGE" 12)
    assert_eq $? 1
    assert_contains "$output" "#7: stage.sh failed: boom"
    assert_contains "$output" "#8: stage.sh failed: boom"
}

test_unreadable_pr_fails() {
    fake_gh "pr view" 1 "not found"
    output=$("$SH" "$ON_MERGE" 12)
    assert_eq $? 1
    assert_eq "$output" "cannot read PR #12: not found"
}

test_bad_argument_fails() {
    "$SH" "$ON_MERGE" abc 2> /dev/null
    assert_eq $? 1
    "$SH" "$ON_MERGE" 2> /dev/null
    assert_eq $? 1
}

test_sets_shaped_on_merged_spec_or_design_pr() {
    pr MERGED "" "Spec for #95"
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set shaped on #95."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2-)" "95 shaped"

    : > "$TEST_TMP/scripts.log"
    pr MERGED "" "Design for #87"
    output=$("$SH" "$ON_MERGE" 13) || exit 1
    assert_eq "$output" "Set shaped on #87."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2-)" "87 shaped"
}

test_closing_issues_take_precedence_over_spec_reference() {
    pr MERGED 7 "Implements Spec for #7"
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2-)" "7 done"
}

test_deduplicates_spec_references() {
    pr MERGED "" "Spec for #5 (duplicate spec for #5)"
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set shaped on #5."
    assert_eq "$(script_calls stage.sh | cut -d' ' -f2-)" "5 shaped"
}

test_archive_opens_cleanup_pr_with_the_spec_moved() {
    git_repo '{}' .sdlc/specs/7-foo.md .sdlc/specs/7-foo-design.md .sdlc/specs/70-bar.md .sdlc/specs/archived/7-old.md
    pr MERGED 7
    no_open_cleanup_pr
    output=$("$SH" "$ON_MERGE" 12) || { printf '%s\n' "$output"; exit 1; }
    assert_eq "$output" "Set done on #7.
Opened cleanup PR https://github.com/o/r/pull/13."
    assert_eq "$(origin_files sdlc/cleanup-12 | tr '\n' ,)" \
        ".sdlc/settings.json,.sdlc/specs/7-foo-design.md,.sdlc/specs/70-bar.md,.sdlc/specs/archived/7-foo.md,.sdlc/specs/archived/7-old.md,"
    assert_contains "$(git --git-dir="$TEST_TMP/origin.git" log -1 --format=%B sdlc/cleanup-12)" "SDLC-Spec-Archive: true"
    log=$(cat "$TEST_TMP/gh.log")
    assert_contains "$log" "pr create --base main --head sdlc/cleanup-12"
    assert_contains "$log" "Cleanup for PR #12"
    case "$log" in *Closes*) echo "PR body must not close an issue"; exit 1 ;; esac
    assert_eq "$(git status --porcelain)" ""
    assert_eq "$(git worktree list | wc -l | tr -d ' ')" 1
    assert_eq "$(origin_files main | grep -c 'specs/7-foo.md')" 1
}

test_delete_opens_cleanup_pr_without_the_spec() {
    git_repo '{"specs": {"on_ship": "delete"}}' .sdlc/specs/7-foo.md .sdlc/specs/8-bar.md
    pr MERGED 7
    no_open_cleanup_pr
    "$SH" "$ON_MERGE" 12 > /dev/null || exit 1
    assert_eq "$(origin_files sdlc/cleanup-12 | tr '\n' ,)" ".sdlc/settings.json,.sdlc/specs/8-bar.md,"
}

test_task_keep_false_removes_the_task_folder() {
    git_repo '{"specs": {"on_ship": "keep"}, "task": {"path": "tasks/", "keep": false}}' \
        .sdlc/specs/7-foo.md tasks/7/SPEC.md tasks/7/QA.md tasks/8/SPEC.md
    pr MERGED 7
    no_open_cleanup_pr
    output=$("$SH" "$ON_MERGE" 12) || { printf '%s\n' "$output"; exit 1; }
    assert_eq "$(origin_files sdlc/cleanup-12 | tr '\n' ,)" ".sdlc/settings.json,.sdlc/specs/7-foo.md,tasks/8/SPEC.md,"
}

test_keep_is_nothing_to_clean_up() {
    git_repo '{"specs": {"on_ship": "keep"}}' .sdlc/specs/7-foo.md .sdlc/task/7/SPEC.md
    pr MERGED 7
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7.
Nothing to clean up."
    assert_eq "$(git --git-dir="$TEST_TMP/origin.git" branch --list 'sdlc/*')" ""
}

test_no_matching_spec_is_nothing_to_clean_up() {
    git_repo '{}' .sdlc/specs/8-bar.md .sdlc/specs/archived/7-foo.md
    pr MERGED 7
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7.
Nothing to clean up."
    case "$(cat "$TEST_TMP/gh.log")" in *"pr create"*) echo "no PR expected"; exit 1 ;; esac
}

test_spec_pr_opens_no_cleanup_pr() {
    git_repo '{}' .sdlc/specs/7-foo.md
    pr MERGED "" "Spec for #7"
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set shaped on #7."
    case "$(cat "$TEST_TMP/gh.log")" in *"pr list"* | *"pr create"*) echo "no cleanup expected"; exit 1 ;; esac
}

test_open_cleanup_pr_is_not_opened_again() {
    git_repo '{}' .sdlc/specs/7-foo.md
    pr MERGED 7
    fake_gh "pr list" 0 '[{"number": 13}]'
    output=$("$SH" "$ON_MERGE" 12) || exit 1
    assert_eq "$output" "Set done on #7.
Cleanup PR #13 is already open."
    assert_contains "$(cat "$TEST_TMP/gh.log")" "pr list --head sdlc/cleanup-12 --base main --state open"
    assert_eq "$(git --git-dir="$TEST_TMP/origin.git" branch --list 'sdlc/*')" ""
}

test_failed_cleanup_pr_fails_and_removes_the_worktree() {
    git_repo '{}' .sdlc/specs/7-foo.md
    pr MERGED 7
    fake_gh "pr list" 0 "[]"
    fake_gh "pr create" 1 "no permission"
    output=$("$SH" "$ON_MERGE" 12)
    assert_eq $? 1
    assert_contains "$output" "cannot open cleanup PR for PR #12: no permission"
    assert_eq "$(git worktree list | wc -l | tr -d ' ')" 1
}
