# Spec: Rename respond to handle-review and verify PRs with Official QA comments

Task: #94. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on `origin/t3/split-sdlc-phases`).
Size: L (story). Confirmed for this task: 5 modules (`skills/sdlc/handle-review`, `skills/sdlc/prove`, `skills/sdlc/ship`, `skills/sdlc/next`, `skills/sdlc/review`), about 20 files, no risk path.

## Data shape
- Triage log: `<work.path>/<id>/review-triage.md` (fallback `.sdlc/work/<id>/review-triage.md`), never staged or committed. `<id>` resolves from `closingIssuesReferences`, `Spec for #<id>` / `Design for #<id>` in the PR body, or `pr-<pr>`.
- Official QA PR comment (`gh pr comment <pr>`): `<review.prefix> [qa] <pass|fail>`, `Commit: <40-char headRefOid>`, `Date: <ISO date>`, `### Checks` (`- <command or action> -> <what you saw>`).
- Non-code exemption in `ship_gates.sh`: commits after a passing `[qa]` commit keep QA valid when carrying `SDLC-Docs-Only: true`, `SDLC-Spec-Archive: true`, or touching only `<specs.path>/`.

## Seam
- `skills/sdlc/handle-review/` (renamed from `respond/`, with `.agents/skills/handle-review` and `.claude/skills/handle-review` symlinks): reads `work.path` and `specs.path`, writes `<work.path>/<id>/review-triage.md`, skips app `prove` when `gh pr diff <pr> --name-only` touches only `<specs.path>/` (Spec/Design PR), runs `prove <task|-> --local` on changed Code PRs before push, and calls `next_step.sh <pr> --after handle-review`.
- `skills/sdlc/prove/`: keeps `--local [task|-]` unchanged; defaults to Official PR QA when `<target>` resolves to a PR without `--local`. Fetches `origin pull/<pr>/head`, runs one fresh-context subagent via `orchestrator` (`references/official_qa_brief.md`) on the clean PR head, verifies `headRefOid` and cited checks, posts one Official QA PR comment, and calls `next_step.sh <pr> --after prove --result <pass|fail>`.
- `skills/sdlc/ship/scripts/ship_gates.sh`: extends `PR_QUERY` with `comments(last: 100)` and `files(first: 100)`. `qa_gate` checks `local HEAD == headRefOid`, passes Spec/Design PRs (non-empty `files` all under `<specs.path>/`), or validates the newest `<review.prefix> [qa]` comment (`pass` and `Commit:` valid for `headRefOid`); drops `read_task_path`, `qa_before_removal`, `qa_check_in_worktree`, and `QA.md` / `sdlc/qa` checks.
- `skills/sdlc/next/scripts/next_step.sh`: replaces `respond` with `handle-review` and adds `verify-spec` and `design` in `SKILLS`; routes Spec/Design PRs (`Spec for #N` / `Design for #N`) to `verify-spec` / `ship`; routes clean Code PRs without `[qa] pass` to `prove <pr>`; updates `after_prove` for PRs and `gate_step` `qa` fail to `prove <pr>`.

## Files
- `skills/sdlc/handle-review/` (moved from `skills/sdlc/respond/`), `.agents/skills/handle-review`, `.claude/skills/handle-review` - Rename skill; update `SKILL.md`, `references/{review_format,auto_mode,standalone}.md`, and `assets/templates/review.md` for local `review-triage.md` and Spec/Design/Code PRs.
- `skills/sdlc/prove/SKILL.md`, `references/official_qa_brief.md` (new) - Add fresh-context Official PR QA mode and subagent brief.
- `skills/sdlc/ship/scripts/ship_gates.sh`, `tests/test_ship_gates.sh` (and `.sdlc/scripts/ship_gates.sh`) - Validate Official `[qa] pass` PR comment and non-code later commits.
- `skills/sdlc/next/scripts/next_step.sh`, `tests/test_next_step.sh` (and `.sdlc/scripts/next_step.sh`), `skills/sdlc/review/SKILL.md` - Update `respond` -> `handle-review`, `verify-spec` PR routing, and Official `prove <pr>` routing.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py` exits 0 on `handle-review`, `prove`, `ship`, `next`, and `review` — proves house format, graph/step parity, and reference links.
- `sh skills/sdlc/handle-review/tests/run.sh`, `sh skills/sdlc/prove/tests/run.sh`, `sh skills/sdlc/ship/tests/run.sh`, and `sh skills/sdlc/next/tests/run.sh` pass — proves `[qa]` PR comment gating, non-code commit exemptions, `handle-review` routing, and Official `prove <pr>` hand-offs.
- Symlink and diff checks verify `.agents/skills/handle-review` and `.claude/skills/handle-review` resolve and old `respond` paths are removed — proves rename cleanup.

## Open questions
- None.
