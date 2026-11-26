# Spec: Archive specs on ship and move retro logs to .sdlc/work

Task: #95. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on `t3/split-sdlc-phases`).
Size: S (confirmed for this task under L story #87: 2 modules — `skills/sdlc/ship`, `skills/sdlc/retro` — 7 files, ~90 changed lines, no risk path).

## Data shape
- Archived spec path: `<specs.archive_path>/<filename>` (default `.sdlc/specs/archived/<filename>`), moved from `<specs.path>/<task>-*.md` (excluding `*-design.md` and `<specs.archive_path>/`) in a commit ending with trailer `SDLC-Spec-Archive: true` (already exempted in `ship_gates.sh` and `qa_check.sh`).
- Local retro logs (never staged or committed): `<work.path>/<task>/retro.md` (feature retro) and `<work.path>/retro.md` (`--repo` retro), reading `<work.path>/<task>/review-triage.md` (fallback `<task.path>/<task>/REVIEW.md`).
- Spec/Design PR merge stage update: `on_merge.sh` reads `body` alongside `closingIssuesReferences` and sets `shaped` via `stage.sh` on `<id>` when `closingIssuesReferences` is empty and `body` contains `Spec for #<id>` or `Design for #<id>`.

## Seam
- `skills/sdlc/ship/SKILL.md` (steps 1–2, 4–5, 7, Output): reads `specs.path` (fallback `.sdlc/specs`), `specs.archive_path` (fallback `.sdlc/specs/archived`), `specs.on_ship` (fallback `archive`), `task.path` (fallback `.sdlc/task`), and `task.keep` (fallback `true`). On a Code PR (skipped when all diff files in `gh pr diff <pr> --name-only` are under `<specs.path>/`), when a matching task spec exists and `specs.on_ship` is `archive` (`mkdir -p` + `git mv` to `<specs.archive_path>/`) or `delete` (`git rm`), commits with `SDLC-Spec-Archive: true`, pushes, waits on `gh pr checks <pr> --watch`, and loops to step 2; `keep` skips to step 6. Preserves `task.keep == false` fallback for legacy `<task.path>/<issue>/`.
- `skills/sdlc/ship/scripts/on_merge.sh` (and `.sdlc/scripts/on_merge.sh`): extends `pr_summary` (`gh pr view "$1" --json state,body,closingIssuesReferences`) to set `shaped` on `Spec for #<id>` / `Design for #<id>` targets when `closingIssuesReferences` is empty.
- `skills/sdlc/retro/SKILL.md`, `references/repo_retro.md`, `references/retro_format.md`: replace `<task.path>/<task>/REVIEW.md` and `RETRO.md` with `<work.path>/<task>/review-triage.md` and `<work.path>/<task>/retro.md` (falling back to `<task.path>` or git history only for legacy task folders), write `--repo` output to `<work.path>/retro.md`, scan rejected lessons under `<work.path>` (plus `<task.path>` if present), ensure `<work.path>/` exists (`warn` if `git check-ignore -q <work.path>` fails), and never stage or commit `<work.path>/`.

## Files
- `skills/sdlc/ship/SKILL.md` - Archive or delete task spec per `specs.on_ship` with `SDLC-Spec-Archive: true` before merge; skip on Spec/Design PRs.
- `skills/sdlc/ship/scripts/on_merge.sh`, `.sdlc/scripts/on_merge.sh`, `skills/sdlc/ship/tests/test_on_merge.sh` - Set `shaped` on Spec/Design PR merge and test both Code and Spec/Design PRs.
- `skills/sdlc/retro/SKILL.md`, `skills/sdlc/retro/references/repo_retro.md`, `skills/sdlc/retro/references/retro_format.md` - Move retro inputs/outputs to `<work.path>/<id>/` (`<work.path>/retro.md` for `--repo`) with legacy fallback.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/ship` and `skills/sdlc/retro` exit 0 — proves house format, flow graph/step parity, and reference links.
- `sh skills/sdlc/ship/tests/run.sh` passes including new `test_on_merge.sh` cases for `Spec for #N` / `Design for #N` -> `shaped` — proves `on_merge.sh` and `ship_gates.sh` (`SDLC-Spec-Archive: true`) pass together.
- `sh skills/sdlc/retro/tests/run.sh` passes — proves `transcript_extract.sh` continues passing alongside updated retro docs.

## Open questions
- None.
