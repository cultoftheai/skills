# Standalone run

Read this file when the repo has no `.sdlc/settings.json` or no `.sdlc/scripts/`. Do not stop for the missing files. Do the changes below and run the rest of the flow as written.

- **Settings.** If the settings file does not exist, use the defaults: `review.prefix` is `:robot:`, `review.resolve` is `reviewer`, `guides.code_review` is null, `task.path` is `.sdlc/task`.
- **Script.** Where the flow says `sh .sdlc/scripts/review_threads.sh`, run `sh <skill-dir>/scripts/review_threads.sh` from the repo root. `<skill-dir>` is the directory of this skill's SKILL.md.
- **REVIEW.md.** If the settings file does not exist, write `REVIEW.md` but do not commit it. Give the user its path.
- **Verify.** If the `prove` skill is not available, run the checks that the repo defines for the changed code. Use its test and lint commands, or the checks that run on the pull request. Report each command and its result to the user.
- **Hand-off.** If `.sdlc/scripts/next_step.sh` does not exist, write the `Next:` line yourself. If the `review` skill is available, print `Next: /review <pr>`. If not, print `Next: wait for review from <login>, then run /respond <pr>`. Add `--auto` to the command if it was passed. In Claude Code, print `Context: clear - the next step starts from the issue, the task folder or the PR. Run /clear before the next command.` just above it.
