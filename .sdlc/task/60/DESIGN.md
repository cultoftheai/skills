# Design: Review the change in a fresh subagent before prove

Story: #60

## Data model

`PR.md`, the record of the local review, in the task folder `<task.path>/<task>/`. XS work uses the XS folder that `submit` already reads: `$(git rev-parse --git-path sdlc/qa)`. So every run has a folder, and the "no folder" case of the story does not come up.

`build` writes it and commits it on the task branch. The XS folder is inside `.git`, so there it is not committed.

```markdown
# Local review
Reviewed: <short sha>. Verified: <short sha or "no">.

| # | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify |
|---|------|----------|----------|---------|----------------|----------|-----|--------|
| 1 | guide | should-fix | path:line | ... | fix | fix | <sha> | fixed |
```

- Recommendation: `fix` for blocking and should-fix, `skip` for nit, `stop` when the fix needs a decision the spec does not cover. `build` sets it and may change it with a reason in the Finding cell.
- Decision: what the person chose, or the recommendation with `--auto`.
- Verify: `fixed`, `not fixed` or `partly fixed`, from the local verify. Empty for skipped rows.

## Changed contracts

**`review`**: new flag `--local`, target is a task number or `-` for XS.

| | Before | After |
|---|---|---|
| Target | PR, issue (spec or design), spec path | adds `<task\|-> --local`: the diff `origin/<default_branch>...HEAD`, without `<task.path>` |
| Level | `--level`, default `high` | `--local` always runs `ultra`; `--level` is ignored |
| Output | a review posted on the PR | findings JSON in review's own temp folder, path in the report. Nothing posted, nothing written in the repo (rule 3 holds) |
| `--verify` | PR only, reads review threads | also `--local --verify`: reads the `fix` rows of `PR.md` and their fix commits, with the brief of `references/verify_brief.md` adapted to rows |
| Round count | full PR reviews by `review.prefix` | unchanged. A local review posts nothing, so it never counts toward `review.max_rounds` |
| Hand-off | `next_step.sh --after review` | none with `--local`: the caller is `build` |

**`build`**: a new step after the last unit, before the report: local review. The run ends with `pass` only after a clean local verify, so `after_build` still names `prove`.

**`next_step.sh --after review`** on an issue at `in-progress`, or on `-`, is a local review that `build` stopped on:
- `pass`: `prove <task>` (or `prove` for XS).
- `fail`: `settle the findings left in <folder>/PR.md, then run build <task>`.

A spec or design review is unchanged: it runs before `in-progress`.

**`submit`**: `assets/pr_body.md` gets one line under Evidence when `PR.md` exists in the folder: `Local review: ran before QA.` No counts, no findings.

## Module boundaries

- `build` owns the loop: start `review --local` in a fresh subagent (via `orchestrator`), show the table and ask (or take the recommendations with `--auto`), apply each `fix` row as its own committed unit, write `PR.md`, start `review --local --verify`, and stop on a `stop` decision or on a blocking or should-fix row left after the verify. One review and one verify per run, no more.
- `review` owns the reviewers, the briefs and the check of each citation. It never edits code or writes in the repo.
- New dependencies: `build` -> `review` and `build` -> `orchestrator`, listed under `build`'s Dependencies.
- `next_step.sh` owns the hand-off after a stop. `submit` only checks that `PR.md` exists.

## Patterns to follow

- `skills/sdlc/review/SKILL.md` step 3, the `--verify` branch: how to collect inputs for a verify run.
- `skills/sdlc/review/references/verify_brief.md`: the brief to adapt from threads to `PR.md` rows.
- `skills/sdlc/submit/SKILL.md` step 2: the XS folder from `git rev-parse --git-path sdlc/qa`.
- `skills/sdlc/next/scripts/next_step.sh` `after_review`, and `test_after_review_of_a_spec` in `skills/sdlc/next/tests/test_next_step.sh`, for the new branch and its test.
