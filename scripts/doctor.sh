#!/usr/bin/env bash
set -uo pipefail

PROJECT="${1:-}"
FAILURES=0
WARNINGS=0

ok() { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail_check() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

OS="${RESEARCH_PLATFORM_OVERRIDE:-$(uname -s)}"
case "$OS" in
  Darwin)
    PLATFORM="macOS"
    ok "Running on macOS"
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="WSL2"
      ok "Running under WSL2"
    else
      PLATFORM="unsupported Linux"
      fail_check "Linux was detected outside WSL2"
    fi
    ;;
  *)
    PLATFORM="unsupported"
    fail_check "Unsupported operating system: $OS"
    ;;
esac

if [[ -f "$HOME/.research_env" ]]; then
  ok "$HOME/.research_env exists"
  # shellcheck disable=SC1090
  source "$HOME/.research_env"
else
  fail_check "$HOME/.research_env is missing"
fi

for command_name in git bash curl python3; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    fail_check "$command_name is not installed"
  fi
done

for command_name in gh conda mamba codex claude code emacs; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    warn "$command_name is not installed or not on PATH"
  fi
done

if command -v python3 >/dev/null 2>&1; then
  if [[ -f "$HOME/.codex/config.toml" ]]; then
    if python3 - "$HOME/.codex/config.toml" <<'PYCODEX'
import sys
import tomllib
from pathlib import Path

path = Path(sys.argv[1])
with path.open("rb") as handle:
    data = tomllib.load(handle)
expected = {
    "model": "gpt-5.6",
    "model_reasoning_effort": "xhigh",
    "plan_mode_reasoning_effort": "xhigh",
}
raise SystemExit(0 if all(data.get(k) == v for k, v in expected.items()) else 1)
PYCODEX
    then
      ok "Codex defaults: gpt-5.6 / xhigh; Plan Mode xhigh"
    else
      warn "Codex defaults differ from the research standard; run setup-agent-defaults"
    fi
  else
    warn "$HOME/.codex/config.toml is missing; run setup-agent-defaults"
  fi

  if [[ -f "$HOME/.claude/settings.json" ]]; then
    if python3 - "$HOME/.claude/settings.json" <<'PYCLAUDE'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
expected = {
    "autoUpdatesChannel": "stable",
    "model": "opus",
    "effortLevel": "xhigh",
}
raise SystemExit(0 if all(data.get(k) == v for k, v in expected.items()) else 1)
PYCLAUDE
    then
      ok "Claude Code defaults: stable channel; opus / xhigh"
    else
      warn "Claude Code defaults differ from the research standard; run setup-agent-defaults"
    fi
  else
    warn "$HOME/.claude/settings.json is missing; run setup-agent-defaults"
  fi
fi

if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
  warn "ANTHROPIC_MODEL overrides the Claude Code model default"
fi
if [[ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]]; then
  warn "CLAUDE_CODE_EFFORT_LEVEL overrides the Claude Code effort default"
fi
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  warn "OPENAI_API_KEY is set; verify that Codex is using ChatGPT subscription authentication"
fi
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  warn "ANTHROPIC_API_KEY is set; Claude Code may use API billing instead of the subscription"
fi

if command -v code >/dev/null 2>&1; then
  extensions="$(code --list-extensions 2>/dev/null || true)"
  expected_extensions=(openai.chatgpt anthropic.claude-code ms-python.python ms-toolsai.jupyter reditorsupport.r)
  if [[ "$PLATFORM" == "WSL2" ]]; then
    expected_extensions=(ms-vscode-remote.remote-wsl "${expected_extensions[@]}")
  fi
  for extension in "${expected_extensions[@]}"; do
    if grep -Fqi "$extension" <<<"$extensions"; then
      ok "VS Code extension: $extension"
    else
      warn "VS Code extension is not installed: $extension (run setup-vscode)"
    fi
  done
fi

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

for variable_name in AICODE_RESEARCH_INPUT_ROOT AICODE_RESEARCH_OUTPUT_ROOT AICODE_LARGE_INPUT_ROOT AICODE_LARGE_OUTPUT_ROOT SRC_ROOT WORKTREE_ROOT SCRATCH_ROOT; do
  value="${!variable_name:-}"
  if [[ -n "$value" && -e "$value" ]]; then
    ok "$variable_name -> $value"
  elif [[ -n "$value" ]]; then
    fail_check "$variable_name target does not exist: $value"
  else
    fail_check "$variable_name is not set"
  fi
done

for legacy_variable in DROPBOX_ROOT RESEARCH_ROOT LARGE_ROOT; do
  if [[ -n "${!legacy_variable:-}" ]]; then
    warn "$legacy_variable is still set in the current shell; open a new shell or rerun setup-machine"
  fi
done

[[ "${AICODE_RESEARCH_INPUT_ROOT:-}" == */Research/aicode/input ]] || fail_check "AICODE_RESEARCH_INPUT_ROOT has an unexpected path"
[[ "${AICODE_RESEARCH_OUTPUT_ROOT:-}" == */Research/aicode/output ]] || fail_check "AICODE_RESEARCH_OUTPUT_ROOT has an unexpected path"
[[ "${AICODE_LARGE_INPUT_ROOT:-}" == */ForShareLargeData/aicode/input ]] || fail_check "AICODE_LARGE_INPUT_ROOT has an unexpected path"
[[ "${AICODE_LARGE_OUTPUT_ROOT:-}" == */ForShareLargeData/aicode/output ]] || fail_check "AICODE_LARGE_OUTPUT_ROOT has an unexpected path"

if [[ -e "$HOME/data-roots" || -L "$HOME/data-roots" ]]; then
  warn "Legacy ~/data-roots remains; rerun setup-machine and inspect any preserved non-symlink contents"
fi

if [[ -n "$PROJECT" && -n "${SRC_ROOT:-}" ]]; then
  REPO="$SRC_ROOT/$PROJECT"
  echo
  echo "Project: $PROJECT"

  if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "Git repository: $REPO"
  else
    fail_check "Git repository not found: $REPO"
  fi

  for file_name in PROJECT.md AGENTS.md CLAUDE.md scripts/configure-workspace.sh; do
    if [[ -f "$REPO/$file_name" ]]; then
      ok "$file_name"
    else
      fail_check "$file_name is missing"
    fi
  done

  if [[ -d "$REPO/workspace" ]]; then
    ok "workspace directory"
    while IFS= read -r link_path; do
      if [[ -e "$link_path" ]]; then
        ok "link: ${link_path#$REPO/} -> $(readlink "$link_path")"
      else
        warn "broken link: ${link_path#$REPO/} -> $(readlink "$link_path")"
      fi
    done < <(find "$REPO/workspace" -maxdepth 2 -type l -print 2>/dev/null)
  else
    warn "workspace directory is missing; run setup-workspace in the project"
  fi
fi

echo
echo "Failures: $FAILURES; warnings: $WARNINGS"
[[ $FAILURES -eq 0 ]]
