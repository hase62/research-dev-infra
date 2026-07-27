# macOS setup

macOSではWSL2を使わず、`~/src`で同じGitHub repositoryとDropbox project領域を利用します。

## 1. 基本tool

```bash
xcode-select --install
```

Homebrew導入後：

```bash
cd ~/src/research-dev-infra
bash scripts/bootstrap-macos.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHub登録メールアドレス"
```

## 2. Dropboxとcommand

Dropbox File Providerの実rootを自動検出します。

```bash
bash scripts/setup-machine.sh
source ~/.zshrc
hash -r
```

自動検出できない場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "$HOME/Library/CloudStorage/<Dropbox名>"
```

共有対象は次の4 rootだけです。

```text
Research/aicode/input
Research/aicode/output
ForShareLargeData/aicode/input
ForShareLargeData/aicode/output
```

## 3. tool導入

```bash
setup-vscode
install-miniforge
install-coding-agents
setup-agent-defaults
setup-emacs
```

## 4. project再開

```bash
cd ~/src
gh repo clone hase62/ExampleProject
cd ExampleProject
setup-workspace
code .
```

Mac実機での最終動作確認は、初回利用時に`research-doctor`と`analysis-smoke-test`で行います。
