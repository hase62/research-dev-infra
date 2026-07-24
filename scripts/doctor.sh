#!/usr/bin/env bash
set -uo pipefail

PROJECT="${1:-}"
FAILURES=0
WARNINGS=0

ok() { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail_check() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

if grep -qi microsoft /proc/version 2>/dev/null; then
  ok "Running under WSL"
else
  warn "WSL was not detected"
fi

if [[ -f "$HOME/.research_env" ]]; then
  ok "$HOME/.research_env exists"
  # shellcheck disable=SC1090
  source "$HOME/.research_env"
else
  fail_check "$HOME/.research_env is missing"
fi

for command_name in git bash curl; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    fail_check "$command_name is not installed"
  fi
done

for command_name in gh conda mamba codex claude code; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    warn "$command_name is not installed or not on PATH"
  fi
done


if command -v git >/dev/null 2>&1; then
  git_name="$(git config --global user.name 2>/dev/null || true)"
  git_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$git_name" && -n "$git_email" ]]; then
    ok "Git identity: $git_name <$git_email>"
  else
    warn "Git user.name or user.email is not configured"
  fi
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ok "GitHub CLI authentication"
  else
    warn "GitHub CLI is not authenticated; run gh auth login"
  fi
fi

for variable_name in RESEARCH_ROOT LARGE_ROOT LOCAL_ROOT SRC_ROOT WORKTREE_ROOT SCRATCH_ROOT; do
  value="${!variable_name:-}"
  if [[ -n "$value" && -e "$value" ]]; then
    ok "$variable_name -> $value"
  elif [[ -n "$value" ]]; then
    fail_check "$variable_name target does not exist: $value"
  else
    fail_check "$variable_name is not set"
  fi
done

if [[ -n "$PROJECT" && -n "${SRC_ROOT:-}" ]]; then
  REPO="$SRC_ROOT/$PROJECT"
  echo
  echo "Project: $PROJECT"

  if [[ -d "$REPO/.git" ]]; then
    ok "Git repository: $REPO"
  else
    fail_check "Git repository not found: $REPO"
  fi

  for file_name in PROJECT.md AGENTS.md CLAUDE.md scripts/setup-local-links.sh; do
    if [[ -f "$REPO/$file_name" ]]; then
      ok "$file_name"
    else
      fail_check "$file_name is missing"
    fi
  done

  if [[ -d "$REPO/.local" ]]; then
    ok ".local directory"
    while IFS= read -r link_path; do
      if [[ -e "$link_path" ]]; then
        ok "link: ${link_path#$REPO/} -> $(readlink "$link_path")"
      else
        warn "broken link: ${link_path#$REPO/} -> $(readlink "$link_path")"
      fi
    done < <(find "$REPO/.local" -maxdepth 2 -type l -print 2>/dev/null)
  else
    warn ".local directory is missing; run setup-project-links in the project"
  fi
fi

echo
echo "Failures: $FAILURES; warnings: $WARNINGS"
[[ $FAILURES -eq 0 ]]
