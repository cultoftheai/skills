# QA

## Run 2026-11-22T18:49:30Z
Commit: 067113437bd50409fd865cdb7d948743e534d396
Result: pass
### Steps
- Fixture: local branch `qa-78` from the commit under test, with `qa-fixture/grade.sh` (planted: `-gt 90` against "A from 90", no range check against "Exits 2 outside 0 to 100", typo "Pritn"). Head e521ff7. Each run below is a fresh subagent that follows `skills/sdlc/review/SKILL.md` from disk.
- `review 78 --local --level high` -> 3 reviewers in one message (criteria, guide, consistency): ultra, not high. 9 findings (2 blocking: both planted bugs), 4 of 4 criteria met. The report gave the 3 findings file paths in the scratchpad. No GitHub write: #78 had 0 comments before and after, and no PR existed for `qa-78`. No `Next:` line (criterion 1).
- `review - --local` -> 2 reviewers (guide, consistency), no criteria reviewer. The report says "the `criteria` axis was skipped". 6 findings, nothing posted, no `Next:` line (criterion 2).
- Fix commit b0e2881 (`-ge 90`, only `-gt 100` checked, and `echo C` changed to `echo D`), plus a hand-written `.sdlc/task/78/PR.md`: row 1 and row 2 `fix` with Fix b0e2881, row 3 a nit with `skip`. Head b6f5432. `review 78 --local --verify` -> 1 reviewer with `verify_brief.md`. Row 1 `fixed` (grade.sh:8), row 2 `partly fixed` (grade.sh:5, -5 still exits 0), row 3 not checked. 1 new blocking finding: `echo D` at grade.sh:13, a line the fix commit changed. Results file path in the report, nothing posted (criterion 3).
- `qa-78` pushed with draft PR #84 (throwaway). `review 84 --level high --auto` -> full review 6013807361 posted. Full reviews on #84 (body starts with `:robot:`, not `:robot: [verify]`): 1.
- `review 78 --local` on the same branch -> 3 reviewers, 9 findings, no GitHub write. Full reviews on #84: still 1 (criterion 4).
- New commit 14306e6 pushed. `review 84 --level high --auto` -> step 2: 1 earlier full review, limit 2 not hit, 14306e6 named in no fix reply, so it recommends a full review. Round 2 ran and posted review 6013825793. Full reviews on #84: 2 (criterion 4).
- Cleanup: PR #84 closed, branch `qa-78` deleted on the remote and locally.
- `lint_skill.py skills/sdlc/review` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- No QA guide (`TESTING.md` is a stub). The real surface of a skill is a run of it, so each check ran the skill in a fresh subagent from the file on disk.
- `REVIEWING.md` is a stub, so the guide axis returned no findings in every run. The PR reviews at `high` with no closing issue checked only that axis, which is why they found nothing.
- The reviewers also reported gaps in the new `--local` text: step 4 still says "hand off with `pass`", `--auto` with no target still names the PR, the `PR.md` Location column is not split into path and line, and step 6 does not say that the `--verify` replies are skipped with `--local`. These do not break a criterion. They are left for the local review and the PR review.
