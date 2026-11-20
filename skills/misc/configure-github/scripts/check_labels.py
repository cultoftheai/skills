#!/usr/bin/env python3
"""Compare the labels of a GitHub repository with the label catalog in references/labels.md.

Usage:
  gh label list --limit 1000 --json name,color,description \\
    | python3 check_labels.py [--groups core,review] [--areas checkout,api]

Reads the repository labels as JSON from stdin and prints a JSON report to stdout.
The script never calls GitHub. The "actions" list holds the gh commands that create
missing labels and fix drift for the selected groups. The script does not run them.
Exit code 0 on success, 2 on bad input.
"""

import argparse
import json
import re
import shlex
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "references" / "labels.md"
GROUP_HEADING = re.compile(r"^## Group `([\w-]+)`")
REQUIRES_LINE = re.compile(r"^Requires - (.+)$")
PATTERN_MARK = "<name>"


def parse_catalog(path):
    """Return the catalog groups in file order, each with its requirements and labels."""
    groups = []
    for line in path.read_text().splitlines():
        heading = GROUP_HEADING.match(line)
        requires = REQUIRES_LINE.match(line)
        if heading:
            groups.append({"name": heading.group(1), "requires": [], "labels": []})
        elif requires and groups:
            groups[-1]["requires"] = [g.strip() for g in requires.group(1).split(",") if g.strip() != "none"]
        elif line.startswith("| `") and groups:
            groups[-1]["labels"].append(parse_row(line))
    return groups


def parse_row(line):
    """Return one catalog label from a markdown table row."""
    name, on, colour, description = [cell.strip() for cell in line.strip().strip("|").split("|")]
    return {
        "name": name.strip("`"),
        "on": on,
        "color": colour.strip("`").lstrip("#").upper(),
        "description": description,
    }


def is_pattern(label):
    """Return True for a pattern label such as 'area: <name>'."""
    return PATTERN_MARK in label["name"]


def pattern_prefix(label):
    """Return the name prefix of a pattern label, for example 'area: '."""
    return label["name"].split(PATTERN_MARK)[0].lower()


def drift_fields(entry, actual):
    """Return the fields of a repository label that differ from its catalog entry."""
    fields = []
    if actual["name"] != entry["name"]:
        fields.append("name")
    if actual["color"].upper() != entry["color"]:
        fields.append("color")
    if (actual.get("description") or "") != entry["description"]:
        fields.append("description")
    return fields


def group_status(group, repo):
    """Return the install status, the missing labels and the drifted labels of one group."""
    fixed = [label for label in group["labels"] if not is_pattern(label)]
    present = [label for label in fixed if label["name"].lower() in repo]
    missing = [label for label in fixed if label["name"].lower() not in repo]
    drifted = []
    for label in present:
        actual = repo[label["name"].lower()]
        fields = drift_fields(label, actual)
        if fields:
            drifted.append({"catalog": label, "repo": actual, "fields": fields})
    status = "installed" if not missing else ("missing" if not present else "partial")
    return {"name": group["name"], "requires": group["requires"], "status": status, "missing": missing, "drifted": drifted}


def pattern_labels(groups):
    """Return all pattern labels of the catalog."""
    return [label for group in groups for label in group["labels"] if is_pattern(label)]


def area_report(groups, repo_labels):
    """Return the repository labels that match a catalog pattern, with a colour check."""
    areas = []
    for pattern in pattern_labels(groups):
        for label in repo_labels:
            if label["name"].lower().startswith(pattern_prefix(pattern)):
                color_ok = label["color"].upper() == pattern["color"]
                areas.append({"name": label["name"], "color": label["color"].upper(), "color_ok": color_ok})
    return areas


def stray_labels(groups, repo_labels):
    """Return the repository labels that are not in the catalog and match no pattern."""
    known = {label["name"].lower() for group in groups for label in group["labels"] if not is_pattern(label)}
    prefixes = [pattern_prefix(label) for label in pattern_labels(groups)]
    return [
        label["name"]
        for label in repo_labels
        if label["name"].lower() not in known and not any(label["name"].lower().startswith(p) for p in prefixes)
    ]


def create_command(name, color, description):
    """Return the gh command that creates one label."""
    return shlex.join(["gh", "label", "create", name, "--color", color, "--description", description])


def edit_command(old_name, label, fields):
    """Return the gh command that sets the drifted fields of one label to the catalog values."""
    command = ["gh", "label", "edit", old_name]
    if "name" in fields:
        command += ["--name", label["name"]]
    if "color" in fields:
        command += ["--color", label["color"]]
    if "description" in fields:
        command += ["--description", label["description"]]
    return shlex.join(command)


def group_actions(report):
    """Return the create and edit actions for one group report."""
    actions = [
        {"group": report["name"], "kind": "create", "label": label["name"],
         "command": create_command(label["name"], label["color"], label["description"])}
        for label in report["missing"]
    ]
    actions += [
        {"group": report["name"], "kind": "edit", "label": item["catalog"]["name"],
         "command": edit_command(item["repo"]["name"], item["catalog"], item["fields"])}
        for item in report["drifted"]
    ]
    return actions


def area_actions(groups, areas, area_names):
    """Return the actions for the area names that the user gave."""
    pattern = next(label for label in pattern_labels(groups) if pattern_prefix(label) == "area: ")
    existing = {area["name"].lower(): area for area in areas}
    actions = []
    for area_name in area_names:
        name = pattern["name"].replace(PATTERN_MARK, area_name)
        area = existing.get(name.lower())
        if area is None:
            actions.append({"group": "tracking", "kind": "create", "label": name,
                            "command": create_command(name, pattern["color"], "")})
        elif not area["color_ok"]:
            actions.append({"group": "tracking", "kind": "edit", "label": name,
                            "command": shlex.join(["gh", "label", "edit", area["name"], "--color", pattern["color"]])})
    return actions


def split_list(value):
    """Return the items of a comma-separated value, without empty items."""
    return [item.strip() for item in (value or "").split(",") if item.strip()]


def parse_args(group_names):
    """Return the command-line arguments."""
    parser = argparse.ArgumentParser(description="Compare repository labels with the label catalog.")
    parser.add_argument("--groups", help="Comma-separated groups to report and plan. Default: all groups.")
    parser.add_argument("--areas", help="Comma-separated area names to plan as 'area: <name>' labels.")
    args = parser.parse_args()
    selected = split_list(args.groups) or group_names
    unknown = [g for g in selected if g not in group_names]
    if unknown:
        parser.exit(2, f"unknown group(s): {', '.join(unknown)}. Known groups: {', '.join(group_names)}\n")
    return selected, split_list(args.areas)


def main():
    """Print the JSON report for the repository labels on stdin."""
    groups = parse_catalog(CATALOG)
    selected, area_names = parse_args([group["name"] for group in groups])
    repo_labels = json.load(sys.stdin)
    repo = {label["name"].lower(): label for label in repo_labels}
    reports = {group["name"]: group_status(group, repo) for group in groups}
    for report in reports.values():
        report["requires_not_installed"] = [g for g in report["requires"] if reports[g]["status"] != "installed"]
    areas = area_report(groups, repo_labels)
    actions = [action for name in selected for action in group_actions(reports[name])]
    actions += area_actions(groups, areas, area_names)
    result = {
        "groups": [reports[name] for name in selected],
        "areas": areas,
        "stray": stray_labels(groups, repo_labels),
        "actions": actions,
    }
    json.dump(result, sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
