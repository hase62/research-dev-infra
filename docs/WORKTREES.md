# Git worktree、VS Code、Agent切替、端末間移動

## 1. worktreeの役割

Git worktreeは、1つのGit repositoryから複数のworking directoryを作る仕組みです。

```text
~/src/Sepsis.Atlas
  branch: main

~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
  branch: work/task-001-qc-audit
```

main checkoutを安定した入口として残し、長い実装をtask worktreeへ隔離します。両者はcommit履歴とGit objectを共有しますが、tracked file、現在branch、未commit変更は別です。

## 2. worktreeはlocal、branchはportable

`~/worktrees/...`のfolderは各PCにだけ存在し、GitHubへはuploadされません。ただし、worktreeで使用しているtask branchをcommit・pushすれば、別PCで同じbranchからworktreeを再作成できます。

```text
GitHub経由で共有される
  commits
  task branch
  tracked files
  handoffs/CURRENT.md

共有されない
  uncommitted changes
  .local links
  conda/mamba environments
  ~/scratch outputs
  running processes and agent chat sessions
```

このため、端末移動前には途中でもcheckpoint commitを作ります。private task branch上では`WIP:` commitを許容し、必要ならtask完了時に履歴を整理します。

## 3. 使用基準

- read-only確認や非常に小さい修正はmain checkoutでもよい。
- 数時間以上、複数file、解析pipeline、Agent切替を伴うtaskはshared worktreeを使う。
- 別PCで続きを行う可能性がある長いtaskもshared worktreeを使い、task branchをpushする。
- 並行taskはtaskごとに別worktreeを作る。
- 独立reviewだけ別review worktreeを作る。
- CodexとClaude Codeを順番に使うだけなら、同じshared worktreeを使う。

## 4. taskを新規作成する

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
git status

new-worktree Sepsis.Atlas shared task-001-qc-audit
```

作成物：

```text
branch: work/task-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
```

`new-worktree`はremoteをfetchした後、branch状態に応じて動作します。

```text
branchなし
  BASE（既定main）から新規作成

local branchあり
  existing local branchへworktreeを接続

originに同名branchあり
  tracking local branchを作成してremoteの続きから再開
```

## 5. VS Codeで開く

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
```

1つのVS Code windowには、原則として1つのproject rootまたはworktreeだけを開きます。main checkoutとtask worktreeを同じmulti-root workspaceへ入れません。

確認点：

- folder pathが`~/worktrees/...`である。
- Git branchが`work/task-001-qc-audit`である。
- WSL2では左下に`WSL: Ubuntu`などが表示される。
- macOSではMac上のlocal folderとして開かれている。

## 6. VS Code extensionを標準UIとして使う

```text
Agentとの会話、file参照、diff review
  VS Code extension

Git、conda、mamba、R、Python、test
  integrated terminal

CLI限定機能
  codex / claude CLI
```

Codex extensionとCLIは`~/.codex/config.toml`を共有します。Claude Code extensionとCLIは`~/.claude/settings.json`を共有します。

同じworktreeへCodexとClaude Codeから同時に編集指示を出しません。

## 7. 同じPCでAgentを切り替える

```bash
git status
git diff --stat
git diff
```

`handoffs/CURRENT.md`へ次を記録します。

```text
Task
Current state
Completed
Next actions
Validation performed
Important files and caveats
```

同じPC・同じworktreeなら未commit変更も次のAgentから見えます。ただし、別PCへ移る可能性がある場合はcheckpoint commitを作ります。

次のAgentへの最初の指示例：

```text
PROJECT.md、AGENTS.mdまたはCLAUDE.md、handoffs/CURRENT.mdを読み、
git statusとgit diffを確認してください。前Agentの説明を無条件に信頼せず、
scientific assumptions、実装状態、未完了testを独立に確認してから続行してください。
```

## 8. PC AからPC Bへtaskを移す

### PC A

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit

# handoffs/CURRENT.mdを更新
git status
git diff --stat
git add <reviewed-files>
git commit -m "WIP: checkpoint QC audit"
git push -u origin work/task-001-qc-audit
git status
```

最後にworking treeがcleanであることを確認します。

Git管理しない中間outputが必要なら、Dropbox、HPC、project固有の永続diskへ保存し、pathと再生成方法をhandoffへ書きます。`~/scratch`の内容はPC Bへ移りません。

### PC B

repositoryがなければcloneします。

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
```

同じtask名でworktreeを再構築します。

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
git switch main
git pull --rebase

new-worktree Sepsis.Atlas shared task-001-qc-audit

cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
git branch -vv
git status
code .
```

`new-worktree`は`origin/work/task-001-qc-audit`を検出し、tracking branchを作ります。`.local` linkとscratch/outputはPC B向けに再生成されます。

### PC Aへ戻る

PC Bでcommit・pushした後：

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
git status
git fetch origin
git pull --rebase
```

PC Aでworktreeを削除していた場合：

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
```

## 9. 端末間移動の制約

- 同じtask branchを複数PCで同時編集しない。
- 移動前にAgentと実行中commandを停止する。
- commit・push後、working treeをcleanにする。
- worktree folderをDropboxへ置かない。
- uncommitted changesはGitHubから復元できない。
- Agent chat sessionの同期を前提にせず、handoffとcommitを正本にする。
- `.local`と解析環境は各PCで再構築する。

## 10. Plan Modeとの関係

```text
worktree
  taskのbranchとfile変更をmainから分離するGitの仕組み

Plan Mode
  Agentが変更前に調査と実装planを作る操作mode
```

長いtaskでは、worktreeをVS Codeで開いた後、最初にPlan Modeで設計を確認します。plan承認後も同じworktreeで実装を続けます。

## 11. taskを完了する

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit

# project固有testを実行
git status
git add -A
git commit -m "Complete QC audit"
git push -u origin work/task-001-qc-audit
```

必要ならPull Request：

```bash
gh pr create --base main --head work/task-001-qc-audit
```

merge後：

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
```

VS Codeのtask windowを閉じてからworktreeを削除します。

```bash
remove-worktree Sepsis.Atlas shared task-001-qc-audit
```

branchも削除する場合：

```bash
remove-worktree \
  Sepsis.Atlas \
  shared \
  task-001-qc-audit \
  --delete-branch
```

## 12. 独立review worktree

review対象を先にcommitします。uncommitted changesは別worktreeへ現れません。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001-qc-audit \
  work/task-001-qc-audit
```

別のVS Code windowで開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/claude-review-001-qc-audit
code .
```

## 13. よくある混乱

### 別PCに`~/worktrees/...`がない

正常です。task branchをfetchし、同じ`new-worktree` commandでlocal worktreeを再構築します。

### 別PCに未commit変更が見えない

uncommitted changesは元PCにしかありません。元PCでcommit・pushするか、元PCからpatchを明示的に移します。worktree folderそのものをDropbox同期しません。

### `new-worktree`がbranch使用中で停止する

同じbranchが別worktreeでcheckoutされています。`git worktree list`で場所を確認し、そのworktreeを使うか、不要なら安全に削除します。

### review worktreeに最新変更が見えない

元task branchの変更が未commitである可能性があります。先にcommitしてからreview worktreeを作ります。
