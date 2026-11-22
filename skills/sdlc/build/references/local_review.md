# Local review

The folder is `<task.path>/<task>/`, or `$(git rev-parse --git-path sdlc/qa)` for XS. `<ref>` is the task, or `-` for XS.

1. **Review** - Follow `orchestrator` to start one fresh subagent that runs `review <ref> --local`. Ask it for its report and the paths of the findings files. Read each findings file.
2. **Recommend** - Give each finding one recommendation: `fix` for blocking and should-fix, `skip` for nit, `stop` when the fix needs a decision that the spec does not cover. You may change a `fix` or a `skip`. Write the reason in the Finding cell.
3. **Decide** - Without `--auto`, show every finding in one table: number, severity, location, finding and recommendation. Ask the person to choose `fix` or `skip` for each row, or to take the recommendations. A `stop` row stays `stop`. With `--auto`, take the recommendations.
4. **Record** - Write `PR.md` in the folder, in the format below. With no finding, write it with no row. For a task, commit it alone. For XS, do not commit it.
5. **Stop?** - If a row is `stop`, make no fix. Name the decision in the report, and hand off as a stop.
6. **Fix** - Apply each `fix` row as one unit, as step 4 of the skill says, and run step 5 of the skill after each one. Write the commit SHA in the Fix column.
7. **Verify** - With at least one `fix` row, follow `orchestrator` to start one fresh subagent that runs `review <ref> --local --verify`. Write each result in the Verify column, add each new finding as a new row, and write the head SHA after `Verified:`. For a task, commit `PR.md` again.
8. **Result** - If a `fix` row is not `fixed`, or the verify reports a new blocking or should-fix finding, hand off as a stop and name them in the report. If not, the run passes.

A stop hands off with `sh .sdlc/scripts/next_step.sh <ref> --after review --result fail`. Run one review and one verify, no more.

## PR.md

```markdown
# Local review
Reviewed: <short sha>. Verified: <short sha or "no">.

| # | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify |
|---|------|----------|----------|---------|----------------|----------|-----|--------|
| 1 | <axis> | <severity> | <path:line> | <the finding in your own words> | <fix, skip or stop> | <fix, skip or stop> | <short sha> | <fixed, not fixed or partly fixed> |
```

Leave Fix and Verify empty for a row that is not fixed.
