# GitHub

## Read

`gh issue view <issue> --json title,body,labels,comments`

## Create

`gh issue create --title "<title>" --body-file <file>`. Add `--type <type>` when `issue.types` has a type for the kind of issue: `epic`, `story`, `task`, or `subtask` for a task under the story. Add `--parent <issue>` to create it under the story. Add `--blocked-by <numbers>` for its blockers.

## Edit

`gh issue edit <issue> --body-file <file>`. Add labels with `gh issue edit <issue> --add-label <names>`.

## Comment

`gh issue comment <issue> --body-file <file>`. Update your own last comment with `--edit-last`.

## Size

`sh .sdlc/scripts/size.sh <issue> <XS|S|M|L|XL>`

## Stage

Set it with `sh .sdlc/scripts/stage.sh <issue> <stage>`. The stage of an issue is its stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
