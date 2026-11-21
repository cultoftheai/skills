#!/bin/sh
# QA fixture for #66. Do not merge.

add() {
    echo $(($1 + $2))
}

mul() {
    echo $(($1 * $3))
}

div() {
    echo $(($1 / $2))
}

greet() {
    echo "Hello $1"
}

usage() {
    echo "usage: fixture.sh add|mul|div|greet ..."
}

case "$1" in
    add) add "$2" "$3" ;;
    mul) mul "$2" "$3" ;;
    div) div "$2" "$3" ;;
    greet) greet "$2" ;;
    *) usage ;;
esac
