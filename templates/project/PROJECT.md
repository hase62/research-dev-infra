# __PROJECT_NAME__

## Goal

TODO: この研究の目的を数行で記載する。

## Current phase

TODO: 現在の作業段階を記載する。

## Repository and storage scope

- Code, tests, lightweight configuration, Agent instructions, handoff notes, and small metadata are stored in Git.
- Shared data, papers, large intermediate outputs, and final outputs are stored in Dropbox or another explicitly documented shared store.
- `.local/` is a machine-local link layer, not the authoritative storage location.
- Shared input data are exposed only through `.local/data/`.
- Temporary and reproducible files must be written under `.local/scratch/`.
- Working outputs must be written under `.local/output/`; outputs needed on another computer must resolve to shared storage or be promoted there before handoff.

## Mandatory rules

- Work only inside this repository, except for paths explicitly exposed through `.local/`.
- Do not search parent directories or unrelated projects.
- Do not access Dropbox roots directly.
- Treat everything under `.local/data/` as read-only unless explicitly instructed otherwise.
- Do not read `.env`, credentials, tokens, or secret files.
- Do not commit, push, merge, rebase, or delete data unless explicitly requested.
- Do not leave the only copy of a persistent file on one computer.
- Commit shareable text/code to Git and place large persistent artifacts in the documented shared storage.
- Treat `.local/scratch/` and any local-only `.local/output/` as disposable and reproducible.
- Inspect `git status` and `git diff` before completing a task.
- Codex and Claude Code may continue the same task sequentially in the same worktree, but must not edit that worktree at the same time.
- When handing work to the other agent, read and update `handoffs/CURRENT.md`; Git files and diffs are the source of truth, not chat history.
