#!/bin/sh
# QA fixture for #66. Do not merge.

add() {
    echo $(($1 + $2))
}

mul() {
    echo $(($1 * $3))
}

div() {
    [ "$2" -ne 0 ] || { echo "div: cannot divide by zero" >&2; exit 1; }
    echo $(($1 / $2))
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
    *) usage; exit 0 ;;
esac
