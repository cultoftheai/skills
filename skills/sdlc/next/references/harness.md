# Harness facts

## Claude Code

- `next_step.sh` finds Claude Code from the `CLAUDECODE` environment variable, which Claude Code sets in its shell. The skills are the `sdlc` plugin, so commands have the form `/sdlc:<skill> <args>`.
- In the brief, tell the subagent to run the skill with the `Skill` tool, for example `skill: "sdlc:shape"` and `args: "12 --auto"`.
- A subagent cannot ask the person anything. Tell it to stop and return the question as its final message.

## Codex

- `next_step.sh` takes Codex when an environment variable starts with `CODEX_`. Unverified: which `CODEX_` variable Codex sets. To be sure, set `SDLC_HARNESS=codex` in the environment.
- Unverified: commands have the form `$<skill> <args>`.
- Unverified: a subagent runs a skill when its brief names it, for example "Use the $shape skill with the arguments 12 --auto".
- Unverified: whether a subagent can ask the person. Tell it to stop and return the question as its final message.
