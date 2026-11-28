# Spec: Rename frame, slice and shape to to-ticket, to-tasks and to-spec

Task: #126. Story: #125. Design: none.
Size: S, confirmed. 1 module (`skills/sdlc`, plus its symlinks, the `.sdlc/` copies and `README.md`), about 20 files, about 260 inserted plus deleted lines (under the 400-line review limit), no risk path.

## Data shape
- Names: `frame`→`to-ticket`, `slice`→`to-tasks`, `shape`→`to-spec`.
- `next_step.sh`: in `SKILLS`, replace the 3 old names with the new ones. Rename `after_frame`/`after_slice`/`after_shape` to `after_to_ticket`/`after_to_tasks`/`after_to_spec`. The dispatch at `next_step.sh:640` already maps `-` to `_`. Every `skill <old>` call and every `wait_then "..." "<old> ..."` call uses the new name. `--after frame|slice|shape` then exits 2, as for any unknown skill.

## Seam
- Folders: `git mv skills/sdlc/{frame,slice,shape}` to `skills/sdlc/{to-ticket,to-tasks,to-spec}`. Set `name:` in each `SKILL.md`. Replace the symlinks `.claude/skills/{frame,slice,shape}` and `.agents/skills/{frame,slice,shape}` with links under the new names. The plugin manifests list `./`, so they need no edit.
- `Next:` lines come from `next_step.sh` and from the hard-coded fallbacks in `to-spec/SKILL.md` (step 10), `design/SKILL.md:58` and `setup/references/harness.md:6`. `skills/sdlc/next/tests/test_next_step.sh` holds the script output. The grep in the Test plan holds the fallbacks.

## Files
- `skills/sdlc/{to-ticket,to-tasks,to-spec}/` (moved) - `name:`, the title of each flow-graph decision node and step that names the skill ("Can to-tasks?"), `--after <new>`, and cross-references (`frame` run, `shape` writes it, `slice` for an M story).
- `skills/sdlc/{research,design,build}/SKILL.md`, `next/references/harness.md`, `setup/references/harness.md`, `to-ticket/references/{sizing,story}.md`, `to-tasks/references/slicing.md:20` - skill references only, including `--after` and the `Next:` fallbacks.
- `skills/sdlc/next/scripts/next_step.sh`, `skills/sdlc/next/tests/test_next_step.sh` - names, function names, header comments and asserts (29 test lines).
- `skills/sdlc/setup/tests/test_install.sh` - `frame/assets/templates/*` → `to-ticket/assets/templates/*`.
- `skills/sdlc/setup/assets/settings.schema.json:103` - "a task that to-tasks creates".
- `.sdlc/scripts/{next_step.sh,settings.schema.json}` - refreshed with `sh skills/sdlc/setup/scripts/install.sh .`. Templates are unchanged.
- `README.md` - the plugin row, the steps, the mermaid nodes and the table rows (the `to-spec` row names only `SPEC.md`, because `design` writes `DESIGN.md`). Add a "Renamed skills" section: an old→new table (3 rows for now), plus a note that existing repos must run `/sdlc:setup` again, because the installed `.sdlc/scripts/next_step.sh` rejects the new `--after` names until then.
- `.claude/skills/*`, `.agents/skills/*` - 6 symlinks.

## Test plan
- `sh skills/sdlc/next/tests/run.sh` passes with the asserts set to the new names. This proves the `Next:` lines (AC3).
- `sh skills/sdlc/setup/tests/run.sh` passes. This proves that `install.sh` finds the templates under the renamed folders and that the stage labels did not change (AC6).
- `python3 skills/misc/create-skill/scripts/lint_skill.py skills/sdlc/<dir>` exits 0 for `to-ticket`, `to-tasks` and `to-spec`. This proves that `name:` matches the folder and that the reference links resolve (AC1).
- `grep -rnwE 'frame|slice|shape' skills README.md .sdlc/scripts .sdlc/templates` lists only the words that Assumptions keeps. It covers descriptions, triggers, `name:` lines, flow-graph nodes, `wait_then` strings, comments and fallbacks. `ls .claude/skills/shape .agents/skills/frame` fails. Together these prove the hard rename and that no skill text keeps an old name (AC2, AC4, AC5).
- After `/plugin` install from this branch, `/sdlc:to-spec` is listed and `/sdlc:shape` is not (AC1, AC2, checked by hand).

## Assumptions
- These words stay unchanged because they are not skill names: "data shape", "slice" and "slices" as nouns, "frame again" in prose, and the `shaped` stage label.
- The stale `respond` mentions in `README.md` are outside this task and stay as they are.
- `.sdlc/specs/archived/` and `.sdlc/task/` stay as they are.

## Open questions
- None.
