# Helpers for the script tests. run.sh sources this file in each test's temp directory.

export TEST_TMP="$PWD"
export PATH="$TEST_TMP/bin:$PATH"
export GATES="$TEST_TMP/scripts/ship_gates.sh"
export ON_MERGE="$TEST_TMP/scripts/on_merge.sh"
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/gh" "$TEST_TMP/scripts"
: > "$TEST_TMP/gh.log"
: > "$TEST_TMP/scripts.log"
cp "$SCRIPTS/ship_gates.sh" "$SCRIPTS/on_merge.sh" "$TEST_TMP/scripts/"

cat > "$TEST_TMP/bin/gh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" | tr '\n' ' ' >> "$TEST_TMP/gh.log"
echo >> "$TEST_TMP/gh.log"
key=$(printf '%s\n' "$1 ${2:-}" | LC_ALL=C sed 's/[^A-Za-z0-9]/_/g')
rule="$TEST_TMP/gh/$key"
if [ ! -f "$rule.code" ]; then
    echo "unexpected command: gh $*" >&2
    exit 99
fi
code=$(cat "$rule.code")
if [ "$code" -ne 0 ]; then
    cat "$rule.out" >&2
    exit "$code"
fi
filter=''
while [ $# -gt 0 ]; do
    if [ "$1" = --jq ]; then
        filter=$2
    fi
    shift
done
if [ -n "$filter" ]; then
    jq -r "$filter" "$rule.out"
else
    cat "$rule.out"
fi
FAKE
chmod +x "$TEST_TMP/bin/gh"

for name in qa_check.sh stage.sh; do
    cat > "$TEST_TMP/scripts/$name" <<'FAKE'
#!/bin/sh
name=$(basename "$0")
printf '%s %s %s\n' "$name" "$(pwd -P)" "$*" >> "$TEST_TMP/scripts.log"
cat "$TEST_TMP/$name.out" 2> /dev/null
exit "$(cat "$TEST_TMP/$name.code" 2> /dev/null || echo 0)"
FAKE
done

# Make the fake gh answer "gh <command> <subcommand> ..." with the exit code and the output, on stderr when the code is not 0.
fake_gh() {
    key=$(printf '%s\n' "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/_/g')
    printf '%s\n' "$2" > "$TEST_TMP/gh/$key.code"
    printf '%s\n' "${3:-}" > "$TEST_TMP/gh/$key.out"
}

# Make the fake sibling script answer with the exit code and stdout.
fake_script() {
    printf '%s\n' "$2" > "$TEST_TMP/$1.code"
    printf '%s\n' "${3:-}" > "$TEST_TMP/$1.out"
}

# Print the logged calls of the fake sibling script: its directory and its arguments.
script_calls() {
    sed -n "s/^$1 //p" "$TEST_TMP/scripts.log"
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
