# RETRO.md format

Path: `<task.path>/<task>/RETRO.md` for a feature retro. If the file exists, put the new run at the top, under the title, and keep the older runs.

```markdown
# Retro of #<task>

## Run <ISO date>

Chat data: <the harnesses read, or none and the reason>

- [accepted] <lesson>. Form: <lint rule, test, guide line, skill edit, note or setting>. Target: <file or setting key>. Seen: <n> times.
- [rejected] <lesson>. Form: <form>. Target: <target>. Seen: <n> times. Reason: <why the user rejected it>.
- [proposed] <lesson>. Form: <form>. Target: <target>. Seen: <n> times.

## Assumptions

- <run date>: <what --auto decided without asking>
```

- Start each lesson line with its status in brackets. The next retro finds the rejected lessons with `grep -rh '^- \[rejected\]' <task.path>`.
- A sizing proposal uses the form `setting`. It names the key, the old value and the new value.
- A person changes `proposed` to `accepted` or `rejected` later.
