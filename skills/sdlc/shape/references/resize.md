# Re-size

After reading the code, raise the size when one of these holds. A spec over its limit is a re-size, never a longer spec.

- The spec will not fit in about 40 lines.
- An open question would change the data model or a public contract. This is also the hard stop.
- The exact module count is `sizing.l_min_modules` or more.
- A file to change is under a glob in `sizing.risk_paths`.

How to raise it:

1. Raise the size on the story when the task has a parent, or on the task when it has none: `python3 .sdlc/scripts/size.py <issue> L`. When the spec is only too long, raise an S to M instead.
2. Release the claim: `python3 .sdlc/scripts/claim.py --release <task>`.
3. Write the signal that changed in a comment on the issue whose size changed. Write no spec.
