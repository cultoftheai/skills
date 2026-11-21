# Search Linear issues

Use the Linear tool that is connected in the session, if there is one, with the key terms as its query.

If no Linear tool is connected, call the GraphQL API at `https://api.linear.app/graphql`. Ask the person for an API key, and never write it to a file:

```graphql
query {
  searchIssues(term: "<terms>", first: 20) {
    nodes { identifier title url state { name type } }
  }
}
```

- Send it with `curl -s -H "Authorization: <key>" -H "Content-Type: application/json" -d '{"query": "<the query>"}' https://api.linear.app/graphql`.
- An issue is open when `state.type` is not `completed` or `canceled`.
- Report each match by its identifier, such as `ENG-12`, its title and its state.
