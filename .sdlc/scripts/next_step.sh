#!/bin/sh
# Print the Next: line, the full command to run after a skill or for an issue.
#
# Usage: next_step.sh <issue-or-pr|-> [--after <skill>] [--result pass|fail] [--keep <open items>] [--auto] [--harness claude-code|codex]
#
# - <issue-or-pr> is an issue or PR number. "-" means no issue: XS work, a
#   first run after setup, or a repo retro.
# - With --after, the after_<skill> function maps the skill that just ran and
#   its result (default pass) to the next command. Where the result alone
#   cannot decide, the script reads the issue or PR with gh.
# - Without --after, the script reads where the issue or PR stands (size,
#   stage, PR state, review threads) and names the skill that comes next.
#   With "-", it names the next ready task.
# - With --after in Claude Code, a Context: line comes before the Next: line.
#   It advises to clear, compact or keep the session context, from the skill
#   that ran and its result. Without settings it advises clear before setup. A compact names the issue, the branch and the
#   open items that --keep gives.
# - --auto adds --auto to the printed command.
# - --harness picks the command form. Default: the SDLC_HARNESS environment
#   variable, else detected from the environment, else claude-code.
#
# When no skill can run yet, the line says what it waits for or what a person
# must do, then the command to run after that. Without .sdlc/settings.json the
# line is "Next: /sdlc:setup" in Claude Code. It runs ready.sh and
# ship_gates.sh from its own directory, and reads JSON with jq.
#
# Exit code 0 when it printed a Next: line, 2 on bad arguments, 1 when gh or
# a helper script fails (it still prints a Next: line).

set -u

HERE=$(dirname "$0")
SETTINGS=.sdlc/settings.json
SKILLS='setup frame slice shape build prove submit review respond document ship retro'
TAB=$(printf '\t')
EDIT='"<the edit in words>"'
FIRST_REQUEST='"<your first request>"'
NEXT_REQUEST='"<your next request>"'
ITEM_QUERY='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issueOrPullRequest(number: $number) {
      __typename
      ... on Issue {
        number state
        labels(first: 50) { nodes { name } }
        parent { number }
        subIssues(first: 50) { nodes { number state labels(first: 50) { nodes { name } } } }
        closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number state } }
      }
      ... on PullRequest {
        number state body
        author { login }
        closingIssuesReferences(first: 10) { nodes { number } }
        reviews(first: 100) { nodes { state author { __typename login } } }
        reviewRequests(first: 20) { nodes { requestedReviewer { __typename ... on User { login } } } }
        reviewThreads(first: 100) { nodes { isResolved comments(last: 1) { nodes { author { login } } } } }
      }
    }
  }
}'
JQ_DEFS='
  def label_names: [(.labels.nodes // [])[].name];
  def stage: first(label_names[] | select(IN("ready", "shaped", "in-progress", "review", "done", "blocked"))) // null;
  def size: first(label_names[] | select(startswith("size:")) | ltrimstr("size:")) // null;
  def open_subs: [(.subIssues.nodes // []) | sort_by(.number)[] | select(.state == "OPEN" and stage != "done")];
  def open_pr: first((.closedByPullRequestsReferences.nodes // [])[] | select(.state == "OPEN") | .number) // null;
  def keyword_issue: (.body // "") | first(match("\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\\s+#(\\d+)"; "i") | .captures[0].string | tonumber);
  def closing_issue: (.closingIssuesReferences.nodes // [])[0].number // keyword_issue // null;
  def author: .author.login // null;
  def threads_needing_reply: author as $a | [(.reviewThreads.nodes // [])[] | select((.isResolved | not) and (.comments.nodes | last | .author.login) != $a)];
  def reviews: .reviews.nodes // [];
  def has_human_approval: author as $a | any(reviews[]; .state == "APPROVED" and .author.__typename == "User" and .author.login != $a);
  def requested_reviewers: [(.reviewRequests.nodes // [])[] | .requestedReviewer // {} | select(.__typename == "User") | .login];
'

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print the usage and exit 2.
bad_arguments() {
    usage
    exit 2
}

# Keep the message as the error and exit 1.
fail() {
    printf '%s\n' "$1" > "$ERROR_FILE"
    exit 1
}

# Keep the stderr of the failed command as the error, or the message when it is empty, and exit 1.
fail_command() {
    [ -s "$ERROR_FILE" ] || printf '%s\n' "$1" > "$ERROR_FILE"
    exit 1
}

# Exit 0 when the first argument is one of the words in the second.
one_of() {
    printf '%s\n' $2 | grep -qxF -- "$1"
}

# Exit 0 when the text starts with the prefix.
starts_with() {
    case "$1" in
        "$2"*) return 0 ;;
    esac
    return 1
}

# Print the value of a jq expression on the item JSON, with the definitions above. Prints nothing for null.
get() {
    printf '%s\n' "$1" | jq -r "$JQ_DEFS ($2) // empty"
}

# Exit 0 when a jq expression on the item JSON is true.
holds() {
    printf '%s\n' "$1" | jq -e "$JQ_DEFS $2" > /dev/null
}

# Print a step that runs a skill with its arguments.
skill() {
    printf '%s\n' "$*"
}

# Print a step that waits for the reason, then takes the step.
wait_then() {
    case "$2" in
        *"$TAB"*) printf '%s, then run %s\n' "$1" "$2" ;;
        *) printf '%s%s%s\n' "$1" "$TAB" "$2" ;;
    esac
}

# Print a step as a person types it, with the harness prefix and --auto.
render() {
    case "$1" in
        *"$TAB"*) printf '%s, then run %s%s%s\n' "${1%%"$TAB"*}" "$PREFIX" "${1#*"$TAB"}" "$AUTO" ;;
        *) printf '%s%s%s\n' "$PREFIX" "$1" "$AUTO" ;;
    esac
}

# Print the issue or pull request with this number as JSON.
item() {
    found=$(gh api graphql -f "query=$ITEM_QUERY" -F 'owner={owner}' -F 'name={repo}' -F "number=$1" \
        --jq '.data.repository.issueOrPullRequest' 2> "$ERROR_FILE") || fail_command "gh api graphql failed"
    if [ -z "$found" ] || [ "$found" = null ]; then
        fail "#$1 is not an issue or a pull request"
    fi
    printf '%s\n' "$found"
}

# Print the numbers that ready.sh lists, in its order.
ready_numbers() {
    listed=$(sh "$HERE/ready.sh" 2> "$ERROR_FILE") || fail_command "sh .sdlc/scripts/ready.sh failed"
    printf '%s\n' "$listed" | sed -n 's/^#\([0-9][0-9]*\).*/\1/p'
}

# Exit 0 when the gate failed in the ship_gates.sh output.
gate_failed() {
    printf '%s\n' "$1" | grep -q "^$2: fail - "
}

# Print the detail of a failed gate in the ship_gates.sh output.
gate_detail() {
    printf '%s\n' "$1" | sed -n "s/^$2: fail - //p" | tail -n 1
}

# Print the next step for an issue or a pull request number.
route() {
    found=$(item "$1") || exit 1
    if [ "$(get "$found" .__typename)" = PullRequest ]; then
        route_pr "$found"
    else
        route_issue "$found"
    fi
}

# Print the next step for an issue, from its size, stage, sub-issues and PR.
route_issue() {
    issue_number=$(get "$1" .number)
    current=$(get "$1" stage)
    if [ "$(get "$1" .state)" != OPEN ] || [ "$current" = done ]; then
        next_ready "$issue_number"
    elif [ "$current" = blocked ]; then
        wait_then "wait until a person unblocks #$issue_number" "next $issue_number"
    elif [ "$(get "$1" size)" = XL ]; then
        route_epic "$1"
    elif [ -z "$current" ]; then
        skill frame "$issue_number"
    else
        route_stage "$1" "$current"
    fi
}

# Print the next step for an issue that has a stage label.
route_stage() {
    issue_number=$(get "$1" .number)
    issue_size=$(get "$1" size)
    first_sub=$(get "$1" 'open_subs[0].number')
    open_pull=$(get "$1" open_pr)
    if [ "$2" = ready ] && [ -n "$first_sub" ]; then
        route "$first_sub"
    elif [ "$2" = ready ] && [ "$issue_size" = M ]; then
        skill slice "$issue_number"
    elif [ "$2" = ready ]; then
        skill shape "$issue_number"
    elif [ "$2" = shaped ] && [ "$issue_size" = L ]; then
        skill slice "$issue_number"
    elif [ "$2" = shaped ]; then
        skill build "$issue_number"
    elif [ -n "$open_pull" ]; then
        route "$open_pull"
    elif [ "$2" = in-progress ]; then
        skill build "$issue_number"
    else
        skill submit "$issue_number"
    fi
}

# Print the next step for an XL epic: frame the next story, or route the first open one.
route_epic() {
    unframed=$(get "$1" 'first(open_subs[] | select(size == null and stage == null) | .number)')
    first_sub=$(get "$1" 'open_subs[0].number')
    if [ -n "$unframed" ]; then
        skill frame "$unframed"
    elif [ -n "$first_sub" ]; then
        route "$first_sub"
    else
        next_ready "$(get "$1" .number)"
    fi
}

# Print the next step for a pull request, from its state, reviews and threads.
route_pr() {
    pr_number=$(get "$1" .number)
    task=$(get "$1" closing_issue)
    pr_state=$(get "$1" .state)
    if [ "$pr_state" = MERGED ]; then
        next_ready
    elif [ "$pr_state" = CLOSED ]; then
        wait_then "reopen PR #$pr_number or open a new one" "next ${task:-$pr_number}"
    elif holds "$1" 'threads_needing_reply | length > 0'; then
        skill respond "$pr_number"
    elif holds "$1" 'reviews | length == 0'; then
        skill review "$pr_number"
    elif holds "$1" has_human_approval; then
        skill ship "$pr_number"
    elif holds "$1" 'requested_reviewers | length > 0'; then
        wait_for_review "$1"
    else
        document_or_ship "$1"
    fi
}

# Print the step for the first ready task other than the skipped number, or frame a new request when none is ready.
next_ready() {
    numbers=$(ready_numbers) || exit 1
    first=$(printf '%s\n' "$numbers" | grep -vxF -- "${1:-}" | head -n 1)
    if [ -z "$first" ]; then
        skill frame "$NEXT_REQUEST"
    else
        route "$first"
    fi
}

# Print the wait for the people asked to review the pull request.
wait_for_review() {
    logins=$(get "$1" 'requested_reviewers | map("@" + .) | join(", ")')
    pr_number=$(get "$1" .number)
    wait_then "wait for review from $logins on PR #$pr_number" "next $pr_number"
}

# Print document for the task that the pull request closes, or ship for XS work.
document_or_ship() {
    task=$(get "$1" closing_issue)
    if [ -n "$task" ]; then
        skill document "$task"
    else
        skill ship "$(get "$1" .number)"
    fi
}

# Exit 0 when the issue is ready and its parent is an L story.
under_l_story() {
    parent=$(get "$1" .parent.number)
    [ "$(get "$1" stage)" = ready ] && [ -n "$parent" ] || return 1
    parent_item=$(item "$parent") || exit 1
    [ "$(get "$parent_item" size)" = L ]
}

# setup: frame the first request.
after_setup() {
    skill frame "$FIRST_REQUEST"
}

# frame: XS goes to build; a stop needs criteria; an issue is routed by its size and stage.
after_frame() {
    if [ -n "$FAILED" ]; then
        wait_then "add the facts that the acceptance criteria need to the request" "frame ${REF:-\"<the request>\"}"
    elif [ -z "$REF" ]; then
        skill build "$EDIT"
    else
        route "$REF"
    fi
}

# slice: route the task or the re-sized story; a stop names the missing design or approval.
after_slice() {
    if [ -z "$FAILED" ]; then
        route "$REF"
        return
    fi
    story=$(item "$REF") || exit 1
    if [ "$(get "$story" size)" = L ] && [ "$(get "$story" stage)" = ready ]; then
        skill shape "$REF"
    else
        wait_then "get story #$REF approved and labelled ready" "slice $REF"
    fi
}

# shape: a spec goes to build and a design to slice; a stop re-frames the L story or routes the issue.
after_shape() {
    issue=$(item "$REF") || exit 1
    if [ -z "$FAILED" ] && [ "$(get "$issue" size)" = L ]; then
        skill slice "$REF"
    elif [ -z "$FAILED" ]; then
        skill build "$REF"
    elif under_l_story "$issue"; then
        skill frame "$(get "$issue" .parent.number)"
    else
        route_issue "$issue"
    fi
}

# build: prove the change; a stop re-sizes through frame or names what blocks the build.
after_build() {
    if [ -z "$FAILED" ]; then
        skill prove ${REF:+"$REF"}
        return
    fi
    if [ -z "$REF" ]; then
        skill frame "$EDIT"
        return
    fi
    issue=$(item "$REF") || exit 1
    case "$(get "$issue" stage)" in
        in-progress) skill frame "$(get "$issue" ".parent.number // $REF")" ;;
        shaped) wait_then "check out the branch of #$REF with its spec" "build $REF" ;;
        *) route_issue "$issue" ;;
    esac
}

# prove: a pass goes to submit, a fail back to build.
after_prove() {
    if [ -n "$FAILED" ]; then
        skill build "${REF:-$EDIT}"
    else
        skill submit ${REF:+"$REF"}
    fi
}

# submit: review the new PR; a stop means no QA evidence for the head, so prove again.
after_submit() {
    if [ -n "$FAILED" ]; then
        skill prove ${REF:+"$REF"}
    else
        skill review ${REF:+"$REF"}
    fi
}

# review: findings go to respond, a clean PR to document; a spec with findings goes back to its author.
after_review() {
    reviewed=$(item "$REF") || exit 1
    if [ "$(get "$reviewed" .__typename)" = Issue ]; then
        step=$(route_issue "$reviewed") || exit 1
        if [ -n "$FAILED" ]; then
            wait_then "apply the review findings to the spec or design of #$REF" "$step"
        else
            printf '%s\n' "$step"
        fi
    elif [ -n "$FAILED" ]; then
        skill respond "$REF"
    else
        document_or_ship "$reviewed"
    fi
}

# respond: retry unanswered threads, wait for a requested person, or review again.
after_respond() {
    pull=$(item "$REF") || exit 1
    if holds "$pull" 'threads_needing_reply | length > 0'; then
        skill respond "$REF"
    elif holds "$pull" 'requested_reviewers | length > 0'; then
        wait_for_review "$pull"
    else
        skill review "$REF"
    fi
}

# document: ship the PR.
after_document() {
    skill ship ${REF:+"$REF"}
}

# ship: a merge goes to retro; a failed gate names who clears it.
after_ship() {
    pull=$(item "$REF") || exit 1
    task=$(get "$pull" closing_issue)
    if [ -n "$FAILED" ]; then
        gate_step "$pull" "$(sh "$HERE/ship_gates.sh" "$REF" 2> /dev/null)"
    elif [ -n "$task" ]; then
        skill retro "$task"
    else
        next_ready
    fi
}

# Print the step that clears the first failed gate in the ship_gates.sh output, or ship again when none failed.
gate_step() {
    pr_number=$(get "$1" .number)
    task=$(get "$1" closing_issue)
    qa=$(gate_detail "$2" qa)
    checks=$(gate_detail "$2" checks)
    if gate_failed "$2" threads; then
        skill respond "$pr_number"
    elif gate_failed "$2" qa && starts_with "$qa" "local HEAD"; then
        wait_then "check out the head of PR #$pr_number" "ship $pr_number"
    elif gate_failed "$2" qa; then
        skill prove ${task:+"$task"}
    elif gate_failed "$2" checks && starts_with "$checks" failed; then
        wait_then "fix the failed checks on PR #$pr_number ($checks)" "ship $pr_number"
    elif gate_failed "$2" approval; then
        wait_then "wait for a person to approve PR #$pr_number ($(gate_detail "$2" approval))" "ship $pr_number"
    elif gate_failed "$2" checks; then
        wait_then "wait for CI on PR #$pr_number ($checks)" "ship $pr_number"
    else
        skill ship "$pr_number"
    fi
}

# retro: the next ready task.
after_retro() {
    next_ready
}

# Print the Context: line for the skill that just ran: clear, compact or keep the session context.
context_line() {
    if [ ! -f "$SETTINGS" ]; then
        printf 'Context: clear - setup needs nothing from this session. Run /clear before the next command.\n'
        return
    fi
    case "$AFTER:$FAILED" in
        prove:1) printf 'Context: compact - the next step continues this work. Run /compact%s\n' "$(keep_list)" ;;
        prove: | document:* | frame:1) printf 'Context: keep - the next step follows on directly.\n' ;;
        *) printf 'Context: clear - the next step starts from the issue, the task folder or the PR. Run /clear before the next command.\n' ;;
    esac
}

# Print what a compaction keeps: the issue, the branch and the open items, each when known.
keep_list() {
    branch=$(git branch --show-current 2> /dev/null)
    list=${REF:+"issue #$REF"}
    [ -z "$branch" ] || list="${list:+$list, }branch $branch"
    [ -z "$OPEN_ITEMS" ] || list="${list:+$list, }open items: $(printf '%s' "$OPEN_ITEMS" | tr -s '\n' ' ')"
    printf '%s' "${list:+ Keep $list}"
}

# Print the harness: SDLC_HARNESS, else claude-code when CLAUDECODE is set, else codex when a CODEX_ variable is set.
detect_harness() {
    if one_of "${SDLC_HARNESS:-}" 'claude-code codex'; then
        printf '%s\n' "$SDLC_HARNESS"
    elif [ -n "${CLAUDECODE:-}" ]; then
        echo claude-code
    elif env | grep -q '^CODEX_'; then
        echo codex
    else
        echo claude-code
    fi
}

# Set RAW_REF, AFTER, FAILED, OPEN_ITEMS, AUTO and HARNESS from the command line. Exit 2 on bad arguments.
parse_args() {
    RAW_REF='' AFTER='' FAILED='' OPEN_ITEMS='' AUTO='' HARNESS=''
    while [ $# -gt 0 ]; do
        case "$1" in
            --after) [ $# -ge 2 ] && one_of "$2" "$SKILLS" || bad_arguments; AFTER=$2; shift ;;
            --result) [ $# -ge 2 ] && one_of "$2" 'pass fail' || bad_arguments; [ "$2" = pass ] || FAILED=1; shift ;;
            --keep) [ $# -ge 2 ] || bad_arguments; OPEN_ITEMS=$2; shift ;;
            --harness) [ $# -ge 2 ] && one_of "$2" 'claude-code codex' || bad_arguments; HARNESS=$2; shift ;;
            --auto) AUTO=' --auto' ;;
            -?*) bad_arguments ;;
            *) [ -z "$RAW_REF" ] || bad_arguments; RAW_REF=$1 ;;
        esac
        shift
    done
}

# Set REF from RAW_REF: the number without "#", or empty for "-". Exit 2 when it is neither.
parse_ref() {
    REF=${RAW_REF#\#}
    case "$RAW_REF" in
        -) REF='' ;;
        '' | '#' | *[!0-9#]* | ?*#*) bad_arguments ;;
        *) REF=$(expr "$REF" + 0) ;;
    esac
}

# Print the next step for the parsed arguments.
decide() {
    if [ -n "$AFTER" ]; then
        "after_$AFTER"
    elif [ -n "$REF" ]; then
        route "$REF"
    else
        next_ready
    fi
}

parse_args "$@"
parse_ref
HARNESS=${HARNESS:-$(detect_harness)}
case "$HARNESS" in
    codex) PREFIX='$' ;;
    *) PREFIX='/sdlc:' ;;
esac
if [ -n "$AFTER" ] && [ "$HARNESS" = claude-code ]; then
    context_line
fi
if [ ! -f "$SETTINGS" ]; then
    printf 'Next: %s\n' "$(render setup)"
    exit 0
fi
ERROR_FILE=$(mktemp)
trap 'rm -f "$ERROR_FILE"' EXIT
if step=$(decide); then
    printf 'Next: %s\n' "$(render "$step")"
    exit 0
fi
error=$(cat "$ERROR_FILE")
printf 'error: %s\n' "$error" >&2
printf 'Next: %s\n' "$(render "fix this error ($error)$TAB""next $RAW_REF")"
exit 1
