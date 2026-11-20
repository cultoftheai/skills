# Tests for labels.sh, stage.sh and size.sh.

issue_with_labels() {
    fake_gh "issue view" 0 "{\"labels\": [$1]}"
    fake_gh "issue edit" 0
}

test_creates_only_missing_labels() {
    fake_gh "label list" 0 '[{"name": "READY"}, {"name": "shaped"}, {"name": "size:S"}, {"name": "bug"}]'
    fake_gh "label create" 0
    "$SH" "$SCRIPTS/labels.sh" > /dev/null || exit 1
    created=$(gh_calls "label create" | cut -d' ' -f3)
    assert_eq "$(printf '%s\n' "$created" | grep -cx -e ready -e size:S)" 0
    assert_eq "$(printf '%s\n' "$created" | wc -l | tr -d ' ')" 8
}

test_dry_run_creates_nothing() {
    fake_gh "label list" 0 '[]'
    output=$("$SH" "$SCRIPTS/labels.sh" --dry-run) || exit 1
    assert_contains "$output" "would create size:XL"
    assert_eq "$(gh_calls "label create")" ""
}

test_reports_when_all_labels_exist() {
    fake_gh "label list" 0 '[{"name":"ready"},{"name":"shaped"},{"name":"in-progress"},{"name":"review"},{"name":"done"},{"name":"blocked"},{"name":"size:XS"},{"name":"size:S"},{"name":"size:M"},{"name":"size:L"},{"name":"size:XL"}]'
    assert_eq "$("$SH" "$SCRIPTS/labels.sh")" "all stage and size labels exist"
}

test_never_edits_or_deletes() {
    fake_gh "label list" 0 '[]'
    fake_gh "label create" 0
    "$SH" "$SCRIPTS/labels.sh" > /dev/null || exit 1
    assert_eq "$(grep -cv -e '^label list' -e '^label create' "$TEST_TMP/gh.log")" 0
    assert_eq "$(grep -c -- --force "$TEST_TMP/gh.log")" 0
}

test_label_create_failure_exits_1() {
    fake_gh "label list" 0 '[]'
    fake_gh "label create" 1
    "$SH" "$SCRIPTS/labels.sh" > /dev/null 2>&1
    assert_eq $? 1
}

test_stage_replaces_other_stage_labels() {
    issue_with_labels '{"name": "ready"}, {"name": "good first issue"}, {"name": "size:M"}'
    "$SH" "$SCRIPTS/stage.sh" 12 shaped > /dev/null || exit 1
    assert_eq "$(gh_calls "issue edit")" "issue edit 12 --add-label shaped --remove-label ready"
}

test_stage_rejects_unknown_stage() {
    "$SH" "$SCRIPTS/stage.sh" 12 doing 2> /dev/null
    assert_eq $? 2
}

test_size_replaces_other_size_labels() {
    issue_with_labels '{"name": "size:S"}, {"name": "size:XL"}, {"name": "ready"}'
    "$SH" "$SCRIPTS/size.sh" 7 M > /dev/null || exit 1
    assert_eq "$(gh_calls "issue edit")" "issue edit 7 --add-label size:M --remove-label size:S,size:XL"
}

test_size_without_other_labels_only_adds() {
    issue_with_labels ''
    "$SH" "$SCRIPTS/size.sh" 7 XS > /dev/null || exit 1
    assert_eq "$(gh_calls "issue edit")" "issue edit 7 --add-label size:XS"
}

test_size_rejects_unknown_size() {
    "$SH" "$SCRIPTS/size.sh" 7 XXL 2> /dev/null
    assert_eq $? 2
}

test_gh_failure_exits_1() {
    fake_gh "issue view" 1
    "$SH" "$SCRIPTS/stage.sh" 12 done > /dev/null 2>&1
    assert_eq $? 1
    assert_eq "$(gh_calls "issue edit")" ""
}
