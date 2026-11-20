#!/usr/bin/env python3
"""Claim an issue for one session, or release the claim.

Usage:
  claim.py <issue>            exit 0 when claimed, exit 3 when already claimed
  claim.py --release <issue>  delete the claim, exit 0

A claim is the Git ref refs/sdlc/claims/<issue> on origin. The script makes a
new root commit with a unique message and pushes it to that ref without force.
The remote creates a ref only when it does not exist yet, and a root commit can
never fast-forward another one. So when two sessions claim at the same time,
exactly one push succeeds and the other is rejected. Releasing an issue with no
claim does nothing. Exit code 2 on bad arguments, 1 on any other error.
"""

import subprocess
import sys
import uuid

REMOTE = "origin"
CLAIMED, LOST = 0, 3


class CommandError(Exception):
    """A command that exited with a non-zero code."""


def run(args, input_text=None):
    """Run a command and return the completed process with text output."""
    return subprocess.run(args, capture_output=True, text=True, input=input_text)


def git(args, runner, input_text=None):
    """Run git with the arguments and return its stripped stdout, or raise CommandError."""
    result = runner(["git", *args], input_text)
    if result.returncode != 0:
        raise CommandError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout.strip()


def claim_ref(issue):
    """Return the ref name that holds the claim of an issue."""
    return f"refs/sdlc/claims/{issue}"


def claim_commit(issue, runner):
    """Create a root commit with an empty tree and a unique message, and return its SHA."""
    tree = git(["mktree"], runner, "")
    message = f"claim #{issue}\n\nid: {uuid.uuid4()}"
    return git(["commit-tree", tree, "-m", message], runner)


def remote_claim(issue, runner):
    """Return the SHA of the claim ref on the remote, or None when there is no claim."""
    output = git(["ls-remote", REMOTE, claim_ref(issue)], runner)
    return output.split()[0] if output else None


def claim(issue, runner):
    """Push a new claim ref. Return CLAIMED, or LOST when another claim exists."""
    sha = claim_commit(issue, runner)
    pushed = runner(["git", "push", "--quiet", REMOTE, f"{sha}:{claim_ref(issue)}"], None)
    if pushed.returncode == 0:
        print(f"claimed #{issue}")
        return CLAIMED
    if remote_claim(issue, runner):
        print(f"lost: #{issue} is already claimed ({claim_ref(issue)} on {REMOTE})")
        return LOST
    raise CommandError(pushed.stderr.strip() or "git push failed")


def release(issue, runner):
    """Delete the claim ref of an issue. Do nothing when there is no claim."""
    if remote_claim(issue, runner) is None:
        print(f"#{issue} has no claim")
        return 0
    git(["push", "--quiet", REMOTE, "--delete", claim_ref(issue)], runner)
    print(f"released #{issue}")
    return 0


def parse_args(args):
    """Return (issue, release) from the command line, or None when the arguments are wrong."""
    if len(args) == 2 and args[0] == "--release" and args[1].isdigit():
        return args[1], True
    if len(args) == 1 and args[0].isdigit():
        return args[0], False
    return None


def main(argv=None, runner=run):
    """Claim or release the issue named in argv."""
    parsed = parse_args(sys.argv[1:] if argv is None else argv)
    if parsed is None:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    issue, releasing = parsed
    try:
        return release(issue, runner) if releasing else claim(issue, runner)
    except CommandError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
