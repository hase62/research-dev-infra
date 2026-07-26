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

From WSL2 or macOS:

```bash
cd ~/src/__PROJECT_NAME__
code .
```

On WSL2, confirm that the lower-left corner shows a WSL connection. On macOS, open the local repository directly. Use the integrated terminal to run `codex` or `claude`. When one service reaches its usage limit, stop it and start the other in the same worktree. Read `handoffs/CURRENT.md`, `git status`, and `git diff` before continuing.

## Edit with Emacs

From WSL2 or macOS:

```bash
cd ~/src/__PROJECT_NAME__
e PROJECT.md
```

`e` is installed by `setup-emacs` and opens terminal Emacs on WSL2 or macOS. VS Code and Emacs
can be used for the same repository, but do not edit the same file in both at
the same time.
