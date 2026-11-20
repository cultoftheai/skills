#!/usr/bin/env python3
"""List the tasks that are ready to pick up.

Usage: ready.py

Prints "#<number> <title>" for each open issue that has the ready label, no
open blocker, no sub-issues and no claim, lowest number first. An issue with
sub-issues is a story or an epic that is already split, so it is left out.
A blocker counts as open unless gh reports it as closed.
Exit code 0 on success, 1 when gh or git fails.
"""

import json
import subprocess
import sys

REMOTE = "origin"
CLAIM_PREFIX = "refs/sdlc/claims/"
ISSUE_FIELDS = "number,title,blockedBy,subIssuesSummary"


class CommandError(Exception):
    """A command that exited with a non-zero code."""


def run(args):
    """Run a command and return the completed process with text output."""
    return subprocess.run(args, capture_output=True, text=True)


def output_of(args, runner):
    """Run a command and return its stdout, or raise CommandError."""
    result = runner(args)
    if result.returncode != 0:
        raise CommandError(result.stderr.strip() or f"{' '.join(args)} failed")
    return result.stdout


def ready_issues(runner):
    """Return the open issues with the ready label."""
    args = ["gh", "issue", "list", "--label", "ready", "--state", "open", "--limit", "1000", "--json", ISSUE_FIELDS]
    return json.loads(output_of(args, runner))


def claimed_issues(runner):
    """Return the issue numbers that have a claim ref on the remote."""
    output = output_of(["git", "ls-remote", REMOTE, f"{CLAIM_PREFIX}*"], runner)
    refs = [line.split()[1] for line in output.splitlines() if line.strip()]
    return {int(ref[len(CLAIM_PREFIX):]) for ref in refs if ref[len(CLAIM_PREFIX):].isdigit()}


def has_open_blocker(issue):
    """Return True when a blocker of the issue is not closed."""
    blockers = (issue.get("blockedBy") or {}).get("nodes", [])
    return any(str(blocker.get("state", "OPEN")).upper() != "CLOSED" for blocker in blockers)


def has_sub_issues(issue):
    """Return True when the issue has sub-issues."""
    return (issue.get("subIssuesSummary") or {}).get("total", 0) > 0


def pickable(issues, claimed):
    """Return the issues with no open blocker, no sub-issues and no claim, lowest number first."""
    free = [i for i in issues if not has_open_blocker(i) and not has_sub_issues(i) and i["number"] not in claimed]
    return sorted(free, key=lambda issue: issue["number"])


def main(argv=None, runner=run):
    """Print the tasks that are ready to pick up."""
    try:
        tasks = pickable(ready_issues(runner), claimed_issues(runner))
    except CommandError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    for task in tasks:
        print(f"#{task['number']} {task['title']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
