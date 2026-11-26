# Spec: Run the local review in build before prove

Task: #79. Story: #60. Design: `.sdlc/task/60/DESIGN.md`.
Size: L (story). Confirmed for this task: 2 modules (`skills/sdlc/build`, `skills/sdlc/next`), 5 files (1 new), about 110 changed lines, no risk path. `after_review` gets a branch for a case that has no hand-off today.

## Data shape
- `PR.md` as the design says. Folder: `<task.path>/<task>/`, or `$(git rev-parse --git-path sdlc/qa)` for XS.
- Recommendation per finding: `fix` (blocking, should-fix), `skip` (nit), `stop` (the fix needs a decision the spec does not cover). `build` may change one only to `stop`, with a reason in the Finding cell.
- Table shown to the person: `#`, severity, location, finding, recommendation. The person answers per row `fix` or `skip`, or "as recommended".
- Hand-off after a stop: `next_step.sh <task|-> --after review --result fail`.

## Seam
- `build` step 6 "Units left?" goes to a new step 7 "Local review" instead of the report. The report becomes step 8.
- Step 7, in `references/local_review.md`:
  1. Start `review <task|-> --local` in a fresh subagent as `orchestrator` says. Read its findings files.
  2. Set each recommendation. Without `--auto`, show the table and take the decisions. With `--auto`, take the recommendations.
  3. Write `PR.md`. Commit it with the task folder, not for XS.
  4. Any `stop` decision: report it and hand off with `--after review --result fail`. No fix is made.
  5. Apply each `fix` row as one unit (step 4 rules), and write its SHA in the Fix column.
  6. With at least one `fix` row, start `review <task|-> --local --verify`. Write each result in the Verify column and `Verified:`.
  7. A row not `fixed`, or a new blocking or should-fix finding: hand off with `--after review --result fail`. If not, step 8 hands off with `--after build` as today.
- The size check of step 5 "Within the spec?" also runs after each fix unit.
- `next_step.sh` `after_review`: with no ref, or an issue at `in-progress`, a local review. `pass` names `prove`. `fail` names "settle the findings left in PR.md in the folder of #<task>" (or "in the XS folder ..."), "then run build <task|edit>".

## Files
- `skills/sdlc/build/SKILL.md`: Dependencies (`review`, `orchestrator`), step 7, the flow graph, the `--auto` flag, Output (`PR.md`).
- `skills/sdlc/build/references/local_review.md` (new): the steps above, the settled-record check, and the table.
- `skills/sdlc/build/references/auto_mode.md`: a `stop` finding is a hard stop.
- `skills/sdlc/next/scripts/next_step.sh` and the copy `.sdlc/scripts/next_step.sh`: the `after_review` branch.
- `skills/sdlc/next/tests/test_next_step.sh`: `test_after_review_of_a_local_review`.

## Test plan
- `sh skills/sdlc/next/tests/run.sh` passes, with the new test: issue 21 `in-progress` and `-`, pass and fail (criterion 9).
- `lint_skill.py skills/sdlc/build` exits 0.
- Throwaway task branch with a planted blocking bug, a nit and a finding that needs a spec decision. `build` without `--auto`: the table shows all three with recommendations; the person picks; `PR.md` holds the rows; the `stop` row ends the run with the settle hand-off (criteria 1, 3, 5, 8).
- The same without the `stop` finding, with `--auto`: the blocking bug is fixed in its own commit, the nit is recorded and skipped, the verify gives `fixed`, and the hand-off is `prove` (criteria 2, 4, 6).
- A fix that leaves the bug half fixed: the run stops with the settle hand-off (criterion 6).
- An XS edit: the review runs without the criteria reviewer, `PR.md` is in the XS folder and not committed (criterion 7).

## Open questions
- None.

## Decisions during the build
- A recommendation follows the severity. `build` may change it only to `stop`, so that `--auto` never skips a blocking or should-fix finding and never fixes a nit (QA run of 2026-11-22, criteria 4 and 6).
- The diff check after each fix runs only the size limit of step 5. A re-size there hands off as a re-size, and the local review runs once per `build` run.
- After a stop, the person settles `PR.md` and runs `build` again. A `PR.md` with no `stop` row and an unfixed `fix` row is reused: `build` applies those rows and verifies them, without a new review (build assumption under `--auto`, recommended to the person on 2026-11-22).
