import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import json
import tempfile

import validate_settings
from fakes import silence

VALID = {
    "default_branch": "main",
    "guides": {"development": "CONTRIBUTING.md", "code_review": None, "qa": None, "labeling": None},
    "issue": {"tracker": "github", "estimation": "none"},
    "task": {"path": ".sdlc/task", "keep": True},
    "spec": {"storage": "local", "review": "manual"},
    "review": {"resolve": "reviewer", "prefix": ":robot:"},
    "retro": {"scope": "worktree"},
    "research": {"engine": None},
    "sizing": {
        "xs_max_files": 2, "xs_max_lines": 20, "m_max_tasks": 3,
        "l_min_modules": 3, "review_limit": 400, "risk_paths": ["db/migrations/**"],
    },
}


def errors_for(settings):
    """Return the validation errors of a settings dict."""
    schema = json.loads(validate_settings.find_schema().read_text())
    return validate_settings.validate(settings, schema)


def changed(path, value):
    """Return a copy of VALID with the dotted key set to value, or removed when value is ...."""
    settings = json.loads(json.dumps(VALID))
    *parents, last = path.split(".")
    target = settings
    for key in parents:
        target = target[key]
    if value is ...:
        del target[last]
    else:
        target[last] = value
    return settings


class ValidateSettingsTest(unittest.TestCase):
    def setUp(self):
        silence(self)

    def test_valid_settings_pass(self):
        self.assertEqual(errors_for(VALID), [])

    def test_schema_defaults_are_valid(self):
        schema = json.loads(validate_settings.find_schema().read_text())
        defaults = {
            group: {key: spec["default"] for key, spec in body["properties"].items()}
            for group, body in schema["properties"].items()
            if body.get("type") == "object"
        }
        self.assertEqual(errors_for({"default_branch": "main", **defaults}), [])

    def test_missing_key_is_named(self):
        self.assertEqual(errors_for(changed("sizing.review_limit", ...)), ["sizing.review_limit: missing"])

    def test_unknown_key_is_named(self):
        self.assertEqual(errors_for(changed("spec.reviewer", "x")), ["spec.reviewer: unknown key"])

    def test_bad_enum_value(self):
        self.assertIn("spec.storage: must be one of", errors_for(changed("spec.storage", "wiki"))[0])

    def test_boolean_is_not_an_integer(self):
        self.assertIn("must be integer", errors_for(changed("sizing.xs_max_files", True))[0])

    def test_empty_prefix_is_rejected(self):
        self.assertEqual(errors_for(changed("review.prefix", "")), ["review.prefix: must not be empty"])

    def test_risk_path_items_are_checked(self):
        self.assertEqual(errors_for(changed("sizing.risk_paths", [3])), ["sizing.risk_paths.0: must be string, got 3"])

    def test_main_reports_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(validate_settings.main([f"{tmp}/settings.json"]), 1)

    def test_main_accepts_valid_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "settings.json"
            path.write_text(json.dumps(VALID))
            self.assertEqual(validate_settings.main([str(path)]), 0)


if __name__ == "__main__":
    unittest.main()
