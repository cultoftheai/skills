# QA

## Run 2026-11-23T07:55:51Z
Commit: adc95ca177cb7070a0152ed072f9089a066ce922
Result: pass
### Steps
- Review round 5 fix 64775f2: a row that the verify adds gets the Decision `skip` only when its recommendation is `skip`, and `stop` otherwise.
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed. `lint_skill.py skills/sdlc/build` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- 64775f2 changes one clause for findings that the verify adds. The other paths hold from the earlier runs in this file.

## Run 2026-11-23T07:48:09Z
Commit: 7b1f1a6726e8e74ddad62e16cb73a3e3a5fc8ea6
Result: pass
### Steps
- Review round 3 fix a5d1348: a row that the verify adds gets the Decision `skip` for a nit and `stop` for any other, and step 9 stops on a verify row with the Decision `stop`.
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed. `lint_skill.py skills/sdlc/build` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- a5d1348 changes two sentences for findings that the verify adds. The XS runs of 2026-11-22T20:39Z added only nits after a verify (`skip`, as now) and stopped only on a row not fixed. The other paths hold from the earlier runs in this file.

## Run 2026-11-22T23:28:14Z
Commit: 53f4e51ddecbbf9829a3be667129930c258147c9
Result: pass
### Steps
- Review round 2 fixes: 4bd7988 (verify rows get a Decision; a row not fixed blocks reuse), d7271ea (commit PR.md on a re-size), 133fab1 (the settle rule names Decision, Fix and Verify).
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed. `lint_skill.py skills/sdlc/build` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- The three commits change only sentences of `local_review.md` for a stop after a verify and for a re-size. The reuse of a settled PR.md (run of 2026-11-22T20:46Z) had no Verify values, so it reads the same under the new check. The other paths hold from the earlier runs in this file.

## Run 2026-11-22T20:46:56Z
Commit: b46ef6660031f2316ae2cf613e5961d88668417b
Result: pass
### Steps
- Review round 1 fixes: 529e589 (settled check and Status), 64eb8e8 (stop on any new stop row), 1dfa1a5 (one hand-off per stop, with `--auto`), 984ae17 (format note), 0663021 (spec), d465057 (Decision column in the settled check).
- Fixture: a local bare repository as `origin` with `main` at 0663021, one clone, a fixture commit with a grade bug, and a hand-written `.sdlc/task/79/PR.md` with Status `stopped`: row 1 `fix` with no Fix SHA, row 2 recommended `stop` and settled `skip`. `build 79 --auto` in a fresh subagent, gh reads through GH_REPO, no writes.
- Result: step 1 reused PR.md (Status `stopped`, Reviewed commit an ancestor of HEAD, no Decision `stop`). No new review. Row 1 fixed with a test first (c3af406), `review 79 --local --verify` -> row 1 `fixed`, 0 new findings. PR.md Status `passed`, committed. Hand-off: "Next: /sdlc:prove 79 --auto".
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed. `lint_skill.py skills/sdlc/build` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- The settled check was run on 0663021; d465057 only names the Decision column, which the run already read that way.
- Criteria 1 to 9 hold from the runs of 2026-11-22T20:39Z (XS) and 2026-11-22T20:19Z (task table and record). The fixes change the re-run, the Status line and the hand-off wording, not those paths.

## Run 2026-11-22T20:39:51Z
Commit: 0bf701e1a41d2b2dda5bd95a9f7af2563eba3a80
Result: pass
### Steps
- Fixture: a local bare repository as `origin` with `main` at the commit under test, and four clones of it. In each, a fresh subagent ran `build "<XS edit>" --auto` from `skills/sdlc/build/SKILL.md` in the clone. No push, no gh write.
- Clone x3, edit "add a comment above run_test that says what it prints when a test fails", with a planted wrong comment ("one line for each passed test") -> build committed the edit (ab4905b), step 7 started `review - --local`: guide and consistency reviewers, no criteria reviewer. 1 should-fix finding on the wrong comment, recommendation `fix`, taken under `--auto`. Fix committed as its own unit (128ac47), tests 32 passed. `review - --local --verify` -> row 1 `fixed`, 2 new nits added as rows with Axis `verify` and `skip`. PR.md at `.git/sdlc/qa/PR.md`, not tracked by git. Hand-off: "Next: /sdlc:prove --auto" (criteria 1, 2, 4, 6, 7, 9).
- Clone x4, same edit and wrong comment, plus a planted bad fix ("passed" changed to "skipped") -> fix a2a0a1c, verify row 1 `not fixed`, nit row `skip`. Hand-off: "Next: settle the findings left in PR.md in the XS folder (git rev-parse --git-path sdlc/qa), then run /sdlc:build "<the edit in words>" --auto" (criteria 6, 9).
- Clones x1 and x2, an edit whose exact wording is false ("all in one shared temp directory") -> 2 should-fix findings recommended `stop`, because a fix would override the wording the edit asked for. No fix, no verify. PR.md in `.git/sdlc/qa`, not tracked. Same settle hand-off (criterion 5 under `--auto`, criterion 7).
- `sh skills/sdlc/next/tests/run.sh` -> 32 tests, 0 failed. `lint_skill.py skills/sdlc/build` -> PASS (mermaid not checked, mmdc missing).

## Assumptions
- No QA guide. A skill's real surface is a run of it, with the person's answers and the planted faults given in the brief.
- Criteria 3 and 8 for a task (one table with recommendations without `--auto`; PR.md committed alone in the task folder) hold from the run of 2026-11-22T20:19Z on 134e113. Since then, `local_review.md` changed the recommendation rule, the fix loop and a new first step for a settled PR.md, not the table or the record.
- The runs reported small gaps that break no criterion: the reviewer brief does not name the repository path, the stop hand-off in `local_review.md` does not say to add `--auto` (build step 8 does), and `build` does not name the branch for XS work.

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

