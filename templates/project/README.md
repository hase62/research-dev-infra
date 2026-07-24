# __PROJECT_NAME__

Research code and documentation for **__PROJECT_NAME__**.

## Local setup

```bash
setup-project-links
research-doctor __PROJECT_NAME__
```

Local data are exposed under `.local/` and are not tracked by Git.

Read `PROJECT.md` before starting Codex or Claude Code.

## Open in Visual Studio Code

From WSL2:

```bash
cd ~/src/__PROJECT_NAME__
code .
```

Confirm that the lower-left corner shows a WSL connection. Use the integrated terminal to run `codex` or `claude`. When one service reaches its usage limit, stop it and start the other in the same worktree. Read `handoffs/CURRENT.md`, `git status`, and `git diff` before continuing.
