#!/bin/sh
# Check that the newest QA run in a work folder is a pass for the head commit.
#
# Usage: qa_check.sh <work-dir>
#
# Reads <work-dir>/self-qa.md (falling back to <work-dir>/QA.md when only the
# legacy file exists). The newest run is the first "## Run" section.
# Exit code 0 when that run is a pass and its commit is HEAD. The run also
# counts for HEAD when it is an ancestor of HEAD and every commit after it
# changes only files inside <work-dir> or <specs.path>/, or carries the Git
# trailer "SDLC-Docs-Only: true" or "SDLC-Spec-Archive: true".
# Prints "QA check passed: pass recorded for <commit>", or "QA check failed:
# <reason>" and exits 1. Exit code 1 also on bad arguments.

set -u
exec 3>&1

DOCS_ONLY_TRAILER=SDLC-Docs-Only
SPEC_ARCHIVE_TRAILER=SDLC-Spec-Archive
SETTINGS=.sdlc/settings.json
DEFAULT_SPECS_PATH=.sdlc/specs

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

# Print the work folder relative to the repository root with a trailing slash, or nothing when it is outside the repository.
task_prefix() {
    root=$(run_git rev-parse --show-toplevel) || exit 1
    root=$(cd "$root" && pwd -P) || exit 1
    folder=$(cd "$TASK_DIR" && pwd -P) || exit 1
    case "$folder" in
        "$root") echo ./ ;;
        "$root"/*) printf '%s/\n' "${folder#"$root"/}" ;;
    esac
}

# Print specs.path from .sdlc/settings.json (or the default) with leading "./" removed and a trailing slash.
specs_prefix() {
    path=''
    if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
        path=$(jq -r '.specs.path // empty' "$SETTINGS" 2>/dev/null)
    fi
    path=${path:-$DEFAULT_SPECS_PATH}
    while [ "${path#./}" != "$path" ]; do
        path=${path#./}
    done
    while [ "${path%/}" != "$path" ] && [ "$path" != / ]; do
        path=${path%/}
    done
    printf '%s/\n' "$path"
}

# Print paths from the list that do not start with the non-empty work prefix or the specs prefix.
outside() {
    printf '%s\n' "$1" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        if [ -n "$2" ] && [ "${path#"$2"}" != "$path" ]; then
            continue
        fi
        if [ -n "$3" ] && [ "${path#"$3"}" != "$path" ]; then
            continue
        fi
        printf '%s\n' "$path"
    done
}

# Exit 0 when one of the whitespace-separated values is "true", in any case.
has_true() {
    lower "$1" | tr -s '[:space:]' '\n' | grep -qx true
}

# Print the files that one commit changes outside the work and specs folders, or nothing when it carries a non-code trailer.
commit_stale_files() {
    trailers=$(run_git log -1 "--format=%(trailers:key=$DOCS_ONLY_TRAILER,key=$SPEC_ARCHIVE_TRAILER,valueonly)" "$1") || exit 1
    if has_true "$trailers"; then
        return 0
    fi
    changed=$(run_git diff --name-only "$1^1" "$1") || exit 1
    outside "$changed" "$2" "$3"
}

# Print the files that make the evidence stale, sorted and unique: files outside the work and specs folders changed by later commits without a non-code trailer.
stale_changes() {
    later=$(run_git rev-list "$1..$2") || exit 1
    files=''
    for sha in $later; do
        files="$files
$(commit_stale_files "$sha" "$3" "$4")" || exit 1
    done
    printf '%s\n' "$files" | sed '/^$/d' | LC_ALL=C sort -u
}

# Print the first five lines of the list joined by ", ".
first_five() {
    printf '%s\n' "$1" | awk 'NR <= 5 { printf "%s%s", (NR > 1 ? ", " : ""), $0 }'
}

# Fail unless the run commit is HEAD, or every later commit is non-code or changes only the work or specs folder.
check_commit() {
    tested=$(resolve "$1") || exit 1
    head=$(run_git rev-parse HEAD) || exit 1
    if [ "$tested" = "$head" ]; then
        return 0
    fi
    base=$(run_git merge-base "$tested" "$head") || exit 1
    [ "$base" = "$tested" ] || fail "the newest run is for $1, which is not an ancestor of HEAD $head"
    prefix=$(task_prefix) || exit 1
    specs=$(specs_prefix)
    stale=$(stale_changes "$tested" "$head" "$prefix" "$specs") || exit 1
    [ -z "$stale" ] || fail "the newest run is for $1, but HEAD $head also changes $(first_five "$stale")"
}

# Fail unless the newest run in self-qa.md (or legacy QA.md) is a pass for HEAD. Print the tested commit.
check() {
    qa_file="${TASK_DIR%/}/self-qa.md"
    if [ ! -f "$qa_file" ] && [ -f "${TASK_DIR%/}/QA.md" ]; then
        qa_file="${TASK_DIR%/}/QA.md"
    fi
    [ -f "$qa_file" ] || fail "${TASK_DIR%/}/self-qa.md does not exist; run prove --local first"
    run=$(newest_run "$qa_file") || fail "$(basename "$qa_file") has no '## Run' section"
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
