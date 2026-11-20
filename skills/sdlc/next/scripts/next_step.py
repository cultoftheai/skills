#!/usr/bin/env python3
"""Print the Next: line, the full command to run after a skill or for an issue.

Usage: next_step.py <issue-or-pr|-> [--after <skill>] [--result pass|fail] [--auto] [--harness claude-code|codex]

- <issue-or-pr> is an issue or PR number. "-" means no issue: XS work, a
  first run after setup, or a repo retro.
- With --after, the TRANSITIONS table maps the skill that just ran and its
  result (default pass) to the next command. Where the result alone cannot
  decide, the script reads the issue or PR with gh.
- Without --after, the script reads where the issue or PR stands (size,
  stage, PR state, review threads) and names the skill that comes next.
  With "-", it names the next ready task.
- --auto adds --auto to the printed command.
- --harness picks the command form. Default: the SDLC_HARNESS environment
  variable, else detected from the environment, else claude-code.

When no skill can run yet, the line says what it waits for or what a person
must do, then the command to run after that. Without .sdlc/settings.json the
line is "Next: /setup".

Exit code 0 when it printed a Next: line, 2 on bad arguments, 1 when gh,
git or a helper script fails (it still prints a Next: line).
"""

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SETTINGS = Path(".sdlc/settings.json")
SKILLS = ("setup", "frame", "slice", "shape", "build", "prove", "submit", "review", "respond", "document", "ship", "retro")
STAGES = ("ready", "shaped", "in-progress", "review", "done", "blocked")
COMMAND_PREFIX = {"claude-code": "/", "codex": "$"}
EDIT = '"<the edit in words>"'
FIRST_REQUEST = '"<your first request>"'
NEXT_REQUEST = '"<your next request>"'
CLAIM_PREFIX = "refs/sdlc/claims/"
CLOSING_KEYWORD = re.compile(r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)", re.I)
ITEM_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issueOrPullRequest(number: $number) {
      __typename
      ... on Issue {
        number state
        labels(first: 50) { nodes { name } }
        parent { number }
        subIssues(first: 50) { nodes { number state labels(first: 50) { nodes { name } } } }
        closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number state } }
      }
      ... on PullRequest {
        number state body
        author { login }
        closingIssuesReferences(first: 10) { nodes { number } }
        reviews(first: 100) { nodes { state author { __typename login } } }
        reviewRequests(first: 20) { nodes { requestedReviewer { __typename ... on User { login } } } }
        reviewThreads(first: 100) { nodes { isResolved comments(last: 1) { nodes { author { login } } } } }
      }
    }
  }
}
"""


class CommandError(Exception):
    """A command that exited with a non-zero code."""


@dataclass(frozen=True)
class Command:
    """A skill command with its arguments."""

    skill: str
    args: tuple = ()

    def render(self, prefix, auto):
        """Return the command as a person types it."""
        parts = [f"{prefix}{self.skill}", *map(str, self.args)] + (["--auto"] if auto else [])
        return " ".join(parts)


@dataclass(frozen=True)
class Wait:
    """What must happen before the command can run: a wait or a person's action."""

    reason: str
    then: Command

    def render(self, prefix, auto):
        """Return the reason and the command to run after it."""
        return f"{self.reason}, then run {self.then.render(prefix, auto)}"


def run(args):
    """Run a command and return the completed process with text output."""
    return subprocess.run(args, capture_output=True, text=True)


def output_of(args, runner):
    """Run a command and return its stdout, or raise CommandError."""
    result = runner(args)
    if result.returncode != 0:
        raise CommandError(result.stderr.strip() or f"{' '.join(args)} failed")
    return result.stdout


class Tracker:
    """Reads issues, pull requests, claims and ready tasks through gh, git and the helper scripts."""

    def __init__(self, runner):
        self.runner = runner

    def item(self, number):
        """Return the issue or pull request with this number as a dict with a __typename key."""
        args = ["gh", "api", "graphql", "-f", f"query={ITEM_QUERY}", "-F", "owner={owner}", "-F", "name={repo}", "-F", f"number={number}"]
        found = json.loads(output_of(args, self.runner))["data"]["repository"]["issueOrPullRequest"]
        if not found:
            raise CommandError(f"#{number} is not an issue or a pull request")
        return found

    def claimed(self, number):
        """Return True when the issue has a claim ref on origin."""
        return bool(output_of(["git", "ls-remote", "origin", f"{CLAIM_PREFIX}{number}"], self.runner).strip())

    def ready_numbers(self):
        """Return the numbers that ready.py lists, in its order."""
        output = output_of(["python3", ".sdlc/scripts/ready.py"], self.runner)
        return [int(match) for match in re.findall(r"^#(\d+)", output, re.M)]

    def gate_failures(self, pr):
        """Return a dict of failed ship gate name to its detail, from ship_gates.py."""
        output = self.runner(["python3", ".sdlc/scripts/ship_gates.py", str(pr)]).stdout
        failures = re.findall(r"^(\w+): fail - (.*)$", output, re.M)
        return dict(failures)


def label_names(node):
    """Return the label names of an issue node."""
    return [label["name"] for label in (node.get("labels") or {}).get("nodes", [])]


def stage(node):
    """Return the stage label of an issue node, or None."""
    return next((name for name in label_names(node) if name in STAGES), None)


def size(node):
    """Return the size of an issue node (XS to XL), or None."""
    return next((name[len("size:"):] for name in label_names(node) if name.startswith("size:")), None)


def sub_issues(node):
    """Return the sub-issue nodes of an issue, lowest number first."""
    return sorted((node.get("subIssues") or {}).get("nodes", []), key=lambda sub: sub["number"])


def open_subs(node):
    """Return the open sub-issues that are not done."""
    return [sub for sub in sub_issues(node) if sub["state"] == "OPEN" and stage(sub) != "done"]


def parent_number(node):
    """Return the number of the parent issue, or None."""
    return (node.get("parent") or {}).get("number")


def open_pr_number(issue):
    """Return the number of an open pull request that closes the issue, or None."""
    prs = (issue.get("closedByPullRequestsReferences") or {}).get("nodes", [])
    return next((pr["number"] for pr in prs if pr["state"] == "OPEN"), None)


def closing_issue(pr):
    """Return the issue number that the pull request closes, or None for XS work."""
    nodes = (pr.get("closingIssuesReferences") or {}).get("nodes", [])
    if nodes:
        return nodes[0]["number"]
    match = CLOSING_KEYWORD.search(pr.get("body") or "")
    return int(match.group(1)) if match else None


def pr_author(pr):
    """Return the login of the pull request author."""
    return (pr.get("author") or {}).get("login")


def threads_needing_reply(pr):
    """Return the unresolved review threads whose last comment is not by the PR author."""
    threads = (pr.get("reviewThreads") or {}).get("nodes", [])
    return [t for t in threads if not t["isResolved"] and last_thread_author(t) != pr_author(pr)]


def last_thread_author(thread):
    """Return the login of the newest comment of a review thread."""
    comments = thread["comments"]["nodes"]
    return (comments[-1].get("author") or {}).get("login") if comments else None


def reviews(pr):
    """Return the review nodes of a pull request."""
    return (pr.get("reviews") or {}).get("nodes", [])


def has_human_approval(pr):
    """Return True when a person other than the author approved the pull request."""
    return any(
        r["state"] == "APPROVED" and (r.get("author") or {}).get("__typename") == "User" and r["author"]["login"] != pr_author(pr)
        for r in reviews(pr)
    )


def requested_reviewers(pr):
    """Return the logins of the people asked to review the pull request."""
    requests = (pr.get("reviewRequests") or {}).get("nodes", [])
    reviewers = [r.get("requestedReviewer") or {} for r in requests]
    return [r["login"] for r in reviewers if r.get("__typename") == "User"]


class Router:
    """Decides the next command from the state of an issue or a pull request."""

    def __init__(self, tracker):
        self.tracker = tracker

    def route(self, number):
        """Return the next step for an issue or a pull request number."""
        item = self.tracker.item(number)
        if item["__typename"] == "PullRequest":
            return self.route_pr(item)
        return self.route_issue(item)

    def route_issue(self, issue):
        """Return the next step for an issue, from its size, stage, sub-issues and PR."""
        number, current = issue["number"], stage(issue)
        if issue["state"] != "OPEN" or current == "done":
            return self.next_ready(skip={number})
        if current == "blocked":
            return Wait(f"wait until a person unblocks #{number}", Command("next", (number,)))
        if size(issue) == "XL":
            return self.route_epic(issue)
        if current is None:
            return Command("frame", (number,))
        return self.route_stage(issue, current)

    def route_stage(self, issue, current):
        """Return the next step for an issue that has a stage label."""
        number = issue["number"]
        if current == "ready" and open_subs(issue):
            return self.route(open_subs(issue)[0]["number"])
        if current == "ready":
            return Command("slice" if size(issue) == "M" else "shape", (number,))
        if current == "shaped":
            return Command("slice" if size(issue) == "L" else "build", (number,))
        pr = open_pr_number(issue)
        if pr:
            return self.route(pr)
        return Command("build" if current == "in-progress" else "submit", (number,))

    def route_epic(self, epic):
        """Return the next step for an XL epic: frame the next story, or route the first open one."""
        unframed = [sub for sub in open_subs(epic) if size(sub) is None and stage(sub) is None]
        if unframed:
            return Command("frame", (unframed[0]["number"],))
        if open_subs(epic):
            return self.route(open_subs(epic)[0]["number"])
        return self.next_ready(skip={epic["number"]})

    def route_pr(self, pr):
        """Return the next step for a pull request, from its state, reviews and threads."""
        number, task = pr["number"], closing_issue(pr)
        if pr["state"] == "MERGED":
            return self.next_ready()
        if pr["state"] == "CLOSED":
            return Wait(f"reopen PR #{number} or open a new one", Command("next", (task or number,)))
        if threads_needing_reply(pr):
            return Command("respond", (number,))
        if not reviews(pr):
            return Command("review", (number,))
        if has_human_approval(pr):
            return Command("ship", (number,))
        if requested_reviewers(pr):
            return wait_for_review(pr)
        return Command("document", (task,)) if task else Command("ship", (number,))

    def next_ready(self, skip=frozenset()):
        """Return the step for the first ready task, or frame a new request when none is ready."""
        numbers = [n for n in self.tracker.ready_numbers() if n not in skip]
        if not numbers:
            return Command("frame", (NEXT_REQUEST,))
        return self.route(numbers[0])


def wait_for_review(pr):
    """Return the wait for the people asked to review the pull request."""
    logins = ", ".join(f"@{login}" for login in requested_reviewers(pr))
    return Wait(f"wait for review from {logins} on PR #{pr['number']}", Command("next", (pr["number"],)))


@dataclass
class Context:
    """One call: the ref, the skill that ran, its result, and the tools to read state."""

    ref: int
    failed: bool
    tracker: Tracker
    router: Router

    def item(self):
        """Return the issue or pull request of the ref."""
        return self.tracker.item(self.ref)

    def task_args(self):
        """Return the ref as command arguments, or none for XS work."""
        return (self.ref,) if self.ref else ()


def after_setup(ctx):
    """setup: frame the first request."""
    return Command("frame", (FIRST_REQUEST,))


def after_frame(ctx):
    """frame: XS goes to build; a stop needs criteria; an issue is routed by its size and stage."""
    if ctx.failed:
        return Wait("add the facts that the acceptance criteria need to the request", Command("frame", (ctx.ref or '"<the request>"',)))
    if not ctx.ref:
        return Command("build", (EDIT,))
    return ctx.router.route(ctx.ref)


def after_slice(ctx):
    """slice: route the task or the re-sized story; a stop names the missing design or approval."""
    if not ctx.failed:
        return ctx.router.route(ctx.ref)
    story = ctx.item()
    if size(story) == "L" and stage(story) == "ready":
        return Command("shape", (ctx.ref,))
    return Wait(f"get story #{ctx.ref} approved and labelled ready", Command("slice", (ctx.ref,)))


def after_shape(ctx):
    """shape: a spec goes to build and a design to slice; a stop moves on, re-frames or routes."""
    issue = ctx.item()
    if not ctx.failed:
        return Command("slice" if size(issue) == "L" else "build", (ctx.ref,))
    if stage(issue) == "ready" and ctx.tracker.claimed(ctx.ref):
        return ctx.router.next_ready(skip={ctx.ref})
    parent = parent_number(issue)
    if stage(issue) == "ready" and parent and size(ctx.tracker.item(parent)) == "L":
        return Command("frame", (parent,))
    return ctx.router.route_issue(issue)


def after_build(ctx):
    """build: prove the change; a stop re-sizes through frame or names what blocks the build."""
    if not ctx.failed:
        return Command("prove", ctx.task_args())
    if not ctx.ref:
        return Command("frame", (EDIT,))
    issue = ctx.item()
    if stage(issue) == "in-progress":
        return Command("frame", (parent_number(issue) or ctx.ref,))
    if stage(issue) == "shaped":
        return Wait(f"check out the branch of #{ctx.ref} with its spec", Command("build", (ctx.ref,)))
    return ctx.router.route_issue(issue)


def after_prove(ctx):
    """prove: a pass goes to submit, a fail back to build."""
    if ctx.failed:
        return Command("build", (ctx.ref,) if ctx.ref else (EDIT,))
    return Command("submit", ctx.task_args())


def after_submit(ctx):
    """submit: review the new PR; a stop means no QA evidence for the head, so prove again."""
    if ctx.failed:
        return Command("prove", ctx.task_args())
    return Command("review", (ctx.ref,))


def after_review(ctx):
    """review: findings go to respond, a clean PR to document; a spec with findings goes back to its author."""
    item = ctx.item()
    if item["__typename"] == "Issue":
        step = ctx.router.route_issue(item)
        return Wait(f"apply the review findings to the spec or design of #{ctx.ref}", step) if ctx.failed else step
    if ctx.failed:
        return Command("respond", (ctx.ref,))
    task = closing_issue(item)
    return Command("document", (task,)) if task else Command("ship", (ctx.ref,))


def after_respond(ctx):
    """respond: retry unanswered threads, wait for a requested person, or review again."""
    pr = ctx.item()
    if threads_needing_reply(pr):
        return Command("respond", (ctx.ref,))
    if requested_reviewers(pr):
        return wait_for_review(pr)
    return Command("review", (ctx.ref,))


def after_document(ctx):
    """document: ship the PR."""
    return Command("ship", (ctx.ref,))


def after_ship(ctx):
    """ship: a merge goes to retro; a failed gate names who clears it."""
    if not ctx.failed:
        task = closing_issue(ctx.item())
        return Command("retro", (task,)) if task else ctx.router.next_ready()
    return gate_step(ctx.item(), ctx.tracker.gate_failures(ctx.ref))


def gate_step(pr_item, failures):
    """Return the step that clears the first failed ship gate, or ship again when none failed."""
    pr, task = pr_item["number"], closing_issue(pr_item)
    ship = Command("ship", (pr,))
    if "threads" in failures:
        return Command("respond", (pr,))
    if "qa" in failures and failures["qa"].startswith("local HEAD"):
        return Wait(f"check out the head of PR #{pr}", ship)
    if "qa" in failures:
        return Command("prove", (task,) if task else ())
    if "checks" in failures and failures["checks"].startswith("failed"):
        return Wait(f"fix the failed checks on PR #{pr} ({failures['checks']})", ship)
    if "approval" in failures:
        return Wait(f"wait for a person to approve PR #{pr} ({failures['approval']})", ship)
    if "checks" in failures:
        return Wait(f"wait for CI on PR #{pr} ({failures['checks']})", ship)
    return ship


def after_retro(ctx):
    """retro: the next ready task."""
    return ctx.router.next_ready()


TRANSITIONS = {
    "setup": after_setup,
    "frame": after_frame,
    "slice": after_slice,
    "shape": after_shape,
    "build": after_build,
    "prove": after_prove,
    "submit": after_submit,
    "review": after_review,
    "respond": after_respond,
    "document": after_document,
    "ship": after_ship,
    "retro": after_retro,
}


def detect_harness(env):
    """Return the harness: SDLC_HARNESS, else Claude Code when CLAUDECODE is set, else Codex when a CODEX_ variable is set."""
    if env.get("SDLC_HARNESS") in COMMAND_PREFIX:
        return env["SDLC_HARNESS"]
    if env.get("CLAUDECODE"):
        return "claude-code"
    if any(key.startswith("CODEX_") for key in env):
        return "codex"
    return "claude-code"


def parse_args(argv):
    """Parse the command line. Exit 2 on bad arguments."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("ref", help="issue or PR number, or - for none")
    parser.add_argument("--after", choices=SKILLS)
    parser.add_argument("--result", choices=("pass", "fail"), default="pass")
    parser.add_argument("--auto", action="store_true")
    parser.add_argument("--harness", choices=sorted(COMMAND_PREFIX))
    args = parser.parse_args(argv)
    if args.ref != "-" and not args.ref.lstrip("#").isdigit():
        parser.error("ref must be an issue or PR number, or -")
    return args


def next_step(args, tracker):
    """Return the next step for the parsed arguments."""
    ref = None if args.ref == "-" else int(args.ref.lstrip("#"))
    router = Router(tracker)
    if args.after:
        return TRANSITIONS[args.after](Context(ref, args.result == "fail", tracker, router))
    return router.route(ref) if ref else router.next_ready()


def main(argv=None, runner=run, env=None, settings=SETTINGS):
    """Print the Next: line for the arguments in argv."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    prefix = COMMAND_PREFIX[args.harness or detect_harness(os.environ if env is None else env)]
    if not Path(settings).is_file():
        print(f"Next: {Command('setup').render(prefix, args.auto)}")
        return 0
    try:
        step = next_step(args, Tracker(runner))
    except (CommandError, ValueError, KeyError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        print(f"Next: {Wait(f'fix this error ({error})', Command('next', (args.ref,))).render(prefix, args.auto)}")
        return 1
    print(f"Next: {step.render(prefix, args.auto)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
