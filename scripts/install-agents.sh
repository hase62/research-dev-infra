#!/usr/bin/env bash
set -euo pipefail

YES=false

usage() {
  cat <<'USAGE'
Usage:
  install-agents.sh [--yes]

Installs Codex CLI and Claude Code using their official Linux installers.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required." >&2
  exit 1
fi

cat <<'NOTICE'
This will execute the current official installers:

  Codex:      https://chatgpt.com/codex/install.sh
  Claude Code: https://claude.ai/install.sh (stable channel)

Review these URLs and continue only if you trust them.
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type INSTALL to continue: " answer
  [[ "$answer" == "INSTALL" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
curl -fsSL https://claude.ai/install.sh | bash -s stable

echo
echo "Installation commands completed."
echo "Open a new shell, then run: codex"
echo "Open a new shell, then run: claude"
