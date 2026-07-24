# research-dev-infra

WSL2、GitHub、Codex、Claude Code、既存Dropboxデータを併用して、複数の研究プロジェクトをシンプルに管理するための共通基盤です。

## 基本方針

- 研究プロジェクトごとにGitHub repositoryを分ける。
- Git working treeはWSL2の `~/src/<Project>` に置く。
- 並列作業は `~/worktrees/<Project>` にGit worktreeを作る。
- 一時ファイルは `~/scratch/<Project>` に置く。
- Dropboxの既存構造は変更しない。
- Dropboxは次の2ルートから、必要な場所だけ各projectの `.local/data/` にsymlinkする。
  - `C:\Users\<WindowsUser>\Dropbox\Research`
  - `C:\Users\<WindowsUser>\Dropbox\ForShareLargeData`
- PC固有の大容量データは `LocalLarge` ルートから参照する。
- CodexとClaude Codeは必ずproject repositoryまたはそのworktreeから起動する。

## 作成されるWSL2構成

```text
/home/<user>/
├── src/
│   ├── research-dev-infra/
│   ├── ProjectA/
│   └── ProjectB/
├── worktrees/
│   ├── ProjectA/
│   └── ProjectB/
├── scratch/
│   ├── ProjectA/
│   └── ProjectB/
└── data-roots/
    ├── Research -> /mnt/c/Users/<WindowsUser>/Dropbox/Research
    ├── ForShareLargeData -> /mnt/c/Users/<WindowsUser>/Dropbox/ForShareLargeData
    └── LocalLarge -> /mnt/d/ResearchLocal など
```

## WSL2をインストールした直後の方

Ubuntu基本ツール、GitHub接続、infra repositoryの登録、Dropbox接続、Miniforge、Codex、Claude Code、最初のprojectと解析実行までを、次の文書に一本道でまとめています。

- [WSL2導入後から最初の解析まで](docs/FROM_WSL_TO_FIRST_ANALYSIS.md)

まずここから開始してください。

## 最初の導入

### 1. このrepositoryをGitHubへ置く

GitHub上にprivate repository `research-dev-infra` を作り、この一式をpushします。
Ubuntuの基本ツールとGitHub CLIが未導入なら、先に `docs/FROM_WSL_TO_FIRST_ANALYSIS.md` の手順に従って `scripts/bootstrap-ubuntu.sh` を実行してください。

```bash
mkdir -p ~/src
cd ~/src
unzip /path/to/research-dev-infra.zip
cd research-dev-infra

git init -b main
git add .
git commit -m "Initialize research development infrastructure"

gh repo create research-dev-infra \
  --private \
  --source=. \
  --remote=origin \
  --push
```

GitHub上で先に空repositoryを作った場合は、通常の `git remote add origin` と `git push` を使ってください。

### 2. マシンを初期設定する

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.bashrc
```

通常はWindowsユーザー名とDropboxの場所を自動検出します。自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --windows-user Takanori \
  --local-root /mnt/d/ResearchLocal
```

### 3. CodexとClaude Codeを導入する

```bash
install-coding-agents
```

インストーラーを実行する前に確認を求めます。認証は各PCで個別に行ってください。

### 4. 診断する

```bash
research-doctor
```

## 新規プロジェクト開始

最短手順は次のとおりです。

```bash
new-project ProteomicAging --github
cd ~/src/ProteomicAging
```

`--github`を付けると、現在 `gh` で認証しているGitHubアカウントにprivate repositoryを作成し、初期commitをpushします。

次に、以下の2ファイルだけ編集します。

```bash
nano PROJECT.md
nano scripts/setup-local-links.sh
```

`PROJECT.md`には研究目的と最低限の作業規則を書きます。`scripts/setup-local-links.sh`には、その研究で必要なDropboxまたはローカルデータへのsymlinkを数行追加します。

例：

```bash
link_data "$RESEARCH_ROOT/Papers/Proteomics" papers
link_data "$LARGE_ROOT/Proteomics/cohort_data" cohort_data
link_data "$LOCAL_ROOT/ProteomicAging/raw" raw
```

リンクを反映します。

```bash
setup-project-links
```

確認後にcommitします。

```bash
git add PROJECT.md scripts/setup-local-links.sh
git commit -m "Configure project scope and local data links"
git push
```

以後はproject rootから起動します。

```bash
codex
# または
claude
```

詳細は [docs/NEW_PROJECT.md](docs/NEW_PROJECT.md) を参照してください。

## Agent用worktree

実装用worktreeを作る例：

```bash
new-worktree ProteomicAging codex task-001-import
cd ~/worktrees/ProteomicAging/codex-task-001-import
codex
```

独立レビュー用：

```bash
new-worktree ProteomicAging claude review-001-import agent/codex/task-001-import
cd ~/worktrees/ProteomicAging/claude-review-001-import
claude
```

worktreeごとに `.local/scratch` と `.local/output` が分離されます。Dropbox等への入力リンクはmain repositoryの `.local/data/` からコピーされるか、projectの `scripts/setup-local-links.sh`から再生成されます。

詳細は [docs/WORKTREES.md](docs/WORKTREES.md) を参照してください。

## 提供コマンド

| コマンド | 用途 |
|---|---|
| `new-project` | 新規project repositoryを作成 |
| `new-worktree` | Agent用branchとworktreeを作成 |
| `remove-worktree` | worktreeを安全に削除 |
| `setup-project-links` | `.local`のデータリンクを再生成 |
| `research-doctor` | WSL2・GitHub・Dropbox・Agent環境を点検 |
| `install-coding-agents` | CodexとClaude Codeを公式installerで導入 |
| `install-miniforge` | WSL2内へMiniforgeを導入 |
| `analysis-smoke-test` | projectのGit・data link・scratch・Python/Rを確認 |

## 重要な制限

`AGENTS.md`や`CLAUDE.md`はAgentへの運用指示であり、OSレベルのアクセス制御ではありません。Agentはrepository rootから起動し、Dropboxのルートや `~/src` 直下から起動しないでください。入力データは `.local/data/` に必要なものだけ公開します。
