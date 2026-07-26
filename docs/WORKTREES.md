# Git worktree、VS Code、Codex、Claude Codeの運用

## 1. worktreeの役割

Git worktreeは、1つのGit repositoryから複数のworking directoryを作る仕組みです。

```text
~/src/Sepsis.Atlas
  branch: main

~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
  branch: work/task-001-qc-audit
```

両者はcommit履歴とGit objectを共有しますが、tracked file、現在branch、未commit変更は別です。

このinfraでは、main checkoutを安定した入口として残し、長い実装をtask worktreeへ隔離します。

## 2. 使用基準

- read-only確認や非常に小さい修正はmain checkoutでもよい。
- 数時間以上、複数file、解析pipeline、Agent切替を伴うtaskはshared worktreeを使う。
- 並行taskはtaskごとに別worktreeを作る。
- 独立reviewだけ別review worktreeを作る。
- CodexとClaude Codeを順番に使うだけなら、同じshared worktreeを使う。

## 3. mainを最新化する

`new-worktree`の既定baseはlocalの`main`です。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
git status
```

main checkoutに未commit変更がある場合、`new-worktree`は停止します。先にcommit、stash、または不要な変更の破棄を行います。

## 4. shared task worktreeを作る

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
```

作成物：

```text
branch: work/task-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
```

第4引数を省略すると`main`から作ります。別branchまたはcommitをbaseにする場合：

```bash
new-worktree Sepsis.Atlas shared task-002-followup work/task-001-qc-audit
```

## 5. VS Codeで開く

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
```

1つのVS Code windowには、原則として1つのproject rootまたはworktreeだけを開きます。main checkoutとtask worktreeを同じmulti-root workspaceへ入れると、Agentが変更対象を誤認しやすくなります。

確認点：

- folder pathが`~/worktrees/...`である。
- Git branchが`work/task-001-qc-audit`である。
- WSL2では左下に`WSL: Ubuntu`などが表示される。
- macOSではMac上のlocal folderとして開かれている。

## 6. VS Code extensionを標準UIとして使う

### Codex

Codex iconまたはCommand Paletteの`Codex: Open Codex Sidebar`から開始します。

- open fileやselected linesをcontextとして渡せる。
- proposed diffをeditor内で確認できる。
- `~/.codex/config.toml`はIDE extensionとCLIで共有される。
- terminal UIが必要な場合だけintegrated terminalで`codex`を実行する。

### Claude Code

Claude Code iconから開始します。

- Plan Mode、inline diff、file referenceをIDE内で使える。
- `~/.claude/settings.json`はextensionとCLIで共有される。
- terminal UIが必要な場合だけintegrated terminalで`claude`を実行する。

推奨分担：

```text
Agentとの会話、file参照、diff review: VS Code extension
Git、conda、mamba、R、Python、test: integrated terminal
CLI限定機能: codex / claude CLI
```

## 7. local dataとoutput

各worktreeには独立した次のlinkが作られます。

```text
.local/data
.local/scratch -> ~/scratch/<Project>/<Workspace>/scratch
.local/output  -> ~/scratch/<Project>/<Workspace>/output
```

入力データのlinkは`scripts/setup-local-links.sh`から生成されます。project固有のlocal SSDが必要なら、そのscriptで任意の絶対pathを`link_data`します。outputを永続diskへ置く場合は`use_output_dir`を使います。

## 8. Agentを切り替える

原則：

- CodexとClaude Codeは同じshared worktreeを順番に利用できる。
- 同じworktreeで両者へ同時に編集させない。
- chat履歴は自動移行しない。
- repository内のinstruction、handoff、commit、diffを引継ぎ媒体にする。

切替前：

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

意味のある単位で安定していればcheckpoint commitを作ります。未完了でcommitできない場合は未commitでもよいですが、handoffへ明記します。

切替後の最初の指示例：

```text
PROJECT.md、AGENTS.mdまたはCLAUDE.md、handoffs/CURRENT.mdを読み、
git statusとgit diffを確認してください。前Agentの説明を無条件に信頼せず、
scientific assumptions、実装状態、未完了testを独立に確認してから続行してください。
```

## 9. Plan Modeとの関係

worktreeとPlan Modeは別の仕組みです。

```text
worktree:
  taskのfile変更とbranchをmainから分離するGitの仕組み

Plan Mode:
  Agentが変更を始める前に調査と実装planを作る操作mode
```

長いtaskでは、worktreeをVS Codeで開いた後、最初にCodexまたはClaude CodeをPlan Modeにして設計を確認します。plan承認後も同じworktreeで実装を続けます。

## 10. taskを完了する

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

未commit変更があるworktreeは削除されません。`.local/output`の保存が必要なら削除前に確認します。

## 11. 独立review worktree

review対象を先にcommitします。未commit変更は別worktreeへ現れません。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001-qc-audit \
  work/task-001-qc-audit
```

作成物：

```text
branch: agent/claude/review-001-qc-audit
path:   ~/worktrees/Sepsis.Atlas/claude-review-001-qc-audit
```

別のVS Code windowで開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/claude-review-001-qc-audit
code .
```

reviewerが変更する場合はreview branchへcommitし、元の実装branchを直接書き換えません。

## 12. よくある混乱

### `~/src/Sepsis.Atlas`を開いたままtaskを始めた

作業前ならwindowを閉じ、task worktreeを`code .`で開き直します。すでに変更した場合は、commitまたはstashしてから適切なbranchへ移します。

### extensionとCLIを両方起動した

両方が同じAgent sessionになるとは限りません。片方を止め、一つのUIに統一します。

### CodexとClaude Codeを同時に開いている

panelが開いているだけなら直ちに問題ではありませんが、両方へ編集taskを同時送信しません。

### review worktreeに最新変更が見えない

base branchの変更が未commitである可能性があります。元task worktreeでcommit後、review worktreeを作り直すか、必要なcommitを取り込みます。

### branchを削除できない

未merge branchに`git branch -d`を実行すると停止します。merge状況を確認し、必要なbranchを誤って削除しないようにします。
