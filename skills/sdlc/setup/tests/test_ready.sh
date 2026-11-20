# Tests for ready.sh.

issue() {
    printf '{"number": %s, "title": "Task %s", "blockedBy": {"nodes": [%s]}, "subIssuesSummary": {"total": %s}}' \
        "$1" "$1" "${2:-}" "${3:-0}"
}

test_lists_only_free_tasks_in_order() {
    fake_gh "issue list" 0 "[$(issue 9), $(issue 3), $(issue 4 '{"number": 3, "state": "OPEN"}'), $(issue 5 '{"number": 1, "state": "CLOSED"}'), $(issue 6 '' 2), $(issue 7)]"
    output=$("$SH" "$SCRIPTS/ready.sh") || exit 1
    assert_eq "$output" "$(printf '#3 Task 3\n#5 Task 5\n#7 Task 7\n#9 Task 9')"
}

test_blocker_without_state_counts_as_open() {
    fake_gh "issue list" 0 "[$(issue 4 '{"number": 2}')]"
    assert_eq "$("$SH" "$SCRIPTS/ready.sh")" ""
}

test_failure_exits_1() {
    fake_gh "issue list" 1
    "$SH" "$SCRIPTS/ready.sh" > /dev/null 2>&1
    assert_eq $? 1
}
