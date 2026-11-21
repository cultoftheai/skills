# Jira

Do each operation with the Jira tool that is connected in the session. If no Jira tool is connected, ask the person to connect one, and go on after they have. With `--auto`, go to step 10 and name the missing tool.

## Search

Search with this JQL:

```
text ~ "<terms>" ORDER BY updated DESC
```

- Add `project = <KEY> AND` in front of the JQL when the request or the existing issue names a project.
- An issue is open when its status category is not `done`.
- Report each match by its key, such as `ABC-12`, its summary and its status.

## Create

Create the issue in the project of its parent, or in the project that the person names. A story is the `Story` type, a task the `Task` type and an epic the `Epic` type. To create it under an epic, set its parent to the epic key.

## Edit

Update the description of the issue. Add labels to the issue. A Jira label has no spaces.

## Comment

Add a comment to the issue. To update a comment, edit your own last comment.

## Size

Add the label `size:<size>` and remove every other size label: `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL`.

## Stage

Add the stage label and remove every other stage label: `ready`, `shaped`, `in-progress`, `review`, `done`, `blocked`.
