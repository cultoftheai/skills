# Spec: Route solo-maintainer PRs from next to ship

Task: #107. Story: #71. Design: none.
Size: S (confirmed under M story #71: 1 module — `skills/sdlc/next` — 4 files including `.sdlc/scripts/next_step.sh`, ~90 changed lines, no risk path).

## Data shape
- Solo mode: computed identically to `.sdlc/specs/105-solo-maintainer-ship-approval.md` from `gh api 'repos/{owner}/{repo}/collaborators?affiliation=all&permission=push&per_page=100'`. Active iff the response is a JSON array with `length < 100` and `[.[] | select(.type == "User" and .permissions.push == true) | .login] == [$author]`. Any API error or non-array response fails closed to `false` without aborting `next_step.sh`.
- Solo approval on a PR (`pullRequest.comments`, never issue comments): active in solo mode when no blocking review exists (`CHANGES_REQUESTED` in `latestOpinionatedReviews`, or `reviewDecision` in `CHANGES_REQUESTED` / `REVIEW_REQUIRED`) and a non-minimized comment with `.author.login == $author` and `(.author.__typename // "User") == "User"` has a first non-empty trimmed line starting with `<review.prefix> [approval]` or matching `^(/approve|approve|approved|lgtm)[.!]*$` (case-insensitive).
- `gate_step()` solo approval handling on `approval: fail - no solo approval from <author>` (from `ship_gates.sh` per #105): pending `checks` take precedence (`wait for CI on PR #<pr> (<checks>)`); when only `no solo approval from <author>` remains, print `approve PR #<pr> (<approval>), then run <prefix>ship <pr>` instead of `wait for a person to approve ...`. All other `approval` failures (`no approval from a person`, `changes requested by ...`, `GitHub review decision is ...`) keep the existing wait message unchanged.

## Seam
- `skills/sdlc/next/scripts/next_step.sh` (synced to `.sdlc/scripts/next_step.sh`): extend `ITEM_QUERY` `PullRequest` fragment with `reviewDecision`, `latestOpinionatedReviews(first: 100) { nodes { state author { __typename login } } }`, and `comments(last: 100) { nodes { body isMinimized author { __typename login } } }`. Add `opinionated_reviews`, `has_blocking_review`, `first_nonempty_line`, `is_approval_body`, and `has_solo_approval_comment` to `JQ_DEFS`.
- `skills/sdlc/next/scripts/next_step.sh`: add `is_solo_author()` (redirecting `gh api` stderr to `/dev/null` so errors fail closed) and `is_approved()` (passes on `has_human_approval`, else lazily checks `!has_blocking_review`, `has_solo_approval_comment`, and `is_solo_author` so no extra API call runs when unneeded). Replace `holds "$1" has_human_approval` in `route_pr()` and `holds "$verified" has_human_approval` in `after_verify_spec()` with `is_approved` (reviewed Spec/Design PRs without requested reviewers and reviewed Code PRs after `prove`/`document` already reach `ship`; `is_approved` routes solo-approved Code, Spec, and Design PRs directly to `ship`).
- `skills/sdlc/next/scripts/next_step.sh` (`gate_step()`): read `approval=$(gate_detail "$2" approval)`, keep `wait for a person to approve` only when `! starts_with "$approval" "no solo approval from "`, check pending `checks` next, and fall back to `wait_then "approve PR #$pr_number ($approval)" "ship $pr_number"` for solo missing approval.
- `skills/sdlc/next/tests/helpers.sh` & `test_next_step.sh`: sanitize fake `gh` / `fake_gh` rule keys (non-alphanumerics -> `_`) so REST collaborator calls can be faked, default to two `User` writers (`dev`, `lead`), add `fake_collaborators`, extend `pr()` with optional `decision` and `opinionated`, and add author-aware `comment()` to `NODE_DEFS`.

## Files
- `skills/sdlc/next/scripts/next_step.sh`, `.sdlc/scripts/next_step.sh` - Add solo-maintainer detection, `is_approved()`, and solo-aware `gate_step()`.
- `skills/sdlc/next/tests/helpers.sh`, `skills/sdlc/next/tests/test_next_step.sh` - Support REST collaborator faking and test solo and multi-maintainer routing for Code, Spec, and Design PRs.

## Test plan
- `sh skills/sdlc/next/tests/run.sh` (and with `SH=dash`) passes with new cases: solo-approved Code, Spec, and Design PRs route directly to `ship` in `route_pr` and `after_verify_spec` (including with `requested_reviewers`, custom `review.prefix`, and bots/read-only collaborators ignored); unapproved reviewed Spec/Design PRs route to `ship` and Code PRs follow `prove` -> `document` -> `ship`; `CHANGES_REQUESTED` and `REVIEW_REQUIRED` block solo approval; API error, non-array response, `length == 100`, or non-writer author fail closed; `gate_step` prioritizes pending `checks` over `no solo approval from <author>` and prompts `approve PR #<pr>` rather than waiting for another person; in a 2+ writer repo, author approval comments and `no approval from a person` behave identically to before — proves criteria 1 and 2.
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/next` exits 0 — proves `skills/sdlc/next/SKILL.md` remains valid and needs no edit.

## Open questions
- None.
