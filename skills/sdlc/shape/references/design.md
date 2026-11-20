# DESIGN.md

At most 200 lines. It holds only the decisions that two or more tasks share. A decision that only one task needs goes in that task's spec later.

```markdown
# Design: <story title>

Story: #<story>

## Data model
<entities, fields and relations that change, and the migration>

## Changed contracts
<each endpoint, event, command or schema that changes, before and after>

## Module boundaries
<which module owns what, and the new dependencies between them>

## Patterns to follow
<existing code that the tasks copy, by path>```

- Leave out a section that has no shared decision.
- If no section has a shared decision, the story is not an L. Lower it with `python3 .sdlc/scripts/size.py <story> M` and write no design.
