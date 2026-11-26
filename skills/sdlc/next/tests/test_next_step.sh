# Tests for next_step.sh. gh, ready.sh and ship_gates.sh are faked.

NODE_DEFS='
  def labels: {nodes: (split(",") | map({name: .}))};
  def sub($n; $s; $l): {number: $n, state: $s, labels: ($l | labels)};
  def pull($n; $s): {number: $n, state: $s};
  def review($s; $l; $t): {state: $s, author: {login: $l, __typename: $t}};
  def thread($resolved; $l): {isResolved: $resolved, comments: {nodes: [{author: {login: $l}}]}};
  def qa($r): {body: ":robot: [qa] \($r)\nCommit: aaa\nDate: 2026-11-26T10:00:00Z"};
  def file($p): {path: $p};
'

# Add an issue. Usage: issue <number> [labels,comma,separated] [jq object of state, parent, subs, prs]
issue() {
    fake_item "$(jq -cn --argjson n "$1" --arg labels "${2:-}" "$NODE_DEFS (${3:-null}) as \$extra | "'
        ({state: "OPEN", parent: null, subs: [], prs: []} + $extra) as $o
        | {__typename: "Issue", number: $n, state: $o.state, labels: ($labels | labels),
           parent: (if $o.parent then {number: $o.parent} else null end),
           subIssues: {nodes: $o.subs}, closedByPullRequestsReferences: {nodes: $o.prs}}')"
}

# Add a pull request by "dev". Usage: pr <number> <issue it closes|-> [jq object of state, body, files, comments, reviews, requests, threads]
pr() {
    fake_item "$(jq -cn --argjson n "$1" --arg closes "$2" "$NODE_DEFS (${3:-null}) as \$extra | "'
        ({state: "OPEN", body: "", files: [], comments: [], reviews: [], requests: [], threads: []} + $extra) as $o
        | {__typename: "PullRequest", number: $n, state: $o.state, body: $o.body, author: {login: "dev"},
           files: {nodes: $o.files},
           comments: {nodes: $o.comments},
           closingIssuesReferences: {nodes: (if $closes == "-" then [] else [{number: ($closes | tonumber)}] end)},
           reviews: {nodes: $o.reviews},
           reviewRequests: {nodes: [$o.requests[] | {requestedReviewer: {__typename: "User", login: .}}]},
           reviewThreads: {nodes: $o.threads}}')"
}

# Fail the test when the ship gates output does not lead to the expected line after a failed ship of PR #9.
assert_gate() {
    fake_gates "$1"
    assert_eq "$(next_line 9 --after ship --result fail)" "$2"
}

test_missing_settings_points_to_setup() {
    rm .sdlc/settings.json
    assert_eq "$(next_line 5 --after prove)" "Next: /sdlc:setup"
    assert_eq "$(next_line 5 --after prove --auto)" "Next: /sdlc:setup --auto"
}

test_auto_is_added_to_commands_and_waits() {
    issue 5 in-progress
    assert_eq "$(next_line 5 --after prove --auto)" "Next: /sdlc:submit 5 --auto"
    pr 9 5
    fake_gates "approval: fail - no approval from a person"
    assert_eq "$(next_line 9 --after ship --result fail --auto)" \
        "Next: wait for a person to approve PR #9 (no approval from a person), then run /sdlc:ship 9 --auto"
}

test_codex_form_from_flag_and_environment() {
    issue 5 in-progress
    assert_eq "$(next_line 5 --after prove --harness codex)" 'Next: $submit 5'
    assert_eq "$(CODEX_SANDBOX=seatbelt "$SH" "$NEXT_STEP" 5 --after prove)" 'Next: $submit 5'
    assert_eq "$(CLAUDECODE=1 "$SH" "$NEXT_STEP" 5 --after prove)" "Next: /sdlc:submit 5"
    assert_eq "$(SDLC_HARNESS=codex CLAUDECODE=1 "$SH" "$NEXT_STEP" 5 --after prove)" 'Next: $submit 5'
}

test_bad_arguments_exit_2() {
    "$SH" "$NEXT_STEP" abc 2> /dev/null
    assert_eq $? 2
    "$SH" "$NEXT_STEP" 5 --after prove --result maybe 2> /dev/null
    assert_eq $? 2
}

test_hash_ref_is_a_number() {
    issue 5 in-progress
    assert_eq "$(next_line '#5' --after prove)" "Next: /sdlc:submit 5"
}

test_unknown_number_prints_a_next_line_and_exits_1() {
    output=$("$SH" "$NEXT_STEP" 404 --after review 2> /dev/null)
    assert_eq $? 1
    assert_eq "$output" "Next: fix this error (#404 is not an issue or a pull request), then run /sdlc:next 404"
}

test_gh_failure_names_its_error() {
    fake_gh "api graphql" 1
    output=$("$SH" "$NEXT_STEP" 9 2> /dev/null)
    assert_eq $? 1
    assert_eq "$output" "Next: fix this error (fake error), then run /sdlc:next 9"
}

test_after_setup() {
    assert_eq "$(next_line - --after setup)" 'Next: /sdlc:frame "<your first request>"'
}

test_after_frame_xs_goes_to_build() {
    assert_eq "$(next_line - --after frame)" 'Next: /sdlc:build "<the edit in words>"'
}

test_after_frame_without_criteria_is_a_stop() {
    assert_eq "$(next_line - --after frame --result fail)" \
        'Next: add the facts that the acceptance criteria need to the request, then run /sdlc:frame "<the request>"'
}

test_after_frame_routes_by_size() {
    issue 1 ready,size:S
    issue 2 ready,size:M
    issue 3 ready,size:L
    assert_eq "$(next_line 1 --after frame)" "Next: /sdlc:shape 1"
    assert_eq "$(next_line 2 --after frame)" "Next: /sdlc:slice 2"
    assert_eq "$(next_line 3 --after frame)" "Next: /sdlc:shape 3"
}

test_after_frame_xl_epic_frames_each_story() {
    issue 10 size:XL '{subs: [sub(11; "OPEN"; "ready,size:S"), sub(12; "OPEN"; "")]}'
    assert_eq "$(next_line 10 --after frame)" "Next: /sdlc:frame 12"
}

test_after_frame_duplicate_in_review_routes_to_its_pr() {
    issue 4 review,size:S '{prs: [pull(8; "OPEN")]}'
    pr 8 4
    assert_eq "$(next_line 4 --after frame)" "Next: /sdlc:review 8"
}

test_after_slice_first_task_and_one_task_story() {
    issue 21 ready '{parent: 20}'
    issue 30 ready,size:S
    assert_eq "$(next_line 21 --after slice)" "Next: /sdlc:shape 21"
    assert_eq "$(next_line 30 --after slice)" "Next: /sdlc:shape 30"
}

test_after_slice_stop() {
    issue 20 ready,size:L
    issue 22 shaped,size:M
    assert_eq "$(next_line 20 --after slice --result fail)" "Next: /sdlc:shape 20"
    assert_eq "$(next_line 22 --after slice --result fail)" "Next: get story #22 approved and labelled ready, then run /sdlc:slice 22"
}

test_after_shape_pass() {
    issue 21 shaped '{parent: 20}'
    issue 20 shaped,size:L
    assert_eq "$(next_line 21 --after shape)" "Next: /sdlc:build 21"
    assert_eq "$(next_line 20 --after shape)" "Next: /sdlc:slice 20"
}

test_after_shape_resize() {
    issue 21 ready '{parent: 20}'
    issue 20 ready,size:L
    issue 30 ready,size:M
    assert_eq "$(next_line 21 --after shape --result fail)" "Next: /sdlc:frame 20"
    assert_eq "$(next_line 30 --after shape --result fail)" "Next: /sdlc:slice 30"
}

test_after_build() {
    issue 21 in-progress '{parent: 20}'
    issue 30 shaped,size:S
    assert_eq "$(next_line 21 --after build)" "Next: /sdlc:prove 21"
    assert_eq "$(next_line - --after build)" "Next: /sdlc:prove"
    assert_eq "$(next_line 21 --after build --result fail)" "Next: /sdlc:frame 20"
    assert_eq "$(next_line - --after build --result fail)" 'Next: /sdlc:frame "<the edit in words>"'
    assert_eq "$(next_line 30 --after build --result fail)" "Next: check out the branch of #30 with its spec, then run /sdlc:build 30"
}

test_after_prove() {
    issue 5 in-progress
    pr 9 5
    pr 10 - '{body: "small fix"}'
    assert_eq "$(next_line 5 --after prove --result pass)" "Next: /sdlc:submit 5"
    assert_eq "$(next_line - --after prove --result pass)" "Next: /sdlc:submit"
    assert_eq "$(next_line 5 --after prove --result fail)" "Next: /sdlc:build 5"
    assert_eq "$(next_line - --after prove --result fail)" 'Next: /sdlc:build "<the edit in words>"'
    assert_eq "$(next_line 9 --after prove --result pass)" "Next: /sdlc:document 5"
    assert_eq "$(next_line 10 --after prove --result pass)" "Next: /sdlc:ship 10"
    assert_eq "$(next_line 9 --after prove --result fail)" "Next: /sdlc:build 5"
    assert_eq "$(next_line 10 --after prove --result fail)" 'Next: /sdlc:build "<the edit in words>"'
}

test_after_submit() {
    assert_eq "$(next_line 9 --after submit)" "Next: /sdlc:review 9"
    assert_eq "$(next_line 5 --after submit --result fail)" "Next: /sdlc:prove 5"
    assert_eq "$(next_line - --after submit --result fail)" "Next: /sdlc:prove"
}

test_after_review_of_a_pr() {
    pr 9 5
    pr 8 5 '{comments: [qa("pass")]}'
    pr 7 - '{body: "small fix"}'
    pr 6 - '{body: "Fixes #3", comments: [qa("pass")]}'
    assert_eq "$(next_line 9 --after review --result pass)" "Next: /sdlc:prove 9"
    assert_eq "$(next_line 8 --after review --result pass)" "Next: /sdlc:document 5"
    assert_eq "$(next_line 9 --after review --result fail)" "Next: /sdlc:handle-review 9"
    assert_eq "$(next_line 7 --after review --result pass)" "Next: /sdlc:prove 7"
    assert_eq "$(next_line 6 --after review --result pass)" "Next: /sdlc:document 3"
}

test_after_review_of_a_spec() {
    issue 5 shaped,size:S
    assert_eq "$(next_line 5 --after review --result pass)" "Next: /sdlc:build 5"
    assert_eq "$(next_line 5 --after review --result fail)" \
        "Next: apply the review findings to the spec or design of #5, then run /sdlc:build 5"
}

test_after_verify_spec() {
    pr 12 - '{body: "Spec for #5"}'
    pr 13 - '{body: "Design for #87", requests: ["alice"]}'
    assert_eq "$(next_line 12 --after verify-spec --result pass)" "Next: /sdlc:ship 12"
    assert_eq "$(next_line 12 --after verify-spec --result fail)" "Next: /sdlc:handle-review 12"
    assert_eq "$(next_line 13 --after verify-spec --result pass)" \
        "Next: wait for review from @alice on PR #13, then run /sdlc:next 13"
}

test_after_handle_review() {
    pr 9 5 '{threads: [thread(false; "alice")]}'
    pr 10 6 '{requests: ["alice"], threads: [thread(false; "dev")]}'
    pr 11 7 '{threads: [thread(true; "alice")]}'
    pr 12 - '{body: "Spec for #7", threads: [thread(true; "alice")]}'
    assert_eq "$(next_line 9 --after handle-review)" "Next: /sdlc:handle-review 9"
    assert_eq "$(next_line 10 --after handle-review)" "Next: wait for review from @alice on PR #10, then run /sdlc:next 10"
    assert_eq "$(next_line 11 --after handle-review)" "Next: /sdlc:review 11"
    assert_eq "$(next_line 12 --after handle-review)" "Next: /sdlc:verify-spec 12"
}

test_after_document() {
    assert_eq "$(next_line 9 --after document)" "Next: /sdlc:ship 9"
}

test_after_ship_pass() {
    pr 9 5 '{state: "MERGED"}'
    pr 7 - '{state: "MERGED"}'
    issue 30 ready,size:M
    fake_ready 30
    assert_eq "$(next_line 9 --after ship --result pass)" "Next: /sdlc:retro 5"
    assert_eq "$(next_line 7 --after ship --result pass)" "Next: /sdlc:slice 30"
}

test_after_ship_fail_names_the_gate() {
    pr 9 5
    assert_gate "threads: fail - 1 unanswered: url" "Next: /sdlc:handle-review 9"
    assert_gate "qa: fail - no Official QA comment found; run prove 9 first" "Next: /sdlc:prove 9"
    assert_gate "qa: fail - local HEAD a is not the PR head b" "Next: check out the head of PR #9, then run /sdlc:ship 9"
    assert_gate "checks: fail - failed: lint" "Next: fix the failed checks on PR #9 (failed: lint), then run /sdlc:ship 9"
    assert_gate "approval: fail - no approval from a person" \
        "Next: wait for a person to approve PR #9 (no approval from a person), then run /sdlc:ship 9"
    assert_gate "checks: fail - pending: test" "Next: wait for CI on PR #9 (pending: test), then run /sdlc:ship 9"
    assert_gate "approval: pass - approved by alice" "Next: /sdlc:ship 9"
}

test_after_retro() {
    assert_eq "$(next_line - --after retro)" 'Next: /sdlc:frame "<your next request>"'
    issue 30 ready,size:S
    fake_ready 30
    assert_eq "$(next_line 5 --after retro)" "Next: /sdlc:shape 30"
}

test_route_issue_stages() {
    issue 1
    issue 2 blocked,size:S
    issue 3 shaped,size:S
    issue 4 in-progress,size:S
    issue 5 review,size:S
    issue 6 ready,size:M '{subs: [sub(7; "CLOSED"; "done"), sub(8; "OPEN"; "ready")]}'
    issue 8 ready '{parent: 6}'
    assert_eq "$(next_line 1)" "Next: /sdlc:frame 1"
    assert_eq "$(next_line 2)" "Next: wait until a person unblocks #2, then run /sdlc:next 2"
    assert_eq "$(next_line 3)" "Next: /sdlc:build 3"
    assert_eq "$(next_line 4)" "Next: /sdlc:build 4"
    assert_eq "$(next_line 5)" "Next: /sdlc:submit 5"
    assert_eq "$(next_line 6)" "Next: /sdlc:shape 8"
}

test_route_done_issue_and_no_ref_go_to_next_ready() {
    issue 1 done '{state: "CLOSED"}'
    issue 3 ready,size:S
    fake_ready 1 3
    assert_eq "$(next_line 1)" "Next: /sdlc:shape 3"
    assert_eq "$(next_line -)" "Next: /sdlc:shape 3"
}

test_route_pull_request_states() {
    issue 4 review,size:S '{prs: [pull(9; "OPEN")]}'
    pr 9 4
    pr 10 4 '{reviews: [review("COMMENTED"; "dev"; "User")], threads: [thread(false; "bot")]}'
    pr 11 4 '{reviews: [review("APPROVED"; "alice"; "User")]}'
    pr 12 4 '{reviews: [review("COMMENTED"; "dev"; "User")], requests: ["alice"]}'
    pr 13 4 '{reviews: [review("COMMENTED"; "dev"; "User")]}'
    pr 16 4 '{reviews: [review("COMMENTED"; "dev"; "User")], comments: [qa("pass")]}'
    pr 17 - '{body: "Spec for #4"}'
    pr 18 - '{files: [file(".sdlc/specs/4-task.md")], reviews: [review("COMMENTED"; "dev"; "User")]}'
    pr 14 - '{state: "CLOSED"}'
    assert_eq "$(next_line 4)" "Next: /sdlc:review 9"
    assert_eq "$(next_line 10)" "Next: /sdlc:handle-review 10"
    assert_eq "$(next_line 11)" "Next: /sdlc:ship 11"
    assert_eq "$(next_line 12)" "Next: wait for review from @alice on PR #12, then run /sdlc:next 12"
    assert_eq "$(next_line 13)" "Next: /sdlc:prove 13"
    assert_eq "$(next_line 16)" "Next: /sdlc:document 4"
    assert_eq "$(next_line 17)" "Next: /sdlc:verify-spec 17"
    assert_eq "$(next_line 18)" "Next: /sdlc:ship 18"
    assert_eq "$(next_line 14)" "Next: reopen PR #14 or open a new one, then run /sdlc:next 14"
}

test_bot_approval_is_not_a_person() {
    pr 15 4 '{reviews: [review("APPROVED"; "ci-bot"; "Bot")], comments: [qa("pass")]}'
    assert_eq "$(next_line 15)" "Next: /sdlc:document 4"
}
