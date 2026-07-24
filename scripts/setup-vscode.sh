#!/usr/bin/env bash
set -euo pipefail

YES=false

usage() {
  cat <<'USAGE'
Usage:
  setup-vscode.sh [--yes]

Checks the Windows Visual Studio Code command from WSL and installs the
recommended official extensions for the research workflow:
  - WSL
  - Codex
  - Claude Code
  - Python
  - Jupyter
  - R

Visual Studio Code itself is a Windows application and is not installed by
this script. If `code` is unavailable, the script prints the Windows install
command and exits without changing anything.
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
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v code >/dev/null 2>&1; then
  cat <<'MISSING'
Visual Studio Code's `code` command is not available in this WSL shell.

Install Visual Studio Code on Windows, not inside Ubuntu.
From Windows PowerShell:

  winget install --id Microsoft.VisualStudioCode -e

Then close and reopen Ubuntu. If `code` is still unavailable, open VS Code on
Windows, install the Microsoft "WSL" extension, and run "WSL: Connect to WSL"
from the Command Palette once.
MISSING
  exit 1
fi

EXTENSIONS=(
  "ms-vscode-remote.remote-wsl"
  "OpenAI.chatgpt"
  "anthropic.claude-code"
  "ms-python.python"
  "ms-toolsai.jupyter"
  "REditorSupport.r"
)

cat <<'NOTICE'
This installs or updates the recommended VS Code extensions for this workflow.
Codex and Claude Code remain separate services with separate authentication and
usage limits. Installing both extensions does not merge their sessions.
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type VSCODE to continue: " answer
  [[ "$answer" == "VSCODE" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

for extension in "${EXTENSIONS[@]}"; do
  echo "==> Installing VS Code extension: $extension"
  code --install-extension "$extension" --force
done

echo
echo "VS Code setup completed."
echo "Open a project from WSL with:"
echo "  cd ~/src/<Project>"
echo "  code ."
