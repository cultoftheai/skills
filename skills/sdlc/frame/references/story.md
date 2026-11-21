# Issue bodies

## Story or task (S, M, L)

Fill in the template at `templates.story`. If that file does not exist, use `assets/templates/story.md` and say so in the report.

At most about 30 lines. Use the project's own terms from the request and the code. Every acceptance criterion is behaviour that someone can observe without reading the code.

- When `issue.estimation` is `fibonacci`, add `Estimate: <1, 2, 3, 5, 8 or 13>` under the size line.
- Test each criterion: could someone who did not write the story say if it holds? If not, rewrite it.

## Epic (XL)

Fill in the template at `templates.epic`. If that file does not exist, use `assets/templates/epic.md` and say so in the report.

An epic has no acceptance criteria of its own. Each story under it gets only a title, its problem and its outcome. Its own `frame` run adds the rest.
