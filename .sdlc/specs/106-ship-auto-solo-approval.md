# Spec: Let ship --auto count as approval in a solo repo

Task: #106 (blocked by #105, spec in `.sdlc/specs/105-solo-maintainer-ship-approval.md`). Story: #71. Design: none.
Size: S (confirmed under M story #71: 1 module — `skills/sdlc/ship` — 2 files, ~35 changed lines, no risk path).

## Data shape
- `--auto` solo approval record posted by `ship` (`gh pr comment <pr>`, never on the issue): `<review.prefix> [approval] approved by --auto for @<author>`.
- Reuses `#105`'s `<review.prefix> [approval]` author PR comment contract (`.sdlc/specs/105-solo-maintainer-ship-approval.md`), so `ship_gates.sh` needs no flag or logic change and produces `approval: pass - approved by <author> (solo approval)`.
- Existing `--auto` merge-confirmation comment in step 6 (`## Assumptions` on the closed issue, or on the PR when it closes no issue) stays unchanged.

## Seam
- `skills/sdlc/ship/SKILL.md`:
  - **Flags (`--auto`)**: note that in solo mode with no approval yet, `--auto` also counts as approved and records that on the PR.
  - **Step 3 (`Gates pass?`)**: extend `#105`'s solo-approval branch (`C -->|Solo approved| B` in Flow Graph, using `review.prefix` from step 1 and `author` from step 2, triggered only when `approval` is the sole failed gate with `no solo approval from <author>`). When `--auto` is passed, skip the chat prompt, post `<review.prefix> [approval] approved by --auto for @<author>` via `gh pr comment <pr>`, and loop to step 2. Post at most once per run: if posting fails or the step 2 re-run still fails `approval` (e.g. `gh` is authenticated as a different account than `<author>`), stop and go to step 8 with result `fail`. If any other gate (`checks`, `threads`, `qa`) fails or `approval` fails for another reason (`changes requested by ...`, `GitHub review decision is ...`, or multi-maintainer `no approval from a person`), fail to step 8 without posting.
  - **Rules 1–2**: allow `--auto` solo-mode recording on the PR when `approval` is the sole failed gate with `no solo approval from <author>`, keeping multi-maintainer repos, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, GitHub review approvals, `--admin`, and `gh pr merge --auto` unchanged.
- `skills/sdlc/ship/scripts/ship_gates.sh` (synced to `.sdlc/scripts/ship_gates.sh`): no code changes beyond `#105`; `#105`'s `approval_gate()` already accepts non-minimized `$author` (`User`) PR comments starting with `<review.prefix> [approval]` in solo mode and rejects them with 2+ writers or `CHANGES_REQUESTED` / `REVIEW_REQUIRED`.
- `skills/sdlc/ship/tests/test_ship_gates.sh`: building on `#105`'s `fake_collaborators` and author-aware `comment()` helpers, add regression tests locking `<review.prefix> [approval] approved by --auto for @dev` against `approval_gate()`.

## Files
- `skills/sdlc/ship/SKILL.md` - Document solo `--auto` approval in Flags, extend step 3's solo branch with once-per-run `gh pr comment` recording and loop to step 2, and update Rules 1–2.
- `skills/sdlc/ship/tests/test_ship_gates.sh` - Add cases proving `<review.prefix> [approval] approved by --auto for @dev` passes in solo mode (default and custom `review.prefix`), fails on `CHANGES_REQUESTED` / `REVIEW_REQUIRED`, and fails in multi-maintainer mode.

## Test plan
- `sh skills/sdlc/ship/tests/run.sh` (and with `SH=dash`) passes with new `--auto` approval comment cases (solo pass with default and custom `review.prefix`, fail with `CHANGES_REQUESTED` / `REVIEW_REQUIRED`, fail with 2+ writers) — proves the PR record format satisfies `ship_gates.sh` only in solo mode without relaxing blocking-review or multi-maintainer gates.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/ship` exits 0 — proves `SKILL.md` house format, Flow Graph/step parity, and reference links.
- Fresh-context local QA run of `ship <pr> --auto` on a solo PR fixture with no approval yet (verifying no chat prompt, `<review.prefix> [approval] approved by --auto for @<author>` posted on the PR, gate re-run passing with `approved by <author> (solo approval)`, and merge completing) plus negative checks (multi-maintainer repo or another failed gate stops without posting) — proves the `#106` acceptance criterion end to end.

## Open questions
- None.
