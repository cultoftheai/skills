# Spec: Add the --verify mode to review

Task: #66. Story: #62. Design: none.
Size: M (story). Confirmed: 2 modules (`skills/sdlc/review`, `skills/sdlc/respond`), 5 files (1 new), about 90 changed lines, no risk path. `--verify` and `list --all` are new options that only add to the existing ones.

## Data shape
- `--verify`: PR targets only. `--level` is ignored with it. With a spec or design target, the skill stops and says so.
- `review_threads.sh list <pr> --all`: also lists resolved threads. Each thread gets a `resolved` field (false without `--all`). The other fields do not change.
- Thread to check: a thread from `.sdlc/scripts/review_threads.sh list <pr> --all`, resolved or not, that has a reply naming a commit SHA (the fix reply that `respond` step 7 writes), and whose first comment is not marked `nit`. A thread with no SHA reply is a decline, needs-you or follow-up thread, and is skipped.
- Fix commits: every SHA named in those replies.
- Verify results JSON: `{"threads": [{thread, result: fixed|not fixed|partly fixed, path, line, evidence}], "findings": [{severity, path, line, finding, evidence}]}`. `findings` holds only problems in lines the fix commits changed, or in lines that contradict them.
- Reply in each checked thread: `<prefix> [verify] <result>: <path>:<line>`. If the thread already has a `[verify] not fixed` or `partly fixed` reply and the result is still not `fixed`, the reply ends with "Needs a person: still not fixed after two verify rounds."

## Seam
- Step 3 collects `threads.json` from `list --all` and the fix SHAs instead of the issue. Step 4 starts 1 reviewer with `references/verify_brief.md`. Steps 5 and 6 check the citations, post the replies with `review_threads.sh reply`, and post the new findings as one review. Step 8: `pass` when every result is `fixed` and no blocking or should-fix finding is left. Nits are posted, but they do not fail the round.
- The stop for a person reuses `respond` step 3: a thread with `rounds` of 2 or more is needs-you. After two fix replies and two verify replies, `respond` asks the person.
- No thread to check: start no reviewer, report that there was nothing to verify, and hand off with `pass`.

## Files
- `skills/sdlc/review/SKILL.md`: the `--verify` flag, and a `--verify` branch in steps 3 to 6 and 8 that reads `references/verify_brief.md`.
- `skills/sdlc/review/references/verify_brief.md` (new): the brief, made from the five rules in the story's `--verify` section and the JSON above.
- `skills/sdlc/respond/scripts/review_threads.sh` and the installed copy `.sdlc/scripts/review_threads.sh`: the `--all` option and the `resolved` field.
- `skills/sdlc/respond/tests/test_review_threads.sh`: one test for `--all` and `resolved`.

## Test plan
- `lint_skill.py skills/sdlc/review` exits 0.
- `sh skills/sdlc/respond/tests/run.sh` passes. With `--all`, the new test sees a resolved thread with `resolved: true`, and the existing test still shows that `list` without `--all` skips it.
- Throwaway PR with 3 review threads: one fixed and resolved, one fixed and left open, one declined. Answer them as `respond` does, then run `review <pr> --verify`. Both fixed threads get `[verify] fixed` with a line, the declined one gets no reply, and the hand-off is `pass` (criteria 1, 3 and 4).
- On the same PR: a fix commit that adds a new problem, plus a problem planted outside the fix lines. Only the first is reported (criterion 2).
- A fix that does not fix, verified twice. The second reply says "Needs a person", and `respond` triages the thread as needs-you (criterion 5).
- The same run on a PR that closes no issue gives the same results (criterion 6).

## Open questions
- None. See the decisions under review.
