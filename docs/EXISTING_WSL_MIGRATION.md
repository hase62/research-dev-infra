# Existing WSL2 home migration

Use this once after updating `research-dev-infra` to the visible `workspace/`
and direct-Dropbox-root layout.

The migration does not modify project repositories or files under `~/src`.
It updates only the WSL2 home-level configuration:

- `~/.research_env`
- `~/.bashrc`
- `~/worktrees`
- `~/scratch`
- `~/.local/bin`
- the legacy `~/data-roots` symlink directory

## 1. Preview

```bash
cd ~/src/research-dev-infra

bash scripts/migrate-existing-wsl-home.sh \
  --dropbox-root "/mnt/c/Users/<WindowsUser>/Dropbox"
```

The default is dry-run. Review the proposed diffs and cleanup list.

## 2. Apply

```bash
bash scripts/migrate-existing-wsl-home.sh \
  --apply \
  --dropbox-root "/mnt/c/Users/<WindowsUser>/Dropbox"
```

The script creates timestamped backups of `~/.research_env` and `~/.bashrc`
when those files already exist.

## 3. Reload and verify

```bash
source ~/.bashrc
hash -r

printf 'DROPBOX_ROOT=%s\n' "$DROPBOX_ROOT"
printf 'RESEARCH_ROOT=%s\n' "$RESEARCH_ROOT"
printf 'LARGE_ROOT=%s\n' "$LARGE_ROOT"

command -v setup-workspace

test ! -e "$HOME/data-roots" && \
  echo "legacy ~/data-roots removed"
```

If `~/data-roots` contains a real file, a real directory, or an unknown
symlink, the script leaves it untouched and prints a warning. Inspect those
entries manually; do not delete them blindly.
