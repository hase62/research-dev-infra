# Codex instructions

Read `PROJECT.md` and `handoffs/CURRENT.md` before starting.

## Scope

- Operate from this repository root.
- Work only below this repository, except for data deliberately exposed through `.local/`.
- Do not inspect parent directories, sibling repositories, or Dropbox roots.

## Local paths

- Input data: `.local/data/`
- Temporary files: `.local/scratch/`
- Working outputs: `.local/output/`

Follow all mandatory rules in `PROJECT.md`.

## Agent switching

This worktree may be continued later by Claude Code. Before making changes, inspect `git status` and `git diff`. Before handing off, update `handoffs/CURRENT.md` with completed work, remaining work, validation, and caveats. Do not run concurrently with Claude Code in the same worktree.
