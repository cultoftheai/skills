#!/usr/bin/env python3
"""Print the user messages that follow an agent action in the chat transcripts of one worktree.

Usage:
  transcript_extract.py --harness claude-code|codex --worktree <path>

Transcripts:
  claude-code  <CLAUDE_CONFIG_DIR or ~/.claude>/projects/<working directory with each
               character that is not a letter or digit replaced by "-">/<session>.jsonl
  codex        <CODEX_HOME or ~/.codex>/sessions/YYYY/MM/DD/rollout-*.jsonl and
               archived_sessions/rollout-*.jsonl, also as .jsonl.zst

A session belongs to the worktree when its working directory is <path> or inside it.
Subagent sessions are skipped, because their user messages come from an agent.

Output: one JSON object per line with the keys session, timestamp, after and text.
"after" lists the agent actions (tool names, or "message") since the previous user
message. "text" is cut to 500 characters. The first message of a session is not
printed, because no agent action comes before it.

Exit codes: 0 when at least one session was read; 1 when no session of the worktree
was found or could be parsed, which means there is no chat data; 2 bad usage.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

MAX_TEXT = 500
MAX_ACTIONS = 5
CLAUDE_CODE_DIR_LIMIT = 200
CODEX_SUBDIRS = ("sessions", "archived_sessions")
SUBAGENT_SOURCES = {"subagent", "internal"}


class ParseError(Exception):
    """A transcript file cannot be read."""


def inside(cwd, worktree):
    """Return True when cwd is the worktree or a directory inside it."""
    root = worktree.rstrip("/")
    return cwd == root or cwd.startswith(root + "/")


def clip(text):
    """Collapse whitespace and cut the text to MAX_TEXT characters."""
    flat = " ".join(text.split())
    return flat if len(flat) <= MAX_TEXT else flat[: MAX_TEXT - 3] + "..."


def read_text(path):
    """Return the text of a plain or zstd-compressed transcript."""
    if path.name.endswith(".zst"):
        try:
            from compression import zstd
        except ImportError as error:
            raise ParseError(f"{path.name}: this Python cannot read .zst files") from error
        return zstd.decompress(path.read_bytes()).decode("utf-8")
    return path.read_text(encoding="utf-8")


def records(path):
    """Return the JSON objects of a JSONL file. Lines that do not parse are skipped."""
    parsed = []
    for line in read_text(path).splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            parsed.append(value)
    if not parsed:
        raise ParseError(f"{path.name}: no JSON records")
    return parsed


def claude_code_files(home, worktree):
    """Return the session files of every project directory that can hold the worktree or a directory inside it."""
    root = home / "projects"
    prefix = re.sub(r"[^a-zA-Z0-9]", "-", worktree.rstrip("/"))[:CLAUDE_CODE_DIR_LIMIT]
    if not root.is_dir():
        return []
    folders = sorted(d for d in root.iterdir() if d.is_dir() and d.name.startswith(prefix))
    return [f for d in folders for f in sorted(d.glob("*.jsonl"))]


def claude_code_actions(content):
    """Return the agent actions of an assistant message."""
    if not isinstance(content, list):
        return ["message"] if content else []
    actions = [b.get("name", "tool") for b in content if b.get("type") == "tool_use"]
    if any(b.get("type") == "text" for b in content):
        actions.append("message")
    return actions


def is_human(origin, fallback):
    """Return True when the origin marks a person, or the fallback when there is no origin."""
    return origin.get("kind") == "human" if isinstance(origin, dict) else fallback


def typed_text(text):
    """Return the text when a person typed it, or None for harness tags such as commands and notifications."""
    return text if isinstance(text, str) and text.strip() and not text.lstrip().startswith("<") else None


def claude_code_user_text(record):
    """Return the text of a user record that a person wrote, or None."""
    if not is_human(record.get("origin"), True):
        return None
    content = (record.get("message") or {}).get("content")
    if isinstance(content, list):
        if any(b.get("type") != "text" for b in content):
            return None
        content = "\n".join(b.get("text", "") for b in content)
    return typed_text(content)


def claude_code_queued_text(record):
    """Return the text of a message that a person sent while the agent worked, or None."""
    attachment = record.get("attachment") or {}
    if attachment.get("type") != "queued_command":
        return None
    if not is_human(attachment.get("origin"), attachment.get("commandMode") == "prompt"):
        return None
    return typed_text(attachment.get("prompt"))


def claude_code_events(path, worktree):
    """Return (kind, value, timestamp) events of one session file, or None when no record is in the worktree."""
    events, matched = [], False
    for record in records(path):
        if record.get("isSidechain") or record.get("isMeta") or not inside(record.get("cwd", ""), worktree):
            continue
        matched = True
        kind, stamp = record.get("type"), record.get("timestamp", "")
        if kind == "assistant":
            events += [("agent", a, stamp) for a in claude_code_actions((record.get("message") or {}).get("content"))]
            continue
        text = claude_code_user_text(record) if kind == "user" else claude_code_queued_text(record) if kind == "attachment" else None
        if text:
            events.append(("human", text, stamp))
    return events if matched else None


def codex_files(home, worktree):
    """Return every rollout file under the Codex home. The worktree is checked per file."""
    files = []
    for subdir in CODEX_SUBDIRS:
        base = home / subdir
        if base.is_dir():
            files += [p for p in sorted(base.rglob("rollout-*")) if p.name.endswith((".jsonl", ".jsonl.zst"))]
    return files


def codex_session_matches(meta, worktree):
    """Return True when the session meta belongs to the worktree and to a person, not a subagent."""
    source = meta.get("source")
    subagent = isinstance(source, dict) and SUBAGENT_SOURCES & set(source)
    spawned = meta.get("parent_thread_id") or meta.get("agent_path") or subagent
    return inside(str(meta.get("cwd", "")), worktree) and not spawned


def codex_action(payload):
    """Return the agent action of a response item, or None."""
    kind = payload.get("type")
    if kind in ("function_call", "custom_tool_call"):
        return payload.get("name", "tool")
    if kind in ("local_shell_call", "web_search_call"):
        return kind.removesuffix("_call")
    if kind == "message" and payload.get("role") == "assistant":
        return "message"
    return None


def codex_event(record):
    """Return the (kind, value, timestamp) event of one rollout line, or None."""
    payload, stamp = record.get("payload") or {}, record.get("timestamp", "")
    if record.get("type") == "event_msg" and payload.get("type") == "user_message":
        text = payload.get("message")
        return ("human", text, stamp) if isinstance(text, str) and text.strip() else None
    if record.get("type") == "response_item":
        action = codex_action(payload)
        return ("agent", action, stamp) if action else None
    return None


def first_record(path):
    """Return the first JSON record of a plain JSONL file, or None when it cannot be read cheaply."""
    if path.name.endswith(".zst"):
        return None
    with path.open(encoding="utf-8") as handle:
        try:
            value = json.loads(handle.readline())
        except json.JSONDecodeError:
            return None
    return value if isinstance(value, dict) else None


def codex_events(path, worktree):
    """Return the events of one rollout file, or None when the session is not a person's session in the worktree."""
    head = first_record(path)
    if head and head.get("type") == "session_meta" and not codex_session_matches(head.get("payload") or {}, worktree):
        return None
    lines = records(path)
    meta = next((r.get("payload") or {} for r in lines if r.get("type") == "session_meta"), None)
    if meta is None or not codex_session_matches(meta, worktree):
        return None
    return [event for event in map(codex_event, lines) if event]


def claude_code_home(env):
    """Return the Claude Code configuration directory."""
    return Path(env.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")


def codex_home(env):
    """Return the Codex home directory."""
    return Path(env.get("CODEX_HOME") or Path.home() / ".codex")


HARNESSES = {
    "claude-code": (claude_code_home, claude_code_files, claude_code_events),
    "codex": (codex_home, codex_files, codex_events),
}


def corrections(session, events):
    """Return the user messages that follow at least one agent action."""
    found, actions, last_text = [], [], None
    for kind, value, stamp in events:
        if kind == "agent":
            actions.append(value)
            continue
        if actions and value != last_text:
            after = list(dict.fromkeys(reversed(actions)))[:MAX_ACTIONS]
            found.append({"session": session, "timestamp": stamp, "after": after, "text": clip(value)})
        actions, last_text = [], value
    return found


def session_name(path):
    """Return the session name of a transcript file."""
    return path.name.split(".")[0]


def extract(harness, worktree, env):
    """Return the corrections of the worktree, the number of sessions read and the parse errors."""
    home_of, list_files, read_events = HARNESSES[harness]
    found, sessions, errors = [], 0, []
    for path in list_files(home_of(env), worktree):
        try:
            events = read_events(path, worktree)
        except (OSError, UnicodeDecodeError, ParseError) as error:
            errors.append(str(error))
            continue
        if events is not None:
            sessions += 1
            found += corrections(session_name(path), events)
    return found, sessions, errors


def parse_args(argv):
    """Parse the command line."""
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--harness", required=True, choices=sorted(HARNESSES))
    parser.add_argument("--worktree", required=True)
    return parser.parse_args(argv)


def main(argv=None, env=None):
    """Print the corrections as JSON lines and return the exit code."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    worktree = os.path.abspath(os.path.expanduser(args.worktree))
    found, sessions, errors = extract(args.harness, worktree, os.environ if env is None else env)
    for error in errors:
        print(f"skipped {error}", file=sys.stderr)
    if sessions == 0:
        print(f"no chat data: no {args.harness} session found for {worktree}", file=sys.stderr)
        return 1
    for item in found:
        print(json.dumps(item, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
