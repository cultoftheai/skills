#!/usr/bin/env python3
"""Check that the newest QA run in a task folder is a pass for the head commit.

Usage: python3 .sdlc/scripts/qa_check.py <task-dir>

Reads <task-dir>/QA.md. The newest run is the first "## Run" section.
Exit code 0 when that run is a pass and its commit is HEAD. The run also
counts for HEAD when every commit after it changes only files inside
<task-dir>, for example the commit that adds QA.md itself.
Otherwise exit code 1, with the reason on stdout.
"""

import re
import subprocess
import sys
from pathlib import Path

RUN_HEADING = re.compile(r"^## Run\b.*$", re.M)
NEXT_HEADING = re.compile(r"^## ", re.M)
COMMIT_LINE = re.compile(r"^Commit:\s*(\S+)\s*$", re.M)
RESULT_LINE = re.compile(r"^Result:\s*(\S+)\s*$", re.M)


class QaError(Exception):
    """The QA evidence does not cover the head commit."""


def git(*args):
    """Run git with the given arguments and return its stripped stdout."""
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise QaError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def newest_run(text):
    """Return the text of the first "## Run" section, up to the next level-2 heading."""
    heading = RUN_HEADING.search(text)
    if not heading:
        raise QaError("QA.md has no '## Run' section")
    rest = text[heading.end():]
    end = NEXT_HEADING.search(rest)
    return rest[: end.start()] if end else rest


def field(pattern, run, name):
    """Return the value of one "Name: value" line of the run."""
    match = pattern.search(run)
    if not match:
        raise QaError(f"the newest run has no '{name}:' line")
    return match.group(1)


def read_run(task_dir):
    """Return the commit and result of the newest run in <task_dir>/QA.md."""
    qa_file = Path(task_dir) / "QA.md"
    if not qa_file.is_file():
        raise QaError(f"{qa_file} does not exist; run prove first")
    run = newest_run(qa_file.read_text())
    return field(COMMIT_LINE, run, "Commit"), field(RESULT_LINE, run, "Result").lower()


def task_prefix(task_dir, run):
    """Return the task folder relative to the repository root with a trailing slash, or None when it is outside the repository."""
    root = Path(run("rev-parse", "--show-toplevel")).resolve()
    folder = Path(task_dir).resolve()
    if folder != root and root not in folder.parents:
        return None
    return folder.relative_to(root).as_posix() + "/"


def changed_outside(commit, head, prefix, run):
    """Return the files changed between commit and head that are outside the task folder."""
    changed = run("diff", "--name-only", commit, head).splitlines()
    return [path for path in changed if prefix is None or not path.startswith(prefix)]


def resolve(commit, run):
    """Return the full sha of the recorded commit, or raise QaError when the repository does not have it."""
    try:
        return run("rev-parse", "--verify", "--quiet", f"{commit}^{{commit}}")
    except QaError:
        raise QaError(f"the newest run names commit {commit}, which this repository does not have") from None


def check_commit(commit, task_dir, run):
    """Raise QaError unless the run commit is HEAD or differs from HEAD only inside the task folder."""
    tested = resolve(commit, run)
    head = run("rev-parse", "HEAD")
    if tested == head:
        return
    if run("merge-base", tested, head) != tested:
        raise QaError(f"the newest run is for {commit}, which is not an ancestor of HEAD {head}")
    outside = changed_outside(tested, head, task_prefix(task_dir, run), run)
    if outside:
        raise QaError(f"the newest run is for {commit}, but HEAD {head} also changes {', '.join(outside[:5])}")


def check(task_dir, run=git):
    """Raise QaError unless the newest run in QA.md is a pass for HEAD. Return the tested commit."""
    commit, result = read_run(task_dir)
    if result != "pass":
        raise QaError(f"the newest run for {commit} is '{result}', not 'pass'")
    check_commit(commit, task_dir, run)
    return commit


def main(argv):
    """Check the task folder given as the only argument and print the outcome."""
    if len(argv) != 1:
        print(__doc__.strip())
        return 1
    try:
        commit = check(argv[0])
    except QaError as error:
        print(f"QA check failed: {error}")
        return 1
    print(f"QA check passed: pass recorded for {commit}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
