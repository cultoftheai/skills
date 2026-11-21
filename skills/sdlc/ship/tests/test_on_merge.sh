# Tests for on_merge.sh. gh and stage.sh are faked.

# Make the fake gh answer "gh pr view" with the state and the closed issues.
pr() {
    fake_gh "pr view" 0 "$(jq -cn --arg state "$1" --arg issues "${2:-}" \
        '{state: $state, closingIssuesReferences: [$issues | split(" ")[] | select(. != "") | {number: tonumber}]}')"
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
