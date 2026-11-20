# Tests for review_threads.sh.

comment() {
    printf '{"url": "https://github.com/o/r/pull/1#discussion_r1", "body": "%s", "createdAt": "2026-11-20T10:00:00Z", "author": {"login": "%s", "__typename": "%s"}}' \
        "$2" "$1" "${3:-User}"
}

thread() {
    printf '{"id": "%s", "isResolved": %s, "isOutdated": false, "path": "src/app.sh", "line": 10, "viewerCanResolve": true, "comments": {"nodes": [%s]}}' \
        "$1" "${3:-false}" "$2"
}

page() {
    if [ -n "${2:-}" ]; then
        info="{\"hasNextPage\": true, \"endCursor\": \"$2\"}"
    else
        info='{"hasNextPage": false, "endCursor": null}'
    fi
    printf '{"data": {"viewer": {"login": "me"}, "repository": {"pullRequest": {"reviewThreads": {"pageInfo": %s, "nodes": [%s]}}}}}' \
        "$info" "$1"
}

test_list_skips_resolved_threads_and_follows_pages() {
    fake_gh_sequence "api graphql" \
        "$(page "$(thread T1 "$(comment rev 'fix this')"), $(thread T2 "$(comment rev x)" true)" c1)" \
        "$(page "$(thread T3 "$(comment rev 'and this')")")"
    output=$("$SH" "$SCRIPTS/review_threads.sh" list 7) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -r '[.[].id] | join(",")')" "T1,T3"
    assert_contains "$(gh_call 1)" "number=7"
    assert_contains "$(gh_call 1)" "owner={owner}"
    assert_eq "$(gh_call 1 | grep -c cursor=)" 0
    assert_contains "$(gh_call 2)" "-f cursor=c1"
}

test_list_prints_the_thread_fields() {
    fake_gh "api graphql" 0 "$(page "$(thread T1 "$(comment rev fix)")")"
    output=$("$SH" "$SCRIPTS/review_threads.sh" list 7) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -c '.[0] | del(.comments)')" \
        '{"id":"T1","path":"src/app.sh","line":10,"outdated":false,"can_resolve":true,"needs_reply":true,"rounds":0}'
    assert_eq "$(printf '%s\n' "$output" | jq -c '.[0].comments[0]')" \
        '{"author":"rev","bot":false,"body":"fix","url":"https://github.com/o/r/pull/1#discussion_r1","created_at":"2026-11-20T10:00:00Z"}'
}

test_needs_reply_is_false_when_our_reply_is_last() {
    fake_gh "api graphql" 0 "$(page "$(thread T1 "$(comment rev fix), $(comment me ':robot: Fixed in abc1234.')")")"
    output=$("$SH" "$SCRIPTS/review_threads.sh" list 7) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -c '.[0] | [.needs_reply, .rounds]')" "[false,1]"
}

test_rounds_count_only_our_prefixed_replies() {
    comments="$(comment rev fix), $(comment me ':robot: Fixed in abc.'), $(comment me 'a manual note'), $(comment rev 'still wrong'), $(comment me ':robot: Fixed again in def.'), $(comment bot nope Bot)"
    fake_gh "api graphql" 0 "$(page "$(thread T1 "$comments")")"
    output=$("$SH" "$SCRIPTS/review_threads.sh" list 7) || exit 1
    assert_eq "$(printf '%s\n' "$output" | jq -c '.[0] | [.needs_reply, .rounds, .comments[-1].bot]')" "[true,2,true]"
}

test_reply_prints_the_url() {
    fake_gh "api graphql" 0 '{"data": {"addPullRequestReviewThreadReply": {"comment": {"url": "https://github.com/o/r/pull/1#discussion_r9"}}}}'
    printf ':robot: Fixed in abc.\n' > body.md
    output=$("$SH" "$SCRIPTS/review_threads.sh" reply T1 body.md) || exit 1
    assert_eq "$output" "https://github.com/o/r/pull/1#discussion_r9"
    assert_contains "$(gh_call 1)" "-f body=:robot: Fixed in abc."
    assert_contains "$(gh_call 1)" "-f thread=T1"
}

test_reply_without_prefix_exits_2() {
    printf 'Fixed in abc.\n' > body.md
    "$SH" "$SCRIPTS/review_threads.sh" reply T1 body.md 2> /dev/null
    assert_eq $? 2
    assert_eq "$(cat "$TEST_TMP/gh.log")" ""
}

test_reply_fails_when_github_returns_no_url() {
    fake_gh "api graphql" 0 '{"data": {"addPullRequestReviewThreadReply": null}}'
    printf ':robot: ok\n' > body.md
    "$SH" "$SCRIPTS/review_threads.sh" reply T1 body.md > /dev/null 2>&1
    assert_eq $? 1
}

test_resolve_with_default_settings_exits_3() {
    "$SH" "$SCRIPTS/review_threads.sh" resolve T1 2> /dev/null
    assert_eq $? 3
    assert_eq "$(cat "$TEST_TMP/gh.log")" ""
}

test_resolve_when_the_author_resolves() {
    mkdir .sdlc
    printf '{"review.resolve": "author"}\n' > .sdlc/settings.json
    fake_gh "api graphql" 0 '{"data": {"resolveReviewThread": {"thread": {"isResolved": true}}}}'
    output=$("$SH" "$SCRIPTS/review_threads.sh" resolve T1) || exit 1
    assert_eq "$output" "resolved T1"
    assert_contains "$(gh_call 1)" "-f thread=T1"
}

test_reads_a_nested_prefix_setting() {
    mkdir .sdlc
    printf '{"review": {"prefix": "[bot]"}}\n' > .sdlc/settings.json
    fake_gh "api graphql" 0 '{"data": {"addPullRequestReviewThreadReply": {"comment": {"url": "u"}}}}'
    printf '[bot] ok\n' > body.md
    assert_eq "$("$SH" "$SCRIPTS/review_threads.sh" reply T1 body.md)" "u"
    printf ':robot: ok\n' > body.md
    "$SH" "$SCRIPTS/review_threads.sh" reply T1 body.md 2> /dev/null
    assert_eq $? 2
}

test_gh_failure_exits_1() {
    fake_gh "api graphql" 1
    "$SH" "$SCRIPTS/review_threads.sh" list 7 > /dev/null 2>&1
    assert_eq $? 1
}

test_bad_usage_exits_2() {
    "$SH" "$SCRIPTS/review_threads.sh" list '#7' 2> /dev/null
    assert_eq $? 2
    "$SH" "$SCRIPTS/review_threads.sh" close T1 2> /dev/null
    assert_eq $? 2
}
