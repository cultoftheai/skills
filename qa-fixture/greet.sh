#!/bin/sh
# QA fixture for #66. Do not merge.

name=$2

if [ -z "$name" ]; then
    echo "Hello, stranger"
else
    echo "Hello, $name"
fi

banner() {
    printf '=== %s ===\n' "$1"
}

banner "done" > /dev/null
echo "Goodbye, $nmae"
