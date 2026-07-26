# research-dev-infra

WSL2またはmacOS上で、GitHub、Dropbox、VS Code、Emacs、Codex、Claude Code、Miniforgeを組み合わせて研究開発を行うための共通基盤です。

このREADMEは、**新しい端末を研究開発に使える状態へする手順**と、**projectを開始・再開する日常手順**だけをまとめています。1台目と2台目以降で手順を分けません。どの端末でも同じmachine setupを行い、既存projectならcloneして環境とlocal linkを再構築します。

詳細な補足は [`docs/`](docs/) に分離しています。

---

## 1. 基本方針

- 研究projectごとにGitHub repositoryを分ける。
- Git working treeはDropbox外の `~/src/` に置く。
- Dropboxの既存構造は変更しない。
- 必要なデータだけ各projectの `.local/data/` にsymlinkする。
- 大規模データ、秘密情報、解析中の出力はGitHubへ入れない。
- CodexとClaude Codeはproject repositoryまたは専用worktreeの中から起動する。
- 同じworking treeをCodexとClaude Codeに同時編集させない。
- 端末固有の設定は `~/.research_env` とprojectの `.local/` に閉じ込める。
- 解析環境はprojectごとに再構築可能な形で管理する。

WSL2ではrepositoryをLinux filesystemの `~/src/` に置き、Windows版VS CodeからWSL extension経由で開きます。macOSでは `~/src/` に直接cloneし、Mac版VS CodeまたはEmacsで開きます。

---

## 2. 作成される構成

```text
~
├── src/
│   ├── research-dev-infra/
│   ├── Sepsis.Atlas/
│   └── OtherProject/
├── worktrees/
│   └── <Project>/<workspace>/
├── scratch/
│   └── <Project>/<workspace>/{scratch,output}
└── data-roots/
    ├── Research -> Dropbox/Research
    └── ForShareLargeData -> Dropbox/ForShareLargeData
```

各projectの最小構成：

```text
~/src/<Project>/
├── PROJECT.md
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── .vscode/extensions.json
├── analysis/
├── docs/
├── tasks/
├── tests/
├── handoffs/CURRENT.md
├── scripts/setup-local-links.sh
└── .local/                 # Git管理しない
    ├── data/
    ├── scratch/
    └── output/
```

標準ではscratchとoutputを `~/scratch/<Project>/<Workspace>/` に置きます。project固有の外付けSSDや大容量diskを使う場合だけ、`scripts/setup-local-links.sh` で個別に指定します。

---

# 3. 新しい端末のセットアップ

以下は1台目でも追加端末でも共通です。違うのはOS別bootstrapとDropboxの実パスだけです。

## 3.1 infraを端末へ置く

すでにGitHub CLIまたはGit認証が使える場合：

```bash
mkdir -p ~/src
cd ~/src
gh repo clone hase62/research-dev-infra
cd research-dev-infra
```

まだGitHub CLIを使えない場合は、GitHubのWeb画面からrepository ZIPをダウンロードし、次の位置へ展開します。

```text
~/src/research-dev-infra
```

bootstrapとGitHub認証の完了後、ZIP版はGit clone版へ置き換えます。

---

## 3.2 OS別bootstrap

### Windows / WSL2

前提：Windows 11、WSL2、Ubuntuが導入済みであること。

Ubuntu terminalで実行します。

```bash
cd ~/src/research-dev-infra

bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

確認時は次を入力します。

```text
BOOTSTRAP
```

### macOS

最初にApple Command Line Toolsを入れます。

```bash
xcode-select --install
```

installer完了後：

```bash
cd ~/src/research-dev-infra

bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

VS CodeとDropboxもHomebrewから入れる場合：

```bash
bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス" \
  --desktop-apps
```

確認時は次を入力します。

```text
BOOTSTRAP
```

bootstrap後：

```bash
source ~/.zprofile
```

---

## 3.3 GitHubへログインする

両OS共通です。

```bash
gh auth login
gh auth setup-git
gh auth status
gh api user --jq '.login'
```

通常は次を選びます。

```text
GitHub.com
HTTPS
Login with a web browser
```

`GH_TOKEN`または`GITHUB_TOKEN`が古い認証を上書きしていないか確認します。

```bash
[ -n "${GH_TOKEN:-}" ] && echo "GH_TOKEN is set"
[ -n "${GITHUB_TOKEN:-}" ] && echo "GITHUB_TOKEN is set"
```

ZIPからbootstrapした場合は、認証後にclone版へ置き換えます。

```bash
cd ~/src
mv research-dev-infra research-dev-infra-from-zip

gh repo clone hase62/research-dev-infra
cd research-dev-infra
```

新しいcloneが正常であることを確認してからZIP版を削除します。

---

## 3.4 Dropboxと共通commandを設定する

Dropboxには次のdirectoryが既に存在する前提です。

```text
Research
ForShareLargeData
```

### WSL2

通常はWindows userとDropbox pathを自動検出できます。

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.bashrc
hash -r
```

自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "/mnt/c/Users/<WindowsUser>/Dropbox"
```

### macOS

Dropbox File Provider環境では、通常は次の配下から自動検出します。

```text
~/Library/CloudStorage/Dropbox*
```

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.zshrc
hash -r
```

自動検出できない場合は候補を確認します。

```bash
find "$HOME/Library/CloudStorage" \
  -maxdepth 1 \
  -type d \
  -name 'Dropbox*' \
  -print
```

実際のrootを指定します。

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "$HOME/Library/CloudStorage/<実際のDropbox名>"
```

### 共通確認

```bash
ls -ld ~/data-roots/Research
ls -ld ~/data-roots/ForShareLargeData
command -v research-doctor
```

`setup-machine.sh`は次を作成します。

```text
~/.research_env
~/.local/bin/new-project
~/.local/bin/new-worktree
~/.local/bin/remove-worktree
~/.local/bin/setup-project-links
~/.local/bin/research-doctor
~/.local/bin/install-coding-agents
~/.local/bin/install-miniforge
~/.local/bin/setup-vscode
~/.local/bin/setup-agent-defaults
~/.local/bin/setup-emacs
~/.local/bin/analysis-smoke-test
```

infraに新しいcommandが追加された場合は、pull後に `bash scripts/setup-machine.sh` を再実行します。

---

## 3.5 VS Code、Miniforge、Agent、Emacsを導入する

### VS Code

WSL2ではWindows側へVS Codeを導入し、Ubuntu terminalから次を実行します。macOSではMac版VS Codeを導入してから同じcommandを使います。

```bash
setup-vscode
```

WSL2ではRemote - WSLを含み、macOSではWSL extensionを除外して必要なextensionを導入します。

### Miniforge

```bash
install-miniforge
```

Shellを読み直します。

```bash
# WSL2
source ~/.bashrc

# macOS
source ~/.zshrc
```

### CodexとClaude Code

```bash
install-coding-agents
```

Shellを読み直し、versionを確認します。

```bash
codex --version
claude --version
```

### 研究計算用の標準model設定

```bash
setup-agent-defaults
```

確認時は次を入力します。

```text
AGENTS
```

標準設定：

```text
Codex
  model: gpt-5.6
  reasoning effort: xhigh
  Plan Mode effort: xhigh

Claude Code
  update channel: stable
  model: opus
  effort: xhigh
```

実際の設定ファイル：

```text
~/.codex/config.toml
~/.claude/settings.json
```

Claude Codeは当面stable channelで利用可能なOpus 4系列を使い、stable版がOpus 5に対応した段階で `opus` aliasから移行します。

### Emacs

terminal版：

```bash
setup-emacs
```

確認時は次を入力します。

```text
EMACS
```

使用例：

```bash
e PROJECT.md
emacs -nw PROJECT.md
```

GUI版も導入する場合：

```bash
setup-emacs --gui
```

---

## 3.6 CodexとClaude Codeへログインする

認証は端末ごとに行います。credentialをGitHubやDropboxで同期しません。

### Codex

```bash
codex login
```

ChatGPT Businessアカウントを使います。

### Claude Code

```bash
claude
```

Claude Code内でログインし、状態を確認します。

```text
/status
/model
/effort
```

subscription利用時は、意図せずAPI billingへ切り替わらないよう環境変数を確認します。

```bash
[[ -n "${OPENAI_API_KEY:-}" ]] && echo "OPENAI_API_KEY is set"
[[ -n "${ANTHROPIC_API_KEY:-}" ]] && echo "ANTHROPIC_API_KEY is set"
```

---

## 3.7 machine診断

```bash
research-doctor
```

`Failures: 0`なら基盤として使用できます。VS Code、R、Emacsなど未使用の任意toolはwarningでも構いません。

---

# 4. Projectを開始または再開する

## 4.1 新規projectを作る

```bash
new-project Sepsis.Atlas --github
cd ~/src/Sepsis.Atlas
```

次を編集します。

```text
PROJECT.md
scripts/setup-local-links.sh
```

その後：

```bash
setup-project-links
research-doctor Sepsis.Atlas
```

GitHub repositoryを後から接続する場合は、`--github`を付けずに作成します。

---

## 4.2 既存projectを別端末で再開する

端末が1台目か2台目かは関係ありません。既存repositoryをcloneし、端末固有部分だけ再構築します。

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas

setup-project-links
research-doctor Sepsis.Atlas
```

project環境を再作成します。

```bash
mamba env create -f environment.yml
conda activate sepsis-atlas
analysis-smoke-test Sepsis.Atlas
```

追加端末で作り直すもの：

- Codex／Claude Codeのログイン
- Miniforge環境
- `~/.research_env`
- Dropbox rootへのsymlink
- projectの `.local/`

GitHubまたはDropboxで同期しないもの：

- credential
- conda環境本体
- `.local/`
- scratch/output

---

# 5. データlinkを設定する

projectの `scripts/setup-local-links.sh` に、必要なデータだけ記述します。

Dropbox例：

```bash
link_data "$RESEARCH_ROOT/Sepsis/metadata" metadata
link_data "$LARGE_ROOT/Sepsis/processed" processed
```

project固有local disk例：

```bash
# WSL2
link_data "/mnt/e/SepsisAtlas/data" local_data
use_output_dir "/mnt/e/SepsisAtlas/results/$WORKSPACE_NAME"

# macOS
link_data "/Volumes/ExternalSSD/SepsisAtlas/data" local_data
use_output_dir "/Volumes/ExternalSSD/SepsisAtlas/results/$WORKSPACE_NAME"
```

反映：

```bash
setup-project-links
```

確認：

```bash
find .local -maxdepth 2 -type l -print -exec readlink {} \;
```

AgentへDropbox全体やデータroot全体を見せず、必要なsubpathだけlinkします。

---

# 6. 解析環境を作る

原則として1 project 1環境から始めます。

Python中心：

```bash
mamba create -n sepsis-atlas \
  -c conda-forge -c bioconda \
  python=3.12 pip jupyterlab numpy pandas scipy matplotlib \
  scanpy anndata
```

RとPython併用：

```bash
mamba create -n sepsis-atlas \
  -c conda-forge -c bioconda \
  python=3.12 pip jupyterlab numpy pandas scipy matplotlib \
  scanpy anndata \
  r-base r-irkernel r-data.table
```

```bash
conda activate sepsis-atlas
conda env export --from-history > environment.yml
```

OS間で再構築しやすいよう、通常は `--from-history` でexportします。Linuxの完全な解決済みpackage一覧をそのままApple Silicon Macへ再現しないでください。

動作確認：

```bash
analysis-smoke-test Sepsis.Atlas
```

---

# 7. CodexまたはClaude Codeで作業する

必ず対象repositoryまたはworktreeへ移動してから起動します。

```bash
cd ~/src/Sepsis.Atlas
code .
```

terminalから：

```bash
codex
```

または：

```bash
claude
```

Emacsを使う場合も、Agentは同じproject terminalから起動します。

```bash
cd ~/src/Sepsis.Atlas
e PROJECT.md
```

## Plan Mode

Plan Modeは、変更前にrepositoryを調査し、実装計画を提示させるために使います。

Codex：

```text
Shift+TabでPlan Modeへ切替
```

Claude Code：

```text
/plan
```

または：

```bash
claude --permission-mode plan
```

推奨依頼：

```text
まだfileを編集しないでください。
現状、科学的前提、解析単位、data leakage、変更対象、test計画を調査し、
実装planを提示してください。不明点は推測せず未確定事項として分けてください。
```

plan承認後、通常modeへ戻して実装します。Claudeの `opusplan` は実装時に別modelへ切り替えるmodel aliasであり、Plan Modeそのものではありません。この基盤では実装中も `opus / xhigh` を標準とします。

---

# 8. task worktreeとAgent切替

## 8.1 worktreeとは何か

Git worktreeは、**同じGit repositoryを別のfolderへもう1つcheckoutする仕組み**です。
通常のproject本体は次にあります。

```text
~/src/Sepsis.Atlas
```

長いtask用のworktreeを作ると、例えば次が追加されます。

```text
~/worktrees/Sepsis.Atlas/shared-task-001-inventory
```

この2つは同じcommit履歴とGit objectを共有しますが、表示しているbranchと作業fileは別です。
したがって、task側で多数のfileを変更しても、`~/src/Sepsis.Atlas`のmain working treeは汚れません。

```text
~/src/Sepsis.Atlas
  branch: main
  用途: 最新mainの確認、merge後の同期、短いread-only確認

~/worktrees/Sepsis.Atlas/shared-task-001-inventory
  branch: work/task-001-inventory
  用途: task-001の設計、実装、test、Agent切替
```

worktreeはrepository全体を完全複製する仕組みではありません。Git履歴を共有するため、通常のcloneを何個も作るより軽量です。一方、tracked fileはworktreeごとに独立して存在します。

## 8.2 いつworktreeを使うか

| 作業 | 推奨場所 |
|---|---|
| fileを読むだけ、短い確認 | `~/src/<Project>` |
| 数fileだけの明確な小修正 | `~/src/<Project>`でもよい |
| 数時間以上の実装、解析pipeline変更 | shared task worktree |
| CodexとClaude Codeを途中で切り替えるtask | shared task worktree |
| 2つのtaskを並行して進める | taskごとに別worktree |
| 実装とは分離した独立review | review専用worktree |

すべての操作にworktreeを使う必要はありません。**長くなる、変更範囲が広い、別Agentへ引き継ぐ可能性がある**場合に使います。

## 8.3 task worktreeを作る

作成前にmain checkoutを最新かつcleanにします。`new-worktree`は既定でlocalの`main`をbaseにするため、この更新を先に行います。

```bash
cd ~/src/Sepsis.Atlas

git switch main
git pull --rebase
git status
```

`working tree clean`を確認してから作成します。

```bash
new-worktree Sepsis.Atlas shared task-001-inventory
```

このcommandは次を作成します。

```text
branch: work/task-001-inventory
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-inventory
```

さらに、そのworktree専用の次のlinkを作成します。

```text
.local/data
.local/scratch
.local/output
```

## 8.4 VS Codeでworktreeを開く

このworkflowでは、**VS Codeを主要画面として使う方法を標準**にします。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-inventory
code .
```

WSL2では、左下に`WSL: Ubuntu`などが表示されていることを確認します。macOSではlocal folderとして直接開きます。

重要なのは、VS Codeで`~/src/Sepsis.Atlas`ではなく、今作ったworktree folderを開くことです。CodexまたはClaude Code extensionは、現在開いているfolder、active file、選択範囲、Git差分をtask contextとして使用します。

推奨運用：

- 1つのVS Code windowには1つのproject rootまたは1つのworktreeだけを開く。
- main checkoutとtask worktreeを同じmulti-root workspaceへ混在させない。
- window titleまたは左下のGit branch表示で`work/task-001-inventory`を確認する。
- Python/R環境、Git、test commandはVS Codeの統合terminalから実行する。

## 8.5 VS Code extensionとCLIのどちらを使うか

CodexとClaude Codeは、どちらもVS Code extensionを主要UIとして使用できます。**extensionを使う場合、統合terminalで`codex`または`claude`を起動する必要はありません。**

### Codex

VS CodeのCodex icon、またはCommand Paletteの`Codex: Open Codex Sidebar`から開始します。開いているfileや選択範囲をcontextに追加し、提案されたdiffをVS Code内で確認します。

Codex IDE extensionとCodex CLIは同じ`~/.codex/config.toml`を使用するため、このinfraで設定した`gpt-5.6 / xhigh`が両方へ適用されます。

terminal UIを使いたい場合だけ、統合terminalで次を実行します。

```bash
codex
```

### Claude Code

VS CodeのClaude Code iconからsessionを開始します。Plan Mode、inline diff、file参照をVS Code内で使用できます。

Claude Code extensionとstandalone CLIは`~/.claude/settings.json`を共有するため、このinfraで設定した`stable / opus / xhigh`が両方へ適用されます。

terminal UIを使いたい場合だけ、統合terminalで次を実行します。

```bash
claude
```

このinfraはextensionとCLIの両方を導入しますが、日常作業では次を推奨します。

```text
コード閲覧・指示・diff確認: VS Code extension
Git・conda・R/Python・test: VS Code integrated terminal
特殊なCLI commandが必要: codex または claude CLI
```

## 8.6 CodexからClaude Codeへ切り替える

両extensionをインストールしておくこと自体は問題ありません。ただし、**同じworktreeへ同時に編集指示を出してはいけません。**

切替手順：

1. Codexのtaskを停止し、実行中commandがないことを確認する。
2. VS CodeのSource Controlまたはterminalで変更を確認する。
3. `handoffs/CURRENT.md`へ現在地を短く記録する。
4. 可能なら意味のある単位でcheckpoint commitを作る。
5. Claude Code extensionを同じVS Code windowで開始する。
6. ClaudeへhandoffとGit差分を先に読ませる。

```bash
git status
git diff --stat
git diff
```

handoffには最低限、次を記載します。

```text
Task
Current state
Completed
Next actions
Validation performed
Important files and caveats
```

Agent切替時の最初の指示例：

```text
PROJECT.md、CLAUDE.md、handoffs/CURRENT.mdを読み、git statusとgit diffを確認してください。
前Agentの実装を無条件に信頼せず、現在のscientific assumptionsと未完了点を確認してから続行してください。
```

CodexとClaude Codeのchat履歴は自動では引き継がれません。引継ぎの正本は、repository内のinstruction file、`handoffs/CURRENT.md`、commit、`git diff`です。

変更がまだ不完全でcommitできない場合は、未commitのまま切り替えても構いません。同じworktreeなので次のAgentから変更は見えます。ただし、handoffに「未commitである理由」と「壊れている可能性がある箇所」を明記します。

## 8.7 taskを完了する

実装、test、結果確認が終わったら、task branchへcommitしてpushします。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-inventory

git status
# project固有のtestを実行
git add -A
git commit -m "Complete task 001 inventory"
git push -u origin work/task-001-inventory
```

必要ならPull Requestを作成します。

```bash
gh pr create \
  --base main \
  --head work/task-001-inventory
```

mainへmergeした後、main checkoutを更新します。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
```

VS Codeのtask windowを閉じ、worktreeを削除します。

```bash
remove-worktree Sepsis.Atlas shared task-001-inventory
```

branchもmerge済みで削除する場合：

```bash
remove-worktree \
  Sepsis.Atlas \
  shared \
  task-001-inventory \
  --delete-branch
```

未commit変更があるworktreeは削除されません。`.local/output`に残すべき成果物がある場合も、削除前に保存先を確認します。

## 8.8 独立review用worktree

実装とは別のbranchとfolderでreviewしたい場合だけ、review worktreeを作ります。review対象の未commit変更はbaseに含まれないため、先にtask branchへcommitします。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-001 \
  work/task-001-inventory
```

作成後は別のVS Code windowで開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/claude-review-001
code .
```

単にCodexからClaudeへ作業を続けてほしいだけなら、review worktreeは不要です。同じshared task worktreeで順番に切り替えます。

詳細は[`docs/WORKTREES.md`](docs/WORKTREES.md)を参照してください。

---

# 9. 日常運用と端末間移動

## 作業開始

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
git pull --rebase
conda activate sepsis-atlas
```

worktreeを使う場合：

```bash
cd ~/worktrees/Sepsis.Atlas/shared-task-001-inventory
git status
```

## 作業終了・別端末へ移る前

```bash
git status
git diff
```

必要な変更をcommitしてpushします。

```bash
git add <確認済みfile>
git commit -m "Describe completed work"
git push
```

別端末では：

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
git switch <branch>
git pull --rebase
setup-project-links
```

同じbranchを複数端末で同時編集しません。未commit変更を端末間で同期する目的でDropboxを使いません。

---

# 10. データの置き場所

## GitHub

- source code
- R / Python / shell script
- tests
- docs
- `PROJECT.md`、`AGENTS.md`、`CLAUDE.md`
- 小さなmetadataやschema
- `environment.yml`
- データ取得手順

## Dropbox

- 既存の共有研究データ
- 論文やreference資料
- 複数端末で共有する必要がある中規模データ

Dropboxの既存directory構造は変更せず、projectから必要なsubpathだけ参照します。

## project固有local disk / HPC

- 数百GB以上のデータ
- GPU処理用データ
- 一時的な中間生成物
- 再生成可能な大容量結果

全端末共通の固定local rootは作りません。projectごとに絶対pathを `scripts/setup-local-links.sh` へ記述します。

## scratch

- trial output
- cache
- temporary file
- Agentが生成する作業途中の成果物

標準path：

```text
~/scratch/<Project>/<Workspace>/
```

---

# 11. infraを更新する

通常の更新：

```bash
cd ~/src/research-dev-infra
git pull --rebase
bash scripts/setup-machine.sh
```

Shellを再読込します。

```bash
# WSL2
source ~/.bashrc

# macOS
source ~/.zshrc
```

infra自体を変更した場合：

```bash
cd ~/src/research-dev-infra
git status
git diff
bash -n scripts/*.sh templates/project/scripts/*.sh
```

確認後：

```bash
git add README.md docs scripts templates
git commit -m "Describe infrastructure update"
git pull --rebase origin main
git push
```

Git操作前にはrepositoryを確認します。

```bash
pwd
git remote get-url origin
git branch --show-current
```

---

# 12. 提供command

| command | 用途 |
|---|---|
| `bash scripts/bootstrap-ubuntu.sh` | WSL2 Ubuntuへ基本toolを導入 |
| `bash scripts/bootstrap-macos.sh` | macOSへHomebrewと基本toolを導入 |
| `bash scripts/setup-machine.sh` | Dropbox root、共通directory、commandを設定 |
| `new-project` | 新規projectを作成 |
| `new-worktree` | sharedまたはAgent別worktreeを作成 |
| `remove-worktree` | worktreeを安全に削除 |
| `setup-project-links` | `.local`のdata / scratch / output linkを生成 |
| `research-doctor` | machineとprojectを診断 |
| `install-coding-agents` | CodexとClaude Codeを導入 |
| `setup-vscode` | OSに応じたVS Code extensionを導入 |
| `setup-agent-defaults` | Codex gpt-5.6/xhigh、Claude stable/opus/xhighを設定 |
| `setup-emacs` | WSL2またはmacOSへEmacsを導入 |
| `install-miniforge` | OSとCPU architectureに応じてMiniforgeを導入 |
| `analysis-smoke-test` | Git、link、scratch、Python/Rを確認 |

help：

```bash
new-project --help
new-worktree --help
remove-worktree --help
install-miniforge --help
install-coding-agents --help
setup-vscode --help
setup-agent-defaults --help
setup-emacs --help
```

---

# 13. 重要な注意

`AGENTS.md`、`CLAUDE.md`、`PROJECT.md`はAgentへの指示であり、OS permissionやcontainerによる完全なsecurity boundaryではありません。

- Agentは対象repositoryまたはworktreeから起動する。
- Dropbox root、`~/src` root、home directoryから起動しない。
- 必要な入力だけ `.local/data/` にlinkする。
- secret、token、`.env`をrepositoryへ置かない。
- 入力データを直接変更させない。
- commit、push、merge、rebaseは人間が差分確認後に行う。
- Agent作業後は `git status` と `git diff` を確認する。
- 同じworktreeでCodexとClaude Codeを同時稼働させない。
- 患者level dataや機密性の高い未公開データを外部modelへ直接渡さない。

---

# 14. 詳細文書

- [WSL2詳細セットアップ](docs/FROM_WSL_TO_FIRST_ANALYSIS.md)
- [macOS詳細セットアップ](docs/MAC_SETUP.md)
- [machine設定](docs/MACHINE_SETUP.md)
- [新規project開始](docs/NEW_PROJECT.md)
- [worktree運用](docs/WORKTREES.md)
- [トラブルシューティング](docs/TROUBLESHOOTING.md)
- [公式参照先](docs/OFFICIAL_REFERENCES.md)

READMEは共通の標準手順だけを扱い、OS固有の補足や問題解決は `docs/` を参照します。
