# Search Jira issues

Use the Jira tool that is connected in the session, if there is one, with this JQL:

```
text ~ "<terms>" ORDER BY updated DESC
```

If no Jira tool is connected, call the REST API. Ask the person for the site URL and an API token, and never write the token to a file:

```sh
curl -s -u "<email>:<token>" --get "https://<site>/rest/api/3/search/jql" \
  --data-urlencode 'jql=text ~ "<terms>" ORDER BY updated DESC' \
  --data-urlencode 'fields=summary,status' --data-urlencode 'maxResults=20'
```

- Add `project = <KEY> AND` in front of the JQL when the request or the existing issue names a project.
- An issue is open when `fields.status.statusCategory.key` is not `done`.
- Report each match by its key, such as `ABC-12`, its summary and its status.
