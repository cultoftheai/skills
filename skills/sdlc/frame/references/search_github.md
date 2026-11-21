# Search GitHub issues

```sh
gh issue list --state all --search "<terms>" --json number,title,state,url --limit 20
```

- `state` is `OPEN` or `CLOSED`. An `OPEN` issue is open.
- Run one search for each group of key terms when one search returns nothing useful.
