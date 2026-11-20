#!/usr/bin/env python3
"""List, reply to and resolve the review threads of a pull request through `gh api graphql`.

Usage:
  review_threads.py list <pr>
      Print a JSON array of the unresolved threads. Each thread has: id, path, line,
      outdated, can_resolve, needs_reply, rounds, comments (author, bot, body, url, created_at).
      needs_reply is true when the last comment is not from the current gh user.
      rounds counts the replies from the current gh user that start with review.prefix.
  review_threads.py reply <thread-id> <body-file>
      Post the file as a reply and print the reply URL. The body must start with review.prefix.
  review_threads.py resolve <thread-id>
      Resolve the thread. Allowed only when review.resolve is "author".

Settings come from .sdlc/settings.json when it exists. Defaults: review.prefix ":robot:",
review.resolve "reviewer".

Exit codes: 0 success; 1 gh failed or GitHub returned no reply URL; 2 bad usage or a body
without the prefix; 3 resolve is not allowed by review.resolve.
"""

import json
import subprocess
import sys
from pathlib import Path

SETTINGS_PATH = Path(".sdlc/settings.json")
DEFAULTS = {"review.prefix": ":robot:", "review.resolve": "reviewer"}
EXIT_GH_ERROR = 1
EXIT_USAGE = 2
EXIT_NOT_ALLOWED = 3

LIST_QUERY = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line viewerCanResolve
          comments(first: 100) {
            nodes { url body createdAt author { login __typename } }
          }
        }
      }
    }
  }
}
"""

REPLY_MUTATION = """
mutation($thread: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $thread, body: $body}) {
    comment { url }
  }
}
"""

RESOLVE_MUTATION = """
mutation($thread: ID!) {
  resolveReviewThread(input: {threadId: $thread}) { thread { isResolved } }
}
"""


class CommandError(Exception):
    """A gh call failed or GitHub did not confirm the change."""


class UsageError(Exception):
    """The arguments or the reply body are not valid."""


class NotAllowedError(Exception):
    """The settings do not allow the action."""


def run_command(args):
    """Run a command and return its stdout. Raise CommandError on a non-zero exit."""
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise CommandError(result.stderr.strip() or f"{args[0]} exited with {result.returncode}")
    return result.stdout


def load_settings(path=SETTINGS_PATH):
    """Return the settings file as a dict, or an empty dict when the file does not exist."""
    return json.loads(path.read_text()) if path.is_file() else {}


def setting(settings, key):
    """Return a dotted setting from nested objects or a flat key, else its default."""
    value = settings
    for part in key.split("."):
        value = value.get(part) if isinstance(value, dict) else None
    if value is None:
        value = settings.get(key)
    return DEFAULTS[key] if value is None else value


def graphql(run, query, typed=None, raw=None):
    """Run a GraphQL query through gh. typed values use -F, raw strings use -f. Return the data object."""
    args = ["gh", "api", "graphql", "-f", f"query={query}"]
    for key, value in (typed or {}).items():
        args += ["-F", f"{key}={value}"]
    for key, value in (raw or {}).items():
        if value is not None:
            args += ["-f", f"{key}={value}"]
    return json.loads(run(args))["data"]


def fetch_threads(run, pr):
    """Return the gh user's login and every review thread node of the pull request."""
    typed = {"owner": "{owner}", "name": "{repo}", "number": int(pr)}
    nodes, cursor, viewer = [], None, None
    while True:
        data = graphql(run, LIST_QUERY, typed, {"cursor": cursor})
        viewer = data["viewer"]["login"]
        page = data["repository"]["pullRequest"]["reviewThreads"]
        nodes += page["nodes"]
        if not page["pageInfo"]["hasNextPage"]:
            return viewer, nodes
        cursor = page["pageInfo"]["endCursor"]


def summarize_comment(node):
    """Return the fields of one comment that triage needs."""
    author = node.get("author") or {}
    return {
        "author": author.get("login", "ghost"),
        "bot": author.get("__typename") == "Bot",
        "body": node["body"],
        "url": node["url"],
        "created_at": node["createdAt"],
    }


def summarize_thread(node, viewer, prefix):
    """Return one thread with needs_reply and rounds computed for the gh user."""
    comments = [summarize_comment(c) for c in node["comments"]["nodes"]]
    ours = [c for c in comments if c["author"] == viewer and c["body"].startswith(prefix)]
    return {
        "id": node["id"],
        "path": node["path"],
        "line": node["line"],
        "outdated": node["isOutdated"],
        "can_resolve": node["viewerCanResolve"],
        "needs_reply": bool(comments) and comments[-1]["author"] != viewer,
        "rounds": len(ours),
        "comments": comments,
    }


def list_threads(run, pr, prefix):
    """Return the unresolved threads of the pull request."""
    viewer, nodes = fetch_threads(run, pr)
    return [summarize_thread(n, viewer, prefix) for n in nodes if not n["isResolved"]]


def reply(run, thread_id, body, prefix):
    """Post a reply that starts with the prefix and return its URL."""
    if not body.startswith(prefix):
        raise UsageError(f"the reply does not start with the prefix {prefix!r}; nothing was posted")
    data = graphql(run, REPLY_MUTATION, raw={"thread": thread_id, "body": body})
    url = ((data.get("addPullRequestReviewThreadReply") or {}).get("comment") or {}).get("url")
    if not url:
        raise CommandError("GitHub returned no reply URL; list the threads again before you retry")
    return url


def resolve(run, thread_id, resolve_setting):
    """Resolve the thread when review.resolve is author."""
    if resolve_setting != "author":
        raise NotAllowedError(f"review.resolve is {resolve_setting!r}; only the reviewer resolves threads")
    data = graphql(run, RESOLVE_MUTATION, raw={"thread": thread_id})
    if not data["resolveReviewThread"]["thread"]["isResolved"]:
        raise CommandError("GitHub did not resolve the thread")


def dispatch(args, run, settings):
    """Run one command and return the text to print."""
    prefix = setting(settings, "review.prefix")
    if len(args) == 2 and args[0] == "list" and args[1].isdigit():
        return json.dumps(list_threads(run, args[1], prefix), indent=2)
    if len(args) == 3 and args[0] == "reply":
        return reply(run, args[1], Path(args[2]).read_text(), prefix)
    if len(args) == 2 and args[0] == "resolve":
        resolve(run, args[1], setting(settings, "review.resolve"))
        return f"resolved {args[1]}"
    raise UsageError(__doc__.strip())


def main(argv=None, run=run_command, settings=None):
    """Parse the arguments, run the command and return the exit code."""
    args = sys.argv[1:] if argv is None else argv
    try:
        print(dispatch(args, run, load_settings() if settings is None else settings))
        return 0
    except UsageError as error:
        print(error, file=sys.stderr)
        return EXIT_USAGE
    except NotAllowedError as error:
        print(error, file=sys.stderr)
        return EXIT_NOT_ALLOWED
    except CommandError as error:
        print(error, file=sys.stderr)
        return EXIT_GH_ERROR


if __name__ == "__main__":
    sys.exit(main())
