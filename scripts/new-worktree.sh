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
  - If the task branch exists locally, attach a worktree and fast-forward it
    from origin when possible.
  - If only origin has the task branch, create a local tracking branch and
    resume it.

Use one unique TASK name for one logical task. Reuse the same TASK name while
that task is active, including on another PC. After merge, remove the worktree
and branches; use a new TASK name for the next task.

Examples:
  new-worktree Sepsis.Atlas shared metadata-audit
  new-worktree Sepsis.Atlas shared task-002-qc-pipeline
  new-worktree Sepsis.Atlas claude review-metadata-audit work/metadata-audit
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

  if git -C "$REPO" show-ref --verify --quiet "$REMOTE_REF"; then
    git -C "$TARGET" branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true

    if git -C "$REPO" merge-base --is-ancestor "$LOCAL_REF" "$REMOTE_REF"; then
      if [[ "$(git -C "$REPO" rev-parse "$LOCAL_REF")" != "$(git -C "$REPO" rev-parse "$REMOTE_REF")" ]]; then
        git -C "$TARGET" merge --ff-only "origin/$BRANCH"
        ACTION="resumed from local branch and fast-forwarded from origin/$BRANCH"
      else
        ACTION="resumed from local branch (already synchronized with origin/$BRANCH)"
      fi
    elif git -C "$REPO" merge-base --is-ancestor "$REMOTE_REF" "$LOCAL_REF"; then
      ACTION="resumed from local branch (local commits are ahead of origin/$BRANCH)"
    else
      warn "Local and remote task branches have diverged: $BRANCH"
      warn "The worktree was created without merging. Inspect both histories before continuing."
      ACTION="resumed from diverged local branch"
    fi
  fi
elif git -C "$REPO" show-ref --verify --quiet "$REMOTE_REF"; then
  git -C "$REPO" worktree add --track -b "$BRANCH" "$TARGET" "origin/$BRANCH"
  ACTION="resumed from origin/$BRANCH"
else
  git -C "$REPO" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || fail "Base was not found: $BASE"
  git -C "$REPO" worktree add -b "$BRANCH" "$TARGET" "$BASE"
  ACTION="created from $BASE"
fi

mkdir -p "$TARGET/workspace"

if [[ -x "$TARGET/scripts/configure-workspace.sh" ]]; then
  PROJECT_ROOT="$TARGET" WORKSPACE_NAME="$WORKSPACE" bash "$TARGET/scripts/configure-workspace.sh"
else
  warn "scripts/configure-workspace.sh is missing; workspace links were not created"
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
