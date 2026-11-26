# GitHub

## Read

`gh issue view <issue> --json title,body,labels,parent,subIssues,comments`

## Comment

`gh issue comment <issue> --body-file <file>`. Update your own last comment with `--edit-last`.

## Open Spec PR

`gh pr create --base <default_branch> --title "Spec for #<issue>: <title>" --body-file <file>` (include `Spec for #<issue>`, never `Closes #<issue>`).

## Size

`sh .sdlc/scripts/size.sh <issue> <XS|S|M|L|XL>`

## Stage

Set it with `sh .sdlc/scripts/stage.sh <issue> <stage>`. The stage of an issue is its stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
