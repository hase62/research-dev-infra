#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
DROPBOX_ROOT_ARG=""
INFRA_ROOT="${HOME}/src/research-dev-infra"
ALLOW_NON_WSL=0

usage() {
  cat <<'USAGE'
Usage:
  migrate-existing-wsl-home.sh [--dry-run] [--apply]
                               [--dropbox-root PATH]
                               [--infra-root PATH]
                               [--force-non-wsl]

Migrate an existing WSL2 home setup without modifying project repositories
under ~/src. Default behavior is --dry-run.

The resulting shared roots are limited to:
  Research/aicode/inout
  Research/aicode/output
  ForShareLargeData/aicode/input
  ForShareLargeData/aicode/output
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --apply) MODE="apply"; shift ;;
    --dropbox-root)
      [[ $# -ge 2 ]] || { echo "ERROR: --dropbox-root requires a path" >&2; exit 2; }
      DROPBOX_ROOT_ARG="$2"; shift 2 ;;
    --infra-root)
      [[ $# -ge 2 ]] || { echo "ERROR: --infra-root requires a path" >&2; exit 2; }
      INFRA_ROOT="$2"; shift 2 ;;
    --force-non-wsl) ALLOW_NON_WSL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ $ALLOW_NON_WSL -ne 1 ]] && ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  echo "ERROR: this migration is intended for WSL2." >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required." >&2; exit 1; }

normalize_path() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

candidate_is_valid() {
  [[ -d "$1/Research" && -d "$1/ForShareLargeData" ]]
}

CANDIDATES=()
add_candidate() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 0
  value="$(normalize_path "$value")"
  local existing
  for existing in "${CANDIDATES[@]:-}"; do
    [[ "$existing" == "$value" ]] && return 0
  done
  CANDIDATES+=("$value")
}

if [[ -n "$DROPBOX_ROOT_ARG" ]]; then
  add_candidate "$DROPBOX_ROOT_ARG"
else
  if [[ -f "$HOME/.research_env" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.research_env" || true
    for value in \
      "${DROPBOX_ROOT:-}" \
      "${RESEARCH_ROOT:+$(dirname "$RESEARCH_ROOT")}" \
      "${LARGE_ROOT:+$(dirname "$LARGE_ROOT")}" \
      "${AICODE_RESEARCH_INOUT_ROOT:+$(dirname "$(dirname "$(dirname "$AICODE_RESEARCH_INOUT_ROOT")")")}"; do
      add_candidate "$value"
    done
  fi
  if command -v cmd.exe >/dev/null 2>&1; then
    win_user="$(cmd.exe /C 'echo %USERNAME%' 2>/dev/null | tr -d '\r' | tail -n 1)"
    [[ -n "$win_user" ]] && add_candidate "/mnt/c/Users/$win_user/Dropbox"
  fi
  while IFS= read -r path; do add_candidate "$path"; done < <(find /mnt/c/Users -maxdepth 2 -type d -name Dropbox -print 2>/dev/null || true)
fi

VALID=()
for candidate in "${CANDIDATES[@]:-}"; do
  candidate_is_valid "$candidate" && VALID+=("$candidate")
done

if [[ ${#VALID[@]} -ne 1 ]]; then
  echo "ERROR: expected exactly one Dropbox root containing Research and ForShareLargeData." >&2
  printf '  candidate: %s\n' "${VALID[@]:-<none>}" >&2
  echo "Use --dropbox-root PATH." >&2
  exit 1
fi

DROPBOX_ROOT_NEW="${VALID[0]}"
AICODE_RESEARCH_INOUT_ROOT_NEW="$DROPBOX_ROOT_NEW/Research/aicode/inout"
AICODE_RESEARCH_OUTPUT_ROOT_NEW="$DROPBOX_ROOT_NEW/Research/aicode/output"
AICODE_LARGE_INPUT_ROOT_NEW="$DROPBOX_ROOT_NEW/ForShareLargeData/aicode/input"
AICODE_LARGE_OUTPUT_ROOT_NEW="$DROPBOX_ROOT_NEW/ForShareLargeData/aicode/output"

printf 'Mode:                    %s\n' "$MODE"
printf 'Research in/out root:    %s\n' "$AICODE_RESEARCH_INOUT_ROOT_NEW"
printf 'Research output root:    %s\n' "$AICODE_RESEARCH_OUTPUT_ROOT_NEW"
printf 'Large input root:        %s\n' "$AICODE_LARGE_INPUT_ROOT_NEW"
printf 'Large output root:       %s\n' "$AICODE_LARGE_OUTPUT_ROOT_NEW"
printf 'Infra repository:        %s\n' "$INFRA_ROOT"

echo
cat <<'PLAN'
Planned changes outside ~/src:
  - Back up and update ~/.research_env.
  - Remove legacy broad Dropbox variables managed by older infra versions.
  - Ensure ~/.bashrc sources ~/.research_env and adds ~/.local/bin.
  - Create ~/worktrees, ~/scratch, ~/.local/bin, and the four fixed Dropbox roots.
  - Remove only known symlinks from ~/data-roots; preserve unexpected entries.
  - Refresh setup-workspace and verifier command symlinks when available.
PLAN

if [[ "$MODE" == "dry-run" ]]; then
  echo
  printf 'No changes made. Apply with:\n  %q --apply --dropbox-root %q\n' "$0" "$DROPBOX_ROOT_NEW"
  exit 0
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
[[ -f "$HOME/.research_env" ]] && cp "$HOME/.research_env" "$HOME/.research_env.backup.$timestamp"
[[ -f "$HOME/.bashrc" ]] && cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$timestamp"

mkdir -p \
  "$HOME/worktrees" \
  "$HOME/scratch" \
  "$HOME/.local/bin" \
  "$AICODE_RESEARCH_INOUT_ROOT_NEW" \
  "$AICODE_RESEARCH_OUTPUT_ROOT_NEW" \
  "$AICODE_LARGE_INPUT_ROOT_NEW" \
  "$AICODE_LARGE_OUTPUT_ROOT_NEW"

python3 - "$HOME/.research_env" \
  "$AICODE_RESEARCH_INOUT_ROOT_NEW" \
  "$AICODE_RESEARCH_OUTPUT_ROOT_NEW" \
  "$AICODE_LARGE_INPUT_ROOT_NEW" \
  "$AICODE_LARGE_OUTPUT_ROOT_NEW" \
  "$HOME/src" "$HOME/worktrees" "$HOME/scratch" <<'PY'
import re, shlex, sys
from pathlib import Path

path = Path(sys.argv[1])
values = {
    "AICODE_RESEARCH_INOUT_ROOT": sys.argv[2],
    "AICODE_RESEARCH_OUTPUT_ROOT": sys.argv[3],
    "AICODE_LARGE_INPUT_ROOT": sys.argv[4],
    "AICODE_LARGE_OUTPUT_ROOT": sys.argv[5],
    "SRC_ROOT": sys.argv[6],
    "WORKTREE_ROOT": sys.argv[7],
    "SCRATCH_ROOT": sys.argv[8],
}
managed = set(values) | {
    "DROPBOX_ROOT", "RESEARCH_ROOT", "LARGE_ROOT", "LOCAL_ROOT",
    "LOCAL_LARGE_ROOT"
}
lines = path.read_text().splitlines() if path.exists() else []
pattern = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=")
kept = []
for line in lines:
    match = pattern.match(line)
    if match and match.group(1) in managed:
        continue
    if line.strip() == "# Generated by research-dev-infra/scripts/setup-machine.sh":
        continue
    kept.append(line)
while kept and not kept[-1].strip():
    kept.pop()
result = ["# Managed shared roots for research-dev-infra"]
for key, value in values.items():
    result.append(f"export {key}={shlex.quote(value)}")
if kept:
    result.extend(["", "# Preserved user-specific settings", *kept])
path.write_text("\n".join(result) + "\n")
PY

for line in \
  '[ -f "$HOME/.research_env" ] && source "$HOME/.research_env"' \
  'export PATH="$HOME/.local/bin:$PATH"'; do
  grep -Fqx "$line" "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$line" >> "$HOME/.bashrc"
done

legacy="$HOME/data-roots"
if [[ -d "$legacy" && ! -L "$legacy" ]]; then
  for name in Research ForShareLargeData Dropbox LocalLarge; do
    entry="$legacy/$name"
    if [[ -L "$entry" ]]; then
      rm -f "$entry"
    elif [[ -e "$entry" ]]; then
      echo "WARNING: preserved unexpected legacy entry: $entry" >&2
    fi
  done
  rmdir "$legacy" 2>/dev/null || echo "WARNING: ~/data-roots remains because it is not empty." >&2
elif [[ -L "$legacy" ]]; then
  echo "WARNING: preserved ~/data-roots because it is itself a symlink." >&2
fi

for pair in setup-workspace:setup-workspace.sh verify-workspace-migration:verify-workspace-migration.sh research-doctor:doctor.sh; do
  name="${pair%%:*}"
  script="${pair#*:}"
  source_path="$INFRA_ROOT/scripts/$script"
  target_path="$HOME/.local/bin/$name"
  if [[ -f "$source_path" ]]; then
    [[ -L "$target_path" ]] && rm -f "$target_path"
    if [[ -e "$target_path" ]]; then
      echo "WARNING: preserved non-symlink command: $target_path" >&2
    else
      ln -s "$source_path" "$target_path"
    fi
  fi
done

old_command="$HOME/.local/bin/setup-project-links"
[[ -L "$old_command" ]] && rm -f "$old_command"

echo
echo "Migration applied."
echo "Run: source ~/.bashrc && hash -r"
echo "Then: verify-workspace-migration"
