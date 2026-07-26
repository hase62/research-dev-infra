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

On WSL2, confirm that the lower-left corner shows a WSL connection. On macOS, open the local repository directly. Use the Codex or Claude Code VS Code extension as the primary interface; the integrated terminal is for Git, environments, tests, or the optional `codex` / `claude` terminal UI. When one service reaches its usage limit, stop its task before starting the other in the same worktree. Read `handoffs/CURRENT.md`, `git status`, and `git diff` before continuing.

## Edit with Emacs

From WSL2 or macOS:

```bash
cd ~/src/__PROJECT_NAME__
e PROJECT.md
```

`e` is installed by `setup-emacs` and opens terminal Emacs on WSL2 or macOS. VS Code and Emacs
can be used for the same repository, but do not edit the same file in both at
the same time.

## Continue the same task on another computer

A worktree folder is local to each computer. Continue the task through its
pushed Git branch, not by synchronizing `~/worktrees/` with Dropbox.

On the computer you are leaving:

```bash
git add <reviewed-files>
git commit -m "WIP: checkpoint current task"
git push -u origin <task-branch>
```

On the next computer, run the same worktree command after fetching:

```bash
cd ~/src/__PROJECT_NAME__
git fetch --all --prune
new-worktree __PROJECT_NAME__ shared <task-name>
```

`new-worktree` resumes `origin/work/<task-name>` when it exists and recreates
local `.local` links and scratch/output directories. Uncommitted changes,
local environments, scratch outputs, and Agent chat sessions do not move
between computers. Record the current state in `handoffs/CURRENT.md`.

