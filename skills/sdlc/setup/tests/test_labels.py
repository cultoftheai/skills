import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import json

import labels
import size
import stage
from fakes import FakeRunner, silence


class LabelsTest(unittest.TestCase):
    def setUp(self):
        silence(self)

    def test_creates_only_missing_labels(self):
        existing = [{"name": name} for name in ["READY", "shaped", "size:S", "bug"]]
        runner = FakeRunner([(["gh", "label", "list"], 0, json.dumps(existing)), (["gh", "label", "create"], 0, "")])
        self.assertEqual(labels.main([], runner), 0)
        created = [call[3] for call in runner.called(["gh", "label", "create"])]
        self.assertNotIn("ready", created)
        self.assertNotIn("size:S", created)
        self.assertEqual(len(created), 8)

    def test_dry_run_creates_nothing(self):
        runner = FakeRunner([(["gh", "label", "list"], 0, "[]")])
        self.assertEqual(labels.main(["--dry-run"], runner), 0)
        self.assertEqual(runner.called(["gh", "label", "create"]), [])

    def test_never_edits_or_deletes(self):
        runner = FakeRunner([(["gh", "label", "list"], 0, "[]"), (["gh", "label", "create"], 0, "")])
        labels.main([], runner)
        self.assertTrue(all(call[2] in ("list", "create") for call in runner.calls))
        self.assertFalse(any("--force" in call for call in runner.calls))


class ExclusiveLabelTest(unittest.TestCase):
    def setUp(self):
        silence(self)

    def runner_with(self, names):
        view = json.dumps({"labels": [{"name": name} for name in names]})
        return FakeRunner([(["gh", "issue", "view"], 0, view), (["gh", "issue", "edit"], 0, "")])

    def test_stage_replaces_other_stage_labels(self):
        runner = self.runner_with(["ready", "bug", "size:M"])
        self.assertEqual(stage.main(["12", "shaped"], runner), 0)
        self.assertEqual(
            runner.called(["gh", "issue", "edit"]),
            [["gh", "issue", "edit", "12", "--add-label", "shaped", "--remove-label", "ready"]],
        )

    def test_stage_rejects_unknown_stage(self):
        self.assertEqual(stage.main(["12", "doing"], FakeRunner([])), 2)

    def test_size_replaces_other_size_labels(self):
        runner = self.runner_with(["size:S", "size:XL", "ready"])
        self.assertEqual(size.main(["7", "M"], runner), 0)
        self.assertEqual(
            runner.called(["gh", "issue", "edit"]),
            [["gh", "issue", "edit", "7", "--add-label", "size:M", "--remove-label", "size:S,size:XL"]],
        )

    def test_size_without_other_labels_only_adds(self):
        runner = self.runner_with([])
        size.main(["7", "XS"], runner)
        self.assertEqual(runner.called(["gh", "issue", "edit"]), [["gh", "issue", "edit", "7", "--add-label", "size:XS"]])

    def test_gh_failure_exits_1(self):
        runner = FakeRunner([(["gh", "issue", "view"], 1, "")])
        self.assertEqual(stage.main(["12", "done"], runner), 1)


if __name__ == "__main__":
    unittest.main()
