#!/usr/bin/env python3
"""Release the claim and set the stage to done for each issue a merged PR closes.

Usage: python3 .sdlc/scripts/on_merge.py <pr>

Run by .github/workflows/sdlc-on-merge.yml when a PR is merged, and by ship
when that workflow is not installed. Calls the sibling scripts claim.py and
stage.py. A claim that is already gone is skipped, so a second run is safe.
Exit code 0 when every issue was updated or there was nothing to do.
Exit code 1 when the PR is not merged or a step failed.
"""

import json
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
CLAIM_REF = "refs/sdlc/claims/{issue}"


def run_command(cmd):
    """Run a command and return the CompletedProcess. Never raises on a non-zero exit."""
    return subprocess.run(cmd, capture_output=True, text=True)


def merged_pr_issues(pr, run):
    """Return the issue numbers that the merged PR closes. Raise RuntimeError when it is not merged."""
    result = run(["gh", "pr", "view", str(pr), "--json", "state,closingIssuesReferences"])
    if result.returncode != 0:
        raise RuntimeError(f"cannot read PR #{pr}: {result.stderr.strip()}")
    pr_data = json.loads(result.stdout)
    if pr_data["state"] != "MERGED":
        raise RuntimeError(f"PR #{pr} is {pr_data['state']}, not MERGED")
    return [issue["number"] for issue in pr_data["closingIssuesReferences"]]


def claim_exists(issue, run):
    """Return True when the claim ref of the issue exists on origin."""
    ref = CLAIM_REF.format(issue=issue)
    return bool(run(["git", "ls-remote", "origin", ref]).stdout.strip())


def script(name, *args):
    """Return the command that runs a sibling script."""
    return [sys.executable, str(SCRIPTS / name), *map(str, args)]


def finish_issue(issue, run):
    """Release the claim and set done for one issue. Return the list of errors."""
    steps = [script("stage.py", issue, "done")]
    if claim_exists(issue, run):
        steps.insert(0, script("claim.py", "--release", issue))
    errors = []
    for step in steps:
        result = run(step)
        if result.returncode != 0:
            errors.append(f"#{issue}: {Path(step[1]).name} failed: {(result.stdout + result.stderr).strip()}")
    return errors


def main(argv, run=run_command):
    """Finish every issue that the merged PR closes. Return the exit code."""
    if len(argv) != 1 or not argv[0].isdigit():
        print(__doc__.strip())
        return 1
    try:
        issues = merged_pr_issues(argv[0], run)
    except RuntimeError as error:
        print(error)
        return 1
    if not issues:
        print(f"PR #{argv[0]} closes no issue. Nothing to do.")
        return 0
    errors = [error for issue in issues for error in finish_issue(issue, run)]
    for error in errors:
        print(error)
    if not errors:
        print(f"Released the claims and set done on {', '.join(f'#{i}' for i in issues)}.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
