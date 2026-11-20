"""Tests for review_threads.py. They fake the gh runner and never call GitHub."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import review_threads  # noqa: E402


def comment(author, body, bot=False):
    """Return a comment node as GitHub sends it."""
    return {
        "url": f"https://github.com/o/r/pull/1#discussion_{len(body)}",
        "body": body,
        "createdAt": "2026-11-20T10:00:00Z",
        "author": {"login": author, "__typename": "Bot" if bot else "User"},
    }


def thread(thread_id, comments, resolved=False):
    """Return a review thread node as GitHub sends it."""
    return {
        "id": thread_id,
        "isResolved": resolved,
        "isOutdated": False,
        "path": "src/app.py",
        "line": 10,
        "viewerCanResolve": True,
        "comments": {"nodes": comments},
    }


def page(nodes, next_cursor=None):
    """Return one page of the list query response."""
    threads = {"pageInfo": {"hasNextPage": next_cursor is not None, "endCursor": next_cursor}, "nodes": nodes}
    return json.dumps({"data": {"viewer": {"login": "me"}, "repository": {"pullRequest": {"reviewThreads": threads}}}})


class FakeRunner:
    """Return canned responses in order and record each call."""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        return self.responses.pop(0)


class ListTest(unittest.TestCase):
    def test_skips_resolved_threads_and_follows_pages(self):
        run = FakeRunner(
            page([thread("T1", [comment("rev", "fix this")]), thread("T2", [comment("rev", "x")], resolved=True)], "c1"),
            page([thread("T3", [comment("rev", "and this")])]),
        )
        threads = review_threads.list_threads(run, "7", ":robot:")
        self.assertEqual([t["id"] for t in threads], ["T1", "T3"])
        self.assertIn("cursor=c1", run.calls[1])
        self.assertIn("number=7", run.calls[0])
        self.assertIn("owner={owner}", run.calls[0])

    def test_needs_reply_is_false_when_our_reply_is_last(self):
        run = FakeRunner(page([thread("T1", [comment("rev", "fix"), comment("me", ":robot: Fixed in abc1234.")])]))
        [listed] = review_threads.list_threads(run, "7", ":robot:")
        self.assertFalse(listed["needs_reply"])
        self.assertEqual(listed["rounds"], 1)

    def test_rounds_count_only_our_prefixed_replies(self):
        comments = [
            comment("rev", "fix"),
            comment("me", ":robot: Fixed in abc."),
            comment("me", "a manual note"),
            comment("rev", "still wrong"),
            comment("me", ":robot: Fixed again in def."),
            comment("bot", "nope", bot=True),
        ]
        [listed] = review_threads.list_threads(FakeRunner(page([thread("T1", comments)])), "7", ":robot:")
        self.assertTrue(listed["needs_reply"])
        self.assertEqual(listed["rounds"], 2)
        self.assertTrue(listed["comments"][-1]["bot"])


class ReplyTest(unittest.TestCase):
    def test_returns_the_url(self):
        url = "https://github.com/o/r/pull/1#discussion_r9"
        run = FakeRunner(json.dumps({"data": {"addPullRequestReviewThreadReply": {"comment": {"url": url}}}}))
        self.assertEqual(review_threads.reply(run, "T1", ":robot: Fixed in abc.", ":robot:"), url)
        self.assertIn("body=:robot: Fixed in abc.", run.calls[0])

    def test_refuses_a_body_without_the_prefix(self):
        run = FakeRunner()
        with self.assertRaises(review_threads.UsageError):
            review_threads.reply(run, "T1", "Fixed in abc.", ":robot:")
        self.assertEqual(run.calls, [])

    def test_fails_when_github_returns_no_url(self):
        run = FakeRunner(json.dumps({"data": {"addPullRequestReviewThreadReply": None}}))
        with self.assertRaises(review_threads.CommandError):
            review_threads.reply(run, "T1", ":robot: ok", ":robot:")


class ResolveTest(unittest.TestCase):
    def test_refuses_when_the_reviewer_resolves(self):
        run = FakeRunner()
        with self.assertRaises(review_threads.NotAllowedError):
            review_threads.resolve(run, "T1", "reviewer")
        self.assertEqual(run.calls, [])

    def test_resolves_when_the_author_resolves(self):
        run = FakeRunner(json.dumps({"data": {"resolveReviewThread": {"thread": {"isResolved": True}}}}))
        review_threads.resolve(run, "T1", "author")
        self.assertIn("thread=T1", run.calls[0])


class SettingsTest(unittest.TestCase):
    def test_defaults_when_the_file_is_missing(self):
        settings = review_threads.load_settings(Path(tempfile.gettempdir()) / "no-such-settings.json")
        self.assertEqual(review_threads.setting(settings, "review.prefix"), ":robot:")
        self.assertEqual(review_threads.setting(settings, "review.resolve"), "reviewer")

    def test_reads_nested_and_flat_keys(self):
        self.assertEqual(review_threads.setting({"review": {"prefix": "[bot]"}}, "review.prefix"), "[bot]")
        self.assertEqual(review_threads.setting({"review.resolve": "author"}, "review.resolve"), "author")


class MainTest(unittest.TestCase):
    def test_reply_without_prefix_exits_2(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as body:
            body.write("no prefix")
        self.assertEqual(review_threads.main(["reply", "T1", body.name], FakeRunner(), {}), 2)

    def test_resolve_with_default_settings_exits_3(self):
        self.assertEqual(review_threads.main(["resolve", "T1"], FakeRunner(), {}), 3)

    def test_gh_failure_exits_1(self):
        def failing(args):
            raise review_threads.CommandError("HTTP 401")

        self.assertEqual(review_threads.main(["list", "7"], failing, {}), 1)

    def test_bad_usage_exits_2(self):
        self.assertEqual(review_threads.main(["list", "#7"], FakeRunner(), {}), 2)


if __name__ == "__main__":
    unittest.main()
