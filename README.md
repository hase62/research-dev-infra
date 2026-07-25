# research-dev-infra

WSL2、GitHub、Visual Studio Code、Codex、Claude Code、Miniforge、既存Dropboxデータを併用し、複数の研究プロジェクトをできるだけ簡単に開始・継続するための共通基盤です。

このREADMEを、**WSL2をインストールした直後から最初の解析を始めるまでの標準手順書**として使用します。

---

## 1. この仕組みの基本方針

- 研究プロジェクトごとにGitHub repositoryを分ける。
- Git repositoryはWSL2のLinux領域に置く。
- Dropboxの既存構造は変更しない。
- 必要なDropboxまたはローカルデータだけを、各projectの `.local/data/` にsymlinkする。
- 大規模データ本体や解析中の出力はGitHubへ入れない。
- Visual Studio Codeを共通の編集、Git差分確認、統合terminal、notebook実行の画面として使う。
- CodexとClaude Codeは両方を導入し、対象project repositoryまたは専用worktreeの中から起動する。
- どちらかの定額プランの利用上限に達したら、同じtask worktreeで停止し、もう一方へ順次切り替える。
- 同じworking treeをCodexとClaude Codeに同時編集させない。
- PC固有の設定は `~/.research_env` と `.local/` に閉じ込める。
- 新規project開始時にYAMLや複雑なデータカタログは要求しない。

コードをLinuxコマンドで扱うため、Git working treeは `/mnt/c/...` やDropbox直下ではなく、WSL2の `~/src/` に置きます。Dropboxは既存データを参照するためのWindows側ストレージとして利用します。Windows版Visual Studio CodeからWSL extensionを介して、このLinux側repositoryを開きます。

この手順でいう「Visual Studio」は **Visual Studio Code** を指します。Windows向けのフルIDEであるVisual Studioは、この構成の前提にはしていません。

---

## 2. 作成される全体構成

```text
/home/<user>/
├── src/
│   ├── research-dev-infra/
│   ├── Sepsis.Atlas/
│   ├── ProteomicAging/
│   └── OtherProject/
│
├── worktrees/
│   ├── Sepsis.Atlas/
│   ├── ProteomicAging/
│   └── OtherProject/
│
├── scratch/
│   ├── Sepsis.Atlas/
│   ├── ProteomicAging/
│   └── OtherProject/
│
└── data-roots/
    ├── Research
    │   -> /mnt/c/Users/<WindowsUser>/Dropbox/Research
    ├── ForShareLargeData
    │   -> /mnt/c/Users/<WindowsUser>/Dropbox/ForShareLargeData
    └── LocalLarge
        -> /mnt/d/ResearchLocal など
```

各projectは次の最小構成を持ちます。

```text
~/src/<Project>/
├── PROJECT.md
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── .vscode/
│   └── extensions.json     # 推奨extension
├── analysis/
├── docs/
├── tasks/
├── tests/
├── handoffs/
│   └── CURRENT.md          # Codex/Claude間の短い引継ぎ
├── scripts/
│   └── setup-local-links.sh
└── .local/                 # Git管理しない
    ├── data/               # 必要な入力データへのsymlink
    ├── scratch/            # WSL2内のtask用一時領域
    └── output/             # PCローカルの作業成果物
```

---

# Part I. 1台目のPC：WSL2導入後から環境を作る

## 3. Ubuntuを開き、infraをWSL2内へ置く

Windows側でこのrepositoryのZIPをダウンロードした場合、例えば次に置きます。

```text
C:\Users\<WindowsUser>\Downloads\research-dev-infra.zip
```

Ubuntuを開きます。

```bash
sudo apt-get update
sudo apt-get install -y unzip

mkdir -p ~/src
cd ~/src

unzip "/mnt/c/Users/<WindowsUser>/Downloads/research-dev-infra.zip"
cd research-dev-infra
```

現在位置を確認します。

```bash
pwd
```

次のようになっていれば正しい状態です。

```text
/home/<user>/src/research-dev-infra
```

---

## 4. Ubuntu基本ツールとGitHub CLIを導入する

GitHubに登録している氏名とメールアドレスを指定します。

```bash
bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

途中で次の確認が出ます。

```text
Type BOOTSTRAP to continue:
```

次を入力します。

```text
BOOTSTRAP
```

導入される主なツールは次のとおりです。

- Git
- GitHub CLI (`gh`)
- curl / wget
- unzip / zip
- rsync
- jq
- ripgrep
- tmux
- shellcheck
- build-essential

確認します。

```bash
git --version
gh --version
git config --global --list
```

メールアドレスをGitHub上で非公開にしたい場合は、GitHubが提供する `noreply` アドレスを `user.email` に設定しても構いません。

---

## 5. GitHub CLIでログインする

```bash
gh auth login
```

通常は次を選択します。

```text
GitHub.com
HTTPS
Login with a web browser
```

認証後、Gitのcredential helperも設定します。

```bash
gh auth setup-git
gh auth status
gh api user --jq '.login'
```

最後のコマンドで自分のGitHubユーザー名が表示されれば正常です。

### 古いpersonal access tokenが認証を上書きしていないか

`GH_TOKEN`または`GITHUB_TOKEN`が設定されていると、保存済みのブラウザ認証より優先されます。

```bash
[ -n "${GH_TOKEN:-}" ] && echo "GH_TOKEN is set"
[ -n "${GITHUB_TOKEN:-}" ] && echo "GITHUB_TOKEN is set"
```

表示された場合は現在のshellから外します。

```bash
unset GH_TOKEN GITHUB_TOKEN
```

設定ファイルに残っていないか確認します。token本体を表示するコマンドは使いません。

```bash
grep -nE 'GH_TOKEN|GITHUB_TOKEN' \
  ~/.bashrc ~/.profile ~/.research_env 2>/dev/null
```

不要な設定行があれば削除して、ブラウザ認証をやり直します。

```bash
gh auth logout --hostname github.com

gh auth login \
  --hostname github.com \
  --web \
  --git-protocol https

gh auth setup-git
gh auth status
```

---

## 6. research-dev-infra自体をprivate GitHub repositoryへ登録する

```bash
cd ~/src/research-dev-infra

git init -b main
git add .
git commit -m "Initialize research development infrastructure"

gh repo create research-dev-infra \
  --private \
  --source=. \
  --remote=origin \
  --push
```

確認します。

```bash
git remote -v
git status
git branch -vv
```

正常な例：

```text
origin  https://github.com/<account>/research-dev-infra.git (fetch)
origin  https://github.com/<account>/research-dev-infra.git (push)
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

### `Resource not accessible by personal access token (createRepository)`

現在使われているtokenにrepository作成権限がありません。

前節の手順で `GH_TOKEN` / `GITHUB_TOKEN` を解除し、`gh auth login --web`をやり直してください。ローカルのcommitは既に成功しているため、`git init`や`git commit`をやり直す必要はありません。認証修正後、`gh repo create ...`だけを再実行します。

### `gh repo view --web`でブラウザが開かない

repository作成やpushの失敗ではありません。WSL2内にURLを開くhelperがないだけです。

Windowsのブラウザで開くには次を使えます。

```bash
explorer.exe "$(gh repo view --json url --jq '.url')"
```

またはURLだけ表示します。

```bash
gh repo view --json url --jq '.url'
```

---

## 7. Dropboxとローカル大容量領域を設定する

本構成は、Dropbox内の次の2ルートを既存構造のまま参照します。

```text
C:\Users\<WindowsUser>\Dropbox\Research
C:\Users\<WindowsUser>\Dropbox\ForShareLargeData
```

PC固有の大容量データは、例として次へ置きます。

```text
D:\ResearchLocal
```

WSL2側で作成します。

```bash
mkdir -p /mnt/d/ResearchLocal
```

マシン設定を実行します。

```bash
cd ~/src/research-dev-infra

bash scripts/setup-machine.sh \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc
```

Windowsユーザー名やDropbox位置を自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --windows-user <WindowsUser> \
  --dropbox-home "/mnt/c/Users/<WindowsUser>/Dropbox" \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc
```

Dドライブを使わないPCでは、WSL2内に作ることもできます。

```bash
bash scripts/setup-machine.sh \
  --local-root "$HOME/local-large"

source ~/.bashrc
```

確認します。

```bash
cat ~/.research_env
ls -l ~/data-roots
research-doctor
```

`~/.research_env`はPC固有ファイルです。GitHubやDropboxで同期しません。

---

## 8. Visual Studio CodeをWindowsへ導入する

このworkflowでは、**Windows版Visual Studio Codeを画面として使い、処理はWSL2内で実行**します。VS Code本体をUbuntuへaptで入れません。

Windows PowerShellで次を実行します。

```powershell
winget install --id Microsoft.VisualStudioCode -e
```

インストール後、Ubuntu terminalを一度閉じて開き直し、確認します。

```bash
code --version
```

続いて、公式のWSL、Codex、Claude Codeと、解析用のPython、Jupyter、R extensionを導入します。

`setup-vscode`は`setup-machine.sh`が`~/.local/bin/`へ登録するcommandです。infraを更新して`setup-vscode.sh`が新しく追加された場合は、先に`setup-machine.sh`をもう一度実行してcommandを再登録します。再実行してもDropboxや既存projectの内容は変更されません。

```bash
cd ~/src/research-dev-infra

bash scripts/setup-machine.sh \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc
hash -r
command -v setup-vscode
setup-vscode
```

Dドライブを使わないPCでは、初回に指定したものと同じ`--local-root`を指定します。command登録前でも、scriptを直接実行できます。

```bash
cd ~/src/research-dev-infra
bash scripts/setup-vscode.sh
```

確認文字列を求められたら、内容を確認して次を入力します。

```text
VSCODE
```

導入対象は次です。

- Microsoft WSL
- OpenAI Codex
- Anthropic Claude Code
- Microsoft Python
- Microsoft Jupyter
- R extension

infra repositoryをVS Codeで開きます。

```bash
cd ~/src/research-dev-infra
code .
```

VS Codeの左下に `WSL: Ubuntu` などの表示が出ていれば、Windows上のVS CodeがWSL2内のrepositoryとLinux toolchainを使用しています。以後、projectもWSL terminalで対象directoryへ移動してから `code .` で開きます。

### `code: command not found`

まずWindows側にVisual Studio Codeが入っていることを確認します。その後、Windows版VS CodeのExtensions画面でMicrosoftの `WSL` extensionを入れ、Command Paletteから `WSL: Connect to WSL` を一度実行してください。Ubuntuを開き直してから再確認します。

```bash
code --version
setup-vscode
```

CodexとClaude CodeのVS Code extensionおよびCLIは、それぞれ別のサービス、認証、利用上限を持ちます。このinfraは残量を自動判定しません。一方が利用上限を通知したら、同じworktreeでそのsessionを停止し、もう一方へ手動で切り替えます。

---

## 9. Miniforgeを導入する

```bash
install-miniforge
source ~/.bashrc
```

確認します。

```bash
conda --version
mamba --version
conda config --show auto_activate_base
```

次の状態が想定されます。

```text
auto_activate_base: false
```

研究用packageはbase環境へ直接追加せず、原則としてprojectごとに環境を分けます。

---

## 10. CodexとClaude Codeを導入する

```bash
install-coding-agents
source ~/.bashrc
```

途中で次が表示されたら、確認後に入力します。

```text
Type INSTALL to continue:
```

```text
INSTALL
```

確認します。

```bash
codex --version
claude --version
```

CodexとClaude Codeは両方を常時導入しておきます。通常はその時点で使いやすい方から開始し、定額プランの利用上限に達したら同じtask worktreeで別のagentへ切り替えます。両者を同じworking treeで同時実行してはいけません。

CLIはVS Codeの統合terminalから起動できます。VS Code extensionを使う場合も、同じrepositoryまたはworktreeを開き、同時編集を避けるという原則は同じです。

現在の `scripts/install-agents.sh` は、Codex installerを非対話モードで実行するため、installer内からCodexを自動起動しません。インストール後のCodexとClaude Codeは、実際の研究repositoryに移動してから手動で起動します。

### 古いscriptで `Start Codex now? [y/N]` に `y` と答えた場合

Codex installerが次のように動いたことがあります。

```text
Start Codex now? [y/N] y
==> Launching Codex
<通常のbash promptへ即座に戻る>
```

これはCodexのインストール失敗ではありません。installer自体が `curl | sh` のパイプ内で実行され、そこから起動された対話CLIがキーボード用の標準入力を利用できず、すぐ終了した可能性があります。

次のような表示に戻っていれば、現在はCodex画面ではなく通常のUbuntu bashです。

```text
<user>@<computer>:~/src/research-dev-infra$
```

Codex画面に入っている場合は、通常の `$` 付きbash promptは表示されません。

古いinstaller呼び出しで処理が途中終了し、Claude Codeだけ入っていない場合：

```bash
curl -fsSL https://claude.ai/install.sh | bash -s stable
hash -r
claude --version
```

infraを最新版へ更新した後、`install-coding-agents`を再実行しても構いません。

---

## 11. マシン全体を診断する

```bash
research-doctor
```

主に次を確認します。

- WSL2上で動作しているか
- Git / curl / bash
- GitHub CLIの認証
- Dropboxの2ルート
- LocalLarge
- `~/src` / `~/worktrees` / `~/scratch`
- Miniforge / conda / mamba
- Codex / Claude Code
- VS Code CLI（未導入ならwarningのみ）

任意ツールがない場合はwarningになります。`Failures: 0`なら基盤としては利用可能です。

---

# Part II. 最初の研究projectを作る

## 12. private GitHub repository付きでprojectを作る

例として `ProteomicAging` を作ります。

```bash
new-project ProteomicAging --github
cd ~/src/ProteomicAging
```

これにより次が作成されます。

```text
~/src/ProteomicAging
~/worktrees/ProteomicAging
~/scratch/ProteomicAging
GitHub private repository: ProteomicAging
```

状態を確認します。

```bash
git status
git remote -v
git branch -vv
```

VS Codeで開きます。

```bash
code .
```

左下がWSL接続になっていることを確認し、以後の編集、terminal、Git差分確認をこのwindowで行います。

GitHub repositoryをまだ作らない場合：

```bash
new-project ProteomicAging
```

後から接続できます。

```bash
cd ~/src/ProteomicAging

gh repo create ProteomicAging \
  --private \
  --source=. \
  --remote=origin \
  --push
```

---

## 13. PROJECT.mdへ研究内容を書く

```bash
nano PROJECT.md
```

最初は数行で十分です。

```markdown
# ProteomicAging

## Goal

細胞種別プロテオミクスを用いて、加齢関連変化と細胞老化標的を解析する。

## Current phase

公開データの収集、入力形式の調査、再現解析環境の構築。
```

`PROJECT.md`はCodexとClaude Codeが最初に理解すべき研究文脈と、データアクセス規則をまとめる場所です。

- `AGENTS.md`：Codex向けの入口
- `CLAUDE.md`：Claude Code向けの入口
- `PROJECT.md`：両者に共通する研究内容と必須ルール

CodexとClaude Codeは、起動したrepositoryまたはworktreeの下を対象にします。親ディレクトリ、Dropbox root、別研究repositoryから起動しません。

---

## 14. 必要なデータだけ `.local/data/` にリンクする

```bash
nano scripts/setup-local-links.sh
```

ファイル末尾のproject-specific sectionへ追加します。

```bash
link_data "$RESEARCH_ROOT/Papers/Aging/Proteomics" papers
link_data "$LARGE_ROOT/Proteomics/PublicData" public_data
link_data "$LOCAL_ROOT/ProteomicAging/large_objects" large_objects
```

実際のDropbox構造に合わせて変更します。Dropbox内をprojectごとに再編成する必要はありません。

リンクを作成します。

```bash
setup-project-links
```

確認します。

```bash
find .local -maxdepth 2 -type l -print -exec readlink {} \;
research-doctor ProteomicAging
```

CodexとClaude Codeに見せる入力は `.local/data/` 以下にリンクした場所だけにします。

`.local/`は `.gitignore` に含まれているため、symlink、データ、scratch、outputはGitHubへpushされません。

---

# Part III. 解析環境を作る

## 15. 原則：1 project 1環境から始める

環境を細かく分けすぎる必要はありません。まずproject用環境を1つ作り、依存関係が衝突した時だけ分割します。

環境名はproject名を小文字のハイフン形式にすると扱いやすくなります。

```text
ProteomicAging -> proteomic-aging
Sepsis.Atlas   -> sepsis-atlas
```

### Python中心の最小例

```bash
mamba create -n proteomic-aging \
  -c conda-forge \
  python=3.12 \
  pip \
  jupyterlab \
  numpy \
  pandas \
  scipy \
  matplotlib
```

### RとPythonを併用する例

```bash
mamba create -n proteomic-aging \
  -c conda-forge \
  -c bioconda \
  python=3.12 \
  pip \
  jupyterlab \
  numpy \
  pandas \
  scipy \
  matplotlib \
  r-base \
  r-irkernel \
  r-data.table
```

環境を有効化します。

```bash
conda activate proteomic-aging
```

確認します。

```bash
which python
python --version
Rscript --version
```

Rを入れていない環境では `Rscript: command not found` でも問題ありません。

### packageを追加する

```bash
mamba install -n proteomic-aging \
  -c conda-forge \
  -c bioconda \
  scikit-learn pyarrow
```

可能な限り、最初から大量のpackageを入れず、解析に必要になったものを追加します。

---

## 16. 環境定義をGitHubで管理する

環境を有効化した状態で、明示的に指定した主要packageを保存します。

```bash
conda env export --from-history > environment.yml
```

内容を確認します。

```bash
cat environment.yml
```

commitします。

```bash
git add environment.yml
git commit -m "Add initial analysis environment"
git push
```

別PCでは次で再作成できます。

```bash
mamba env create -f environment.yml
```

環境名が既に存在する場合は更新します。

```bash
mamba env update -f environment.yml --prune
```

`environment.yml`だけで完全再現が不足する高度なprojectでは、後から `renv.lock`、`uv.lock`、container定義などを追加します。最初から全projectへ強制しません。

---

## 17. 最初の動作確認を行う

project rootで実行します。

```bash
cd ~/src/ProteomicAging
conda activate proteomic-aging
analysis-smoke-test ProteomicAging
```

このtestは次を確認します。

- Git working treeが存在する
- `.local/data/`が存在する
- `.local/scratch/`が存在し書き込める
- `.local/output/`が存在し書き込める
- active environmentのPythonが実行できる
- Rを入れた場合はRscriptが実行できる
- `git status`が実行できる

成功例の末尾：

```text
Failures: 0; warnings: 0
```

Rを入れていない場合などはwarningがあっても構いません。

```text
Failures: 0; warnings: 1
```

`Failures: 0`であれば解析開始可能です。

---

# Part IV. VS CodeからCodexまたはClaude Codeで最初の解析を始める

## 18. 必ず対象projectをVS Codeで開いてから起動する

WSL terminalで対象projectへ移動し、VS Codeを開きます。

```bash
cd ~/src/ProteomicAging
code .
```

VS Codeの統合terminalを開き、解析環境を有効化します。

```bash
conda activate proteomic-aging
```

Codexから開始する場合：

```bash
codex
```

Claude Codeから開始する場合：

```bash
claude
```

VS CodeのCodexまたはClaude Code panelを使っても構いません。最も単純で共通性が高い運用は、VS CodeをeditorとGit画面として使い、統合terminalからCLIを起動する方法です。

次の場所から起動してはいけません。

```text
~
~/src
~/data-roots
DropboxのResearch root
DropboxのForShareLargeData root
```

Agentに見せるデータは `.local/data/` 以下に限定します。

### 最初の依頼例

```text
PROJECT.md、AGENTS.mdまたはCLAUDE.mdを読んでください。

.local/data以下で利用可能な入力データを確認し、入力データ自体は変更せず、
ファイル名、サイズ、形式を一覧化するinventory scriptをanalysis/に作成してください。
結果は.local/outputへ出してください。

まず実施計画を示し、その後に作業してください。
commitやpushは行わないでください。
```

### 一方の利用上限に達したら、同じworktreeで切り替える

CodexとClaude Codeは会話履歴を共有しませんが、**同じdirectory内のfile、Git差分、未commit変更はそのまま共有できます**。上限到達時にrepositoryをcloneし直したり、新しいworktreeへ移動したりする必要はありません。

1. 現在のagent sessionを停止する。両者を同時に動かさない。
2. VS Codeで変更fileを保存する。
3. 統合terminalで状態を確認する。

```bash
git status --short
git diff --stat
```

4. 可能なら `handoffs/CURRENT.md` を短く更新する。

```markdown
## Current state
入力inventory scriptは作成済み。出力先のpath処理を修正中。

## Completed
- analysis/inventory.pyを追加
- CSVとRDSの判定を実装

## Next actions
- symlink先のdirectory処理を確認
- tests/test_inventory.pyを追加

## Validation performed
- 小規模sampleでPython実行済み
```

5. 状態が一貫しているなら、task branch上でcheckpoint commitを作ってもよい。

```bash
git add <必要なfile>
git commit -m "WIP: checkpoint before agent switch"
```

途中状態をcommitしたくなければ、未commit差分のままでも同じworktree内で引き継げます。その場合は `handoffs/CURRENT.md` と `git diff` を必ず確認させます。

6. 同じVS Code window、同じ統合terminalのdirectoryで、もう一方を起動する。

```bash
claude
# または
codex
```

切替後の最初の依頼例：

```text
PROJECT.md、handoffs/CURRENT.md、git status、git diffを確認してください。
前のagentが途中まで進めた同じtaskを引き継いでください。
既存変更を不用意に巻き戻さず、まず現状と次の作業を要約してください。
commitやpushは行わないでください。
```

利用上限で前のagentが突然止まり、handoffを書けなかった場合も、新しいagentに `git status`、`git diff`、変更file、test結果を調べさせれば続行できます。

### Codex／Claude画面から終了する

通常は各CLIの終了コマンドを使うか、`Ctrl+C`で戻ります。終了後に次のようなpromptが出れば通常のbashです。

```text
<user>@<computer>:~/src/<Project>$
```

---

## 19. Agent作業後に人間が確認する

Agentに自動commit・pushをさせず、まず差分を確認します。

```bash
git status
git diff
```

新規ファイルも確認します。

```bash
git status --short
```

テストや解析を再実行し、問題がなければ人間がcommitします。

```bash
git add PROJECT.md scripts analysis tests environment.yml
git commit -m "Set up initial analysis workflow"
git push
```

`.local/`以下はGit管理しません。

---

# Part V. 日常運用

## 20. 作業を始める時

```bash
cd ~/src/<Project>
git status
git fetch --all --prune
git pull --rebase
code .
```

VS Codeの統合terminalで解析環境を有効化し、CodexまたはClaude Codeを起動します。

```bash
conda activate <environment-name>
codex
# または
claude
```

一方の利用上限に達したら、そのsessionを停止し、同じdirectoryで `handoffs/CURRENT.md` とGit差分を確認してからもう一方を起動します。

---

## 21. PCを移る前

```bash
git status
git diff
```

問題がなければcommit・pushします。

```bash
git add <必要なファイル>
git commit -m "Describe the completed work"
git push
```

未commit、未pushの状態で別PCへ移らないことを原則とします。

データ本体はGitHubではなく、Dropbox、LocalLarge、HPCのいずれかにあります。別PCで同じデータが必要なら、そのPCでも `.local/data/` のlink先を設定します。

---

# Part VI. 切替可能なtask worktreeと独立review worktree

## 22. 上限到達時にagentを切り替えられるshared worktreeを作る

main working treeに未commit変更がないことを確認します。

```bash
cd ~/src/ProteomicAging
git status
```

通常の実装taskは、agent名ではなく `shared` modeで作ることを推奨します。

```bash
new-worktree ProteomicAging shared task-001-import

cd ~/worktrees/ProteomicAging/shared-task-001-import
code .
```

作成されるbranch：

```text
work/task-001-import
```

VS Codeの統合terminalで開始します。

```bash
conda activate proteomic-aging
codex
```

Codexの利用上限に達したら、同じworktreeで停止し、handoffとGit差分を確認してから切り替えます。

```bash
claude
```

agent別worktreeは、独立実装やreviewを同時並行させたい場合に使います。

```bash
new-worktree ProteomicAging codex experiment-001
new-worktree ProteomicAging claude review-001
```

各worktreeには独立した次の領域が作られます。

```text
.local/scratch
.local/output
```

入力data linkはprojectの `scripts/setup-local-links.sh` から再生成されます。

同じworking treeでCodexとClaude Codeを同時に編集させません。shared worktreeでは順次切替、agent別worktreeでは独立作業とreviewに使います。

標準運用：

```text
shared worktreeで一方が実装
  ↓
利用上限または役割交代
  ↓
handoffs/CURRENT.md + Git差分
  ↓
同じworktreeでもう一方が続行
  ↓
必要に応じて別worktreeで独立レビュー
  ↓
人間が採否判断
```

---

## 23. 特定branchを基点にreview worktreeを作る

CodexのbranchをClaude Codeでreviewする例：

```bash
new-worktree \
  ProteomicAging \
  claude \
  review-001-import \
  agent/codex/task-001-import

cd ~/worktrees/ProteomicAging/claude-review-001-import
claude
```

この実装ではreview用にも新しいbranchが作られます。reviewerに変更させたくない場合は、依頼文で「レビューのみ、ファイル変更禁止」と明示します。

---

## 24. worktreeを削除する

まずworktree内に未commit変更がないことを確認します。

```bash
git status
```

shared worktreeだけ削除し、branchを残す場合：

```bash
remove-worktree ProteomicAging shared task-001-import
```

agent別worktreeの場合：

```bash
remove-worktree ProteomicAging codex experiment-001
```

branchも削除する場合：

```bash
remove-worktree \
  ProteomicAging \
  codex \
  task-001-import \
  --delete-branch
```

branchが未mergeなら、Gitが安全のため削除を拒否することがあります。内容を確認してから対応します。

---

# Part VII. 2台目以降のPC

## 25. 方針

2台目以降では、次をGitHubから取得します。

- `research-dev-infra`
- 各研究project repository
- `environment.yml`などの環境定義

次はPCごとに作り直します。

- Codex／Claude Codeのログイン
- Miniforge環境
- `~/.research_env`
- DropboxとLocalLargeへのsymlink
- 各projectの `.local/`

認証情報、conda環境本体、`.local/`をDropboxやGitHubで同期しません。

---

## 26. 2台目でinfraを取得する

### 方法A：最初にGitHub CLIを準備できる場合

Git、curl、GitHub CLIを導入し、ログインします。

```bash
gh auth login
gh auth setup-git
```

その後：

```bash
mkdir -p ~/src
cd ~/src

gh repo clone <GitHubAccount>/research-dev-infra
cd research-dev-infra
```

### 方法B：まだGitHub CLIがない場合

Windowsブラウザでprivate repositoryのZIPをダウンロードして、1台目と同様にWSL2へ展開します。その後、以下を実行します。

```bash
cd ~/src/research-dev-infra

bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"

gh auth login
gh auth setup-git
```

ZIP展開版をそのまま使うより、認証後にGit cloneへ置き換える方が以後の更新が簡単です。

```bash
cd ~/src
mv research-dev-infra research-dev-infra-from-zip

gh repo clone <GitHubAccount>/research-dev-infra
```

必要がなくなったことを確認してからZIP版を削除します。

---

## 27. 2台目のマシン設定

```bash
cd ~/src/research-dev-infra

bash scripts/setup-machine.sh \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc

# Windows側にVisual Studio Codeを導入後
setup-vscode

install-miniforge
source ~/.bashrc

install-coding-agents
source ~/.bashrc

research-doctor
```

Dropboxの位置やLocalLargeのドライブが1台目と異なっても構いません。`setup-machine.sh`の引数でそのPCの実パスを指定します。

---

## 28. 2台目で研究projectを取得する

```bash
cd ~/src
gh repo clone <GitHubAccount>/ProteomicAging
cd ProteomicAging
```

データリンクを設定します。

```bash
nano scripts/setup-local-links.sh
setup-project-links
research-doctor ProteomicAging
```

通常、`scripts/setup-local-links.sh`自体はGitHubから取得済みです。同じDropbox相対パスを使えるPCなら編集せず、そのまま `setup-project-links` を実行できます。

解析環境を再作成します。

```bash
mamba env create -f environment.yml
conda activate proteomic-aging
analysis-smoke-test ProteomicAging
code .
```

VS CodeのCodex、Claude Code extensionはPCごとにサインインします。これで1台目と同じコードを使って解析でき、どちらかの利用上限に達した場合も同じworktreeで別のagentへ切り替えられます。

---

# Part VIII. データの置き場所

## 29. GitHubに置くもの

- ソースコード
- shell / R / Python script
- 軽量な設定
- `PROJECT.md`、`AGENTS.md`、`CLAUDE.md`
- docs
- tests
- metadata schema
- 小さなTSV / CSV
- `environment.yml`
- 入力データの取得手順

---

## 30. Dropbox `Research` / `ForShareLargeData`から参照するもの

既存構造は変更しません。必要な場所を `.local/data/` にlinkします。

主な用途：

- 論文PDF
- Supplementary files
- 研究資料
- metadata source
- 複数PCで共有したい処理済みデータ
- 比較的小〜中規模のRDS / H5AD
- 確定成果物

Dropbox上の入力ファイルは、原則として読み取り専用として扱います。

頻繁に書き換えるDuckDB、SQLite、HDF5、workflow work directory、大量ログなどはDropbox上で直接運用しません。

---

## 31. LocalLargeに置くもの

```text
D:\ResearchLocal
```

または各PCで指定した大容量領域です。

主な用途：

- 数十GB〜TB級データ
- FASTQ / BAM / CRAM
- Cell Ranger全出力
- 大規模RDS / H5AD
- integration object
- model checkpoint
- PC固有の作業結果

projectからは次の形式でlinkします。

```bash
link_data "$LOCAL_ROOT/<Project>/raw" raw
```

---

## 32. WSL2 scratchに置くもの

```text
~/scratch/<Project>/<Workspace>
```

主な用途：

- 再生成可能な一時ファイル
- 高頻度I/O
- 大量の小ファイル
- 一時展開
- cache
- workflowの中間生成物

Git repositoryと高頻度I/Oの作業領域をWSL2のLinux filesystemに置くことで、Linuxツール使用時の速度と互換性を確保します。

---

# Part IX. infra repository自体を更新する

## 33. 別PCで変更されたinfraを取り込む

```bash
cd ~/src/research-dev-infra
git status
git pull --rebase
```

setup scriptやcommand symlinkが増えた場合は、再度実行します。

```bash
bash scripts/setup-machine.sh \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc
research-doctor
```

---

## 34. READMEやscriptを変更してGitHubへ反映する

```bash
cd ~/src/research-dev-infra

git status
git diff
bash -n scripts/*.sh
shellcheck scripts/*.sh templates/project/scripts/*.sh
```

問題がなければ：

```bash
git add README.md scripts docs templates
git commit -m "Expand setup and analysis workflow documentation"
git push
```

---

# Part X. よくある問題

## 35. `command not found: new-project`など

```bash
source ~/.bashrc
```

それでも見つからない場合：

```bash
echo "$PATH"
ls -l ~/.local/bin
cat ~/.research_env
```

`setup-machine.sh`を再実行します。

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh --local-root /mnt/d/ResearchLocal
source ~/.bashrc
```

---

## 36. Dropbox directory was not found

Windows側でDropboxが起動しており、次が存在するか確認します。

```bash
ls -ld "/mnt/c/Users/<WindowsUser>/Dropbox/Research"
ls -ld "/mnt/c/Users/<WindowsUser>/Dropbox/ForShareLargeData"
```

Dropboxの実際の場所が異なる場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "/mnt/c/実際の/Dropbox" \
  --local-root /mnt/d/ResearchLocal
```

---

## 37. Dropboxファイルが見えるが読めない

Dropboxの「オンラインのみ」状態で、実体がまだPCにダウンロードされていない可能性があります。Windows側のDropboxで対象folderまたはfileをローカル保存状態にしてから再確認します。

```bash
ls -lh .local/data/<link-name>
```

---

## 38. `claude: command not found`

```bash
curl -fsSL https://claude.ai/install.sh | bash -s stable
hash -r
source ~/.bashrc
claude --version
```

最新版のinfraでは、Codexを自動起動せず、その後にClaude Code installerまで進むようになっています。

---

## 39. `codex`を実行すると通常promptへ戻る

通常promptの例：

```text
<user>@<computer>:~/src/<Project>$
```

installerのパイプ内から起動された場合は標準入力の都合ですぐ終了することがあります。通常のbashから、対象project内で改めて直接実行します。

```bash
cd ~/src/<Project>
codex
```

それでも終了する場合：

```bash
codex --version
which codex
```

versionが表示されればインストール自体は完了しています。

---

## 40. `new-worktree`がmainの未commit変更を理由に止まる

安全のための仕様です。

```bash
cd ~/src/<Project>
git status
git diff
```

変更をcommitするか、意図的にstashしてから再実行します。

```bash
git stash push -u -m "Temporary before worktree"
```

作業後に戻す場合：

```bash
git stash pop
```

---

## 41. `analysis-smoke-test`でRだけwarningになる

active environmentにRを入れていないだけなら問題ありません。Rを使うprojectであれば追加します。

```bash
mamba install -n <environment-name> -c conda-forge r-base
```

---

## 42. GitHubへ大きなfileをcommitしてしまった

push前なら、Gitのindexから外します。

```bash
git rm --cached <large-file>
```

`.gitignore`へ追加してcommitし直します。既にpushした大容量fileの履歴削除は別途対応が必要です。研究データは原則として `.local/`、Dropbox、LocalLarge、HPCへ置きます。

---

## 43. `setup-vscode: command not found`

`setup-vscode.sh`を追加した後にinfra repositoryだけを更新し、`setup-machine.sh`を再実行していない場合に発生します。`setup-machine.sh`は共通commandを`~/.local/bin/`へsymlinkとして登録します。

```bash
cd ~/src/research-dev-infra

bash scripts/setup-machine.sh \
  --local-root /mnt/d/ResearchLocal

source ~/.bashrc
hash -r
command -v setup-vscode
```

正常なら、次のようなpathが表示されます。

```text
/home/<user>/.local/bin/setup-vscode
```

その後に実行します。

```bash
setup-vscode
```

急いでいる場合はcommand登録を待たず、repository内のscriptを直接実行できます。

```bash
cd ~/src/research-dev-infra
bash scripts/setup-vscode.sh
```

まだ見つからない場合は次を確認します。

```bash
ls -l ~/.local/bin/setup-vscode
echo "$PATH" | tr ':' '\n' | grep -F "$HOME/.local/bin"
```

---

## 44. `code: command not found`またはVS CodeがWindows側directoryを開く

Visual Studio CodeはWindowsへインストールし、Microsoft WSL extensionを使います。Ubuntu内へLinux版VS Codeをaptで入れません。

Windows PowerShell：

```powershell
winget install --id Microsoft.VisualStudioCode -e
```

Windows版VS CodeでMicrosoftの `WSL` extensionを入れ、Ubuntuを開き直します。

```bash
code --version
setup-vscode
cd ~/src/<Project>
code .
```

VS Code左下にWSL接続が表示され、terminalのpromptが `/home/<user>/src/<Project>` を指していることを確認します。

## 45. CodexまたはClaude Codeの利用上限に達した

障害ではありません。現在のagentを停止し、同じworktreeのまま次を実行します。

```bash
git status --short
git diff --stat
```

`handoffs/CURRENT.md`を更新し、もう一方を起動します。

```bash
claude
# または
codex
```

新しいagentには、最初に `PROJECT.md`、`handoffs/CURRENT.md`、`git status`、`git diff`を読ませます。別worktreeを新規作成する必要はありません。

---

# Part XI. 提供コマンド一覧

| コマンド | 用途 |
|---|---|
| `new-project` | 新規project repositoryを作成 |
| `new-worktree` | sharedまたはagent別のbranchとworktreeを作成 |
| `remove-worktree` | worktreeを安全に削除 |
| `setup-project-links` | `.local`のdata / scratch / output linkを生成 |
| `research-doctor` | WSL2、GitHub、Dropbox、Agent環境を点検 |
| `install-coding-agents` | CodexとClaude Codeを公式installerで導入 |
| `setup-vscode` | VS Codeの公式WSL、Codex、Claude Code、解析extensionを導入 |
| `install-miniforge` | WSL2内へMiniforgeを導入 |
| `analysis-smoke-test` | projectのGit、data link、scratch、Python/Rを確認 |

各commandのhelp：

```bash
new-project --help
new-worktree --help
remove-worktree --help
install-miniforge --help
install-coding-agents --help
setup-vscode --help
```

---

# Part XII. 重要な注意

## Agentへの指示はOSレベルの完全な隔離ではない

`AGENTS.md`、`CLAUDE.md`、`PROJECT.md`はAgentへの作業規則です。OSのpermissionやcontainerによる完全なsecurity boundaryではありません。

したがって、次を守ります。

- Agentは対象repositoryまたはworktreeから起動する。
- Dropbox rootや `~/src` rootから起動しない。
- 必要な入力だけ `.local/data/` にlinkする。
- secret、token、`.env`をrepositoryへ置かない。
- 入力データを直接変更させない。
- commit、push、merge、rebaseは原則として人間が確認後に行う。
- Agent作業後は必ず `git status` と `git diff` を確認する。
- 利用上限でagentを切り替える場合は同じworktreeを使い、`handoffs/CURRENT.md`を引継ぎに使う。
- 同じworktreeでCodexとClaude Codeを同時稼働させない。

---

# Part XIII. 詳細文書

- [WSL2導入後から最初の解析まで](docs/FROM_WSL_TO_FIRST_ANALYSIS.md)
- [マシン設定](docs/MACHINE_SETUP.md)
- [新規project開始](docs/NEW_PROJECT.md)
- [worktree運用](docs/WORKTREES.md)
- [公式参照先](docs/OFFICIAL_REFERENCES.md)

READMEを標準手順書とし、詳細な背景や補足は `docs/` を参照します。

---

# Official references

- [Microsoft: Working across Windows and Linux file systems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
- [Microsoft: Set up a WSL development environment](https://learn.microsoft.com/en-us/windows/wsl/setup/environment)
- [GitHub CLI: gh auth login](https://cli.github.com/manual/gh_auth_login)
- [GitHub CLI: gh repo create](https://cli.github.com/manual/gh_repo_create)
- [GitHub CLI environment variables](https://cli.github.com/manual/gh_help_environment)
- [Miniforge](https://github.com/conda-forge/miniforge)
- [Microsoft: Developing in WSL with Visual Studio Code](https://code.visualstudio.com/docs/remote/wsl)
- [OpenAI Codex documentation](https://developers.openai.com/codex/)
- [OpenAI Codex VS Code extension](https://marketplace.visualstudio.com/items?itemName=OpenAI.chatgpt)
- [Claude Code documentation](https://code.claude.com/docs/en/setup)
- [Claude Code in VS Code](https://code.claude.com/docs/en/vs-code)
