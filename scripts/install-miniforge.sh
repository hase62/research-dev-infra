#!/usr/bin/env bash
set -euo pipefail

PREFIX="$HOME/miniforge3"
YES=false

usage() {
  cat <<'USAGE'
Usage:
  install-miniforge.sh [--prefix PATH] [--yes]

Installs the latest Miniforge for the current Linux or macOS architecture,
initializes the default shell, and disables automatic activation of the base
environment.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      [[ $# -ge 2 ]] || { echo "ERROR: --prefix requires a value" >&2; exit 1; }
      PREFIX="$2"
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
      exit 1
      ;;
  esac
done

if [[ -e "$PREFIX" ]]; then
  echo "ERROR: Installation path already exists: $PREFIX" >&2
  echo "Use the existing installation or pass a different --prefix." >&2
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS:$ARCH" in
  Linux:x86_64|Linux:amd64)
    INSTALLER="Miniforge3-Linux-x86_64.sh"
    SHELL_NAME="bash"
    RC_FILE="$HOME/.bashrc"
    ;;
  Linux:aarch64|Linux:arm64)
    INSTALLER="Miniforge3-Linux-aarch64.sh"
    SHELL_NAME="bash"
    RC_FILE="$HOME/.bashrc"
    ;;
  Darwin:arm64)
    INSTALLER="Miniforge3-MacOSX-arm64.sh"
    SHELL_NAME="zsh"
    RC_FILE="$HOME/.zshrc"
    ;;
  Darwin:x86_64)
    INSTALLER="Miniforge3-MacOSX-x86_64.sh"
    SHELL_NAME="zsh"
    RC_FILE="$HOME/.zshrc"
    ;;
  *)
    echo "ERROR: Unsupported platform: $OS $ARCH" >&2
    exit 1
    ;;
esac

URL="https://github.com/conda-forge/miniforge/releases/latest/download/$INSTALLER"
TMP_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/miniforge.XXXXXX.sh")"
trap 'rm -f "$TMP_INSTALLER"' EXIT

cat <<NOTICE
This will download the current official Miniforge installer from:
  $URL
and install it into:
  $PREFIX
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type MINIFORGE to continue: " answer
  [[ "$answer" == "MINIFORGE" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

curl -fL "$URL" -o "$TMP_INSTALLER"
bash "$TMP_INSTALLER" -b -p "$PREFIX"

"$PREFIX/bin/conda" init "$SHELL_NAME"
"$PREFIX/bin/conda" config --set auto_activate_base false

cat <<DONE

Miniforge installed.

Open a new shell or run:
  source $RC_FILE

Then verify:
  conda --version
  mamba --version

Create one environment per research project. Do not install project packages
into the base environment.
DONE
