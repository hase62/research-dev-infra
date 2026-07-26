#!/usr/bin/env bash
set -euo pipefail

YES=false

usage() {
  cat <<'USAGE'
Usage:
  setup-agent-defaults.sh [--yes]

Configures the default interactive coding models for research work:
  Codex:       GPT-5.6 with xhigh reasoning
  Claude Code: latest Opus alias with xhigh effort

The script preserves unrelated settings and creates timestamped backups.
USAGE
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
This sets the default agent configuration for research computing:

  Codex
    model = gpt-5.6
    model_reasoning_effort = xhigh
    plan_mode_reasoning_effort = xhigh

  Claude Code
    model = opus
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

stamp="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$HOME/.codex"
codex_config="$HOME/.codex/config.toml"
if [[ -f "$codex_config" ]]; then
  cp -a "$codex_config" "$codex_config.bak.$stamp"
fi

tmp_codex="$(mktemp)"
trap 'rm -f "$tmp_codex"' EXIT
if [[ -f "$codex_config" ]]; then
  awk '
    !/^[[:space:]]*model[[:space:]]*=/ &&
    !/^[[:space:]]*model_reasoning_effort[[:space:]]*=/ &&
    !/^[[:space:]]*plan_mode_reasoning_effort[[:space:]]*=/
  ' "$codex_config" > "$tmp_codex"
fi

{
  printf 'model = "gpt-5.6"\n'
  printf 'model_reasoning_effort = "xhigh"\n'
  printf 'plan_mode_reasoning_effort = "xhigh"\n'
  if [[ -s "$tmp_codex" ]]; then
    printf '\n'
    cat "$tmp_codex"
  fi
} > "$codex_config"

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

data["model"] = "opus"
data["effortLevel"] = "xhigh"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

cat <<DONE
Agent defaults configured.

Codex config:
  $codex_config

Claude Code settings:
  $claude_settings

Verify in new sessions:
  codex
    /status

  claude
    /status
    /model
    /effort

Claude Code v2.1.219 or later resolves the Anthropic API 'opus' alias to Opus 5.
Run 'claude update' if an older Opus version is shown.
DONE
