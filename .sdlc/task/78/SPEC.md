# Spec: Review a branch diff before a PR exists

Task: #78. Story: #60. Design: `.sdlc/task/60/DESIGN.md`.
Size: L (story). Confirmed for this task: 1 module (`skills/sdlc/review`), 3 files, about 45 changed lines, no risk path. `--local` only adds to the existing targets.

## Data shape
- Target with `--local`: a task number, or `-` for XS. The folder is `<task.path>/<task>/`, or `$(git rev-parse --git-path sdlc/qa)` for `-`.
- Local diff: `git fetch origin <default_branch>`, then `git diff origin/<default_branch>...HEAD -- . ':!<task.path>'`. Head: `git rev-parse HEAD`. Issue: the task, none for `-`.
- Findings: the JSON list of `references/reviewer_brief.md`, one file per axis in review's temp folder, as at ultra today.
- Local verify input, made from the rows of `<folder>/PR.md` (design) whose Decision is `fix`:
  - `threads.json`: `[{id: "<#>", path, line, comments: [{body: "<severity>: <finding>"}, {body: "fixed in <Fix sha>"}]}]`
  - `open.json`: `[]`
  - Fix commits: the Fix column.
  - The result `thread` is the row number.

## Seam
- Step 2: with `--local`, skip the PR lookup and the round count. With `--verify` but no `--local` on a non-PR target, the stop stays as it is.
- Step 3: the local diff, head and issue above. With `--local --verify`, build `threads.json`, `open.json` and the fix commits from `PR.md`. A `PR.md` with no `fix` row means nothing to verify (step 4 today).
- Step 4: `--local` always starts the three ultra reviewers and ignores `--level`. XS drops `criteria` as it does today. `--local --verify` starts one reviewer with `references/verify_brief.md`.
- Step 6: with `--local`, post nothing.
- Step 7: with `--local`, the report also gives the path of each findings or results file.
- Step 8: with `--local`, no hand-off. The caller (`build`, #79) takes over.
- The round count reads only reviews posted on a PR, so a local run never counts toward `review.max_rounds`.

## Files
- `skills/sdlc/review/SKILL.md`: the `--local` flag, `-` as a target, the argument hint and the triggers, and the `--local` branches in steps 2 to 4 and 6 to 8.
- `skills/sdlc/review/references/reviewer_brief.md`: "a branch" as a fourth kind of input. The Diff and Head commit lines apply to it too.
- `skills/sdlc/review/references/verify_brief.md`: the goal speaks of "a pull request or a branch" and "findings", so local rows read correctly.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` exits 0.
- Throwaway branch from `main` with a planted bug and a broken rule. `review 78 --local --level high`: three reviewers start, the report gives findings and file paths, the PR and issue get no new review or comment (criterion 1).
- The same branch with `review - --local`: no `criteria` reviewer, and the report says the axis was skipped (criterion 2).
- A hand-written `PR.md` with one `fix` row fixed, one half-fixed and one `skip` row, plus a fix commit that adds a new bug. `review 78 --local --verify` gives `fixed` and `partly fixed`, skips the `skip` row and reports the new bug (criterion 3).
- On an open PR with one full review, a local run leaves the count of full reviews at 1, and the next `review <pr>` still runs as round 2 (criterion 4).

## Open questions
- None.
