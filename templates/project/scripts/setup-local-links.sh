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

mkdir -p "$PROJECT_ROOT/.local/data"

WORKSPACE_NAME="${WORKSPACE_NAME:-}"
if [[ -z "$WORKSPACE_NAME" && -f "$PROJECT_ROOT/.local/workspace-name" ]]; then
  WORKSPACE_NAME="$(cat "$PROJECT_ROOT/.local/workspace-name")"
fi
WORKSPACE_NAME="${WORKSPACE_NAME:-main}"
printf '%s\n' "$WORKSPACE_NAME" > "$PROJECT_ROOT/.local/workspace-name"

SCRATCH_DIR="$SCRATCH_ROOT/$PROJECT_NAME/$WORKSPACE_NAME"
OUTPUT_DIR="$LOCAL_ROOT/$PROJECT_NAME/results/$WORKSPACE_NAME"

mkdir -p "$SCRATCH_DIR" "$OUTPUT_DIR"
ln -sfnT "$SCRATCH_DIR" "$PROJECT_ROOT/.local/scratch"
ln -sfnT "$OUTPUT_DIR" "$PROJECT_ROOT/.local/output"

link_data() {
  local source_path="$1"
  local link_name="$2"

  if [[ "$link_name" == */* || "$link_name" == "." || "$link_name" == ".." ]]; then
    echo "ERROR: link name must be a simple name: $link_name" >&2
    return 1
  fi

  ln -sfnT "$source_path" "$PROJECT_ROOT/.local/data/$link_name"

  if [[ ! -e "$source_path" ]]; then
    echo "WARNING: target does not currently exist: $source_path" >&2
  fi
}

# -----------------------------------------------------------------------------
# Project-specific data links
#
# Add only the Dropbox or local directories needed by this project.
# Keep Dropbox's existing directory structure unchanged.
#
# Examples:
# link_data "$RESEARCH_ROOT/Papers/ExampleProject" papers
# link_data "$LARGE_ROOT/ExampleData/processed" processed_data
# link_data "$LOCAL_ROOT/$PROJECT_NAME/raw" raw
# -----------------------------------------------------------------------------


echo "Local links configured for $PROJECT_NAME ($WORKSPACE_NAME):"
echo "  data:    $PROJECT_ROOT/.local/data"
echo "  scratch: $SCRATCH_DIR"
echo "  output:  $OUTPUT_DIR"
