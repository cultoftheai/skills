# RETRO.md format

Path: `<task.path>/<task>/RETRO.md` for a feature retro. If the file exists, put the new run at the top, under the title, and keep the older runs.

Fill in the template at `templates.retro`. If that setting or file does not exist, use `assets/templates/retro.md` and say so in the report.

- Start each lesson line with its status in brackets. The next retro finds the rejected lessons with `grep -rh '^- \[rejected\]' <task.path>`.
- A sizing proposal uses the form `setting`. It names the key, the old value and the new value.
- A person changes `proposed` to `accepted` or `rejected` later.
