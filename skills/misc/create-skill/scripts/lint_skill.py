#!/usr/bin/env python3
"""Lint a skill directory against the house format of the create-skill skill.

Usage: lint_skill.py <skill-dir>
Exit code 0 when the skill passes, 1 when it has errors.
"""

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SECTION_ORDER = ["Dependencies", "Args", "Flags", "Flow Graph", "Flow steps", "Rules", "Output"]
REQUIRED_SECTIONS = ["Flow Graph", "Flow steps", "Rules"]
NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NODE_PATTERN = re.compile(r"^\s*\w+\s*[\[{](.+?)[\]}]\s*$", re.M)
NUMBERED_LABEL = re.compile(r"^(\d+)\.\s+(.+)$")
STEP_PATTERN = re.compile(r"^(\d+)\.\s+\*\*(.+?)\*\*", re.M)
PATH_PATTERN = re.compile(r"(?:references|scripts|assets)/[\w./-]*\w")
MAX_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024
MAX_LINES = 500


def split_frontmatter(text):
    """Return the frontmatter as a dict and the body after it, or (None, text) when there is no frontmatter."""
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not match:
        return None, text
    meta = dict(line.split(":", 1) for line in match.group(1).splitlines() if ":" in line)
    return {key.strip(): value.strip() for key, value in meta.items()}, match.group(2)


def sections(body):
    """Return a dict of level-2 heading to section text and the list of headings, ignoring headings inside code blocks."""
    section_map, headings, current, in_code = {}, [], None, False
    for line in body.splitlines():
        in_code = in_code != line.startswith("```")
        heading = re.match(r"^## (.+?)\s*$", line)
        if heading and not in_code:
            current = heading.group(1)
            headings.append(current)
            section_map[current] = ""
        elif current:
            section_map[current] += line + "\n"
    return section_map, headings


def check_name(meta, skill_dir):
    """Check the frontmatter name."""
    name = meta.get("name", "")
    errors = []
    if not NAME_PATTERN.match(name):
        errors.append(f"name '{name}' is not kebab-case")
    if len(name) > MAX_NAME_LENGTH:
        errors.append(f"name is longer than {MAX_NAME_LENGTH} characters")
    if name != skill_dir.name:
        errors.append(f"name '{name}' is not the same as the directory name '{skill_dir.name}'")
    return errors


def check_description(meta):
    """Check the frontmatter description."""
    description = meta.get("description", "")
    errors = []
    if not description.startswith("Use when"):
        errors.append("description does not start with 'Use when'")
    if len(description) > MAX_DESCRIPTION_LENGTH:
        errors.append(f"description is longer than {MAX_DESCRIPTION_LENGTH} characters")
    if "<" in description or ">" in description:
        errors.append("description contains '<' or '>'")
    if ": " in description:
        errors.append("description contains ': ', which breaks the YAML frontmatter")
    return errors


def check_placeholders(text):
    """Check that no template placeholders are left."""
    if "{{" in text or "{%" in text:
        return ["template placeholders ({{ or {%) are left"]
    return []


def check_length(text):
    """Check the line count of SKILL.md."""
    if len(text.splitlines()) > MAX_LINES:
        return [f"SKILL.md is longer than {MAX_LINES} lines; move content to references/"]
    return []


def check_section_order(headings):
    """Check that only template sections are used, once each, in template order."""
    errors = [f"section '{h}' is not in the template" for h in headings if h not in SECTION_ORDER]
    errors += [f"section '{h}' is missing" for h in REQUIRED_SECTIONS if h not in headings]
    known = [h for h in headings if h in SECTION_ORDER]
    if len(set(known)) != len(known):
        errors.append("a section is used more than once")
    if known != sorted(known, key=SECTION_ORDER.index):
        errors.append(f"sections are not in template order: {', '.join(SECTION_ORDER)}")
    return errors


def mermaid_graph(section_text):
    """Return the content of the mermaid code block, or None."""
    match = re.search(r"```mermaid\n(.*?)```", section_text or "", re.S)
    return match.group(1) if match else None


def graph_nodes(graph):
    """Return the numbered nodes as a dict of number to name, and the errors found while reading them."""
    errors = []
    nodes = {}
    for label in NODE_PATTERN.findall(graph):
        numbered = NUMBERED_LABEL.match(label.strip())
        if not numbered:
            errors.append(f"graph node '{label}' is not numbered")
            continue
        number = int(numbered.group(1))
        if number in nodes:
            errors.append(f"graph node number {number} is used more than once")
        nodes[number] = numbered.group(2).strip()
    return nodes, errors


def check_graph_shape(graph):
    """Check the flowchart type and that nodes are not defined inside edge lines."""
    errors = []
    if not graph.lstrip().startswith("flowchart TD"):
        errors.append("flow graph does not start with 'flowchart TD'")
    for line in graph.splitlines():
        if "--" in line and re.search(r"[\[{]", line):
            errors.append(f"define nodes on their own lines, not in edge '{line.strip()}'")
    return errors


def check_numbering(numbers):
    """Check that numbers start at 1 and have no gaps."""
    if sorted(numbers) != list(range(1, len(numbers) + 1)):
        return [f"node numbers are not 1 to {len(numbers)} without gaps: {sorted(numbers)}"]
    return []


def check_steps_match(nodes, steps_text):
    """Check that each graph node has a flow step with the same number and name, and the reverse."""
    steps = {int(number): name.strip() for number, name in STEP_PATTERN.findall(steps_text or "")}
    errors = [f"graph node {n} has no flow step" for n in nodes if n not in steps]
    errors += [f"flow step {n} has no graph node" for n in steps if n not in nodes]
    errors += [
        f"step {n}: graph name '{nodes[n]}' is not flow step name '{steps[n]}'"
        for n in nodes
        if n in steps and nodes[n] != steps[n]
    ]
    if len(set(steps.values())) != len(steps):
        errors.append("flow step names are not unique")
    return errors


def check_flow(section_map):
    """Check the flow graph and its match with the flow steps."""
    graph = mermaid_graph(section_map.get("Flow Graph"))
    if graph is None:
        return ["Flow Graph has no mermaid code block"], None
    nodes, errors = graph_nodes(graph)
    errors += check_graph_shape(graph)
    errors += check_numbering(nodes.keys())
    errors += check_steps_match(nodes, section_map.get("Flow steps"))
    return errors, graph


def check_paths(text, skill_dir):
    """Check that each references/, scripts/ and assets/ path exists in the skill directory."""
    missing = sorted({p for p in PATH_PATTERN.findall(text) if not (skill_dir / p).exists()})
    return [f"path '{p}' does not exist" for p in missing]


def check_mermaid_syntax(graph):
    """Parse the graph with mmdc. Return (errors, checked)."""
    if graph is None or not shutil.which("mmdc"):
        return [], False
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "graph.mmd"
        source.write_text(graph)
        result = subprocess.run(["mmdc", "-i", str(source), "-o", str(Path(tmp) / "graph.svg")], capture_output=True, text=True)
    if result.returncode != 0:
        return [f"mermaid syntax error: {result.stderr.strip().splitlines()[-1:]}"], True
    return [], True


def lint(skill_dir):
    """Return all errors for the skill and whether the mermaid syntax was checked."""
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        return [f"{skill_file} does not exist"], False
    text = skill_file.read_text()
    meta, body = split_frontmatter(text)
    if meta is None:
        return ["SKILL.md has no frontmatter"], False
    section_map, headings = sections(body)
    flow_errors, graph = check_flow(section_map)
    syntax_errors, syntax_checked = check_mermaid_syntax(graph)
    errors = (
        check_name(meta, skill_dir)
        + check_description(meta)
        + check_placeholders(text)
        + check_length(text)
        + check_section_order(headings)
        + flow_errors
        + syntax_errors
        + check_paths(text, skill_dir)
    )
    return errors, syntax_checked


def main():
    """Lint the skill directory given as the first argument and print the result."""
    if len(sys.argv) != 2:
        print(__doc__.strip())
        return 1
    skill_dir = Path(sys.argv[1]).resolve()
    errors, syntax_checked = lint(skill_dir)
    for error in errors:
        print(f"ERROR: {error}")
    if not syntax_checked:
        print("NOTE: mmdc not found; mermaid syntax not checked")
    print("FAIL" if errors else "PASS")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
