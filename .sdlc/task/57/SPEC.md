# Spec: Ask each setup question as a list of options

Task: #57. Story: #46. Design: none.
Size: S task of M story #46 confirmed. 1 module (setup), no risk path, about 45 changed lines in 3 files, no script change.

## Data shape
No settings key, allowed value or default changes. A question is one key (or one bundle of keys) with an ordered option list:

1. The detected value, else the schema default. It is first, and its label ends with `(Recommended)`.
2. The other detected values (each matching guide file, each project or team).
3. The other allowed values of the schema (`enum`, or `true` and `false`).
4. `null` for a nullable key.

At most four options. When more match, keep the first three and `null`. A key with one option gets `Enter another value` as the second, then the value is asked as free text.

Bundles, one question each, with the values in the description and `Use these (Recommended)` first: `issue.stages`, `issue.types`, `task.path` with `templates.*`, `sizing.risk_paths` (plus `None`), and the five `sizing` thresholds. With them, each group has at most four questions, so one picker call asks one group.

Picker, Claude Code: `AskUserQuestion` with one question for each key left, `header` = the last part of the key (12 characters at most), the value in `description`. Its own `Other` is the free-text answer. No picker (Codex, or no such tool in the session): one message for each group, each key with its options numbered from 1, and the line "Reply with one line for each key: a number or your own value."

## Seam
Step 5 of `SKILL.md` reads the option rules in `references/walkthrough.md` and the picker in `references/harness.md`. No script changes, so no shell test holds it. The proof is a run of `/setup` in a scratch repo (`prove`).

## Files
- `skills/sdlc/setup/SKILL.md` - step 5: ask each key as a list of options with the picker of the harness, in place of "show the detected value or the schema default"
- `skills/sdlc/setup/references/walkthrough.md` - new `## Options` section: the order, the cap, the bundles; groups 2, 4 and 6 name their bundles
- `skills/sdlc/setup/references/harness.md` - the picker for Claude Code, and the numbered list for Codex (unverified) and any harness with no picker

## Test plan
- `/setup` in a scratch Git repo with no settings: each group is one `AskUserQuestion` call, the first option is the detected or default value with `(Recommended)`, and `Other` takes free text - criterion 1
- the same repo with a settings file that holds some valid keys: the groups keep their order, a group with no key left is skipped, and no kept key is asked - criterion 2
- `claude --disallowedTools AskUserQuestion` in the same repo: each group is a numbered list. A reply with a number and one with free text both land in the file - criterion 3
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/setup` passes

## Open questions
- none
