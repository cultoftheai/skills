# QA

## Run 2026-11-22T11:02:17Z
Commit: 7b70253ade62c8e2e85f517b7062beb23735370d
Result: pass
### Steps
- A fresh clone of `main` only, without the PR commits -> `git rev-list 0d5441e..7b70253` (the latest full review commit to the PR head) exited 128 with "Invalid revision range".
- Step 2 as written: `git fetch origin pull/76/head`, then the same `git rev-list` -> exit 0. 2 commits: ee8194d and 7b70253.
- Round limit on PR #76 -> 3 full reviews, the latest at 0d5441e. Of the 2 commits after it, 7b70253 changes only `.sdlc/task/66/REVIEW.md` and is left out. ee8194d is named in the fix reply. Recommendation: "--verify".
- `lint_skill.py skills/sdlc/review` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- No QA guide. I followed step 2 of `skills/sdlc/review/SKILL.md` at the commit under test.
- Commit ee8194d only adds the fetch to step 2. The rest holds from the runs of 2026-11-22T10:57, 10:45 and 10:36.

## Run 2026-11-22T10:56:58Z
Commit: 0744125c5e83c4a7385cfa5141a9def8dac5ef89
Result: pass
### Steps
- Round limit on closed fixture PR #77 (real threads and reviews, read only) -> 2 full reviews, the latest at 123a96f. `git rev-list 123a96f..d22c6f2` gave 4 commits, all outside `.sdlc/task`. c37b9aa, 6693186 and f1819d2 are named in fix replies; d22c6f2 is not. The `[verify] pass` is on f1819d2, not the head. Recommendation: "full review".
- Round limit on PR #76 itself after fix 1848cae and its reply -> 2 full reviews, the latest at 38760f3. `git rev-list 38760f3..0744125` gave 2 commits: 1848cae, named in the fix reply, and 0744125, which changes only `.sdlc/task/66/REVIEW.md` and is left out. Recommendation: "--verify".
- `lint_skill.py skills/sdlc/review` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- No QA guide. I followed step 2 of `skills/sdlc/review/SKILL.md` at the commit under test, with `gh pr view <pr> --json headRefOid,reviews`, `git rev-list` and `git diff-tree --name-only`.
- Commit 1848cae changes only the round-limit recommendation in step 2. The rest of `--verify` holds from the run of 2026-11-22T10:45 and the run of 2026-11-22T10:36.

## Run 2026-11-22T10:45:22Z
Commit: 802d96829e9f0a4ccfd45b8bd3fc956c73d456b1
Result: pass
### Steps
- Fixture: draft PR #77 (`qa-fixture/count.sh`, head f1819d2 after the fixes), with 2 full reviews posted as fixtures and 3 threads:
  - a "Fixed differently in c37b9aa" reply;
  - a fix reply, then a `[verify] not fixed` reply, then a decline;
  - a fix reply on a thread that is then resolved.
- `review 77 --verify`, step 3 -> `all.json` held 3 threads. `threads.json` held 2: the fix-differently thread and the resolved thread. The thread whose newest non-`[verify]` reply is the decline was left out, though an older reply names 6693186. Fix commits: c37b9aa f1819d2.
- Steps 4 to 6 -> 1 reviewer with `verify_brief.md`. Results: 2 of 2 threads fixed (:4 and :8), 0 findings. Every thread to check had a result. Review pullrequestreview-6011823805, `:robot: [verify] pass`, on commit f1819d2. Hand-off: "Next: /sdlc:ship 77".
- Round limit at head f1819d2 -> `gh pr view 77 --json headRefOid,reviews`: 2 full reviews, and the `[verify] pass` is on the head commit. Recommendation: "skip the review, hand off pass".
- Round limit after one more commit (head d22c6f2) -> the `[verify] pass` is on f1819d2, not the head. Recommendation: "run with --verify".
- `lint_skill.py skills/sdlc/review` and `skills/sdlc/respond` -> PASS. `sh skills/sdlc/respond/tests/run.sh` -> 13 tests, 0 failed.
- Cleanup -> PR #77 closed and its branch deleted. Fixture worktree removed.

## Assumptions
- No QA guide. I followed `skills/sdlc/review/SKILL.md` at the commit under test. The full reviews, the replies and the earlier `[verify] not fixed` reply on the fixture were posted by hand.
- The rule "a thread with no result counts as not fixed" was not triggered: the reviewer gave a result for every thread. The paths that did not change since the run of 2026-11-22T10:36 (criteria 2, 3, 6 and the fail side of 4) hold from that run.

## Run 2026-11-22T10:36:04Z
Commit: e3db30bfe617b513e6c9abf9ea70afa9a29421c8
Result: pass
### Steps
- Fixture: draft PR #74 (`qa-fixture/greet.sh`, head a294a73) against `main`. It closes no issue. I posted 2 full reviews as `review` step 6 writes them: one with 5 inline findings (two greetings, unused `count`, `banner` output thrown away, a `nit:` for `printf`, and a translation question), one body-only. A planted bug outside every fix: line 17, `$nmae`.
- Answered as `respond` does: 2e23a13 (one greeting), f84f4f9 (removes `count`, and also changes `name=$1` to `name=$2`, a regression), 195e7ed (the nit). Replies "Fixed in <sha>" on those 3 threads. A decline with no SHA on the `banner` thread, and a needs-you reply with no SHA on the translation thread. I resolved the greeting thread.
- `review 74 --verify`, round 1 -> step 3: `review_threads.sh list 74 --all` returned 5 threads, with the greeting thread `resolved: true`. It kept 2 threads (greeting, count) and skipped the declined, needs-you and nit threads. Fix commits: 2e23a13 f84f4f9 (195e7ed left out, because its thread is a nit). 1 reviewer started with `verify_brief.md`, filled in. Results: fixed :8, fixed :4. Finding: blocking :4, the name is read from `$2`. All cited lines exist at the head. Replies `:robot: [verify] fixed: qa-fixture/greet.sh:8` and `...:4`. Review pullrequestreview-6011765096 with the body `:robot: [verify] fail`. Hand-off: "Next: /sdlc:respond 74".
- Criterion 1 -> the resolved thread and the open thread both got a result with a cited line, in every round.
- Criterion 2 -> the regression in f84f4f9 was reported as blocking. The planted `$nmae` on line 17 was not reported in round 1, because no fix commit touched it. The reviewer's reply named it as out of scope.
- Criterion 3 -> the declined, needs-you and nit threads were skipped in all 3 rounds. The brief names no criteria and no guide.
- Criterion 6 -> I created throwaway issue #75 and set the PR body to "Closes #75". `closingIssuesReferences` was [75]. Step 3 run again gave the same kept threads, fix SHAs, head and brief. Body restored, #75 closed as not planned.
- Round limit after round 1, `review 74` without `--verify` -> 2 full reviews counted (the `[verify]` review and the empty reply reviews not counted). 2 >= `review.max_rounds` 2, so the limit is hit. No `[verify] pass` is newer than the latest full review, so the recommendation is "run with --verify".
- Round 2: a person-style comment without the prefix opened a thread on the `$nmae` typo. Fix a47895f set `name=$1` and also changed "Goodbye" to "Bye" on line 17, without touching the typo -> step 3 fix commits: only a47895f. The 2 threads verified in round 1 had no newer fix reply, so they added no SHA. Results: 3 of 3 fixed. Finding: should-fix :17, the wording change that no thread asked for. The `$nmae` typo on the same changed line was not reported, and the reviewer named open thread PRRT_kwDOV1MHCs66izd6 as the reason. Review pullrequestreview-6011771261, `:robot: [verify] fail`.
- Round 3, after fix 02cd7bc restored "Goodbye" -> fix commits: only 02cd7bc. Results: 4 of 4 fixed, 0 findings. Review pullrequestreview-6011776373 with the body `:robot: [verify] pass`. Hand-off: "Next: /sdlc:ship 74".
- Criterion 4 -> fail when a regression was found (round 1) or a should-fix was left (round 2). Pass when every result was `fixed` and no finding was left (round 3).
- Round limit after round 3 -> 2 full reviews, limit hit. A `[verify] pass` is newer than the latest full review, so the recommendation is "skip the review, hand off pass".
- Findings per round: 1, 1, 0. Fix commits per round: 2, 1, 1.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` -> PASS (mermaid not checked, mmdc missing). `sh skills/sdlc/respond/tests/run.sh` -> 13 tests, 0 failed. `sh skills/sdlc/setup/tests/run.sh` -> 38 tests, 0 failed.
- Cleanup -> PR #74 closed and its branch deleted. Issue #75 closed as not planned. Fixture worktree removed.

## Assumptions
- No QA guide (`TESTING.md` is a TODO). I ran `review --verify` by following `skills/sdlc/review/SKILL.md` at the commit under test. The reviewer subagent got only the brief from `references/verify_brief.md`, filled in.
- I posted the 2 full reviews and the `respond` answers myself as fixtures. I did not run the `high` reviewer or the `respond` skill.
- The round-limit question was not shown. I computed the count and the recommendation that step 2 describes.
- Criterion 5 was removed from #66 on 2026-11-22 and moved to #64, so this run does not check it.

## Run 2026-11-21T22:55:03Z
Commit: 68e82eb3666e38672b63bb9a1638b0204e04b373
Result: fail
### Steps
- Fixture: draft PR #72 (`qa-fixture/fixture.sh`, head 1849953) against `main`. It closes no issue. I posted 2 full reviews as `review` step 6 writes them: one with 5 inline findings (4 should-fix, 1 `nit:`), one body-only. A planted bug outside every fix: line 9, `mul` uses `$3`.
- Answered as `respond` does: fix commits 8f0195a (div by zero), 13b26df (greet needs a name, but errors on stdout with exit 0), b9d8cc8 (the nit), 1b15474 (unknown command, still `exit 0`, does not fix). Replies "Fixed in <sha>" on 4 threads, a decline with no SHA on the `add` thread. I resolved the div thread with the GraphQL `resolveReviewThread` mutation.
- `review 72 --verify`, round 1 -> step 3: `review_threads.sh list 72 --all` returned 5 threads; the div thread had `resolved: true`. Kept 3 threads (div, greet, unknown command). Skipped the declined thread (no SHA) and the nit thread. Fix commits: 8f0195a 13b26df 1b15474. 1 reviewer started with `verify_brief.md`. Results: fixed :13, partly fixed :18, not fixed :31. Findings: should-fix :18 (greet exits 0, a fix line), nit :13 (a fix line). All cited lines exist at 1b15474. 3 replies posted, for example `:robot: [verify] fixed: qa-fixture/fixture.sh:13`. Review pullrequestreview-6008689153 with the body `:robot: [verify] fail`. Hand-off: "Next: /sdlc:respond 72".
- Criterion 2 -> the planted `mul` bug on line 9 was not reported in any of the 5 rounds. Every finding was in a line that a fix commit changed.
- Criterion 3 -> the declined thread and both nit threads (`[guide] nit:` and `[verify] nit:`) were skipped in every round. The brief names no criteria and no guide.
- Criterion 6 -> I created throwaway issue #73 and set the PR body to "Closes #73". `closingIssuesReferences` was [73]. Step 3 run again gave the same kept threads, fix SHAs, head and brief. Body restored, #73 closed as not planned.
- Round limit after round 1, `review 72` without `--verify` -> `gh pr view 72 --json reviews`: 2 full reviews (the `:robot: [verify] fail` review and the empty reply reviews not counted). 2 >= `review.max_rounds` 2, so the limit is hit. No `[verify] pass` is newer than the latest full review, so the recommendation is "run with --verify".
- Round 2 (after fix c9a269a for greet and the not-fixing 4e2f538, `usage; exit`) -> 4 threads: 3 fixed, unknown command not fixed :31. The reply was `:robot: [verify] not fixed: qa-fixture/fixture.sh:31` followed by "Needs a person: still not fixed after 2 verify rounds." Review pullrequestreview-6008696964, `:robot: [verify] fail`.
- Criterion 5, "the flow stops on it" -> FAIL. `review_threads.sh list 72` gives that thread `rounds: 5, needs_reply: false`, because the last comment is the `[verify]` reply from the current gh user. `respond` step 2 keeps only threads with `needs_reply` true, so it never reaches the step 3 needs-you rule. `next_step.sh 72 --after respond` printed "Next: /sdlc:review 72", and the round limit then recommends `--verify` again. The flow loops instead of stopping. This holds for every `--verify` reply when one gh user runs both skills.
- Rounds 3 to 5 (fixes e768cf7, 4d66603, a66287c) -> round 3: 4 of 4 fixed, 1 should-fix in a fix line, `fail`. Round 4: 1 partly fixed, 2 blocking and 1 should-fix, all real regressions from 4d66603, `fail`. Round 5: 9 of 9 fixed, 1 blocking (`+2` divisor rejected) and 1 should-fix, `fail`. Findings per round: 2, 2, 1, 3, 2.
- Criterion 4 -> the fail side holds: round 3 had every thread fixed and one should-fix finding, and it failed. The pass side was not observed, because no round passed.
- Round limit, skip path -> not observed. With 5 `[verify] fail` reviews and no pass, the recommendation stayed "run with --verify".
- Cleanup -> PR #72 closed and its branch deleted. Issue #73 closed as not planned. Fixture worktree removed.

## Assumptions
- No QA guide (`TESTING.md` is a TODO). I ran `review --verify` by following `skills/sdlc/review/SKILL.md` at the commit under test. The reviewer subagent got only the brief from `references/verify_brief.md`, filled in.
- I posted the 2 full reviews and the `respond` answers myself as fixtures. I did not run the `high` reviewer or the `respond` skill. In round 2 I answered the threads as `respond` would after a person asked for another try, because `respond` itself would skip them (`needs_reply` false).
- The round-limit question was not shown. I computed the count and the recommendation that step 2 describes.
- Observed, not a criterion: the loop did not converge. The fix commits pile up (3 SHAs in round 1, 7 in round 5), so each round checks every earlier fix line again. One problem (the div message) came back as a new finding in rounds 1 to 3, with the severity nit, then nit, then should-fix. Already fixed threads get another `[verify] fixed` reply every round. `rounds` also counts the first review comment when the current gh user posted the review.
