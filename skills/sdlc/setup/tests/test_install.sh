# Tests for install.sh. Each test copies install.sh into a fake skills folder.

make_skills() {
    for path in setup/scripts/stage.sh setup/assets/settings.schema.json \
        prove/scripts/qa_check.sh root-cause/SKILL.md frame/assets/templates/story.md \
        frame/assets/templates/epic.md; do
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

test_missing_schema_exits_1() {
    make_skills
    rm skills/setup/assets/settings.schema.json
    "$SH" skills/setup/scripts/install.sh repo > /dev/null 2>&1
    assert_eq $? 1
}

test_copies_templates_of_every_skill() {
    make_skills
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    assert_eq "$(ls repo/.sdlc/templates | tr '\n' ' ')" "epic.md story.md "
}

test_keeps_an_existing_template() {
    make_skills
    mkdir -p repo/.sdlc/templates
    echo mine > repo/.sdlc/templates/story.md
    output=$("$SH" skills/setup/scripts/install.sh repo) || exit 1
    assert_contains "$output" "kept repo/.sdlc/templates/story.md"
    assert_eq "$(cat repo/.sdlc/templates/story.md)" mine
}

test_override_replaces_an_existing_template() {
    make_skills
    mkdir -p repo/.sdlc/templates
    echo mine > repo/.sdlc/templates/story.md
    "$SH" skills/setup/scripts/install.sh repo --override > /dev/null || exit 1
    assert_eq "$(cat repo/.sdlc/templates/story.md)" frame/assets/templates/story.md
}

test_unknown_flag_exits_2() {
    make_skills
    "$SH" skills/setup/scripts/install.sh repo --force 2> /dev/null
    assert_eq $? 2
}

test_bad_arguments_exit_2() {
    "$SH" "$SCRIPTS/install.sh" /does/not/exist 2> /dev/null
    assert_eq $? 2
}

test_creates_specs_archive_and_work_directories() {
    make_skills
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    [ -d repo/.sdlc/specs ] || exit 1
    [ -d repo/.sdlc/specs/archived ] || exit 1
    [ -d repo/.sdlc/work ] || exit 1
}

test_writes_work_to_sdlc_gitignore_without_touching_root() {
    make_skills
    echo node_modules/ > repo/.gitignore
    output=$("$SH" skills/setup/scripts/install.sh repo) || exit 1
    assert_contains "$output" "wrote repo/.sdlc/.gitignore"
    assert_eq "$(cat repo/.sdlc/.gitignore)" "work/"
    assert_eq "$(cat repo/.gitignore)" "node_modules/"
}

test_preserves_existing_sdlc_gitignore_and_is_idempotent() {
    make_skills
    mkdir -p repo/.sdlc
    printf 'local.env' > repo/.sdlc/.gitignore
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    assert_eq "$(cat repo/.sdlc/.gitignore)" "$(printf 'local.env\nwork/')"
}

test_respects_custom_paths_from_settings() {
    make_skills
    mkdir -p repo/.sdlc
    printf '{"specs":{"path":"docs/specs","archive_path":"docs/specs/done"},"work":{"path":".sdlc/tmp-work/"}}\n' \
        > repo/.sdlc/settings.json
    "$SH" skills/setup/scripts/install.sh repo > /dev/null || exit 1
    [ -d repo/docs/specs ] || exit 1
    [ -d repo/docs/specs/done ] || exit 1
    [ -d repo/.sdlc/tmp-work ] || exit 1
    assert_eq "$(cat repo/.sdlc/.gitignore)" "tmp-work/"
}

test_warns_when_work_path_is_outside_sdlc() {
    make_skills
    mkdir -p repo/.sdlc
    printf '{"specs":{"path":".sdlc/specs","archive_path":".sdlc/specs/archived"},"work":{"path":"tmp/work"}}\n' \
        > repo/.sdlc/settings.json
    err=$("$SH" skills/setup/scripts/install.sh repo 2>&1 >/dev/null) || exit 1
    [ -d repo/tmp/work ] || exit 1
    [ ! -f repo/.sdlc/.gitignore ] || exit 1
    [ ! -f repo/.gitignore ] || exit 1
    assert_contains "$err" "tmp/work"
}
