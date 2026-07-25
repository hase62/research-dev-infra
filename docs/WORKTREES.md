# CodexとClaude Codeのworktree運用

## 原則

- 通常は1タスクにつき1branch・1worktree
- CodexとClaude Codeは同じworktreeを順番に利用できる
- 同じworking treeで両方を同時に動かさない
- 切替時は `handoffs/CURRENT.md`、`git status`、`git diff`を引継ぎ媒体にする
- 独立レビューが必要な場合だけ別worktreeを作る

## 切替可能なtask worktree

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
```

作成物：

```text
branch: work/task-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
```

VS Codeで開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
```

CodexまたはClaude Codeを起動します。一方の利用上限に達したら終了し、同じterminal・同じworktreeで他方を起動します。

## 独立review worktree

第4引数にbase branchまたはcommitを指定します。

```bash
new-worktree   Sepsis.Atlas   claude   review-001-qc-audit   work/task-001-qc-audit
```

reviewerが変更を加える場合はreview branchへcommitし、実装branchを直接書き換えません。

## local data

各worktreeには独立した次のリンクが作られます。

```text
.local/scratch -> ~/scratch/<Project>/<workspace>/scratch
.local/output  -> ~/scratch/<Project>/<workspace>/output
```

入力データのリンクは `scripts/setup-local-links.sh`から生成されます。project固有のローカルSSDが必要なら、そのscriptで任意の絶対パスを `link_data` します。outputを永続ディスクへ置く場合は `use_output_dir` を使います。

## 削除

```bash
remove-worktree Sepsis.Atlas shared task-001-qc-audit
```

branchも削除する場合：

```bash
remove-worktree   Sepsis.Atlas   shared   task-001-qc-audit   --delete-branch
```

未commitの変更があるworktreeは削除されません。`.local/output`の保存が必要なら、削除前に確定成果物を適切な保存先へ移してください。
