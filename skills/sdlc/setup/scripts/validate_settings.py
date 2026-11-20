#!/usr/bin/env python3
"""Validate an SDLC settings file against the settings schema.

Usage: validate_settings.py [path]

path defaults to .sdlc/settings.json. The script reads settings.schema.json
from its own directory, or from ../assets/ when it runs inside the setup skill.
It supports the schema keywords that the settings schema uses: type, enum,
minLength, minimum, properties, required, additionalProperties and items.
Prints "valid" and exits 0, or prints one "<key>: <problem>" line per error
and exits 1.
"""

import json
import sys
from pathlib import Path

DEFAULT_PATH = ".sdlc/settings.json"
SCHEMA_NAME = "settings.schema.json"
TYPES = {
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "array": lambda v: isinstance(v, list),
    "object": lambda v: isinstance(v, dict),
    "null": lambda v: v is None,
}


def find_schema():
    """Return the path of the settings schema next to this script or in the skill's assets."""
    here = Path(__file__).resolve().parent
    for candidate in (here / SCHEMA_NAME, here.parent / "assets" / SCHEMA_NAME):
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"{SCHEMA_NAME} not found next to {here}")


def key_name(path):
    """Return the dotted key for a list of path parts, or (root) for the top level."""
    return ".".join(str(part) for part in path) or "(root)"


def type_errors(value, schema, path):
    """Return an error when the value does not have one of the schema types."""
    allowed = schema.get("type")
    if allowed is None:
        return []
    allowed = allowed if isinstance(allowed, list) else [allowed]
    if any(TYPES[name](value) for name in allowed):
        return []
    return [f"{key_name(path)}: must be {' or '.join(allowed)}, got {json.dumps(value)}"]


def value_errors(value, schema, path):
    """Return the enum, minLength and minimum errors of one value."""
    errors = []
    if "enum" in schema and value not in schema["enum"]:
        choices = ", ".join(json.dumps(choice) for choice in schema["enum"])
        errors.append(f"{key_name(path)}: must be one of {choices}, got {json.dumps(value)}")
    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        errors.append(f"{key_name(path)}: must not be empty")
    if TYPES["integer"](value) and "minimum" in schema and value < schema["minimum"]:
        errors.append(f"{key_name(path)}: must be {schema['minimum']} or more, got {value}")
    return errors


def object_errors(value, schema, path):
    """Return the errors of the required, unknown and nested keys of an object."""
    properties = schema.get("properties", {})
    errors = [f"{key_name(path + [key])}: missing" for key in schema.get("required", []) if key not in value]
    if schema.get("additionalProperties") is False:
        errors += [f"{key_name(path + [key])}: unknown key" for key in value if key not in properties]
    for key, child in properties.items():
        if key in value:
            errors += validate(value[key], child, path + [key])
    return errors


def array_errors(value, schema, path):
    """Return the errors of the items of an array."""
    items = schema.get("items")
    if items is None:
        return []
    return [error for index, item in enumerate(value) for error in validate(item, items, path + [index])]


def validate(value, schema, path=None):
    """Return every error of the value against the schema."""
    path = path or []
    errors = type_errors(value, schema, path)
    if errors:
        return errors
    errors = value_errors(value, schema, path)
    if isinstance(value, dict):
        errors += object_errors(value, schema, path)
    if isinstance(value, list):
        errors += array_errors(value, schema, path)
    return errors


def load_settings(path):
    """Return the parsed settings file, or raise ValueError with the reason."""
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        raise ValueError(f"{path}: file not found")
    except json.JSONDecodeError as error:
        raise ValueError(f"{path}: not valid JSON ({error})")


def main(argv=None):
    """Validate the settings file named in argv and print the result."""
    args = sys.argv[1:] if argv is None else argv
    path = args[0] if args else DEFAULT_PATH
    try:
        errors = validate(load_settings(path), json.loads(find_schema().read_text()))
    except (ValueError, FileNotFoundError) as error:
        errors = [str(error)]
    for error in errors:
        print(error)
    if not errors:
        print("valid")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
