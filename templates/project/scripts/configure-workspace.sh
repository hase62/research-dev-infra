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

for variable_name in \
  AICODE_RESEARCH_INOUT_ROOT \
  AICODE_RESEARCH_OUTPUT_ROOT \
  AICODE_LARGE_INPUT_ROOT \
  AICODE_LARGE_OUTPUT_ROOT \
  SCRATCH_ROOT
 do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "ERROR: $variable_name is not set in $HOME/.research_env" >&2
    exit 1
  fi
done

if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: unsafe project name: $PROJECT_NAME" >&2
  exit 1
fi

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

RESEARCH_INOUT_DIR="$AICODE_RESEARCH_INOUT_ROOT/$PROJECT_NAME"
RESEARCH_OUTPUT_DIR="$AICODE_RESEARCH_OUTPUT_ROOT/$PROJECT_NAME"
LARGE_INPUT_DIR="$AICODE_LARGE_INPUT_ROOT/$PROJECT_NAME"
LARGE_OUTPUT_DIR="$AICODE_LARGE_OUTPUT_ROOT/$PROJECT_NAME"
SCRATCH_DIR="$SCRATCH_ROOT/$PROJECT_NAME/$WORKSPACE_NAME"

mkdir -p \
  "$RESEARCH_INOUT_DIR" \
  "$RESEARCH_OUTPUT_DIR" \
  "$LARGE_INPUT_DIR" \
  "$LARGE_OUTPUT_DIR" \
  "$SCRATCH_DIR"

mkdir -p "$PROJECT_ROOT/workspace"

for workspace_name in \
  research-inout \
  research-output \
  large-input \
  large-output \
  scratch
 do
  workspace_path="$PROJECT_ROOT/workspace/$workspace_name"
  if [[ -e "$workspace_path" && ! -L "$workspace_path" ]]; then
    echo "ERROR: refusing to replace a non-symlink path: $workspace_path" >&2
    exit 1
  fi
done

replace_link "$RESEARCH_INOUT_DIR" "$PROJECT_ROOT/workspace/research-inout"
replace_link "$RESEARCH_OUTPUT_DIR" "$PROJECT_ROOT/workspace/research-output"
replace_link "$LARGE_INPUT_DIR" "$PROJECT_ROOT/workspace/large-input"
replace_link "$LARGE_OUTPUT_DIR" "$PROJECT_ROOT/workspace/large-output"
replace_link "$SCRATCH_DIR" "$PROJECT_ROOT/workspace/scratch"

echo "Workspace configured for $PROJECT_NAME ($WORKSPACE_NAME):"
echo "  research-inout:  $RESEARCH_INOUT_DIR"
echo "  research-output: $RESEARCH_OUTPUT_DIR"
echo "  large-input:     $LARGE_INPUT_DIR"
echo "  large-output:    $LARGE_OUTPUT_DIR"
echo "  scratch:         $SCRATCH_DIR"
