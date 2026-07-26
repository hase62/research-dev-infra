#!/usr/bin/env bash
set -euo pipefail

YES=false
CLAUDE_MIN_VERSION="2.1.219"

usage() {
  cat <<'USAGE'
Usage:
  setup-agent-defaults.sh [--yes]

Configures the persistent default interactive coding models for research work:
  Codex:       gpt-5.6 with xhigh reasoning
  Codex Plan:  gpt-5.6 with xhigh reasoning
  Claude Code: claude-opus-5 with xhigh effort

The script preserves unrelated settings and creates timestamped backups.
Claude Code 2.1.219 or later is required for claude-opus-5.
USAGE
}

version_ge() {
  local current="$1"
  local required="$2"
  [[ "$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n 1)" == "$required" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cat <<'NOTICE'
This sets the persistent default agent configuration for research computing:

  Codex
    model = gpt-5.6
    model_reasoning_effort = xhigh
    plan_mode_reasoning_effort = xhigh

  Claude Code
    model = claude-opus-5
    effortLevel = xhigh

Use max only for a specific difficult session rather than as the persistent default.
NOTICE

if [[ "$YES" != true ]]; then
  read -r -p "Type AGENTS to continue: " answer
  [[ "$answer" == "AGENTS" ]] || {
    echo "Cancelled."
    exit 0
  }
fi

if command -v claude >/dev/null 2>&1; then
  claude_version="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
  if [[ -n "$claude_version" ]] && ! version_ge "$claude_version" "$CLAUDE_MIN_VERSION"; then
    echo "Claude Code $claude_version is older than the required $CLAUDE_MIN_VERSION."
    if [[ "$YES" == true ]]; then
      update_answer="y"
    else
      read -r -p "Run 'claude update' now? [Y/n] " update_answer
      update_answer="${update_answer:-y}"
    fi
    if [[ "$update_answer" =~ ^[Yy]$ ]]; then
      claude update
      hash -r
      claude_version="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
    fi
    if [[ -z "$claude_version" ]] || ! version_ge "$claude_version" "$CLAUDE_MIN_VERSION"; then
      echo "ERROR: Claude Code $CLAUDE_MIN_VERSION or later is required." >&2
      echo "Run: claude update" >&2
      exit 1
    fi
  fi
else
  echo "WARNING: Claude Code is not installed. The settings will be written now," >&2
  echo "         but install Claude Code 2.1.219 or later before using claude-opus-5." >&2
fi

stamp="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$HOME/.codex"
codex_config="$HOME/.codex/config.toml"
if [[ -f "$codex_config" ]]; then
  cp -a "$codex_config" "$codex_config.bak.$stamp"
fi

python3 - "$codex_config" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.exists() else ""
lines = text.splitlines(keepends=True)
keys = {"model", "model_reasoning_effort", "plan_mode_reasoning_effort"}
key_re = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=")
table_re = re.compile(r"^\s*\[")

kept = []
in_root = True
for line in lines:
    if table_re.match(line):
        in_root = False
    match = key_re.match(line)
    if in_root and match and match.group(1) in keys:
        continue
    kept.append(line)

prefix = (
    'model = "gpt-5.6"\n'
    'model_reasoning_effort = "xhigh"\n'
    'plan_mode_reasoning_effort = "xhigh"\n'
)
remainder = "".join(kept).lstrip("\n")
path.write_text(prefix + ("\n" + remainder if remainder else ""), encoding="utf-8")
PY

mkdir -p "$HOME/.claude"
claude_settings="$HOME/.claude/settings.json"
if [[ -f "$claude_settings" ]]; then
  cp -a "$claude_settings" "$claude_settings.bak.$stamp"
fi

python3 - "$claude_settings" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if path.exists() and path.stat().st_size:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid JSON in {path}: {exc}")
else:
    data = {}

if not isinstance(data, dict):
    raise SystemExit(f"ERROR: expected a JSON object in {path}")

data["model"] = "claude-opus-5"
data["effortLevel"] = "xhigh"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 - "$codex_config" "$claude_settings" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

codex_path = Path(sys.argv[1])
claude_path = Path(sys.argv[2])
with codex_path.open("rb") as handle:
    codex = tomllib.load(handle)
claude = json.loads(claude_path.read_text(encoding="utf-8"))

expected_codex = {
    "model": "gpt-5.6",
    "model_reasoning_effort": "xhigh",
    "plan_mode_reasoning_effort": "xhigh",
}
for key, expected in expected_codex.items():
    actual = codex.get(key)
    if actual != expected:
        raise SystemExit(f"ERROR: {codex_path}: {key}={actual!r}, expected {expected!r}")

expected_claude = {"model": "claude-opus-5", "effortLevel": "xhigh"}
for key, expected in expected_claude.items():
    actual = claude.get(key)
    if actual != expected:
        raise SystemExit(f"ERROR: {claude_path}: {key}={actual!r}, expected {expected!r}")
PY

cat <<DONE
Agent defaults configured and validated.

Codex config:
  $codex_config
  model = gpt-5.6
  model_reasoning_effort = xhigh
  plan_mode_reasoning_effort = xhigh

Claude Code settings:
  $claude_settings
  model = claude-opus-5
  effortLevel = xhigh

Start new sessions and verify:
  codex
    /status

  claude
    /status
    /model
    /effort

Do not use 'claude --resume' or 'claude --continue' for the first verification:
a resumed session retains the model used when that session was saved.
DONE

if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
  echo "WARNING: ANTHROPIC_MODEL is set and overrides the Claude model setting." >&2
fi
if [[ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]]; then
  echo "WARNING: CLAUDE_CODE_EFFORT_LEVEL is set and overrides effortLevel." >&2
fi
