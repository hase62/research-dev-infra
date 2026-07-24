# 実際の新規プロジェクト開始手順

## 1. projectを作成する

GitHub private repositoryも同時に作成する場合：

```bash
new-project Sepsis.Atlas --github
```

ローカルだけ作成する場合：

```bash
new-project Sepsis.Atlas
```

別のownerまたはorganizationに作成する場合：

```bash
new-project Sepsis.Atlas --github my-organization/Sepsis.Atlas
```

作成される構造：

```text
~/src/Sepsis.Atlas/
├── AGENTS.md
├── CLAUDE.md
├── PROJECT.md
├── README.md
├── .gitignore
├── .vscode/extensions.json
├── analysis/
├── docs/
├── handoffs/
│   └── CURRENT.md
├── scripts/
│   └── setup-local-links.sh
├── tasks/
├── tests/
└── .local/
    ├── data/
    ├── output -> LocalLargeまたはscratch
    └── scratch -> ~/scratch/Sepsis.Atlas/main
```

`.local/`はGit管理されません。

## 2. PROJECT.mdを書く

最初は数行で十分です。

```markdown
# Project

## Goal

細胞種別プロテオミクスを用いて加齢関連変化を解析する。

## Current phase

公開データの収集と再現解析。
```

長い運用規則やデータ台帳を最初から作る必要はありません。

## 3. 必要なデータだけリンクする

```bash
nano scripts/setup-local-links.sh
```

ファイル末尾のproject-specific linksへ追加します。

```bash
link_data "$RESEARCH_ROOT/Papers/Aging/Proteomics" papers
link_data "$LARGE_ROOT/Proteomics/PublicData" public_data
link_data "$LOCAL_ROOT/ProteomicAging/large_objects" large_objects
```

絶対パスを直接書く代わりに、次のroot変数を使います。

- `$RESEARCH_ROOT`
- `$LARGE_ROOT`
- `$LOCAL_ROOT`

反映：

```bash
cd ~/src/Sepsis.Atlas
setup-project-links
```

確認：

```bash
find .local -maxdepth 2 -type l -print -exec readlink {} \;
research-doctor Sepsis.Atlas
```

## 4. 最初のcommit

`new-project --github`を使った場合、初期雛形はすでにpushされています。編集した内容だけcommitします。

```bash
git add PROJECT.md scripts/setup-local-links.sh
git commit -m "Configure project and local data links"
git push
```

データ本体やsymlinkは `.local/`配下なのでcommitされません。`scripts/setup-local-links.sh`には共有Dropbox内の相対位置だけが残るため、別PCでも同じscriptを再実行できます。

## 5. Visual Studio CodeからCodexまたはClaude Codeを起動する

main working treeで単独作業する場合：

```bash
cd ~/src/Sepsis.Atlas
code .
```

VS Code統合terminalで：

```bash
codex
```

```bash
cd ~/src/Sepsis.Atlas
claude
```

Agentは必ずproject rootまたはそのworktreeから起動します。次の場所からは起動しません。

```text
~/src
~/data-roots
DropboxのResearch root
DropboxのForShareLargeData root
```

## 6. 通常taskはshared worktreeを使う

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
codex
```

Codexの利用上限に達したら同じworktreeで停止し、`handoffs/CURRENT.md`とGit差分を確認してから `claude` を起動します。

別Agentによるレビュー：

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001-qc-audit \
  agent/codex/task-001-qc-audit

cd ~/worktrees/Sepsis.Atlas/claude-review-001-qc-audit
claude
```

## 7. 別PCで再開する

```bash
cd ~/src
git clone git@github.com:<ACCOUNT>/Sepsis.Atlas.git
cd Sepsis.Atlas
setup-project-links
research-doctor Sepsis.Atlas
```

Dropbox内の必要なファイルをそのPCでローカル保存状態にしてから解析を開始します。

## WSL2導入直後から始める場合

GitHub、Miniforge、Codex、Claude Code、最初の解析環境がまだ未設定の場合は、先に [WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md) を実行してください。
