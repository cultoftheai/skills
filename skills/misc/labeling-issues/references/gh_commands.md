# gh commands

All commands use the repository of the current directory. `gh api` fills `{owner}` and `{repo}` from that repository. Replace `<n>` with the issue number.

## Read commands

Issue:

```bash
gh issue view <n> --json number,title,body,state,author,labels,comments,url
```

Linked pull requests (open pull requests that close the issue, with their labels) and `blockedBy` dependencies:

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F n=<n> -f query='
query($owner: String!, $repo: String!, $n: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $n) {
      closedByPullRequestsReferences(first: 20) {
        nodes { number state isDraft url labels(first: 50) { nodes { name } } }
      }
      blockedBy(first: 20) {
        nodes { number state url }
      }
    }
  }
}'
```

Use only pull requests with `state` OPEN.

Dependencies named in the body ("blocked by #N", "depends on #N"):

```bash
gh issue view <N> --json number,state
```

`area:` labels of the repository:

```bash
gh label list --limit 1000 --json name --jq '.[].name | select(startswith("area: "))'
```

## Write commands

Run these commands only after the user confirms.

Labels (one command for all changes, comma-separated names):

```bash
gh issue edit <n> --add-label "<label>,<label>" --remove-label "<label>,<label>"
```

Comment (write the text to a temporary file first):

```bash
gh issue comment <n> --body-file <file>
```
