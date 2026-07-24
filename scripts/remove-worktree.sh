#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" == /* ]] || SCRIPT_PATH="$SCRIPT_LINK_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  remove-worktree PROJECT AGENT TASK [--delete-branch]
USAGE
}

[[ $# -ge 3 && $# -le 4 ]] || {
  usage
  exit 1
}

PROJECT="$1"
AGENT="$2"
TASK="$3"
DELETE_BRANCH=false

if [[ "${4:-}" == "--delete-branch" ]]; then
  DELETE_BRANCH=true
elif [[ $# -eq 4 ]]; then
  fail "Unknown option: $4"
fi

validate_name "$PROJECT" "Project name"
validate_name "$AGENT" "Agent name"
validate_name "$TASK" "Task name"
load_research_env

REPO="$SRC_ROOT/$PROJECT"
WORKSPACE="$AGENT-$TASK"
TARGET="$WORKTREE_ROOT/$PROJECT/$WORKSPACE"
BRANCH="agent/$AGENT/$TASK"

[[ -d "$TARGET" ]] || fail "Worktree path was not found: $TARGET"

if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
  fail "Worktree has uncommitted changes and was not removed: $TARGET"
fi

git -C "$REPO" worktree remove "$TARGET"

if [[ "$DELETE_BRANCH" == true ]]; then
  git -C "$REPO" branch -d "$BRANCH"
fi

info "Worktree removed: $TARGET"
if [[ "$DELETE_BRANCH" != true ]]; then
  echo "Branch retained: $BRANCH"
fi
