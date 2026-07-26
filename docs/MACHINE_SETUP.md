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

1. `~/src`、`~/worktrees`、`~/scratch`を作成
2. Dropbox実体のpathを検出
3. `RESEARCH_ROOT`と`LARGE_ROOT`が実体を直接指す`~/.research_env`を生成
4. WSL2では `~/.bashrc`、macOSでは `~/.zshrc`から読み込む設定を追加
5. `~/.local/bin`へ共通commandを登録
6. 旧版の`~/data-roots/`に既知symlinkだけが残っていれば安全に削除

`~/data-roots/`の中継directoryは作りません。Dropboxの場所はOSごとに異なりますが、project側は共通の`RESEARCH_ROOT`と`LARGE_ROOT`だけを使用します。

## projectの共有dataとoutput

machine全体の `LOCAL_ROOT` は定義しません。通常はDropboxの共通論理rootを使い、どのPCでも同じ`scripts/configure-workspace.sh`からlinkを再構築します。

```bash
link_data "$RESEARCH_ROOT/Papers/ProteomicAging" papers
link_data "$LARGE_ROOT/Proteomics/PublicData" public_data
use_output_dir "$LARGE_ROOT/ProteomicAging/results/$WORKSPACE_NAME"
```

PC固有pathは、共有不要かつ再生成可能なcacheなどに限る例外です。その場合もtracked scriptへ絶対pathを直書きせず、`~/.research_env`のproject固有環境変数を使います。

```bash
# ~/.research_env（各PCで必要な場合だけ設定）
export PROTEOMIC_AGING_LOCAL_CACHE_ROOT="/mnt/e/ProteomicAging/cache"  # WSL2例
# export PROTEOMIC_AGING_LOCAL_CACHE_ROOT="/Volumes/ExternalSSD/ProteomicAging/cache"  # macOS例

# scripts/configure-workspace.sh（Git管理）
if [[ -n "${PROTEOMIC_AGING_LOCAL_CACHE_ROOT:-}" ]]; then
  link_data "$PROTEOMIC_AGING_LOCAL_CACHE_ROOT" local_cache
fi
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
