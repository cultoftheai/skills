# Spec: Let a solo maintainer approve their own PR in ship

Task: #105. Story: #71. Design: none.
Size: S (confirmed under M story #71: 1 module — `skills/sdlc/ship` — 5 files including `.sdlc/scripts/ship_gates.sh`, ~120 changed lines, no risk path).

## Data shape
- Solo mode: computed from `gh api 'repos/{owner}/{repo}/collaborators?affiliation=all&permission=push&per_page=100'`. Active iff the response is a JSON array with `length < 100` and `[.[] | select(.type == "User" and .permissions.push == true) | .login] == [$author]` (non-bot writers equal to PR author). Any API error or non-array response fails closed to `false`.
- Author solo approval comment on the PR (`pullRequest.comments`, never issue comments): non-minimized comment with `.author.login == $author` and `(.author.__typename // "User") == "User"` whose first non-empty trimmed line either starts with `<review.prefix> [approval]` or matches `^(/approve|approve|approved|lgtm)[.!]*$` (case-insensitive).
- Chat approval record posted by `ship` (`gh pr comment <pr>`): `<review.prefix> [approval] approved in chat by @<author>`.
- `approval` gate lines in `ship_gates.sh`: unchanged in multi-maintainer mode and for `CHANGES_REQUESTED` / `REVIEW_REQUIRED`; in solo mode, `approval: pass - approved by <author> (solo approval)` when an author approval comment exists, or `approval: fail - no solo approval from <author>` when none exists.

## Seam
- `skills/sdlc/ship/scripts/ship_gates.sh` (synced to `.sdlc/scripts/ship_gates.sh`): extend `PR_QUERY` `comments(last: 100)` nodes to `{ body isMinimized author { __typename login } }`. Add `is_solo_author()` (called only when no `CHANGES_REQUESTED` review and no non-author `User` `APPROVED` review exist) and `approval_gate()` (mirroring `checks_gate()` and `qa_gate()`), passing `--argjson solo` and `--arg prefix "$PREFIX"` into `APPROVAL`. Evaluate `CHANGES_REQUESTED` before solo approval, and `reviewDecision` (`CHANGES_REQUESTED` / `REVIEW_REQUIRED`) before passing or prompting solo approval.
- `skills/sdlc/ship/SKILL.md`: in step 1 read `review.prefix` (fallback `:robot:`); in step 2 include `author` in `gh pr view`; in step 3 (and Flow Graph `C -->|Solo approved| B`), when `approval` is the only failed gate with `no solo approval from <author>` and `--auto` is absent, ask the maintainer in chat to approve — on yes, post the chat approval record with `gh pr comment <pr>` and loop to step 2; on no, fail and go to step 8 with `fail`. Update Rules 1–2 for solo PR comments and chat-confirmed recording (leaving `--auto` solo approval to #106).
- `skills/sdlc/ship/tests/helpers.sh` & `test_ship_gates.sh`: sanitize rule keys in fake `gh` / `fake_gh` (non-alphanumerics -> `_`) so REST collaborator calls can be faked; default `setup()` to two `User` writers (`dev`, `lead`) and add `fake_collaborators` and author-aware `comment()` helpers.

## Files
- `skills/sdlc/ship/scripts/ship_gates.sh`, `.sdlc/scripts/ship_gates.sh` - Add solo-maintainer detection and author PR approval comment handling in `approval_gate()`.
- `skills/sdlc/ship/SKILL.md` - Prompt for chat approval on solo `no solo approval from <author>`, record via `gh pr comment`, re-run gates, and update Rules 1–2.
- `skills/sdlc/ship/tests/helpers.sh`, `skills/sdlc/ship/tests/test_ship_gates.sh` - Support REST `fake_gh` rules and test solo detection, approval comments, chat record format, `CHANGES_REQUESTED`, and multi-maintainer parity.

## Test plan
- `sh skills/sdlc/ship/tests/run.sh` (and with `SH=dash`) passes with new cases: solo detection ignores bots and read/triage users, rejects external/bot PR authors, fails closed on API error or `length == 100`; author comments (`LGTM`, `/approve`, `Approved!`, `<review.prefix> [approval] ...`) pass with `approved by dev (solo approval)`; non-approval comments (QA comments, prose, minimized comments, non-author comments) fail with `no solo approval from dev`; `CHANGES_REQUESTED` and `REVIEW_REQUIRED` still fail in solo mode; 2+ writers fail on author approval comments with `no approval from a person` — proves criteria 1, 2, 4, 5, 6.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/ship` exits 0 — proves `SKILL.md` house format, Flow Graph/step parity, and reference links.
- Fresh-context local QA run of `ship` on a solo PR fixture with no approval yet (testing both "yes" -> `gh pr comment` + gate re-run + pass, and "no" -> stops with approval gate failed) — proves criterion 3.

## Open questions
- None.
