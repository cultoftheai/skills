# Helpers for the script tests. run.sh sources this file in each test's temp directory.

export TEST_TMP="$PWD"
export PATH="$TEST_TMP/bin:$PATH"
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/gh"
: > "$TEST_TMP/gh.log"
: > "$TEST_TMP/items.jsonl"

cat > "$TEST_TMP/bin/gh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_TMP/gh.log"
rule="$TEST_TMP/gh/$1_$2"
if [ "$1 $2" = "api graphql" ] && [ ! -f "$rule.code" ]; then
    number=$(printf '%s\n' "$@" | sed -n 's/^number=//p')
    rule="$TEST_TMP/gh/item_$number"
    jq -s --argjson n "$number" '{data: {repository: {issueOrPullRequest: (map(select(.number == $n))[0])}}}' "$TEST_TMP/items.jsonl" > "$rule.out"
    echo 0 > "$rule.code"
fi
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
if [ -n "$filter" ]; then
    jq -r "$filter" "$rule.out"
else
    cat "$rule.out"
fi
FAKE
chmod +x "$TEST_TMP/bin/gh"

unset SDLC_HARNESS CLAUDECODE
for name in $(env | sed -n 's/^\(CODEX_[A-Za-z0-9_]*\)=.*/\1/p'); do
    unset "$name"
done

export NEXT_STEP="$TEST_TMP/.sdlc/scripts/next_step.sh"
mkdir -p "$TEST_TMP/.sdlc/scripts"
echo '{}' > "$TEST_TMP/.sdlc/settings.json"
cp "$SCRIPTS/next_step.sh" "$NEXT_STEP"
: > "$TEST_TMP/ready.out"
: > "$TEST_TMP/gates.out"
cat > "$TEST_TMP/.sdlc/scripts/ready.sh" <<'FAKE'
#!/bin/sh
cat "$TEST_TMP/ready.out"
FAKE
cat > "$TEST_TMP/.sdlc/scripts/ship_gates.sh" <<'FAKE'
#!/bin/sh
cat "$TEST_TMP/gates.out"
! grep -q ': fail - ' "$TEST_TMP/gates.out"
FAKE

# Make the fake gh answer "gh <command> <subcommand> ..." with the exit code and stdout.
fake_gh() {
    printf '%s\n' "$2" > "$TEST_TMP/gh/$(echo "$1" | tr ' ' _).code"
    printf '%s\n' "${3:-}" > "$TEST_TMP/gh/$(echo "$1" | tr ' ' _).out"
}

# Add a node to the issues and pull requests that the fake "gh api graphql" answers with, by number.
fake_item() {
    printf '%s\n' "$1" >> "$TEST_TMP/items.jsonl"
}

# Make the fake ready.sh list these issue numbers, in this order.
fake_ready() {
    for number in "$@"; do
        printf '#%s Task %s\n' "$number" "$number"
    done > "$TEST_TMP/ready.out"
}

# Make the fake ship_gates.sh print this output, and exit 1 when a gate failed.
fake_gates() {
    printf '%s\n' "$1" > "$TEST_TMP/gates.out"
}

# Print the last line that next_step.sh prints for the arguments.
next_line() {
    "$SH" "$NEXT_STEP" "$@" 2> /dev/null | tail -n 1
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
