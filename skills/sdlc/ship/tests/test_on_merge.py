"""Tests for on_merge.py. They fake every git and gh call."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import on_merge  # noqa: E402


def done(stdout="", returncode=0, stderr=""):
    """Return a CompletedProcess with the given output."""
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class FakeRunner:
    """Answer commands by the first matching rule and record each call."""

    def __init__(self, state="MERGED", issues=(7,), claimed=True, failing=None):
        self.pr = {"state": state, "closingIssuesReferences": [{"number": n} for n in issues]}
        self.claimed = claimed
        self.failing = failing
        self.calls = []

    def __call__(self, cmd):
        self.calls.append(cmd)
        if cmd[:3] == ["gh", "pr", "view"]:
            return done(json.dumps(self.pr))
        if cmd[:2] == ["git", "ls-remote"]:
            return done(f"abc\t{cmd[-1]}\n" if self.claimed else "")
        if self.failing and Path(cmd[1]).name == self.failing:
            return done(returncode=1, stderr="boom")
        return done()

    def scripts(self):
        """Return each sibling script call as (name, args)."""
        return [(Path(c[1]).name, c[2:]) for c in self.calls if c[0] == sys.executable]


class OnMergeTest(unittest.TestCase):
    def test_releases_claim_then_sets_done(self):
        fake = FakeRunner()
        self.assertEqual(on_merge.main(["12"], run=fake), 0)
        self.assertEqual(fake.scripts(), [("claim.py", ["--release", "7"]), ("stage.py", ["7", "done"])])

    def test_skips_release_when_claim_is_gone(self):
        fake = FakeRunner(claimed=False)
        self.assertEqual(on_merge.main(["12"], run=fake), 0)
        self.assertEqual(fake.scripts(), [("stage.py", ["7", "done"])])

    def test_handles_every_closed_issue(self):
        fake = FakeRunner(issues=(7, 8), claimed=False)
        on_merge.main(["12"], run=fake)
        self.assertEqual(fake.scripts(), [("stage.py", ["7", "done"]), ("stage.py", ["8", "done"])])

    def test_open_pr_fails_and_changes_nothing(self):
        fake = FakeRunner(state="OPEN")
        self.assertEqual(on_merge.main(["12"], run=fake), 1)
        self.assertEqual(fake.scripts(), [])

    def test_no_issue_is_nothing_to_do(self):
        fake = FakeRunner(issues=())
        self.assertEqual(on_merge.main(["12"], run=fake), 0)
        self.assertEqual(fake.scripts(), [])

    def test_failed_step_fails_but_runs_the_rest(self):
        fake = FakeRunner(failing="claim.py")
        self.assertEqual(on_merge.main(["12"], run=fake), 1)
        self.assertEqual([name for name, _ in fake.scripts()], ["claim.py", "stage.py"])

    def test_bad_argument_fails(self):
        self.assertEqual(on_merge.main(["abc"], run=FakeRunner()), 1)


if __name__ == "__main__":
    unittest.main()
