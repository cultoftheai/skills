# GitHub

## Search

```sh
gh issue list --state all --search "<terms>" --json number,title,state,url --limit 20
```

- `state` is `OPEN` or `CLOSED`. An `OPEN` issue is open.
- Run one search for each group of key terms when one search returns nothing useful.

## Create

`gh issue create --title "<title>" --body-file <file>`. Add `--type <type>` when `issue.types` has a type for the kind of issue: `epic`, `story`, `task`. Add `--parent <issue>` to create it under an epic.

## Edit

`gh issue edit <issue> --body-file <file>`. Add labels with `gh issue edit <issue> --add-label <names>`.

## Comment

`gh issue comment <issue> --body-file <file>`. Update your own last comment with `--edit-last`.

## Size

`sh .sdlc/scripts/size.sh <issue> <XS|S|M|L|XL>`

## Stage

Set it with `sh .sdlc/scripts/stage.sh <issue> <stage>`. The stage of an issue is its stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
