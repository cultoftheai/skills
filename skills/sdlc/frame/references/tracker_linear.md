# Linear

Do each operation with the Linear tool that is connected in the session. If no Linear tool is connected, ask the person to connect one, and go on after they have. With `--auto`, go to step 10 and name the missing tool.

## Search

Search with the key terms as the query.

- An issue is open when its state type is not `completed` or `canceled`.
- Report each match by its identifier, such as `ENG-12`, its title and its state.

## Create

Create the issue in the team of its parent, or in the team that the person names. To create it under an epic, set its parent issue. Linear shows it as a sub-issue.

## Edit

Update the description of the issue. Add labels to the issue. A Linear label must exist before you add it: create it in the team when it is missing.

## Comment

Add a comment to the issue. To update a comment, edit your own last comment.

## Size

Add the label `size:<size>` and remove every other size label: `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL`. Create a label when it is missing.

## Stage

Add the stage label and remove every other stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`. Create a label when it is missing.
