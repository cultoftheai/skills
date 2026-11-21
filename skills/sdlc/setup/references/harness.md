# Harness facts

## Claude Code

- A skill runs as `/<name>`.
- Fallback hand-off after a normal run: `Next: /frame "<your first request>"`. After a run with `--auto`: `Next: /frame "<your first request>" --auto`.
- Fallback hand-off after a hard stop: say what to fix, then `Context: clear - setup needs nothing from this session. Run /clear before the next command.` and `Next: /setup`.
- Fallback Context line just above the fallback hand-off after a normal run: `Context: clear - the next step starts from the issue, the task folder or the PR. Run /clear before the next command.`
- Connected search tools are the MCP tools in the session, named `mcp__<server>__<tool>`. The built-in `WebSearch` tool is the fallback, so it maps to `null`.

## Codex

- A skill runs as `$<name>` (unverified).
- Fallback hand-off: the same `Next:` lines as Claude Code, with `$` in place of `/`, and no `Context:` line (unverified).
- Connected search tools are the MCP servers in the Codex configuration. The built-in web search is the fallback, so it maps to `null` (unverified).
