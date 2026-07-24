# CodexとClaude Codeのworktree運用

## 原則

- 1タスクにつき1branch・1worktree
- 同じworking treeでCodexとClaudeを同時に動かさない
- 一方が実装し、もう一方が独立レビューする
- Agentにcommitやpushを行わせる場合は明示的に指示する

## 実装worktree

```bash
new-worktree Sepsis.Atlas codex task-001-qc-audit
```

作成物：

```text
branch: agent/codex/task-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/codex-task-001-qc-audit
```

## 任意のbranchまたはcommitから作る

第4引数にbaseを指定します。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001-qc-audit \
  agent/codex/task-001-qc-audit
```

reviewerが変更を加える場合は、このreview worktreeのbranchへcommitし、実装branchへ直接commitしない運用にします。

## local data

各worktreeには独立した次のリンクが作られます。

```text
.local/scratch -> ~/scratch/<Project>/<agent-task>
.local/output  -> <LocalLarge>/<Project>/results/<agent-task>
```

入力データのリンクは `scripts/setup-local-links.sh`から生成されます。scriptにリンク定義がない古いprojectでは、main repositoryの `.local/data/` symlinkをコピーします。

## 削除

```bash
remove-worktree Sepsis.Atlas codex task-001-qc-audit
```

branchも削除する場合：

```bash
remove-worktree \
  Sepsis.Atlas \
  codex \
  task-001-qc-audit \
  --delete-branch
```

未commitの変更があるworktreeは削除されません。
