# Spec: Add verify-spec skill and narrow review to code diffs

Task: #91. Story: #87. Design: `.sdlc/task/87/DESIGN.md` (on branch `t3/split-sdlc-phases`).
Size: L (story). Confirmed for this task: 2 modules (`skills/sdlc/verify-spec`, `skills/sdlc/review`), 6 files (4 new, 2 modified), about 180 changed lines, no risk path.

## Data shape
- `verify-spec` targets: `<pr | issue | spec-or-design-path>` with optional `--local` and `--auto`.
  - PR target (`gh pr view <target>` succeeds and `--local` absent): fetches `pull/<pr>/head`, reads `gh pr diff <pr>`, resolves linked issue from `Spec for #<id>` / `Design for #<id>` in PR body (fallback `closingIssuesReferences`), posts one `COMMENT` review via `gh api repos/{owner}/{repo}/pulls/<pr>/reviews --input <file>` (`event: "COMMENT"`, `commit_id: <head-sha>`) with body prefix `<review.prefix> [spec]` and inline comments `<review.prefix> [spec] <severity>: <finding>` for findings on diff lines.
  - Local target (`--local`, file path, or non-PR issue): reads `<specs.path>/<issue>-*-design.md` or `<specs.path>/<issue>-*.md` (fallback `<task.path>/<issue>/DESIGN.md` or `SPEC.md`, or issue comment when `spec.storage` is `issue_comment`). For a flat file path, extracts issue number from leading `<id>-` or `Task: #<id>` / `Story: #<id>`. Posts nothing.
- Findings JSON (in temp folder outside repo): `[{severity, path, line, question, finding, evidence}]` (`severity`: `blocking | should-fix | nit`, max 5 findings, most severe first).
- `review` targets: `<pr | task | ->` with `--level`, `--local`, `--verify`, `--auto`; code diffs only.

## Seam
- `skills/sdlc/verify-spec/SKILL.md` starts one fresh-context subagent via `orchestrator` using `references/spec_brief.md` to check: (1) the 5 spec/design questions (`reviewer_brief.md` lines 25–31) and (2) every cited file path, symbol, and seam against the repository (flagging missing or mismatched citations as `blocking` when load-bearing, else `should-fix`).
- The parent verifies each finding's cited `path` and `line` exist before reporting or posting, then on a PR calls `sh .sdlc/scripts/next_step.sh <pr> --after verify-spec --result <pass|fail>` (with `--auto` if set; `pass` when no `blocking`/`should-fix` finding remains); local runs skip `next_step.sh` and return findings to the caller.
- `skills/sdlc/review/SKILL.md` and `references/reviewer_brief.md` drop `issue` (spec/design) and `spec-or-design-path` targets, `spec.storage`, the `Spec or design` input, and the 5 spec/design questions; non-PR targets without `--local` stop and point to `verify-spec`. `review --local` keeps `<task.path>`/`PR.md` until #93 migrates `build`.

## Files
- `skills/sdlc/verify-spec/SKILL.md` (new) - House-format skill flow (resolve target, collect inputs, run fresh subagent, verify citations, post PR review or report locally, hand off).
- `skills/sdlc/verify-spec/references/spec_brief.md` (new) - Subagent brief with the 5 spec/design questions, codebase citation checks, and JSON output schema.
- `.agents/skills/verify-spec` and `.claude/skills/verify-spec` (new symlinks) - Point to `../../skills/sdlc/verify-spec` matching sibling `sdlc` skills.
- `skills/sdlc/review/SKILL.md` - Narrow description, args, steps 2–6, and Output to PR and `--local` branch code diffs only.
- `skills/sdlc/review/references/reviewer_brief.md` - Remove spec/design target wording, input line, and 5 spec/design questions.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/verify-spec` and `.../lint_skill.py skills/sdlc/review` both exit 0 — proves house format, graph/step parity, and reference paths.
- Local run against a spec/design with a planted nonexistent file path and wrong symbol reports a finding citing the missing path/symbol without posting to GitHub — proves codebase citation checks and local mode.
- Throwaway Spec/Design PR run posts one `COMMENT` review starting with `<review.prefix> [spec]` with inline diff comments and calls `next_step.sh` — proves PR review format.
- `review <issue>` (non-PR, without `--local`) stops and directs to `verify-spec`, while `review <pr>` and `review <task> --local` still review code diffs — proves `review` is narrowed to code diffs.

## Open questions
- None.
