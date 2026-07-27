# Existing WSL2 home migration

既存WSL2の`~/src`以外を、4つの固定Dropbox root方式へ移行します。

## dry-run

```bash
bash scripts/migrate-existing-wsl-home.sh \
  --dropbox-root "/mnt/c/Users/<WindowsUser>/Dropbox"
```

## apply

```bash
bash scripts/migrate-existing-wsl-home.sh \
  --apply \
  --dropbox-root "/mnt/c/Users/<WindowsUser>/Dropbox"

source ~/.bashrc
hash -r
verify-workspace-migration
```

移行後の確認：

```bash
printf '%s\n' \
  "$AICODE_RESEARCH_INOUT_ROOT" \
  "$AICODE_RESEARCH_OUTPUT_ROOT" \
  "$AICODE_LARGE_INPUT_ROOT" \
  "$AICODE_LARGE_OUTPUT_ROOT"
```

scriptは`~/src`以下を変更しません。旧`~/data-roots`では既知のsymlinkだけを削除し、予期しない実fileやdirectoryは保持します。
