#!/usr/bin/env bash
set -euo pipefail

YES=false
MIN_VSCODE_VERSION="1.98.0"

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
this script. The script requires VS Code 1.98.0 or newer because the current
Claude Code extension requires at least that version.
USAGE
}

version_ge() {
  # Return success when $1 >= $2 using version-aware sort.
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2" ]]
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

VSCODE_VERSION="$(code --version 2>/dev/null | head -n 1 | tr -d '\r')"
if [[ ! "$VSCODE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Could not determine the VS Code version from: $VSCODE_VERSION" >&2
  exit 1
fi

if ! version_ge "$VSCODE_VERSION" "$MIN_VSCODE_VERSION"; then
  cat <<EOF_OLD
ERROR: Visual Studio Code $VSCODE_VERSION is too old.

This workflow requires VS Code $MIN_VSCODE_VERSION or newer because current
Codex, Claude Code, and analysis extensions may reject older versions.

Close all VS Code windows, then update from Windows PowerShell:

  winget upgrade --id Microsoft.VisualStudioCode -e

If winget does not find an upgrade, run:

  winget install --id Microsoft.VisualStudioCode -e

Then restart WSL from Windows PowerShell:

  wsl --shutdown

Open Ubuntu again and verify:

  code --version

After the version is at least $MIN_VSCODE_VERSION, rerun:

  setup-vscode
EOF_OLD
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

cat <<NOTICE
Detected Visual Studio Code $VSCODE_VERSION.
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

FAILED_EXTENSIONS=()
for extension in "${EXTENSIONS[@]}"; do
  echo "==> Installing VS Code extension: $extension"
  log_file="$(mktemp)"
  if code --install-extension "$extension" --force >"$log_file" 2>&1; then
    cat "$log_file"
  else
    FAILED_EXTENSIONS+=("$extension")
    echo "ERROR: Failed to install $extension" >&2
    if ! grep -E "not compatible|Can't install|Error while installing|Failed Installing|Canceled" "$log_file" | head -n 8 >&2; then
      tail -n 12 "$log_file" >&2
    fi
  fi
  rm -f "$log_file"
done

if (( ${#FAILED_EXTENSIONS[@]} > 0 )); then
  echo >&2
  echo "VS Code setup completed with failures." >&2
  echo "Failed extensions:" >&2
  printf '  - %s\n' "${FAILED_EXTENSIONS[@]}" >&2
  echo >&2
  echo "Check that Windows VS Code is current, then run:" >&2
  echo "  wsl --shutdown" >&2
  echo "  code --version" >&2
  echo "  setup-vscode" >&2
  exit 1
fi

echo
echo "VS Code setup completed successfully."
echo "Open a project from WSL with:"
echo "  cd ~/src/<Project>"
echo "  code ."
