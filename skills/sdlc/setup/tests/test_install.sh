# Tests for install.sh. Each test copies install.sh into a fake skills folder.

make_skills() {
    for path in setup/scripts/stage.sh setup/assets/settings.schema.json \
        prove/scripts/qa_check.sh ship/assets/sdlc-on-merge.yml root-cause/SKILL.md; do
        mkdir -p "skills/$(dirname "$path")"
        echo "$path" > "skills/$path"
    done
    cp "$SCRIPTS/install.sh" skills/setup/scripts/install.sh
    mkdir repo
}

test_copies_all_scripts_and_schema_but_not_itself() {
    make_skills
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    assert_eq "$(ls repo/.sdlc/scripts | tr '\n' ' ')" "qa_check.sh settings.schema.json stage.sh "
}

test_on_merge_copies_workflow() {
    make_skills
    "$SH" skills/setup/scripts/install.sh repo --on-merge > /dev/null || exit 1
    assert_eq "$(cat repo/.github/workflows/sdlc-on-merge.yml)" "ship/assets/sdlc-on-merge.yml"
}

test_missing_workflow_exits_1() {
    make_skills
    rm -r skills/ship
    "$SH" skills/setup/scripts/install.sh repo --on-merge > /dev/null 2>&1
    assert_eq $? 1
}

test_bad_arguments_exit_2() {
    "$SH" "$SCRIPTS/install.sh" /does/not/exist 2> /dev/null
    assert_eq $? 2
}
