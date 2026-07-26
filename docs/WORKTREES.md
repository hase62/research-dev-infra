# Git worktree、VS Code、Agent切替、端末間移動

## 1. 要点

Git worktreeは、1つのGit repositoryからtask専用のworking directoryを作る仕組みです。

```text
~/src/Sepsis.Atlas
  branch: main

~/worktrees/Sepsis.Atlas/shared-metadata-audit
  branch: work/metadata-audit
```

main checkoutを安定した入口として残し、長い実装をtask worktreeへ隔離します。両者はGit objectとcommit履歴を共有しますが、tracked file、current branch、未commit変更は別です。

worktree folderは各PCのlocalにだけ存在します。PC間で共有するのはGitHub上のtask branchです。

## 2. 1 task、1 branch、PCごとのlocal worktree

1つの論理taskに対して、1つのtask名と1つのtask branchを決めます。worktree folderはPCごとに作られるlocal checkoutです。

```text
task名: metadata-audit
branch: work/metadata-audit
path:   ~/worktrees/Sepsis.Atlas/shared-metadata-audit
```

長期projectで順序を追跡したい場合は、番号を手動で付けても構いません。

```text
task-001-metadata-audit
task-002-qc-pipeline
task-003-celltype-annotation
```

番号はGitやscriptの必須仕様ではなく、自動採番もされません。番号を使う場合は、新しいtaskを作るたびに未使用の次番号を割り当てます。並行taskでは作成時点で番号を確保し、完了済みのtask名を別の目的へ再利用しません。

### ライフサイクル

```text
開始
  新しいtask名でworktreeを作る

作業中
  同じtask名とworktreeを使い続ける
  Agentを替えてもbranchは替えない
  PCを替える場合は同じtask名でlocal worktreeを再構築する

完了
  test、commit、push、PR、merge
  各PCのlocal worktreeを削除
  local branchとremote branchを削除

次のtask
  新しいtask名で新しいworktreeを作る
```

`shared`はPC間でfolderが共有されるという意味ではありません。CodexとClaude Codeが同じtaskを**順番に**引き継げるworktreeという意味です。

## 3. worktreeを使う基準

- read-only確認や非常に小さい修正はmain checkoutでもよい。
- 数時間以上、複数file、解析pipeline変更を伴うtaskはshared worktreeを使う。
- CodexとClaude Codeを切り替えるtaskはshared worktreeを使う。
- 別PCで継続する可能性があるtaskもshared worktreeを使う。
- 並行taskはtaskごとに別worktreeを作る。
- 独立reviewだけreview専用worktreeを作る。

main checkoutを常にcleanに保ちたい場合は、小修正もworktreeで行って構いません。

## 4. taskを新規作成する

main checkoutを最新かつcleanにします。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
git status
```

taskを作成します。

```bash
new-worktree Sepsis.Atlas shared metadata-audit
```

作成物：

```text
branch: work/metadata-audit
path:   ~/worktrees/Sepsis.Atlas/shared-metadata-audit
```

`new-worktree`はremoteをfetchした後、branch状態に応じて動作します。

```text
branchなし
  BASE（既定main）から新規作成

local branchのみあり
  local branchへworktreeを接続

local branchとorigin branchあり
  local branchへ接続し、可能ならoriginからfast-forward

origin branchのみあり
  tracking local branchを作成し、別PCの続きから再開
```

localとremoteが分岐している場合は自動mergeせず警告します。両履歴を確認してから解決してください。

## 5. VS Codeで開く

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
code .
```

確認点：

- folder pathが`~/worktrees/...`である。
- Git branchが`work/metadata-audit`である。
- 1つのVS Code windowにmain checkoutとtask worktreeを混在させない。
- WSL2では左下に`WSL: Ubuntu`などが表示される。
- macOSではMac上のlocal folderとして開かれている。

標準UI：

```text
Agentとの会話、file参照、diff review
  VS Code extension

Git、conda、mamba、R、Python、test
  integrated terminal

CLI固有機能
  codex / claude CLI
```

Codex extensionとCLIは`~/.codex/config.toml`を共有します。Claude Code extensionとCLIは`~/.claude/settings.json`を共有します。

## 6. 同じPCでAgentを切り替える

同じworktreeへCodexとClaude Codeから同時に編集指示を出しません。

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

## 7. PC AからPC Bへtaskを移す

### PC A

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit

# handoffs/CURRENT.mdを更新
git status
git diff --stat
git add -p
git commit -m "WIP: checkpoint metadata audit"
git push -u origin work/metadata-audit
git status
```

最後にworking treeがcleanであることを確認します。

Git管理しない中間outputが必要なら、Dropbox、HPC、project固有の永続diskへ保存し、pathと再生成方法をhandoffへ書きます。`~/scratch`の内容はPC Bへ移りません。

### PC B

repositoryがなければcloneします。

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas
setup-project-links
```

同じtask名でworktreeを再構築します。

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
new-worktree Sepsis.Atlas shared metadata-audit

cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
git branch -vv
git status
code .
```

`new-worktree`は`origin/work/metadata-audit`を検出し、tracking branchを作ります。`.local` linkとscratch/outputはPC B向けに再生成されます。

### PC Aへ戻る

PC Bでcommit・pushした後、worktreeが残っていれば更新します。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
git status
git fetch origin
git pull --rebase
```

PC Aでworktreeを削除していた場合は、同じcommandで再構築します。

```bash
new-worktree Sepsis.Atlas shared metadata-audit
```

## 8. 端末間移動の制約

GitHub経由で移動するもの：

```text
commit済みのcodeと文書
task branch
PROJECT.md
AGENTS.md / CLAUDE.md
handoffs/CURRENT.md
```

移動しないもの：

```text
未commit変更
.local link
conda/mamba環境
~/scratch output
実行中process
Agent chat session
```

運用ルール：

- 同じtask branchを複数PCで同時編集しない。
- 移動前にAgentと実行中commandを停止する。
- commit・push後、working treeをcleanにする。
- worktree folderをDropboxへ置かない。
- Agent chat sessionの同期を前提にせず、handoffとcommitを正本にする。
- `.local`と解析環境は各PCで再構築する。

## 9. taskを完了する

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit

# project固有testを実行
git status
git add -A
git commit -m "Complete metadata audit"
git push -u origin work/metadata-audit
```

必要ならPull Request：

```bash
gh pr create --base main --head work/metadata-audit
```

merge後、mainを更新します。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
```

VS Codeのtask windowを閉じ、current PCのworktreeを削除します。

```bash
remove-worktree Sepsis.Atlas shared metadata-audit
```

local branchも削除する場合：

```bash
remove-worktree Sepsis.Atlas shared metadata-audit --delete-branch
```

`--delete-branch`はlocal branchだけを削除します。remote branchはPR merge時の自動削除を使うか、merge確認後に次を実行します。

```bash
git push origin --delete work/metadata-audit
```

複数PCで同じtaskを開いた場合、local worktreeは各PCで削除します。remote branchの削除は1回だけです。

### squash merge後にlocal branchを削除できない場合

Gitはsquash mergeされたtask branchを「merge済み」と判定しない場合があります。`remove-worktree --delete-branch`がlocal branchを残したら、GitHub上のPRがmerge済みでmainに内容が入っていることを確認してから、明示的に削除します。

```bash
git branch -D work/metadata-audit
```

確認せずに`-D`を使わないでください。

## 10. 独立review worktree

review対象を先にcommitします。未commit変更は別worktreeへ現れません。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-metadata-audit \
  work/metadata-audit
```

別のVS Code windowで開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/claude-review-metadata-audit
code .
```

単にCodexからClaude Codeへ作業を続けてほしい場合、review worktreeは不要です。同じshared task worktreeで順番に切り替えます。

## 11. Plan Modeとの関係

```text
worktree
  taskのbranchとfile変更をmainから分離するGitの仕組み

Plan Mode
  Agentが変更前に調査と実装planを作る操作mode
```

長いtaskでは、worktreeをVS Codeで開いた後、最初にPlan Modeで設計を確認します。plan承認後も同じworktreeで実装を続けます。

## 12. よくある混乱

### `shared-metadata-audit`は次のtaskでも使うのか

使い回しません。metadata auditが完了したらworktreeとbranchを削除し、次のtaskには新しいtask名を付けます。

### 番号は自動で増えるのか

増えません。番号は任意の人間向け整理規則です。使う場合はproject内で手動で増やします。

### 別PCに`~/worktrees/...`がない

正常です。task branchをfetchし、同じ`new-worktree` commandでlocal worktreeを再構築します。

### 別PCに未commit変更が見えない

未commit変更は元PCにしかありません。元PCでcommit・pushするか、patchを明示的に移します。worktree folderそのものをDropbox同期しません。

### `new-worktree`がbranch使用中で停止する

同じbranchが同じPCの別worktreeでcheckoutされています。`git worktree list`で場所を確認し、そのworktreeを使うか、不要なら安全に削除します。

### `new-worktree`がlocal/remote divergenceを警告する

同じtask branchを複数PCで並行編集した可能性があります。自動mergeは行われません。両branchの履歴と差分を確認してからrebaseまたはmergeします。

### review worktreeに最新変更が見えない

元task branchの変更が未commitである可能性があります。先にcommitしてからreview worktreeを作ります。
