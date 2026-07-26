# macOS導入後から最初の解析まで

この文書は、macOSを`research-dev-infra`で研究開発端末へ設定する手順です。Windows/WSL2端末の有無に関係なく、同じGitHub repositoryとDropbox data rootを利用できます。

## 1. Apple Command Line Tools

```bash
xcode-select --install
```

installer完了後、Terminalを開き直します。

## 2. infraを取得

GitHub CLIがすでにある場合：

```bash
GITHUB_ACCOUNT="hase62"
mkdir -p ~/src
cd ~/src
gh repo clone "$GITHUB_ACCOUNT/research-dev-infra"
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
GITHUB_ACCOUNT="hase62"
cd ~/src
gh repo clone "$GITHUB_ACCOUNT/Sepsis.Atlas"
cd Sepsis.Atlas

setup-workspace
mamba env create -f environment.yml
conda activate sepsis-atlas
analysis-smoke-test Sepsis.Atlas
code .
```

## 10. Mac固有の例外path

通常のdataと永続outputはDropboxの共通rootを使うため、Mac固有pathは不要です。

```bash
link_data "$LARGE_ROOT/Sepsis/processed" processed
use_output_dir "$LARGE_ROOT/Sepsis/results/$WORKSPACE_NAME"
```

外付けSSDを使うのは、共有不要かつ再生成可能なcacheや、計算用replicaに限る例外です。必要な場合は`~/.research_env`へ環境変数を設定し、tracked scriptへMac固有の絶対pathを直書きしません。

```bash
# ~/.research_env
export SEPSIS_LOCAL_CACHE_ROOT="/Volumes/ExternalSSD/SepsisAtlas/cache"

# scripts/configure-workspace.sh
if [[ -n "${SEPSIS_LOCAL_CACHE_ROOT:-}" ]]; then
  link_data "$SEPSIS_LOCAL_CACHE_ROOT" local_cache
fi
```

別PCで進行中taskを続ける場合は、code・Markdown指示・handoffをcheckpoint commitとしてGitHubへpushし、大きな中間・最終outputをDropboxへ保存します。移動先では同じtask名の`new-worktree`を実行します。worktree folder自体はPC間で同期しません。詳細は[worktree運用](WORKTREES.md)を参照してください。
