#!/bin/sh
# Set the one size label of an issue.
#
# Usage: size.sh <issue> <XS|S|M|L|XL>
#
# Adds the label size:<size> and removes every other size label from the issue.
# Exit code 0 on success, 2 on bad arguments, 1 when gh fails.

set -u
. "$(dirname "$0")/label_lib.sh"

if [ $# -ne 2 ] || ! in_list "size:$2" "$(label_names "$SIZE_LABELS")"; then
    usage
    exit 2
fi
set_exclusive_label "$1" "size:$2" "$SIZE_LABELS"
printf '#%s size: %s\n' "$1" "$2"
