#!/bin/sh
# List the approved task specs in the specs folder with their claim status.
#
# Usage: specs.sh
#
# Reads specs.path from .sdlc/settings.json (default .sdlc/specs), lists each
# top-level *.md file excluding *-design.md and subdirectories (such as
# archived/), and reports [PR #<n>], [branch <ref>], or [unclaimed].
# Exit code 0 on success, 1 when gh fails.

set -u

SETTINGS=.sdlc/settings.json

# Strip leading "./" and trailing "/" from a relative path.
trim_path() {
    path=$1
    while [ "${path#./}" != "$path" ]; do
        path=${path#./}
    done
    while [ "${path%/}" != "$path" ] && [ "$path" != / ]; do
        path=${path%/}
    done
    printf '%s\n' "$path"
}

# Print specs.path from .sdlc/settings.json, or the default .sdlc/specs.
read_specs_dir() {
    value=''
    if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
        value=$(jq -r '.specs.path // empty' "$SETTINGS" 2>/dev/null)
    fi
    trim_path "${value:-.sdlc/specs}"
}

# Print sorted "<sort-key>\t<id>\t<path>" lines for top-level task specs in $1.
list_spec_files() {
    [ -d "$1" ] || return 0
    for file in "$1"/*.md; do
        [ -f "$file" ] || continue
        base=$(basename "$file")
        case "$base" in
            *-design.md) continue ;;
        esac
        case "$base" in
            [0-9]*-*)
                id=${base%%-*}
                case "$id" in
                    *[!0-9]*) printf '1\t%s\t\t%s\n' "$base" "$file" ;;
                    *) printf '0\t%09d\t%s\t%s\n' "$id" "$id" "$file" ;;
                esac
                ;;
            *)
                printf '1\t%s\t\t%s\n' "$base" "$file"
                ;;
        esac
    done | LC_ALL=C sort
}

# Print the first open PR number claiming task $1, or nothing.
find_claiming_pr() {
    id=$1
    [ -n "$id" ] || return 0
    printf '%s\n' "$OPEN_PRS" | jq -r --arg id "$id" '
        ($id | tonumber) as $num
        | first(
            .[]
            | select(
                any((.closingIssuesReferences // [])[]; .number == $num)
                or ((.body // "") | test("\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\\s+#" + $id + "\\b"; "i"))
                or (((.headRefName // "") | test("^(?:spec|design)/") | not)
                    and ((.headRefName // "") | test("(^|/)" + $id + "-")))
            )
            | .number
        ) // empty'
}

# Print the first git branch claiming task $1 (ignoring spec/* and design/*), or nothing.
find_claiming_branch() {
    id=$1
    [ -n "$id" ] && [ -n "$BRANCHES" ] || return 0
    printf '%s\n' "$BRANCHES" | while IFS= read -r ref; do
        case "$ref" in
            */HEAD | HEAD) continue ;;
            spec/* | design/* | */spec/* | */design/*) continue ;;
            "$id"-* | */"$id"-*)
                printf '%s\n' "$ref"
                break
                ;;
        esac
    done
}

specs_dir=$(read_specs_dir)
specs=$(list_spec_files "$specs_dir")
[ -n "$specs" ] || exit 0

if ! OPEN_PRS=$(gh pr list --state open --limit 1000 --json number,headRefName,closingIssuesReferences,body); then
    echo "error: gh pr list failed" >&2
    exit 1
fi
BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null || true)

printf '%s\n' "$specs" | while IFS="$(printf '\t')" read -r _kind _sort id file; do
    pr=$(find_claiming_pr "$id")
    if [ -n "$pr" ]; then
        status="PR #$pr"
    else
        branch=$(find_claiming_branch "$id")
        if [ -n "$branch" ]; then
            status="branch $branch"
        else
            status=unclaimed
        fi
    fi
    if [ -n "$id" ]; then
        printf '#%s %s [%s]\n' "$id" "$file" "$status"
    else
        printf '%s [%s]\n' "$file" "$status"
    fi
done
