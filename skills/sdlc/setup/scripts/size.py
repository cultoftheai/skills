#!/usr/bin/env python3
"""Set the one size label of an issue.

Usage: size.py <issue> <XS|S|M|L|XL>

Adds the label size:<size> and removes every other size label from the issue.
Exit code 0 on success, 2 on bad arguments, 1 when gh fails.
"""

import sys

from labels import SIZE_LABELS, CommandError, run, set_exclusive_label


def main(argv=None, runner=run):
    """Set the size label named in argv on the issue named in argv."""
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2 or f"size:{args[1]}" not in SIZE_LABELS:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    issue, size = args
    try:
        set_exclusive_label(issue, f"size:{size}", SIZE_LABELS, runner)
    except CommandError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"#{issue} size: {size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
