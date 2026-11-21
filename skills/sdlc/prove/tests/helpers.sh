# Helpers for the script tests. run.sh sources this file in each test's temp directory.

export TEST_TMP="$PWD"
export PATH="$TEST_TMP/bin:$PATH"
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/git"
: > "$TEST_TMP/git.log"

cat > "$TEST_TMP/bin/git" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_TMP/git.log"
rule="$TEST_TMP/git/$(printf '%s' "$*" | tr -c 'A-Za-z0-9._-' _)"
if [ ! -f "$rule.code" ]; then
    echo "unexpected command: git $*" >&2
    exit 99
fi
code=$(cat "$rule.code")
if [ "$code" -ne 0 ]; then
    echo "fake error" >&2
    exit "$code"
fi
cat "$rule.out"
FAKE
chmod +x "$TEST_TMP/bin/git"

# Make the fake git answer "git <arguments>" with the exit code and stdout. The arguments must match exactly.
fake_git() {
    rule="$TEST_TMP/git/$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' _)"
    printf '%s\n' "$2" > "$rule.code"
    printf '%s\n' "${3:-}" > "$rule.out"
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
