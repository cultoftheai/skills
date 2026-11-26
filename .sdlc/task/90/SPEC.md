# Spec: Separate L-story design from shape and update vertical slicing

Task: #90. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on `t3/split-sdlc-phases`, not yet merged to `main`).
Size: L (story). Confirmed for this task: 3 modules (`skills/sdlc/design`, `skills/sdlc/shape`, `skills/sdlc/slice`), 17 files (8 new in `design`, 2 symlinks, 5 edited, 2 removed from `shape`), about 220 changed lines, no risk path.

## Data shape
- L-story design file: `<specs.path>/<id>-<slug>-design.md` (default `.sdlc/specs/`); branch `design/<id>-<slug>` from `origin/<default_branch>`; Design PR body uses `Design for #<id>` (never `Closes #<id>`).
- `specs.delivery`: `"pr"` opens the Design PR and keeps the story `ready` until merge (then `shaped`); `"direct"` commits the file (or posts `## DESIGN.md` per `spec.storage`) and marks `shaped`.
- `spec.review`: `"auto"` (or `--auto` when not `pr`) invokes `verify-spec` locally; `"manual"` stops for approval; `"pr"` defers review to the Design PR.
- `slice` reads `<specs.path>/<story>-*-design.md` on `<default_branch>` (falling back to story comments when `spec.storage` is `issue_comment`).

## Seam
- `skills/sdlc/design/SKILL.md`: new skill extracting L-story design from `shape`, placing its template at `assets/templates/design.md` (discovered by `setup/scripts/install.sh`) and exposing the skill via `.claude/skills/design` and `.agents/skills/design`.
- `skills/sdlc/shape/`: drops L-story handling (`templates.design`, `references/design.md`, `assets/templates/design.md`, and story branches in `SKILL.md`, `references/task_folder.md`, `references/auto_mode.md`), rejecting stories with a pointer to `design` (L) or `slice` (M).
- `skills/sdlc/slice/`: updates `SKILL.md` (reads `specs.path` and `<specs.path>/<story>-*-design.md`) and `references/slicing.md` to require independent A–Z vertical slices (deliverable before full feature completeness) and to place any shared data model / schema foundation first with blocking links to dependent slices.

## Files
- `skills/sdlc/design/SKILL.md`, `references/{design,delivery,auto_mode,tracker_github,tracker_jira,tracker_linear}.md`, `assets/templates/design.md` (new; template moved from `shape`) - Dedicated L-story design skill.
- `.claude/skills/design`, `.agents/skills/design` (new symlinks) - Point to `../../skills/sdlc/design`.
- `skills/sdlc/shape/{SKILL.md,references/task_folder.md,references/auto_mode.md}` (edited), `skills/sdlc/shape/{references/design.md,assets/templates/design.md}` (removed) - Keep `shape` task-only.
- `skills/sdlc/slice/{SKILL.md,references/slicing.md}` (edited) - Read `<specs.path>/<story>-*-design.md`; add A–Z vertical slicing and shared data-model-first rule.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py` passes (exit 0) for `skills/sdlc/design`, `skills/sdlc/shape`, and `skills/sdlc/slice` — proves house format and reference paths.
- `sh skills/sdlc/setup/tests/run.sh` passes and `install.sh` copies `design.md` into a temp repo's `.sdlc/templates/` once — proves template discovery.
- Walk-through checks verify symlinks resolve, `shape` rejects story inputs, and `slice` orders shared data models first as a blocking task — proves criteria.

## Open questions
- None.
