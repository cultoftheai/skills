#!/bin/sh
# Copy the SDLC scripts into a repository.
#
# Usage: install.sh <repo-root>
#
# Copies the files in scripts/ of every SDLC skill (the directories next to this
# skill's directory, this skill included) into <repo-root>/.sdlc/scripts/, and
# this skill's assets/settings.schema.json next to them for validate_settings.sh.
# install.sh itself is not copied. Copies from an earlier run are overwritten.
# Prints each file that it wrote. Exit code 0 on success, 2 on bad arguments,
# 1 when a source file is missing.

set -u

SETUP_DIR=$(cd "$(dirname "$0")/.." && pwd)
SKILLS_DIR=$(dirname "$SETUP_DIR")

# Print the usage comment at the top of this script to stderr.
usage() {
    sed -n '2,/^$/s/^# \{0,1\}//p' "$0" >&2
}

# Copy one file, create the target directory, and print the target. Exit 1 when the source is missing.
copy() {
    if [ ! -f "$1" ]; then
        printf 'error: %s does not exist\n' "$1" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$2")" && cp -p "$1" "$2" && printf 'wrote %s\n' "$2"
}

# Copy every script of every skill, except this one, and the settings schema into <repo-root>/.sdlc/scripts/.
install_scripts() {
    for source in "$SKILLS_DIR"/*/scripts/*; do
        if [ -f "$source" ] && [ "$(basename "$source")" != install.sh ]; then
            copy "$source" "$1/.sdlc/scripts/$(basename "$source")"
        fi
    done
    copy "$SETUP_DIR/assets/settings.schema.json" "$1/.sdlc/scripts/settings.schema.json"
}

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
    usage
    exit 2
fi
install_scripts "$1"
