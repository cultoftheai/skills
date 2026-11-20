import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import contextlib
import io
import os
import subprocess
import tempfile

import claim
from fakes import FakeRunner

CLAIM_SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "claim.py"
IDENTITY = {
    "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
    "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com",
}


def git(*args, cwd):
    """Run git in cwd and fail the test when it fails."""
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def make_clones(tmp, count):
    """Create a bare origin and count clones of it. Return the clone paths."""
    origin = Path(tmp) / "origin.git"
    git("init", "--quiet", "--bare", str(origin), cwd=tmp)
    clones = []
    for index in range(count):
        clone = Path(tmp) / f"clone{index}"
        git("clone", "--quiet", str(origin), str(clone), cwd=tmp)
        clones.append(clone)
    return clones


def start_claim(clone, *args):
    """Start claim.py in a clone and return the process."""
    env = {**os.environ, **IDENTITY}
    return subprocess.Popen(
        [sys.executable, str(CLAIM_SCRIPT), *args], cwd=clone, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )


def finish(process):
    """Wait for a process and return its exit code and stdout."""
    stdout, _ = process.communicate(timeout=60)
    return process.returncode, stdout


class ClaimRaceTest(unittest.TestCase):
    def test_concurrent_claims_have_exactly_one_winner(self):
        with tempfile.TemporaryDirectory() as tmp:
            clones = make_clones(tmp, 6)
            for round_number in range(5):
                issue = str(40 + round_number)
                results = [finish(p) for p in [start_claim(clone, issue) for clone in clones]]
                codes = sorted(code for code, _ in results)
                self.assertEqual(codes, [0] + [3] * (len(clones) - 1), results)
                losers = [out for code, out in results if code == 3]
                self.assertTrue(all("already claimed" in out for out in losers))

    def test_claim_after_release_succeeds_again(self):
        with tempfile.TemporaryDirectory() as tmp:
            first, second = make_clones(tmp, 2)
            self.assertEqual(finish(start_claim(first, "8"))[0], 0)
            self.assertEqual(finish(start_claim(second, "8"))[0], 3)
            self.assertEqual(finish(start_claim(first, "--release", "8"))[0], 0)
            self.assertEqual(finish(start_claim(second, "8"))[0], 0)

    def test_release_without_claim_is_a_no_op(self):
        with tempfile.TemporaryDirectory() as tmp:
            (clone,) = make_clones(tmp, 1)
            code, out = finish(start_claim(clone, "--release", "5"))
            self.assertEqual((code, out.strip()), (0, "#5 has no claim"))


class ClaimUnitTest(unittest.TestCase):
    def test_push_error_without_remote_claim_exits_1(self):
        runner = FakeRunner([
            (["git", "mktree"], 0, "tree\n"),
            (["git", "commit-tree"], 0, "sha\n"),
            (["git", "push"], 1, ""),
            (["git", "ls-remote"], 0, ""),
        ])
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(claim.main(["9"], runner), 1)

    def test_push_is_never_forced(self):
        runner = FakeRunner([
            (["git", "mktree"], 0, "tree\n"),
            (["git", "commit-tree"], 0, "sha\n"),
            (["git", "push"], 0, ""),
        ])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(claim.main(["9"], runner), 0)
        (push,) = runner.called(["git", "push"])
        self.assertFalse(any(arg.startswith(("-f", "--force")) or arg.startswith("+") for arg in push))

    def test_bad_arguments_exit_2(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(claim.main(["abc"], FakeRunner([])), 2)


if __name__ == "__main__":
    unittest.main()
