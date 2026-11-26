# Branch, task folder and storage

- Branch: `git fetch origin <default_branch>`, then `git switch -c <issue>-<short-slug> origin/<default_branch>`. If the branch exists, switch to it.
- Folder: `<task.path>/<issue>/`. Create only the files that this skill writes. No empty templates.

## `spec.storage`

| Value | Where the file goes |
|---|---|
| `local` | The file in the task folder, committed on the branch |
| `issue_comment` | A comment on the issue that starts with `## SPEC.md`. No file |
| `both` | The file is the source. Post the same text as a comment, and update the comment when the file changes |
