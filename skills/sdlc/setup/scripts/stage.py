#!/usr/bin/env python3
"""Set the one stage label of an issue.

Usage: stage.py <issue> <stage>

stage is one of: ready, shaped, in-progress, review, done, blocked.
Adds the stage label and removes every other stage label from the issue.
Exit code 0 on success, 2 on bad arguments, 1 when gh fails.
"""

import sys

from labels import STAGE_LABELS, CommandError, run, set_exclusive_label


def main(argv=None, runner=run):
    """Set the stage label named in argv on the issue named in argv."""
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2 or args[1] not in STAGE_LABELS:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    issue, stage = args
    try:
        set_exclusive_label(issue, stage, STAGE_LABELS, runner)
    except CommandError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"#{issue} stage: {stage}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
