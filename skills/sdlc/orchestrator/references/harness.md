# How to start a subagent

## Claude Code

- Start a worker with the `Agent` tool. Put the brief in `prompt` and a few words in `description`.
- A new `Agent` call starts with an empty context. `subagent_type: "fork"` copies this conversation. Do not fork when a fresh view is the point.
- Use `subagent_type: "Explore"` for read-only search. Leave `subagent_type` out for work that edits files.
- Workers share the worktree of the parent. Do not set `isolation`, even for a worker that edits files.
- To run workers in parallel, send several `Agent` calls in one message.
- Only the final message of the worker comes back to you.
- `SendMessage` continues a worker with its full context. After a failure, make a new `Agent` call instead.

## Codex

- Ask Codex to spawn a subagent and give it the brief, for example "Spawn one subagent with this brief: ...". Codex spawns subagents only when a person or a skill asks for them.
- Built-in agent types: `worker` for changes and fixes, `explorer` for read-only exploration, `default` for the rest.
- Codex waits for every subagent you asked for, then the results come back to the main thread.
- `agents.max_concurrent_threads_per_session` in the Codex config caps the open subagent threads.
- Subagents inherit the sandbox policy and approval settings of the parent.
- Unverified: whether a subagent starts with an empty context or with a copy of this conversation. When a fresh view is the point, run `codex exec "<brief>"` in a shell instead. It is a new session with no history. Unverified: that it prints only the final message to stdout.
- Unverified: whether a subagent can get its own worktree. For a worker that edits files, run `git worktree add <path> -b <branch>` first and name the path in the brief.
