#!/usr/bin/env bash
set -euo pipefail

PREFIX="$HOME/miniforge3"
YES=false

usage() {
  cat <<'USAGE'
Usage:
  install-miniforge.sh [--prefix PATH] [--yes]

Installs the latest Miniforge for the current Linux architecture, initializes
conda for Bash, and disables automatic activation of the base environment.
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

case "$(uname -m)" in
  x86_64|amd64)
    INSTALLER="Miniforge3-Linux-x86_64.sh"
    ;;
  aarch64|arm64)
    INSTALLER="Miniforge3-Linux-aarch64.sh"
    ;;
  *)
    echo "ERROR: Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

URL="https://github.com/conda-forge/miniforge/releases/latest/download/$INSTALLER"
TMP_INSTALLER="$(mktemp --suffix=.sh)"
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

"$PREFIX/bin/conda" init bash
"$PREFIX/bin/conda" config --set auto_activate_base false

cat <<DONE

Miniforge installed.

Open a new shell or run:
  source ~/.bashrc

Then verify:
  conda --version
  mamba --version

Create one environment per research project. Do not install project packages
into the base environment.
DONE
