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
  remove-worktree PROJECT MODE TASK [--delete-branch]

The worktree path is always local to the current computer. --delete-branch
also deletes the local task branch after Git confirms that it is merged. It
does not delete the branch from GitHub.

Examples:
  remove-worktree Sepsis.Atlas shared metadata-audit
  remove-worktree Sepsis.Atlas shared task-002-qc-pipeline --delete-branch
USAGE
}

[[ $# -ge 3 && $# -le 4 ]] || {
  usage
  exit 1
}

PROJECT="$1"
MODE="$2"
TASK="$3"
DELETE_BRANCH=false

if [[ "${4:-}" == "--delete-branch" ]]; then
  DELETE_BRANCH=true
elif [[ $# -eq 4 ]]; then
  fail "Unknown option: $4"
fi

validate_name "$PROJECT" "Project name"
validate_name "$MODE" "Mode name"
validate_name "$TASK" "Task name"
load_research_env

REPO="$SRC_ROOT/$PROJECT"
if [[ "$MODE" == "shared" ]]; then
  WORKSPACE="shared-$TASK"
  BRANCH="work/$TASK"
else
  WORKSPACE="$MODE-$TASK"
  BRANCH="agent/$MODE/$TASK"
fi
TARGET="$WORKTREE_ROOT/$PROJECT/$WORKSPACE"

[[ -d "$TARGET" ]] || fail "Worktree path was not found: $TARGET"

if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
  fail "Worktree has uncommitted changes and was not removed: $TARGET"
fi

git -C "$REPO" worktree remove "$TARGET"

info "Worktree removed: $TARGET"

if [[ "$DELETE_BRANCH" == true ]]; then
  if git -C "$REPO" branch -d "$BRANCH"; then
    echo "Local branch deleted: $BRANCH"
  else
    warn "The worktree was removed, but the local branch was retained because Git does not consider it merged: $BRANCH"
    warn "Verify the PR/merge before deleting it manually. A squash merge may require an explicit force delete after verification."
    exit 1
  fi
else
  echo "Local branch retained: $BRANCH"
fi

echo "Remote branch is unchanged. Delete it through the merged PR setting or with:"
echo "  git -C '$REPO' push origin --delete '$BRANCH'"
