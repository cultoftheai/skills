# Branch, design file, and delivery

- File path: `<specs.path>/<story>-<slug>-design.md` (default `.sdlc/specs/<story>-<slug>-design.md`), directly under `<specs.path>/`.
- Branch: `git fetch origin <default_branch>`, then `git switch -c design/<story>-<slug> origin/<default_branch>`. If the branch already exists, switch to it.
- Design PR (`specs.delivery` = `pr`): commit `<specs.path>/<story>-<slug>-design.md`, push `design/<story>-<slug>`, and open a PR whose body contains `Design for #<story>` (never `Closes #<story>`, `Fixes #<story>`, or `Resolves #<story>`, so merging the design does not close the story). Keep the story `ready` until the Design PR merges; once merged, the story moves to `shaped`.
- Direct delivery (`specs.delivery` = `direct`): commit `<specs.path>/<story>-<slug>-design.md` directly on the branch (or `<default_branch>`) and set the story stage to `shaped`.

## `spec.storage`

| Value | Where the design goes |
|---|---|
| `local` | `<specs.path>/<story>-<slug>-design.md`, committed on the branch |
| `issue_comment` | A comment on the story starting with `## DESIGN.md` (when `specs.delivery` is `pr`, still commit the file so the PR has a diff) |
| `both` | Commit `<specs.path>/<story>-<slug>-design.md` as the source and post or update the matching comment on the story |
