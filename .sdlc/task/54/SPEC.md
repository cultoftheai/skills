# Spec: Advise clear, compact or keep at every hand-off in Claude Code

Task: #54. Story: #45. Design: none.
Size: S task of M story #45 confirmed. 1 module (sdlc), no risk path, about 180 changed lines in 16 files.

## Data shape
`next_step.sh` prints one more line, `Context:`, before `Next:` when it runs with `--after` in Claude Code. It does not print it without `--after` (no hand-off) or in Codex (that is #55). When settings are missing, the advice is always clear: `Context: clear - setup needs nothing from this session. Run /clear before the next command.` Each skill that stops for missing settings prints that line itself in Claude Code, above `Next: /setup`. The advice depends only on `--after` and `--result`:

| After, result | Advice | Reason in the line |
|---|---|---|
| prove fail | compact | the next step continues this work |
| prove pass, document, frame fail | keep | the next step follows on directly |
| any other | clear | the next step starts from the issue, task folder or PR |

- `Context: clear - <reason>. Run /clear before the next command.`
- `Context: compact - <reason>. Run /compact Keep issue #<ref>, branch <branch>, open items: <keep>`
- `Context: keep - <reason>.`

`--keep "<text>"` is a new flag: the open items of the run. Leave out the issue for `-`, the branch when `git branch --show-current` is empty, and the open items when `--keep` is missing.

## Seam
A new `context_line` function in `next_step.sh`, called from the main block before the `Next:` line. Tests call the script as they do now and read the line before the last.

## Files
- `skills/sdlc/next/scripts/next_step.sh` - `--keep`, `context_line`, the usage comment
- `.sdlc/scripts/next_step.sh` - the same copy, as installed in this repo
- `skills/sdlc/next/tests/helpers.sh` - `context_line` helper: the line before the last
- `skills/sdlc/next/tests/test_next_step.sh` - the tests below
- `skills/sdlc/{setup,frame,slice,shape,build,prove,submit,review,respond,document,ship,retro}/SKILL.md` - "print its output as the last line" becomes "print its output as the last lines"; prove passes `--keep` with the open items of the run
- `skills/sdlc/next/SKILL.md` - the subagent returns, and the report prints, the last `Context:` line too
- `README.md` - the line on `Next:` names the `Context:` line

## Test plan
- each row of the table gives its advice - criteria 2, 3, 4, 5, 6
- compact with `--keep`, without it, and with `-` - criterion 7
- `Next:` is still the last line, and no `Context:` line without `--after`, without settings or in Codex - criteria 1, 8

## Open questions
- none
