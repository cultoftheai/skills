# Spec: Run build self-review and self-QA in .sdlc/work and open clean Code PRs

Task: #93. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on `t3/split-sdlc-phases`).
Size: L (story). Confirmed for this task: 4 modules (`skills/sdlc/build`, `skills/sdlc/prove`, `skills/sdlc/review`, `skills/sdlc/submit`), 10 files (1 new, 9 edited including `.sdlc/scripts/qa_check.sh`), about 200 changed lines, no risk path.

## Data shape
- Local working folder: `<work.path>/<task>/` (fallback `.sdlc/work/<task>/`), or `<work.path>/xs/` for XS work (replacing `<task.path>/<task>/` and `git rev-parse --git-path sdlc/qa`). Never staged or committed.
- `<work-dir>/self-review.md`: local self-review table (`# Local review`, `Reviewed: <short sha>. Verified: <short sha or "no">. Status: <open, stopped, re-size or passed>.`, rows with `# | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify`).
- `<work-dir>/self-qa.md`: local self-QA log (`## Run <ISO date>`, `Commit: <full sha>`, `Result: pass|fail`, `### Steps`).
- Non-code commit trailers in `qa_check.sh`: `SDLC-Docs-Only: true`, `SDLC-Spec-Archive: true`, or commits touching only `<specs.path>/` (fallback `.sdlc/specs/`) do not invalidate a prior passing QA commit.

## Seam
- `build` branches from `origin/<default_branch>` (`<task>-<slug>` or keeps existing `in-progress` branch), reads the merged spec at `<specs.path>/<task>-*.md` (excluding `*-design.md` and `<specs.archive_path>/`; fallback `<task.path>/<task>/SPEC.md` or issue comment), builds units, runs `references/local_review.md` (`review <ref> --local` -> `<work-dir>/self-review.md` -> fix -> `review <ref> --local --verify`), then runs `prove <ref> --local` (`<work-dir>/self-qa.md`). On QA failure, `build` fixes with `root-cause`, commits, checks `sizing.review_limit`, and loops back to local review until both pass, then runs `next_step.sh <ref> --after prove --result pass` (`Next: /sdlc:submit <ref>`).
- `review` (`--local` and `--local --verify`) switches its local folder from `<task.path>` / `sdlc/qa` to `<work.path>/<task|xs>/`, excludes `:!<work.path>` from the branch diff, and reads `<folder>/self-review.md` instead of `PR.md`.
- `prove` adds `--local` (used by `build`, and default for `[task]`/`-` until Official `<pr>` QA lands in #94): verifies clean working tree outside `<work.path>/`, runs checks against the real surface, writes `<work-dir>/self-qa.md` without committing, and runs `qa_check.sh <work-dir>`.
- `qa_check.sh` reads `<dir>/self-qa.md` (temporary fallback `<dir>/QA.md` only when `self-qa.md` is absent, keeping un-migrated `ship_gates.sh` working until #94) and exempts `SDLC-Spec-Archive: true` and `<specs.path>/`-only commits in `commit_stale_files`.
- `submit` checks `git diff --name-only origin/<default_branch>...HEAD` and `git status` for any files under `<work.path>/`, runs `qa_check.sh <work-dir>`, fills `assets/pr_body.md` (in a temp file outside the repo) with the merged spec link and local `self-qa.md` evidence, and opens a clean Code PR.

## Files
- `skills/sdlc/build/SKILL.md`, `references/local_review.md` (new), `references/auto_mode.md` - Branch from merged spec; add local self-review + `prove --local` loop in `<work.path>/<id>/`.
- `skills/sdlc/review/SKILL.md` - Point `--local` and `--local --verify` to `<work.path>/<task|xs>/self-review.md`.
- `skills/sdlc/prove/SKILL.md`, `scripts/qa_check.sh` (synced to `.sdlc/scripts/qa_check.sh`), `tests/test_qa_check.sh` - Add `--local` self-QA in `<work-dir>/self-qa.md` (uncommitted); update `qa_check.sh` and tests.
- `skills/sdlc/submit/SKILL.md`, `assets/pr_body.md` - Gate on `qa_check.sh <work-dir>` and clean diff (no `<work.path>/` files); link merged spec in PR body.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py` exits 0 on `skills/sdlc/build`, `skills/sdlc/prove`, `skills/sdlc/review`, and `skills/sdlc/submit` — proves house format, graph/step parity, and reference links.
- `sh skills/sdlc/prove/tests/run.sh` and `sh skills/sdlc/setup/tests/run.sh` pass — proves `qa_check.sh` validates `self-qa.md`, rejects stale/failed runs, exempts `SDLC-Docs-Only`/`SDLC-Spec-Archive`/`<specs.path>/`, and keeps `install.sh` intact.
- Walk-through in a temp git repo verifies `build`/`prove --local` leave `self-review.md` and `self-qa.md` untracked in `.sdlc/work/<id>/`, `qa_check.sh` passes for HEAD, and `submit` rejects tracked `.sdlc/work/` files — proves clean Code PR contract.

## Open questions
- None.
