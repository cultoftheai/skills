# Harness facts

Run the transcript script once for each harness below. A harness with no session for the path exits 1. That is normal when the task was built in the other harness.

## Claude Code

- Script flag: `--harness claude-code`.
- Transcripts: `~/.claude/projects/<folder>/<session>.jsonl`, or under `$CLAUDE_CONFIG_DIR/projects/` when that variable is set. `<folder>` is the working directory with each character that is not a letter or a digit replaced by `-`. A folder name longer than 200 characters is cut and gets a hash suffix.
- Subagent transcripts are in `<folder>/<session>/subagents/`. The script does not read them, because their user messages come from an agent.

## Codex

- Script flag: `--harness codex`.
- Transcripts: `~/.codex/sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl` and `~/.codex/archived_sessions/`, or under `$CODEX_HOME` when that variable is set. Codex can compress old files to `.jsonl.zst`. The script reads them only when `zstd` is installed.
- These facts come from the Codex source (openai/codex, commit 60fc55b). They were not checked on a Codex install: unverified.
