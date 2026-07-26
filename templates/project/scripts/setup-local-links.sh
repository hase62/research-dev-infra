#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="__PROJECT_NAME__"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ ! -f "$HOME/.research_env" ]]; then
  echo "ERROR: $HOME/.research_env was not found." >&2
  echo "Run research-dev-infra/scripts/setup-machine.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$HOME/.research_env"

replace_link() {
  local source_path="$1"
  local link_path="$2"

  mkdir -p "$(dirname "$link_path")"
  if [[ -L "$link_path" ]]; then
    rm -f "$link_path"
  elif [[ -e "$link_path" ]]; then
    echo "ERROR: refusing to replace a non-symlink path: $link_path" >&2
    return 1
  fi
  ln -s "$source_path" "$link_path"
}

mkdir -p "$PROJECT_ROOT/.local/data"

WORKSPACE_NAME="${WORKSPACE_NAME:-}"
if [[ -z "$WORKSPACE_NAME" && -f "$PROJECT_ROOT/.local/workspace-name" ]]; then
  WORKSPACE_NAME="$(cat "$PROJECT_ROOT/.local/workspace-name")"
fi
WORKSPACE_NAME="${WORKSPACE_NAME:-main}"
printf '%s\n' "$WORKSPACE_NAME" > "$PROJECT_ROOT/.local/workspace-name"

WORKSPACE_DIR="$SCRATCH_ROOT/$PROJECT_NAME/$WORKSPACE_NAME"
SCRATCH_DIR="$WORKSPACE_DIR/scratch"
OUTPUT_DIR="$WORKSPACE_DIR/output"

mkdir -p "$SCRATCH_DIR" "$OUTPUT_DIR"
replace_link "$SCRATCH_DIR" "$PROJECT_ROOT/.local/scratch"
replace_link "$OUTPUT_DIR" "$PROJECT_ROOT/.local/output"

link_data() {
  local source_path="$1"
  local link_name="$2"

  if [[ "$link_name" == */* || "$link_name" == "." || "$link_name" == ".." ]]; then
    echo "ERROR: link name must be a simple name: $link_name" >&2
    return 1
  fi

  replace_link "$source_path" "$PROJECT_ROOT/.local/data/$link_name"

  if [[ ! -e "$source_path" ]]; then
    echo "WARNING: target does not currently exist: $source_path" >&2
  fi
}

use_output_dir() {
  local source_path="$1"
  mkdir -p "$source_path"
  OUTPUT_DIR="$source_path"
  replace_link "$OUTPUT_DIR" "$PROJECT_ROOT/.local/output"
}

# -----------------------------------------------------------------------------
# Project-specific data links
#
# Add only the shared Dropbox directories needed by this project.
# Keep Dropbox's existing directory structure unchanged.
# This tracked script should reconstruct the same logical links on every PC.
#
# Shared input examples:
# link_data "$RESEARCH_ROOT/Papers/ExampleProject" papers
# link_data "$LARGE_ROOT/ExampleData/processed" processed_data
#
# Persistent output shared across PCs (recommended):
# use_output_dir "$LARGE_ROOT/ExampleProject/results/$WORKSPACE_NAME"
#
# If use_output_dir is omitted, .local/output points to local scratch and must
# contain only reproducible/disposable working output.
#
# Rare machine-specific cache example. Define EXAMPLE_LOCAL_CACHE_ROOT in
# ~/.research_env on only the relevant PC; do not hard-code a PC-specific path:
# if [[ -n "${EXAMPLE_LOCAL_CACHE_ROOT:-}" ]]; then
#   link_data "$EXAMPLE_LOCAL_CACHE_ROOT" local_cache
# fi
#
# There is intentionally no machine-wide LOCAL_ROOT.
# -----------------------------------------------------------------------------


echo "Local links configured for $PROJECT_NAME ($WORKSPACE_NAME):"
echo "  data:    $PROJECT_ROOT/.local/data"
echo "  scratch: $SCRATCH_DIR"
echo "  output:  $OUTPUT_DIR"
if [[ "$OUTPUT_DIR" == "$SCRATCH_ROOT/"* ]]; then
  echo "  note:    output is local/disposable; use Dropbox for persistent shared results"
fi
