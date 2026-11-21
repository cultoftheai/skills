# GitHub

## Read

`gh issue view <issue> --json title,body,labels,comments`

## Create

`gh issue create --title "<title>" --body-file <file>`. Add `--parent <issue>` to create it under the story. Add `--blocked-by <numbers>` for its blockers.

## Edit

`gh issue edit <issue> --body-file <file>`. Add labels with `gh issue edit <issue> --add-label <names>`.

## Comment

`gh issue comment <issue> --body-file <file>`. Update your own last comment with `--edit-last`.

## Size

`sh .sdlc/scripts/size.sh <issue> <XS|S|M|L|XL>`

## Stage

`sh .sdlc/scripts/stage.sh <issue> <stage>`
