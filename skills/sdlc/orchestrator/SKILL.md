---
name: orchestrator
description: Use when a skill or a long session is about to hand work to a subagent, or wants a fresh view on its own output. Decides when to delegate, how to brief a worker, what the worker returns and who checks the result. Triggers - delegate this, use a subagent, run workers in parallel, get a fresh context. Not for picking the next workflow skill, which is what next does.
type: principle
---

## Rules

1. Delegate when the output is bulky, the work does not depend on this conversation, or a fresh view is the point.
2. Do the work yourself when the decision needs context that only this session holds. Also do it yourself when the brief would be longer than the work, or when two workers would edit the same files.
3. Start the brief with the goal. Give the issue, spec and files as links or paths, not as pasted text. Then say what the worker may change, what done looks like and what to return.
4. Ask for a short summary, the evidence, and the path to the full output. Keep bulky output in that file.
5. You own the result. Check the evidence before you pass anything on.
6. Run workers in parallel only when their files do not overlap. Give each one its own worktree.
7. When a worker fails, start a new one with the original brief and the failed report. Do not continue the failed one.
8. Delegate only to save context. Run at most three workers at once.
9. To start a worker, read `references/harness.md` and follow the section for the harness you run in.
