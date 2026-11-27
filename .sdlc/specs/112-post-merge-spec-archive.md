# Spec: Move spec archiving to post-merge cleanup PR

Task: #112. Story: none. Design: none.
Size: S (confirmed after re-frame: 1 module `skills/sdlc/ship` + its synced copy `.sdlc/scripts/on_merge.sh`, 7 files, ~555 changed lines of which ~180 are the synced copy, no risk path).

## Data shape
- Cleanup branch & PR: one `sdlc/<issue>-cleanup` per closed issue (so `specs.sh` sees the spec as claimed), targeting `<baseRefName>`, opened only for merged Code PRs (`closingIssuesReferences` non-empty and at least one changed file outside `<specs.path>/`) when matching files exist for `specs.on_ship` (`archive` -> `<specs.path>/<issue>-*.md` excluding `*-design.md` and `<specs.archive_path>/`; `delete`) or `task.keep == false` (`<task.path>/<issue>/`).
- Cleanup commit: trailer `SDLC-Spec-Archive: true`; commit and PR title `Clean up spec for #<issue>`; PR body `Cleanup for PR #<pr>` (no `Closes #N`).
- `on_merge.sh` output after the stage line: `Nothing to clean up.` (`keep`), `Only specs changed. Nothing to clean up.`, or per issue `Opened cleanup PR <url> for #<issue>.`, `Cleanup PR #<n> for #<issue> is already open.` or `Nothing to clean up for #<issue>.`
- Workflow `skills/sdlc/ship/assets/sdlc-on-merge.yml`: `pull-requests: write`, a `github-actions[bot]` git identity, and a comment naming the prerequisite repository setting "Allow GitHub Actions to create and approve pull requests". With it off, `gh pr create` fails: the stage is already set, `on_merge.sh` exits 1 with `cannot open cleanup PR for #<issue>: <err>` and the run is red. A `GITHUB_TOKEN` PR starts no CI; both are noted in the `ship` Output.

## Seam
- `skills/sdlc/ship/SKILL.md`: remove pre-merge steps 4–5, renumber to 6 steps (merge is step 5), and document that `on_merge.sh` opens the cleanup PR; `ship` merges the approved head untouched.
- `skills/sdlc/ship/scripts/on_merge.sh` (copied verbatim to `.sdlc/scripts/on_merge.sh`): add `baseRefName` to the `pr_summary` query; after the stage update, when `.sdlc/settings.json` exists and the stage is `done`, read `specs.path`/`archive_path`/`on_ship` and `task.path`/`keep` with `ship`'s fallbacks, skip when every changed file (`gh pr view --json files`) is under `<specs.path>/`, fetch `origin/<baseRefName>`, and per issue list matching paths, skip if none or its cleanup PR is open, else commit in a temp `git worktree`, push, and `gh pr create`.
- Tests hold it with the fake `gh` and a real git origin/clone fixture in `helpers.sh`.
- `ship_gates.sh`, `qa_check.sh`: unchanged (exemptions stay).

## Files
- `skills/sdlc/ship/SKILL.md` - Remove the pre-merge loop and its mentions (description, git dependency, Output); document the cleanup PR.
- `skills/sdlc/ship/references/harness.md` - Step reference 7 -> 5.
- `skills/sdlc/ship/scripts/on_merge.sh`, `.sdlc/scripts/on_merge.sh` - Cleanup PR creation.
- `skills/sdlc/ship/assets/sdlc-on-merge.yml` - Permission and git identity.
- `skills/sdlc/ship/tests/test_on_merge.sh`, `skills/sdlc/ship/tests/helpers.sh` - Cases below.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/ship` exits 0 - valid flow graph and steps.
- `sh skills/sdlc/ship/tests/run.sh` (also `SH=dash`) passes - `archive`, `delete`, `task.keep=false`, `keep`, no match, Spec PR skip, specs-only PR skip, one cleanup PR per closed issue, open cleanup PR not duplicated, failed `gh pr create` exits 1 and removes the worktree, existing `ship_gates.sh` exemptions.
- `sh skills/sdlc/prove/tests/run.sh` passes - `qa_check.sh` exemptions intact.

## Assumptions
- The review-limit check counts the verbatim copy `.sdlc/scripts/on_merge.sh`; without it the diff is ~375 lines, under `sizing.review_limit` (400). The size stays S and the overage is accepted for this task.
- Merging the cleanup PR is out of scope (issue). A `task.keep=false` cleanup touches files outside `specs.path`, so `ship_gates.sh` asks it for a `[qa]` pass like any PR.
- A rerun force-pushes `sdlc/<issue>-cleanup` so a branch left by a failed `gh pr create` does not block the retry.

## Open questions
- None.
