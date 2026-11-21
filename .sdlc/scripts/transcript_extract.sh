#!/bin/sh
# Print the user messages that follow an agent action in the chat transcripts of one worktree.
#
# Usage: transcript_extract.sh --harness claude-code|codex --worktree <path>
#
# Transcripts:
#   claude-code  <CLAUDE_CONFIG_DIR or ~/.claude>/projects/<working directory with each
#                character that is not a letter or digit replaced by "-">/<session>.jsonl
#   codex        <CODEX_HOME or ~/.codex>/sessions/YYYY/MM/DD/rollout-*.jsonl and
#                archived_sessions/rollout-*.jsonl, also as .jsonl.zst (read with zstd)
#
# A session belongs to the worktree when its working directory is <path> or inside it.
# Subagent sessions are skipped, because their user messages come from an agent.
#
# Output: one JSON object per line with the keys session, timestamp, after and text.
# "after" lists the agent actions (tool names, or "message") since the previous user
# message. "text" is cut to 500 characters. The first message of a session is not
# printed, because no agent action comes before it.
#
# Exit codes: 0 when at least one session was read; 1 when no session of the worktree
# was found or could be parsed, which means there is no chat data; 2 bad usage.

set -u
LC_ALL=C
export LC_ALL

NOT_A_SESSION=10
NO_RECORDS=11

COMMON='
  def inside($worktree): ($worktree | sub("/+$"; "")) as $root | . == $root or startswith($root + "/");
  def blank: test("^\\s*$");
  def parse: fromjson? | objects;
  def stop($code): "" | halt_error($code);
  def clip: [splits("\\s+") | select(. != "")] | join(" ") | if length <= 500 then . else .[:497] + "..." end;
  def distinct: reduce .[] as $item ([]; if any(.[]; . == $item) then . else . + [$item] end);
  def corrections:
    reduce .[] as [$kind, $value, $stamp] ({actions: [], last: null, found: []};
      if $kind == "agent" then .actions += [$value]
      else
        (if (.actions | length) > 0 and $value != .last
         then .found += [{session: $session, timestamp: $stamp, after: (.actions | reverse | distinct | .[:5]), text: ($value | clip)}]
         else . end)
        | .actions = [] | .last = $value
      end)
    | .found[];
'

CLAUDE_CODE_FILTER='
  def actions:
    if type == "array" then [.[] | select(.type == "tool_use") | .name // "tool"] + (if any(.[]; .type == "text") then ["message"] else [] end)
    elif . == null or . == "" or . == false then []
    else ["message"] end;
  def human($fallback): if type == "object" then .kind == "human" else $fallback end;
  def typed: select(type == "string" and (blank | not) and (test("^\\s*<") | not));
  def user_text:
    select(.origin | human(true))
    | (.message // {}).content
    | if type == "array" then select(all(.[]; .type == "text")) | map(.text // "") | join("\n") else . end
    | typed;
  def queued_text:
    (.attachment // {}) as $attachment
    | select($attachment.type == "queued_command")
    | select($attachment.origin | human($attachment.commandMode == "prompt"))
    | $attachment.prompt | typed;
  def event:
    (.timestamp // "") as $stamp
    | if .type == "assistant" then (.message // {}).content | actions[] | ["agent", ., $stamp]
      elif .type == "user" then user_text | ["human", ., $stamp]
      elif .type == "attachment" then queued_text | ["human", ., $stamp]
      else empty end;
  [inputs | parse] as $records
  | if $records == [] then stop($no_records) else . end
  | [$records[] | select((.isSidechain or .isMeta) | not) | select((.cwd // "") | tostring | inside($worktree))] as $own
  | if $own == [] then stop($not_a_session) else . end
  | [$own[] | event] | corrections
'

CODEX_FILTER='
  def person_in_worktree:
    (if (.source | type) == "object" then .source | has("subagent") or has("internal") else false end) as $subagent
    | ((.cwd // "") | tostring | inside($worktree)) and ((.parent_thread_id or .agent_path or $subagent) | not);
  def action:
    if .type == "function_call" or .type == "custom_tool_call" then .name // "tool"
    elif .type == "local_shell_call" or .type == "web_search_call" then .type | rtrimstr("_call")
    elif .type == "message" and .role == "assistant" then "message"
    else empty end;
  def event:
    (.payload // {}) as $payload
    | (.timestamp // "") as $stamp
    | if .type == "event_msg" and $payload.type == "user_message" then $payload.message | select(type == "string" and (blank | not)) | ["human", ., $stamp]
      elif .type == "response_item" then $payload | action | ["agent", ., $stamp]
      else empty end;
  [try input catch empty | parse] as $head
  | if ($head[0].type? == "session_meta") and (($head[0].payload // {}) | person_in_worktree | not) then stop($not_a_session) else . end
  | ($head + [inputs | parse]) as $records
  | if $records == [] then stop($no_records) else . end
  | [$records[] | select(.type == "session_meta")][0] as $meta
  | if $meta == null or (($meta.payload // {}) | person_in_worktree | not) then stop($not_a_session) else . end
  | [$records[] | event] | corrections
'

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Set HARNESS and WORKTREE from the command line. Exit 2 on bad usage.
parse_args() {
    HARNESS=''
    WORKTREE=''
    while [ $# -gt 0 ]; do
        case "$1" in
            --harness=*) HARNESS=${1#*=}; shift ;;
            --worktree=*) WORKTREE=${1#*=}; shift ;;
            --harness) [ $# -ge 2 ] || bad_usage; HARNESS=$2; shift 2 ;;
            --worktree) [ $# -ge 2 ] || bad_usage; WORKTREE=$2; shift 2 ;;
            *) bad_usage ;;
        esac
    done
    case "$HARNESS" in
        claude-code|codex) ;;
        *) bad_usage ;;
    esac
    [ -n "$WORKTREE" ] || bad_usage
}

# Print the usage and exit 2.
bad_usage() {
    usage
    exit 2
}

# Print the path with "~" expanded, made absolute, and without a trailing slash.
absolute_path() {
    case "$1" in
        "~") set -- "$HOME" ;;
        "~/"*) set -- "$HOME/${1#"~/"}" ;;
    esac
    case "$1" in
        /*) ;;
        *) set -- "$PWD/$1" ;;
    esac
    if [ -d "$1" ]; then
        (CDPATH='' cd -- "$1" && pwd)
    else
        printf '%s\n' "$1" | sed 's#//*$##; s#^$#/#'
    fi
}

# Print the session files of every Claude Code project folder that can hold the worktree or a directory inside it.
claude_code_files() {
    home=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
    prefix=$(jq -rn --arg path "$WORKTREE" '$path | sub("/+$"; "") | gsub("[^a-zA-Z0-9]"; "-") | .[:200]')
    for folder in "$home/projects/$prefix"*; do
        for path in "$folder"/*.jsonl; do
            if [ -f "$path" ]; then
                printf '%s\n' "$path"
            fi
        done
    done
}

# Print every rollout file under the Codex home. The worktree is checked per file.
codex_files() {
    home=${CODEX_HOME:-$HOME/.codex}
    for subdir in sessions archived_sessions; do
        if [ -d "$home/$subdir" ]; then
            find "$home/$subdir" -type f -name 'rollout-*' \( -name '*.jsonl' -o -name '*.jsonl.zst' \) | sort
        fi
    done
}

# Run the filter of the harness on stdin, with the session name as $session.
filter_transcript() {
    jq -cnR --arg worktree "$WORKTREE" --arg session "$1" \
        --argjson not_a_session "$NOT_A_SESSION" --argjson no_records "$NO_RECORDS" "$COMMON$FILTER"
}

# Run the filter on one plain or zstd-compressed transcript file.
run_filter() {
    case "$1" in
        *.zst) zstd -dcq -- "$1" 2>/dev/null | filter_transcript "$2" ;;
        *) filter_transcript "$2" < "$1" ;;
    esac
}

# Print "skipped <file>: <reason>" to stderr.
skipped() {
    printf 'skipped %s: %s\n' "$1" "$2" >&2
}

# Print the corrections of one transcript file, and count it when it is a session of the worktree.
read_session() {
    name=$(basename "$1")
    if [ ! -r "$1" ]; then
        skipped "$name" "cannot be read"
        return
    fi
    case "$name" in
        *.zst) if ! command -v zstd >/dev/null; then skipped "$name" "zstd is not installed"; return; fi ;;
    esac
    run_filter "$1" "${name%%.*}"
    case $? in
        0) SESSIONS=$((SESSIONS + 1)) ;;
        "$NOT_A_SESSION") ;;
        "$NO_RECORDS") skipped "$name" "no JSON records" ;;
        *) skipped "$name" "cannot be parsed" ;;
    esac
}

# Read every transcript file of the harness. Exit 1 when no session of the worktree was read.
extract() {
    SESSIONS=0
    while IFS= read -r path; do
        if [ -n "$path" ]; then
            read_session "$path"
        fi
    done <<EOF
$1
EOF
    if [ "$SESSIONS" -eq 0 ]; then
        printf 'no chat data: no %s session found for %s\n' "$HARNESS" "$WORKTREE" >&2
        exit 1
    fi
}

parse_args "$@"
WORKTREE=$(absolute_path "$WORKTREE")
case "$HARNESS" in
    claude-code) FILTER=$CLAUDE_CODE_FILTER; extract "$(claude_code_files)" ;;
    codex) FILTER=$CODEX_FILTER; extract "$(codex_files)" ;;
esac
