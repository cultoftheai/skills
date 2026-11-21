#!/bin/sh
# List the tasks that are ready to pick up.
#
# Usage: ready.sh
#
# Prints "#<number> <title>" for each open issue that has the ready label, no
# open blocker and no sub-issues, lowest number first. An issue with
# sub-issues is a story or an epic that is already split, so it is left out.
# A blocker counts as open unless gh reports it as closed.
# Exit code 0 on success, 1 when gh fails.

set -u

FIELDS=number,title,blockedBy,subIssuesSummary
FILTER='
  def open_blockers: [(.blockedBy.nodes // [])[] | select((.state // "OPEN") | ascii_upcase != "CLOSED")];
  map(select((open_blockers | length) == 0 and (.subIssuesSummary.total // 0) == 0))
  | sort_by(.number)[]
  | "#\(.number) \(.title)"'

if ! gh issue list --label ready --state open --limit 1000 --json "$FIELDS" --jq "$FILTER"; then
    echo "error: gh issue list failed" >&2
    exit 1
fi
