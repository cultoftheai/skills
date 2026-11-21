# Tracker mapping

Fill `issue.project`, `issue.stages`, `issue.size_field` and `issue.types` for the tracker that group 1 chose, so that the skills leave each tracker in about the same state. Show the mapping, and ask about each stage that maps to `null`: keep the label, or name a status.

## GitHub

- `issue.project`: `null`. `issue.stages`: all `null`, so the stage labels hold the stage. `issue.size_field`: `label`.
- `issue.types`: run `gh api orgs/<owner>/issue-types --jq '.[].name'`. It fails for a repository that a user owns: then all `null`. Match epic to `Epic` or `Feature`, story to `Story` or `Feature`, task and subtask to `Task`. Anything unmatched is `null`.
- Labels: `sh <skill-dir>/scripts/labels.sh --dry-run` lists the missing labels. Run it without `--dry-run` to create them.

## Jira

Use the Jira tool that is connected in the session. If none is connected, ask the person to connect one. With `--auto`, keep the schema defaults and list these keys as assumptions.

- `issue.project`: list the projects. Take the only one, or ask which one.
- `issue.stages`: read the statuses of the project. Match without case: ready to `Ready` or `To Do`, shaped to `Shaped`, in-progress to `In Progress`, review to `In Review` or `Review`, done to `Done`, blocked to `Blocked`. Anything unmatched is `null`.
- `issue.size_field`: `label`. Jira has no T-shirt field.
- `issue.types`: read the issue types of the project. Match epic to `Epic`, story to `Story`, task to `Task`, subtask to `Sub-task` or `Subtask`.
- Labels: Jira creates a label when an issue first gets it. Nothing to create.

## Linear

Use the Linear tool that is connected in the session. If none is connected, ask the person to connect one. With `--auto`, keep the schema defaults and list these keys as assumptions.

- `issue.project`: list the teams and use the team key. Take the only one, or ask which one.
- `issue.stages`: read the workflow states of the team. Match without case: ready to `Ready` or `Todo`, shaped to `Shaped`, in-progress to `In Progress`, review to `In Review`, done to `Done`, blocked to `Blocked`. Anything unmatched is `null`.
- `issue.size_field`: `estimate` when the team uses the T-shirt estimate scale. If not, `label`.
- `issue.types`: all `null`. Linear has no issue types. An epic or a story is a parent issue.
- Labels: the team needs the stage label of each stage that maps to `null`, and `size:XS` to `size:XL` when `issue.size_field` is `label`. Their names, colors and descriptions are in `scripts/label_lib.sh`. List the missing ones, and create them in the team with the tool.
