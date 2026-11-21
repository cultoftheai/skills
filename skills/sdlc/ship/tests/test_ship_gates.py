"""Tests for ship_gates.py. They fake every git and gh call."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import ship_gates  # noqa: E402

HEAD = "a" * 40


def done(stdout="", returncode=0, stderr=""):
    """Return a CompletedProcess with the given output."""
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


def review(state, login, typename="User"):
    """Return one latestOpinionatedReviews node."""
    return {"state": state, "author": {"__typename": typename, "login": login}}


def thread(resolved, login):
    """Return one review thread whose newest comment is by login."""
    comment = {"url": f"https://example.test/{login}", "author": {"login": login}}
    return {"isResolved": resolved, "comments": {"nodes": [comment]}}


def pr_data(reviews=None, threads=None, issues=(7,), decision="APPROVED"):
    """Return a pullRequest object as the GraphQL query gives it."""
    return {
        "headRefOid": HEAD,
        "reviewDecision": decision,
        "author": {"login": "dev"},
        "closingIssuesReferences": {"nodes": [{"number": n} for n in issues]},
        "latestOpinionatedReviews": {"nodes": reviews if reviews is not None else [review("APPROVED", "lead")]},
        "reviewThreads": {"nodes": threads or []},
    }


class FakeRunner:
    """Answer commands by the first matching prefix and record each call."""

    def __init__(self, answers):
        self.answers = answers
        self.calls = []

    def __call__(self, cmd, cwd=None):
        self.calls.append((cmd, cwd))
        for prefix, answer in self.answers:
            if cmd[: len(prefix)] == prefix:
                return answer
        return done(returncode=1, stderr=f"unexpected: {cmd}")


def runner(data=None, checks=None, extra=()):
    """Return a FakeRunner for a PR with the given data and checks."""
    graphql = {"data": {"repository": {"pullRequest": data or pr_data()}}}
    return FakeRunner([
        *extra,
        (["gh", "api", "graphql"], done(json.dumps(graphql))),
        (["gh", "pr", "checks"], done(json.dumps(checks if checks is not None else [{"name": "ci", "bucket": "pass"}]))),
        (["git", "rev-parse", "HEAD"], done(HEAD + "\n")),
        (["git", "rev-parse", "--git-path", "sdlc/qa"], done(".git/sdlc/qa\n")),
        (["git", "cat-file", "-e"], done()),
        ([sys.executable], done("QA check passed: pass recorded for " + HEAD)),
    ])


def run_main(fake):
    """Run main with the fake and return the exit code."""
    return ship_gates.main(["12"], run=fake, task_path=".sdlc/task")


class ApprovalGateTest(unittest.TestCase):
    def test_person_approval_passes(self):
        self.assertEqual(ship_gates.approval_gate(pr_data()), (True, "approved by lead"))

    def test_bot_approval_does_not_count(self):
        passed, detail = ship_gates.approval_gate(pr_data([review("APPROVED", "ci-app", "Bot")]))
        self.assertFalse(passed)
        self.assertIn("no approval from a person", detail)

    def test_no_review_fails(self):
        self.assertFalse(ship_gates.approval_gate(pr_data([]))[0])

    def test_changes_requested_fails(self):
        data = pr_data([review("APPROVED", "lead"), review("CHANGES_REQUESTED", "qa")])
        self.assertEqual(ship_gates.approval_gate(data), (False, "changes requested by qa"))

    def test_review_required_fails(self):
        self.assertFalse(ship_gates.approval_gate(pr_data(decision="REVIEW_REQUIRED"))[0])

    def test_no_branch_protection_passes(self):
        self.assertTrue(ship_gates.approval_gate(pr_data(decision=None))[0])


class ChecksGateTest(unittest.TestCase):
    def test_failed_check_fails(self):
        fake = runner(checks=[{"name": "ci", "bucket": "pass"}, {"name": "lint", "bucket": "fail"}])
        self.assertEqual(ship_gates.checks_gate(12, fake), (False, "failed: lint"))

    def test_pending_check_fails(self):
        fake = runner(checks=[{"name": "ci", "bucket": "pending"}])
        self.assertEqual(ship_gates.checks_gate(12, fake), (False, "pending: ci"))

    def test_skipped_check_passes(self):
        fake = runner(checks=[{"name": "ci", "bucket": "pass"}, {"name": "deploy", "bucket": "skipping"}])
        self.assertTrue(ship_gates.checks_gate(12, fake)[0])

    def test_no_checks_passes(self):
        fake = runner(extra=[(["gh", "pr", "checks"], done(returncode=1, stderr="no checks reported on the 'x' branch"))])
        self.assertEqual(ship_gates.checks_gate(12, fake), (True, "no checks reported"))


class ThreadsGateTest(unittest.TestCase):
    def test_thread_answered_by_author_passes(self):
        self.assertTrue(ship_gates.threads_gate(pr_data(threads=[thread(False, "dev")]))[0])

    def test_resolved_thread_passes(self):
        self.assertTrue(ship_gates.threads_gate(pr_data(threads=[thread(True, "lead")]))[0])

    def test_reviewer_last_fails(self):
        passed, detail = ship_gates.threads_gate(pr_data(threads=[thread(False, "lead")]))
        self.assertFalse(passed)
        self.assertIn("https://example.test/lead", detail)


class QaGateTest(unittest.TestCase):
    def test_runs_qa_check_on_task_folder(self):
        fake = runner()
        self.assertTrue(ship_gates.qa_gate(pr_data(), ".sdlc/task", fake)[0])
        self.assertEqual(fake.calls[-1][0][-1], ".sdlc/task/7")

    def test_local_head_must_be_pr_head(self):
        fake = runner(extra=[(["git", "rev-parse", "HEAD"], done("b" * 40))])
        passed, detail = ship_gates.qa_gate(pr_data(), ".sdlc/task", fake)
        self.assertFalse(passed)
        self.assertIn("is not the PR head", detail)

    def test_qa_check_failure_fails(self):
        fake = runner(extra=[([sys.executable], done("QA check failed: stale", returncode=1))])
        self.assertEqual(ship_gates.qa_gate(pr_data(), ".sdlc/task", fake), (False, "QA check failed: stale"))

    def test_no_issue_checks_xs_evidence(self):
        fake = runner()
        self.assertTrue(ship_gates.qa_gate(pr_data(issues=()), ".sdlc/task", fake)[0])
        self.assertEqual(fake.calls[-1][0][-1], ".git/sdlc/qa")

    def test_no_issue_without_xs_evidence_fails(self):
        missing = "QA check failed: .git/sdlc/qa/QA.md does not exist; run prove first"
        fake = runner(extra=[([sys.executable], done(missing, returncode=1))])
        self.assertEqual(ship_gates.qa_gate(pr_data(issues=()), ".sdlc/task", fake), (False, missing))

    def test_missing_qa_fails(self):
        fake = runner(extra=[
            (["git", "cat-file", "-e"], done(returncode=128)),
            (["git", "log"], done("")),
        ])
        passed, detail = ship_gates.qa_gate(pr_data(), ".sdlc/task", fake)
        self.assertFalse(passed)
        self.assertIn("run prove first", detail)

    def test_removed_folder_checks_commit_before_removal(self):
        fake = runner(extra=[
            (["git", "cat-file", "-e"], done(returncode=128)),
            (["git", "log"], done("c" * 40 + "\n")),
            (["git", "diff"], done(".sdlc/task/7/QA.md\n.sdlc/task/7/SPEC.md\n")),
            (["git", "worktree"], done()),
        ])
        self.assertTrue(ship_gates.qa_gate(pr_data(), ".sdlc/task", fake)[0])
        commands = [cmd for cmd, _ in fake.calls]
        add = next(cmd for cmd in commands if cmd[:3] == ["git", "worktree", "add"])
        self.assertEqual(add[-1], "c" * 40 + "^")
        qa_cwd = next(cwd for cmd, cwd in fake.calls if cmd[0] == sys.executable)
        self.assertEqual(qa_cwd, add[-2])
        self.assertEqual(commands[-1][:3], ["git", "worktree", "remove"])

    def test_code_change_after_removal_fails(self):
        fake = runner(extra=[
            (["git", "cat-file", "-e"], done(returncode=128)),
            (["git", "log"], done("c" * 40)),
            (["git", "diff"], done(".sdlc/task/7/QA.md\nsrc/app.txt\n")),
        ])
        passed, detail = ship_gates.qa_gate(pr_data(), ".sdlc/task", fake)
        self.assertFalse(passed)
        self.assertIn("src/app.txt", detail)


class MainTest(unittest.TestCase):
    def test_all_gates_pass(self):
        self.assertEqual(run_main(runner()), 0)

    def test_one_failed_gate_fails(self):
        self.assertEqual(run_main(runner(data=pr_data(reviews=[]))), 1)

    def test_bad_argument_fails(self):
        self.assertEqual(ship_gates.main([], run=runner()), 1)

    def test_unreadable_pr_fails(self):
        fake = runner(extra=[(["gh", "api", "graphql"], done(returncode=1, stderr="not found"))])
        self.assertEqual(run_main(fake), 1)


if __name__ == "__main__":
    unittest.main()
