# macOS導入後から最初の解析まで

この文書は、MacをWindows/WSL2と同じ研究開発環境へ追加するための手順です。

## 1. Apple Command Line Tools

```bash
xcode-select --install
```

installer完了後、Terminalを開き直します。

## 2. infraを取得

GitHub CLIがすでにある場合：

```bash
mkdir -p ~/src
cd ~/src
gh repo clone <GitHubAccount>/research-dev-infra
cd research-dev-infra
```

まだ認証手段がない場合は、GitHubのWeb画面からZIPを取得して `~/src/research-dev-infra` へ展開し、bootstrap後にclone版へ置き換えます。

## 3. Homebrewと基本tool

```bash
bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

VS CodeとDropboxも導入する場合：

```bash
bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス" \
  --desktop-apps
```

```bash
source ~/.zprofile
gh auth login
gh auth setup-git
```

## 4. Dropbox

Dropbox desktop appへログインし、以下がMac上に存在することを確認します。

```text
Dropbox/Research
Dropbox/ForShareLargeData
```

File Provider環境では通常、Dropboxは `~/Library/CloudStorage/Dropbox*` 以下です。

```bash
find "$HOME/Library/CloudStorage" -maxdepth 1 -type d -name 'Dropbox*' -print
```

## 5. machine setup

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
source ~/.zshrc
hash -r
research-doctor
```

自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "$HOME/Library/CloudStorage/<Actual Dropbox Name>"
```

## 6. VS Code

```bash
brew install --cask visual-studio-code
```

VS CodeのCommand Paletteで以下を実行します。

```text
Shell Command: Install 'code' command in PATH
```

```bash
code --version
setup-vscode
```

MacではWSL extensionは不要です。

## 7. Miniforge、Agent、Emacs

```bash
install-miniforge
source ~/.zshrc

install-coding-agents
source ~/.zshrc

setup-agent-defaults
setup-emacs
```

GUI Emacsも必要なら：

```bash
setup-emacs --gui
```

## 8. Login

```bash
codex login
claude
```

API定額プランを使う場合、通常は `OPENAI_API_KEY` と `ANTHROPIC_API_KEY` を設定しません。

## 9. 既存project

```bash
cd ~/src
gh repo clone <GitHubAccount>/Sepsis.Atlas
cd Sepsis.Atlas

setup-project-links
mamba env create -f environment.yml
conda activate sepsis-atlas
analysis-smoke-test Sepsis.Atlas
code .
```

## 10. Mac固有データ

```bash
link_data "/Volumes/ExternalSSD/SepsisAtlas/data" local_data
use_output_dir "/Volumes/ExternalSSD/SepsisAtlas/results/$WORKSPACE_NAME"
```

MacとWSL2で同じbranchを同時編集しません。移動前にcommit/pushし、移動後にpullします。
