---
name: ship
description: Use when an approved pull request is ready to merge. Checks the merge gates (a person's approval, green checks, no unanswered review thread, QA evidence for the head commit), merges, removes the task folder when the settings say so, and deletes the branch and worktree. Triggers - ship this PR, merge the PR, ship it, land this. Not for opening a PR or reviewing one.
argument-hint: [pr] [--auto]
---

## Dependencies

- **(cli tool) git** [Must] - Removes the task folder and deletes the branch and worktree.
- **(cli tool) gh** [Must] - GitHub official CLI. Reads the gates and merges the PR.
- **(cli tool) jq** [Must] - `ship_gates.sh` reads the PR and the settings with it.

## Args

- **pr** [Optional] - Number of the pull request. Default: the PR of the current branch.

## Flags

- **--auto** [Optional] - Merge without a typed confirmation, and record that on the issue. If absent, ask the person to confirm the merge.

## Flow Graph

```mermaid
flowchart TD
    A{1. Settings exist?}
    B[2. Run gates]
    C{3. Gates pass?}
    D{4. Folder to remove?}
    E[5. Remove task folder]
    F{6. Merge confirmed?}
    G[7. Merge and clean up]
    H[8. Hand off]

    A -->|Yes| B
    A -->|No| H
    B --> C
    C -->|Yes| D
    C -->|No| H
    D -->|Yes| E
    D -->|No| F
    E --> B
    F -->|Yes| G
    F -->|No| H
    G --> H
```

## Flow steps

1. **Settings exist?** - If `.sdlc/settings.json` exists, go to step 2. If not, stop and print `Next: /setup` as the last line, with `Context: clear - setup needs nothing from this session. Run /clear before the next command.` just above it in Claude Code.
2. **Run gates** - Get the PR with `gh pr view [pr] --json number,headRefName,closingIssuesReferences`. Fast-forward the PR branch to the PR head and do not push local commits. From the repository root, run `sh .sdlc/scripts/ship_gates.sh <pr>` and show its output.
3. **Gates pass?** - If the exit code is 0, go to step 4. If not, name each failed gate and who can clear it, then go to step 8 with result `fail`.
4. **Folder to remove?** - If `task.keep` is `false` and `<task.path>/<issue>/` exists, go to step 5. If not, go to step 6.
5. **Remove task folder** - Remove the folder with `git rm -r`, commit, and push to the PR branch. Wait with `gh pr checks <pr> --watch`. Go to step 2.
6. **Merge confirmed?** - Choose the first merge method that `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` allows, in that order. Without `--auto`, show the gate lines and the method, and ask the person to type `merge`. Any other answer goes to step 8 with result `fail`. With `--auto`, do not ask. Comment on the issue, or on the PR when it closes no issue, under `## Assumptions`: merged without a typed confirmation, and the method you chose.
7. **Merge and clean up** - Run `gh pr merge <pr> --<method> --match-head-commit <head>`, where `<head>` is `git rev-parse HEAD`. If `.github/workflows/sdlc-on-merge.yml` does not exist, run `sh .sdlc/scripts/on_merge.sh <pr>`. Delete the remote branch with `git push origin --delete <branch>`. A branch that the repository already deleted is not an error. Remove the worktree of the branch and the local branch. If this session runs inside that worktree, read `references/harness.md` first.
8. **Hand off** - Give the report from the Output section. Run `sh .sdlc/scripts/next_step.sh <pr> --after ship --result <pass|fail>`, with `--auto` if the flag is passed. Print its output as the last lines.

## Rules

1. Never merge without a person's approval on the PR. `--auto` removes the question, not a gate.
2. Do not approve the PR, dismiss a review or resolve a thread yourself to make a gate pass.
3. Do not merge with `--admin`, and do not pass this skill's `--auto` to `gh pr merge`.

## Output

- The merged PR. With `task.keep` set to `false`, the PR also removes the task folder.
- The issue at `done`, by the on-merge action or by `on_merge.sh`.
- A report: the gate lines, the merge commit, and what was cleaned up.
- The `Next:` line as the last line.
