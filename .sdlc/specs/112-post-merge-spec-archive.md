# Spec: Move spec archiving to post-merge cleanup PR

Task: #112. Story: none. Design: none.
Size: S (confirmed: 1 module `skills/sdlc/ship` + synced `.sdlc/scripts/on_merge.sh`, 6 files, ~200 lines, no risk path).

## Data shape
- Cleanup branch & PR: `sdlc/cleanup-<pr>` targeting `<baseRefName>`, opened only for merged Code PRs (`closingIssuesReferences` non-empty) when matching files exist for `specs.on_ship` (`archive` -> `<specs.path>/<issue>-*.md` excluding `*-design.md` and `<specs.archive_path>/`; `delete`) or `task.keep == false` (`<task.path>/<issue>/`).
- Cleanup commit: trailer `SDLC-Spec-Archive: true`; PR body references `Cleanup for PR #<pr>` (no `Closes #N`) so it is eligible for future auto-merge without re-closing issues.
- Workflow permissions in `skills/sdlc/ship/assets/sdlc-on-merge.yml`: add `pull-requests: write` alongside `contents: write` and `issues: write`.

## Seam
- `skills/sdlc/ship/SKILL.md`: remove pre-merge steps 4–5 (`Spec or folder to update?` / `Update spec or folder`) and update the flow graph, steps 1/3/7/8, and Output so `ship` merges the approved PR head untouched and relies on `sdlc-on-merge.yml` or `on_merge.sh` for post-merge cleanup PR creation.
- `skills/sdlc/ship/scripts/on_merge.sh` (synced to `.sdlc/scripts/on_merge.sh`): after setting issue stages, read settings (`specs.path`, `specs.archive_path`, `specs.on_ship`, `task.path`, `task.keep`) when `.sdlc/settings.json` exists; skip Spec/Design PRs, `keep` (when `task.keep` is not `false`), or when no matching spec/folder exists on `origin/<baseRefName>`; otherwise apply changes in a temporary `git worktree` from `origin/<baseRefName>`, push `sdlc/cleanup-<pr>` (skipping if already open), and run `gh pr create --base <baseRefName>`.
- `skills/sdlc/ship/scripts/ship_gates.sh` & `.sdlc/scripts/qa_check.sh`: unchanged; keep `SDLC-Spec-Archive: true` and `<specs.path>/` exemptions for backwards compatibility.

## Files
- `skills/sdlc/ship/SKILL.md` - Remove pre-merge spec move/push loop; document post-merge cleanup PR flow.
- `skills/sdlc/ship/scripts/on_merge.sh`, `.sdlc/scripts/on_merge.sh` - Add idempotent post-merge cleanup PR creation in a temp worktree.
- `skills/sdlc/ship/assets/sdlc-on-merge.yml` - Grant `pull-requests: write` (and git author fallback if needed) for cleanup PR creation.
- `skills/sdlc/ship/tests/test_on_merge.sh`, `skills/sdlc/ship/tests/helpers.sh` - Cover `archive`, `delete`, `task.keep=false`, `keep`, Spec PR skip, and no-op cases.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/ship` exits 0 — proves valid skill flow graph, steps, and references.
- `sh skills/sdlc/ship/tests/run.sh` passes — proves `on_merge.sh` cleanup PR logic (`archive`, `delete`, `keep`, `task.keep=false`, Spec PR skip, idempotency) and existing `ship_gates.sh` `SDLC-Spec-Archive: true` compatibility.
- `sh skills/sdlc/prove/tests/run.sh` passes — proves `qa_check.sh` `SDLC-Spec-Archive: true` compatibility remains intact.

## Open questions
- None.
