---
name: root-cause
description: Use when something fails, breaks, throws an error or gives a wrong result, and you are about to change code to fix it. Traces the symptom back to the first place where the system went wrong and fixes it there. Triggers - fix this bug, the test fails, it crashes, error, regression, it broke again. Not for new features or for speed tuning when nothing is wrong.
type: principle
---

## Rules

1. Trace each symptom back to the first place where the system went wrong. Fix it there, not where the symptom shows.
2. A guard (a null check, a catch, a retry, a default value) is a fix only when the state that it handles is legitimate. A guard against a state that must not exist hides the fault.
3. When two fixes fail and they share an assumption, the assumption is wrong. Test the assumption directly before you try a third fix.
