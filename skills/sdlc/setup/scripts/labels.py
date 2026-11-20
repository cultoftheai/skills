#!/usr/bin/env python3
"""Create the missing SDLC stage and size labels on the GitHub repository.

Usage: labels.py [--dry-run]

Run it from inside the repository. It never edits or deletes an existing label,
and it compares names without case. With --dry-run, it prints the labels that
it would create and creates nothing. Exit code 0 on success, 1 when gh fails.

stage.py and size.py import STAGE_LABELS, SIZE_LABELS and set_exclusive_label
from this file.
"""

import json
import subprocess
import sys

STAGE_LABELS = {
    "ready": ("0E8A16", "The what is agreed. Anyone can pick it up."),
    "shaped": ("1D76DB", "Claimed, and the how is agreed."),
    "in-progress": ("FBCA04", "Code is being written."),
    "review": ("5319E7", "A pull request is open."),
    "done": ("0B6E2E", "Merged and closed."),
    "blocked": ("B60205", "Cannot move. The reason is on the issue."),
}
SIZE_LABELS = {
    "size:XS": ("EDEDED", "One obvious edit. Nothing to plan."),
    "size:S": ("C2E0C6", "One outcome, one module, one PR."),
    "size:M": ("FEF2C0", "One outcome in two or three tasks."),
    "size:L": ("F9D0C4", "Tasks share a decision. Needs a design."),
    "size:XL": ("D93F0B", "More than one outcome. An epic."),
}


class CommandError(Exception):
    """A command that exited with a non-zero code."""


def run(args):
    """Run a command and return the completed process with text output."""
    return subprocess.run(args, capture_output=True, text=True)


def gh(args, runner):
    """Run gh with the arguments and return its stdout, or raise CommandError."""
    result = runner(["gh", *args])
    if result.returncode != 0:
        raise CommandError(result.stderr.strip() or f"gh {' '.join(args)} failed")
    return result.stdout


def existing_labels(runner):
    """Return the lowercase names of the labels on the repository."""
    labels = json.loads(gh(["label", "list", "--limit", "1000", "--json", "name"], runner))
    return {label["name"].lower() for label in labels}


def missing_labels(existing):
    """Return the stage and size labels whose names are not in existing, as (name, color, description)."""
    catalog = {**STAGE_LABELS, **SIZE_LABELS}
    return [(name, color, text) for name, (color, text) in catalog.items() if name.lower() not in existing]


def create_label(label, runner):
    """Create one label. gh fails rather than edit a label that exists."""
    name, color, description = label
    gh(["label", "create", name, "--color", color, "--description", description], runner)


def issue_labels(issue, runner):
    """Return the label names on an issue."""
    data = json.loads(gh(["issue", "view", str(issue), "--json", "labels"], runner))
    return [label["name"] for label in data["labels"]]


def set_exclusive_label(issue, label, family, runner):
    """Add label to the issue and remove every other label of the same family from it."""
    others = [name for name in issue_labels(issue, runner) if name in family and name != label]
    args = ["issue", "edit", str(issue), "--add-label", label]
    if others:
        args += ["--remove-label", ",".join(others)]
    gh(args, runner)


def create_missing(missing, dry_run, runner):
    """Create each missing label and print its name. With dry_run, only print."""
    for label in missing:
        if not dry_run:
            create_label(label, runner)
        print(f"{'would create' if dry_run else 'created'} {label[0]}")
    if not missing:
        print("all stage and size labels exist")


def main(argv=None, runner=run):
    """Create the missing labels, or list them with --dry-run."""
    args = sys.argv[1:] if argv is None else argv
    try:
        create_missing(missing_labels(existing_labels(runner)), "--dry-run" in args, runner)
    except CommandError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
