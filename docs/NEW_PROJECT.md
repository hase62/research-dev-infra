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

`.local/`はGit管理されません。標準ではscratchとworking outputを各端末の `~/scratch/` 以下へ置きます。

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
# WSL2例
link_data "/mnt/e/ProteomicAging/large_objects" large_objects

# macOS例
link_data "/Volumes/ExternalSSD/ProteomicAging/large_objects" large_objects
```

working outputも外部ディスクへ置きたいprojectだけ、次を追加します。

```bash
# WSL2例
use_output_dir "/mnt/e/ProteomicAging/results/$WORKSPACE_NAME"

# macOS例
use_output_dir "/Volumes/ExternalSSD/ProteomicAging/results/$WORKSPACE_NAME"
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

## 5. VS Codeで作業を始める

小さな作業ならmain checkoutを開きます。

```bash
cd ~/src/Sepsis.Atlas
code .
```

CodexまたはClaude CodeのVS Code extensionを標準UIとして使います。Git、解析環境、testはintegrated terminalから実行します。CLI固有機能が必要な場合だけ、同じproject terminalで`codex`または`claude`を起動します。

Agentは必ずproject rootまたはtask worktreeから開始し、Dropbox rootやhome directoryから起動しません。

## 6. 長いtaskは専用worktreeを使う

1つの論理taskに1つのtask名を付けます。

```bash
new-worktree Sepsis.Atlas shared metadata-audit
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
code .
```

このtaskが続く間は同じworktreeを使います。CodexからClaude Codeへ切り替える場合もbranchは替えず、`handoffs/CURRENT.md`とGit差分で引き継ぎます。両Agentへ同時に編集指示を出しません。

作業完了後は、test、commit、push、PR、mergeを行い、worktreeとtask branchを削除します。次のtaskには新しいtask名を付けます。番号は任意で、自動採番されません。

詳細は[worktree運用](WORKTREES.md)を参照してください。

## 7. 別PCでprojectまたはtaskを再開する

project repositoryがない場合：

```bash
GITHUB_ACCOUNT="hase62"
cd ~/src
gh repo clone "$GITHUB_ACCOUNT/Sepsis.Atlas"
cd Sepsis.Atlas
setup-project-links
research-doctor Sepsis.Atlas
```

Dropbox内の必要なfileをそのPCでローカル保存状態にします。外部disk pathがPCごとに異なる場合は、そのPCの実パスに合わせてlink設定を調整します。

進行中のtaskを再開する場合は、同じtask名でlocal worktreeを再構築します。

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
new-worktree Sepsis.Atlas shared metadata-audit
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
code .
```

移動元PCでは、先に`handoffs/CURRENT.md`を更新し、checkpoint commitをpushします。未commit変更、`.local`、解析環境、scratch output、Agent chat sessionは別PCへ移りません。

## 新しい端末から始める場合

GitHub、Miniforge、Codex、Claude Code、解析環境が未設定なら、WSL2では[WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md)、Macでは[Macセットアップ](MAC_SETUP.md)を先に実行してください。
