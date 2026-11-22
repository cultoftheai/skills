# QA

## Run 2026-11-22T20:19:03Z
Commit: 134e1130b3303a48f112d29fd46ac946c781d10e
Result: fail
### Steps
- Fixture: three worktrees from the commit under test (qa-79a, qa-79b, qa-79c). Each holds `qa-fixture/grade.sh` with a planted bug (`-gt 90`, so 90 prints B) and a typo, and a fixture SPEC.md in place of the #79 spec (qa-79a also has an open question on scores outside 0 to 100). Each run is a fresh subagent that follows `skills/sdlc/build/SKILL.md` from its worktree. No push, PR, comment or label change.
- qa-79a, `build 79`, the person answers "take the recommendations" -> step 7 started one `review 79 --local` subagent, which ran 3 reviewers at ultra. Build showed one table of 14 findings with number, severity, location, finding and recommendation (10 `stop`, 1 `fix`, 3 `skip`). PR.md written with 14 rows, Decision = Recommendation, and committed alone (1ef8d10). No fix, no verify. Hand-off: "Next: settle the findings left in PR.md of the local review, then run /sdlc:build 79" (criteria 1, 3, 5, 8, 9 stop branch).
- qa-79b, `build 79 --auto` -> no table. 14 findings: 2 `fix` (the planted bug, two axes), 8 `stop`, 4 `skip`. PR.md committed alone (5151f84). The `stop` rows ended the run before any fix, so the fix, verify and prove path did not run (criteria 2, 4, 6 not shown).
- qa-79c, `build 79 --auto` with a planted bad fix -> 18 findings, 11 `stop`. Same stop before any fix, so the bad fix was never applied (criterion 6 not shown).
- Why the runs stopped: the fixture branches sit on the #79 commits, and the review diffs against `origin/main`, which does not hold them. The reviewers also read the real #79 changes, which the fixture spec does not cover, so build marked them `stop`.
- Defects the reviewers found in the change under test, reported by two or three of the runs each:
  - `skills/sdlc/build/references/local_review.md:6`: build may change a `fix` to `skip` or a `skip` to `fix`. With `--auto`, a blocking or should-fix finding can then reach `prove` with no person (criterion 6), and a nit can be fixed (criterion 4).
  - `local_review.md:10`: "run step 5 of the skill after each one" leads on to steps 6 and 7, so each fix starts the local review again. A step-5 stop in the fix loop also has two hand-offs (`--after build` and `--after review`).
  - `local_review.md:8` and the settle hand-off: after a stop, `build` runs a new review and writes a new PR.md, so the decisions a person settled in PR.md are never read.
  - Nits: the settle line names `PR.md` without its folder (`next_step.sh:395`, DESIGN.md asks for `<folder>/PR.md`); `auto_mode.md:3` lists only three hard stops; verify findings added as rows have no axis or recommendation defined; Output says "task folder" for XS too.
- Not run: the XS edit (criterion 7) and a clean verify that goes on to `prove`.
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed (reported by the reviewers at head).

## Assumptions
- No QA guide. A skill's real surface is a run of it, so each check ran `build` in a fresh subagent from the files on disk, with the person's answer given in the brief.
- Next fixture: a local bare repository as `origin` with `main` at the commit under test, so that the branch diff holds only the fixture, and the fixture spec kept in a separate task folder.
- The planted typo and the open question were not reported in any findings file, so the fixture did not drive a `stop` on its own.

