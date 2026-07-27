#!/usr/bin/env bash
set -uo pipefail

INFRA_ROOT="$HOME/src/research-dev-infra"
PROJECT_ROOT=""
RUN_FUNCTIONAL_TEST=true
STRICT=false
FAILURES=0
WARNINGS=0

usage() {
  cat <<'USAGE'
Usage:
  verify-workspace-migration.sh [options]

Read-only verification for the current workspace design:
  - no project .local/ links
  - no ~/data-roots indirection
  - only four fixed Dropbox AI roots
  - five fixed project workspace links, including local scratch

Options:
  --infra PATH          research-dev-infra repository path
  --project PATH        optionally verify one project using the new template
  --skip-functional     skip the isolated functional test
  --strict              fail when warnings are present
  -h, --help            show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --infra) [[ $# -ge 2 ]] || exit 2; INFRA_ROOT="$2"; shift 2 ;;
    --project) [[ $# -ge 2 ]] || exit 2; PROJECT_ROOT="$2"; shift 2 ;;
    --skip-functional) RUN_FUNCTIONAL_TEST=false; shift ;;
    --strict) STRICT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

ok() { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail_check() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
section() { printf '\n== %s ==\n' "$*"; }

canonical_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
  fi
}

section "Repository and syntax"
if [[ -d "$INFRA_ROOT/.git" ]] && git -C "$INFRA_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "infra Git repository: $INFRA_ROOT"
  [[ -z "$(git -C "$INFRA_ROOT" status --porcelain 2>/dev/null)" ]] || warn "infra working tree has uncommitted changes"
else
  fail_check "infra Git repository not found: $INFRA_ROOT"
fi

required_files=(
  scripts/setup-machine.sh
  scripts/setup-workspace.sh
  scripts/migrate-existing-wsl-home.sh
  scripts/verify-workspace-migration.sh
  templates/project/.gitignore
  templates/project/.vscode/settings.json
  templates/project/AGENTS.md
  templates/project/CLAUDE.md
  templates/project/PROJECT.md
  templates/project/scripts/configure-workspace.sh
)
for relative_path in "${required_files[@]}"; do
  [[ -f "$INFRA_ROOT/$relative_path" ]] && ok "file: $relative_path" || fail_check "missing file: $relative_path"
done

syntax_failed=false
while IFS= read -r script_path; do
  if ! bash -n "$script_path"; then
    fail_check "shell syntax error: $script_path"
    syntax_failed=true
  fi
done < <(find "$INFRA_ROOT/scripts" "$INFRA_ROOT/templates/project/scripts" -type f -name '*.sh' -print 2>/dev/null | sort)
[[ "$syntax_failed" == false ]] && ok "all shell scripts pass bash -n"

section "Home environment"
if [[ ! -f "$HOME/.research_env" ]]; then
  fail_check "$HOME/.research_env is missing"
else
  ok "$HOME/.research_env exists"
  if bash -n "$HOME/.research_env"; then
    # shellcheck disable=SC1090
    source "$HOME/.research_env"
  else
    fail_check "$HOME/.research_env has invalid shell syntax"
  fi
fi

new_variables=(
  AICODE_RESEARCH_INOUT_ROOT
  AICODE_RESEARCH_OUTPUT_ROOT
  AICODE_LARGE_INPUT_ROOT
  AICODE_LARGE_OUTPUT_ROOT
  SRC_ROOT
  WORKTREE_ROOT
  SCRATCH_ROOT
)
for variable_name in "${new_variables[@]}"; do
  value="${!variable_name:-}"
  if [[ -n "$value" && -d "$value" ]]; then
    ok "$variable_name=$value"
  elif [[ -n "$value" ]]; then
    fail_check "$variable_name directory does not exist: $value"
  else
    fail_check "$variable_name is not set"
  fi
done

for legacy_variable in DROPBOX_ROOT RESEARCH_ROOT LARGE_ROOT LOCAL_ROOT LOCAL_LARGE_ROOT; do
  if grep -Eq "^[[:space:]]*(export[[:space:]]+)?${legacy_variable}=" "$HOME/.research_env" 2>/dev/null; then
    fail_check "legacy broad variable remains in .research_env: $legacy_variable"
  else
    ok "legacy variable absent: $legacy_variable"
  fi
done

[[ "${AICODE_RESEARCH_INOUT_ROOT:-}" == */Research/aicode/inout ]] \
  && ok "Research in/out root has the fixed path" \
  || fail_check "Research in/out root should end with Research/aicode/inout"
[[ "${AICODE_RESEARCH_OUTPUT_ROOT:-}" == */Research/aicode/output ]] \
  && ok "Research output root has the fixed path" \
  || fail_check "Research output root should end with Research/aicode/output"
[[ "${AICODE_LARGE_INPUT_ROOT:-}" == */ForShareLargeData/aicode/input ]] \
  && ok "Large input root has the fixed path" \
  || fail_check "Large input root should end with ForShareLargeData/aicode/input"
[[ "${AICODE_LARGE_OUTPUT_ROOT:-}" == */ForShareLargeData/aicode/output ]] \
  && ok "Large output root has the fixed path" \
  || fail_check "Large output root should end with ForShareLargeData/aicode/output"

if [[ -e "$HOME/data-roots" || -L "$HOME/data-roots" ]]; then
  fail_check "legacy ~/data-roots still exists"
else
  ok "legacy ~/data-roots is absent"
fi

section "Template policy"
template_config="$INFRA_ROOT/templates/project/scripts/configure-workspace.sh"
for required_text in \
  'workspace/research-inout' \
  'workspace/research-output' \
  'workspace/large-input' \
  'workspace/large-output' \
  'workspace/scratch' \
  'AICODE_RESEARCH_INOUT_ROOT' \
  'AICODE_RESEARCH_OUTPUT_ROOT' \
  'AICODE_LARGE_INPUT_ROOT' \
  'AICODE_LARGE_OUTPUT_ROOT'; do
  grep -Fq "$required_text" "$template_config" 2>/dev/null \
    && ok "template contains: $required_text" \
    || fail_check "template is missing: $required_text"
done

for forbidden_text in 'link_data(' 'use_output_dir(' 'RESEARCH_ROOT' 'LARGE_ROOT' 'workspace/data' 'workspace/output'; do
  if grep -Fq "$forbidden_text" "$template_config" 2>/dev/null; then
    fail_check "template still contains obsolete flexible-link text: $forbidden_text"
  else
    ok "obsolete template text absent: $forbidden_text"
  fi
done

legacy_hits="$(grep -RInE --exclude-dir=.git --exclude='*.backup.*' \
  '\.local/(data|output|scratch)|setup-local-links\.sh|workspace/data|workspace/output|link_data\(|use_output_dir\(' \
  "$INFRA_ROOT/README.md" "$INFRA_ROOT/docs" "$INFRA_ROOT/templates" 2>/dev/null || true)"
if [[ -z "$legacy_hits" ]]; then
  ok "no obsolete project workspace paths in docs/templates"
else
  fail_check "obsolete project workspace references remain"
  printf '%s\n' "$legacy_hits" | sed 's/^/       /'
fi

section "Functional reconstruction"
if [[ "$RUN_FUNCTIONAL_TEST" == true ]]; then
  test_root="$(mktemp -d "${TMPDIR:-/tmp}/research-workspace-check.XXXXXX")"
  trap 'rm -rf "$test_root"' EXIT
  test_home="$test_root/home"
  test_project="$test_root/project"
  test_dropbox="$test_root/Dropbox"
  test_scratch="$test_root/scratch"
  mkdir -p "$test_home" "$test_project" "$test_dropbox/Research" "$test_dropbox/ForShareLargeData" "$test_scratch"
  cp -a "$INFRA_ROOT/templates/project/." "$test_project/"
  python3 - "$test_project" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for path in root.rglob('*'):
    if path.is_file() and not path.is_symlink():
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        path.write_text(text.replace('__PROJECT_NAME__', 'MigrationCheck'))
PY
  cat > "$test_home/.research_env" <<EOF
export AICODE_RESEARCH_INOUT_ROOT='$test_dropbox/Research/aicode/inout'
export AICODE_RESEARCH_OUTPUT_ROOT='$test_dropbox/Research/aicode/output'
export AICODE_LARGE_INPUT_ROOT='$test_dropbox/ForShareLargeData/aicode/input'
export AICODE_LARGE_OUTPUT_ROOT='$test_dropbox/ForShareLargeData/aicode/output'
export SRC_ROOT='$test_root/src'
export WORKTREE_ROOT='$test_root/worktrees'
export SCRATCH_ROOT='$test_scratch'
EOF
  functional_log="$test_root/functional.log"
  if HOME="$test_home" PROJECT_ROOT="$test_project" WORKSPACE_NAME="test-task" \
    bash "$test_project/scripts/configure-workspace.sh" >"$functional_log" 2>&1; then
    ok "template configure-workspace executes"
  else
    fail_check "template configure-workspace failed"
    sed 's/^/       /' "$functional_log"
  fi

  declare -A expected=(
    [research-inout]="$test_dropbox/Research/aicode/inout/MigrationCheck"
    [research-output]="$test_dropbox/Research/aicode/output/MigrationCheck"
    [large-input]="$test_dropbox/ForShareLargeData/aicode/input/MigrationCheck"
    [large-output]="$test_dropbox/ForShareLargeData/aicode/output/MigrationCheck"
    [scratch]="$test_scratch/MigrationCheck/test-task"
  )
  for name in research-inout research-output large-input large-output scratch; do
    link="$test_project/workspace/$name"
    if [[ -L "$link" && -e "$link" ]]; then
      actual="$(canonical_path "$link")"
      wanted="$(canonical_path "${expected[$name]}")"
      [[ "$actual" == "$wanted" ]] && ok "workspace/$name target is correct" || fail_check "workspace/$name -> $actual; expected $wanted"
    else
      fail_check "workspace/$name is missing or broken"
    fi
  done
  [[ ! -e "$test_project/.local" && ! -L "$test_project/.local" ]] && ok "legacy project .local was not created" || fail_check "legacy project .local was created"
  rm -rf "$test_root"
  trap - EXIT
else
  warn "functional test was skipped"
fi

if [[ -n "$PROJECT_ROOT" ]]; then
  section "Project check"
  if [[ ! -d "$PROJECT_ROOT" ]]; then
    fail_check "project path does not exist: $PROJECT_ROOT"
  else
    project_name="$(basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT_ROOT")")"
    declare -A roots=(
      [research-inout]="${AICODE_RESEARCH_INOUT_ROOT:-}/$project_name"
      [research-output]="${AICODE_RESEARCH_OUTPUT_ROOT:-}/$project_name"
      [large-input]="${AICODE_LARGE_INPUT_ROOT:-}/$project_name"
      [large-output]="${AICODE_LARGE_OUTPUT_ROOT:-}/$project_name"
    )
    for name in research-inout research-output large-input large-output scratch; do
      link="$PROJECT_ROOT/workspace/$name"
      if [[ -L "$link" && -e "$link" ]]; then
        ok "project link: workspace/$name -> $(readlink "$link")"
        if [[ "$name" != scratch ]]; then
          actual="$(canonical_path "$link")"
          wanted="$(canonical_path "${roots[$name]}")"
          [[ "$actual" == "$wanted" ]] || fail_check "workspace/$name does not target the fixed project directory"
        fi
      else
        fail_check "missing or broken project link: workspace/$name"
      fi
    done
    [[ ! -e "$PROJECT_ROOT/.local" && ! -L "$PROJECT_ROOT/.local" ]] && ok "project has no legacy .local" || fail_check "project still contains .local"
  fi
fi

section "Result"
printf 'Failures: %d; warnings: %d\n' "$FAILURES" "$WARNINGS"
if [[ $FAILURES -gt 0 ]]; then exit 1; fi
if [[ "$STRICT" == true && $WARNINGS -gt 0 ]]; then exit 1; fi
echo "Workspace verification passed."
