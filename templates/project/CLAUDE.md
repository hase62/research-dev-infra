@PROJECT.md

Read `handoffs/CURRENT.md` before starting.

# Claude Code instructions

- Operate from this repository root.
- Work only below this repository, except for data deliberately exposed through `workspace/`.
- Do not inspect parent directories, sibling repositories, or Dropbox roots.
- Use `workspace/scratch/` only for temporary, reproducible files.
- Use `workspace/output/` for working outputs.
- `workspace/` is a link layer, not authoritative storage.
- Commit persistent text/code/instructions to Git and store large persistent outputs in the shared location exposed through `workspace/output/`.
- Do not leave the only copy of a required artifact in local scratch.

## Agent switching

This worktree may be continued later by Codex. Before making changes, inspect `git status` and `git diff`. Before handing off, update `handoffs/CURRENT.md` with completed work, remaining work, validation, and caveats. Do not run concurrently with Codex in the same worktree.
