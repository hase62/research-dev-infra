@PROJECT.md

Read `handoffs/CURRENT.md` before starting.

# Claude Code instructions

- Operate from this repository root.
- Work only below this repository, except for data deliberately exposed through `.local/`.
- Do not inspect parent directories, sibling repositories, or Dropbox roots.
- Use `.local/scratch/` for temporary files.
- Use `.local/output/` for working outputs.

## Agent switching

This worktree may be continued later by Codex. Before making changes, inspect `git status` and `git diff`. Before handing off, update `handoffs/CURRENT.md` with completed work, remaining work, validation, and caveats. Do not run concurrently with Codex in the same worktree.
