# GitHub

## Read

`gh issue view <issue> --json title,body,labels,comments`

## Comment

`gh issue comment <issue> --body-file <file>`. Update your own last comment with `--edit-last`.

## Stage

Set it with `sh .sdlc/scripts/stage.sh <issue> <stage>`. The stage of an issue is its stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
