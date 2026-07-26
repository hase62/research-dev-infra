# Codex instructions

Read `PROJECT.md` and `handoffs/CURRENT.md` before starting.

## Scope

- Operate from this repository root.
- Work only below this repository, except for data deliberately exposed through `workspace/`.
- Do not inspect parent directories, sibling repositories, or Dropbox roots.

## Local paths and persistence

- Shared input data: `workspace/data/`
- Temporary, reproducible files: `workspace/scratch/`
- Working outputs: `workspace/output/`
- `workspace/` contains links and is not the authoritative storage location.
- Commit persistent text/code/instructions to Git. Store large persistent outputs in the shared location exposed through `workspace/output/`.
- Do not leave the only copy of a required artifact in local scratch.

Follow all mandatory rules in `PROJECT.md`.

## Agent switching

This worktree may be continued later by Claude Code. Before making changes, inspect `git status` and `git diff`. Before handing off, update `handoffs/CURRENT.md` with completed work, remaining work, validation, and caveats. Do not run concurrently with Claude Code in the same worktree.
