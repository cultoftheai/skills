# QA

## Run 2026-11-26T20:38:23+01:00
Commit: e75559c7e760f1b6bccf70757d6566f9770d01d8
Result: pass
### Steps
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/shape` and `lint_skill.py skills/sdlc/setup` -> both printed `PASS` (`NOTE: mmdc not found; mermaid syntax not checked`).
- `sh skills/sdlc/setup/tests/run.sh` -> printed `52 tests, 0 failed` (covering `test_specs.sh` and existing setup tests).
- `sh skills/sdlc/setup/scripts/install.sh` into a temp git repo with `origin` pointing to `cultoftheai/skills`, followed by creating `.sdlc/specs/92-flat-task-specs.md`, `.sdlc/specs/87-story-design.md`, and `.sdlc/specs/archived/10-old.md` and running `sh .sdlc/scripts/specs.sh` against real `gh` -> installed `.sdlc/scripts/specs.sh` alongside the other scripts and printed `#92 .sdlc/specs/92-flat-task-specs.md [unclaimed]` (excluding `87-story-design.md` and `archived/10-old.md`).
- Fresh-context subagent run of `skills/sdlc/shape/SKILL.md` for `1 --auto` in `/tmp/qa-92-shape/repo` (`specs.delivery: "pr"`, `spec.review: "pr"`, bare `origin`, faked `gh` logging `issue view` and `pr create`) -> created and pushed `spec/1-add-punctuation-option-to-greet` (`5674c9d43848ca3d7f32a7e1c6f141f4dd94e793`), committed `.sdlc/specs/1-add-punctuation-option-to-greet.md`, called `gh pr create --base main --title "Spec for #1: Add punctuation option to greet" --body-file .sdlc/work/spec-pr-1.md` with body `Spec for #1` (no `Closes #1`), left issue #1 `ready`, and printed `Next: /sdlc:verify-spec 10`.
- Cleanup -> removed temporary repo and `/tmp/qa-92-shape`; `git status --porcelain` clean.

## Assumptions
- `TESTING.md` contains only a placeholder TODO, so real-surface QA verified `specs.sh` via `install.sh` + real `gh` in a temp repo pointing at `cultoftheai/skills` and verified `shape` in a fresh subagent against a temporary git/bare-remote fixture with a fake `gh` CLI so no test issues or Spec PRs were left on GitHub.
- `next_step.sh` is updated for Spec PRs in a sibling task of `#87`, so `shape` step 10 falling back to `Next: /sdlc:verify-spec 10` is expected until `next_step.sh` is migrated.
