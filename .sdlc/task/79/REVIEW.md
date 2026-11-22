# Review of #86

## Round 2, 2026-11-22T23:28:08Z

| Thread | Reviewer | Concern | Severity | Confidence | Outcome | Evidence |
|---|---|---|---|---|---|---|
| https://github.com/cultoftheai/skills/pull/86#discussion_r4660476057 | jakubtobiasz | A PR.md left by a verify stop looks settled, because verify rows had no Decision | major | high | fix | 4bd7988 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4660476065 | jakubtobiasz | A re-size leaves PR.md uncommitted | minor | high | fix | d7271ea |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4660476067 | jakubtobiasz | The settle rule does not name the columns to change | nit | high | fix | 133fab1 |

## Round 1, 2026-11-22T20:46:56Z

| Thread | Reviewer | Concern | Severity | Confidence | Outcome | Evidence |
|---|---|---|---|---|---|---|
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941378 | jakubtobiasz | A re-size or an old XS record looks settled, so the review is skipped | major | high | fix | 529e589, d465057 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941380 | jakubtobiasz | A row not fixed after a verify has no way to be settled | major | high | fix | 529e589 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941383 | jakubtobiasz | A new nit recommended stop after the verify reaches prove | minor | high | fix | 64eb8e8 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941385 | jakubtobiasz | For XS, PR.md is also written, not only the report as criterion 8 says | nit | medium | needs-you | The design (approved by the person) keeps PR.md in the XS folder; the criterion text of #79 and #60 should say so. A person decides whether to edit the issue text. |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941387 | jakubtobiasz | A re-size in the fix loop has two hand-offs | minor | high | fix | 1dfa1a5 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941388 | jakubtobiasz | Same as 1, from the consistency reviewer | major | high | fix | 529e589, d465057 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941391 | jakubtobiasz | A settled PR.md with only skip rows, or a not-fixed row, is not reused | major | high | fix | 529e589 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941394 | jakubtobiasz | The note under the PR.md format contradicts the Verify values | nit | high | fix | 984ae17 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941396 | jakubtobiasz | Spec data shape lets build change a recommendation either way | nit | high | fix | 0663021 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941400 | jakubtobiasz | Spec says step 5 runs after each fix and "seven steps" | nit | high | fix | 0663021 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941403 | jakubtobiasz | Spec wording of the fail hand-off differs from the script | nit | high | fix | 0663021 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941404 | jakubtobiasz | The stop hand-off has no --auto | nit | high | fix | 1dfa1a5 |
| https://github.com/cultoftheai/skills/pull/86#discussion_r4659941408 | jakubtobiasz | Every --after review on an in-progress issue is read as a local review | nit | medium | needs-you | The design (.sdlc/task/60/DESIGN.md, Changed contracts) says a spec review runs before in-progress. A person decides whether a spec review of an in-progress task needs its own hand-off. |

## Assumptions

- Round 2: no person confirmed the triage (`respond --auto`); the verify threads also had `needs_reply` false (#64).

- Round 1: no person confirmed the triage (`respond --auto`).
- Round 1: threads 4 and 13 would be declines; under `--auto` they are needs-you.
- Round 1: `review_threads.sh list` gave `needs_reply` false on all 13 threads (#64), so every thread got a reply, as the person approved on PR #85.
