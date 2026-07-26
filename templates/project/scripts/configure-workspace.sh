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

if [[ -n "${WORKSPACE_NAME:-}" ]]; then
  :
elif [[ -d "$PROJECT_ROOT/.git" ]]; then
  WORKSPACE_NAME="main"
else
  WORKSPACE_NAME="$(basename "$PROJECT_ROOT")"
fi

mkdir -p "$PROJECT_ROOT/workspace/data"
while IFS= read -r stale_link; do
  rm -f "$stale_link"
done < <(find "$PROJECT_ROOT/workspace/data" -mindepth 1 -maxdepth 1 -type l -print 2>/dev/null)

LOCAL_WORKSPACE_DIR="$SCRATCH_ROOT/$PROJECT_NAME/$WORKSPACE_NAME"
SCRATCH_DIR="$LOCAL_WORKSPACE_DIR/scratch"
OUTPUT_DIR="$LOCAL_WORKSPACE_DIR/output"

mkdir -p "$SCRATCH_DIR" "$OUTPUT_DIR"
replace_link "$SCRATCH_DIR" "$PROJECT_ROOT/workspace/scratch"
replace_link "$OUTPUT_DIR" "$PROJECT_ROOT/workspace/output"

link_data() {
  local source_path="$1"
  local link_name="$2"

  if [[ "$link_name" == */* || "$link_name" == "." || "$link_name" == ".." ]]; then
    echo "ERROR: link name must be a simple name: $link_name" >&2
    return 1
  fi

  replace_link "$source_path" "$PROJECT_ROOT/workspace/data/$link_name"

  if [[ ! -e "$source_path" ]]; then
    echo "WARNING: target does not currently exist: $source_path" >&2
  fi
}

use_output_dir() {
  local source_path="$1"
  mkdir -p "$source_path"
  OUTPUT_DIR="$source_path"
  replace_link "$OUTPUT_DIR" "$PROJECT_ROOT/workspace/output"
}

# -----------------------------------------------------------------------------
# Project-specific workspace links
#
# Add only the shared Dropbox directories needed by this project.
# Keep Dropbox's existing directory structure unchanged.
# This tracked script reconstructs the same logical workspace on every PC.
#
# Shared input examples:
# link_data "$RESEARCH_ROOT/Papers/ExampleProject" papers
# link_data "$LARGE_ROOT/ExampleData/processed" processed_data
#
# Persistent output shared across PCs (recommended):
# use_output_dir "$LARGE_ROOT/ExampleProject/results/$WORKSPACE_NAME"
#
# If use_output_dir is omitted, workspace/output points to local scratch and
# must contain only reproducible/disposable working output.
#
# Rare machine-specific cache example. Define EXAMPLE_LOCAL_CACHE_ROOT in
# ~/.research_env on only the relevant PC; do not hard-code a PC-specific path:
# if [[ -n "${EXAMPLE_LOCAL_CACHE_ROOT:-}" ]]; then
#   link_data "$EXAMPLE_LOCAL_CACHE_ROOT" local_cache
# fi
#
# There is intentionally no machine-wide local-data root or ~/data-roots layer.
# -----------------------------------------------------------------------------


echo "Workspace configured for $PROJECT_NAME ($WORKSPACE_NAME):"
echo "  data:    $PROJECT_ROOT/workspace/data"
echo "  scratch: $SCRATCH_DIR"
echo "  output:  $OUTPUT_DIR"
if [[ "$OUTPUT_DIR" == "$SCRATCH_ROOT/"* ]]; then
  echo "  note:    output is local/disposable; use Dropbox for persistent shared results"
fi
