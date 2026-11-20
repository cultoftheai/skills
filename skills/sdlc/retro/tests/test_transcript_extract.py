"""Tests for transcript_extract.py. They build small transcripts in a temporary directory."""

import io
import json
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import transcript_extract  # noqa: E402

WORKTREE = "/work/repo/.trees/task-7"


def write_jsonl(path, items, extra_lines=()):
    """Write the items as JSON lines, followed by raw extra lines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(item) for item in items] + list(extra_lines)
    path.write_text("\n".join(lines) + "\n")


def cc_user(text, cwd=WORKTREE, **extra):
    """Return a Claude Code user record."""
    return {"type": "user", "cwd": cwd, "timestamp": "t", "isSidechain": False, "message": {"role": "user", "content": text}, **extra}


def cc_tool(name, cwd=WORKTREE):
    """Return a Claude Code assistant record with one tool call."""
    content = [{"type": "tool_use", "name": name, "input": {}}]
    return {"type": "assistant", "cwd": cwd, "timestamp": "t", "isSidechain": False, "message": {"role": "assistant", "content": content}}


def cc_tool_result(cwd=WORKTREE):
    """Return a Claude Code user record that carries a tool result."""
    return cc_user([{"type": "tool_result", "tool_use_id": "x", "content": "long output"}], cwd)


def cc_queued(prompt, kind="human"):
    """Return a Claude Code attachment for a message sent while the agent worked."""
    attachment = {"type": "queued_command", "prompt": prompt, "commandMode": "prompt", "origin": {"kind": kind}}
    return {"type": "attachment", "cwd": WORKTREE, "timestamp": "t", "isSidechain": False, "attachment": attachment}


def cc_folder(path):
    """Return the Claude Code project folder name of a path."""
    return re.sub(r"[^a-zA-Z0-9]", "-", path)


def codex_line(kind, payload):
    """Return one Codex rollout line."""
    return {"timestamp": "2026-11-20T10:00:00Z", "type": kind, "payload": payload}


def codex_meta(cwd=WORKTREE, **extra):
    """Return a Codex session meta line."""
    return codex_line("session_meta", {"id": "s", "cwd": cwd, "source": "cli", **extra})


def codex_user(text):
    """Return a Codex user message event."""
    return codex_line("event_msg", {"type": "user_message", "message": text})


def codex_call(name):
    """Return a Codex function call item."""
    return codex_line("response_item", {"type": "function_call", "name": name, "arguments": "{}", "call_id": "c"})


class ClaudeCodeTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.env = {"CLAUDE_CONFIG_DIR": str(self.home)}

    def session(self, items, folder=WORKTREE, name="s1", extra_lines=()):
        write_jsonl(self.home / "projects" / cc_folder(folder) / f"{name}.jsonl", items, extra_lines)

    def extract(self, worktree=WORKTREE):
        return transcript_extract.extract("claude-code", worktree, self.env)

    def test_keeps_messages_after_an_agent_action(self):
        self.session([cc_user("build it"), cc_tool("Edit"), cc_tool_result(), cc_tool("Bash"), cc_user("no, keep the old name")])
        found, sessions, _ = self.extract()
        self.assertEqual(sessions, 1)
        self.assertEqual([f["text"] for f in found], ["no, keep the old name"])
        self.assertEqual(found[0]["after"], ["Bash", "Edit"])
        self.assertEqual(found[0]["session"], "s1")

    def test_skips_meta_sidechain_tags_and_other_origins(self):
        self.session([
            cc_user("start"),
            cc_tool("Read"),
            cc_user("skill text", isMeta=True),
            cc_user("agent prompt", isSidechain=True),
            cc_user("<command-name>/clear</command-name>"),
            cc_user("a report", origin={"kind": "task-notification"}),
            cc_queued("<task-notification>done</task-notification>", kind="task-notification"),
        ])
        self.assertEqual(self.extract()[0], [])

    def test_keeps_a_message_queued_while_the_agent_worked(self):
        self.session([cc_user("start"), cc_tool("Bash"), cc_queued("stop, wrong branch")])
        self.assertEqual([f["text"] for f in self.extract()[0]], ["stop, wrong branch"])

    def test_reads_text_blocks_and_skips_bad_lines(self):
        blocks = [{"type": "text", "text": "use the helper"}]
        self.session([cc_user("start"), cc_tool("Write"), cc_user(blocks)], extra_lines=["{not json"])
        self.assertEqual([f["text"] for f in self.extract()[0]], ["use the helper"])

    def test_includes_directories_inside_the_worktree_only(self):
        self.session([cc_user("a"), cc_tool("Bash"), cc_user("inside")], folder=WORKTREE + "/sub", name="in")
        self.session([cc_user("a", "/work/repo/.trees/task-70"), cc_tool("Bash", "/work/repo/.trees/task-70"), cc_user("other", "/work/repo/.trees/task-70")], folder="/work/repo/.trees/task-70", name="out")
        found, sessions, _ = self.extract()
        self.assertEqual(sessions, 1)
        self.assertEqual([f["text"] for f in found], ["inside"])

    def test_repo_root_covers_its_worktrees(self):
        self.session([cc_user("a"), cc_tool("Bash"), cc_user("fix")])
        self.assertEqual(self.extract("/work/repo")[1], 1)

    def test_cuts_long_messages(self):
        self.session([cc_user("a"), cc_tool("Bash"), cc_user("x " * 600)])
        self.assertLessEqual(len(self.extract()[0][0]["text"]), transcript_extract.MAX_TEXT)

    def test_no_session_exits_1(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = transcript_extract.main(["--harness", "claude-code", "--worktree", WORKTREE], self.env)
        self.assertEqual(code, 1)
        self.assertIn("no chat data", stderr.getvalue())

    def test_prints_json_lines(self):
        self.session([cc_user("a"), cc_tool("Bash"), cc_user("again")])
        stdout = io.StringIO()
        with redirect_stdout(stdout):
            code = transcript_extract.main(["--harness", "claude-code", "--worktree", WORKTREE], self.env)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout.getvalue())["text"], "again")


class CodexTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.env = {"CODEX_HOME": str(self.home)}

    def rollout(self, items, name="rollout-2026-11-20T10-00-00-a.jsonl", subdir="sessions/2026/11/20"):
        write_jsonl(self.home / subdir / name, items)

    def extract(self):
        return transcript_extract.extract("codex", WORKTREE, self.env)

    def test_keeps_messages_after_an_agent_action(self):
        self.rollout([codex_meta(), codex_user("add a flag"), codex_call("shell"), codex_user("wrong file")])
        found, sessions, _ = self.extract()
        self.assertEqual(sessions, 1)
        self.assertEqual([(f["text"], f["after"]) for f in found], [("wrong file", ["shell"])])

    def test_counts_an_assistant_message_as_an_action(self):
        reply = codex_line("response_item", {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "done"}]})
        self.rollout([codex_meta(), codex_user("hi"), reply, codex_user("that is not what I asked")])
        self.assertEqual(self.extract()[0][0]["after"], ["message"])

    def test_skips_other_worktrees_and_subagents(self):
        self.rollout([codex_meta(cwd="/elsewhere"), codex_user("a"), codex_call("shell"), codex_user("b")], name="rollout-1.jsonl")
        self.rollout([codex_meta(source={"subagent": "review"}), codex_user("a"), codex_call("shell"), codex_user("b")], name="rollout-2.jsonl")
        self.rollout([codex_meta(parent_thread_id="p"), codex_user("a"), codex_call("shell"), codex_user("b")], name="rollout-3.jsonl")
        self.assertEqual(self.extract()[1], 0)

    def test_reads_archived_sessions(self):
        self.rollout([codex_meta(), codex_user("a"), codex_call("apply_patch"), codex_user("b")], subdir="archived_sessions")
        self.assertEqual([f["text"] for f in self.extract()[0]], ["b"])

    def test_reports_a_file_that_does_not_parse(self):
        path = self.home / "sessions/2026/11/20/rollout-bad.jsonl"
        path.parent.mkdir(parents=True)
        path.write_text("not json\n")
        found, sessions, errors = self.extract()
        self.assertEqual((found, sessions), ([], 0))
        self.assertEqual(len(errors), 1)

    @unittest.skipUnless(sys.version_info >= (3, 14), "compression.zstd needs Python 3.14")
    def test_reads_compressed_rollouts(self):
        from compression import zstd

        items = [codex_meta(), codex_user("a"), codex_call("shell"), codex_user("b")]
        path = self.home / "sessions/2026/11/20/rollout-z.jsonl.zst"
        path.parent.mkdir(parents=True)
        path.write_bytes(zstd.compress("\n".join(json.dumps(i) for i in items).encode()))
        self.assertEqual([f["text"] for f in self.extract()[0]], ["b"])


if __name__ == "__main__":
    unittest.main()
