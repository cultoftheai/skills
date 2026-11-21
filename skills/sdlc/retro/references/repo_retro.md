# Repo retro

Read only the `RETRO.md` and `REVIEW.md` files under `<task.path>`. Do not run the transcript script. If `task.keep` is false, the folders of merged tasks exist only in git history. Find the files with `git log --diff-filter=D --name-only -- <task.path>` and read each one with `git show <commit>^:<file>`.

- **Promote.** A lesson or review concern that came back in two or more tasks did not stop the repeat. Propose the next form up: a note becomes a skill edit, a skill edit becomes a guide line, a guide line becomes a lint rule or a test.
- **Prune.** Propose to remove an accepted rule when a lint rule or a test now enforces the same thing, or when the code that it names no longer exists.
- **Record.** Write the proposals to `<task.path>/RETRO.md`, not to a task folder.
