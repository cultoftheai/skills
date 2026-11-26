# Spec: Deliver flat task specs via Spec PRs and list approved specs

Task: #92. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on branch `t3/split-sdlc-phases`).
Size: L (story). Confirmed for this task: 2 modules (`skills/sdlc/shape`, `skills/sdlc/setup`), 8 files (3 new, 4 edited, 1 deleted), about 180 changed lines, no risk path.

## Data shape
- Task spec file: `<specs.path>/<id>-<slug>.md` (default `.sdlc/specs/<id>-<slug>.md`), branch `spec/<id>-<slug>` from `origin/<default_branch>`, PR body includes `Spec for #<id>` (never `Closes #<id>`, `Fixes #<id>`, or `Resolves #<id>`).
- `specs.delivery`: `"pr"` opens the Spec PR and keeps the task `ready` until merge (then `shaped`); `"direct"` commits the file (or posts `## SPEC.md` per `spec.storage`) and marks `shaped`.
- `spec.review`: `"auto"` (or `--auto` when not `"pr"`) runs `verify-spec` locally; `"manual"` stops for approval; `"pr"` defers review to the Spec PR.
- `specs.sh` output line per approved task spec (`*.md` directly under `<specs.path>/`, excluding `*-design.md` and subdirectories such as `archived/`): `#<id> <path> [unclaimed|PR #<n>|branch <ref>]` (or `<path> [<status>]` if unnumbered), sorted by id/filename.

## Seam
- `skills/sdlc/shape/` mirrors `skills/sdlc/design/`: step 1 reads `specs.*` (fallback `.sdlc/specs`, `pr`) instead of `task.path`; step 4 creates `spec/<issue>-<slug>` without `<task.path>/<issue>/`; step 7 writes `<specs.path>/<issue>-<slug>.md`; step 8 delegates automated spec verification to `verify-spec` instead of `review`; step 9 delivers via Spec PR or direct commit/comment; step 10 runs `next_step.sh` and falls back to `verify-spec <pr>` when a Spec PR was opened.
- `skills/sdlc/setup/scripts/specs.sh` follows `ready.sh`: reads `specs.path` from `.sdlc/settings.json` (fallback `.sdlc/specs`), lists top-level `*.md` excluding `*-design.md` (missing dir prints nothing, exits 0), queries open PRs via `gh pr list` (exits 1 if `gh` fails) and local/remote refs via `git for-each-ref` (ignoring `spec/*` and `design/*` branches) to report claim status. `install.sh` (`install_scripts`) installs it automatically into `.sdlc/scripts/`.

## Files
- `skills/sdlc/shape/SKILL.md` - Switch steps 1, 4, 7–10, Output, and Rules to flat `<specs.path>/<id>-<slug>.md`, `verify-spec`, and `specs.delivery`.
- `skills/sdlc/shape/references/delivery.md` (new, replaces `references/task_folder.md`, deleted) - Spec path, `spec/<id>-<slug>` branch, Spec PR / direct delivery, and `spec.storage` table.
- `skills/sdlc/shape/references/spec.md`, `references/auto_mode.md`, `references/tracker_github.md` - Reference `<specs.path>/<id>-<slug>.md`, `verify-spec`, and `## Open Spec PR`.
- `skills/sdlc/setup/scripts/specs.sh` (new), `skills/sdlc/setup/tests/test_specs.sh` (new) - List approved task specs with PR/branch claim status and test filtering, sorting, claim detection, and `gh` failure.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/shape` exits 0 — proves house format, step/graph parity, and `references/` links (including removal of `task_folder.md`).
- `sh skills/sdlc/setup/tests/run.sh` passes all existing setup tests plus `test_specs.sh` (flat `*.md` only, excludes `archived/` and `*-design.md`, custom `specs.path`, unclaimed/PR/branch claims, missing dir, `gh` error) — proves approved spec listing and script discovery.

## Open questions
- None.
