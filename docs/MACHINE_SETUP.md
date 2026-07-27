# Machine setup

`setup-machine.sh`はWSL2またはmacOSで共通の開発基盤を設定します。

## Dropbox前提

Dropbox root直下に次が存在する必要があります。

```text
Research
ForShareLargeData
```

scriptは次のAI専用rootを作成します。

```text
Research/aicode/inout
Research/aicode/output
ForShareLargeData/aicode/input
ForShareLargeData/aicode/output
```

## 実行

```bash
cd ~/src/research-dev-infra
bash scripts/setup-machine.sh
```

Dropboxを自動検出できない場合：

```bash
bash scripts/setup-machine.sh --dropbox-home "/actual/path/to/Dropbox"
```

WSL2では`~/.bashrc`、macOSでは`~/.zshrc`を再読込します。

```bash
source ~/.bashrc   # WSL2
# source ~/.zshrc # macOS
hash -r
```

## ~/.research_env

Dropbox全体のrootはexportしません。projectから使用できる共有rootは次だけです。

```text
AICODE_RESEARCH_INOUT_ROOT
AICODE_RESEARCH_OUTPUT_ROOT
AICODE_LARGE_INPUT_ROOT
AICODE_LARGE_OUTPUT_ROOT
SRC_ROOT
WORKTREE_ROOT
SCRATCH_ROOT
```

`~/data-roots`は作成しません。旧版の既知symlinkは安全に削除されます。
