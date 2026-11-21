#!/bin/sh
# Create the missing SDLC stage and size labels on the GitHub repository.
#
# Usage: labels.sh [--dry-run]
#
# Run it from inside the repository. It never edits or deletes an existing label,
# and it compares names without case. With --dry-run, it prints the labels that
# it would create and creates nothing. Exit code 0 on success, 1 when gh fails.

set -u
. "$(dirname "$0")/label_lib.sh"

# Print the catalog lines whose names are not among the existing names, compared without case.
missing_labels() {
    printf '%s\n%s\n' "$STAGE_LABELS" "$SIZE_LABELS" | while IFS='|' read -r name color text; do
        if ! printf '%s\n' "$1" | grep -qixF -- "$name"; then
            printf '%s|%s|%s\n' "$name" "$color" "$text"
        fi
    done
}

# Create each missing label and print its name. With --dry-run, only print.
create_missing() {
    printf '%s\n' "$1" | while IFS='|' read -r name color text; do
        if [ "$2" = --dry-run ]; then
            printf 'would create %s\n' "$name"
        else
            gh label create "$name" --color "$color" --description "$text" >/dev/null || fail "gh label create $name failed"
            printf 'created %s\n' "$name"
        fi
    done
}

existing=$(gh label list --limit 1000 --json name --jq '.[].name') || fail "gh label list failed"
missing=$(missing_labels "$existing")
if [ -z "$missing" ]; then
    echo "all stage and size labels exist"
    exit 0
fi
create_missing "$missing" "${1:-}" || exit 1
