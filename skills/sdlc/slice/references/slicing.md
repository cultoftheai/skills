# Slicing

## A good task

- It is a vertical slice. It goes through every layer that the behaviour needs, and someone can demo it alone.
- One developer can build it in one context window and ship it as one PR.
- It does not depend on a later task to be useful. It can depend on an earlier task through a blocking edge.

## Order

- Prefactoring that makes the change easy comes first, as its own task. It changes no behaviour.
- A wide mechanical change that cannot land in one slice gets three tasks in sequence: expand (add the new form next to the old one), migrate (move each user to the new form), contract (remove the old form).
- Add a blocking edge only when a task cannot start before the other one merges. Tasks without an edge can run in parallel.

## Re-size

- One task: the story is an S (step 5).
- On an M story, more tasks than `sizing.m_max_tasks`: the story is an L. Run `sh .sdlc/scripts/size.sh <story> L`, create no task, and stop. An L story needs a design before `slice`, so end the run with `next_step.sh <story> --after slice --result fail`.

## Task body

```markdown
## Goal
<what this slice delivers, in one or two sentences>

## Acceptance criteria
- [ ] <observable behaviour, taken from the story>

Story: #<story>
```

The blocking edges are native tracker links, not text in the body.
