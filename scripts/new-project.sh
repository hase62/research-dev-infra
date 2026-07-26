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
  new-project PROJECT [--github [OWNER/REPO]] [--public]

Examples:
  new-project ProteomicAging
  new-project ProteomicAging --github
  new-project Sepsis.Atlas --github my-organization/Sepsis.Atlas
USAGE
}

[[ $# -ge 1 ]] || {
  usage
  exit 1
}

PROJECT="$1"
shift
validate_name "$PROJECT" "Project name"

CREATE_GITHUB=false
GITHUB_REPO=""
VISIBILITY="private"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github)
      CREATE_GITHUB=true
      if [[ $# -ge 2 && "$2" != --* ]]; then
        GITHUB_REPO="$2"
        shift 2
      else
        shift
      fi
      ;;
    --public)
      VISIBILITY="public"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

load_research_env

PROJECT_DIR="$SRC_ROOT/$PROJECT"
[[ ! -e "$PROJECT_DIR" ]] || fail "Project path already exists: $PROJECT_DIR"

mkdir -p "$PROJECT_DIR" "$WORKTREE_ROOT/$PROJECT" "$SCRATCH_ROOT/$PROJECT"
cp -a "$INFRA_ROOT/templates/project/." "$PROJECT_DIR/"
replace_placeholder "$PROJECT_DIR" "__PROJECT_NAME__" "$PROJECT"
mkdir -p "$PROJECT_DIR/analysis" "$PROJECT_DIR/docs" "$PROJECT_DIR/handoffs" "$PROJECT_DIR/tasks" "$PROJECT_DIR/tests"
touch "$PROJECT_DIR/analysis/.gitkeep" "$PROJECT_DIR/docs/.gitkeep" "$PROJECT_DIR/tasks/.gitkeep" "$PROJECT_DIR/tests/.gitkeep"
mkdir -p "$PROJECT_DIR/workspace/data"
chmod +x "$PROJECT_DIR/scripts/configure-workspace.sh"

PROJECT_ROOT="$PROJECT_DIR" WORKSPACE_NAME="main" bash "$PROJECT_DIR/scripts/configure-workspace.sh"

git -C "$PROJECT_DIR" init -b main >/dev/null
git -C "$PROJECT_DIR" add .

if ! git -C "$PROJECT_DIR" commit -m "Initialize $PROJECT" >/dev/null; then
  warn "Initial commit failed. Configure git user.name and user.email, then commit manually."
  CREATE_GITHUB=false
fi

if [[ "$CREATE_GITHUB" == true ]]; then
  command -v gh >/dev/null 2>&1 || fail "gh is required for --github"
  gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run: gh auth login"

  if [[ -z "$GITHUB_REPO" ]]; then
    OWNER="$(gh api user --jq .login)"
    GITHUB_REPO="$OWNER/$PROJECT"
  fi

  gh repo create "$GITHUB_REPO" \
    "--$VISIBILITY" \
    --source="$PROJECT_DIR" \
    --remote=origin \
    --push
fi

info "Project created: $PROJECT_DIR"
echo
echo "Next steps:"
echo "  cd '$PROJECT_DIR'"
echo "  edit PROJECT.md"
echo "  edit scripts/configure-workspace.sh"
echo "  setup-workspace"
echo "  code ."
if [[ "$CREATE_GITHUB" != true ]]; then
  echo "  connect the repository to GitHub when ready"
fi
