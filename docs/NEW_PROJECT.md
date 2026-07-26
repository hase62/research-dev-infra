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

`.local/`はGit管理されませんが、fileの正本を置く場所ではありません。共有dataと永続outputへのsymlink、およびlocal scratchへのsymlinkをまとめるlink層です。標準のworking outputは`~/scratch/`以下ですが、別PCで必要になるoutputはDropbox上の共有directoryへ切り替えます。

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

通常は`$RESEARCH_ROOT`または`$LARGE_ROOT`以下のDropbox pathを指定します。PC固有のローカルSSDや外付けdiskは、共有不要かつ再生成可能なcacheなどに限る例外です。例外pathはtracked scriptへPC名とともに直書きせず、`~/.research_env`のproject固有環境変数から受け取ります。

別PCでも必要なworking outputや最終outputは、原則としてDropboxへ置くよう次を追加します。

```bash
use_output_dir "$LARGE_ROOT/ProteomicAging/results/$WORKSPACE_NAME"
```

共有不要かつ再生成可能な巨大cacheだけをlocal diskへ置く特殊例：

```bash
# ~/.research_env（PCごとの設定。Gitへ入れない）
export PROTEOMIC_AGING_LOCAL_CACHE_ROOT="/mnt/e/ProteomicAging/cache"  # WSL2
# export PROTEOMIC_AGING_LOCAL_CACHE_ROOT="/Volumes/ExternalSSD/ProteomicAging/cache"  # macOS

# scripts/setup-local-links.sh（Gitへcommit）
if [[ -n "${PROTEOMIC_AGING_LOCAL_CACHE_ROOT:-}" ]]; then
  link_data "$PROTEOMIC_AGING_LOCAL_CACHE_ROOT" local_cache
fi
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
git commit -m "Configure project data and output links"
git push
```

データ本体やsymlinkは `.local/`配下なのでcommitされません。一方、どの共有pathを使うかを定義する`scripts/setup-local-links.sh`はcommitします。通常はDropboxの共通rootからのpathだけを記述し、PC固有pathは例外的な環境変数として扱います。

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

Dropbox内の必要なfileをそのPCでoffline利用可能な状態にします。共有linkは`$RESEARCH_ROOT`と`$LARGE_ROOT`から再構築されるため、通常はPCごとのscript修正は不要です。特殊なlocal cacheだけ、`~/.research_env`のproject固有環境変数を設定します。

進行中のtaskを再開する場合は、同じtask名でlocal worktreeを再構築します。

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
new-worktree Sepsis.Atlas shared metadata-audit
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
code .
```

移動元PCでは、先に`handoffs/CURRENT.md`を更新し、checkpoint commitをpushします。別PCでも必要な大きなoutputはDropboxへ保存します。未commit変更、`.local`のlink、解析環境、再生成可能なscratch、Agent chat sessionは別PCへ移りません。

## 新しい端末から始める場合

GitHub、Miniforge、Codex、Claude Code、解析環境が未設定なら、WSL2では[WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md)、Macでは[Macセットアップ](MAC_SETUP.md)を先に実行してください。
