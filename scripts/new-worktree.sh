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
  new-worktree PROJECT MODE TASK [BASE]

MODE may be:
  shared   A switchable task worktree that can be used sequentially by Codex
           and Claude Code. Recommended when switching after a usage limit.
  codex    Agent-specific worktree.
  claude   Agent-specific worktree.

Examples:
  new-worktree Sepsis.Atlas shared task-001-qc
  new-worktree Sepsis.Atlas codex task-001-qc
  new-worktree Sepsis.Atlas claude review-001-qc agent/codex/task-001-qc
USAGE
}

[[ $# -ge 3 && $# -le 4 ]] || {
  usage
  exit 1
}

PROJECT="$1"
MODE="$2"
TASK="$3"
BASE="${4:-main}"

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

[[ -d "$REPO/.git" ]] || fail "Git repository was not found: $REPO"
[[ ! -e "$TARGET" ]] || fail "Worktree path already exists: $TARGET"

if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
  fail "Main working tree has uncommitted changes. Commit or stash them first: $REPO"
fi

if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  fail "Branch already exists: $BRANCH"
fi

mkdir -p "$WORKTREE_ROOT/$PROJECT"
git -C "$REPO" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || fail "Base was not found: $BASE"
git -C "$REPO" worktree add -b "$BRANCH" "$TARGET" "$BASE"

mkdir -p "$TARGET/.local/data"
printf '%s\n' "$WORKSPACE" > "$TARGET/.local/workspace-name"

if [[ -x "$TARGET/scripts/setup-local-links.sh" ]]; then
  PROJECT_ROOT="$TARGET" WORKSPACE_NAME="$WORKSPACE" bash "$TARGET/scripts/setup-local-links.sh"
elif [[ -d "$REPO/.local/data" ]]; then
  cp -a "$REPO/.local/data/." "$TARGET/.local/data/"
  mkdir -p "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/scratch" "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/output"
  ln -sfnT "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/scratch" "$TARGET/.local/scratch"
  ln -sfnT "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/output" "$TARGET/.local/output"
fi

info "Worktree created"
echo "  branch: $BRANCH"
echo "  path:   $TARGET"
echo
echo "Start with:"
echo "  cd '$TARGET'"
echo "  code ."
if [[ "$MODE" == "shared" ]]; then
  echo "  then start either: codex"
  echo "  or:                claude"
  echo "  Do not run both against this worktree at the same time."
else
  echo "  $MODE"
fi
