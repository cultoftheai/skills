import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import contextlib
import io
import json

import ready
from fakes import FakeRunner


def issue(number, blockers=(), sub_issues=0):
    """Return an issue as gh issue list prints it."""
    return {
        "number": number,
        "title": f"Task {number}",
        "blockedBy": {"nodes": [{"number": n, "state": s} for n, s in blockers], "totalCount": len(blockers)},
        "subIssuesSummary": {"total": sub_issues, "completed": 0, "percentCompleted": 0},
    }


def run_ready(issues, claims):
    """Run ready.py against fake gh and git output. Return the exit code and the printed lines."""
    runner = FakeRunner([(["gh", "issue", "list"], 0, json.dumps(issues)), (["git", "ls-remote"], 0, claims)])
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = ready.main([], runner)
    return code, out.getvalue().splitlines()


class ReadyTest(unittest.TestCase):
    def test_lists_only_free_tasks_in_order(self):
        issues = [
            issue(9),
            issue(3),
            issue(4, blockers=[(3, "OPEN")]),
            issue(5, blockers=[(1, "CLOSED")]),
            issue(6, sub_issues=2),
            issue(7),
        ]
        code, lines = run_ready(issues, "abc123\trefs/sdlc/claims/7\n")
        self.assertEqual(code, 0)
        self.assertEqual(lines, ["#3 Task 3", "#5 Task 5", "#9 Task 9"])

    def test_blocker_without_state_counts_as_open(self):
        self.assertTrue(ready.has_open_blocker({"blockedBy": {"nodes": [{"number": 2}]}}))

    def test_failure_exits_1(self):
        runner = FakeRunner([(["gh", "issue", "list"], 1, "")])
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(ready.main([], runner), 1)


if __name__ == "__main__":
    unittest.main()
