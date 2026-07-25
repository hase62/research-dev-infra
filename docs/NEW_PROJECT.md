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
├── analysis/
├── docs/
├── handoffs/
├── scripts/
│   └── setup-local-links.sh
├── tasks/
├── tests/
└── .local/
    ├── data/
    ├── output -> ~/scratch/Sepsis.Atlas/main/output
    └── scratch -> ~/scratch/Sepsis.Atlas/main/scratch
```

`.local/`はGit管理されません。標準ではscratchとworking outputをWSL内へ置きます。

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
```

PC固有のローカルSSDや外付けディスクを使う研究では、その実パスを直接指定します。

```bash
link_data "/mnt/e/ProteomicAging/large_objects" large_objects
```

working outputも外部ディスクへ置きたいprojectだけ、次を追加します。

```bash
use_output_dir "/mnt/e/ProteomicAging/results/$WORKSPACE_NAME"
```

共通root変数は次の2つだけです。

- `$RESEARCH_ROOT`
- `$LARGE_ROOT`

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

データ本体やsymlinkは `.local/`配下なのでcommitされません。`scripts/setup-local-links.sh`にはDropboxの共通パスや、必要なproject固有のローカルパスだけが残ります。

## 5. CodexまたはClaude Codeを起動する

main working treeで単独作業する場合：

```bash
cd ~/src/Sepsis.Atlas
code .
```

VS Codeのterminalから、どちらか一方を起動します。

```bash
codex
```

```bash
claude
```

Agentは必ずproject rootまたはそのworktreeから起動します。

## 6. 切替可能なtask worktreeを使う

```bash
new-worktree Sepsis.Atlas shared task-001-qc-audit
cd ~/worktrees/Sepsis.Atlas/shared-task-001-qc-audit
code .
```

CodexまたはClaude Codeを起動し、一方の利用上限に達したら同じworktreeで他方へ切り替えます。同時には起動しません。

## 7. 別PCで再開する

```bash
cd ~/src
gh repo clone <ACCOUNT>/Sepsis.Atlas
cd Sepsis.Atlas
setup-project-links
research-doctor Sepsis.Atlas
```

Dropbox内の必要なファイルをそのPCでローカル保存状態にします。project固有の外部ディスクパスがPCごとに異なる場合は、そのPCで `scripts/setup-local-links.sh` を調整するか、リンクを手動で作ります。

## WSL2導入直後から始める場合

GitHub、Miniforge、Codex、Claude Code、最初の解析環境がまだ未設定の場合は、先に [WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md) を実行してください。
