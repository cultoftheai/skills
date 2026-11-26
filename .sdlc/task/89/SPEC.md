# Spec: Configure specs and work directories in setup

Task: #89. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (currently on `t3/split-sdlc-phases`, not yet merged to `main`).
Size: L (story). Confirmed for this task: 1 module (`skills/sdlc/setup`), 6 files, about 170 changed lines, no risk path.

## Data shape
- Replace top-level `task` (`path`, `keep`) in `assets/settings.schema.json` with two required objects (`additionalProperties: false`):
  - `specs`: `path` (string, `minLength: 1`, default `".sdlc/specs"`), `archive_path` (string, `minLength: 1`, default `".sdlc/specs/archived"`), `delivery` (`"pr" | "direct"`, default `"pr"`), `on_ship` (`"archive" | "delete" | "keep"`, default `"archive"`).
  - `work`: `path` (string, `minLength: 1`, default `".sdlc/work"`).
- Extend `spec.review` enum to `["pr", "auto", "manual", "off"]` with default `"pr"`.
- `.sdlc/.gitignore`: newline-delimited entries containing `<work-rel>/` (`work/` for default `.sdlc/work`).

## Seam
- `validate_settings.sh` is schema-driven via `assets/settings.schema.json`; updating the schema automatically validates the new keys and flags legacy `task` as `task: unknown key` so `setup` step 3 drops `task` and asks Group 4.
- `install.sh` gains a `setup_layout` helper called alongside `install_scripts` and `install_templates`: reads `specs.path`, `specs.archive_path`, and `work.path` from `<repo>/.sdlc/settings.json` when present (else schema defaults), runs `mkdir -p` for all three, and ensures `<repo>/.sdlc/.gitignore` has the `.sdlc/`-relative work entry without duplicating lines, losing existing entries, or editing root `.gitignore`. If `work.path` is outside `.sdlc/`, warn to stderr and leave root `.gitignore` untouched.
- This repo's own `.sdlc/settings.json` and `.sdlc/scripts/settings.schema.json` stay unchanged in #89 so un-migrated skills (`shape`, `build`, `submit`, `ship`) keep working until #90–#95 land.

## Files
- `skills/sdlc/setup/assets/settings.schema.json` - Replace `task` with `specs` and `work`; add `"pr"` (default) to `spec.review`.
- `skills/sdlc/setup/scripts/install.sh` - Add `setup_layout` to create `<specs.path>`, `<specs.archive_path>`, `<work.path>`, and idempotently maintain `.sdlc/.gitignore`.
- `skills/sdlc/setup/references/walkthrough.md` - Update Group 4 (`Specs and work`) for `specs.*`, `work.path`, `spec.storage`, `spec.review`, and `templates.*`.
- `skills/sdlc/setup/SKILL.md` - Update step 8 and Output to include the specs, archive, and work folders and `.sdlc/.gitignore`.
- `skills/sdlc/setup/tests/test_validate_settings.sh` - Update `VALID` fixture; add tests for `specs.*`, `work.path`, `spec.review: "pr"`, and rejecting `task`.
- `skills/sdlc/setup/tests/test_install.sh` - Add tests for directory creation, `.sdlc/.gitignore` creation/idempotency/preservation, untouched root `.gitignore`, and custom paths from `settings.json`.

## Test plan
- `sh skills/sdlc/setup/tests/run.sh` passes all `test_validate_settings.sh` tests, including schema-default validation, `specs.delivery` (`pr`/`direct`), `specs.on_ship` (`archive`/`delete`/`keep`), `spec.review` (`pr`), and legacy `task` rejection — proves settings schema and defaults.
- `sh skills/sdlc/setup/tests/run.sh` passes all `test_install.sh` tests: creates `.sdlc/specs/`, `.sdlc/specs/archived/`, `.sdlc/work/`, writes `work/` to `.sdlc/.gitignore`, preserves existing lines without duplicates on re-run, leaves root `.gitignore` untouched, and respects custom paths — proves repository layout and gitignore behavior.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/setup` exits 0 — proves skill structure and links stay valid.

## Open questions
- None.
