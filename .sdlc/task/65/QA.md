# QA

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
