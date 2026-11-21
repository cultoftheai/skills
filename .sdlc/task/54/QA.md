## Run 2026-11-21
Commit: ef189b27f405004a1efcc3b182ae5e3f840b82c0
Result: pass
### Steps
- `gh issue view 54` -> criterion 5 now gives "a failed `prove` back to `build`" as the only example of compact. The issue was edited after the last run, and the code was not changed.
- `CLAUDECODE=1 sh .sdlc/scripts/next_step.sh 54 --after <skill> --result <pass|fail>` for setup, frame, slice, shape, build, prove, submit, review, respond, document, ship and retro -> each of the 24 runs printed two lines: a `Context:` line, then `Next:` as the last line. compact only for prove fail. keep for prove pass, submit fail, document pass and fail, and frame fail. clear for all the others, frame pass, ship and retro included. Each line names one advice and gives a reason (criteria 1, 2, 4, 5 and 6 pass).
- The whole matrix of 24 runs ran twice -> identical output (criterion 3 pass).
- `--after build --result pass` -> `Context: clear - the next step starts from the issue, the task folder or the PR. Run /clear before the next command.` then `Next: /sdlc:prove 54`. The clear line names `/clear`.
- `--after prove --result fail --keep "lint fails"` -> `Context: compact - the next step continues this work. Run /compact Keep issue #54, branch 54-context-advice, open items: lint fails`. With no `--keep` -> `Run /compact Keep issue #54, branch 54-context-advice`. With `-` as the task -> `Run /compact Keep branch 54-context-advice, open items: lint fails`, with no issue (criterion 7 pass).
- `dash .sdlc/scripts/next_step.sh 54 --after prove --result fail --keep x` -> the same two lines as under sh.
- `sh .sdlc/scripts/next_step.sh 54` with no `--after` -> only `Next: /sdlc:build 54`. skills/sdlc/next/SKILL.md step 1 keeps the `Next:` line, step 3 asks the subagent for the last `Context:` and `Next:` lines, and step 4 prints them as the last lines (criterion 8 pass).
- `env -u CLAUDECODE CODEX_THREAD_ID=t1 sh ...` and `SDLC_HARNESS=codex sh ...` with `--after prove --result fail` -> only `Next: $build 54`, with no Context line (Codex is #55).
- The script run in a new git repo with no settings, with `--after build` -> only `Next: /sdlc:setup`.
- `grep -n next_step.sh skills/sdlc/*/SKILL.md` -> the hand-off steps of all 12 skills, and the stops of prove and submit, print the script output "as the last lines". `grep -n "Next: /" skills/sdlc/*/SKILL.md` -> the only `Next:` lines printed without the script are the stops for missing settings, which the spec leaves without a Context line.
- `diff .sdlc/scripts/next_step.sh skills/sdlc/next/scripts/next_step.sh` -> no difference.
- `sh skills/sdlc/next/tests/run.sh` and `SH=dash sh skills/sdlc/next/tests/run.sh` -> `35 tests, 0 failed` each.

## Assumptions
- TESTING.md is a TODO stub, so the run has no QA guide. The real surface is the installed script `.sdlc/scripts/next_step.sh` run as a skill runs it, plus the SKILL.md steps that tell the agent what to print.
- `CLAUDECODE=1` stands for a Claude Code session, which is how the script detects one.
- The commit under test is ef189b2. It adds only QA.md on top of 9774283, the last code change.

## Run 2026-11-21
Commit: 9774283b25a308e5c3471aec1862d0ec62de4958
Result: fail
### Steps
- `CLAUDECODE=1 sh .sdlc/scripts/next_step.sh 54 --after <skill> --result <pass|fail>` for setup, frame, slice, shape, build, prove, submit, review, respond, document, ship and retro -> each of the 24 runs printed two lines: a `Context:` line, then `Next:` as the last line. compact only for prove fail. keep for prove pass, submit fail, document pass and fail, and frame fail. clear for all the others, build pass included. Each line names one advice and gives a reason (criteria 1, 2, 4 and 6 pass).
- `--after build` run twice -> identical output both times (criterion 3 pass).
- `--after build --result pass` -> `Context: clear - the next step starts from the issue, the task folder or the PR. Run /clear before the next command.` then `Next: /sdlc:prove 54`. Criterion 5 on the issue gives "`build` to `prove`" as an example of compact. The spec (commit a837db5) and the script (commit 9774283) now advise clear here, and the issue was not changed. Criterion 5 fails as written. The prove fail -> build example gives compact as expected.
- `--after prove --result fail --keep "criterion 5 fails"` -> `Context: compact - the next step continues this work. Run /compact Keep issue #54, branch 54-context-advice, open items: criterion 5 fails`. The clear line names `Run /clear before the next command.` (criterion 7 pass).
- `sh .sdlc/scripts/next_step.sh - --after prove --result fail --keep "lint fails"` -> `Run /compact Keep branch 54-context-advice, open items: lint fails`, with no issue in the list. With no `--keep` -> `Run /compact Keep issue #54, branch 54-context-advice`.
- `dash .sdlc/scripts/next_step.sh 54 --after prove --result fail --keep x` -> the same two lines as under sh.
- `sh .sdlc/scripts/next_step.sh 54` with no `--after` -> only `Next: /sdlc:build 54`. skills/sdlc/next/SKILL.md step 1 keeps the `Next:` line, step 3 asks the subagent for the last `Context:` and `Next:` lines, and step 4 prints them as the last lines (criterion 8 pass).
- `env -u CLAUDECODE CODEX_THREAD_ID=t1 sh ...` and `SDLC_HARNESS=codex sh ...` with `--after prove --result fail` -> only `Next: $build 54`, with no Context line (Codex is #55).
- The script run in a new git repo with no settings, with `--after build` -> only `Next: /sdlc:setup`.
- `grep -n next_step.sh skills/sdlc/*/SKILL.md` -> all 12 skills (setup, frame, slice, shape, build, prove, submit, review, respond, document, ship, retro) print the script output "as the last lines". prove step 6, the stop for changed files or an app that does not run, now runs `next_step.sh --after prove --result fail --keep`, so that path gets a Context line too (the gap from the last run is closed). Only prove passes `--keep`.
- `grep -n "Next: /" skills/sdlc/*/SKILL.md` -> the only `Next:` lines printed without the script are the stops for missing settings, which the spec leaves without a Context line.
- `diff .sdlc/scripts/next_step.sh skills/sdlc/next/scripts/next_step.sh` -> no difference.
- `sh skills/sdlc/next/tests/run.sh` and `SH=dash sh skills/sdlc/next/tests/run.sh` -> `35 tests, 0 failed` each.

## Assumptions
- TESTING.md is a TODO stub, so the run has no QA guide. The real surface is the installed script `.sdlc/scripts/next_step.sh` run as a skill runs it, plus the SKILL.md steps that tell the agent what to print.
- `CLAUDECODE=1` stands for a Claude Code session, which is how the script detects one.
- The issue's acceptance criteria are the reference, not the changed spec. To fix criterion 5, either change its example on the issue to match the new decision or bring back compact after a build pass.

## Run 2026-11-21
Commit: 42d4dd96d669c28ce9caf4d0e1370a4f3c266160
Result: fail
### Steps
- `CLAUDECODE=1 sh .sdlc/scripts/next_step.sh 54 --after <skill> --result <pass|fail>` for frame, slice, shape, build, prove, submit, review, respond, document, ship, retro and setup -> each of the 24 runs printed two lines, a `Context:` line and then `Next:` as the last line. compact for build pass and prove fail. keep for prove pass, submit fail, document pass and fail, and frame fail. clear for all the others. Each line names one advice with a reason (criteria 2, 4, 5, 6 pass).
- The same `--after build` command run twice -> identical output (criterion 3 pass).
- `--after prove --result fail --keep "criterion 3 fails: two runs differ"` -> `Context: compact - the next step continues this work. Run /compact Keep issue #54, branch 54-context-advice, open items: criterion 3 fails: two runs differ`. The clear line names `Run /clear before the next command.` (criterion 7 pass).
- `sh .sdlc/scripts/next_step.sh - --after build --keep "lint fails"` -> `Run /compact Keep branch 54-context-advice, open items: lint fails`, with no issue in the list.
- `dash .sdlc/scripts/next_step.sh 54 --after build --keep x` -> the same two lines as under sh.
- `sh .sdlc/scripts/next_step.sh 54`, with no `--after` -> only `Next: /sdlc:build 54`, the line the `next` skill keeps. skills/sdlc/next/SKILL.md step 3 asks the subagent for the last `Context:` and `Next:` lines, and step 4 prints them as the last lines (criterion 8 pass).
- `CODEX_THREAD_ID=t1 sh ...` and `SDLC_HARNESS=codex sh ...` with `--after build` -> only `Next: $prove 54`, with no Context line (Codex is #55).
- The script run in a new git repo with no settings, with `--after build` -> only `Next: /sdlc:setup`.
- `grep -n next_step.sh skills/sdlc/*/SKILL.md` -> all 12 hand-off steps (setup, frame, slice, shape, build, prove, submit, review, respond, document, ship, retro) print the script output "as the last lines". build and prove pass `--keep`.
- `grep -n "Next: /" skills/sdlc/*/SKILL.md` -> the other places that print `Next:` without the script are the stops for missing settings, which the spec leaves without a Context line, and prove step 6. prove step 6 (a stop because of changed files or an app that does not run, with settings present) prints `Next: /prove <task>` directly, so that end of the prove skill has no `Context:` line (criterion 1 fails on this path).
- `sh skills/sdlc/next/tests/run.sh` and `SH=dash sh skills/sdlc/next/tests/run.sh` -> `35 tests, 0 failed` each.

## Assumptions
- TESTING.md is a TODO stub, so the run has no QA guide. The real surface is the installed script `.sdlc/scripts/next_step.sh` run as a skill runs it, and the SKILL.md steps that tell the agent what to print.
- `CLAUDECODE=1` stands for a Claude Code session, as the script detects it.

