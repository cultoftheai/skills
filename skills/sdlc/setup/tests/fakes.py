"""A fake command runner and an output silencer for the script tests."""

import contextlib
import io
import subprocess


def silence(test):
    """Hide what the code under test prints, until the test ends."""
    for redirect in (contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO())):
        redirect.__enter__()
        test.addCleanup(redirect.__exit__, None, None, None)


class FakeRunner:
    """Answer commands from a list of (prefix, returncode, stdout) rules and record every call."""

    def __init__(self, rules):
        self.rules = rules
        self.calls = []

    def __call__(self, args, input_text=None):
        self.calls.append(list(args))
        for prefix, code, stdout in self.rules:
            if list(args[: len(prefix)]) == list(prefix):
                return subprocess.CompletedProcess(args, code, stdout, "fake error" if code else "")
        raise AssertionError(f"unexpected command: {args}")

    def called(self, prefix):
        """Return the calls that start with prefix."""
        return [call for call in self.calls if call[: len(prefix)] == list(prefix)]
