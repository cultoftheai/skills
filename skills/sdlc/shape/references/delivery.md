# Branch, spec file, and delivery

- File path: `<specs.path>/<issue>-<slug>.md` (default `.sdlc/specs/<issue>-<slug>.md`), directly under `<specs.path>/`.
- Branch: `git fetch origin <default_branch>`, then `git switch -c spec/<issue>-<slug> origin/<default_branch>`. If the branch already exists, switch to it.
- Spec PR (`specs.delivery` = `pr`): commit `<specs.path>/<issue>-<slug>.md`, push `spec/<issue>-<slug>`, and open a PR whose body contains `Spec for #<issue>` (never `Closes #<issue>`, `Fixes #<issue>`, or `Resolves #<issue>`, so merging the spec does not close the task). Keep the task `ready` until the Spec PR merges; once merged, the task moves to `shaped`.
- Direct delivery (`specs.delivery` = `direct`): commit `<specs.path>/<issue>-<slug>.md` directly on the branch (or `<default_branch>`) and set the task stage to `shaped`.

## `spec.storage`

| Value | Where the spec goes |
|---|---|
| `local` | `<specs.path>/<issue>-<slug>.md`, committed on the branch |
| `issue_comment` | A comment on the issue starting with `## SPEC.md` (when `specs.delivery` is `pr`, still commit the file so the PR has a diff) |
| `both` | Commit `<specs.path>/<issue>-<slug>.md` as the source and post or update the matching comment on the issue |
