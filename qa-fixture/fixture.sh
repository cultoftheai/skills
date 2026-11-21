#!/bin/sh
# QA fixture for #66. Do not merge.

add() {
    echo $(($1 + $2))
}

mul() {
    echo $(($1 * $3))
}

div() {
    case "$2" in
        '' | - | *[!0-9-]* | ?*-*) echo "div: the divisor must be a whole number" >&2; exit 1 ;;
    esac
    sign=${2%%[0-9]*}
    d=$(printf '%s\n' "${2#-}" | sed 's/^0*//')
    [ -n "$d" ] || { echo "div: cannot divide by zero" >&2; exit 1; }
    echo $(($1 / ${sign}d))
}

greet() {
    [ -n "$1" ] || { echo "greet: a name is required" >&2; exit 1; }
    echo "Hello $1"
}

usage() {
    echo "usage: fixture.sh add|mul|div|greet ..." >&2
}

case "$1" in
    add) add "$2" "$3" ;;
    mul) mul "$2" "$3" ;;
    div) div "$2" "$3" ;;
    greet) greet "$2" ;;
    *) usage; exit 1 ;;
esac
