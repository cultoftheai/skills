# Linear

Do each operation with the Linear tool that is connected in the session. If no Linear tool is connected, ask the person to connect one, and go on after they have. With `--auto`, go to step 10 and name the missing tool.

## Search

Search the team `issue.project` with the key terms as the query.

- An issue is open when its state type is not `completed` or `canceled`.
- Report each match by its identifier, such as `ENG-12`, its title and its state.

## Create

Create the issue in the team `issue.project`. Linear has no issue types. To create it under an epic, set its parent issue.

## Edit

Update the description of the issue. Add labels to the issue. A Linear label must exist before you add it: create it in the team when it is missing.

## Comment

Add a comment to the issue. To update a comment, edit your own last comment.

## Size

When `issue.size_field` is `estimate`, set the T-shirt estimate to the size. When it is `label`, add the label `size:<size>` and remove every other size label: `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL`. Create a label in the team when it is missing.

## Stage

Set the workflow state that `issue.stages` gives for the stage. When it gives `null`, add the stage label instead, and create the label in the team when it is missing. Then remove every other stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`. The stage of an issue is the stage whose workflow state it has, or else its stage label.
