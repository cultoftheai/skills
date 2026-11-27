#!/bin/sh
# Check the merge gates of a pull request.
#
# Usage: ship_gates.sh <pr>
#
# Run it from the repository root, on a checkout of the PR head.
# Prints one line per gate: approval, checks, threads, qa.
# Exit code 0 when every gate passes, 1 when any gate fails or the arguments are bad.
#
# - approval: a person (not a bot, not the PR author) approved — or, when
#   the PR author is the only non-bot user with push access, the author left
#   a solo approval comment on the PR — nobody asks for changes, and GitHub's
#   review decision is not blocking.
# - checks: no check failed, was cancelled or is still pending.
# - threads: every unresolved review thread ends with a reply from the PR author.
# - qa: local HEAD is the PR head, and either all PR files are under specs.path
#   (Spec/Design PR) or the newest "<review.prefix> [qa]" PR comment is a pass
#   for the PR head (or an ancestor followed only by commits carrying
#   SDLC-Docs-Only: true, SDLC-Spec-Archive: true, or touching only specs.path).
#
# Reads review.prefix and specs.path from .sdlc/settings.json and needs jq.

set -u
exec 3>&1

SETTINGS=.sdlc/settings.json
DEFAULT_PREFIX=':robot:'
DEFAULT_SPECS_PATH=.sdlc/specs
DOCS_ONLY_TRAILER=SDLC-Docs-Only
SPEC_ARCHIVE_TRAILER=SDLC-Spec-Archive
COLLAB_ENDPOINT='repos/{owner}/{repo}/collaborators?affiliation=all&permission=push&per_page=100'
TAB=$(printf '\t')
FAILED=0

PR_QUERY='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      headRefOid
      reviewDecision
      author { login }
      files(first: 100) { nodes { path } }
      comments(last: 100) { nodes { body isMinimized author { __typename login } } }
      latestOpinionatedReviews(first: 100) { nodes { state author { __typename login } } }
      reviewThreads(first: 100) {
        nodes { isResolved comments(last: 1) { nodes { url author { login } } } }
      }
    }
  }
}'

SOLO_CHECK='
  if type == "array" and length < 100 then
    ([.[] | select(type == "object" and .type == "User" and (.permissions | type == "object" and .push == true)) | .login] | unique) == [$author]
  else false end'

NEEDS_SOLO='
  .author.login as $author
  | (.latestOpinionatedReviews.nodes // []) as $reviews
  | ([$reviews[] | select(.state == "CHANGES_REQUESTED")] | length) == 0
    and ([$reviews[] | select(.state == "APPROVED" and .author.__typename == "User" and .author.login != $author)] | length) == 0'

APPROVAL='
  .author.login as $author
  | (.latestOpinionatedReviews.nodes // []) as $reviews
  | [$reviews[] | select(.state == "APPROVED" and .author.__typename == "User" and .author.login != $author)
     | .author.login] as $approvers
  | [$reviews[] | select(.state == "CHANGES_REQUESTED") | .author.login // "ghost"] as $blockers
  | (([(.comments.nodes // [])[]
      | select(($author != null)
          and (.isMinimized // false | not)
          and (.author != null)
          and (.author.login == $author)
          and ((.author.__typename // "User") == "User"))
      | ((.body // "") | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)) | first // "")
      | select(startswith($prefix + " [approval]") or test("^(/approve|approve|approved|lgtm)[.!]*$"; "i"))]
     | length) > 0) as $solo_approved
  | if ($blockers | length) > 0 then "fail\tchanges requested by \($blockers | join(", "))"
    elif ($approvers | length) == 0 and ($solo | not) then "fail\tno approval from a person"
    elif .reviewDecision == "CHANGES_REQUESTED" or .reviewDecision == "REVIEW_REQUIRED"
      then "fail\tGitHub review decision is \(.reviewDecision)"
    elif ($approvers | length) > 0 then "pass\tapproved by \($approvers | join(", "))"
    elif $solo_approved then "pass\tapproved by \($author) (solo approval)"
    else "fail\tno solo approval from \($author)" end'

CHECKS='
  [.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] as $failed
  | [.[] | select(.bucket == "pending") | .name] as $pending
  | if ($failed | length) > 0 then "fail\tfailed: \($failed | join(", "))"
    elif ($pending | length) > 0 then "fail\tpending: \($pending | join(", "))"
    else "pass\t\(length) green" end'

THREADS='
  .author.login as $author
  | [.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[-1]
     | select(.author.login != $author) | .url] as $unanswered
  | if ($unanswered | length) > 0 then "fail\t\($unanswered | length) unanswered: \($unanswered | join(" "))"
    else "pass\tno unanswered thread" end'

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print "ship_gates failed: <reason>" to stdout, also from a command substitution, and exit 1.
fail() {
    printf 'ship_gates failed: %s\n' "$1" >&3
    exit 1
}

# Print a verdict: "pass" or "fail", a tab, and the detail.
verdict() {
    printf '%s\t%s\n' "$1" "$2"
}

# Print the gate line for the verdict, and remember a failed gate.
report() {
    result=${2%%"$TAB"*}
    printf '%s: %s - %s\n' "$1" "$result" "${2#*"$TAB"}"
    [ "$result" = pass ] || FAILED=1
}

# Print the text in lower case.
lower() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

# Read review.prefix and specs.path (normalized with trailing slash) from .sdlc/settings.json.
read_settings() {
    [ -f "$SETTINGS" ] || fail "cannot read $SETTINGS"
    jq -e . "$SETTINGS" >/dev/null 2>&1 || fail "cannot read $SETTINGS"
    PREFIX=$(jq -r '.review.prefix // empty' "$SETTINGS" 2>/dev/null) || fail "cannot read $SETTINGS"
    PREFIX=${PREFIX:-$DEFAULT_PREFIX}
    specs=$(jq -r '.specs.path // empty' "$SETTINGS" 2>/dev/null) || fail "cannot read $SETTINGS"
    specs=${specs:-$DEFAULT_SPECS_PATH}
    while [ "${specs#./}" != "$specs" ]; do
        specs=${specs#./}
    done
    while [ "${specs%/}" != "$specs" ] && [ "$specs" != / ]; do
        specs=${specs%/}
    done
    SPECS_PREFIX="$specs/"
}

# Print the pullRequest object of the GraphQL query for the PR.
fetch_pr() {
    err=$(gh api graphql -f query="$PR_QUERY" -F owner='{owner}' -F name='{repo}' -F number="$1" \
        --jq '.data.repository.pullRequest' 2>&1 >&4) || fail "cannot read PR #$1: $err"
} 4>&1

# Print the value of the jq filter on the JSON text.
field() {
    printf '%s\n' "$1" | jq -r "$2"
}

# Print "true" when the PR author is the only non-bot User with push access, else "false".
is_solo_author() {
    [ -n "$1" ] || { printf 'false\n'; return; }
    output=$(gh api "$COLLAB_ENDPOINT" 2>/dev/null) || { printf 'false\n'; return; }
    result=$(printf '%s\n' "$output" | jq -r --arg author "$1" "$SOLO_CHECK" 2>/dev/null) || result=false
    if [ "$result" = true ]; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

# Print the verdict of the gate that needs a person's approval or a solo author PR approval comment.
approval_gate() {
    solo=false
    if [ "$(field "$1" "$NEEDS_SOLO")" = true ]; then
        author=$(field "$1" '.author.login // empty')
        solo=$(is_solo_author "$author")
    fi
    printf '%s\n' "$1" | jq -r --argjson solo "$solo" --arg prefix "$PREFIX" "$APPROVAL"
}

# Print the verdict of the gate that needs green checks.
checks_gate() {
    output=$(gh pr checks "$1" --json name,bucket 2>&1)
    case "$output" in
        *'no checks reported'*) verdict pass 'no checks reported' ;;
        '['*) field "$output" "$CHECKS" ;;
        *) verdict fail "cannot read checks: $output" ;;
    esac
}

# Exit 0 when one of the whitespace-separated values is "true", in any case.
has_true() {
    lower "$1" | tr -s '[:space:]' '\n' | grep -qx true
}

# Print paths from the list that do not start with SPECS_PREFIX.
outside_specs() {
    printf '%s\n' "$1" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        case "$path" in
            "$SPECS_PREFIX"*) continue ;;
        esac
        printf '%s\n' "$path"
    done
}

# Print the files changed by one commit outside SPECS_PREFIX, or nothing when it carries a non-code trailer.
commit_stale_files() {
    trailers=$(git log -1 "--format=%(trailers:key=$DOCS_ONLY_TRAILER,key=$SPEC_ARCHIVE_TRAILER,valueonly)" "$1" 2>/dev/null) || return 1
    if has_true "$trailers"; then
        return 0
    fi
    changed=$(git diff --name-only "$1^1" "$1" 2>/dev/null) || return 1
    outside_specs "$changed"
}

# Print sorted unique files outside SPECS_PREFIX changed by commits after the tested commit without non-code trailers.
stale_changes() {
    later=$(git rev-list "$1..$2" 2>/dev/null) || return 1
    files=''
    for sha in $later; do
        part=$(commit_stale_files "$sha") || return 1
        files="$files
$part"
    done
    printf '%s\n' "$files" | sed '/^$/d' | LC_ALL=C sort -u
}

# Print the first five lines of the list joined by ", ".
first_five() {
    printf '%s\n' "$1" | awk 'NR <= 5 { printf "%s%s", (NR > 1 ? ", " : ""), $0 }'
}

# Print the verdict of the gate that needs an Official QA PR comment for the head commit.
qa_gate() {
    head=$(field "$1" .headRefOid)
    local_head=$(git rev-parse HEAD 2>/dev/null)
    if [ "$local_head" != "$head" ]; then
        verdict fail "local HEAD $local_head is not the PR head $head"
        return
    fi
    is_specs_only=$(printf '%s\n' "$1" | jq -r --arg specs "$SPECS_PREFIX" \
        '[(.files.nodes // [])[].path] as $p | ($p | length) > 0 and all($p[]; startswith($specs))')
    if [ "$is_specs_only" = true ]; then
        verdict pass "spec/design-only PR; no app QA required"
        return
    fi
    comment=$(printf '%s\n' "$1" | jq -r --arg prefix "$PREFIX [qa]" \
        '[(.comments.nodes // [])[] | .body // "" | select(startswith($prefix))] | last // empty')
    if [ -z "$comment" ]; then
        verdict fail "no Official QA comment found; run prove $2 first"
        return
    fi
    first_line=$(printf '%s\n' "$comment" | head -n 1)
    result=${first_line#"$PREFIX [qa]"}
    result=$(printf '%s\n' "$result" | awk '{print $1}')
    result=$(lower "$result")
    commit=$(printf '%s\n' "$comment" | sed -n 's/^Commit:[[:space:]]*\([^[:space:]]\{1,\}\)[[:space:]]*$/\1/p' | head -n 1)
    if [ -z "$commit" ]; then
        verdict fail "newest Official QA comment has no 'Commit:' line"
        return
    fi
    if [ "$result" != pass ]; then
        verdict fail "newest Official QA comment for $commit is '$result', not 'pass'"
        return
    fi
    tested=$(git rev-parse --verify --quiet "$commit^{commit}" 2>/dev/null)
    if [ -z "$tested" ]; then
        verdict fail "newest Official QA comment names commit $commit, which this repository does not have"
        return
    fi
    if [ "$tested" = "$head" ]; then
        verdict pass "Official QA passed for $tested"
        return
    fi
    base=$(git merge-base "$tested" "$head" 2>/dev/null)
    if [ "$base" != "$tested" ]; then
        verdict fail "newest Official QA comment is for $commit, which is not an ancestor of PR head $head"
        return
    fi
    if ! stale=$(stale_changes "$tested" "$head"); then
        verdict fail "cannot inspect commits between $commit and $head"
        return
    fi
    if [ -n "$stale" ]; then
        verdict fail "newest Official QA pass is for $commit, but PR head $head also changes $(first_five "$stale")"
        return
    fi
    verdict pass "Official QA passed for $tested"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
case "$1" in
    '' | *[!0-9]*) usage; exit 1 ;;
esac
read_settings || exit 1
pr=$(fetch_pr "$1") || exit 1
report approval "$(approval_gate "$pr")"
report checks "$(checks_gate "$1")"
report threads "$(field "$pr" "$THREADS")"
report qa "$(qa_gate "$pr" "$1")"
exit "$FAILED"
