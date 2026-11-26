# Helpers for the script tests. run.sh sources this file in each test's temp directory.

export TEST_TMP="$PWD"
export PATH="$TEST_TMP/bin:$PATH"
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/gh"
: > "$TEST_TMP/gh.log"

cat > "$TEST_TMP/bin/gh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" | tr '\n' ' ' >> "$TEST_TMP/gh.log"
echo >> "$TEST_TMP/gh.log"
rule="$TEST_TMP/gh/$1_$2"
calls=$(($(cat "$rule.calls" 2>/dev/null || echo 0) + 1))
echo "$calls" > "$rule.calls"
if [ ! -f "$rule.code" ]; then
    echo "unexpected command: gh $*" >&2
    exit 99
fi
code=$(cat "$rule.code")
if [ "$code" -ne 0 ]; then
    echo "fake error" >&2
    exit "$code"
fi
filter=''
while [ $# -gt 0 ]; do
    if [ "$1" = --jq ]; then
        filter=$2
    fi
    shift
done
out="$rule.out"
if [ -f "$rule.$calls.out" ]; then
    out="$rule.$calls.out"
fi
if [ -n "$filter" ]; then
    jq -r "$filter" "$out"
else
    cat "$out"
fi
FAKE
chmod +x "$TEST_TMP/bin/gh"

# Make the fake gh answer "gh <command> <subcommand> ..." with the exit code and stdout.
fake_gh() {
    printf '%s\n' "$2" > "$TEST_TMP/gh/$(echo "$1" | tr ' ' _).code"
    printf '%s\n' "${3:-}" > "$TEST_TMP/gh/$(echo "$1" | tr ' ' _).out"
}

# Make the fake gh answer the nth call of "gh <command> <subcommand> ..." with exit code 0 and the nth stdout.
fake_gh_sequence() {
    rule="$TEST_TMP/gh/$(echo "$1" | tr ' ' _)"
    shift
    echo 0 > "$rule.code"
    n=0
    for out in "$@"; do
        n=$((n + 1))
        printf '%s\n' "$out" > "$rule.$n.out"
    done
}

# Print the nth logged gh call.
gh_call() {
    sed -n "$1p" "$TEST_TMP/gh.log"
}

# Print the logged gh calls whose arguments start with the prefix.
gh_calls() {
    grep -- "^$1" "$TEST_TMP/gh.log"
}

# Fail the test when the two values differ.
assert_eq() {
    if [ "$1" != "$2" ]; then
        printf 'expected: %s\n     got: %s\n' "$2" "$1"
        exit 1
    fi
}

# Fail the test when the text does not contain the part.
assert_contains() {
    case "$1" in
        *"$2"*) ;;
        *) printf 'expected to contain: %s\n                got: %s\n' "$2" "$1"; exit 1 ;;
    esac
}
