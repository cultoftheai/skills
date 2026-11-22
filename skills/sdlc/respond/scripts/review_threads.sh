#!/bin/sh
# List, reply to and resolve the review threads of a pull request through gh api graphql.
#
# Usage: review_threads.sh list <pr> [--all]
#        review_threads.sh reply <thread-id> <body-file>
#        review_threads.sh resolve <thread-id>
#
# list prints a JSON array of the unresolved threads, or of all threads with --all.
# Each thread has: id, path, line, outdated, resolved, can_resolve, needs_reply,
# rounds, comments (author, bot, body, url, created_at). needs_reply is true when the last comment is not from the
# current gh user. rounds counts the replies from the current gh user that start
# with review.prefix.
# reply posts the file as a reply and prints the reply URL. The body must start
# with review.prefix.
# resolve resolves the thread. Allowed only when review.resolve is "author".
#
# Settings come from .sdlc/settings.json when it exists. Defaults: review.prefix
# ":robot:", review.resolve "reviewer". Needs jq.
# Exit codes: 0 success; 1 gh failed or GitHub returned no reply URL; 2 bad usage
# or a body without the prefix; 3 resolve is not allowed by review.resolve.

set -u

SETTINGS=.sdlc/settings.json

LIST_QUERY='
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line viewerCanResolve
          comments(first: 100) {
            nodes { url body createdAt author { login __typename } }
          }
        }
      }
    }
  }
}'

REPLY_MUTATION='
mutation($thread: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $thread, body: $body}) {
    comment { url }
  }
}'

RESOLVE_MUTATION='
mutation($thread: ID!) {
  resolveReviewThread(input: {threadId: $thread}) { thread { isResolved } }
}'

SUMMARIZE='
  (last | .data.viewer.login) as $viewer
  | [.[].data.repository.pullRequest.reviewThreads.nodes[]
    | select($all or (.isResolved | not))
    | [.comments.nodes[] | {
        author: (.author.login // "ghost"),
        bot: (.author.__typename == "Bot"),
        body,
        url,
        created_at: .createdAt
      }] as $comments
    | {
        id,
        path,
        line,
        outdated: .isOutdated,
        resolved: .isResolved,
        can_resolve: .viewerCanResolve,
        needs_reply: (($comments | length) > 0 and $comments[-1].author != $viewer),
        rounds: ([$comments[] | select(.author == $viewer and (.body | startswith($prefix)))] | length),
        comments: $comments
      }]'

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Print the message to stderr and exit with the code.
fail() {
    printf '%s\n' "$2" >&2
    exit "$1"
}

# Print a dotted setting, nested or as a flat key, from the settings file, else the default.
setting() {
    if [ -f "$SETTINGS" ]; then
        jq -r --arg key "$1" --arg default "$2" \
            '(try getpath($key | split(".")) catch null) // .[$key] // $default' "$SETTINGS"
    else
        printf '%s\n' "$2"
    fi
}

# Print one page of review threads of the pull request, after the cursor when it is set.
fetch_page() {
    gh api graphql -f query="$LIST_QUERY" -F owner='{owner}' -F name='{repo}' -F number="$1" \
        ${2:+-f} ${2:+"cursor=$2"}
}

# Print every page of review threads of the pull request, one JSON response per line.
fetch_pages() {
    cursor=''
    while :; do
        page=$(fetch_page "$1" "$cursor") || return 1
        printf '%s\n' "$page" | jq -c .
        cursor=$(printf '%s\n' "$page" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo
            | if .hasNextPage then .endCursor else empty end')
        [ -n "$cursor" ] || return 0
    done
}

# Print the unresolved threads of the pull request as a JSON array, or all threads when the third argument is true.
list_threads() {
    pages=$(fetch_pages "$1") || exit 1
    printf '%s\n' "$pages" | jq -s --arg prefix "$2" --argjson all "$3" "$SUMMARIZE"
}

# Post the body file as a reply to the thread when it starts with the prefix, and print the reply URL.
reply() {
    body=$(cat "$2") || exit 2
    case "$body" in
        "$3"*) ;;
        *) fail 2 "the reply does not start with the prefix '$3'; nothing was posted" ;;
    esac
    response=$(gh api graphql -f query="$REPLY_MUTATION" -f thread="$1" -f body="$body") || exit 1
    url=$(printf '%s\n' "$response" | jq -r '.data.addPullRequestReviewThreadReply.comment.url // empty')
    [ -n "$url" ] || fail 1 "GitHub returned no reply URL; list the threads again before you retry"
    printf '%s\n' "$url"
}

# Resolve the thread when the resolve setting is author.
resolve() {
    [ "$2" = author ] || fail 3 "review.resolve is '$2'; only the reviewer resolves threads"
    response=$(gh api graphql -f query="$RESOLVE_MUTATION" -f thread="$1") || exit 1
    resolved=$(printf '%s\n' "$response" | jq -r '.data.resolveReviewThread.thread.isResolved')
    [ "$resolved" = true ] || fail 1 "GitHub did not resolve the thread"
    printf 'resolved %s\n' "$1"
}

prefix=$(setting review.prefix ':robot:') || fail 1 "cannot read $SETTINGS"
case "${1:-}:$#" in
    list:2 | list:3)
        case "$2" in
            '' | *[!0-9]*) usage; exit 2 ;;
        esac
        case "${3:-}" in
            '') all=false ;;
            --all) all=true ;;
            *) usage; exit 2 ;;
        esac
        list_threads "$2" "$prefix" "$all"
        ;;
    reply:3)
        reply "$2" "$3" "$prefix"
        ;;
    resolve:2)
        resolve_setting=$(setting review.resolve reviewer) || fail 1 "cannot read $SETTINGS"
        resolve "$2" "$resolve_setting"
        ;;
    *)
        usage
        exit 2
        ;;
esac
