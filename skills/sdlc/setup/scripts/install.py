#!/usr/bin/env python3
"""Copy the SDLC scripts into a repository.

Usage: install.py <repo-root> [--on-merge]

Copies the files in scripts/ of every SDLC skill (the directories next to this
skill's directory, this skill included) into <repo-root>/.sdlc/scripts/, and
this skill's assets/settings.schema.json next to them for validate_settings.py.
install.py itself is not copied. Copies from an earlier run are overwritten.
With --on-merge, it also copies ship/assets/sdlc-on-merge.yml to
<repo-root>/.github/workflows/sdlc-on-merge.yml.
Prints each file that it wrote. Exit code 0 on success, 2 on bad arguments,
1 when a source file is missing.
"""

import shutil
import sys
from pathlib import Path

SETUP_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = SETUP_DIR.parent
SCHEMA = SETUP_DIR / "assets" / "settings.schema.json"
ON_MERGE = SKILLS_DIR / "ship" / "assets" / "sdlc-on-merge.yml"
ON_MERGE_TARGET = Path(".github") / "workflows" / "sdlc-on-merge.yml"
SKIPPED = {"install.py"}


def script_sources(skills_dir):
    """Return the script files of every skill under skills_dir, except the skipped ones."""
    files = sorted(skills_dir.glob("*/scripts/*"))
    return [f for f in files if f.is_file() and f.name not in SKIPPED and f.suffix != ".pyc"]


def copy(source, target):
    """Copy one file, create the target directory, and print the target."""
    if not source.is_file():
        raise FileNotFoundError(f"{source} does not exist")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    print(f"wrote {target}")


def install_scripts(repo_root, skills_dir=SKILLS_DIR, schema=SCHEMA):
    """Copy every script and the settings schema into <repo_root>/.sdlc/scripts/."""
    target_dir = repo_root / ".sdlc" / "scripts"
    for source in script_sources(skills_dir):
        copy(source, target_dir / source.name)
    copy(schema, target_dir / schema.name)


def install_on_merge(repo_root, source=ON_MERGE):
    """Copy the on-merge workflow into the repository's workflow folder."""
    copy(source, repo_root / ON_MERGE_TARGET)


def main(argv=None):
    """Install the scripts, and the on-merge workflow with --on-merge."""
    args = sys.argv[1:] if argv is None else argv
    paths = [arg for arg in args if arg != "--on-merge"]
    if len(paths) != 1 or not Path(paths[0]).is_dir():
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        install_scripts(Path(paths[0]))
        if "--on-merge" in args:
            install_on_merge(Path(paths[0]))
    except FileNotFoundError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
