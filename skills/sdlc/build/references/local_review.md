# Local review

The folder is `<work.path>/<task>/` (fallback `.sdlc/work/<task>/`), or `<work.path>/xs/` for XS. `<ref>` is `<task>`, or `-` for XS. Ensure the folder exists (`mkdir -p`) and never stage or commit it.

1. **Settled?** - Reuse `<folder>/self-review.md` only when its `Status` is `stopped`, its `Reviewed` commit is an ancestor of `HEAD` (`git merge-base --is-ancestor`), no row has the Decision `stop`, and no `fix` row has the Verify `not fixed` or `partly fixed`: a person settled it after a stop. Then skip steps 2–6 and go to step 7 with its rows. If not, go to step 2.
2. **Review** - Follow `orchestrator` to start one fresh subagent that runs `review <ref> --local`. Ask it for its report and the paths of the findings files. Read each findings file.
3. **Recommend** - Give each finding one recommendation: `fix` for `blocking` and `should-fix`, `skip` for `nit`, `stop` when the fix needs a decision that the spec does not cover. Change a recommendation only to `stop`, and write the reason in the Finding cell.
4. **Decide** - Without `--auto`, show every finding in one table: number, severity, location, finding, and recommendation. Ask the person to choose `fix` or `skip` for each row, or to take the recommendations. A `stop` row stays `stop`. With `--auto`, take the recommendations.
5. **Record** - Write `<folder>/self-review.md` in the format below without committing it. With no finding, write it with no row and `Status: passed`, and finish local review. Otherwise set `Status` to `open`.
6. **Stop?** - If any row is `stop`, make no fix, set `Status` to `stopped`, name the decision in the report, and stop for review.
7. **Fix** - Apply each `fix` row with an empty `Fix` column as one unit, as step 4 of `build` says, and write the short commit SHA in the `Fix` column of `self-review.md`. After each unit, run the diff check of step 5 of `build`. If the diff passes `sizing.review_limit`, set `Status` to `re-size` and stop for a re-size as step 5 says.
8. **Verify** - With at least one `fix` row, follow `orchestrator` to start one fresh subagent that runs `review <ref> --local --verify`. Write each result in the `Verify` column, add each new finding as a new row with Axis `verify`, its recommendation from step 3, and a Decision (`skip` when its recommendation is `skip`, `stop` otherwise), and write the short head SHA after `Verified:`.
9. **Result** - If a `fix` row is not `fixed`, or a row that verify added has the Decision `stop`, set `Status` to `stopped`, name them in the report, and stop for review. Otherwise set `Status` to `passed` and continue to step 8 of `build`.

Run one review and one verify per round. To settle `self-review.md` after a stop, a person changes the Decision of each `stop` row to `fix` or `skip` (or clears `Fix` and `Verify` on an unfixed `fix` row) and runs `build` again.

## self-review.md

```markdown
# Local review
Reviewed: <short sha>. Verified: <short sha or "no">. Status: <open, stopped, re-size or passed>.

| # | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify |
|---|------|----------|----------|---------|----------------|----------|-----|--------|
| 1 | <axis> | <severity> | <path:line> | <the finding in your own words> | <fix, skip or stop> | <fix, skip or stop> | <short sha> | <fixed, not fixed or partly fixed> |
```

Leave `Fix` empty for a row that is not fixed yet, and `Verify` empty for a row with no `Fix`.
