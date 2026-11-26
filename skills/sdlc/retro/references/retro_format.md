# retro.md format

Path: `<work.path>/<task>/retro.md` for a feature retro (fallback `.sdlc/work/<task>/retro.md`), never staged or committed. Ensure `<work.path>/<task>/` exists (`mkdir -p`; warn if `git check-ignore -q <work.path>` fails). If the file exists, put the new run at the top, under the title, and keep the older runs.

Fill in the template at `templates.retro`. If that setting or file does not exist, use `assets/templates/retro.md` and say so in the report.

- Start each lesson line with its status in brackets. The next retro finds the rejected lessons with `grep -rh '^- \[rejected\]' <work.path>` (and `<task.path>` when present).
- A sizing proposal uses the form `setting`. It names the key, the old value and the new value.
- A person changes `proposed` to `accepted` or `rejected` later.
