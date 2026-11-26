#!/bin/sh
# Run every test_* function in tests/test_*.sh, each in its own subshell and temp directory.
#
# Usage: tests/run.sh
#
# Set SH to run the scripts under another shell, for example SH=dash.
# Prints one line per failed test and a summary. Exit code 0 when all pass, 1 when any fails.

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
export SCRIPTS="$(dirname "$TESTS_DIR")/scripts"
export SH="${SH:-sh}"
total=0
failed=0

# Run one test function of one test file. Print its output when it fails.
run_test() {
    tmp=$(mktemp -d)
    output=$( (cd "$tmp" && . "$TESTS_DIR/helpers.sh" && . "$1" && "$2") 2>&1 )
    status=$?
    rm -rf "$tmp"
    if [ "$status" -ne 0 ]; then
        printf 'FAIL %s %s\n%s\n' "$(basename "$1")" "$2" "$output"
        return 1
    fi
}

for file in "$TESTS_DIR"/test_*.sh; do
    for name in $(sed -n 's/^\(test_[a-z0-9_]*\)() {$/\1/p' "$file"); do
        total=$((total + 1))
        run_test "$file" "$name" || failed=$((failed + 1))
    done
done
printf '%s tests, %s failed\n' "$total" "$failed"
[ "$failed" -eq 0 ]
