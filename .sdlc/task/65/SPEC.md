# Spec: Add the ultra and high review levels

Task: #65. Story: #62. Design: none.
Size: M (story). Confirmed: 1 module (`skills/sdlc/review`), 2 files, about 50 changed lines, no risk path. The new `--level` flag is additive: `review <pr>` keeps working.

## Data shape
- `--level <ultra|high>`, default `high`. It applies to a PR only. On a spec or design, the level is ignored.
- Axes: `criteria` (acceptance criteria), `guide` (code review guide), `consistency` (a line in the diff that another file contradicts, in or outside the diff).
- Each finding in the findings JSON gets one more key, `axis`. Each posted comment names its axis after `review.prefix`, for example `:robot: [consistency]`.
- A PR that closes no issue is XS work, as `document_or_ship` in `next_step.sh` already treats it. Its `criteria` axis is skipped, and the report says so. Today, a PR like that always gets a blocking finding.

## Seam
- The brief in `references/reviewer_brief.md` gets an `Axes: <list>` line and the text for all 3 axes. The reviewer checks only the axes in that list. One brief serves both levels.
- `high`: 1 reviewer with axes `criteria, guide`. This is today's review.
- `ultra`: 3 reviewers started in one message, as `orchestrator` says (at most 3 at once), each with one axis and its own findings file. Step 5 reads all 3 files. The criteria table comes from the `criteria` reviewer.
- Pass rule (step 8): every finding counts at both levels, so it does not change.

## Files
- `skills/sdlc/review/SKILL.md`: `argument-hint` and the Flags section get `--level`. Step 3 gets the XS rule. Step 4 picks the reviewers and axes by level. Steps 5 and 6 merge the findings files and name the axis.
- `skills/sdlc/review/references/reviewer_brief.md`: the `Axes` line, the `consistency` axis, the `axis` key, and one findings path for each reviewer.

## Test plan
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/review` exits 0.
- Run `review <pr> --level ultra` on a test PR that changes a rule in one reference file while another file still says the opposite. 3 reviewers start, each comment names its axis, and the `consistency` axis reports the contradiction. This proves criteria 1 and 2.
- Run `review <pr> --level high` and `review <pr>` on the same PR. Each starts 1 reviewer, and the two results have the same axes. This proves criterion 3.
- Run `review <pr>` on a PR that closes no issue. It gives no blocking finding about missing criteria, and the report says the criteria axis was skipped. This proves the `high` half of criterion 4. The `--verify` half is checked in #66.

## Open questions
- None.
