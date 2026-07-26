#!/usr/bin/env bash
set -euo pipefail

YES=false
GUI=false

usage() {
  cat <<'USAGE'
Usage:
  setup-emacs.sh [--gui] [--yes]

WSL2 default:
  Installs terminal Emacs (emacs-nox). Use --gui for emacs-gtk with WSLg.

macOS default:
  Installs the Homebrew Emacs formula for terminal use. Use --gui to also
  install the Emacs.app cask.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gui)
      GUI=true
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

OS="$(uname -s)"
case "$OS" in
  Linux)
    grep -qi microsoft /proc/version 2>/dev/null || {
      echo "ERROR: Linux setup is supported only under WSL2." >&2
      exit 1
    }
    PLATFORM="wsl"
    package="emacs-nox"
    [[ "$GUI" == true ]] && package="emacs-gtk"
    DESCRIPTION="Install $package with apt"
    ;;
  Darwin)
    PLATFORM="macos"
    command -v brew >/dev/null 2>&1 || {
      echo "ERROR: Homebrew is required. Run scripts/bootstrap-macos.sh first." >&2
      exit 1
    }
    DESCRIPTION="Install the Homebrew emacs formula"
    [[ "$GUI" == true ]] && DESCRIPTION="$DESCRIPTION and the emacs-app cask"
    ;;
  *)
    echo "ERROR: Unsupported operating system: $OS" >&2
    exit 1
    ;;
esac

cat <<NOTICE
This will $DESCRIPTION and configure Git to use terminal Emacs.
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type EMACS to continue: " answer
  [[ "$answer" == "EMACS" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

if [[ "$PLATFORM" == "wsl" ]]; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
else
  brew install emacs
  if [[ "$GUI" == true ]]; then
    brew install --cask emacs-app
  fi
fi

git config --global core.editor "emacs -nw"
if command -v gh >/dev/null 2>&1; then
  gh config set editor "emacs -nw" >/dev/null
fi

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/e" <<'WRAPPER'
#!/usr/bin/env bash
exec emacs -nw "$@"
WRAPPER
chmod +x "$HOME/.local/bin/e"

if [[ "$PLATFORM" == "macos" && "$GUI" == true ]]; then
  cat > "$HOME/.local/bin/emacs-gui" <<'WRAPPER'
#!/usr/bin/env bash
open -a Emacs "$@"
WRAPPER
  chmod +x "$HOME/.local/bin/emacs-gui"
fi

cat <<DONE
Emacs setup completed.

Terminal use:
  e FILE
  emacs -nw FILE

Open a project:
  cd ~/src/<Project>
  e PROJECT.md
DONE

if [[ "$PLATFORM" == "macos" && "$GUI" == true ]]; then
  cat <<'DONE'

GUI use on macOS:
  emacs-gui FILE
DONE
fi

cat <<'DONE'

VS Code and Emacs may both be open, but do not edit the same file in both at the
same time. Use the Codex or Claude Code VS Code extension as the standard UI;
the project terminal remains available for Git, environments, tests, and the
optional CLI interfaces.
DONE
