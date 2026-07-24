# __PROJECT_NAME__

## Goal

TODO: この研究の目的を数行で記載する。

## Current phase

TODO: 現在の作業段階を記載する。

## Repository scope

- Code, tests, lightweight configuration, and documentation are stored in Git.
- Local data are exposed only through `.local/data/`.
- Temporary files must be written under `.local/scratch/`.
- Working outputs must be written under `.local/output/`.

## Mandatory rules

- Work only inside this repository, except for paths explicitly exposed through `.local/`.
- Do not search parent directories or unrelated projects.
- Do not access Dropbox roots directly.
- Treat everything under `.local/data/` as read-only unless explicitly instructed otherwise.
- Do not read `.env`, credentials, tokens, or secret files.
- Do not commit, push, merge, rebase, or delete data unless explicitly requested.
- Inspect `git status` and `git diff` before completing a task.
