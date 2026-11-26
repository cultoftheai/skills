# GitHub

## Read

`gh issue view <story> --json title,body,labels,parent,subIssues,comments`

## Comment

`gh issue comment <story> --body-file <file>`. Update your own last comment with `--edit-last`.

## Open Design PR

`gh pr create --base <default_branch> --title "Design for #<story>: <title>" --body-file <file>` (include `Design for #<story>`, never `Closes #<story>`).

## Size

`sh .sdlc/scripts/size.sh <story> <XS|S|M|L|XL>`

## Stage

Set it with `sh .sdlc/scripts/stage.sh <story> <stage>`. The stage of an issue is its stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
