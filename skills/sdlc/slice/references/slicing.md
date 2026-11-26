# Slicing

## A good task

- It is a small, independent vertical slice A–Z. It cuts through every layer needed for one narrow outcome, so someone can deliver, use, and demo it alone even before full feature completeness.
- Avoid horizontal layer-only slices (such as backend-only or UI-only tasks), except for the shared foundations below.
- One developer can build it in one context window and ship it as one PR.
- It does not depend on a later task to be useful. It can depend on an earlier foundation or blocker through a blocking edge.

## Order

- Shared data model or schema foundation comes first as its own blocking task whenever multiple slices share new or changed entities, schemas, or migrations. Dependent slices block on it with native blocking links.
- Prefactoring that makes the change easy comes first, as its own task. It changes no behaviour.
- A wide mechanical change that cannot land in one slice gets three tasks in sequence: expand (add the new form next to the old one), migrate (move each user to the new form), contract (remove the old form).
- Add a blocking edge only when a task cannot start before the other one merges. Independent vertical slices have no edge between them and can run in parallel.

## Re-size

- One task: the story is an S (step 5).
- On an M story, more tasks than `sizing.m_max_tasks`: the story is an L. Set the size of the story to L as the tracker reference says, create no task, and stop. An L story needs a design before `slice`, so end the run with `next_step.sh <story> --after slice --result fail`.

## Task body

Fill in the template at `templates.task`. If that file does not exist, use `assets/templates/task.md` and say so in the report.

The blocking edges are native tracker links, not text in the body.
