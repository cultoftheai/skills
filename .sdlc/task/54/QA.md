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

