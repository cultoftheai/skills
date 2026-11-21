# QA

## Run 2026-11-21T22:21:04Z
Commit: a5a8f02ecfb628d911979407f8d98daa70986fa6
Result: pass
### Steps
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` -> PASS. The frontmatter parses, and the description is 575 characters, under the limit of 1024.
- `sed -n 3p skills/sdlc/review/SKILL.md` -> the description reads "Starts up to three reviewer subagents with no memory of the build, one for each axis at the ultra level." This matches step 4, which starts 0 to 3 reviewers.

## Assumptions
- Commit 5c236cf changes only the frontmatter description, which is shown where skills are listed. No behaviour of the flow changes, so the review runs below still hold.

## Run 2026-11-21T22:10:40Z
Commit: c83027b605273e0c83ea0f5156f6993cd3b206aa
Result: pass
### Steps
- Fixture: draft PR #70 (head dc8444f) against `main`, with the same planted contradiction as #68 (harness.md:8 against orchestrator rule 6). It closes no issue. The settings were read from a scratch copy with `guides.code_review: null`, which was never committed.
- `review 70` (`high`, XS, no guide) -> step 3 found no closing issue, so `criteria` was dropped, and there was no guide, so `guide` was dropped. 0 axes left, so step 4 started 0 reviewers. Step 6 posted nothing: `gh api .../pulls/70/reviews --jq length` printed 0. The report says there was nothing to check, and the hand-off with `pass` printed "Next: /sdlc:ship 70".
- `review 70 --level ultra` (XS, no guide) -> only `consistency` was left, so step 4 started 1 reviewer with `Axes: consistency` and briefed "Code review guide: none". It reported blocking: harness.md:8 against `orchestrator/SKILL.md:14`, and should-fix: harness.md:8 against harness.md:21. Review https://github.com/cultoftheai/skills/pull/70#pullrequestreview-6008523434 was posted. Its comments start with [":robot: [consistency] **blocking**: The new l",":robot: [consistency] **should-fix**: The Cla"]. The review count went from 0 to 1.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` -> PASS.
- Cleanup -> PR #70 closed and its branch deleted.

## Assumptions
- No QA guide. I ran the skill by following `skills/sdlc/review/SKILL.md` at the commit under test.
- The fixes for threads 3 to 5 change only wording, so this run checks the one behaviour change, thread 1. The `high` path with an issue and a guide has the same text as the passing run below.

## Run 2026-11-21T22:01:08Z
Commit: 1eb9582c633561c0cf24a4127d5d7158cdba3176
Result: pass
### Steps
- Fixture: draft PR #68 (head fec95c5) against `main`. It changes `skills/sdlc/orchestrator/references/harness.md:8` to "Workers share the worktree of the parent. Do not set `isolation`". That contradicts `skills/sdlc/orchestrator/SKILL.md:14`, "Give each one its own worktree". The PR closed the throwaway issue #67, which has 1 criterion.
- `review 68 --level ultra` -> step 3 collected the diff from `gh pr diff 68`, issue #67, the head fec95c5 and the guide `REVIEWING.md`. Step 4 started 3 reviewers in one message, with `Axes: criteria`, `Axes: guide` and `Axes: consistency`, each with its own findings file. criteria: criterion met, 0 findings. guide: 0 findings, `REVIEWING.md` has no rules. consistency: 2 findings.
- Criterion 2 -> blocking: harness.md:8 contradicts orchestrator `SKILL.md:14` (rule 6). should-fix: harness.md:8 contradicts harness.md:21 (the Codex section). Step 5 found both cited lines at fec95c5, and dropped 0 findings.
- Criterion 1 -> review https://github.com/cultoftheai/skills/pull/68#pullrequestreview-6008477024 was posted as type COMMENT. Its 2 inline comments on harness.md start with `:robot: [consistency] **blocking**` and `:robot: [consistency] **should-fix**`. The body has the level `ultra` and the criteria table.
- `review 68 --level high` -> 1 reviewer with `Axes: criteria, guide`. Criterion met, 0 findings. Posted pullrequestreview-6008479552.
- `review 68` with no level -> 1 reviewer. Its brief matches the `high` brief except for the temp folder. Criterion met, 0 findings. Posted pullrequestreview-6008479659.
- Criterion 4: I edited the PR body to remove `Closes #67`, then ran `review 68` -> `closingIssuesReferences` was empty. 1 reviewer with `Axes: guide` and `Issue: none`. There was no "missing criteria" finding. Posted pullrequestreview-6008482327, with the body "Criteria axis skipped: the PR closes no issue, so it is XS work."
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` -> PASS.
- Cleanup -> PR #68 closed and its branch deleted. Issue #67 closed as not planned.

## Assumptions
- No QA guide (`TESTING.md` is a TODO). I ran the skill by following `skills/sdlc/review/SKILL.md` at the commit under test, because the installed skill is the old `main` version.
- The `--verify` half of criterion 4 moved to #66 before this run. #65 now asks only that `high` works on an XS PR.
- I discarded a first `ultra` batch on #68 that briefed "Code review guide: none" instead of `REVIEWING.md`. It was not posted. Its findings were the same.

## Run 2026-11-21T21:45:39Z
Commit: bd0511467c90b64846bc1e2bebdbbaa84535d21c
Result: fail
### Steps
- Fixture: local branch `qa-65-fixture` at 3d9aa88 on top of the commit under test. It changes `skills/sdlc/orchestrator/SKILL.md:16` from "at most three workers" to "at most two workers". The fixture issue has 1 criterion: "The orchestrator skill says to run at most two workers at once." -> diff saved, head 3d9aa88.
- `review <fixture> --level ultra`, following step 4 of the review skill -> 3 reviewers started in one message, with `Axes: criteria`, `Axes: guide` and `Axes: consistency`, each with its own findings file. criteria: 0 findings, criterion met. guide: 0 findings, axis skipped (no guide). consistency: 2 findings, both `axis: consistency`.
- The consistency findings (criterion 2) -> blocking: orchestrator:16 "at most two" contradicts `skills/sdlc/review/SKILL.md:51` "At `ultra`, start three in one message". should-fix: contradicts `.sdlc/task/65/SPEC.md:15` "at most 3 at once". Step 5 citation check: both cited lines exist at 3d9aa88.
- Step 6 for ultra, dry run, not posted -> the review payload has 2 inline comments, each starting `:robot: [consistency]`, and the criteria table in the body. Posting to a PR was not run.
- `review <fixture> --level high` -> 1 reviewer with `Axes: criteria, guide`. 0 findings, criterion met, guide skipped.
- `review <fixture>` with no level -> 1 reviewer, and its brief is the same as the `high` brief (`Axes: criteria, guide`). 0 findings, criterion met.
- `review <fixture>` with no closing issue (XS) -> 1 reviewer with `Axes: guide` and `Issue: none`. No blocking "missing criteria" finding. The reviewer reported the criteria axis as skipped.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` -> PASS (mermaid not checked, mmdc missing).
- Fail: criterion 1 says "each posted finding names its axis". The review was not posted to a real PR, because the person chose a dry run. Criterion 4 (the `--verify` half) can only be checked once #66 ships.

## Assumptions
- No QA guide (`TESTING.md` is a TODO). I ran the skill by following `skills/sdlc/review/SKILL.md` at the commit under test, because the installed skill is the old `main` version.
- The fixture was a local commit, not a PR. The diff came from `git diff`, not from `gh pr diff`.
- The `high`, default and XS reviewers ran at the same time as the 3 `ultra` reviewers, so 6 ran at once. Within the `ultra` run itself, 3 started in one message.
