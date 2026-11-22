#!/bin/sh
# QA fixture for #66. Do not merge.

dir=${1:?usage: count.sh <folder>}
files=$(ls $dir)
echo "Files in $dir:"
echo "$files"
total=$(echo "$files" | wc -l)
echo "Total: $total"
