# Search Jira issues

Use the Jira tool that is connected in the session with this JQL:

```
text ~ "<terms>" ORDER BY updated DESC
```

If no Jira tool is connected, ask the person to connect one, and search after they have. With `--auto`, go to step 10 and name the missing tool.

- Add `project = <KEY> AND` in front of the JQL when the request or the existing issue names a project.
- An issue is open when its status category is not `done`.
- Report each match by its key, such as `ABC-12`, its summary and its status.
