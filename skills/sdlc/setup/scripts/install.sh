#!/bin/sh
# Copy the SDLC scripts and templates into a repository, and set up the specs and work layout.
#
# Usage: install.sh <repo-root> [--override]
#
# Copies the files in scripts/ of every SDLC skill (the directories next to this
# skill's directory, this skill included) into <repo-root>/.sdlc/scripts/, and
# this skill's assets/settings.schema.json next to them for validate_settings.sh.
# install.sh itself is not copied. Copies from an earlier run are overwritten.
# Copies the files in assets/templates/ of every SDLC skill into
# <repo-root>/.sdlc/templates/. A template that already exists is kept and
# printed as "kept <path>", unless --override is passed.
# Creates the specs, archive and work directories from <repo-root>/.sdlc/settings.json
# (or the defaults .sdlc/specs, .sdlc/specs/archived and .sdlc/work), and ensures
# <repo-root>/.sdlc/.gitignore ignores the work directory without editing the root
# .gitignore.
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

# Copy every template of every skill into <repo-root>/.sdlc/templates/. Keep an existing one unless the second argument is --override.
install_templates() {
    for source in "$SKILLS_DIR"/*/assets/templates/*; do
        target="$1/.sdlc/templates/$(basename "$source")"
        if [ ! -f "$source" ]; then
            continue
        elif [ -f "$target" ] && [ "$2" != --override ]; then
            printf 'kept %s\n' "$target"
        else
            copy "$source" "$target"
        fi
    done
}

# Read one string setting from <repo-root>/.sdlc/settings.json, or print the default when missing.
read_setting() {
    settings="$1/.sdlc/settings.json"
    value=''
    if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
        value=$(jq -r "$2 // empty" "$settings" 2>/dev/null)
    fi
    printf '%s\n' "${value:-$3}"
}

# Strip leading "./" and trailing "/" from a relative path.
trim_path() {
    path=$1
    while [ "${path#./}" != "$path" ]; do
        path=${path#./}
    done
    while [ "${path%/}" != "$path" ] && [ "$path" != / ]; do
        path=${path%/}
    done
    printf '%s\n' "$path"
}

# Ensure <entry> is listed in <repo-root>/.sdlc/.gitignore without duplicating or removing existing lines.
ensure_gitignore_entry() {
    gitignore="$1/.sdlc/.gitignore"
    entry=$2
    mkdir -p "$(dirname "$gitignore")" || exit 1
    if [ -f "$gitignore" ] && grep -Fxq -- "$entry" "$gitignore"; then
        return 0
    fi
    if [ -s "$gitignore" ] && [ -n "$(tail -c 1 "$gitignore")" ]; then
        printf '\n' >> "$gitignore" || exit 1
    fi
    printf '%s\n' "$entry" >> "$gitignore" && printf 'wrote %s\n' "$gitignore"
}

# Create the specs, archive and work folders, and gitignore the work folder via .sdlc/.gitignore.
setup_layout() {
    specs_path=$(trim_path "$(read_setting "$1" '.specs.path' '.sdlc/specs')")
    archive_path=$(trim_path "$(read_setting "$1" '.specs.archive_path' '.sdlc/specs/archived')")
    work_path=$(trim_path "$(read_setting "$1" '.work.path' '.sdlc/work')")
    mkdir -p "$1/$specs_path" "$1/$archive_path" "$1/$work_path" || exit 1
    case "$work_path" in
        .sdlc/*)
            ensure_gitignore_entry "$1" "${work_path#.sdlc/}/" || exit 1
            ;;
        *)
            printf 'warning: work.path (%s) is outside .sdlc/; add it to your gitignore manually\n' "$work_path" >&2
            ;;
    esac
}

if [ $# -lt 1 ] || [ $# -gt 2 ] || [ ! -d "$1" ] || [ "${2:---override}" != --override ]; then
    usage
    exit 2
fi
install_scripts "$1"
install_templates "$1" "${2:-}"
setup_layout "$1"
