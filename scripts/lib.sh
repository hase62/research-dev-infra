#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
}

info() {
  echo "==> $*"
}

platform_name() {
  case "${RESEARCH_PLATFORM_OVERRIDE:-$(uname -s)}" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    *) echo "unsupported" ;;
  esac
}

is_wsl() {
  [[ "$(platform_name)" == "linux" ]] && grep -qi microsoft /proc/version 2>/dev/null
}

shell_rc_file() {
  if [[ "$(platform_name)" == "macos" ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

ensure_line() {
  local file_path="$1"
  local line="$2"
  mkdir -p "$(dirname "$file_path")"
  touch "$file_path"
  if ! grep -Fqx "$line" "$file_path" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file_path"
  fi
}

replace_symlink() {
  local source_path="$1"
  local link_path="$2"

  mkdir -p "$(dirname "$link_path")"

  if [[ -L "$link_path" ]]; then
    rm -f "$link_path"
  elif [[ -e "$link_path" ]]; then
    fail "Refusing to replace a non-symlink path: $link_path"
  fi

  ln -s "$source_path" "$link_path"
}

load_research_env() {
  [[ -f "$HOME/.research_env" ]] || fail "$HOME/.research_env was not found. Run setup-machine.sh first."
  # shellcheck disable=SC1090
  source "$HOME/.research_env"

  : "${SRC_ROOT:?SRC_ROOT is not set}"
  : "${WORKTREE_ROOT:?WORKTREE_ROOT is not set}"
  : "${SCRATCH_ROOT:?SCRATCH_ROOT is not set}"
  : "${RESEARCH_ROOT:?RESEARCH_ROOT is not set}"
  : "${LARGE_ROOT:?LARGE_ROOT is not set}"
}

validate_name() {
  local value="$1"
  local label="$2"
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || fail "$label may contain only letters, numbers, dot, underscore, and hyphen: $value"
}

replace_placeholder() {
  local root="$1"
  local placeholder="$2"
  local replacement="$3"

  command -v python3 >/dev/null 2>&1 || fail "python3 is required to initialize project templates"

  python3 - "$root" "$placeholder" "$replacement" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
placeholder = sys.argv[2]
replacement = sys.argv[3]

for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink():
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    updated = text.replace(placeholder, replacement)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
PY
}
