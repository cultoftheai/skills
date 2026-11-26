# QA

## Run 2026-11-26T20:08:15+01:00
Commit: fc9f11c1b62af046116211c62d5406cce9382ebf
Result: pass
### Steps
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/verify-spec` and `lint_skill.py skills/sdlc/review` -> both printed `PASS` (`NOTE: mmdc not found; mermaid syntax not checked`); `readlink .agents/skills/verify-spec .claude/skills/verify-spec` -> `../../skills/sdlc/verify-spec`.
- `verify-spec /tmp/qa-91-spec.md --local` in a fresh subagent from `skills/sdlc/verify-spec/SKILL.md` -> launched fresh verifier subagent with `references/spec_brief.md`; reported 5 findings (3 `blocking`, 2 `should-fix`) in `/tmp/verify-spec-qa-cYHvV0/findings.json`, catching planted missing file `skills/sdlc/verify-spec/nonexistent.md`, missing symbol `verify_spec_helper`, and missing seam `install_spec_layout` in `skills/sdlc/setup/scripts/install.sh`, plus 5-question answers; posted nothing to GitHub and printed no `Next:` line.
- `verify-spec 97 --auto` in a fresh subagent against throwaway draft Spec PR #97 (`qa-91-fixture`, head `43aa0f1`, body `Spec for #91`, `.sdlc/specs/91-qa-fixture.md`) -> resolved `#91`, posted `COMMENT` review `https://github.com/cultoftheai/skills/pull/97#pullrequestreview-6079317493` (`6079317493`) with body prefix `:robot: [spec]`, 5-question summary, and 4 inline diff comments (`:robot: [spec] <severity>:`); `sh .sdlc/scripts/next_step.sh 97 --after verify-spec --result fail --auto` exited 2 because `next_step.sh` does not yet include `verify-spec` in `SKILLS`.
- `review 91` (non-PR, without `--local`) in a fresh subagent from `skills/sdlc/review/SKILL.md` -> stopped at step 2 with "`review` only reviews pull requests or `--local` branch diffs (use `verify-spec` for specs and designs)", started 0 subagents, and wrote nothing to GitHub.
- `review 91 --local` in a fresh subagent -> started 3 fresh reviewers (`criteria`, `guide`, `consistency`), wrote findings under `/tmp/review-91-f1TU54/`, posted nothing to GitHub, and printed no `Next:` line.
- `sh skills/sdlc/next/tests/run.sh` -> `31 tests, 0 failed`.
- Cleanup: closed throwaway PR #97, deleted remote/local branch `qa-91-fixture`, removed `/tmp/qa-91-tree` and `/tmp/qa-91-spec.md`.

## Assumptions
- `TESTING.md` contains only a placeholder TODO, so real-surface QA ran `verify-spec` and `review` in fresh subagents from the skill files on disk using temporary local and throwaway draft PR fixtures.
- `next_step.sh` (routing `--after verify-spec`), `shape` (invoking `verify-spec`), and `README.md` are updated in sibling tasks of `#87` (`#92` and the routing/docs task), so `next_step.sh` exiting 2 on `--after verify-spec` and cross-skill consistency findings against un-migrated `shape`/`next_step.sh`/`README.md` are expected until those tasks land.
