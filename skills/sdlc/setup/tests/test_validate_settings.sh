# Tests for validate_settings.sh.

VALID='{
  "default_branch": "main",
  "guides": {"development": "CONTRIBUTING.md", "code_review": null, "qa": null, "labeling": null},
  "templates": {"story": ".sdlc/templates/story.md", "epic": ".sdlc/templates/epic.md", "task": ".sdlc/templates/task.md",
                "spec": ".sdlc/templates/spec.md", "design": ".sdlc/templates/design.md",
                "review": ".sdlc/templates/review.md", "retro": ".sdlc/templates/retro.md"},
  "issue": {"tracker": "github", "estimation": "tshirt", "project": null,
            "stages": {"ready": null, "shaped": null, "in-progress": null, "review": null, "done": null, "blocked": null},
            "size_field": "label", "types": {"epic": null, "story": null, "task": null, "subtask": null}},
  "task": {"path": ".sdlc/task", "keep": true},
  "spec": {"storage": "local", "review": "manual"},
  "review": {"resolve": "reviewer", "prefix": ":robot:"},
  "retro": {"scope": "worktree"},
  "research": {"engine": null},
  "sizing": {"xs_max_files": 2, "xs_max_lines": 20, "m_max_tasks": 3,
             "l_min_modules": 3, "review_limit": 400, "risk_paths": ["db/migrations/**"]}
}'

# Validate VALID changed by the jq expression and print the output.
errors_for() {
    printf '%s\n' "$VALID" | jq "$1" > settings.json
    "$SH" "$SCRIPTS/validate_settings.sh" settings.json
}

test_valid_settings_pass() {
    assert_eq "$(errors_for .)" valid
}

test_schema_defaults_are_valid() {
    jq '{default_branch: "main"} + (.properties | with_entries(select(.value.type == "object")
        | .value |= (.properties | map_values(.default))))' "$SCRIPTS/../assets/settings.schema.json" > settings.json
    assert_eq "$("$SH" "$SCRIPTS/validate_settings.sh" settings.json)" valid
}

test_every_tracker_and_estimation_is_valid() {
    for tracker in github jira linear; do
        for estimation in none tshirt fibonacci; do
            assert_eq "$(errors_for ".issue.tracker = \"$tracker\" | .issue.estimation = \"$estimation\"")" valid
        done
    done
}

test_native_mapping_is_valid() {
    assert_eq "$(errors_for '.issue.tracker = "jira" | .issue.project = "ABC" | .issue.stages.ready = "To Do" | .issue.types.subtask = "Sub-task"')" valid
}

test_unknown_stage_is_named() {
    assert_eq "$(errors_for '.issue.stages.shipped = "Done"')" "issue.stages.shipped: unknown key"
}

test_bad_size_field() {
    assert_contains "$(errors_for '.issue.size_field = "points"')" "issue.size_field: must be one of"
}

test_missing_key_is_named() {
    assert_eq "$(errors_for 'del(.sizing.review_limit)')" "sizing.review_limit: missing"
}

test_unknown_key_is_named() {
    assert_eq "$(errors_for '.spec.reviewer = "x"')" "spec.reviewer: unknown key"
}

test_bad_enum_value() {
    assert_contains "$(errors_for '.spec.storage = "wiki"')" "spec.storage: must be one of"
}

test_boolean_is_not_an_integer() {
    assert_eq "$(errors_for '.sizing.xs_max_files = true')" "sizing.xs_max_files: must be integer, got true"
}

test_below_minimum_is_rejected() {
    assert_eq "$(errors_for '.sizing.m_max_tasks = 1')" "sizing.m_max_tasks: must be 2 or more, got 1"
}

test_empty_prefix_is_rejected() {
    assert_eq "$(errors_for '.review.prefix = ""')" "review.prefix: must not be empty"
}

test_risk_path_items_are_checked() {
    assert_eq "$(errors_for '.sizing.risk_paths = [3]')" "sizing.risk_paths.0: must be string, got 3"
}

test_errors_exit_1() {
    errors_for 'del(.retro)' > /dev/null
    assert_eq $? 1
}

test_missing_file_is_reported() {
    output=$("$SH" "$SCRIPTS/validate_settings.sh" missing.json)
    assert_eq $? 1
    assert_eq "$output" "missing.json: file not found"
}

test_invalid_json_is_reported() {
    printf '{"default_branch":' > settings.json
    assert_eq "$("$SH" "$SCRIPTS/validate_settings.sh" settings.json)" "settings.json: not valid JSON"
}
