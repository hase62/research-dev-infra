# research-dev-infra

WSL2またはmacOS上で、GitHub、Dropbox、VS Code、Emacs、Codex、Claude Code、Miniforgeを組み合わせて研究開発を行うための共通基盤です。

このREADMEは、**新しい端末を研究開発に使える状態へする手順**と、**projectを開始・再開する日常手順**をまとめています。端末台数では手順を分けず、どの端末でも同じmachine setupを行います。既存projectではrepositoryをcloneし、解析環境と`workspace/`のlinkだけを端末ごとに再構築します。

詳細な補足は [`docs/`](docs/) に分離しています。

---

## 1. 基本方針

- 研究projectごとにGitHub repositoryを分ける。
- Git working treeはDropbox外の`~/src/`に置く。
- 永続化すべき情報の唯一のコピーを、特定PCだけに置かない。
- code、設定、手順、Agent指示、handoff、manifest、小さなmetadataはGitHubで共有する。
- Dropbox上でAgentが扱う範囲は、projectごとの次の4 directoryに固定する。

```text
Research/aicode/input/<Project>
Research/aicode/output/<Project>
ForShareLargeData/aicode/input/<Project>
ForShareLargeData/aicode/output/<Project>
```

- 必要なdataや文書はこの4領域へコピーし、その内部で自由にsubdirectoryを作る。
- AgentはDropbox rootや他projectを探索せず、projectの`workspace/`に作られた固定linkだけを使う。
- `workspace/scratch/`だけはlocalの再生成可能な一時領域とする。
- CodexとClaude Codeはproject repositoryまたは専用worktreeの中から起動し、同じworking treeを同時編集させない。
- 解析環境はprojectごとに再構築可能な形で管理する。

WSL2ではrepositoryをLinux filesystemの`~/src/`へ置き、Windows版VS CodeからWSL extension経由で開きます。macOSでは`~/src/`へ直接cloneします。

## 2. 作成される構成

```text
~
├── src/
│   ├── research-dev-infra/
│   ├── Sepsis.Atlas/
│   └── OtherProject/
├── worktrees/
│   └── <Project>/<worktree-name>/
└── scratch/
    └── <Project>/<checkout-name>/
```

`~/.research_env`にはDropbox全体のrootをexportせず、次の4つのAI用rootだけを記録します。

```text
AICODE_RESEARCH_INPUT_ROOT  = Research/aicode/input
AICODE_RESEARCH_OUTPUT_ROOT = Research/aicode/output
AICODE_LARGE_INPUT_ROOT     = ForShareLargeData/aicode/input
AICODE_LARGE_OUTPUT_ROOT    = ForShareLargeData/aicode/output
```

各projectの最小構成：

```text
~/src/<Project>/
├── PROJECT.md
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── .vscode/
│   ├── extensions.json
│   └── settings.json
├── analysis/
├── docs/
├── tasks/
├── tests/
├── handoffs/CURRENT.md
├── scripts/configure-workspace.sh
└── workspace/                     # Git管理しないlink層
    ├── research-input  -> Research/aicode/input/<Project>
    ├── research-output -> Research/aicode/output/<Project>
    ├── large-input     -> ForShareLargeData/aicode/input/<Project>
    ├── large-output    -> ForShareLargeData/aicode/output/<Project>
    └── scratch         -> local ~/scratch/...
```

4つのDropbox project directoryは`setup-workspace`が必要に応じて作成します。worktreeを複数使う場合は、output側でtask名やrun名のsubdirectoryを作り、衝突を避けます。

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

Dropbox root直下に`Research`と`ForShareLargeData`が存在する前提です。`setup-machine.sh`は、その中へ次を作成します。

```text
Research/aicode/input
Research/aicode/output
ForShareLargeData/aicode/input
ForShareLargeData/aicode/output
```

### WSL2

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

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.zshrc
hash -r
```

自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "$HOME/Library/CloudStorage/<実際のDropbox名>"
```

### 共通確認

```bash
source ~/.research_env
printf '%s\n' \
  "$AICODE_RESEARCH_INPUT_ROOT" \
  "$AICODE_RESEARCH_OUTPUT_ROOT" \
  "$AICODE_LARGE_INPUT_ROOT" \
  "$AICODE_LARGE_OUTPUT_ROOT"

ls -ld \
  "$AICODE_RESEARCH_INPUT_ROOT" \
  "$AICODE_RESEARCH_OUTPUT_ROOT" \
  "$AICODE_LARGE_INPUT_ROOT" \
  "$AICODE_LARGE_OUTPUT_ROOT"

command -v setup-workspace
command -v research-doctor
command -v verify-workspace-migration
```

旧版の`DROPBOX_ROOT`、`RESEARCH_ROOT`、`LARGE_ROOT`はprojectへ公開しません。旧`~/data-roots/`の既知symlinkは安全に削除されます。

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

旧project内の`.local/`廃止、`workspace/`導入、`~/data-roots`廃止、Dropbox実体pathへの直接参照が正しく反映されたかは、専用のread-only検証を実行します。

```bash
verify-workspace-migration
```

この検証はinfra、`~/.research_env`、`~/.bashrc`、共通command、project templateを確認し、temporary directory内で`workspace/`の再構築も試験します。既存projectは変更しません。すでに新方式へ移行した特定projectも確認する場合だけ、pathを追加します。

```bash
verify-workspace-migration --project ~/src/<Project>
```

既存のSepsis.Atlasなど、まだ個別移行していないprojectには`--project`を付けません。

---

# 4. Projectを開始または再開する

## 4.1 新規projectを作る

```bash
new-project Sepsis.Atlas --github
cd ~/src/Sepsis.Atlas
setup-workspace
research-doctor Sepsis.Atlas
```

project名が`Sepsis.Atlas`なら、次が自動的に作成・linkされます。

```text
workspace/research-input  -> Research/aicode/input/Sepsis.Atlas
workspace/research-output -> Research/aicode/output/Sepsis.Atlas
workspace/large-input     -> ForShareLargeData/aicode/input/Sepsis.Atlas
workspace/large-output    -> ForShareLargeData/aicode/output/Sepsis.Atlas
workspace/scratch         -> local scratch
```

必要なdataや資料を該当project directoryへコピーし、その中で用途別のsubdirectoryを作成します。projectごとに任意のDropbox pathを設定する作業はありません。

## 4.2 既存projectをこの端末で再開する

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas

setup-workspace
research-doctor Sepsis.Atlas
```

別端末でもproject名から同じ4つのDropbox directoryへ接続されます。credential、環境本体、`workspace/`のsymlink、local scratch、実行中process、Agent chat sessionは同期されません。

# 5. Dropbox project領域の使い分け

| Workspace path | 用途 |
|---|---|
| `workspace/research-input/` | 文書、論文、metadata、manifest、小さめの入力、手動受け渡しなど。read/write |
| `workspace/research-output/` | report、table、figure、通常サイズの中間・最終成果物 |
| `workspace/large-input/` | 大容量入力。原則read-only |
| `workspace/large-output/` | 大容量の中間・最終成果物 |
| `workspace/scratch/` | localで再生成可能なtemporary file |

Agentにはこの5 path以外を探索させません。4つの共有directory全体を無目的に再帰探索させず、taskで指定したsubdirectoryまたはfileから開始させます。

複数worktreeや複数PCから同じprojectを使う場合は、出力先にtask名やrun名を付けます。

```text
workspace/research-output/metadata-audit/
workspace/large-output/integration-v1/
```

確認：

```bash
find workspace -maxdepth 1 -type l -print -exec readlink {} \;
```

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

## Agentが読む指示file

Agentへの継続的な指示は、特定PCのchat履歴やlocal noteではなく、repository内のtracked Markdownへ置きます。

```text
AGENTS.md
CLAUDE.md
PROJECT.md
README.md
handoffs/CURRENT.md
関連するdocs/*.md
```

worktreeにはtask branchのtracked fileがcheckoutされるため、これらも同じbranchに含まれます。Codexは`AGENTS.md`を起点にし、Claude Codeは`CLAUDE.md`を起点にします。両fileから`PROJECT.md`と`handoffs/CURRENT.md`を読むよう指示しているため、VS Codeでworktree rootを開けば同じ共有指示を利用できます。

GitHubの`main`だけに指示の新版があり、進行中task branchへ未反映の場合、その新版はworktreeから見えません。必要な変更はtask branchへmergeしてpushします。

```bash
cd ~/worktrees/Sepsis.Atlas/shared-metadata-audit
git fetch origin
git merge origin/main
git push
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

移動先でも必要な中間outputは、`workspace/research-output/`または`workspace/large-output/`へ保存します。既にlocal scratchへ作成した場合は移動前に共有側へ移し、subdirectoryと再生成方法を`handoffs/CURRENT.md`へ記録します。`~/scratch`、conda環境、Agent chat session、未commit変更は別PCへ移りません。

### 移動先PC

project repositoryがなければcloneします。

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas
setup-workspace
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

`new-worktree`は`origin/work/metadata-audit`を検出し、tracking branchとlocal worktreeを作ります。Git管理された指示・code・handoffはbranchから復元され、`workspace` linkはそのPC向けに再生成されます。共有dataと永続outputはDropboxの同じ論理pathを参照します。

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

未commit変更があるworktreeは削除されません。必要な成果物が`workspace/research-output/`または`workspace/large-output/`へ保存済みかも削除前に確認します。

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

# 10. 共有先とlocal-only領域

## GitHub

- source code、tests、docs
- `PROJECT.md`、`AGENTS.md`、`CLAUDE.md`
- `handoffs/CURRENT.md`
- manifest、schema、小さなmetadata、環境再構築情報

## Dropbox

Agentが利用するDropbox領域はprojectごとの次の4つだけです。

```text
Research/aicode/input/<Project>
Research/aicode/output/<Project>
ForShareLargeData/aicode/input/<Project>
ForShareLargeData/aicode/output/<Project>
```

必要なdataはこの中へコピーします。Dropbox内の既存研究directoryや他projectをAgentに直接探索させません。

## local-onlyとして許容するもの

- credential、token、secret
- conda/mamba環境本体
- package cache
- temporary fileと再生成可能なscratch
- worktree folderと`workspace/`のsymlink
- 実行中processとAgent chat session

永続化すべき成果物の唯一のコピーをlocal-only領域へ残しません。HPCや外付けdiskを計算用に使った場合も、必要な成果物は4つの共有project directoryへ回収します。

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
| `bash scripts/setup-machine.sh` | 4つの固定Dropbox AI root、共通directory、commandを設定 |
| `new-project` | 新規projectを作成 |
| `new-worktree` | sharedまたはAgent別worktreeを作成 |
| `remove-worktree` | local worktreeを安全に削除し、必要ならlocal branchも削除 |
| `setup-workspace` | `scripts/configure-workspace.sh`から`workspace/`を再構築 |
| `research-doctor` | machineとprojectを診断 |
| `verify-workspace-migration` | `.local/`廃止以降の基盤移行をread-onlyで検証 |
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
setup-workspace --help
verify-workspace-migration --help
install-miniforge --help
install-coding-agents --help
setup-vscode --help
setup-agent-defaults --help
setup-emacs --help
```

---

# 13. 重要な注意

`AGENTS.md`、`CLAUDE.md`、`PROJECT.md`はAgentへのルールであり、OS permissionによる完全なsandboxではありません。

- Agentは対象repositoryまたはworktreeから起動する。
- Dropboxは4つの固定`workspace/` linkからのみ利用する。
- Dropbox root、home directory、`~/src` root、他projectを探索させない。
- `workspace/large-input/`は明示指示がない限り変更・削除しない。
- linked directory全体の再帰探索は、完全inventoryが必要なtaskに限定する。
- secret、token、`.env`をrepositoryへ置かない。
- commit、push、merge、rebase、shared data削除は人間が差分確認後に行う。
- 同じworktreeでCodexとClaude Codeを同時稼働させない。
- 患者level dataや機密性の高い未公開dataを外部modelへ直接渡さない。

# 14. 詳細文書

- [WSL2詳細セットアップ](docs/FROM_WSL_TO_FIRST_ANALYSIS.md)
- [macOS詳細セットアップ](docs/MAC_SETUP.md)
- [machine設定](docs/MACHINE_SETUP.md)
- [新規project開始](docs/NEW_PROJECT.md)
- [worktree運用](docs/WORKTREES.md)
- [トラブルシューティング](docs/TROUBLESHOOTING.md)
- [公式参照先](docs/OFFICIAL_REFERENCES.md)

READMEは共通の標準手順だけを扱い、OS固有の補足や問題解決は `docs/` を参照します。
