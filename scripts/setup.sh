#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: scripts/setup.sh [--check]

Initializes the oss-crs submodule when needed and checks the local prerequisites
for the Claude Code Finder/Patcher workflow. --check never changes submodule
state.
EOF
}

CHECK_ONLY=false

while (($#)); do
  case "$1" in
    --check)
      CHECK_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

status=0

note_ok() {
  printf '[ok] %s\n' "$1"
}

note_warn() {
  printf '[warn] %s\n' "$1" >&2
}

note_error() {
  printf '[error] %s\n' "$1" >&2
  status=1
}

if ! command -v git >/dev/null 2>&1; then
  note_error 'git is required to initialize and inspect the oss-crs submodule.'
fi

if [[ ! -f "$ROOT/oss-crs/pyproject.toml" ]]; then
  if [[ "$CHECK_ONLY" == true ]]; then
    note_error 'oss-crs is not initialized. Run scripts/setup.sh without --check.'
  elif command -v git >/dev/null 2>&1; then
    printf 'Initializing oss-crs submodule...\n'
    git submodule update --init --recursive oss-crs
  fi
fi

if [[ -f "$ROOT/oss-crs/pyproject.toml" ]]; then
  note_ok 'oss-crs submodule is present.'
else
  note_error 'oss-crs/pyproject.toml is missing.'
fi

if command -v uv >/dev/null 2>&1; then
  note_ok "uv: $(uv --version)"
  if [[ -f "$ROOT/oss-crs/pyproject.toml" ]]; then
    if uv run --project "$ROOT/oss-crs" python - "$ROOT" <<'PY'
from pathlib import Path
import sys

from oss_crs.src.config.crs_compose import CRSComposeConfig
from oss_crs.src.crs_compose import CRSCompose

import tempfile
root = Path(sys.argv[1])
checks = (
    ("finder-claude-code.yaml", "crs-finder-claude-code"),
    ("patcher-claude-code.yaml", "crs-patcher-claude-code"),
)

# This validates both local CRS roots and manifests without cloning, Docker, or
# LLM credentials. A temporary work directory keeps the repository clean.
for compose_name, crs_name in checks:
    compose_file = root / "configs" / compose_name
    config = CRSComposeConfig.from_yaml_file(compose_file)
    assert crs_name in config.crs_entries
    with tempfile.TemporaryDirectory() as work_dir:
        CRSCompose.from_yaml_file(
            compose_file, Path(work_dir), skip_crs_init=True
        )

print("Finder and Patcher compose/manifests parse successfully.")
PY
    then
      note_ok 'Finder and Patcher compose/manifest static checks passed.'
    else
      note_error 'Finder or Patcher compose/manifest static check failed.'
    fi
  fi
else
  note_error 'uv is required. Install Astral uv, then rerun this script.'
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    note_ok 'Docker daemon is reachable.'
  else
    note_error 'Docker is installed but its daemon is not reachable.'
  fi

  if docker compose version >/dev/null 2>&1; then
    note_ok 'Docker Compose v2 is available.'
  else
    note_error 'Docker Compose v2 is required by oss-crs.'
  fi
else
  note_error 'Docker and Docker Compose v2 are required for build and run phases.'
fi

if command -v nproc >/dev/null 2>&1; then
  cpu_count="$(nproc)"
  if ((cpu_count < 8)); then
    note_warn "The default Claude compose names CPUs 0-7, but nproc reports ${cpu_count}. Adjust the Claude compose files before running."
  else
    note_ok "CPU check: ${cpu_count} logical CPUs available to this shell."
  fi
fi

if [[ -r /proc/meminfo ]]; then
  memory_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  if [[ -n "$memory_kib" ]] && ((memory_kib < 25165824)); then
    note_warn 'The default compose reserves 24G across finder and infrastructure; the host reports less than 24G.'
  fi
fi

if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  note_ok 'CLAUDE_CODE_OAUTH_TOKEN is exported.'
elif [[ -f "$ROOT/.env" ]] && rg -q '^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_OAUTH_TOKEN=.+$' "$ROOT/.env"; then
  note_ok 'CLAUDE_CODE_OAUTH_TOKEN is present in root .env.'
else
  note_warn 'CLAUDE_CODE_OAUTH_TOKEN is absent. Claude Finder/Patcher runs will fail before prepare/build.'
fi

if ((status != 0)); then
  exit "$status"
fi

printf 'Setup checks passed. Use scripts/run-claude-e2e.sh for the staged Claude workflow.\n'
