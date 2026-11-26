# Repo retro

Read only the `retro.md` and `review-triage.md` files under `<work.path>/*/` (plus any legacy `RETRO.md` and `REVIEW.md` files under `<task.path>`, or from git history via `git log --diff-filter=D --name-only -- <task.path>` and `git show <commit>^:<file>` when `task.keep` is false). Do not run the transcript script.

- **Promote.** A lesson or review concern that came back in two or more tasks did not stop the repeat. Propose the next form up: a note becomes a skill edit, a skill edit becomes a guide line, a guide line becomes a lint rule or a test.
- **Prune.** Propose to remove an accepted rule when a lint rule or a test now enforces the same thing, or when the code that it names no longer exists.
- **Record.** Write the proposals to `<work.path>/retro.md`, not to a task folder, and never stage or commit it.
