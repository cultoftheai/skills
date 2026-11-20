"""Tests for scripts/qa_check.py. Git is faked; no repository is needed."""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import qa_check  # noqa: E402

HEAD = "a" * 40
OLD = "b" * 40


def qa_text(commit=HEAD, result="pass"):
    """Return a QA.md text whose newest run has the given commit and result, above an older passing run."""
    return (
        f"## Run 2026-11-20T10:00:00Z\nCommit: {commit}\nResult: {result}\n### Steps\n- cmd -> ok\n\n"
        "## Assumptions\n- the app runs on the default port\n\n"
        f"## Run 2026-11-19T10:00:00Z\nCommit: {HEAD}\nResult: pass\n### Steps\n- cmd -> ok\n"
    )


class FakeGit:
    """A git runner that answers from a fixed repository state."""

    def __init__(self, root, ancestor=True, changed=()):
        self.root = root
        self.ancestor = ancestor
        self.changed = changed

    def __call__(self, *args):
        """Answer the git calls that qa_check makes."""
        if args[:3] == ("rev-parse", "--verify", "--quiet"):
            return self.resolve(args[3].split("^")[0])
        if args == ("rev-parse", "HEAD"):
            return HEAD
        if args == ("rev-parse", "--show-toplevel"):
            return str(self.root)
        if args[0] == "merge-base":
            return args[1] if self.ancestor else "c" * 40
        if args[:2] == ("diff", "--name-only"):
            return "\n".join(self.changed)
        raise AssertionError(f"unexpected git call {args}")

    @staticmethod
    def resolve(commit):
        """Return the commit when it is known, or fail like git does."""
        if commit in (HEAD, OLD):
            return commit
        raise qa_check.QaError("git rev-parse failed")


class QaCheckTest(unittest.TestCase):
    """Behaviour of qa_check.check."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.task = self.root / ".sdlc" / "task" / "5"
        self.task.mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write_qa(self, text):
        (self.task / "QA.md").write_text(text)

    def assert_fails(self, reason, git):
        with self.assertRaisesRegex(qa_check.QaError, reason):
            qa_check.check(str(self.task), git)

    def test_pass_for_head(self):
        self.write_qa(qa_text())
        self.assertEqual(qa_check.check(str(self.task), FakeGit(self.root)), HEAD)

    def test_missing_file(self):
        self.assert_fails("does not exist", FakeGit(self.root))

    def test_no_run_section(self):
        self.write_qa("# QA\nnothing yet\n")
        self.assert_fails("no '## Run' section", FakeGit(self.root))

    def test_missing_commit_line(self):
        self.write_qa("## Run 2026-11-20\nResult: pass\n")
        self.assert_fails("no 'Commit:' line", FakeGit(self.root))

    def test_newest_run_failed(self):
        self.write_qa(qa_text(result="fail"))
        self.assert_fails("'fail', not 'pass'", FakeGit(self.root))

    def test_older_pass_does_not_count(self):
        self.write_qa(qa_text(commit=OLD, result="fail"))
        self.assert_fails("'fail'", FakeGit(self.root))

    def test_unknown_commit(self):
        self.write_qa(qa_text(commit="d" * 40))
        self.assert_fails("does not have", FakeGit(self.root))

    def test_stale_commit_with_code_change(self):
        self.write_qa(qa_text(commit=OLD))
        git = FakeGit(self.root, changed=[".sdlc/task/5/QA.md", "src/app.py"])
        self.assert_fails("also changes src/app.py", git)

    def test_old_commit_with_only_task_folder_changes(self):
        self.write_qa(qa_text(commit=OLD))
        git = FakeGit(self.root, changed=[".sdlc/task/5/QA.md"])
        self.assertEqual(qa_check.check(str(self.task), git), OLD)

    def test_other_task_folder_is_not_exempt(self):
        self.write_qa(qa_text(commit=OLD))
        git = FakeGit(self.root, changed=[".sdlc/task/50/QA.md"])
        self.assert_fails("also changes", git)

    def test_commit_not_ancestor(self):
        self.write_qa(qa_text(commit=OLD))
        self.assert_fails("not an ancestor", FakeGit(self.root, ancestor=False))

    def test_folder_outside_repository_needs_exact_head(self):
        self.write_qa(qa_text(commit=OLD))
        git = FakeGit(self.root / "elsewhere", changed=[".sdlc/task/5/QA.md"])
        self.assert_fails("also changes", git)

    def test_main_exit_codes(self):
        self.write_qa(qa_text(result="fail"))
        with redirect_stdout(io.StringIO()) as out:
            self.assertEqual(qa_check.main([str(self.task)]), 1)
            self.assertEqual(qa_check.main([]), 1)
        self.assertIn("'fail', not 'pass'", out.getvalue())


if __name__ == "__main__":
    unittest.main()
