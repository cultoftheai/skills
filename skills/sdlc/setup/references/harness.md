# Harness facts

## Claude Code

- A skill runs as `/<name>`.
- Fallback hand-off after a normal run: `Next: /frame "<your first request>"`. After a run with `--auto`: `Next: /frame "<your first request>" --auto`.
- Fallback hand-off after a hard stop: say what to fix, then `Next: /setup`.
- Connected search tools are the MCP tools in the session, named `mcp__<server>__<tool>`. The built-in `WebSearch` tool is the fallback, so it maps to `null`.
- Option picker: the `AskUserQuestion` tool. One call holds one to four questions, and each question has two to four options. Put the recommended option first and end its label with `(Recommended)`. Use the last part of the key, or a short name for a bundle, as `header` (12 characters at most, so `default_branch` becomes `branch`). Put the value and what it means in `description`. The tool adds `Other` for a free-text answer, so do not add one.

## Codex

- A skill runs as `$<name>` (unverified).
- Fallback hand-off: the same lines as Claude Code, with `$` in place of `/` (unverified).
- Connected search tools are the MCP servers in the Codex configuration. The built-in web search is the fallback, so it maps to `null` (unverified).
- Option picker: none, so ask with the numbered list below (unverified).

## No option picker

In a harness or session with no option picker, ask each group in one message. List each key with its options numbered from 1, the recommended option first. End the message with "Reply with one line for each key: a number or your own value."
