# Tests for transcript_extract.sh. They build small transcripts in the temp directory.

WORKTREE=/work/repo/.trees/task-7
OTHER=/work/repo/.trees/task-70
export CLAUDE_CONFIG_DIR="$TEST_TMP/claude"
export CODEX_HOME="$TEST_TMP/codex"

extract() {
    "$SH" "$SCRIPTS/transcript_extract.sh" --harness "$1" --worktree "${2:-$WORKTREE}"
}

texts() {
    jq -r .text
}

cc_user() {
    printf '{"type": "user", "cwd": "%s", "timestamp": "t", "isSidechain": false, "message": {"role": "user", "content": %s}%s}\n' \
        "${2:-$WORKTREE}" "$1" "${3:-}"
}

cc_say() {
    cc_user "\"$1\"" "${2:-$WORKTREE}"
}

cc_tool() {
    printf '{"type": "assistant", "cwd": "%s", "timestamp": "t", "isSidechain": false, "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "%s", "input": {}}]}}\n' \
        "${2:-$WORKTREE}" "$1"
}

cc_tool_result() {
    cc_user '[{"type": "tool_result", "tool_use_id": "x", "content": "long output"}]'
}

cc_queued() {
    printf '{"type": "attachment", "cwd": "%s", "timestamp": "t", "isSidechain": false, "attachment": {"type": "queued_command", "prompt": "%s", "commandMode": "prompt", "origin": {"kind": "%s"}}}\n' \
        "$WORKTREE" "$1" "${2:-human}"
}

cc_session() {
    folder="$CLAUDE_CONFIG_DIR/projects/$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-')"
    mkdir -p "$folder"
    printf '%s\n' "$3" > "$folder/$2.jsonl"
}

codex_line() {
    printf '{"timestamp": "2026-11-20T10:00:00Z", "type": "%s", "payload": %s}\n' "$1" "$2"
}

codex_meta() {
    codex_line session_meta "{\"id\": \"s\", \"cwd\": \"${1:-$WORKTREE}\", \"source\": ${2:-\"cli\"}${3:-}}"
}

codex_user() {
    codex_line event_msg "{\"type\": \"user_message\", \"message\": \"$1\"}"
}

codex_call() {
    codex_line response_item "{\"type\": \"function_call\", \"name\": \"$1\", \"arguments\": \"{}\", \"call_id\": \"c\"}"
}

codex_rollout() {
    mkdir -p "$CODEX_HOME/${3:-sessions/2026/11/20}"
    printf '%s\n' "$2" > "$CODEX_HOME/${3:-sessions/2026/11/20}/$1"
}

test_keeps_messages_after_an_agent_action() {
    cc_session "$WORKTREE" s1 "$(cc_say "build it"; cc_tool Edit; cc_tool_result; cc_tool Bash; cc_say "no, keep the old name")"
    output=$(extract claude-code) || exit 1
    assert_eq "$(printf '%s\n' "$output" | texts)" "no, keep the old name"
    assert_eq "$(printf '%s\n' "$output" | jq -c .after)" '["Bash","Edit"]'
    assert_eq "$(printf '%s\n' "$output" | jq -r .session)" s1
}

test_skips_meta_sidechain_tags_and_other_origins() {
    cc_session "$WORKTREE" s1 "$(cc_say start; cc_tool Read
        cc_user '"skill text"' "$WORKTREE" ', "isMeta": true'
        cc_user '"agent prompt"' "$WORKTREE" ', "isSidechain": true'
        cc_say "<command-name>/clear</command-name>"
        cc_user '"a report"' "$WORKTREE" ', "origin": {"kind": "task-notification"}'
        cc_queued "<task-notification>done</task-notification>" task-notification)"
    output=$(extract claude-code) || exit 1
    assert_eq "$output" ""
}

test_keeps_a_message_queued_while_the_agent_worked() {
    cc_session "$WORKTREE" s1 "$(cc_say start; cc_tool Bash; cc_queued "stop, wrong branch")"
    assert_eq "$(extract claude-code | texts)" "stop, wrong branch"
}

test_reads_text_blocks_and_skips_bad_lines() {
    cc_session "$WORKTREE" s1 "$(cc_say start; cc_tool Write; cc_user '[{"type": "text", "text": "use the helper"}]'; echo '{not json')"
    assert_eq "$(extract claude-code | texts)" "use the helper"
}

test_includes_directories_inside_the_worktree_only() {
    cc_session "$WORKTREE/sub" in "$(cc_say a; cc_tool Bash; cc_say inside)"
    cc_session "$OTHER" out "$(cc_say a "$OTHER"; cc_tool Bash "$OTHER"; cc_say other "$OTHER")"
    assert_eq "$(extract claude-code | texts)" "inside"
}

test_other_worktree_is_no_session() {
    cc_session "$OTHER" out "$(cc_say a "$OTHER"; cc_tool Bash "$OTHER"; cc_say other "$OTHER")"
    extract claude-code > /dev/null 2>&1
    assert_eq $? 1
}

test_repo_root_covers_its_worktrees() {
    cc_session "$WORKTREE" s1 "$(cc_say a; cc_tool Bash; cc_say fix)"
    assert_eq "$(extract claude-code /work/repo | texts)" "fix"
}

test_cuts_long_messages() {
    cc_session "$WORKTREE" s1 "$(cc_say a; cc_tool Bash; cc_say "$(awk 'BEGIN { for (i = 0; i < 600; i++) printf "x " }')")"
    text=$(extract claude-code | texts)
    assert_eq "${#text}" 500
    assert_contains "$text" "x x..."
}

test_no_session_exits_1() {
    stderr=$(extract claude-code 2>&1 >/dev/null)
    assert_eq $? 1
    assert_contains "$stderr" "no chat data"
}

test_prints_json_lines() {
    cc_session "$WORKTREE" s1 "$(cc_say a; cc_tool Bash; cc_say again)"
    output=$(extract claude-code) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -r .text)" "again"
    assert_eq "$(printf '%s\n' "$output" | jq -r 'keys_unsorted | join(",")')" "session,timestamp,after,text"
}

test_bad_usage_exits_2() {
    "$SH" "$SCRIPTS/transcript_extract.sh" --harness other --worktree "$WORKTREE" 2> /dev/null
    assert_eq $? 2
    "$SH" "$SCRIPTS/transcript_extract.sh" --harness codex 2> /dev/null
    assert_eq $? 2
}

test_codex_keeps_messages_after_an_agent_action() {
    codex_rollout rollout-2026-11-20T10-00-00-a.jsonl "$(codex_meta; codex_user "add a flag"; codex_call shell; codex_user "wrong file")"
    output=$(extract codex) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -c '[.text, .after]')" '["wrong file",["shell"]]'
}

test_codex_counts_an_assistant_message_as_an_action() {
    reply=$(codex_line response_item '{"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "done"}]}')
    codex_rollout rollout-a.jsonl "$(codex_meta; codex_user hi; printf '%s\n' "$reply"; codex_user "that is not what I asked")"
    assert_eq "$(extract codex | jq -c .after)" '["message"]'
}

test_codex_skips_other_worktrees_and_subagents() {
    codex_rollout rollout-1.jsonl "$(codex_meta /elsewhere; codex_user a; codex_call shell; codex_user b)"
    codex_rollout rollout-2.jsonl "$(codex_meta "$WORKTREE" '{"subagent": "review"}'; codex_user a; codex_call shell; codex_user b)"
    codex_rollout rollout-3.jsonl "$(codex_meta "$WORKTREE" '"cli"' ', "parent_thread_id": "p"'; codex_user a; codex_call shell; codex_user b)"
    extract codex > /dev/null 2>&1
    assert_eq $? 1
}

test_codex_reads_archived_sessions() {
    codex_rollout rollout-a.jsonl "$(codex_meta; codex_user a; codex_call apply_patch; codex_user b)" archived_sessions
    assert_eq "$(extract codex | texts)" "b"
}

test_codex_reports_a_file_that_does_not_parse() {
    codex_rollout rollout-bad.jsonl "not json"
    stderr=$(extract codex 2>&1 >/dev/null)
    assert_eq $? 1
    assert_contains "$stderr" "skipped rollout-bad.jsonl: no JSON records"
}

test_codex_reads_compressed_rollouts() {
    if ! command -v zstd > /dev/null; then
        return 0
    fi
    codex_rollout rollout-z.jsonl "$(codex_meta; codex_user a; codex_call shell; codex_user b)"
    zstd -q --rm "$CODEX_HOME/sessions/2026/11/20/rollout-z.jsonl"
    assert_eq "$(extract codex | texts)" "b"
}
