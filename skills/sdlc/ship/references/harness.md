# Remove the worktree that the session runs in

Read this file when the session runs inside the worktree that step 7 removes. The shell cannot stay in a directory that you delete.

## Claude Code

- If the session entered the worktree with `EnterWorktree` and a name, call `ExitWorktree` with `action: "remove"`. It deletes the worktree and its local branch.
- If the session entered it with `EnterWorktree` and a path, call `ExitWorktree` with `action: "keep"`. Then run `git worktree remove <path>` and `git branch -D <branch>` from the main checkout.
- If the harness started this session or subagent in the worktree, do not remove it. Delete only the remote branch, and tell the person the worktree path so they can remove it.

## Codex

- The Codex app makes its own worktrees in a detached HEAD state, under `$CODEX_HOME/worktrees`. It deletes one when the person archives the chat. Do not remove such a worktree. Tell the person to archive the chat.
- For a worktree made with `git worktree add`, run `git -C <main checkout> worktree remove <path>` and `git -C <main checkout> branch -D <branch>`. Then tell the person to start the next session in the main checkout. (unverified: how the Codex CLI handles a working directory that was removed)
