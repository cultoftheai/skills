#!/bin/sh
# Validate an SDLC settings file against the settings schema.
#
# Usage: validate_settings.sh [path]
#
# path defaults to .sdlc/settings.json. The script reads settings.schema.json
# from its own directory, or from ../assets/ when it runs inside the setup skill.
# It supports the schema keywords that the settings schema uses: type, enum,
# minLength, minimum, properties, required, additionalProperties and items.
# Prints "valid" and exits 0, or prints one "<key>: <problem>" line per error
# and exits 1. Needs jq.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SETTINGS=${1:-.sdlc/settings.json}

VALIDATE='
  def key($path): if ($path | length) == 0 then "(root)" else ($path | map(tostring) | join(".")) end;
  def kind: if type == "number" and . == floor then "integer" else type end;
  def type_errors($schema; $path):
    . as $value
    | ($schema.type // empty | if type == "array" then . else [.] end) as $types
    | select(any($types[]; . == ($value | kind)) | not)
    | "\(key($path)): must be \($types | join(" or ")), got \($value | tojson)";
  def value_errors($schema; $path):
    . as $value
    | (select($schema | has("enum")) | select(any($schema.enum[]; . == $value) | not)
        | "\(key($path)): must be one of \($schema.enum | map(tojson) | join(", ")), got \(tojson)"),
      (select(type == "string" and length < ($schema.minLength // 0))
        | "\(key($path)): must not be empty"),
      (select(kind == "integer" and ($schema | has("minimum")) and . < $schema.minimum)
        | "\(key($path)): must be \($schema.minimum) or more, got \(.)");
  def errors($schema; $path):
    [type_errors($schema; $path)] as $wrong_type
    | if ($wrong_type | length) > 0 then $wrong_type[]
      else
        value_errors($schema; $path),
        (select(type == "object") | . as $object | ($schema.properties // {}) as $properties
          | (($schema.required // [])[] | select(. as $k | $object | has($k) | not) | "\(key($path + [.])): missing"),
            (select($schema.additionalProperties == false) | keys_unsorted[]
              | select(. as $k | $properties | has($k) | not) | "\(key($path + [.])): unknown key"),
            ($properties | to_entries[] | select(.key as $k | $object | has($k))
              | .key as $k | .value as $child | $object[$k] | errors($child; $path + [$k]))),
        (select(type == "array" and ($schema | has("items")))
          | to_entries[] | .key as $i | .value | errors($schema.items; $path + [$i]))
      end;
  errors($schema[0]; [])'

# Print the path of the settings schema next to this script or in the skill's assets.
find_schema() {
    for candidate in "$HERE/settings.schema.json" "$HERE/../assets/settings.schema.json"; do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# Exit 0 when the file holds exactly one JSON value.
is_json() {
    [ "$(jq -s length "$1" 2>/dev/null)" = 1 ]
}

if ! schema=$(find_schema); then
    echo "settings.schema.json not found next to $HERE"
    exit 1
fi
if [ ! -f "$SETTINGS" ]; then
    echo "$SETTINGS: file not found"
    exit 1
fi
if ! is_json "$SETTINGS"; then
    echo "$SETTINGS: not valid JSON"
    exit 1
fi
errors=$(jq -r --slurpfile schema "$schema" "$VALIDATE" "$SETTINGS")
if [ -n "$errors" ]; then
    printf '%s\n' "$errors"
    exit 1
fi
echo valid
