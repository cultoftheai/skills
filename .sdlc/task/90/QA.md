# QA

## Run 2026-11-26T19:04:01Z
Commit: 681a9186639a389c2521345655ad29e020fec671
Result: pass
### Steps
- `python3 skills/misc/create-skill/scripts/lint_skill.py` on `skills/sdlc/design`, `skills/sdlc/shape`, and `skills/sdlc/slice` -> `PASS` for all three (`NOTE: mmdc not found; mermaid syntax not checked`).
- `readlink .claude/skills/design` and `readlink .agents/skills/design` -> both resolve to `../../skills/sdlc/design`.
- `sh skills/sdlc/setup/tests/run.sh` -> `47 tests, 0 failed`.
- `sh skills/sdlc/setup/scripts/install.sh "$tmp"` in a fresh temp git repo -> copied `.sdlc/templates/design.md` once and `diff -u` against `skills/sdlc/design/assets/templates/design.md` exited 0.
- `test ! -e skills/sdlc/shape/references/design.md && test ! -e skills/sdlc/shape/assets/templates/design.md` -> exited 0; `grep` confirmed `skills/sdlc/shape/SKILL.md` rejects stories (pointing to `design`/`slice`), `skills/sdlc/design/references/delivery.md` specifies `<specs.path>/<story>-<slug>-design.md` and `Design for #<story>` PRs, and `skills/sdlc/slice/references/slicing.md` specifies independent A–Z vertical slices with shared data models first as a blocking task.

## Assumptions
- `TESTING.md` contains only a placeholder TODO, so real-surface verification checked skill linting, symlink resolution, `setup` tests and `install.sh` template discovery in a temporary git repository, and the documented contracts in the skill files rather than executing a live tracker/PR run.
