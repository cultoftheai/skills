#!/bin/sh
# Set the stage to done for each issue a merged PR closes, or shaped for a merged Spec/Design PR.
# For a merged Code PR that changes more than specs, also open one cleanup PR sdlc/<issue>-cleanup
# per closed issue against its base branch. It applies specs.on_ship to the task spec and removes
# the task folder when task.keep is false.
#
# Usage: on_merge.sh <pr>
#
# Run from the repository root by .github/workflows/sdlc-on-merge.yml when a PR is merged, and
# by ship when that workflow is not installed. Calls the sibling script stage.sh and makes the
# cleanup commit in a temporary git worktree, so a second run is safe. The cleanup is skipped
# without .sdlc/settings.json, when nothing matches on the base branch, or when the cleanup PR
# is already open.
# Exit code 0 when every issue was updated or there was nothing to do.
# Exit code 1 when the PR is not merged, a step failed or the arguments are bad.

set -u
exec 3>&1

HERE=$(dirname "$0")
SETTINGS=.sdlc/settings.json
WORKTREE=''

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print the message to stdout, also from a command substitution, and exit 1.
fail() {
    printf '%s\n' "$1" >&3
    exit 1
}

# Print the PR state, base branch, space-separated closed issues, and space-separated Spec/Design issues, one per line.
pr_summary() {
    err=$(gh pr view "$1" --json state,closingIssuesReferences,body,baseRefName \
        --jq '.state,
              .baseRefName,
              ([(.closingIssuesReferences // [])[].number | tostring] | join(" ")),
              ([((.body // "") | scan("\\b(?:Spec|Design)\\s+for\\s+#(\\d+)\\b"; "i"))[0]]
                | reduce .[] as $id ([]; if index($id) then . else . + [$id] end) | join(" "))' 2>&1 >&4) || fail "cannot read PR #$1: $err"
} 4>&1

# Set stage on the issue. Print the error and exit 1 when stage.sh fails.
set_stage() {
    output=$(sh "$HERE/stage.sh" "$1" "$2" 2>&1) || {
        printf '#%s: stage.sh failed: %s\n' "$1" "$output"
        return 1
    }
}

# Print the issue numbers of the list as "#7, #8".
issue_list() {
    printf '%s\n' $1 | awk '{ printf "%s#%s", (NR > 1 ? ", " : ""), $0 } END { print "" }'
}

# Print the setting at the jq path, or the fallback when it is null or missing.
setting() {
    value=$(jq -r "$1 | if . == null then empty else tostring end" "$SETTINGS" 2>/dev/null)
    printf '%s\n' "${value:-$2}"
}

# Print the path without a leading ./ or a trailing /.
trim_path() {
    path=$1
    while [ "${path#./}" != "$path" ]; do
        path=${path#./}
    done
    while [ "${path%/}" != "$path" ]; do
        path=${path%/}
    done
    printf '%s\n' "$path"
}

# Read specs.path, specs.archive_path, specs.on_ship, task.path and task.keep into SPECS, ARCHIVE, ON_SHIP, TASKS and KEEP.
read_settings() {
    jq -e . "$SETTINGS" >/dev/null 2>&1 || fail "cannot read $SETTINGS"
    SPECS=$(trim_path "$(setting .specs.path .sdlc/specs)")
    ARCHIVE=$(trim_path "$(setting .specs.archive_path .sdlc/specs/archived)")
    ON_SHIP=$(setting .specs.on_ship archive)
    TASKS=$(trim_path "$(setting .task.path .sdlc/task)")
    KEEP=$(setting .task.keep true)
}

# Run git with the arguments, quietly. Print the error and exit 1 when it fails.
run_git() {
    err=$(git "$@" 2>&1 >/dev/null) || fail "git $1 failed: $err"
}

# Print the task specs (on archive or delete) and the task folder (when task.keep is false) of the issue on origin/<base>.
cleanup_paths() {
    case "$ON_SHIP" in
        archive | delete) task_specs "$1" "$2" ;;
    esac
    if [ "$KEEP" = false ] && [ -n "$(git ls-tree --name-only "origin/$1" -- "$TASKS/$2")" ]; then
        printf '%s\n' "$TASKS/$2"
    fi
}

# Print the changed files of the PR, one per line.
pr_files() {
    err=$(gh pr view "$1" --json files --jq '(.files // [])[].path' 2>&1 >&4) || fail "cannot read files of PR #$1: $err"
} 4>&1

# Succeed when the PR changes at least one file and only files under <specs.path>/.
specs_only() {
    files=$(pr_files "$1") || exit 1
    [ -n "$files" ] || return 1
    while IFS= read -r file; do
        case "$file" in
            "$SPECS"/*) ;;
            *) return 1 ;;
        esac
    done <<FILES
$files
FILES
}

# Print the files <specs.path>/<issue>-*.md on origin/<base>, without *-design.md.
task_specs() {
    git ls-tree --name-only "origin/$1" -- "$SPECS/" | while IFS= read -r path; do
        case "${path##*/}" in
            "$2"-*-design.md) ;;
            "$2"-*.md) printf '%s\n' "$path" ;;
        esac
    done
}

# Print the number of the open cleanup PR from the branch into the base branch, if any.
open_cleanup_pr() {
    err=$(gh pr list --head "$1" --base "$2" --state open --json number --jq '.[0].number // empty' 2>&1 >&4) \
        || fail "cannot list cleanup PRs: $err"
} 4>&1

# Remove the temporary worktree, if one was made.
remove_worktree() {
    [ -n "$WORKTREE" ] || return 0
    git worktree remove --force "$WORKTREE" >/dev/null 2>&1
    rm -rf "$(dirname "$WORKTREE")"
}

# Move or remove each path in the worktree and commit the change with the trailer SDLC-Spec-Archive: true.
commit_cleanup() {
    while IFS= read -r path; do
        case "$path" in
            "$TASKS"/*) run_git -C "$WORKTREE" rm -rq -- "$path" ;;
            *) remove_spec "$path" ;;
        esac
    done <<PATHS
$2
PATHS
    run_git -C "$WORKTREE" commit -q -m "Clean up spec for #$1" -m "SDLC-Spec-Archive: true"
}

# Move the spec to <specs.archive_path>/ on archive, or remove it on delete.
remove_spec() {
    if [ "$ON_SHIP" = archive ]; then
        mkdir -p "$WORKTREE/$ARCHIVE"
        run_git -C "$WORKTREE" mv -- "$1" "$ARCHIVE/"
    else
        run_git -C "$WORKTREE" rm -q -- "$1"
    fi
}

# Open the cleanup PR for the issue from the branch into the base branch and print its URL.
create_cleanup_pr() {
    err=$(gh pr create --base "$3" --head "$2" --title "Clean up spec for #$4" \
        --body "Cleanup for PR #$1: applies specs.on_ship ($ON_SHIP) and task.keep ($KEEP) to #$4 after the merge." 2>&1 >&4) \
        || fail "cannot open cleanup PR for #$4: $err"
} 4>&1

# Open a cleanup PR per closed issue for the merged PR into the base branch, unless there is nothing to do.
clean_up() {
    if [ "$ON_SHIP" != archive ] && [ "$ON_SHIP" != delete ] && [ "$KEEP" != false ]; then
        printf 'Nothing to clean up.\n'
        return
    fi
    if specs_only "$1"; then
        printf 'Only specs changed. Nothing to clean up.\n'
        return
    fi
    run_git fetch -q origin "+refs/heads/$2:refs/remotes/origin/$2"
    for issue in $3; do
        clean_up_issue "$1" "$2" "$issue"
    done
}

# Open the cleanup PR sdlc/<issue>-cleanup for the issue, unless nothing matches or it is already open.
clean_up_issue() {
    paths=$(cleanup_paths "$2" "$3")
    if [ -z "$paths" ]; then
        printf 'Nothing to clean up for #%s.\n' "$3"
        return
    fi
    branch="sdlc/$3-cleanup"
    open=$(open_cleanup_pr "$branch" "$2") || exit 1
    if [ -n "$open" ]; then
        printf 'Cleanup PR #%s for #%s is already open.\n' "$open" "$3"
        return
    fi
    WORKTREE=$(mktemp -d)/worktree
    run_git worktree add -q --detach "$WORKTREE" "origin/$2"
    commit_cleanup "$3" "$paths"
    run_git -C "$WORKTREE" push -q --force origin "HEAD:refs/heads/$branch"
    url=$(create_cleanup_pr "$1" "$branch" "$2" "$3") || exit 1
    remove_worktree
    WORKTREE=''
    printf 'Opened cleanup PR %s for #%s.\n' "$url" "$3"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
case "$1" in
    '' | *[!0-9]*) usage; exit 1 ;;
esac
summary=$(pr_summary "$1") || exit 1
{
    IFS= read -r state
    IFS= read -r base
    IFS= read -r issues
    IFS= read -r spec_issues
} <<EOF
$summary
EOF
[ "$state" = MERGED ] || fail "PR #$1 is $state, not MERGED"
if [ -n "$issues" ]; then
    stage=done
    targets=$issues
elif [ -n "$spec_issues" ]; then
    stage=shaped
    targets=$spec_issues
else
    printf 'PR #%s closes no issue. Nothing to do.\n' "$1"
    exit 0
fi
failed=0
for issue in $targets; do
    set_stage "$issue" "$stage" || failed=1
done
[ "$failed" -eq 0 ] || exit 1
printf 'Set %s on %s.\n' "$stage" "$(issue_list "$targets")"
[ "$stage" = done ] && [ -f "$SETTINGS" ] || exit 0
read_settings
trap remove_worktree EXIT
clean_up "$1" "$base" "$issues"
