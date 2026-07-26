#!/usr/bin/env bash
set -euo pipefail

YES=false
GUI=false

usage() {
  cat <<'USAGE'
Usage:
  setup-emacs.sh [--gui] [--yes]

Default installs terminal Emacs (emacs-nox), suitable for WSL terminals and
VS Code integrated terminals. Use --gui to install emacs-gtk for WSLg.
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

package="emacs-nox"
if [[ "$GUI" == true ]]; then
  package="emacs-gtk"
fi

cat <<NOTICE
This installs $package with apt and configures Git to use Emacs.
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type EMACS to continue: " answer
  [[ "$answer" == "EMACS" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"

git config --global core.editor "emacs -nw"

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/e" <<'WRAPPER'
#!/usr/bin/env bash
exec emacs -nw "$@"
WRAPPER
chmod +x "$HOME/.local/bin/e"

cat <<'DONE'
Emacs setup completed.

Terminal use:
  e FILE
  emacs -nw FILE

Open a project:
  cd ~/src/<Project>
  e PROJECT.md

VS Code and Emacs may both be open, but do not edit the same file in both at the
same time. Codex and Claude Code still run from the project terminal.
DONE
