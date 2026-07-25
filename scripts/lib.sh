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

  while IFS= read -r -d '' file; do
    sed -i "s|$placeholder|$replacement|g" "$file"
  done < <(find "$root" -type f -print0)
}
