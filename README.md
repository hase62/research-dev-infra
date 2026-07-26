# research-dev-infra

WSL2またはmacOS上で、GitHub、Dropbox、VS Code、Emacs、Codex、Claude Code、Miniforgeを組み合わせて研究開発を行うための共通基盤です。

このREADMEは、**新しい端末を研究開発に使える状態へする手順**と、**projectを開始・再開する日常手順**をまとめています。端末台数では手順を分けず、どの端末でも同じmachine setupを行います。既存projectではrepositoryをcloneし、解析環境とlocal linkだけを端末ごとに再構築します。

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

どの端末でも共通の手順です。OSごとに異なるのはbootstrap、Shell設定、Dropboxの実パスだけです。

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

Claude Codeはstable channelと`opus` aliasを使います。実際に選択されたmodelは新規sessionの`/status`で確認します。stable channelで利用可能なOpusが更新されても、設定ファイルのmodel名を固定し直す必要はありません。

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

## 4.2 既存projectをこの端末で再開する

既存repositoryをcloneし、端末固有部分だけ再構築します。すでにclone済みなら、cloneの代わりに`git pull --rebase`を実行します。

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

# 8. task worktree、Agent切替、端末間移動

## 8.1 worktreeの位置づけ

Git worktreeは、**1つのGit repositoryから、task専用のworking directoryとbranchを追加する仕組み**です。
通常のproject checkoutはmainの入口として残し、長い変更はtask worktreeへ分離します。

```text
~/src/Sepsis.Atlas
  branch: main
  用途: mainの同期、task作成、merge後の確認

~/worktrees/Sepsis.Atlas/shared-<task-name>
  branch: work/<task-name>
  用途: 1つのtaskの設計、実装、test、Agent切替
```

worktreeはrepositoryを丸ごと再cloneするものではなく、Git objectを共有するため軽量です。tracked fileと未commit変更はworktreeごとに独立します。

worktree folderは各PCのlocalにだけ存在します。GitHubへ共有されるのは、worktreeで使うtask branchのcommitです。
したがって、別PCでは同じfolderを同期するのではなく、同じtask branchからlocal worktreeを再構築します。

## 8.2 1 taskのライフサイクル

**1つの論理taskにつき、1つのtask名と1つのtask branch**を使います。worktree folderは端末ごとのlocal checkoutなので、同じtaskを複数PCで扱う場合は、各PCに同じbranchから1つずつ再構築します。

```text
開始
  task名を決めてworktreeを作る

作業中
  同じPCでは同じworktreeを使い続ける
  別PCでは同じtask名でworktreeを再構築する
  CodexとClaude Codeは同じworktreeを順番に使う

完了
  test、commit、push、PR、mainへのmerge
  各PCに残ったworktreeを削除
  local branchとremote branchを削除

次のtask
  新しいtask名で新しいworktreeを作る
```

`shared`はfolderがPC間で共有されるという意味ではありません。**CodexとClaude Codeが同じtaskを順番に引き継げるworktree**という意味です。同時編集はさせません。

### task名

番号は任意で、自動採番されません。長期projectで順序を追跡したい場合だけ、project内で手動で増やします。

```text
番号なし
  metadata-audit
  qc-pipeline
  celltype-annotation

番号あり
  task-001-metadata-audit
  task-002-qc-pipeline
  task-003-celltype-annotation
```

番号を使う場合は、新しいtaskを作るたびに未使用の次番号を割り当てます。並行taskでは作成時点で番号を確保します。完了済みtask名を別の目的へ再利用するとbranch、PR、handoffの意味が曖昧になるため、再利用しません。

例えば、task名を`task-001-metadata-audit`にすると次が作られます。

```text
branch: work/task-001-metadata-audit
path:   ~/worktrees/Sepsis.Atlas/shared-task-001-metadata-audit
```

## 8.3 worktreeを使う基準

| 作業 | 推奨場所 |
|---|---|
| read-only確認 | `~/src/<Project>` |
| 数行の明確な小修正 | `~/src/<Project>`でもよい |
| 数時間以上、複数file、解析pipeline変更 | shared task worktree |
| CodexとClaude Codeを切り替えるtask | shared task worktree |
| 別PCで継続する可能性があるtask | shared task worktree |
| 複数taskを並行する | taskごとに別worktree |
| 実装から分離した独立review | review専用worktree |

main checkoutを常にcleanに保ちたい場合は、小修正もtask worktreeで行って構いません。

## 8.4 taskを開始してVS Codeで開く

main checkoutを最新かつcleanにします。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
git status
```

task名を決めて作成します。

```bash
new-worktree Sepsis.Atlas shared metadata-audit
```

VS Codeでtask folderを開きます。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
code .
```

確認点：

- VS Codeで開いているfolderが`~/worktrees/...`である。
- Git branchが`work/metadata-audit`である。
- 1つのVS Code windowへmain checkoutとtask worktreeを混在させない。
- CodexまたはClaude Code extensionは、現在開いているworktreeだけを対象にする。
- Git、conda、R/Python、testはintegrated terminalから実行する。

Codex／Claude Code extensionを使う場合、terminalで`codex`または`claude`を別途起動する必要はありません。CLI固有機能を使う場合だけ、同じworktreeのintegrated terminalから起動します。

## 8.5 同じPCでAgentを切り替える

CodexとClaude Codeを同じworktreeへ同時に編集させません。

1. 現在のAgentのtaskと実行中commandを停止する。
2. `git status`と`git diff`を確認する。
3. `handoffs/CURRENT.md`へ現在地を記録する。
4. 可能なら意味のある単位でcheckpoint commitを作る。
5. 同じVS Code windowで次のAgentを開始する。
6. 次のAgentへinstruction file、handoff、Git差分を先に読ませる。

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

次のAgentへの最初の指示例：

```text
PROJECT.md、AGENTS.mdまたはCLAUDE.md、handoffs/CURRENT.mdを読み、
git statusとgit diffを確認してください。前Agentの説明を無条件に信頼せず、
scientific assumptions、実装状態、未完了testを独立に確認してから続行してください。
```

同じPCなら未commit変更も次のAgentから見えます。ただし、別PCへ移る可能性がある場合は、途中でもcheckpoint commitを作ってpushします。

## 8.6 別PCで同じtaskを続ける

### 移動元PC

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

Git管理しない中間outputが移動先でも必要なら、Dropbox、HPC、project固有の永続diskへ保存し、そのpathと再生成方法をhandoffへ書きます。`~/scratch`、conda環境、Agent chat session、未commit変更は別PCへ移りません。

### 移動先PC

project repositoryがなければcloneします。

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas
setup-project-links
```

同じtask名でlocal worktreeを再構築します。

```bash
cd ~/src/Sepsis.Atlas
git fetch --all --prune
new-worktree Sepsis.Atlas shared metadata-audit

cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
git branch -vv
git status
code .
```

`new-worktree`は`origin/work/metadata-audit`を検出し、tracking branchとlocal worktreeを作ります。`.local` linkとscratch/outputはそのPC向けに再生成されます。

### 元PCへ戻る

worktreeが残っている場合：

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
git status
git fetch origin
git pull --rebase
```

worktreeを削除済みの場合は、同じcommandで再構築します。

```bash
new-worktree Sepsis.Atlas shared metadata-audit
```

同じtask branchを複数PCで同時編集しません。PCを移る前に、現在のPCでcommit・pushしてから作業を止めます。

## 8.7 taskを完了して削除する

作業worktreeでtest、commit、pushを行います。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit

# project固有のtestを実行
git status
git add -A
git commit -m "Complete metadata audit"
git push -u origin work/metadata-audit
```

必要ならPull Requestを作成します。

```bash
gh pr create \
  --base main \
  --head work/metadata-audit
```

mainへmerge後、main checkoutを更新します。

```bash
cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
```

VS Codeのtask windowを閉じてから、**そのPCのlocal worktree**を削除します。

```bash
remove-worktree Sepsis.Atlas shared metadata-audit
```

local task branchも削除する場合：

```bash
remove-worktree \
  Sepsis.Atlas \
  shared \
  metadata-audit \
  --delete-branch
```

`--delete-branch`が削除するのはlocal branchだけです。GitHubのremote branchは、PR merge時の自動削除を使うか、merge確認後に次を実行します。

```bash
git push origin --delete work/metadata-audit
```

同じtaskを複数PCで開いた場合、worktree folderは各PCにあります。task完了後は各PCでlocal worktreeを削除します。remote branchの削除は1回だけで構いません。

squash mergeではGitがlocal branchをmerge済みと判定せず、`--delete-branch`がbranchを残す場合があります。PRとmainへの反映を確認した後の手動削除方法は[`docs/WORKTREES.md`](docs/WORKTREES.md)を参照してください。

未commit変更があるworktreeは削除されません。`.local/output`に残すべき成果物がある場合も、削除前に保存先を確認します。

## 8.8 独立review用worktree

実装とは別のfolderで独立reviewしたい場合だけ、review worktreeを作ります。review対象の変更は先にtask branchへcommitしてください。

```bash
new-worktree \
  Sepsis.Atlas \
  claude \
  review-metadata-audit \
  work/metadata-audit

cd ~/worktrees/Sepsis.Atlas/claude-review-metadata-audit
code .
```

単にCodexからClaude Codeへ作業を続けてほしい場合、review worktreeは不要です。同じshared task worktreeで順番に切り替えます。

詳細は[`docs/WORKTREES.md`](docs/WORKTREES.md)を参照してください。

---

# 9. 日常の最短手順

## 新しいtaskを始める

```bash
TASK_NAME="metadata-audit"

cd ~/src/Sepsis.Atlas
git switch main
git pull --rebase
new-worktree Sepsis.Atlas shared "$TASK_NAME"
cd "$WORKTREE_ROOT/Sepsis.Atlas/shared-$TASK_NAME"
code .
```

## 同じPCでtaskを再開する

```bash
TASK_NAME="metadata-audit"
cd "$WORKTREE_ROOT/Sepsis.Atlas/shared-$TASK_NAME"
git status
git pull --rebase
code .
```

## 別PCへ移る

移動元でcheckpointをcommit・pushし、移動先で同じcommandを実行します。

```bash
TASK_NAME="metadata-audit"
new-worktree Sepsis.Atlas shared "$TASK_NAME"
```

## taskを終える

```text
test → commit → push → PR/merge → main更新 → 各PCのworktree削除 → branch削除
```

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
git add -A
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
| `remove-worktree` | local worktreeを安全に削除し、必要ならlocal branchも削除 |
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
