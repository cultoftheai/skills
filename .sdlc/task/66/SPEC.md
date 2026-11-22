# Spec: Add the --verify mode to review

Task: #66. Story: #62. Design: none.
Size: M (story). Confirmed: 2 modules (`skills/sdlc/review`, `skills/sdlc/respond`), 5 files (1 new), about 90 changed lines, no risk path. `--verify` and `list --all` are new options that only add to the existing ones.

## Data shape
- `--verify`: PR targets only. `--level` is ignored with it. With a spec or design target, the skill stops and says so.
- `review_threads.sh list <pr> --all`: also lists resolved threads. Each thread gets a `resolved` field (false without `--all`). The other fields do not change.
- Thread to check: a thread from `.sdlc/scripts/review_threads.sh list <pr> --all`, resolved or not, whose newest reply that is not a `[verify]` reply names a commit SHA (the fix or fix-differently reply that `respond` step 7 writes), and whose first comment is not marked `nit`. A thread with no SHA reply is a decline, needs-you or follow-up thread, and is skipped.
- Fix commits: the SHAs named in the replies after the newest `[verify]` reply of each thread to check. A thread with no `[verify]` reply gives every SHA in its replies. A thread verified before with no newer fix reply is still checked, but adds no fix commit.
- Open threads: the threads from the same list with `resolved` false. The reviewer does not report a problem again that an open thread already raises.
- Verify results JSON: `{"threads": [{thread, result: fixed|not fixed|partly fixed, path, line, evidence}], "findings": [{severity, path, line, finding, evidence}]}`. `findings` holds only problems in lines the fix commits changed, or in lines that contradict them.
- Reply in each checked thread: `<prefix> [verify] <result>: <path>:<line>`.
- Nit thread: a thread whose first comment marks its severity as `nit` (`nit:` or `[nit]`). `review` step 6 puts the severity after the axis in each finding it posts: `<prefix> [<axis>] <severity>: <finding>`.
- `review.max_rounds` (new, optional, integer, minimum 1, default 2): the number of full review rounds on a PR. A full round is one `review` run at `high` or `ultra`; `ultra` counts once, `--verify` does not count.
- Review body: a full review starts with `<prefix>`. A `--verify` round always posts one review, with or without findings, that starts with `<prefix> [verify] <pass|fail>`.

## Seam
- Step 3 collects `threads.json` from `list --all` and the fix SHAs instead of the issue. Step 4 starts 1 reviewer with `references/verify_brief.md`. Steps 5 and 6 check the citations, post the replies with `review_threads.sh reply`, and post the new findings as one review. Step 8: `pass` when every thread to check has a result, every result is `fixed` and no blocking or should-fix finding is left. Nits are posted, but they do not fail the round.
- The stop for a person reuses `respond` step 3: a thread with `rounds` of 2 or more is needs-you. After two fix replies and two verify replies, `respond` asks the person.
- No thread to check: start no reviewer, report that there was nothing to verify, and hand off with `pass`.
- Round limit, not a hard stop: before a full review of a PR, count the earlier full reviews from `gh pr view <pr> --json reviews` (body starts with `<prefix>`, not `<prefix> [verify]`). At `review.max_rounds` or more, say so and ask. When a `[verify] pass` review is newer than the latest full review and was posted on the head commit, recommend to skip the review and hand off with `pass`. If not, recommend `--verify` only when every commit after the latest full review, other than commits that change only `<task.path>`, is named in a fix reply. If one is not, recommend the full review. Offer the full review as the other option, or `--verify` when the full review is the recommendation. With `--auto`, take the recommended option.

## Files
- `skills/sdlc/review/SKILL.md`: the `--verify` flag, a `--verify` branch in steps 3 to 6 and 8 that reads `references/verify_brief.md`, the round limit, and the severity in posted findings.
- `skills/sdlc/setup/assets/settings.schema.json` and the installed copy `.sdlc/scripts/settings.schema.json`: `review.max_rounds`. `.sdlc/settings.json`: `review.max_rounds: 2`. `skills/sdlc/setup/references/walkthrough.md`: name it in the review group.
- `skills/sdlc/setup/tests/test_validate_settings.sh`: one test that `review.max_rounds` below 1 is rejected.
- `skills/sdlc/review/references/verify_brief.md` (new): the brief, made from the five rules in the story's `--verify` section and the JSON above.
- `skills/sdlc/respond/scripts/review_threads.sh` and the installed copy `.sdlc/scripts/review_threads.sh`: the `--all` option and the `resolved` field.
- `skills/sdlc/respond/tests/test_review_threads.sh`: one test for `--all` and `resolved`.

## Test plan
- `lint_skill.py skills/sdlc/review` exits 0.
- `sh skills/sdlc/setup/tests/run.sh` passes, with the new `review.max_rounds` test.
- `sh skills/sdlc/respond/tests/run.sh` passes. With `--all`, the new test sees a resolved thread with `resolved: true`, and the existing test still shows that `list` without `--all` skips it.
- Throwaway PR with 3 review threads: one fixed and resolved, one fixed and left open, one declined. Answer them as `respond` does, then run `review <pr> --verify`. Both fixed threads get `[verify] fixed` with a line, the declined one gets no reply, and the hand-off is `pass` (criteria 1, 3 and 4).
- On the same PR: a fix commit that adds a new problem, plus a problem planted outside the fix lines. Only the first is reported (criterion 2).
- Round 2 on the same PR, after one more fix: the fix commits hold only the SHAs named after the newest `[verify]` reply, and a problem that is already an open thread is not reported again.
- The same run on a PR that closes no issue gives the same results (criterion 6).

## Open questions
- None. See the decisions under review.

## Decisions during the build
- Nits: the severity goes into each posted finding, so `--verify` can skip the nits that `review` posted (person, 2026-11-21).
- `rounds` in `review_threads.sh` stays as it is. It also counts `[verify]` replies, so `respond` may stop for a person after one verify round. That is earlier than criterion 5 and safe. #64 covers `needs_reply` when the current user posted the last reply (person, 2026-11-21).
- `review.max_rounds` and the round limit above (person, 2026-11-21). With `--auto`, the limit takes the recommended option (build assumption).
- Criterion 5 ("the flow stops on it") is removed from #66 and moves to the bugfix for `needs_reply` (#64). The QA run of 2026-11-21 showed that `respond` never sees a thread whose last reply is a `[verify]` reply from the same gh user. The "Needs a person" reply moves with it (person, 2026-11-22).
- Convergence: the fix commits are only the SHAs named after the newest `[verify]` reply, and open threads are not reported again. The QA run showed 5 rounds with 2, 2, 1, 3 and 2 findings, because the fix commits piled up (person, 2026-11-21).
