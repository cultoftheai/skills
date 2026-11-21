# Label catalog and helpers shared by labels.sh, stage.sh and size.sh.
# Source this file. Do not run it.

STAGE_LABELS='ready|0E8A16|The what is agreed. Anyone can pick it up.
shaped|1D76DB|The how is agreed.
in-progress|FBCA04|Code is being written.
review|5319E7|A pull request is open.
done|0B6E2E|Merged and closed.
blocked|B60205|Cannot move. The reason is on the issue.'

SIZE_LABELS='size:XS|EDEDED|One obvious edit. Nothing to plan.
size:S|C2E0C6|One outcome, one module, one PR.
size:M|FEF2C0|One outcome in two or three tasks.
size:L|F9D0C4|Tasks share a decision. Needs a design.
size:XL|D93F0B|More than one outcome. An epic.'

# Print the usage comment at the top of the running script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print "error: <message>" to stderr and exit 1.
fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

# Print the label names of a catalog, one per line.
label_names() {
    printf '%s\n' "$1" | cut -d'|' -f1
}

# Exit 0 when the first argument is a whole line of the second.
in_list() {
    printf '%s\n' "$2" | grep -qxF -- "$1"
}

# Print the labels of the issue that are in the family and are not the label, joined by commas.
other_family_labels() {
    current=$(gh issue view "$1" --json labels --jq '.labels[].name') || return 1
    printf '%s\n' "$current" | while IFS= read -r name; do
        if [ "$name" != "$2" ] && in_list "$name" "$3"; then
            printf '%s,' "$name"
        fi
    done
}

# Add the label to the issue and remove every other label of the same catalog from it.
set_exclusive_label() {
    others=$(other_family_labels "$1" "$2" "$(label_names "$3")") || fail "gh issue view $1 failed"
    if [ -n "$others" ]; then
        gh issue edit "$1" --add-label "$2" --remove-label "${others%,}" >/dev/null || fail "gh issue edit $1 failed"
    else
        gh issue edit "$1" --add-label "$2" >/dev/null || fail "gh issue edit $1 failed"
    fi
}
