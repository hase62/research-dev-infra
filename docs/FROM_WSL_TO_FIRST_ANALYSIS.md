# WSL2導入後から最初の解析まで

この文書は、WSL2とUbuntuをインストールした直後から、GitHub、Dropbox、Miniforge、Codex、Claude Codeを準備し、最初の研究repositoryで解析を実行するまでの一本道です。

Macを設定する場合は [Macセットアップ](MAC_SETUP.md) を参照してください。

構成は次を前提とします。

- コードはWSL2内の `~/src/<Project>` に置く
- GitHub repositoryは研究プロジェクトごとに分ける
- Dropboxの既存構造は変更しない
- 必要なDropboxディレクトリだけをprojectの `.local/data/` にsymlinkする
- 大規模なPC固有データは、必要なprojectだけ任意のローカルパスから参照する
- CodexとClaude Codeはproject rootまたはworktreeから起動する

---

## 0. Windows側で確認する

PowerShellで次を実行します。

```powershell
wsl --status
wsl --list --verbose
wsl --update
```

UbuntuのVERSIONが2であることを確認します。

Dropbox desktop applicationもWindows側で起動し、次のディレクトリが実在することを確認します。

```text
C:\Users\<WindowsUser>\Dropbox\Research
C:\Users\<WindowsUser>\Dropbox\ForShareLargeData
```

解析で使用するDropboxファイルは、必要に応じてWindows側でローカル保存状態にします。オンラインのみのまま大量解析を始めないでください。

---

## 1. Ubuntuを開き、Linuxホームを確認する

Ubuntu terminalを開きます。

```bash
whoami
pwd
uname -a
```

通常、作業場所は次です。

```text
/home/<LinuxUser>
```

コードは `/mnt/c/...` ではなくLinuxホーム以下に置きます。

---

## 2. 初回だけ：infra ZIPをWSLへ展開する

このinfra repositoryがまだGitHubにない最初のPCでは、配布ZIPをWindowsのDownloadsなどに保存してから展開します。

Ubuntu初期状態で `unzip` がない場合だけ、先に導入します。

```bash
sudo apt-get update
sudo apt-get install -y unzip
```

その後、ZIPを展開します。

```bash
mkdir -p ~/src
cd ~/src

unzip "/mnt/c/Users/<WindowsUser>/Downloads/research-dev-infra.zip"
cd research-dev-infra
```

ZIPの置き場所が異なる場合はパスを変更してください。

すでにinfraをGitHubへpush済みの2台目以降では、「12. 2台目以降のPC」を参照します。

---

## 3. Ubuntuの基本ツールとGitHub CLIを導入する

Gitで使用する表示名とメールアドレスを指定します。

```bash
bash scripts/bootstrap-ubuntu.sh \
  --git-name "Your Name" \
  --git-email "your-address@example.com"
```

このscriptはGit、curl、unzip、rsync、build-essential、GitHub CLIなどを導入し、次のGit設定を行います。

```text
init.defaultBranch=main
core.autocrlf=input
pull.rebase=true
fetch.prune=true
push.autoSetupRemote=true
```

確認します。

```bash
git --version
gh --version
git config --global --list
```

### GitHubへログイン

```bash
gh auth login
```

通常は次を選択します。

```text
GitHub.com
HTTPS
Login with a web browser
```

認証確認：

```bash
gh auth status
gh config set git_protocol https
```

HTTPSを標準にすると、PCごとのSSH鍵準備なしで開始できます。HPCなどSSHが適する環境では後からSSHへ切り替えて構いません。

---

## 4. infra自体をprivate GitHub repositoryへ登録する

最初のPCだけで実行します。

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

確認：

```bash
git remote -v
git status
gh repo view --web
```

以後、このrepositoryが新しいPCの共通セットアップ元になります。

---

## 5. Dropboxの共通参照ルートを接続する

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.bashrc
```

確認：

```bash
research-doctor
ls -la ~/data-roots
```

期待されるリンク：

```text
~/data-roots/Research
  -> /mnt/c/Users/<WindowsUser>/Dropbox/Research

~/data-roots/ForShareLargeData
  -> /mnt/c/Users/<WindowsUser>/Dropbox/ForShareLargeData
```

この段階ではDドライブや外付けSSDを登録しません。大規模ローカルデータが必要なprojectだけ、後で `scripts/setup-local-links.sh` に任意の実パスを記載します。

---

## 6. Miniforgeを導入する

解析環境はWindows側のCondaとは分離し、WSL2内にMiniforgeを導入します。

```bash
install-miniforge
source ~/.bashrc
```

確認：

```bash
conda --version
mamba --version
conda config --show auto_activate_base
```

`auto_activate_base: false`になっていることを確認します。project packageをbaseへ入れず、研究ごとに環境を作ります。

---

## 7. CodexとClaude Codeを導入する

```bash
install-coding-agents
source ~/.bashrc
```

確認：

```bash
codex --version
claude --version
```

各PCで個別にログインします。

```bash
codex
claude
```

認証情報やホームディレクトリ下のAgent設定全体をDropboxで同期しません。

---

## 8. 任意：VS CodeをWSLへ接続する

Windows側にVS CodeとWSL extensionを導入した後、Ubuntuでproject directoryから実行します。

```bash
cd ~/src/research-dev-infra
code .
```

画面左下がWSL接続になっていることを確認します。Windows側から `\\wsl$` 経由で直接編集するのではなく、Remote WSLとして開きます。

Dockerは必要なprojectで後から導入します。最初の解析開始には必須ではありません。

---

## 9. 最初の研究projectを作る

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

まず研究概要を数行書きます。

```bash
nano PROJECT.md
```

例：

```markdown
# ProteomicAging

## Goal

細胞種別プロテオミクスを用いて加齢関連変化を解析する。

## Current phase

公開データの取得と再現解析。
```

---

## 10. 必要なDropboxまたはローカルデータだけを接続する

```bash
nano scripts/setup-local-links.sh
```

末尾に必要なリンクだけ追加します。

```bash
link_data "$RESEARCH_ROOT/Papers/Aging/Proteomics" papers
link_data "$LARGE_ROOT/Proteomics/PublicData" public_data
link_data "/mnt/e/ProteomicAging/large_objects" large_objects

# 必要なprojectだけoutputも外部ディスクへ変更
use_output_dir "/mnt/e/ProteomicAging/results/$WORKSPACE_NAME"
```

反映：

```bash
setup-project-links
research-doctor ProteomicAging
```

確認：

```bash
find .local -maxdepth 2 -type l -print -exec readlink {} \;
```

CodexとClaude CodeにはDropboxルート全体ではなく、`.local/data/`に公開した場所だけを利用させます。

---

## 11. project専用の解析環境を作る

### Python中心の例

```bash
mamba create -n proteomic-aging \
  -c conda-forge \
  python=3.12 \
  pip \
  jupyterlab \
  ipykernel \
  numpy \
  pandas \
  scipy \
  matplotlib

conda activate proteomic-aging
```

### R中心の例

```bash
mamba create -n proteomic-aging-r \
  -c conda-forge \
  -c bioconda \
  r-base \
  r-irkernel \
  r-data.table \
  r-tidyverse

conda activate proteomic-aging-r
```

### RとPythonを同じ環境で使う例

```bash
mamba create -n proteomic-aging \
  -c conda-forge \
  -c bioconda \
  python=3.12 \
  pip \
  jupyterlab \
  numpy \
  pandas \
  r-base \
  r-irkernel \
  r-data.table

conda activate proteomic-aging
```

本格的なprojectでは、環境が固まった段階で次のどちらかをGit管理します。

```bash
conda env export --from-history > environment.yml
```

または、より厳密に再現する場合：

```bash
conda env export > environment.lock.yml
```

最初から巨大な環境定義を作る必要はありません。

---

## 12. 最初の解析を実行する

Python例：

```bash
mkdir -p analysis
cat > analysis/hello_analysis.py <<'PY'
from pathlib import Path
import pandas as pd

out = Path(".local/output/hello_analysis.tsv")
out.parent.mkdir(parents=True, exist_ok=True)

result = pd.DataFrame(
    {"status": ["ok"], "message": ["WSL2 analysis environment is ready"]}
)
result.to_csv(out, sep="\t", index=False)
print(result)
print(f"written: {out}")
PY

python analysis/hello_analysis.py
```

R例：

```bash
cat > analysis/hello_analysis.R <<'RS'
out <- ".local/output/hello_analysis_R.tsv"
result <- data.frame(
  status = "ok",
  message = "WSL2 R environment is ready"
)
write.table(result, out, sep = "\t", row.names = FALSE, quote = FALSE)
print(result)
cat("written:", out, "\n")
RS

Rscript analysis/hello_analysis.R
```

infraのsmoke testも実行します。

```bash
analysis-smoke-test ProteomicAging
```

問題がなければコードと環境定義だけcommitします。`.local/`以下のデータや出力はcommitされません。

```bash
git status
git add PROJECT.md scripts/setup-local-links.sh analysis environment.yml
git commit -m "Add initial analysis environment and smoke test"
git push
```

`environment.yml`をまだ作っていない場合は、その引数を外してください。

---

## 13. CodexまたはClaude Codeで作業を開始する

単独の小さな作業ならmain repositoryから開始できます。

```bash
cd ~/src/ProteomicAging
conda activate proteomic-aging
codex
```

または：

```bash
cd ~/src/ProteomicAging
conda activate proteomic-aging
claude
```

最初の依頼例：

```text
PROJECT.mdを読み、現在のrepository構造と.local/dataの利用可能な入力を確認してください。
入力データは変更せず、最初のデータinventoryをanalysis/に実装し、結果は.local/outputへ出してください。
commitやpushは行わないでください。
```

並列タスクや独立レビューではworktreeを使います。

```bash
new-worktree ProteomicAging codex task-001-data-inventory
cd ~/worktrees/ProteomicAging/codex-task-001-data-inventory
conda activate proteomic-aging
codex
```

---

## 14. 2台目以降のPC

Ubuntu基本ツールとGitHub CLIを導入し、GitHubへログインした後：

```bash
mkdir -p ~/src
cd ~/src
gh repo clone <GitHubAccount>/research-dev-infra
cd research-dev-infra

bash scripts/setup-machine.sh
source ~/.bashrc
install-miniforge
install-coding-agents
research-doctor
```

既存projectを取得：

```bash
cd ~/src
gh repo clone <GitHubAccount>/ProteomicAging
cd ProteomicAging
setup-project-links
research-doctor ProteomicAging
```

project環境は `environment.yml` があれば再作成します。

```bash
mamba env create -f environment.yml
```

同じbranchの未push変更を複数PCに残さないことが重要です。PCを移る前にcommitとpushを行います。

---

## 15. 日常の開始・終了

### 作業開始

```bash
cd ~/src/ProteomicAging
git fetch --all --prune
git pull --rebase
conda activate proteomic-aging
research-doctor ProteomicAging
```

### 作業終了

```bash
git status
git diff
git add <必要なコードと文書>
git commit -m "Describe the change"
git push
```

Dropboxはデータ参照、GitHubはコード同期です。DropboxをGit repositoryの同期手段にしません。


## Codex installerで起動を選び、Claudeが入らなかった場合

古い `install-agents.sh` ではCodex installerが対話モードで動き、
`Start Codex now?` に `y` と答えると、後続のClaude Code installerへ
到達しないことがありました。Codexが入っていてClaudeだけ未導入なら、次を実行します。

```bash
curl -fsSL https://claude.ai/install.sh | bash -s stable
hash -r
claude --version
```

現在のscriptはCodex installerを `CODEX_NON_INTERACTIVE=1` で実行し、
インストール中にCodexを自動起動しません。
