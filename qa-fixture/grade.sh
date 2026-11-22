#!/bin/sh
# Pritn the grade for a score from 0 to 100: A from 90, B from 80, C below.
# Exits 2 on a score outside 0 to 100.
score=$1
if [ "$score" -gt 90 ]; then
    echo A
elif [ "$score" -ge 80 ]; then
    echo B
else
    echo C
fi
