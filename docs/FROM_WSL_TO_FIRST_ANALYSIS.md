# WSL2導入後から最初の解析まで

この文書は、Windows 11上のWSL2 Ubuntuを、`research-dev-infra`を使って研究開発端末へ設定する手順です。共通方針と日常運用はrepository rootの[README](../README.md)を正本とします。

前提：

- codeはWSL2の`~/src/<Project>`へ置く。
- Dropboxの既存構造は変更しない。
- 必要なデータだけprojectの`.local/data/`へlinkする。
- VS Codeを標準UIとし、Codex／Claude Code extensionを使う。
- 長いtaskはtask worktreeとGitHub branchで管理する。

## 1. WindowsとWSL2を確認する

PowerShell：

```powershell
wsl --status
wsl --list --verbose
wsl --update
```

Ubuntuがversion 2であることを確認します。

Windows側のDropboxに次が存在することを確認します。

```text
C:\Users\<WindowsUser>\Dropbox\Research
C:\Users\<WindowsUser>\Dropbox\ForShareLargeData
```

解析に使うDropbox fileは、必要に応じてWindows側でローカル保存状態にします。

## 2. infraを取得する

GitHub CLIと認証がすでに使える場合：

```bash
mkdir -p ~/src
cd ~/src
gh repo clone hase62/research-dev-infra
cd research-dev-infra
```

まだGitHub CLIを使えない場合は、GitHubのWeb画面からZIPを取得し、`~/src/research-dev-infra`へ展開します。bootstrapとGitHub認証後に、ZIP版をGit clone版へ置き換えます。

Ubuntu初期状態で`unzip`がない場合：

```bash
sudo apt-get update
sudo apt-get install -y unzip
```

## 3. Ubuntu基本toolを導入する

```bash
cd ~/src/research-dev-infra

bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

確認時は`BOOTSTRAP`と入力します。

## 4. GitHubへログインする

```bash
gh auth login
gh auth setup-git
gh auth status
```

通常は`GitHub.com`、`HTTPS`、browser loginを選びます。

ZIPから開始した場合は、認証後にclone版へ置き換えます。

```bash
cd ~/src
mv research-dev-infra research-dev-infra-from-zip
gh repo clone hase62/research-dev-infra
cd research-dev-infra
```

clone版の確認後、ZIP版を削除します。

## 5. Dropbox rootと共通commandを設定する

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.bashrc
hash -r
```

Dropboxを自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "/mnt/c/Users/<WindowsUser>/Dropbox"
```

確認：

```bash
ls -ld ~/data-roots/Research
ls -ld ~/data-roots/ForShareLargeData
command -v new-project
command -v new-worktree
research-doctor
```

## 6. VS Codeを設定する

Windows側のVS Codeを最新版へ更新してから、Ubuntuで実行します。

```bash
setup-vscode
```

projectはUbuntu terminalから開きます。

```bash
cd ~/src/research-dev-infra
code .
```

左下に`WSL: Ubuntu`などが表示されることを確認します。Windows側から`\\wsl$`経由で直接編集するのではなく、Remote WSLとして開きます。

## 7. Miniforge、Codex、Claude Code、Emacs

```bash
install-miniforge
source ~/.bashrc

install-coding-agents
source ~/.bashrc

setup-agent-defaults
setup-emacs
```

確認：

```bash
conda --version
mamba --version
codex --version
claude --version
emacs --version
```

CodexとClaude Codeへ端末ごとにログインします。

```bash
codex login
claude
```

credentialやAgent設定directory全体をDropboxで同期しません。

## 8. 既存projectを再開する

```bash
cd ~/src
gh repo clone hase62/Sepsis.Atlas
cd Sepsis.Atlas

setup-project-links
research-doctor Sepsis.Atlas
```

`environment.yml`がある場合：

```bash
mamba env create -f environment.yml
conda activate sepsis-atlas
analysis-smoke-test Sepsis.Atlas
```

すでにclone済みなら：

```bash
cd ~/src/Sepsis.Atlas
git pull --rebase
setup-project-links
```

## 9. 新規projectを作る

```bash
new-project NewProject --github
cd ~/src/NewProject
```

次を編集します。

```text
PROJECT.md
scripts/setup-local-links.sh
```

linkを反映します。

```bash
setup-project-links
research-doctor NewProject
```

詳細は[新規project開始](NEW_PROJECT.md)を参照してください。

## 10. 解析環境を作る

例：

```bash
mamba create -n new-project \
  -c conda-forge -c bioconda \
  python=3.12 pip jupyterlab numpy pandas scipy matplotlib \
  r-base r-irkernel r-data.table

conda activate new-project
conda env export --from-history > environment.yml
analysis-smoke-test NewProject
```

projectごとに必要なpackageだけを追加します。Windows側のConda環境はWSL2へ共有しません。

## 11. VS CodeでAgent作業を始める

小さな作業：

```bash
cd ~/src/NewProject
code .
```

VS CodeのCodexまたはClaude Code extensionを開始します。CLIを使う場合だけintegrated terminalで`codex`または`claude`を起動します。

長いtask：

```bash
cd ~/src/NewProject
git switch main
git pull --rebase
new-worktree NewProject shared metadata-audit
cd ~/worktrees/NewProject/shared-metadata-audit
code .
```

worktreeの命名、別PCでの再開、task完了後の削除は[worktree運用](WORKTREES.md)を参照してください。

## 12. 端末を移る前

```bash
git status
git diff
# handoffs/CURRENT.mdを更新
git add -p
git commit -m "WIP: checkpoint current task"
git push
```

別PCでは同じtask名で`new-worktree`を実行し、GitHub上のtask branchからlocal worktreeを再構築します。未commit変更、`.local`、conda環境、`~/scratch`、Agent chat sessionは移動しません。
