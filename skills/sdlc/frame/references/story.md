# Issue bodies

## Story or task (S, M, L)

At most about 30 lines. Use the project's own terms from the request and the code. Every acceptance criterion is behaviour that someone can observe without reading the code.

```markdown
## Problem
<what is wrong or missing now, in the project's terms>

## Who it is for
<the user, client or operator who gains>

## Outcome
<what is true when this ships>

## Acceptance criteria
- [ ] <observable behaviour>

## Out of scope
- <what a reader might expect that this does not do>

## Size
<the size line>
```

- When `issue.estimation` is `fibonacci`, add `Estimate: <1, 2, 3, 5, 8 or 13>` under the size line.
- Test each criterion: could someone who did not write the story say if it holds? If not, rewrite it.

## Epic (XL)

```markdown
## Goal
<the outcomes that belong together>

## Stories
- <one line for each outcome. The sub-issues hold the stories.>

## Size
<the size line>
```

An epic has no acceptance criteria of its own. Each story under it gets only a title, its problem and its outcome. Its own `frame` run adds the rest.
