#!/bin/sh
# Set the stage to done for each issue a merged PR closes.
#
# Usage: on_merge.sh <pr>
#
# Run by .github/workflows/sdlc-on-merge.yml when a PR is merged, and by ship
# when that workflow is not installed. Calls the sibling script stage.sh, so a
# second run is safe.
# Exit code 0 when every issue was updated or there was nothing to do.
# Exit code 1 when the PR is not merged, a step failed or the arguments are bad.

set -u
exec 3>&1

HERE=$(dirname "$0")

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print the message to stdout, also from a command substitution, and exit 1.
fail() {
    printf '%s\n' "$1" >&3
    exit 1
}

# Print the state of the PR, then the number of each issue it closes, one per line.
pr_summary() {
    err=$(gh pr view "$1" --json state,closingIssuesReferences \
        --jq '.state, .closingIssuesReferences[].number' 2>&1 >&4) || fail "cannot read PR #$1: $err"
} 4>&1

# Set done on the issue. Print the error and exit 1 when stage.sh fails.
finish_issue() {
    output=$(sh "$HERE/stage.sh" "$1" done 2>&1) || {
        printf '#%s: stage.sh failed: %s\n' "$1" "$output"
        return 1
    }
}

# Print the issue numbers of the list as "#7, #8".
issue_list() {
    printf '%s\n' "$1" | awk '{ printf "%s#%s", (NR > 1 ? ", " : ""), $0 } END { print "" }'
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
case "$1" in
    '' | *[!0-9]*) usage; exit 1 ;;
esac
summary=$(pr_summary "$1") || exit 1
state=$(printf '%s\n' "$summary" | head -n 1)
issues=$(printf '%s\n' "$summary" | tail -n +2)
[ "$state" = MERGED ] || fail "PR #$1 is $state, not MERGED"
if [ -z "$issues" ]; then
    printf 'PR #%s closes no issue. Nothing to do.\n' "$1"
    exit 0
fi
failed=0
for issue in $issues; do
    finish_issue "$issue" || failed=1
done
[ "$failed" -eq 0 ] || exit 1
printf 'Set done on %s.\n' "$(issue_list "$issues")"
