# Local review

The folder is `<task.path>/<task>/`, or `$(git rev-parse --git-path sdlc/qa)` for XS. `<ref>` is the task, or `-` for XS.

1. **Settled?** - Reuse `PR.md` only when its Status is `stopped`, its Reviewed commit is an ancestor of HEAD (`git merge-base --is-ancestor`), no row has the Decision `stop`, and no `fix` row has the Verify `not fixed` or `partly fixed`: a person settled it after a stop. Then skip the review and go to step 7 with its rows. If not, go to step 2.
2. **Review** - Follow `orchestrator` to start one fresh subagent that runs `review <ref> --local`. Ask it for its report and the paths of the findings files. Read each findings file.
3. **Recommend** - Give each finding one recommendation: `fix` for blocking and should-fix, `skip` for nit, `stop` when the fix needs a decision that the spec does not cover. Change a recommendation only to `stop`, and write the reason in the Finding cell.
4. **Decide** - Without `--auto`, show every finding in one table: number, severity, location, finding and recommendation. Ask the person to choose `fix` or `skip` for each row, or to take the recommendations. A `stop` row stays `stop`. With `--auto`, take the recommendations.
5. **Record** - Write `PR.md` in the folder, in the format below. Set its Status to `open`. With no finding, write it with no row. For a task, commit it alone. For XS, do not commit it.
6. **Stop?** - If a row is `stop`, make no fix. Name the decision in the report, and hand off as a stop.
7. **Fix** - Apply each `fix` row with an empty Fix column as one unit, as step 4 of the skill says, and write the commit SHA in the Fix column. After each unit, run the diff check of step 5 of the skill. If the diff passes `sizing.review_limit`, set Status to `re-size`, commit `PR.md` for a task, and stop for a re-size as step 5 says. It hands off as a re-size, not as a stop below.
8. **Verify** - With at least one `fix` row, follow `orchestrator` to start one fresh subagent that runs `review <ref> --local --verify`. Write each result in the Verify column, add each new finding as a new row with Axis `verify`, its recommendation from step 3, and the Decision `skip` for a nit or `stop` for any other, and write the head SHA after `Verified:`. For a task, commit `PR.md` again.
9. **Result** - If a `fix` row is not `fixed`, or a row that the verify added has the Decision `stop`, hand off as a stop and name them in the report. If not, set Status to `passed`, commit `PR.md` for a task, and the run passes.

A stop sets Status to `stopped`, commits `PR.md` for a task, and hands off with `sh .sdlc/scripts/next_step.sh <ref> --after review --result fail`, with `--auto` when the run has it. Run one review and one verify, no more.

To settle `PR.md` after a stop, a person changes the Decision of each `stop` row to `fix` or `skip`. For each row that is not `fixed` after a verify, they change the Decision to `skip`, or keep `fix` and clear its Fix and Verify to try again. Then they run `build` again.

## PR.md

```markdown
# Local review
Reviewed: <short sha>. Verified: <short sha or "no">. Status: <open, stopped, re-size or passed>.

| # | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify |
|---|------|----------|----------|---------|----------------|----------|-----|--------|
| 1 | <axis> | <severity> | <path:line> | <the finding in your own words> | <fix, skip or stop> | <fix, skip or stop> | <short sha> | <fixed, not fixed or partly fixed> |
```

Leave Fix empty for a row that is not fixed yet, and Verify empty for a row with no Fix.
