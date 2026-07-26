# Machine setup

`research-dev-infra`はUbuntu on WSL2とmacOSを同じ論理構成で扱います。

詳細手順：

- WSL2: [WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md)
- macOS: [Macセットアップ](MAC_SETUP.md)

## 前提

共通：

- GitHub account
- Dropbox account
- Dropbox root直下に `Research` と `ForShareLargeData`
- Git repositoryはDropbox外の `~/src/`

WSL2：

- Windows 11
- WSL2 Ubuntu
- Windows版DropboxとVisual Studio Code

macOS：

- macOS 13以降を推奨
- Apple Command Line Tools
- Homebrew
- Mac版DropboxとVisual Studio Code

## 初期bootstrap

WSL2：

```bash
bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

macOS：

```bash
xcode-select --install

bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHubに登録しているメールアドレス"
```

VS CodeとDropboxもHomebrewから導入する場合：

```bash
bash scripts/bootstrap-macos.sh --desktop-apps
```

## 共通machine setup

```bash
bash scripts/setup-machine.sh
```

WSL2では通常、Windows userと `C:\Users\<user>\Dropbox` を自動検出します。

macOSでは通常、`~/Library/CloudStorage/Dropbox*` を探索し、`Research`と`ForShareLargeData`の両方を持つrootを自動検出します。

自動検出できない場合：

```bash
bash scripts/setup-machine.sh --dropbox-home "/actual/path/to/Dropbox"
```

Shell設定を再読込します。

```bash
# WSL2
source ~/.bashrc

# macOS
source ~/.zshrc
```

実行内容：

1. `~/src`、`~/worktrees`、`~/scratch`、`~/data-roots`を作成
2. Dropboxの2ルートを `~/data-roots/` へsymlink
3. `~/.research_env`を生成
4. WSL2では `~/.bashrc`、macOSでは `~/.zshrc`から読み込む設定を追加
5. `~/.local/bin`へ共通commandを登録

## project固有のローカルデータ

machine全体の `LOCAL_ROOT` は定義しません。必要なprojectだけ `scripts/setup-local-links.sh` に追加します。

```bash
# Dropbox共通論理root
link_data "$RESEARCH_ROOT/Papers/ProteomicAging" papers
link_data "$LARGE_ROOT/Proteomics/PublicData" public_data

# WSL2固有例
link_data "/mnt/e/ProteomicAging/raw" raw
use_output_dir "/mnt/e/ProteomicAging/results/$WORKSPACE_NAME"

# macOS固有例
link_data "/Volumes/ExternalSSD/ProteomicAging/raw" raw
use_output_dir "/Volumes/ExternalSSD/ProteomicAging/results/$WORKSPACE_NAME"
```

## Agentとeditor

```bash
install-coding-agents
setup-agent-defaults
setup-vscode
setup-emacs
```

標準Agent設定：

```text
Codex       gpt-5.6 / xhigh
Codex Plan  gpt-5.6 / xhigh
Claude Code stable channel / opus / xhigh
```

## 診断

```bash
research-doctor
research-doctor Sepsis.Atlas
```

`Failures: 0`なら共通基盤は利用可能です。未導入の任意ツールはwarningとして表示されます。
