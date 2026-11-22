#!/bin/sh
# QA fixture for #66. Do not merge.

name=$1
count=$2

if [ -z "$name" ]; then
    echo "Hello, stranger"
else
    echo "Hello, $name"
fi

banner() {
    echo "=== $1 ==="
}

banner "done" > /dev/null
echo "Goodbye, $nmae"
