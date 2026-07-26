#!/usr/bin/env bash
set -euo pipefail

YES=false
GIT_NAME=""
GIT_EMAIL=""
INSTALL_DESKTOP_APPS=false

usage() {
  cat <<'USAGE'
Usage:
  bootstrap-macos.sh [options]

Options:
  --git-name NAME        Configure git user.name
  --git-email EMAIL      Configure git user.email
  --desktop-apps         Also install Visual Studio Code and Dropbox with Homebrew Cask
  --yes                  Do not ask for confirmation
  -h, --help             Show this help

Installs Homebrew when needed and the baseline macOS command-line tools required
by research-dev-infra.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-name)
      [[ $# -ge 2 ]] || { echo "ERROR: --git-name requires a value" >&2; exit 1; }
      GIT_NAME="$2"
      shift 2
      ;;
    --git-email)
      [[ $# -ge 2 ]] || { echo "ERROR: --git-email requires a value" >&2; exit 1; }
      GIT_EMAIL="$2"
      shift 2
      ;;
    --desktop-apps)
      INSTALL_DESKTOP_APPS=true
      shift
      ;;
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

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "ERROR: bootstrap-macos.sh must be run on macOS." >&2
  exit 1
}

if ! xcode-select -p >/dev/null 2>&1; then
  cat <<'XCODE'
Apple Command Line Tools are not installed.

Run:
  xcode-select --install

Complete the macOS installer, then rerun bootstrap-macos.sh.
XCODE
  exit 1
fi

cat <<NOTICE
This script installs or updates the baseline macOS development tools through
Homebrew:
  git, gh, curl, wget, rsync, jq, tree, ripgrep, tmux, htop,
  shellcheck, pkg-config, python, unzip

Homebrew itself will be installed from the official installer if missing.
NOTICE

if [[ "$INSTALL_DESKTOP_APPS" == true ]]; then
  echo "It will also install Visual Studio Code and Dropbox."
fi

if [[ "$YES" != true ]]; then
  read -r -p "Type BOOTSTRAP to continue: " answer
  [[ "$answer" == "BOOTSTRAP" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

command -v brew >/dev/null 2>&1 || {
  echo "ERROR: Homebrew was installed but is not available on PATH." >&2
  exit 1
}

BREW_PREFIX="$(brew --prefix)"
SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
touch "$HOME/.zprofile"
if ! grep -Fqx "$SHELLENV_LINE" "$HOME/.zprofile" 2>/dev/null; then
  printf '\n%s\n' "$SHELLENV_LINE" >> "$HOME/.zprofile"
fi

brew update
brew install \
  curl \
  gh \
  git \
  htop \
  jq \
  pkg-config \
  python \
  ripgrep \
  rsync \
  shellcheck \
  tmux \
  tree \
  unzip \
  wget

if [[ "$INSTALL_DESKTOP_APPS" == true ]]; then
  brew install --cask visual-studio-code dropbox
fi

git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global pull.rebase true
git config --global fetch.prune true
git config --global push.autoSetupRemote true

if [[ -n "$GIT_NAME" ]]; then
  git config --global user.name "$GIT_NAME"
fi
if [[ -n "$GIT_EMAIL" ]]; then
  git config --global user.email "$GIT_EMAIL"
fi

mkdir -p "$HOME/.local/bin"

cat <<'DONE'

macOS bootstrap completed.

Next:
  1. Start a new Terminal window or run:
       source ~/.zprofile
  2. Confirm Git identity:
       git config --global --list
  3. Authenticate GitHub:
       gh auth login
     Recommended choices: GitHub.com -> HTTPS -> Login with a web browser
  4. Confirm authentication:
       gh auth status
DONE
