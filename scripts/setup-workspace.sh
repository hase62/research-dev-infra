#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup-workspace [PROJECT_PATH]

Reconstruct workspace/data, workspace/scratch, and workspace/output from the
tracked scripts/configure-workspace.sh in a project or worktree.

Without PROJECT_PATH, the current Git working tree root is used. If the current
directory is not inside Git, the current directory itself is used.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  TARGET="$(cd "$1" && pwd)"
elif TARGET="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  TARGET="$PWD"
fi

CONFIG_SCRIPT="$TARGET/scripts/configure-workspace.sh"
if [[ ! -f "$CONFIG_SCRIPT" ]]; then
  echo "ERROR: scripts/configure-workspace.sh was not found under: $TARGET" >&2
  exit 1
fi

PROJECT_ROOT="$TARGET" bash "$CONFIG_SCRIPT"
