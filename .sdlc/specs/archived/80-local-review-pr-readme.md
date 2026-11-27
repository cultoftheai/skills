# Spec: Show the local review in the PR and the README

Task: #80. Story: #60. Design: `.sdlc/task/60/DESIGN.md`.
Size: L (story). Confirmed for this task: 1 skill (`skills/sdlc/submit`) plus `README.md`, 3 files, about 12 changed lines, no risk path, no contract change.

## Data shape
- The record is now `<work-folder>/self-review.md` (uncommitted, from #79 and #93), not the `PR.md` of the design. `submit` reads only its `Status` and `Reviewed` fields.
- New body line under `## Evidence` in `assets/pr_body.md`: `Local review: ran before QA.` No counts, no findings, no path.

## Seam
- `submit` step 4 "Write body": keep the line when `<work-folder>/self-review.md` exists, its `Status` is `passed`, and its `Reviewed` commit is `HEAD` or an ancestor of `HEAD`. Remove it in every other case.
- `README.md` "Skill order": `build` goes to a new node `review --local` (ultra, fresh subagent). That node goes back to `build` with fixes, and to `prove` after a clean verify. `prove -->|fail| build` stays.

## Files
- `skills/sdlc/submit/assets/pr_body.md` - the `Local review: ran before QA.` line under the self-QA line of `## Evidence`.
- `skills/sdlc/submit/SKILL.md` - step 4: when to keep or remove the line.
- `README.md` - the mermaid chart as the seam says. Skill table: `build` row adds "Runs the local review before `prove`."; `review` row adds "a branch before its PR".

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/submit` exits 0.
- Throwaway XS branch with `<work.path>/xs/self-review.md` at `Status: passed` and a passing `self-qa.md`: `submit` writes a body with the one line and no finding detail (criterion 1).
- The same with no `self-review.md`: the body has no local review line (criterion 1).
- The README chart renders on GitHub (or `mmdc`) and shows `build -> review --local -> prove -> submit`; the skill table names the local review (criterion 2).

## Open questions
- None.
