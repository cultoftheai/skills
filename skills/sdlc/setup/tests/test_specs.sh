# Tests for specs.sh.

make_git_repo() {
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
}

test_lists_only_top_level_task_specs_in_order() {
    mkdir -p .sdlc/specs/archived
    : > .sdlc/specs/10-ten.md
    : > .sdlc/specs/2-two.md
    : > .sdlc/specs/87-story-design.md
    : > .sdlc/specs/archived/1-old.md
    : > .sdlc/specs/notes.txt
    fake_gh "pr list" 0 "[]"
    output=$("$SH" "$SCRIPTS/specs.sh") || exit 1
    assert_eq "$output" "$(printf '#2 .sdlc/specs/2-two.md [unclaimed]\n#10 .sdlc/specs/10-ten.md [unclaimed]')"
}

test_reports_pr_and_branch_claims_and_ignores_spec_branches() {
    make_git_repo
    mkdir -p .sdlc/specs
    : > .sdlc/specs/3-three.md
    : > .sdlc/specs/4-four.md
    : > .sdlc/specs/5-five.md
    git add .sdlc/specs
    git commit -q -m "Add specs"
    git branch 4-build-four
    git branch spec/5-five
    fake_gh "pr list" 0 '[{"number": 42, "headRefName": "3-work", "closingIssuesReferences": [{"number": 3}], "body": "Closes #3"}, {"number": 43, "headRefName": "spec/5-five", "closingIssuesReferences": [], "body": "Spec for #5"}]'
    output=$("$SH" "$SCRIPTS/specs.sh") || exit 1
    expected=$(printf '#3 .sdlc/specs/3-three.md [PR #42]\n#4 .sdlc/specs/4-four.md [branch 4-build-four]\n#5 .sdlc/specs/5-five.md [unclaimed]')
    assert_eq "$output" "$expected"
}

test_respects_custom_specs_path_from_settings() {
    mkdir -p .sdlc docs/specs
    printf '{"specs":{"path":"docs/specs/"}}\n' > .sdlc/settings.json
    : > docs/specs/7-seven.md
    fake_gh "pr list" 0 "[]"
    output=$("$SH" "$SCRIPTS/specs.sh") || exit 1
    assert_eq "$output" "#7 docs/specs/7-seven.md [unclaimed]"
}

test_missing_specs_dir_prints_nothing_and_exits_0() {
    output=$("$SH" "$SCRIPTS/specs.sh") || exit 1
    assert_eq "$output" ""
}

test_gh_failure_exits_1() {
    mkdir -p .sdlc/specs
    : > .sdlc/specs/1-one.md
    fake_gh "pr list" 1
    "$SH" "$SCRIPTS/specs.sh" > /dev/null 2>&1
    assert_eq $? 1
}
