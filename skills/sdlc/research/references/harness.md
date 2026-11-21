# Harness facts for `research`

Read the section for the harness that runs you.

## Claude Code

- **Start a subagent** - Use the Agent tool with the `general-purpose` subagent type. Its last message comes back as the tool result. A subagent cannot start another subagent. If you already run as a subagent, run steps 4 to 6 yourself.
- **Find the engine** - MCP tools have names of the form `mcp__<server>__<tool>`. The value of `research.engine` can be the full name or only the `<tool>` part. Some tools load on demand. Search the tool list for the name before you decide that the tool is not connected.
- **Built-in web search** - `WebSearch` finds pages. `WebFetch` reads one page.

## Codex

- **Start a subagent** - Ask for it in plain words, for example "start one subagent to run steps 4 to 6 of this skill". Subagents are on by default (`agents.enabled` defaults to `true`). The main thread collects the result. If a subagent can start its own subagent: unverified.
- **Find the engine** - MCP servers come from the `mcp_servers.<id>` tables in `config.toml`. The form of the tool name that the model sees: unverified. Match `research.engine` against the tool names that you have.
- **Built-in web search** - The web search tool. By default it returns cached results from an index that OpenAI keeps, so a page can be old. `web_search = "live"` in `config.toml`, or `codex --search`, gives live results. `web_search = "disabled"` turns it off. With cached results, write `web search (cached)` as the engine. The exact tool name that the model sees: unverified.
