#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
DROPBOX_ROOT_ARG=""
INFRA_ROOT="${HOME}/src/research-dev-infra"
ALLOW_NON_WSL=0

usage() {
  cat <<'EOF'
Usage:
  migrate-existing-wsl-home.sh [--dry-run] [--apply]
                               [--dropbox-root PATH]
                               [--infra-root PATH]
                               [--force-non-wsl]

Purpose:
  Migrate an already configured WSL2 home directory to the current
  research-dev-infra layout without modifying anything under ~/src.

Default behavior is --dry-run.

Changes outside ~/src:
  - Updates ~/.research_env to point directly to Dropbox.
  - Ensures ~/.bashrc loads ~/.research_env and ~/.local/bin.
  - Creates ~/worktrees, ~/scratch, and ~/.local/bin if missing.
  - Removes only known/safe symlinks from the legacy ~/data-roots directory.
  - Removes ~/data-roots itself only when it becomes empty.
  - Refreshes the setup-workspace command symlink when the updated infra
    repository is available.
  - Removes the legacy setup-project-links command only when it is a symlink
    into the specified research-dev-infra repository.

It never modifies project repositories or files under ~/src.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --dropbox-root)
      [[ $# -ge 2 ]] || { echo "ERROR: --dropbox-root requires a path" >&2; exit 2; }
      DROPBOX_ROOT_ARG="$2"
      shift 2
      ;;
    --infra-root)
      [[ $# -ge 2 ]] || { echo "ERROR: --infra-root requires a path" >&2; exit 2; }
      INFRA_ROOT="$2"
      shift 2
      ;;
    --force-non-wsl)
      ALLOW_NON_WSL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $ALLOW_NON_WSL -ne 1 ]]; then
  if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    echo "ERROR: this migration is intended for WSL2." >&2
    echo "Use --force-non-wsl only for testing." >&2
    exit 1
  fi
fi

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 is required." >&2
  exit 1
}

normalize_path() {
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

candidate_is_valid() {
  local root="$1"
  [[ -d "$root/Research" && -d "$root/ForShareLargeData" ]]
}

add_candidate() {
  local root="$1"
  [[ -n "$root" ]] || return 0
  root="$(normalize_path "$root")"
  local existing
  for existing in "${CANDIDATES[@]:-}"; do
    [[ "$existing" == "$root" ]] && return 0
  done
  CANDIDATES+=("$root")
}

CANDIDATES=()

if [[ -n "$DROPBOX_ROOT_ARG" ]]; then
  add_candidate "$DROPBOX_ROOT_ARG"
else
  if [[ -n "${DROPBOX_ROOT:-}" ]]; then
    add_candidate "$DROPBOX_ROOT"
  fi
  if [[ -n "${RESEARCH_ROOT:-}" ]]; then
    add_candidate "$(dirname "$RESEARCH_ROOT")"
  fi
  if [[ -n "${LARGE_ROOT:-}" ]]; then
    add_candidate "$(dirname "$LARGE_ROOT")"
  fi

  if [[ -f "$HOME/.research_env" ]]; then
    OLD_ENV_VALUES="$(bash -c '
      set +u
      source "$1" >/dev/null 2>&1 || true
      printf "%s\n%s\n%s\n" \
        "${DROPBOX_ROOT:-}" \
        "${RESEARCH_ROOT:-}" \
        "${LARGE_ROOT:-}"
    ' _ "$HOME/.research_env")"

    mapfile -t OLD_ENV_LINES <<< "$OLD_ENV_VALUES"
    [[ -n "${OLD_ENV_LINES[0]:-}" ]] && add_candidate "${OLD_ENV_LINES[0]}"
    [[ -n "${OLD_ENV_LINES[1]:-}" ]] && add_candidate "$(dirname "${OLD_ENV_LINES[1]}")"
    [[ -n "${OLD_ENV_LINES[2]:-}" ]] && add_candidate "$(dirname "${OLD_ENV_LINES[2]}")"
  fi

  if command -v cmd.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    WIN_PROFILE="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' | tail -n 1 || true)"
    if [[ -n "$WIN_PROFILE" && "$WIN_PROFILE" != '%USERPROFILE%' ]]; then
      WSL_PROFILE="$(wslpath -u "$WIN_PROFILE" 2>/dev/null || true)"
      [[ -n "$WSL_PROFILE" ]] && add_candidate "$WSL_PROFILE/Dropbox"
    fi
  fi

  shopt -s nullglob
  for path in /mnt/c/Users/*/Dropbox; do
    add_candidate "$path"
  done
  shopt -u nullglob
fi

VALID_CANDIDATES=()
for candidate in "${CANDIDATES[@]:-}"; do
  if candidate_is_valid "$candidate"; then
    VALID_CANDIDATES+=("$candidate")
  fi
done

if [[ ${#VALID_CANDIDATES[@]} -eq 0 ]]; then
  echo "ERROR: could not find a Dropbox root containing both:" >&2
  echo "  Research" >&2
  echo "  ForShareLargeData" >&2
  echo >&2
  echo "Run again with:" >&2
  echo "  $0 --dropbox-root /mnt/c/Users/<WindowsUser>/Dropbox --apply" >&2
  exit 1
fi

if [[ ${#VALID_CANDIDATES[@]} -gt 1 && -z "$DROPBOX_ROOT_ARG" ]]; then
  echo "ERROR: multiple Dropbox roots were detected:" >&2
  printf '  %s\n' "${VALID_CANDIDATES[@]}" >&2
  echo "Specify one with --dropbox-root." >&2
  exit 1
fi

NEW_DROPBOX_ROOT="${VALID_CANDIDATES[0]}"
NEW_RESEARCH_ROOT="$NEW_DROPBOX_ROOT/Research"
NEW_LARGE_ROOT="$NEW_DROPBOX_ROOT/ForShareLargeData"
NEW_SRC_ROOT="$HOME/src"
NEW_WORKTREE_ROOT="$HOME/worktrees"
NEW_SCRATCH_ROOT="$HOME/scratch"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ENV_TARGET="$HOME/.research_env"
BASHRC_TARGET="$HOME/.bashrc"
ENV_NEW="$TMP_DIR/research_env.new"
BASHRC_NEW="$TMP_DIR/bashrc.new"

python3 - \
  "$ENV_TARGET" \
  "$ENV_NEW" \
  "$NEW_DROPBOX_ROOT" \
  "$NEW_RESEARCH_ROOT" \
  "$NEW_LARGE_ROOT" \
  "$NEW_SRC_ROOT" \
  "$NEW_WORKTREE_ROOT" \
  "$NEW_SCRATCH_ROOT" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
values = {
    "DROPBOX_ROOT": sys.argv[3],
    "RESEARCH_ROOT": sys.argv[4],
    "LARGE_ROOT": sys.argv[5],
    "SRC_ROOT": sys.argv[6],
    "WORKTREE_ROOT": sys.argv[7],
    "SCRATCH_ROOT": sys.argv[8],
}

begin = "# >>> research-dev-infra managed environment >>>"
end = "# <<< research-dev-infra managed environment <<<"
managed_keys = set(values) | {
    "DATA_ROOTS_DIR",
    "LOCAL_ROOT",
    "LOCAL_LARGE_ROOT",
}

text = source.read_text() if source.exists() else ""
lines = text.splitlines()
out = []
in_managed = False

assignment = re.compile(
    r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*="
)

for line in lines:
    if line.strip() == begin:
        in_managed = True
        continue
    if line.strip() == end:
        in_managed = False
        continue
    if in_managed:
        continue
    match = assignment.match(line)
    if match and match.group(1) in managed_keys:
        continue
    out.append(line)

while out and not out[-1].strip():
    out.pop()

if out:
    out.append("")

out.append(begin)
for key, value in values.items():
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    out.append(f'export {key}="{escaped}"')
out.append(end)
out.append("")

target.write_text("\n".join(out))
PY

python3 - "$BASHRC_TARGET" "$BASHRC_NEW" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
text = source.read_text() if source.exists() else ""
lines = text.splitlines()

begin = "# >>> research-dev-infra shell integration >>>"
end = "# <<< research-dev-infra shell integration <<<"
legacy_lines = {
    'export PATH="$HOME/.local/bin:$PATH"',
    '[ -f "$HOME/.research_env" ] && source "$HOME/.research_env"',
    'source "$HOME/.research_env"',
}

out = []
in_managed = False
for line in lines:
    if line.strip() == begin:
        in_managed = True
        continue
    if line.strip() == end:
        in_managed = False
        continue
    if in_managed:
        continue
    if line.strip() in legacy_lines:
        continue
    out.append(line)

while out and not out[-1].strip():
    out.pop()

if out:
    out.append("")

out.extend(
    [
        begin,
        'export PATH="$HOME/.local/bin:$PATH"',
        '[ -f "$HOME/.research_env" ] && source "$HOME/.research_env"',
        end,
        "",
    ]
)

target.write_text("\n".join(out))
PY

LEGACY_ROOT="$HOME/data-roots"
SETUP_WORKSPACE_SOURCE="$INFRA_ROOT/scripts/setup-workspace.sh"
SETUP_WORKSPACE_LINK="$HOME/.local/bin/setup-workspace"
LEGACY_COMMAND_LINK="$HOME/.local/bin/setup-project-links"
LEGACY_COMMAND_SOURCE="$INFRA_ROOT/scripts/setup-project-links.sh"

print_header() {
  printf '\n== %s ==\n' "$1"
}

show_file_diff() {
  local current="$1"
  local proposed="$2"
  if [[ -f "$current" ]]; then
    diff -u "$current" "$proposed" || true
  else
    diff -u /dev/null "$proposed" || true
  fi
}

safe_legacy_links=()
unsafe_legacy_entries=()
if [[ -d "$LEGACY_ROOT" && ! -L "$LEGACY_ROOT" ]]; then
  shopt -s dotglob nullglob
  for entry in "$LEGACY_ROOT"/*; do
    name="$(basename "$entry")"
    if [[ -L "$entry" ]]; then
      target="$(readlink -f "$entry" 2>/dev/null || true)"
      case "$name" in
        Research|ForShareLargeData|Dropbox|LocalLarge)
          safe_legacy_links+=("$entry")
          ;;
        *)
          if [[ -n "$target" && "$target" == "$NEW_DROPBOX_ROOT"* ]]; then
            safe_legacy_links+=("$entry")
          else
            unsafe_legacy_entries+=("$entry")
          fi
          ;;
      esac
    else
      unsafe_legacy_entries+=("$entry")
    fi
  done
  shopt -u dotglob nullglob
elif [[ -L "$LEGACY_ROOT" ]]; then
  unsafe_legacy_entries+=("$LEGACY_ROOT")
fi

print_header "Migration summary"
echo "Mode:             $MODE"
echo "Dropbox root:     $NEW_DROPBOX_ROOT"
echo "Research root:    $NEW_RESEARCH_ROOT"
echo "Large-data root:  $NEW_LARGE_ROOT"
echo "Source root:      $NEW_SRC_ROOT"
echo "Worktree root:    $NEW_WORKTREE_ROOT"
echo "Scratch root:     $NEW_SCRATCH_ROOT"
echo "Infra root:       $INFRA_ROOT"

echo
printf 'This script will not modify anything under: %s\n' "$HOME/src"

print_header "Proposed ~/.research_env"
show_file_diff "$ENV_TARGET" "$ENV_NEW"

print_header "Proposed ~/.bashrc integration"
show_file_diff "$BASHRC_TARGET" "$BASHRC_NEW"

print_header "Legacy ~/data-roots cleanup"
if [[ ! -e "$LEGACY_ROOT" && ! -L "$LEGACY_ROOT" ]]; then
  echo "No legacy directory exists."
else
  if [[ ${#safe_legacy_links[@]} -gt 0 ]]; then
    echo "The following symlinks are safe to remove:"
    for entry in "${safe_legacy_links[@]}"; do
      printf '  %s -> %s\n' "$entry" "$(readlink "$entry")"
    done
  else
    echo "No safe legacy symlinks found."
  fi

  if [[ ${#unsafe_legacy_entries[@]} -gt 0 ]]; then
    echo
    echo "These entries will NOT be removed automatically:"
    printf '  %s\n' "${unsafe_legacy_entries[@]}"
  fi
fi

print_header "Command symlinks"
if [[ -x "$SETUP_WORKSPACE_SOURCE" ]]; then
  echo "Will link: $SETUP_WORKSPACE_LINK -> $SETUP_WORKSPACE_SOURCE"
else
  echo "Will not create setup-workspace: source script not found or not executable."
  echo "Expected: $SETUP_WORKSPACE_SOURCE"
fi

if [[ -L "$LEGACY_COMMAND_LINK" ]]; then
  current_target="$(readlink "$LEGACY_COMMAND_LINK")"
  if [[ "$current_target" == "$LEGACY_COMMAND_SOURCE" || "$current_target" == "$INFRA_ROOT"/* ]]; then
    echo "Will remove legacy command symlink: $LEGACY_COMMAND_LINK"
  else
    echo "Will keep unrelated legacy command symlink: $LEGACY_COMMAND_LINK -> $current_target"
  fi
fi

if [[ "$MODE" == "dry-run" ]]; then
  print_header "No changes applied"
  echo "Review the output, then run:"
  printf '  %q --apply --dropbox-root %q\n' "$0" "$NEW_DROPBOX_ROOT"
  exit 0
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$HOME/.local/bin" "$NEW_WORKTREE_ROOT" "$NEW_SCRATCH_ROOT"

if [[ -f "$ENV_TARGET" ]]; then
  cp -p "$ENV_TARGET" "$ENV_TARGET.backup.$TIMESTAMP"
fi
if [[ -f "$BASHRC_TARGET" ]]; then
  cp -p "$BASHRC_TARGET" "$BASHRC_TARGET.backup.$TIMESTAMP"
fi

install -m 600 "$ENV_NEW" "$ENV_TARGET"
install -m 644 "$BASHRC_NEW" "$BASHRC_TARGET"

for entry in "${safe_legacy_links[@]}"; do
  rm -- "$entry"
done

if [[ -d "$LEGACY_ROOT" && ! -L "$LEGACY_ROOT" ]]; then
  rmdir "$LEGACY_ROOT" 2>/dev/null || true
fi

if [[ -x "$SETUP_WORKSPACE_SOURCE" ]]; then
  rm -f "$SETUP_WORKSPACE_LINK"
  ln -s "$SETUP_WORKSPACE_SOURCE" "$SETUP_WORKSPACE_LINK"
fi

if [[ -L "$LEGACY_COMMAND_LINK" ]]; then
  current_target="$(readlink "$LEGACY_COMMAND_LINK")"
  if [[ "$current_target" == "$LEGACY_COMMAND_SOURCE" || "$current_target" == "$INFRA_ROOT"/* ]]; then
    rm -- "$LEGACY_COMMAND_LINK"
  fi
fi

print_header "Migration complete"
echo "Backups, when applicable:"
echo "  $ENV_TARGET.backup.$TIMESTAMP"
echo "  $BASHRC_TARGET.backup.$TIMESTAMP"
echo
echo "Reload the shell configuration:"
echo "  source ~/.bashrc"
echo "  hash -r"
echo
echo "Verify:"
echo "  printf 'RESEARCH_ROOT=%s\\n' \"\$RESEARCH_ROOT\""
echo "  printf 'LARGE_ROOT=%s\\n' \"\$LARGE_ROOT\""
echo "  command -v setup-workspace"
echo "  test ! -e ~/data-roots && echo 'legacy data-roots removed'"

if [[ ${#unsafe_legacy_entries[@]} -gt 0 ]]; then
  echo
  echo "WARNING: ~/data-roots still contains entries that were not removed."
  echo "Inspect them manually before deleting anything."
fi
