# Standalone run

Read this file when the repo has no `.sdlc/settings.json` or no `.sdlc/scripts/`. Do not stop for the missing files. Do the changes below and run the rest of the flow as written.

- **Settings.** If the settings file does not exist, use the defaults: `review.prefix` is `:robot:`, `review.resolve` is `reviewer`, `guides.code_review` is `null`, `guides.development` is `null`, `specs.path` is `.sdlc/specs`, `work.path` is `.sdlc/work`.
- **Script.** Where the flow says `sh .sdlc/scripts/review_threads.sh`, run `sh <skill-dir>/scripts/review_threads.sh` from the repo root. `<skill-dir>` is the directory of this skill's `SKILL.md`.
- **review-triage.md.** Write `<work.path>/<id>/review-triage.md` locally without committing it. Give the user its path.
- **Verify.** On a Spec/Design PR (all diff paths under `<specs.path>/`), skip app QA (run `verify-spec --local` if available). On a Code PR, if `prove` is not available, run the checks that the repo defines for the changed code (test and lint commands, or the PR checks) and report each command and result.
- **Hand-off.** If `.sdlc/scripts/next_step.sh` does not exist, write the `Next:` line yourself. On a Spec/Design PR, print `Next: /verify-spec <pr>` when `verify-spec` is available. On a Code PR, print `Next: /review <pr>` when `review` is available. Otherwise print `Next: wait for review from <login>, then run /handle-review <pr>`. Add `--auto` to the command if it was passed.
