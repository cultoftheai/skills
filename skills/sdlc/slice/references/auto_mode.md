# Auto mode

With `--auto`, the skill does not confirm the breakdown. It stops only on a hard stop: no tool is connected for the tracker, the story is not `ready` (or, for an L story, not `shaped`), or an L story has no design.

- Skip step 6 and treat the breakdown as approved.
- Write each choice that a person would have confirmed (a task boundary, a blocking edge, the order) in a comment on the story, under an `## Assumptions` heading.
