# Review of #85

## Round 1, 2026-11-22T19:07:36Z

| Thread | Reviewer | Concern | Severity | Confidence | Outcome | Evidence |
|---|---|---|---|---|---|---|
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659504997 | jakubtobiasz | Step 4 hands off with pass when nothing is left, though --local never hands off | major | high | fix | bdf820d, a59e1f9 |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505017 | jakubtobiasz | Same as the criteria thread on step 4 | major | high | fix | bdf820d, a59e1f9 |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505001 | jakubtobiasz | --auto with no target still reviews the PR of the branch, which --local has not got | minor | high | fix | 4850a86 |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505022 | jakubtobiasz | Same as the criteria thread on --auto | minor | high | fix | 4850a86 |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505008 | jakubtobiasz | The --verify replies in step 6 are not limited to a PR | minor | high | fix | 47c656c |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505028 | jakubtobiasz | Same as the criteria thread on step 6 | minor | high | fix | 47c656c |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505012 | jakubtobiasz | Step 3 does not say to split the PR.md Location into path and line | nit | high | fix | b1cf0df |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505031 | jakubtobiasz | Same as the criteria thread on the Location column | nit | high | fix | b1cf0df |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505034 | jakubtobiasz | README says every skill ends with Next:, --local prints none | nit | medium | decline | --local is an internal mode that build calls; each run a person types still ends with Next:. README changes are in #80 |
| https://github.com/cultoftheai/skills/pull/85#discussion_r4659505036 | jakubtobiasz | README review row does not name a branch | nit | high | decline | #80 updates the README skill table (its criterion 2) |

## Assumptions

- Round 1: `review_threads.sh list` gave `needs_reply` false on all 10 threads, because the review was posted by the PR author's gh user (#64). The person confirmed that every thread gets a reply.
