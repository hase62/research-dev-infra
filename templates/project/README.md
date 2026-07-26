# __PROJECT_NAME__

Research code and documentation for **__PROJECT_NAME__**.

## Local setup

```bash
setup-workspace
research-doctor __PROJECT_NAME__
```

Shared data and outputs are exposed under `workspace/`; the links themselves are not tracked by Git. `workspace/` is not a private storage area. Persistent text/code belongs in GitHub, and large persistent artifacts belong in Dropbox or the documented shared store. Read `PROJECT.md` before starting Codex or Claude Code.

## Open in Visual Studio Code

```bash
cd ~/src/__PROJECT_NAME__
code .
```

On WSL2, confirm that the lower-left corner shows a WSL connection. On macOS, open the local repository directly. Use the Codex or Claude Code VS Code extension as the primary interface. Use the integrated terminal for Git, environments, tests, or the optional CLI interfaces.

## Long task worktree

Use one unique task name for one logical task.

```bash
new-worktree __PROJECT_NAME__ shared metadata-audit
cd ~/worktrees/__PROJECT_NAME__/shared-metadata-audit
code .
```

Continue using the same task name until that task is merged. Do not reuse the worktree for an unrelated task. After merge, delete the local worktree and task branch, then create a new worktree with a new task name.

`shared` means Codex and Claude Code may use the same worktree sequentially. Do not give both Agents editing tasks at the same time.

## Continue the task on another computer

The worktree folder is local to each computer. Continue through the pushed Git branch.

On the computer you are leaving:

```bash
git add <reviewed-files>
git commit -m "WIP: checkpoint current task"
git push -u origin work/metadata-audit
```

On the next computer:

```bash
cd ~/src/__PROJECT_NAME__
git fetch --all --prune
new-worktree __PROJECT_NAME__ shared metadata-audit
```

`new-worktree` resumes `origin/work/metadata-audit` and recreates local `workspace` links. GitHub carries code, instructions, and handoff notes; Dropbox carries shared data and large persistent outputs. Uncommitted changes, local environments, reproducible scratch outputs, and Agent chat sessions do not move between computers. Record the current state and shared output paths in `handoffs/CURRENT.md`.

## Edit with Emacs

```bash
cd ~/src/__PROJECT_NAME__
e PROJECT.md
```

VS Code and Emacs may both be open, but do not edit the same file in both at the same time.
