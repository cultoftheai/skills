#!/bin/sh
# Check that the newest QA run in a task folder is a pass for the head commit.
#
# Usage: qa_check.sh <task-dir>
#
# Reads <task-dir>/QA.md. The newest run is the first "## Run" section.
# Exit code 0 when that run is a pass and its commit is HEAD. The run also
# counts for HEAD when it is an ancestor of HEAD and every commit after it
# either changes only files inside <task-dir>, for example the commit that
# adds QA.md itself, or carries the Git trailer "SDLC-Docs-Only: true".
# Prints "QA check passed: pass recorded for <commit>", or "QA check failed:
# <reason>" and exits 1. Exit code 1 also on bad arguments.

set -u
exec 3>&1

DOCS_ONLY_TRAILER=SDLC-Docs-Only

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print "QA check failed: <reason>" to stdout, also from a command substitution, and exit 1.
fail() {
    printf 'QA check failed: %s\n' "$1" >&3
    exit 1
}

# Run git with the arguments and print its stdout. Fail with git's stderr when git fails.
run_git() {
    if ! err=$(git "$@" 2>&1 >&4); then
        fail "git $* failed: $err"
    fi
} 4>&1

# Print the lines of the first "## Run" section of the file, up to the next level-2 heading. Exit 1 when there is none.
newest_run() {
    awk '
        found && /^## / { exit }
        found { print }
        /^## Run([^A-Za-z0-9_]|$)/ { found = 1 }
        END { exit !found }
    ' "$1"
}

# Print the value of the first "<name>: <value>" line of the run. Fail when there is none.
run_field() {
    value=$(printf '%s\n' "$2" | sed -n "s/^$1:[[:space:]]*\([^[:space:]]\{1,\}\)[[:space:]]*\$/\1/p" | head -n 1)
    [ -n "$value" ] || fail "the newest run has no '$1:' line"
    printf '%s\n' "$value"
}

# Print the text in lower case.
lower() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

# Print the full sha of the recorded commit. Fail when the repository does not have it.
resolve() {
    git rev-parse --verify --quiet "$1^{commit}" 2>/dev/null ||
        fail "the newest run names commit $1, which this repository does not have"
}

# Print the task folder relative to the repository root with a trailing slash, or nothing when it is outside the repository.
task_prefix() {
    root=$(run_git rev-parse --show-toplevel) || exit 1
    root=$(cd "$root" && pwd -P) || exit 1
    folder=$(cd "$TASK_DIR" && pwd -P) || exit 1
    case "$folder" in
        "$root") echo ./ ;;
        "$root"/*) printf '%s/\n' "${folder#"$root"/}" ;;
    esac
}

# Print the files of the list, one per line, that do not start with the prefix. An empty prefix keeps every file.
outside() {
    printf '%s\n' "$1" | while IFS= read -r path; do
        if [ -n "$path" ] && { [ -z "$2" ] || [ "${path#"$2"}" = "$path" ]; }; then
            printf '%s\n' "$path"
        fi
    done
}

# Exit 0 when one of the whitespace-separated values is "true", in any case.
has_true() {
    lower "$1" | tr -s '[:space:]' '\n' | grep -qx true
}

# Print the files that one commit changes outside the task folder, or nothing when it carries the docs-only trailer.
commit_stale_files() {
    trailers=$(run_git log -1 "--format=%(trailers:key=$DOCS_ONLY_TRAILER,valueonly)" "$1") || exit 1
    if has_true "$trailers"; then
        return 0
    fi
    changed=$(run_git diff --name-only "$1^1" "$1") || exit 1
    outside "$changed" "$2"
}

# Print the files that make the evidence stale, sorted and unique: files outside the task folder changed by later commits without the docs-only trailer.
stale_changes() {
    later=$(run_git rev-list "$1..$2") || exit 1
    files=''
    for sha in $later; do
        files="$files
$(commit_stale_files "$sha" "$3")" || exit 1
    done
    printf '%s\n' "$files" | sed '/^$/d' | LC_ALL=C sort -u
}

# Print the first five lines of the list joined by ", ".
first_five() {
    printf '%s\n' "$1" | awk 'NR <= 5 { printf "%s%s", (NR > 1 ? ", " : ""), $0 }'
}

# Fail unless the run commit is HEAD, or every later commit is docs-only or changes only the task folder.
check_commit() {
    tested=$(resolve "$1") || exit 1
    head=$(run_git rev-parse HEAD) || exit 1
    if [ "$tested" = "$head" ]; then
        return 0
    fi
    base=$(run_git merge-base "$tested" "$head") || exit 1
    [ "$base" = "$tested" ] || fail "the newest run is for $1, which is not an ancestor of HEAD $head"
    prefix=$(task_prefix) || exit 1
    stale=$(stale_changes "$tested" "$head" "$prefix") || exit 1
    [ -z "$stale" ] || fail "the newest run is for $1, but HEAD $head also changes $(first_five "$stale")"
}

# Fail unless the newest run in QA.md is a pass for HEAD. Print the tested commit.
check() {
    qa_file="${TASK_DIR%/}/QA.md"
    [ -f "$qa_file" ] || fail "$qa_file does not exist; run prove first"
    run=$(newest_run "$qa_file") || fail "QA.md has no '## Run' section"
    commit=$(run_field Commit "$run") || exit 1
    result=$(run_field Result "$run") || exit 1
    result=$(lower "$result")
    [ "$result" = pass ] || fail "the newest run for $commit is '$result', not 'pass'"
    check_commit "$commit"
    printf '%s\n' "$commit"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
TASK_DIR=$1
commit=$(check) || exit 1
printf 'QA check passed: pass recorded for %s\n' "$commit"
