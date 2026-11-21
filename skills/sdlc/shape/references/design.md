# DESIGN.md

At most 200 lines. It holds only the decisions that two or more tasks share. A decision that only one task needs goes in that task's spec later.

Fill in the template at `templates.design`. If that file does not exist, use `assets/templates/design.md` and say so in the report.

- Leave out a section that has no shared decision.
- If no section has a shared decision, the story is not an L. Lower it with `sh .sdlc/scripts/size.sh <story> M` and write no design.
