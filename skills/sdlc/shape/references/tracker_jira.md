# Jira

Do each operation with the Jira tool that is connected in the session. If no Jira tool is connected, ask the person to connect one, and go on after they have. With `--auto`, go to step 10 and name the missing tool.

## Read

Get the issue with its title, description, status, labels, parent, sub-issues and comments.

## Comment

Add a comment to the issue. To update a comment, edit your own last comment.

## Size

Add the label `size:<size>` and remove every other size label: `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL`.

## Stage

Move the issue to the status that `issue.stages` gives for the stage. When it gives `null`, add the stage label instead. Then remove every other stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`. The stage of an issue is the stage whose status it has, or else its stage label.
