import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import contextlib
import io
import tempfile

import install


def make_skills(root):
    """Create a fake skills folder with setup, one more skill with scripts, and ship's workflow."""
    for path in ["setup/scripts/install.py", "setup/scripts/claim.py", "setup/assets/settings.schema.json",
                 "prove/scripts/qa_check.py", "ship/assets/sdlc-on-merge.yml", "root-cause/SKILL.md"]:
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(path)
    return root


class InstallTest(unittest.TestCase):
    def test_copies_all_scripts_and_schema_but_not_itself(self):
        with tempfile.TemporaryDirectory() as tmp:
            skills = make_skills(Path(tmp) / "skills")
            repo = Path(tmp) / "repo"
            with contextlib.redirect_stdout(io.StringIO()):
                install.install_scripts(repo, skills, skills / "setup/assets/settings.schema.json")
            copied = sorted(p.name for p in (repo / ".sdlc/scripts").iterdir())
            self.assertEqual(copied, ["claim.py", "qa_check.py", "settings.schema.json"])

    def test_on_merge_copies_workflow(self):
        with tempfile.TemporaryDirectory() as tmp:
            skills = make_skills(Path(tmp) / "skills")
            repo = Path(tmp) / "repo"
            with contextlib.redirect_stdout(io.StringIO()):
                install.install_on_merge(repo, skills / "ship/assets/sdlc-on-merge.yml")
            self.assertTrue((repo / ".github/workflows/sdlc-on-merge.yml").is_file())

    def test_missing_workflow_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                install.install_on_merge(Path(tmp), Path(tmp) / "missing.yml")

    def test_bad_arguments_exit_2(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(install.main(["/does/not/exist"]), 2)


if __name__ == "__main__":
    unittest.main()
