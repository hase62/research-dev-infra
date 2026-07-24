# CodexとClaude Codeのworktree運用

## 原則

- 1タスクにつき1branch・1worktree
- 通常taskは `shared` worktreeを使い、CodexとClaude Codeを順次切り替えられるようにする
- 同じworking treeでCodexとClaude Codeを同時に動かさない
- 会話履歴は共有されないため、`handoffs/CURRENT.md`、Git差分、test結果を引継ぎに使う
- agent別worktreeは独立実装または独立reviewに使う

## shared worktree

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
```

作成物：

```text
branch: work/task-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
```

VS Code統合terminalで開始します。

```bash
codex
```

利用上限に達したら停止し、次を確認します。

```bash
git status --short
git diff --stat
```

`handoffs/CURRENT.md`を更新して、同じworktreeで切り替えます。

```bash
claude
```

## agent別worktree

独立実装やreviewでは従来どおりagent名を指定できます。

```bash
new-worktree Sepsis.Atlas codex experiment-001
new-worktree Sepsis.Atlas claude review-001
```

任意のbranchまたはcommitを第4引数でbaseにできます。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001-qc-audit \
  work/task-001-qc-audit
```

## local data

各worktreeには独立した次のリンクが作られます。

```text
.local/scratch -> ~/scratch/<Project>/<workspace>
.local/output  -> <LocalLarge>/<Project>/results/<workspace>
```

入力データのリンクは `scripts/setup-local-links.sh`から生成されます。

## 削除

shared worktree：

```bash
remove-worktree Sepsis.Atlas shared task-001-qc-audit
```

agent別worktree：

```bash
remove-worktree Sepsis.Atlas codex experiment-001
```

branchも削除する場合は `--delete-branch` を付けます。未commitの変更があるworktreeは削除されません。
