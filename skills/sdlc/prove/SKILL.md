---
name: prove
description: Use when a built change must be shown to work before it goes to review. Runs the change on its real surface (the running app, the real endpoint, the real command), then records the commit, every step and the result in self-qa.md. Triggers - prove the task, verify the change, run QA, check it works. Not for writing tests or fixing code.
argument-hint: "[task] [--local] [--auto]"
---

## Dependencies

- **(cli tool) git** [Must] - Names the commit under test and checks for uncommitted code changes.
- **(cli tool) gh** [Must] - Reads the acceptance criteria on the issue.

## Args

- **task** [Optional] - Issue number of the task. Default: none, for XS work, which has no issue.

## Flags

- **--local** [Optional] - Runs author-side self-QA and writes `<work.path>/<id>/self-qa.md` without committing (default for `[task]` or `-`).
- **--auto** [Optional] - Adds `--auto` to the `Next:` line. The run asks nothing in either mode.

## Flow Graph

```mermaid
flowchart TD
    A{1. Settings exist?}
    B[2. Load context]
    C{3. Ready to run?}
    D[4. Run checks]
    E[5. Record run]
    F[6. Stop]
    G[7. Hand off]

    A -->|No| F
    A -->|Yes| B
    B --> C
    C -->|No| F
    C -->|Yes| D
    D --> E
    E --> G
```

## Flow steps

1. **Settings exist?** - If `.sdlc/settings.json` exists, go to step 2. If not, go to step 6.
2. **Load context** - Read `work.path` (fallback `.sdlc/work`), `specs.path` (fallback `.sdlc/specs`), `specs.archive_path` (fallback `.sdlc/specs/archived`), `task.path` (fallback `.sdlc/task`), `spec.storage`, and `guides.qa` from `.sdlc/settings.json`. The work folder is `<work.path>/<task>/`, or `<work.path>/xs/` for XS work (`-` or omitted); create it with `mkdir -p`, never stage or commit it, and warn if `git check-ignore -q <work.path>` fails. Read the acceptance criteria with `gh issue view <task>` and the test plan from `<specs.path>/<task>-*.md` (excluding `*-design.md` and `<specs.archive_path>/`), falling back to `<task.path>/<task>/SPEC.md` or the issue comment `## SPEC.md` when `spec.storage` is `issue_comment`. If `guides.qa` is null, say that the run has no QA guide.
3. **Ready to run?** - Run `git status --porcelain -- . ":!<work.path>"`. If any file outside `<work.path>/` has changes, go to step 6, because the evidence must name a commit. Start the app, or reach the endpoint or command, as the QA guide says. If it does not run, go to step 6. If it runs, go to step 4.
4. **Run checks** - For each acceptance criterion, check the behaviour where a user, API client or operator meets it. Write down the exact command or action and what you saw.
5. **Record run** - Add the run at the top of `<work-folder>/self-qa.md` in the format below; never commit `self-qa.md`. On a pass, run `sh .sdlc/scripts/qa_check.sh <work-folder>` and fix `self-qa.md` until it exits 0. Go to step 7.
6. **Stop** - Write nothing to `self-qa.md`. Say why the run stopped: no settings, the changed files, or what you tried and the error. Print `Next: /setup` when the settings are missing. If not, print `Next: /prove <task> --local` to run after the fix, with `--auto` when this run has it.
7. **Hand off** - Run `sh .sdlc/scripts/next_step.sh <task or -> --after prove --result <pass|fail>`, with `--auto` when this run has it. Print its output as the last line.

```
## Run <ISO date>
Commit: <full sha of HEAD>
Result: pass|fail
### Steps
- <command or action> -> <what you saw>
```

## Rules

1. A check passes only on the real surface. A clean build and green tests are not a pass for behaviour that a user, API client or operator sees.
2. The run is a pass only when every check passed. A check that you skipped or could not run makes the run a fail.
3. Write what you saw, not what you expected. On a fail, write enough for `build` to reproduce it.
4. Do not change code. `build` fixes what `prove` finds.
5. Never edit an older run. `self-qa.md` is text only, so describe a screen in words.
6. Write each assumption, such as how you started the app without a QA guide, under an `## Assumptions` heading directly below the run.
