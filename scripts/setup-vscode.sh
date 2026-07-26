#!/usr/bin/env bash
set -euo pipefail

YES=false
MIN_VSCODE_VERSION="1.98.0"

usage() {
  cat <<'USAGE'
Usage:
  setup-vscode.sh [--yes]

Checks Visual Studio Code and installs the recommended official extensions for
this research workflow.

WSL2:
  - WSL
  - Codex
  - Claude Code
  - Python
  - Jupyter
  - R

macOS:
  - Codex
  - Claude Code
  - Python
  - Jupyter
  - R

The script requires VS Code 1.98.0 or newer because current AI and analysis
extensions may reject older versions.
USAGE
}

version_ge() {
  python3 - "$1" "$2" <<'PY'
import sys

def parts(value):
    return tuple(int(x) for x in value.split("."))

raise SystemExit(0 if parts(sys.argv[1]) >= parts(sys.argv[2]) else 1)
PY
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

OS="$(uname -s)"
case "$OS" in
  Linux)
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
      echo "ERROR: Linux setup is supported only under WSL2." >&2
      exit 1
    fi
    PLATFORM="wsl"
    ;;
  Darwin)
    PLATFORM="macos"
    ;;
  *)
    echo "ERROR: Unsupported operating system: $OS" >&2
    exit 1
    ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required for version checks." >&2
  exit 1
fi

if ! command -v code >/dev/null 2>&1; then
  if [[ "$PLATFORM" == "wsl" ]]; then
    cat <<'MISSING_WSL'
Visual Studio Code's `code` command is not available in this WSL shell.

Install Visual Studio Code on Windows, not inside Ubuntu. From Windows
PowerShell:

  winget install --id Microsoft.VisualStudioCode -e

Then close and reopen Ubuntu. If `code` is still unavailable, open VS Code on
Windows, install the Microsoft "WSL" extension, and run "WSL: Connect to WSL"
from the Command Palette once.
MISSING_WSL
  else
    cat <<'MISSING_MAC'
Visual Studio Code's `code` command is not available on this Mac.

Install it with Homebrew:

  brew install --cask visual-studio-code

Then open Visual Studio Code and run from the Command Palette:

  Shell Command: Install 'code' command in PATH

Open a new Terminal window and rerun setup-vscode.
MISSING_MAC
  fi
  exit 1
fi

VSCODE_VERSION="$(code --version 2>/dev/null | head -n 1 | tr -d '\r')"
if [[ ! "$VSCODE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Could not determine the VS Code version from: $VSCODE_VERSION" >&2
  exit 1
fi

if ! version_ge "$VSCODE_VERSION" "$MIN_VSCODE_VERSION"; then
  echo "ERROR: Visual Studio Code $VSCODE_VERSION is too old." >&2
  echo "This workflow requires VS Code $MIN_VSCODE_VERSION or newer." >&2
  echo >&2
  if [[ "$PLATFORM" == "wsl" ]]; then
    cat >&2 <<'OLD_WSL'
Close all VS Code windows, then update from Windows PowerShell:

  winget upgrade --id Microsoft.VisualStudioCode -e

Then restart WSL from Windows PowerShell:

  wsl --shutdown
OLD_WSL
  else
    cat >&2 <<'OLD_MAC'
Update Visual Studio Code with:

  brew upgrade --cask visual-studio-code

If it was not installed through Homebrew, use Code -> Check for Updates in VS
Code or replace it with the current official application.
OLD_MAC
  fi
  echo >&2
  echo "Verify with: code --version" >&2
  echo "Then rerun: setup-vscode" >&2
  exit 1
fi

EXTENSIONS=(
  "OpenAI.chatgpt"
  "anthropic.claude-code"
  "ms-python.python"
  "ms-toolsai.jupyter"
  "REditorSupport.r"
)
if [[ "$PLATFORM" == "wsl" ]]; then
  EXTENSIONS=("ms-vscode-remote.remote-wsl" "${EXTENSIONS[@]}")
fi

cat <<NOTICE
Detected Visual Studio Code $VSCODE_VERSION on $PLATFORM.
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
  log_file="$(mktemp "${TMPDIR:-/tmp}/vscode-extension.XXXXXX")"
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
  echo "Update VS Code, confirm 'code --version', and rerun setup-vscode." >&2
  exit 1
fi

echo
echo "VS Code setup completed successfully."
echo "Open a project with:"
echo "  cd ~/src/<Project>"
echo "  code ."
