# Troubleshooting

READMEの標準手順で解決しない場合に参照します。

## 最初に確認すること

```bash
pwd
git remote -v
git branch --show-current
git status
research-doctor
```

別repositoryでコマンドを実行していないか、未commit変更が残っていないかを最初に確認します。

---

## `command not found: new-project` など

`setup-machine.sh`がまだ実行されていないか、Shellを再読込していません。

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
```

```bash
# WSL2
source ~/.bashrc

# macOS
source ~/.zshrc
```

```bash
hash -r
command -v new-project
command -v setup-vscode
```

infra更新後に新しいcommandが増えた場合も、`setup-machine.sh`を再実行します。

---

## Dropbox directory was not found

### WSL2

```bash
ls -ld "/mnt/c/Users/<WindowsUser>/Dropbox/Research"
ls -ld "/mnt/c/Users/<WindowsUser>/Dropbox/ForShareLargeData"
```

実際のDropbox rootを指定します。

```bash
bash ~/src/research-dev-infra/scripts/setup-machine.sh \
  --dropbox-home "/mnt/c/Users/<WindowsUser>/Dropbox"
```

### macOS

```bash
find "$HOME/Library/CloudStorage" \
  -maxdepth 1 \
  -type d \
  -name 'Dropbox*' \
  -print
```

```bash
bash ~/src/research-dev-infra/scripts/setup-machine.sh \
  --dropbox-home "$HOME/Library/CloudStorage/<実際のDropbox名>"
```

指定するrootの直下に `Research` と `ForShareLargeData` が必要です。

---

## Dropbox fileが見えるが読めない

macOS File ProviderやDropboxのonline-only fileで起こります。FinderまたはDropbox appで対象directoryをoffline利用可能にし、download完了後に再実行します。

大規模解析の入力は、処理開始前にlocalへ完全downloadされていることを確認してください。

---

## GitHub認証が失敗する

```bash
gh auth status
```

古い環境変数が保存済み認証を上書きしていないか確認します。

```bash
env | grep -E '^(GH_TOKEN|GITHUB_TOKEN)='
```

現在のShellから外す場合：

```bash
unset GH_TOKEN
unset GITHUB_TOKEN
```

再ログイン：

```bash
gh auth logout
gh auth login
gh auth setup-git
gh auth status
```

### `Resource not accessible by personal access token (createRepository)`

古いtokenの権限不足が典型です。上記の環境変数を解除し、browser loginで認証し直します。

---

## `git pull --rebase`が未commit変更で止まる

```text
error: cannot pull with rebase: You have unstaged changes
```

変更を確認します。

```bash
git status
git diff
```

残す変更ならcommitします。

```bash
git add -p
git commit -m "Describe local changes"
git pull --rebase
```

一時退避する場合：

```bash
git stash push -u -m "temporary before pull"
git pull --rebase
git stash pop
```

---

## `pathspec ... did not match any files`

別repositoryで `git add` している可能性があります。

```bash
pwd
git remote get-url origin
git branch --show-current
git status
```

目的のrepositoryへ移動してから実行します。

```bash
cd ~/src/research-dev-infra
```

---

## pushがrejectされた

remoteが先に進んでいる場合：

```bash
git pull --rebase origin main
git push
```

未確認のforce pushは行いません。

---

## `gh repo view --web`でbrowserが開かない

WSL2側にbrowser openerがない場合があります。repository URLをWindows側で開きます。

```bash
explorer.exe "https://github.com/hase62/research-dev-infra"
```

GitやGitHub認証の失敗ではありません。

---

## `code: command not found`

### WSL2

WindowsへVS Codeを導入し、Remote - WSL extensionを有効にします。Ubuntu terminalを開き直して確認します。

```bash
code --version
```

### macOS

VS CodeのCommand Paletteで次を実行します。

```text
Shell Command: Install 'code' command in PATH
```

新しいTerminalで確認します。

```bash
code --version
```

---

## VS Code extensionがversion非互換になる

VS Code本体を更新します。

### Windows

```powershell
winget upgrade --id Microsoft.VisualStudioCode -e
wsl --shutdown
```

Ubuntuを開き直します。

```bash
code --version
setup-vscode
```

### macOS

```bash
brew upgrade --cask visual-studio-code
code --version
setup-vscode
```

古いVS CodeではCodex、Claude Code、Python、Jupyter、R extensionの最新版が入らないことがあります。

---

## `claude: command not found`

```bash
install-coding-agents
```

Shellを再読込します。

```bash
# WSL2
source ~/.bashrc

# macOS
source ~/.zshrc
```

```bash
command -v claude
claude --version
```

---

## Claude Codeで期待したOpusが表示されない

このinfraはstable channelを標準にしています。

```json
{
  "autoUpdatesChannel": "stable",
  "model": "opus",
  "effortLevel": "xhigh"
}
```

`opus` aliasが解決されるmodelは、installed Claude Code version、stable channel、契約で利用可能なmodelに依存します。特定のmajor versionへ固定せず、新規sessionで実際のmodelを確認します。

```bash
claude update
claude --version
```

Claude Code内：

```text
/status
/model
/effort
```

---

## Codexをinstallした直後にpromptへ戻る

installerをpipe実行中にCodexを起動すると、標準入力がEOFとなり終了する場合があります。install失敗とは限りません。

新しいShellから直接実行します。

```bash
codex --version
codex
```

Claude Codeが未導入なら、再度次を実行します。

```bash
install-coding-agents
```

---

## modelまたはeffortが標準設定と違う

```bash
setup-agent-defaults
research-doctor
```

確認：

```bash
grep -E \
  '^(model|model_reasoning_effort|plan_mode_reasoning_effort)' \
  ~/.codex/config.toml
```

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / ".claude" / "settings.json"
data = json.loads(path.read_text())
for key in ("autoUpdatesChannel", "model", "effortLevel"):
    print(f"{key}: {data.get(key)}")
PY
```

環境変数が上書きしていないか確認します。

```bash
env | grep -E '^(ANTHROPIC_MODEL|CLAUDE_CODE_EFFORT_LEVEL|OPENAI_API_KEY|ANTHROPIC_API_KEY)='
```

---

## CodexまたはClaude Codeの利用上限に達した

同じworktreeで実行中のAgentを停止し、`handoffs/CURRENT.md`へ現状を書いてからもう一方へ切り替えます。

```bash
git status
git diff
```

Codexを停止したら同じVS Code windowでClaude Code extensionを開始し、Claude Codeを停止したらCodex extensionを開始します。CLIを使っている場合だけ、同じworktreeのterminalで`claude`または`codex`を起動します。

両方へ同時に編集指示を出しません。chat履歴は自動移行されないため、`handoffs/CURRENT.md`、commit、`git diff`を引継ぎの正本にします。

---

## `new-worktree`がmainの未commit変更を理由に止まる

main working treeを確認します。

```bash
PROJECT="Sepsis.Atlas"
cd "$HOME/src/$PROJECT"
git status
git diff
```

変更をcommitまたはstashしてcleanにしてから再実行します。

```bash
PROJECT="Sepsis.Atlas"
TASK="metadata-audit"
new-worktree "$PROJECT" shared "$TASK"
```

---

## worktreeを削除できない

未commit変更がある場合は安全のため削除されません。

```bash
PROJECT="Sepsis.Atlas"
WORKSPACE="shared-metadata-audit"
cd "$WORKTREE_ROOT/$PROJECT/$WORKSPACE"
git status
git diff
```

変更をcommit、退避、または明示的に破棄してから `remove-worktree` を実行します。


---

## `new-worktree`がlocal/remote divergenceを警告する

同じtask branchを複数PCで並行編集した可能性があります。scriptは自動mergeしません。

```bash
PROJECT="Sepsis.Atlas"
TASK="metadata-audit"
cd "$WORKTREE_ROOT/$PROJECT/shared-$TASK"
git status
git branch -vv
git log --oneline --graph --decorate --all -20
```

両方の変更が必要なら履歴を確認してrebaseまたはmergeします。不明な状態でforce pushしません。

---

## `remove-worktree --delete-branch`でbranchが残る

worktree自体は削除済みでも、Gitがbranchをmerge済みと判断しない場合があります。squash mergeで起きることがあります。

GitHubのPRがmerge済みで、mainに必要な変更が入っていることを確認してからlocal branchを削除します。

```bash
TASK="metadata-audit"
git branch -D "work/$TASK"
```

remote branchが残っていれば、merge確認後に削除します。

```bash
TASK="metadata-audit"
git push origin --delete "work/$TASK"
```

確認せずに`-D`やremote branch削除を実行しません。
---

## `analysis-smoke-test`でRだけwarningになる

Rを使わないprojectなら問題ありません。Rを使用する場合はproject環境へ追加します。

```bash
mamba install -n sepsis-atlas -c conda-forge r-base r-irkernel
```

---

## 大きなfileをGitへ追加してしまった

push前ならstageから外します。

```bash
git restore --staged path/to/file
```

`.gitignore`へ追加します。複数PCで必要なfileや永続成果物はDropboxへ移し、共有不要かつ再生成可能なcacheだけをlocal diskへ残します。

一度Git履歴へcommitした大容量fileの削除は履歴書換えを伴うため、push前後の状態を確認して個別に対応します。

---

## MacでLinux用environmentが解決できない

完全なLinux環境exportはOSやCPU architecture固有packageを含むことがあります。原則として次を使用します。

```bash
conda env export --from-history > environment.yml
```

必要なら次へ分けます。

```text
environment.yml
environment-linux.yml
environment-macos.yml
```

GPU/CUDA依存環境はMacへ再現せず、HPCまたはGPU端末へ残します。

---

## workspace linkがない／古いpathを指す

projectまたはworktree rootで再構築します。

```bash
setup-workspace
find workspace -maxdepth 1 -type l -print -exec readlink {} \;
```

正常なlink名は次の5つだけです。

```text
research-input
research-output
large-input
large-output
scratch
```

旧式の可変data/output linkや任意のDropbox subpath linkが残っている場合は、新しいproject templateへ移行できていません。

## AgentがDropbox全体を探索しようとする

Agentはproject rootまたはworktree rootから起動し、`PROJECT.md`、`AGENTS.md`または`CLAUDE.md`を読ませます。使用可能なDropbox pathは4つの固定workspace linkだけです。必要なdataを該当project directoryへ先にコピーし、Dropbox rootや他projectを探索させません。
