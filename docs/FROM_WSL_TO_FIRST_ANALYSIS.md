# WSL2から最初の解析まで

## 1. infra取得

```bash
mkdir -p ~/src
cd ~/src
gh repo clone hase62/research-dev-infra
cd research-dev-infra
```

## 2. 基本tool

```bash
bash scripts/bootstrap-ubuntu.sh \
  --git-name "Takanori Hasegawa" \
  --git-email "GitHub登録メールアドレス"
```

## 3. machine setup

```bash
bash scripts/setup-machine.sh
source ~/.bashrc
hash -r
```

Dropboxの自動検出に失敗する場合：

```bash
bash scripts/setup-machine.sh \
  --dropbox-home "/mnt/c/Users/<WindowsUser>/Dropbox"
```

確認：

```bash
printf '%s\n' \
  "$AICODE_RESEARCH_INPUT_ROOT" \
  "$AICODE_RESEARCH_OUTPUT_ROOT" \
  "$AICODE_LARGE_INPUT_ROOT" \
  "$AICODE_LARGE_OUTPUT_ROOT"
research-doctor
```

## 4. Agentと解析環境

```bash
setup-vscode
install-coding-agents
setup-agent-defaults
install-miniforge
source ~/.bashrc
```

## 5. project

新規project：

```bash
new-project ExampleProject --github
cd ~/src/ExampleProject
setup-workspace
code .
```

既存project：

```bash
cd ~/src
gh repo clone hase62/ExampleProject
cd ExampleProject
setup-workspace
code .
```

必要なdataはproject専用の4つのDropbox directoryへコピーします。AgentにDropbox rootを探索させません。
