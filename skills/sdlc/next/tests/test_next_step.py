"""Tests for next_step.py. gh, git and the helper scripts are faked."""

import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import next_step


def labels(*names):
    """Return a labels connection."""
    return {"nodes": [{"name": name} for name in names]}


def issue(number, *names, state="OPEN", parent=None, subs=(), prs=()):
    """Return an issue node as the GraphQL query returns it."""
    return {
        "__typename": "Issue",
        "number": number,
        "state": state,
        "labels": labels(*names),
        "parent": {"number": parent} if parent else None,
        "subIssues": {"nodes": [{"number": n, "state": s, "labels": labels(*ls)} for n, s, ls in subs]},
        "closedByPullRequestsReferences": {"nodes": [{"number": n, "state": s} for n, s in prs]},
    }


def pr(number, closes=None, state="OPEN", body="", reviews=(), requests=(), threads=()):
    """Return a pull request node. reviews are (state, login, typename); threads are (resolved, last login)."""
    return {
        "__typename": "PullRequest",
        "number": number,
        "state": state,
        "body": body,
        "author": {"login": "dev"},
        "closingIssuesReferences": {"nodes": [{"number": closes}] if closes else []},
        "reviews": {"nodes": [{"state": s, "author": {"login": l, "__typename": t}} for s, l, t in reviews]},
        "reviewRequests": {"nodes": [{"requestedReviewer": {"__typename": "User", "login": l}} for l in requests]},
        "reviewThreads": {
            "nodes": [{"isResolved": r, "comments": {"nodes": [{"author": {"login": l}}]}} for r, l in threads]
        },
    }


class FakeRunner:
    """Answers gh, git and helper script calls from fixed data and records every call."""

    def __init__(self, items=(), claims=(), ready=(), gates=""):
        self.items = {item["number"]: item for item in items}
        self.claims = set(claims)
        self.ready = list(ready)
        self.gates = gates
        self.calls = []

    def __call__(self, args):
        self.calls.append(list(args))
        if args[:3] == ["gh", "api", "graphql"]:
            number = int(args[-1].split("=")[1])
            return self.done(json.dumps({"data": {"repository": {"issueOrPullRequest": self.items.get(number)}}}))
        if args[:2] == ["git", "ls-remote"]:
            number = int(args[-1].rsplit("/", 1)[1])
            return self.done(f"abc\t{args[-1]}\n" if number in self.claims else "")
        if args[1:] == [".sdlc/scripts/ready.py"]:
            return self.done("".join(f"#{n} Task {n}\n" for n in self.ready))
        if args[1] == ".sdlc/scripts/ship_gates.py":
            return subprocess.CompletedProcess(args, 1 if "fail" in self.gates else 0, self.gates, "")
        raise AssertionError(f"unexpected command: {args}")

    @staticmethod
    def done(stdout):
        return subprocess.CompletedProcess([], 0, stdout, "")


class NextStepCase(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.settings = Path(folder.name) / "settings.json"
        self.settings.write_text("{}")

    def next_line(self, argv, runner=None, env=None):
        """Run main and return the printed Next: line."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            self.code = next_step.main(argv, runner or FakeRunner(), env or {}, self.settings)
        return out.getvalue().strip().splitlines()[-1]


class SettingsAndFormTest(NextStepCase):
    def test_missing_settings_points_to_setup(self):
        self.settings.unlink()
        self.assertEqual(self.next_line(["5", "--after", "prove"]), "Next: /sdlc:setup")
        self.assertEqual(self.next_line(["5", "--after", "prove", "--auto"]), "Next: /sdlc:setup --auto")

    def test_auto_is_added_to_commands_and_waits(self):
        self.assertEqual(self.next_line(["5", "--after", "prove", "--auto"]), "Next: /sdlc:submit 5 --auto")
        runner = FakeRunner([pr(9, closes=5)], gates="approval: fail - no approval from a person\n")
        line = self.next_line(["9", "--after", "ship", "--result", "fail", "--auto"], runner)
        self.assertTrue(line.endswith("then run /sdlc:ship 9 --auto"), line)

    def test_codex_form_from_flag_and_environment(self):
        self.assertEqual(self.next_line(["5", "--after", "prove", "--harness", "codex"]), "Next: $submit 5")
        self.assertEqual(self.next_line(["5", "--after", "prove"], env={"CODEX_SANDBOX": "seatbelt"}), "Next: $submit 5")
        self.assertEqual(self.next_line(["5", "--after", "prove"], env={"CLAUDECODE": "1"}), "Next: /sdlc:submit 5")
        self.assertEqual(self.next_line(["5", "--after", "prove"], env={"SDLC_HARNESS": "codex", "CLAUDECODE": "1"}), "Next: $submit 5")

    def test_bad_arguments_exit_2(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as stop:
            next_step.main(["abc"], FakeRunner(), {}, self.settings)
        self.assertEqual(stop.exception.code, 2)

    def test_gh_error_prints_a_next_line_and_exits_1(self):
        line = self.next_line(["404", "--after", "review"], FakeRunner())
        self.assertEqual(self.code, 1)
        self.assertTrue(line.startswith("Next: fix this error") and line.endswith("then run /sdlc:next 404"), line)


class AfterSkillTest(NextStepCase):
    def test_setup(self):
        self.assertEqual(self.next_line(["-", "--after", "setup"]), 'Next: /sdlc:frame "<your first request>"')

    def test_frame_xs_goes_to_build(self):
        self.assertEqual(self.next_line(["-", "--after", "frame"]), 'Next: /sdlc:build "<the edit in words>"')

    def test_frame_without_criteria_is_a_stop(self):
        line = self.next_line(["-", "--after", "frame", "--result", "fail"])
        self.assertEqual(line, 'Next: add the facts that the acceptance criteria need to the request, then run /sdlc:frame "<the request>"')

    def test_frame_routes_by_size(self):
        runner = FakeRunner([issue(1, "ready", "size:S"), issue(2, "ready", "size:M"), issue(3, "ready", "size:L")])
        self.assertEqual(self.next_line(["1", "--after", "frame"], runner), "Next: /sdlc:shape 1")
        self.assertEqual(self.next_line(["2", "--after", "frame"], runner), "Next: /sdlc:slice 2")
        self.assertEqual(self.next_line(["3", "--after", "frame"], runner), "Next: /sdlc:shape 3")

    def test_frame_xl_epic_frames_each_story(self):
        epic = issue(10, "size:XL", subs=[(11, "OPEN", ("ready", "size:S")), (12, "OPEN", ())])
        self.assertEqual(self.next_line(["10", "--after", "frame"], FakeRunner([epic])), "Next: /sdlc:frame 12")

    def test_frame_duplicate_in_review_routes_to_its_pr(self):
        runner = FakeRunner([issue(4, "review", "size:S", prs=[(8, "OPEN")]), pr(8, closes=4)])
        self.assertEqual(self.next_line(["4", "--after", "frame"], runner), "Next: /sdlc:review 8")

    def test_slice_first_task_and_one_task_story(self):
        runner = FakeRunner([issue(21, "ready", parent=20), issue(30, "ready", "size:S")])
        self.assertEqual(self.next_line(["21", "--after", "slice"], runner), "Next: /sdlc:shape 21")
        self.assertEqual(self.next_line(["30", "--after", "slice"], runner), "Next: /sdlc:shape 30")

    def test_slice_stop(self):
        runner = FakeRunner([issue(20, "ready", "size:L"), issue(22, "shaped", "size:M")])
        self.assertEqual(self.next_line(["20", "--after", "slice", "--result", "fail"], runner), "Next: /sdlc:shape 20")
        line = self.next_line(["22", "--after", "slice", "--result", "fail"], runner)
        self.assertEqual(line, "Next: get story #22 approved and labelled ready, then run /sdlc:slice 22")

    def test_shape_pass(self):
        runner = FakeRunner([issue(21, "shaped", parent=20), issue(20, "shaped", "size:L")])
        self.assertEqual(self.next_line(["21", "--after", "shape"], runner), "Next: /sdlc:build 21")
        self.assertEqual(self.next_line(["20", "--after", "shape"], runner), "Next: /sdlc:slice 20")

    def test_shape_claim_lost_moves_to_next_ready_task(self):
        runner = FakeRunner([issue(21, "ready", parent=20), issue(23, "ready", parent=20)], claims=[21], ready=[21, 23])
        self.assertEqual(self.next_line(["21", "--after", "shape", "--result", "fail"], runner), "Next: /sdlc:shape 23")

    def test_shape_resize(self):
        runner = FakeRunner([issue(21, "ready", parent=20), issue(20, "ready", "size:L"), issue(30, "ready", "size:M")])
        self.assertEqual(self.next_line(["21", "--after", "shape", "--result", "fail"], runner), "Next: /sdlc:frame 20")
        self.assertEqual(self.next_line(["30", "--after", "shape", "--result", "fail"], runner), "Next: /sdlc:slice 30")

    def test_build(self):
        runner = FakeRunner([issue(21, "in-progress", parent=20), issue(30, "shaped", "size:S")])
        self.assertEqual(self.next_line(["21", "--after", "build"], runner), "Next: /sdlc:prove 21")
        self.assertEqual(self.next_line(["-", "--after", "build"], runner), "Next: /sdlc:prove")
        self.assertEqual(self.next_line(["21", "--after", "build", "--result", "fail"], runner), "Next: /sdlc:frame 20")
        self.assertEqual(self.next_line(["-", "--after", "build", "--result", "fail"], runner), 'Next: /sdlc:frame "<the edit in words>"')
        line = self.next_line(["30", "--after", "build", "--result", "fail"], runner)
        self.assertEqual(line, "Next: check out the branch of #30 with its spec, then run /sdlc:build 30")

    def test_prove(self):
        self.assertEqual(self.next_line(["5", "--after", "prove", "--result", "pass"]), "Next: /sdlc:submit 5")
        self.assertEqual(self.next_line(["-", "--after", "prove", "--result", "pass"]), "Next: /sdlc:submit")
        self.assertEqual(self.next_line(["5", "--after", "prove", "--result", "fail"]), "Next: /sdlc:build 5")
        self.assertEqual(self.next_line(["-", "--after", "prove", "--result", "fail"]), 'Next: /sdlc:build "<the edit in words>"')

    def test_submit(self):
        self.assertEqual(self.next_line(["9", "--after", "submit"]), "Next: /sdlc:review 9")
        self.assertEqual(self.next_line(["5", "--after", "submit", "--result", "fail"]), "Next: /sdlc:prove 5")
        self.assertEqual(self.next_line(["-", "--after", "submit", "--result", "fail"]), "Next: /sdlc:prove")

    def test_review_of_a_pr(self):
        runner = FakeRunner([pr(9, closes=5), pr(7, body="small fix")])
        self.assertEqual(self.next_line(["9", "--after", "review", "--result", "pass"], runner), "Next: /sdlc:document 5")
        self.assertEqual(self.next_line(["9", "--after", "review", "--result", "fail"], runner), "Next: /sdlc:respond 9")
        self.assertEqual(self.next_line(["7", "--after", "review", "--result", "pass"], runner), "Next: /sdlc:ship 7")

    def test_review_of_a_spec(self):
        runner = FakeRunner([issue(5, "shaped", "size:S")])
        self.assertEqual(self.next_line(["5", "--after", "review", "--result", "pass"], runner), "Next: /sdlc:build 5")
        line = self.next_line(["5", "--after", "review", "--result", "fail"], runner)
        self.assertEqual(line, "Next: apply the review findings to the spec or design of #5, then run /sdlc:build 5")

    def test_respond(self):
        runner = FakeRunner([
            pr(9, closes=5, threads=[(False, "alice")]),
            pr(10, closes=6, requests=["alice"], threads=[(False, "dev")]),
            pr(11, closes=7, threads=[(True, "alice")]),
        ])
        self.assertEqual(self.next_line(["9", "--after", "respond"], runner), "Next: /sdlc:respond 9")
        self.assertEqual(self.next_line(["10", "--after", "respond"], runner), "Next: wait for review from @alice on PR #10, then run /sdlc:next 10")
        self.assertEqual(self.next_line(["11", "--after", "respond"], runner), "Next: /sdlc:review 11")

    def test_document(self):
        self.assertEqual(self.next_line(["9", "--after", "document"]), "Next: /sdlc:ship 9")

    def test_ship_pass(self):
        runner = FakeRunner([pr(9, closes=5, state="MERGED"), pr(7, state="MERGED"), issue(30, "ready", "size:M")], ready=[30])
        self.assertEqual(self.next_line(["9", "--after", "ship", "--result", "pass"], runner), "Next: /sdlc:retro 5")
        self.assertEqual(self.next_line(["7", "--after", "ship", "--result", "pass"], runner), "Next: /sdlc:slice 30")

    def test_ship_fail_names_the_gate(self):
        cases = [
            ("threads: fail - 1 unanswered: url\n", "Next: /sdlc:respond 9"),
            ("qa: fail - .sdlc/task/5/QA.md does not exist; run prove first\n", "Next: /sdlc:prove 5"),
            ("qa: fail - local HEAD a is not the PR head b\n", "Next: check out the head of PR #9, then run /sdlc:ship 9"),
            ("checks: fail - failed: lint\n", "Next: fix the failed checks on PR #9 (failed: lint), then run /sdlc:ship 9"),
            ("approval: fail - no approval from a person\n", "Next: wait for a person to approve PR #9 (no approval from a person), then run /sdlc:ship 9"),
            ("checks: fail - pending: test\n", "Next: wait for CI on PR #9 (pending: test), then run /sdlc:ship 9"),
            ("approval: pass - approved by alice\n", "Next: /sdlc:ship 9"),
        ]
        for gates, expected in cases:
            runner = FakeRunner([pr(9, closes=5)], gates=gates)
            self.assertEqual(self.next_line(["9", "--after", "ship", "--result", "fail"], runner), expected)

    def test_retro(self):
        runner = FakeRunner([issue(30, "ready", "size:S")], ready=[30])
        self.assertEqual(self.next_line(["5", "--after", "retro"], runner), "Next: /sdlc:shape 30")
        self.assertEqual(self.next_line(["-", "--after", "retro"], FakeRunner()), 'Next: /sdlc:frame "<your next request>"')


class RouterTest(NextStepCase):
    def test_issue_stages(self):
        runner = FakeRunner([
            issue(1),
            issue(2, "blocked", "size:S"),
            issue(3, "shaped", "size:S"),
            issue(4, "in-progress", "size:S"),
            issue(5, "review", "size:S"),
            issue(6, "ready", "size:M", subs=[(7, "CLOSED", ("done",)), (8, "OPEN", ("ready",))]),
            issue(8, "ready", parent=6),
        ])
        self.assertEqual(self.next_line(["1"], runner), "Next: /sdlc:frame 1")
        self.assertEqual(self.next_line(["2"], runner), "Next: wait until a person unblocks #2, then run /sdlc:next 2")
        self.assertEqual(self.next_line(["3"], runner), "Next: /sdlc:build 3")
        self.assertEqual(self.next_line(["4"], runner), "Next: /sdlc:build 4")
        self.assertEqual(self.next_line(["5"], runner), "Next: /sdlc:submit 5")
        self.assertEqual(self.next_line(["6"], runner), "Next: /sdlc:shape 8")

    def test_done_issue_and_no_ref_go_to_next_ready(self):
        runner = FakeRunner([issue(1, "done", state="CLOSED"), issue(3, "ready", "size:S")], ready=[3])
        self.assertEqual(self.next_line(["1"], runner), "Next: /sdlc:shape 3")
        self.assertEqual(self.next_line(["-"], runner), "Next: /sdlc:shape 3")

    def test_pull_request_states(self):
        human = ("APPROVED", "alice", "User")
        runner = FakeRunner([
            issue(4, "review", "size:S", prs=[(9, "OPEN")]),
            pr(9, closes=4),
            pr(10, closes=4, reviews=[("COMMENTED", "dev", "User")], threads=[(False, "bot")]),
            pr(11, closes=4, reviews=[human]),
            pr(12, closes=4, reviews=[("COMMENTED", "dev", "User")], requests=["alice"]),
            pr(13, closes=4, reviews=[("COMMENTED", "dev", "User")]),
            pr(14, state="CLOSED"),
        ])
        self.assertEqual(self.next_line(["4"], runner), "Next: /sdlc:review 9")
        self.assertEqual(self.next_line(["10"], runner), "Next: /sdlc:respond 10")
        self.assertEqual(self.next_line(["11"], runner), "Next: /sdlc:ship 11")
        self.assertEqual(self.next_line(["12"], runner), "Next: wait for review from @alice on PR #12, then run /sdlc:next 12")
        self.assertEqual(self.next_line(["13"], runner), "Next: /sdlc:document 4")
        self.assertEqual(self.next_line(["14"], runner), "Next: reopen PR #14 or open a new one, then run /sdlc:next 14")


if __name__ == "__main__":
    unittest.main()
