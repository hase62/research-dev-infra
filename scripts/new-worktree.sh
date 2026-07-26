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
           and Claude Code. Recommended for long tasks and cross-PC handoff.
  codex    Agent-specific worktree.
  claude   Agent-specific worktree.

Behavior:
  - If the task branch does not exist, create it from BASE (default: main).
  - If the task branch exists locally, attach a new local worktree to it.
  - If origin has the task branch, create a local tracking branch and resume it.

This means the same command can start a task on one PC and reconstruct its
worktree on another PC after the branch has been committed and pushed.

Examples:
  new-worktree Sepsis.Atlas shared task-001-qc
  new-worktree Sepsis.Atlas codex task-001-qc
  new-worktree Sepsis.Atlas claude review-001-qc work/task-001-qc
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

# Refresh remote branch information when origin is available. Network failure
# does not prevent creating a new local task from an already available base.
if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
  if ! git -C "$REPO" fetch origin --prune; then
    warn "Could not fetch origin. Continuing with the refs currently available locally."
  fi
fi

LOCAL_REF="refs/heads/$BRANCH"
REMOTE_REF="refs/remotes/origin/$BRANCH"
ACTION="created"

if git -C "$REPO" show-ref --verify --quiet "$LOCAL_REF"; then
  if git -C "$REPO" worktree list --porcelain | grep -Fqx "branch $LOCAL_REF"; then
    fail "Branch is already checked out in another worktree: $BRANCH"
  fi
  git -C "$REPO" worktree add "$TARGET" "$BRANCH"
  ACTION="resumed from local branch"
elif git -C "$REPO" show-ref --verify --quiet "$REMOTE_REF"; then
  git -C "$REPO" worktree add --track -b "$BRANCH" "$TARGET" "origin/$BRANCH"
  ACTION="resumed from origin/$BRANCH"
else
  git -C "$REPO" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || fail "Base was not found: $BASE"
  git -C "$REPO" worktree add -b "$BRANCH" "$TARGET" "$BASE"
  ACTION="created from $BASE"
fi

mkdir -p "$TARGET/.local/data"
printf '%s\n' "$WORKSPACE" > "$TARGET/.local/workspace-name"

if [[ -x "$TARGET/scripts/setup-local-links.sh" ]]; then
  PROJECT_ROOT="$TARGET" WORKSPACE_NAME="$WORKSPACE" bash "$TARGET/scripts/setup-local-links.sh"
elif [[ -d "$REPO/.local/data" ]]; then
  cp -a "$REPO/.local/data/." "$TARGET/.local/data/"
  mkdir -p "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/scratch" "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/output"
  replace_symlink "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/scratch" "$TARGET/.local/scratch"
  replace_symlink "$SCRATCH_ROOT/$PROJECT/$WORKSPACE/output" "$TARGET/.local/output"
fi

info "Worktree ready"
echo "  action: $ACTION"
echo "  branch: $BRANCH"
echo "  path:   $TARGET"
echo
echo "Start with:"
echo "  cd '$TARGET'"
echo "  code ."
echo "  Then use the Codex or Claude Code VS Code extension."
echo "  The integrated terminal can also run: codex or claude"
echo
if [[ "$ACTION" == created* ]]; then
  echo "Before moving to another PC:"
  echo "  git add <reviewed-files>"
  echo "  git commit -m 'WIP: describe current state'"
  echo "  git push -u origin '$BRANCH'"
else
  echo "This worktree was reconstructed from an existing task branch."
  echo "Check handoffs/CURRENT.md, git status, and git branch -vv before continuing."
fi
if [[ "$MODE" == "shared" ]]; then
  echo "Do not give both agents editing tasks in this worktree at the same time."
else
  echo "Intended agent: $MODE"
fi
