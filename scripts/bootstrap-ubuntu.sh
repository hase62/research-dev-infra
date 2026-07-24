#!/usr/bin/env bash
set -euo pipefail

YES=false
GIT_NAME=""
GIT_EMAIL=""

usage() {
  cat <<'USAGE'
Usage:
  bootstrap-ubuntu.sh [options]

Options:
  --git-name NAME      Configure git user.name
  --git-email EMAIL    Configure git user.email
  --yes                Do not ask for confirmation
  -h, --help           Show this help

Installs the baseline Ubuntu tools required before using research-dev-infra,
including Git and the official GitHub CLI apt repository.
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

if ! command -v apt-get >/dev/null 2>&1; then
  echo "ERROR: This script currently supports Ubuntu/Debian systems using apt." >&2
  exit 1
fi

cat <<'NOTICE'
This script will use sudo to install baseline development tools and register
the official GitHub CLI apt repository.

Installed baseline packages include:
  git, curl, wget, unzip, zip, rsync, jq, tree, ripgrep, tmux, htop,
  shellcheck, build-essential, pkg-config, ca-certificates, gnupg
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type BOOTSTRAP to continue: " answer
  [[ "$answer" == "BOOTSTRAP" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  htop \
  jq \
  lsb-release \
  pkg-config \
  ripgrep \
  rsync \
  shellcheck \
  tmux \
  tree \
  unzip \
  wget \
  zip

sudo install -m 0755 -d /etc/apt/keyrings
TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$TMP_KEY"
sudo install -m 0644 "$TMP_KEY" /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh

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

Ubuntu bootstrap completed.

Next:
  1. Confirm Git identity:
       git config --global --list
  2. Authenticate GitHub:
       gh auth login
     Recommended choices: GitHub.com -> HTTPS -> Login with a web browser
  3. Confirm authentication:
       gh auth status
DONE
