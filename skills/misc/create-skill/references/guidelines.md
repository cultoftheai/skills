# Skill authoring guidelines

Rules for each part of a house-format skill. `scripts/lint_skill.py` checks the rules marked **(lint)**.

## Frontmatter

- **name** - kebab-case, 64 characters or fewer, same as the directory name. **(lint)**
- **description** - 1024 characters or fewer, no `<` or `>`, no `: ` (it breaks the YAML), starts with "Use when". **(lint)**
  - The description is the only text an agent sees before it loads the skill. It decides if the skill starts.
  - Use this structure: `Use when <situation>. <What the skill does>. Triggers - <phrase>, <phrase>. Not for <case>.`
  - Use the words a user types, for example "fix review feedback", not "remediate".
  - If a similar skill exists, write the difference in the "Not for" part.
- **argument-hint** [Optional] - Shows the args and flags in the slash-command menu, for example `<pr-number> [--auto]`. Add it when the skill has Args or Flags.
- **allowed-tools** [Optional] - Tools the skill can use without a permission prompt. Add it only when the user asks for it.
- **disable-model-invocation** [Optional] - Set to `true` when only the user may start the skill, for example a skill that deploys or deletes.

## Dependencies

- Format: `- **(<type>) <name>** [Must|Optional] - <why the skill needs it>`.
- Types: `skill`, `cli tool`, `mcp server`. Do not use other types.
- Write skill names in backticks.

## Args and Flags

- An arg is a value, for example a PR number. A flag is a `--name` switch that changes the behaviour.
- Format: `- **<name>** [Must|Optional] - <meaning>`. Flags start with `--`.
- For each Optional arg, give the default value.
- Flags are Optional. For each flag, write what happens when it is absent.
- After the Args list, write: "Ask interactively if any **Must** arg is missing."

## Flow Graph and Flow steps

- Use `flowchart TD` in a `mermaid` code block. **(lint)**
- Define each node on its own line. Write the edges on separate lines after the nodes. **(lint)**
- Number every node, decisions included. Start at 1 and count in flow order. **(lint)**
- Node label: `<number>. <Name>`. Use `[...]` for a step and `{...}` for a decision. A decision name ends with `?`.
- Label each edge out of a decision, for example `|Yes|` and `|No|`.
- Each node has a flow step `<number>. **<Name>** - <description>` with the same number and name. Each name is unique. **(lint)**
- A decision step says how to decide and which step each answer goes to.

## Rules

- Constraints that apply to all steps, not one step.
- One constraint for each item. Use the imperative.
- Do not repeat the flow steps.

## Output

- List the files or results that the skill produces.
- List what the skill reports to the user at the end.
- Remove the section if the skill produces nothing.

## Reference files, scripts and assets

- Keep SKILL.md at 500 lines or fewer. **(lint)**
- Move content to `references/<topic>.md` when only some runs need it (a mode, a flag, a branch of the flow), or when one section is longer than about 50 lines.
- Use lowercase snake_case file names. A subdirectory such as `references/templates/` is permitted.
- Load each reference file from a flow step with an explicit instruction, for example "Read `references/auto_mode.md`." Do not load a reference file from another reference file.
- Each `references/`, `scripts/` and `assets/` path in SKILL.md must exist. **(lint)**
- Put deterministic work (validation, parsing, conversion) in `scripts/`. Give the exact command in the flow step.
- Put files that the skill copies into its output (templates, images) in `assets/`.
