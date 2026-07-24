#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-$PWD}"
TARGET="$(cd "$TARGET" && pwd)"

if [[ ! -f "$TARGET/scripts/setup-local-links.sh" ]]; then
  echo "ERROR: scripts/setup-local-links.sh was not found under: $TARGET" >&2
  exit 1
fi

PROJECT_ROOT="$TARGET" bash "$TARGET/scripts/setup-local-links.sh"
