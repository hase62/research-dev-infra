# 新しいPCのセットアップ

詳細な初回手順は [WSL2導入後から最初の解析まで](FROM_WSL_TO_FIRST_ANALYSIS.md) を先に参照してください。

## 前提

- Windows 11とWSL2 Ubuntu
- Windows側にDropbox desktop applicationが導入済み
- Dropbox内に以下が存在する
  - `Research`
  - `ForShareLargeData`
- WSL2内にGitとGitHub CLIが導入済み（未導入なら `scripts/bootstrap-ubuntu.sh` を使用）

## 手順

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/<YOUR_ACCOUNT>/research-dev-infra.git
cd research-dev-infra
bash scripts/setup-machine.sh
source ~/.bashrc
research-doctor
```

`setup-machine.sh`は次だけを行います。

1. `~/src`、`~/worktrees`、`~/scratch`、`~/data-roots`を作成
2. Dropboxの `Research` と `ForShareLargeData` へのsymlinkを作成
3. `~/.research_env`を作成
4. `~/.bashrc`から `~/.research_env`を読み込む設定を追加
5. 共通コマンドを `~/.local/bin` に登録

PC全体で共通の `D:\ResearchLocal` のような大容量ルートは作りません。ローカルSSDや外付けディスクが必要な研究だけ、各projectの `scripts/setup-local-links.sh` で任意の実パスを直接linkします。

例：

```bash
link_data "/mnt/e/ProteomicAging/raw" raw
use_output_dir "/mnt/e/ProteomicAging/results/$WORKSPACE_NAME"
```

## CodexとClaude Code

```bash
install-coding-agents
```

導入後に各コマンドを起動し、各PCでログインします。

```bash
codex
claude
```

認証ディレクトリをDropboxやGitHubで同期しないでください。

## Miniforge

```bash
install-miniforge
source ~/.bashrc
```

研究ごとに独立したConda/Mamba環境を作り、base環境へ解析packageを追加しないでください。

## 最初の解析確認

projectを作成してdata linkと解析環境を準備した後：

```bash
analysis-smoke-test <ProjectName>
```

## Optional editor and research-grade agent defaults

After `setup-machine.sh` has registered commands:

```bash
setup-agent-defaults
setup-emacs
```

The standard agent defaults are Codex `gpt-5.6` with xhigh reasoning and Claude
Code `claude-opus-5` with xhigh effort. `setup-emacs` installs terminal Emacs for WSL2.
