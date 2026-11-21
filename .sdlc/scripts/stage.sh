#!/bin/sh
# Set the one stage label of an issue.
#
# Usage: stage.sh <issue> <stage>
#
# stage is one of: ready, shaped, in-progress, review, done, blocked.
# Adds the stage label and removes every other stage label from the issue.
# Exit code 0 on success, 2 on bad arguments, 1 when gh fails.

set -u
. "$(dirname "$0")/label_lib.sh"

if [ $# -ne 2 ] || ! in_list "$2" "$(label_names "$STAGE_LABELS")"; then
    usage
    exit 2
fi
set_exclusive_label "$1" "$2" "$STAGE_LABELS"
printf '#%s stage: %s\n' "$1" "$2"
