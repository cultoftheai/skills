# QA

## Run 2026-11-25T09:23:05Z
Commit: eecc7478cb434b502abe9c835ef33b2aa156daf6
Result: pass
### Steps
- Generated settings from `skills/sdlc/setup/assets/settings.schema.json` defaults and checked `specs` (`path: ".sdlc/specs"`, `archive_path: ".sdlc/specs/archived"`, `delivery: "pr"`, `on_ship: "archive"`), `work` (`path: ".sdlc/work"`), and `spec` (`storage: "local"`, `review: "pr"`); `sh skills/sdlc/setup/scripts/validate_settings.sh "$tmp/repo/.sdlc/settings.json"` -> `valid`.
- Validated a settings JSON containing legacy `.task` with `sh skills/sdlc/setup/scripts/validate_settings.sh "$tmp/legacy.json"` -> `task: unknown key`.
- Ran `sh skills/sdlc/setup/scripts/install.sh "$tmp/repo"` twice in a fresh git repo containing `node_modules/` in root `.gitignore` -> first run wrote scripts, templates, and `.sdlc/.gitignore` (`work/`); second run was idempotent with `.sdlc/.gitignore` still `work/` and root `.gitignore` unchanged (`node_modules/`).
- Checked `git -C "$tmp/repo" check-ignore -v` on `.sdlc/work/local.md`, `.sdlc/specs/99-example.md`, and `.sdlc/.gitignore` -> `.sdlc/work/local.md` ignored by `.sdlc/.gitignore:1:work/`; `.sdlc/specs/99-example.md` and `.sdlc/.gitignore` not ignored.
- Ran `sh skills/sdlc/setup/tests/run.sh` -> `47 tests, 0 failed`.
- Ran `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/setup` -> `PASS` (with `NOTE: mmdc not found; mermaid syntax not checked`).

## Assumptions
- `TESTING.md` contains only a placeholder TODO, so real-surface verification ran `validate_settings.sh`, `install.sh`, and `git check-ignore` against a temporary initialized git repository instead of modifying the repo's live `.sdlc/settings.json`.
