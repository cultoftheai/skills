#!/usr/bin/env python3
"""Check the merge gates of a pull request.

Usage: python3 .sdlc/scripts/ship_gates.py <pr>

Run it from the repository root, on a checkout of the PR head.
Prints one line per gate: approval, checks, threads, qa.
Exit code 0 when every gate passes, 1 when any gate fails.

- approval: a person (not a bot, not the PR author) approved, nobody asks
  for changes, and GitHub's review decision is not blocking.
- checks: no check failed, was cancelled or is still pending.
- threads: every unresolved review thread ends with a reply from the PR author.
- qa: local HEAD is the PR head, and qa_check.py passes for the task folder
  of the issue the PR closes. When the task folder was removed on the branch,
  the check runs on the last commit that still had it, and every later change
  must be inside the task folder. A PR that closes no issue is XS work: its
  evidence is the untracked QA.md in `git rev-parse --git-path sdlc/qa`.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

SETTINGS = Path(".sdlc/settings.json")
DEFAULT_TASK_PATH = ".sdlc/task"
QA_CHECK = Path(__file__).resolve().parent / "qa_check.py"
PR_QUERY = """
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
}
"""


def run_command(cmd, cwd=None):
    """Run a command and return the CompletedProcess. Never raises on a non-zero exit."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def read_task_path(settings_file=SETTINGS):
    """Return task.path from the settings file, or the default when it is not set."""
    settings = json.loads(settings_file.read_text())
    return settings.get("task", {}).get("path") or DEFAULT_TASK_PATH


def fetch_pr(pr, run):
    """Return the pullRequest object of the GraphQL query for the PR."""
    result = run([
        "gh", "api", "graphql", "-f", f"query={PR_QUERY}",
        "-F", "owner={owner}", "-F", "name={repo}", "-F", f"number={pr}",
    ])
    if result.returncode != 0:
        raise RuntimeError(f"cannot read PR #{pr}: {result.stderr.strip()}")
    return json.loads(result.stdout)["data"]["repository"]["pullRequest"]


def approval_gate(pr_data):
    """Return (passed, detail) for the gate that needs a person's approval."""
    pr_author = pr_data["author"]["login"]
    reviews = pr_data["latestOpinionatedReviews"]["nodes"]
    approvers = [r["author"]["login"] for r in reviews if is_human_approval(r, pr_author)]
    blockers = [r["author"]["login"] for r in reviews if r["state"] == "CHANGES_REQUESTED"]
    decision = pr_data.get("reviewDecision")
    if blockers:
        return False, f"changes requested by {', '.join(blockers)}"
    if not approvers:
        return False, "no approval from a person"
    if decision in ("CHANGES_REQUESTED", "REVIEW_REQUIRED"):
        return False, f"GitHub review decision is {decision}"
    return True, f"approved by {', '.join(approvers)}"


def is_human_approval(review, pr_author):
    """Return True when the review is an approval by a person other than the PR author."""
    author = review["author"] or {}
    return (
        review["state"] == "APPROVED"
        and author.get("__typename") == "User"
        and author.get("login") != pr_author
    )


def checks_gate(pr, run):
    """Return (passed, detail) for the gate that needs green checks."""
    result = run(["gh", "pr", "checks", str(pr), "--json", "name,bucket"])
    if "no checks reported" in result.stderr:
        return True, "no checks reported"
    if not result.stdout.strip():
        return False, f"cannot read checks: {result.stderr.strip()}"
    checks = json.loads(result.stdout)
    failed = [c["name"] for c in checks if c["bucket"] in ("fail", "cancel")]
    pending = [c["name"] for c in checks if c["bucket"] == "pending"]
    if failed:
        return False, f"failed: {', '.join(failed)}"
    if pending:
        return False, f"pending: {', '.join(pending)}"
    return True, f"{len(checks)} green"


def threads_gate(pr_data):
    """Return (passed, detail) for the gate that needs every review thread answered."""
    pr_author = pr_data["author"]["login"]
    unanswered = [
        last_comment(thread)["url"]
        for thread in pr_data["reviewThreads"]["nodes"]
        if not thread["isResolved"] and last_author(thread) != pr_author
    ]
    if unanswered:
        return False, f"{len(unanswered)} unanswered: {' '.join(unanswered)}"
    return True, "no unanswered thread"


def last_comment(thread):
    """Return the newest comment of a review thread."""
    return thread["comments"]["nodes"][-1]


def last_author(thread):
    """Return the login of the newest comment's author, or None for a deleted account."""
    return (last_comment(thread)["author"] or {}).get("login")


def qa_gate(pr_data, task_path, run):
    """Return (passed, detail) for the gate that needs QA evidence for the head commit."""
    head = pr_data["headRefOid"]
    local = run(["git", "rev-parse", "HEAD"]).stdout.strip()
    if local != head:
        return False, f"local HEAD {local} is not the PR head {head}"
    issues = pr_data["closingIssuesReferences"]["nodes"]
    if not issues:
        return run_qa_check(xs_qa_dir(run), None, run)
    task_dir = f"{task_path.rstrip('/')}/{issues[0]['number']}"
    if exists_at_head(f"{task_dir}/QA.md", run):
        return run_qa_check(task_dir, None, run)
    return qa_before_removal(task_dir, run)


def xs_qa_dir(run):
    """Return the folder that holds the QA.md of XS work, inside the git directory."""
    return run(["git", "rev-parse", "--git-path", "sdlc/qa"]).stdout.strip()


def exists_at_head(path, run):
    """Return True when the file is part of the HEAD commit."""
    return run(["git", "cat-file", "-e", f"HEAD:{path}"]).returncode == 0


def qa_before_removal(task_dir, run):
    """Check QA on the last commit that had the task folder, when HEAD only removed it."""
    removal = run(["git", "log", "-1", "--format=%H", "--diff-filter=D", "HEAD", "--", f"{task_dir}/QA.md"])
    removal_commit = removal.stdout.strip()
    if not removal_commit:
        return False, f"{task_dir}/QA.md does not exist; run prove first"
    before = f"{removal_commit}^"
    outside = changed_outside(before, task_dir, run)
    if outside:
        return False, f"QA.md was removed and later commits change {', '.join(outside[:5])}"
    return qa_check_in_worktree(task_dir, before, run)


def changed_outside(commit, task_dir, run):
    """Return the files changed between commit and HEAD that are outside the task folder."""
    changed = run(["git", "diff", "--name-only", commit, "HEAD"]).stdout.splitlines()
    return [path for path in changed if not path.startswith(f"{task_dir}/")]


def qa_check_in_worktree(task_dir, commit, run):
    """Run qa_check.py in a temporary worktree at the given commit."""
    with tempfile.TemporaryDirectory() as tmp:
        tree = str(Path(tmp) / "tree")
        added = run(["git", "worktree", "add", "--detach", tree, commit])
        if added.returncode != 0:
            return False, f"cannot check out {commit}: {added.stderr.strip()}"
        try:
            return run_qa_check(task_dir, tree, run)
        finally:
            run(["git", "worktree", "remove", "--force", tree])


def run_qa_check(task_dir, cwd, run):
    """Return (passed, detail) from qa_check.py for the task folder."""
    result = run([sys.executable, str(QA_CHECK), task_dir], cwd=cwd)
    return result.returncode == 0, (result.stdout.strip() or result.stderr.strip())


def gates(pr, task_path, run):
    """Return the list of (name, passed, detail) for every gate of the PR."""
    pr_data = fetch_pr(pr, run)
    return [
        ("approval", *approval_gate(pr_data)),
        ("checks", *checks_gate(pr, run)),
        ("threads", *threads_gate(pr_data)),
        ("qa", *qa_gate(pr_data, task_path, run)),
    ]


def main(argv, run=run_command, task_path=None):
    """Print one line per gate and return 0 when all pass, 1 otherwise."""
    if len(argv) != 1 or not argv[0].isdigit():
        print(__doc__.strip())
        return 1
    try:
        results = gates(argv[0], task_path or read_task_path(), run)
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print(f"ship_gates failed: {error}")
        return 1
    for name, passed, detail in results:
        print(f"{name}: {'pass' if passed else 'fail'} - {detail}")
    return 0 if all(passed for _, passed, _ in results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
