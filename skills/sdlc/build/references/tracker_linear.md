# Linear

Do each operation with the Linear tool that is connected in the session. If no Linear tool is connected, ask the person to connect one, and go on after they have. With `--auto`, go to step 7 and name the missing tool.

## Read

Get the issue with its title, description, status, labels and comments.

## Comment

Add a comment to the issue. To update a comment, edit your own last comment.

## Stage

Set the workflow state that `issue.stages` gives for the stage. When it gives `null`, add the stage label instead, and create the label in the team when it is missing. Then remove every other stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`. The stage of an issue is the stage whose workflow state it has, or else its stage label.
