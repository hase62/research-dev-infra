#!/usr/bin/env bash
set -uo pipefail

PROJECT="${1:-}"
FAILURES=0
WARNINGS=0

ok() { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail_check() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

if [[ -f "$HOME/.research_env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.research_env"
else
  fail_check "$HOME/.research_env is missing"
fi

if [[ -z "$PROJECT" ]]; then
  if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    PROJECT="$(basename "$REPO_ROOT")"
  else
    echo "Usage: analysis-smoke-test PROJECT" >&2
    exit 1
  fi
fi

REPO="${SRC_ROOT:-$HOME/src}/$PROJECT"
if [[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == *"/worktrees/"* ]]; then
  REPO="$(git rev-parse --show-toplevel)"
elif [[ -d "$PWD/.git" && "$(basename "$PWD")" == "$PROJECT" ]]; then
  REPO="$PWD"
fi

printf 'Project: %s\nPath:    %s\n\n' "$PROJECT" "$REPO"

[[ -d "$REPO" ]] && ok "project directory exists" || fail_check "project directory not found"
[[ -d "$REPO/.git" || -f "$REPO/.git" ]] && ok "Git working tree" || fail_check "not a Git working tree"

workspace_names=(research-input research-output large-input large-output scratch)
for workspace_name in "${workspace_names[@]}"; do
  workspace_path="$REPO/workspace/$workspace_name"
  if [[ -L "$workspace_path" && -e "$workspace_path" ]]; then
    ok "workspace link: workspace/$workspace_name -> $(readlink "$workspace_path")"
  elif [[ -L "$workspace_path" ]]; then
    fail_check "broken workspace link: workspace/$workspace_name -> $(readlink "$workspace_path")"
  else
    fail_check "missing workspace link: workspace/$workspace_name"
  fi
done

if [[ -d "$REPO/workspace/scratch" && -w "$REPO/workspace/scratch" ]]; then
  TEST_FILE="$REPO/workspace/scratch/.write_test_$$"
  if printf 'research-dev-infra smoke test\n' > "$TEST_FILE" && rm -f "$TEST_FILE"; then
    ok "scratch is writable"
  else
    fail_check "scratch write test failed"
  fi
fi

for output_name in research-output large-output; do
  output_path="$REPO/workspace/$output_name"
  if [[ -d "$output_path" && -w "$output_path" ]]; then
    ok "$output_name is writable"
  else
    fail_check "$output_name is not writable"
  fi
done

if command -v python >/dev/null 2>&1; then
  if python - <<'PY'
import platform
print(platform.python_version())
PY
  then
    ok "Python executes"
  else
    fail_check "Python execution failed"
  fi
else
  warn "Python is not available in the active shell/environment"
fi

if command -v Rscript >/dev/null 2>&1; then
  if Rscript -e 'cat(as.character(getRversion()), "\n")'; then
    ok "R executes"
  else
    fail_check "R execution failed"
  fi
else
  warn "Rscript is not available in the active shell/environment"
fi

if command -v git >/dev/null 2>&1; then
  git -C "$REPO" status --short
  ok "git status completed"
fi

printf '\nFailures: %d; warnings: %d\n' "$FAILURES" "$WARNINGS"
[[ $FAILURES -eq 0 ]]
