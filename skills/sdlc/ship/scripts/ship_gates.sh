#!/bin/sh
# Check the merge gates of a pull request.
#
# Usage: ship_gates.sh <pr>
#
# Run it from the repository root, on a checkout of the PR head.
# Prints one line per gate: approval, checks, threads, qa.
# Exit code 0 when every gate passes, 1 when any gate fails or the arguments are bad.
#
# - approval: a person (not a bot, not the PR author) approved, nobody asks
#   for changes, and GitHub's review decision is not blocking.
# - checks: no check failed, was cancelled or is still pending.
# - threads: every unresolved review thread ends with a reply from the PR author.
# - qa: local HEAD is the PR head, and qa_check.sh passes for the task folder
#   of the issue the PR closes. When the task folder was removed on the branch,
#   the check runs on the last commit that still had it, and every later change
#   must be inside the task folder. A PR that closes no issue is XS work: its
#   evidence is the untracked QA.md in `git rev-parse --git-path sdlc/qa`.
#
# Reads task.path from .sdlc/settings.json and needs jq.

set -u
exec 3>&1

HERE=$(cd "$(dirname "$0")" && pwd)
SETTINGS=.sdlc/settings.json
DEFAULT_TASK_PATH=.sdlc/task
TAB=$(printf '\t')
FAILED=0

PR_QUERY='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      headRefOid
      reviewDecision
      author { login }
      closingIssuesReferences(first: 10) { nodes { number } }
      latestOpinionatedReviews(first: 100) { nodes { state author { __typename login } } }
      reviewThreads(first: 100) {
        nodes { isResolved comments(last: 1) { nodes { url author { login } } } }
      }
    }
  }
}'

APPROVAL='
  .author.login as $author
  | .latestOpinionatedReviews.nodes as $reviews
  | [$reviews[] | select(.state == "APPROVED" and .author.__typename == "User" and .author.login != $author)
     | .author.login] as $approvers
  | [$reviews[] | select(.state == "CHANGES_REQUESTED") | .author.login // "ghost"] as $blockers
  | if ($blockers | length) > 0 then "fail\tchanges requested by \($blockers | join(", "))"
    elif ($approvers | length) == 0 then "fail\tno approval from a person"
    elif .reviewDecision == "CHANGES_REQUESTED" or .reviewDecision == "REVIEW_REQUIRED"
      then "fail\tGitHub review decision is \(.reviewDecision)"
    else "pass\tapproved by \($approvers | join(", "))" end'

CHECKS='
  [.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] as $failed
  | [.[] | select(.bucket == "pending") | .name] as $pending
  | if ($failed | length) > 0 then "fail\tfailed: \($failed | join(", "))"
    elif ($pending | length) > 0 then "fail\tpending: \($pending | join(", "))"
    else "pass\t\(length) green" end'

THREADS='
  .author.login as $author
  | [.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[-1]
     | select(.author.login != $author) | .url] as $unanswered
  | if ($unanswered | length) > 0 then "fail\t\($unanswered | length) unanswered: \($unanswered | join(" "))"
    else "pass\tno unanswered thread" end'

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print "ship_gates failed: <reason>" to stdout, also from a command substitution, and exit 1.
fail() {
    printf 'ship_gates failed: %s\n' "$1" >&3
    exit 1
}

# Print a verdict: "pass" or "fail", a tab, and the detail.
verdict() {
    printf '%s\t%s\n' "$1" "$2"
}

# Print the gate line for the verdict, and remember a failed gate.
report() {
    result=${2%%"$TAB"*}
    printf '%s: %s - %s\n' "$1" "$result" "${2#*"$TAB"}"
    [ "$result" = pass ] || FAILED=1
}

# Print task.path from the settings file, or the default when it is not set.
read_task_path() {
    path=$(jq -r '.task.path // empty' "$SETTINGS" 2>/dev/null) || fail "cannot read $SETTINGS"
    printf '%s\n' "${path:-$DEFAULT_TASK_PATH}"
}

# Print the pullRequest object of the GraphQL query for the PR.
fetch_pr() {
    err=$(gh api graphql -f query="$PR_QUERY" -F owner='{owner}' -F name='{repo}' -F number="$1" \
        --jq '.data.repository.pullRequest' 2>&1 >&4) || fail "cannot read PR #$1: $err"
} 4>&1

# Print the value of the jq filter on the JSON text.
field() {
    printf '%s\n' "$1" | jq -r "$2"
}

# Print the verdict of the gate that needs green checks.
checks_gate() {
    output=$(gh pr checks "$1" --json name,bucket 2>&1)
    case "$output" in
        *'no checks reported'*) verdict pass 'no checks reported' ;;
        '['*) field "$output" "$CHECKS" ;;
        *) verdict fail "cannot read checks: $output" ;;
    esac
}

# Print the verdict of the gate that needs QA evidence for the head commit.
qa_gate() {
    head=$(field "$1" .headRefOid)
    local_head=$(git rev-parse HEAD 2>/dev/null)
    issue=$(field "$1" '.closingIssuesReferences.nodes[0].number // empty')
    if [ "$local_head" != "$head" ]; then
        verdict fail "local HEAD $local_head is not the PR head $head"
    elif [ -z "$issue" ]; then
        run_qa_check "$(git rev-parse --git-path sdlc/qa)"
    elif git cat-file -e "HEAD:${2%/}/$issue/QA.md" 2>/dev/null; then
        run_qa_check "${2%/}/$issue"
    else
        qa_before_removal "${2%/}/$issue"
    fi
}

# Print the verdict of qa_check.sh for the task folder, in the current directory.
run_qa_check() {
    if output=$(sh "$HERE/qa_check.sh" "$1" 2>&1); then
        verdict pass "$output"
    else
        verdict fail "$output"
    fi
}

# Print the verdict of the QA check on the last commit that had the task folder, when HEAD only removed it.
qa_before_removal() {
    removal=$(git log -1 --format=%H --diff-filter=D HEAD -- "$1/QA.md" 2>/dev/null)
    if [ -z "$removal" ]; then
        verdict fail "$1/QA.md does not exist; run prove first"
        return
    fi
    outside=$(changed_outside "$removal^" "$1")
    if [ -n "$outside" ]; then
        verdict fail "QA.md was removed and later commits change $(first_five "$outside")"
        return
    fi
    qa_check_in_worktree "$1" "$removal^"
}

# Print the files changed between the commit and HEAD that are outside the task folder.
changed_outside() {
    git diff --name-only "$1" HEAD | while IFS= read -r path; do
        case "$path" in
            "$2"/*) ;;
            *) printf '%s\n' "$path" ;;
        esac
    done
}

# Print the first five lines of the list joined by ", ".
first_five() {
    printf '%s\n' "$1" | awk 'NR <= 5 { printf "%s%s", (NR > 1 ? ", " : ""), $0 }'
}

# Print the verdict of qa_check.sh for the task folder in a temporary worktree at the commit.
qa_check_in_worktree() {
    tmp=$(mktemp -d)
    if ! err=$(git worktree add --detach "$tmp/tree" "$2" 2>&1); then
        rm -rf "$tmp"
        verdict fail "cannot check out $2: $err"
        return
    fi
    result=$(cd "$tmp/tree" && run_qa_check "$1")
    git worktree remove --force "$tmp/tree" >/dev/null 2>&1
    rm -rf "$tmp"
    printf '%s\n' "$result"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
case "$1" in
    '' | *[!0-9]*) usage; exit 1 ;;
esac
task_path=$(read_task_path) || exit 1
pr=$(fetch_pr "$1") || exit 1
report approval "$(field "$pr" "$APPROVAL")"
report checks "$(checks_gate "$1")"
report threads "$(field "$pr" "$THREADS")"
report qa "$(qa_gate "$pr" "$task_path")"
exit "$FAILED"
