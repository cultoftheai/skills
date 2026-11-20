# SPEC.md

At most about 40 lines. It says how this task is built. The issue says what and why, so link to it and do not repeat it.

```markdown
# Spec: <task title>

Task: #<task>. Story: #<story>. Design: <path or none>.
Size: <the size line, confirmed after reading the code>

## Data shape
<the types, records or messages that this task adds or changes>

## Seam
<where the change plugs in, and where a test can hold it>

## Files
- <path> - <what changes>

## Test plan
- <test> - <the criterion it proves>

## Open questions
- <question> - <who can answer it>
```

- Follow the patterns in the development guide and in the design.
- An open question that changes the data model or a public contract is not open: it is a hard stop (`references/resize.md`).
