#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

FINDER_NAME="crs-finder-codex"
PATCHER_NAME="crs-patcher-codex"
BENCHMARK="sanity-mock-c-delta-01"
HARNESS="fuzz_parse_buffer_section"
SANITIZER="address"
MODE="delta"

usage() {
  cat <<'EOF'
Usage: scripts/run-codex-e2e.sh [options]

Runs the Codex CRSBench smoke chain:
  Finder -> CRSBench verify cpv_1 -> Patcher -> CRSBench patch-verify cpv_1

Defaults:
  benchmark: sanity-mock-c-delta-01
  harness:   fuzz_parse_buffer_section
  mode:      delta/address

Options:
  --crsbench-root DIR       CRSBench checkout (default: ../CRC-Evaluate)
  --crsbench-bin FILE       crsbench executable (default: <root>/.venv/bin/crsbench)
  --oss-crs-cmd FILE        oss-crs executable (default: oss-crs/.venv/bin/oss-crs)
  --run-id ID               Stable run label (generated when omitted)
  --out-root DIR            Output root (default: generated/crsbench-codex-smoke)
  --finder-run-timeout SEC  Finder run timeout in CRSBench config (default: 360)
  --patcher-run-timeout SEC Patcher run timeout in CRSBench config (default: 600)
  --config-only             Generate and validate configs, then stop after Finder dry-run
  -h, --help                Show this help

The script reads CRC_LITELLM_UPSTREAM_BASE_URL/API_KEY from the ignored root
.env when present and exports CRSBench's CRSBENCH_LLM_UPSTREAM_* variables.
It never writes those credentials into generated configs or logs.
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

safe_id() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "Invalid run ID: $1"
}

canonical_existing_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "Directory does not exist: $path"
  (cd "$path" && pwd -P)
}

canonical_dir() {
  local path="$1"
  mkdir -p "$path"
  (cd "$path" && pwd -P)
}

find_nonempty_file() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  find "$dir" -type f ! -name '.*' -size +0c -print -quit
}

find_matching_nonempty_file() {
  local root="$1"
  local path_pattern="$2"
  [[ -d "$root" ]] || return 1
  find "$root" -type f -path "$path_pattern" ! -name '.*' -size +0c -print -quit
}

run_crsbench() {
  local log_path="$1"
  shift
  printf '[run] crsbench'
  printf ' %q' "$@"
  printf '\n'
  {
    printf '[run] crsbench'
    printf ' %q' "$@"
    printf '\n'
    cd "$CRSBENCH_ROOT"
    "$CRSBENCH_BIN" "$@"
  } 2>&1 | tee "$log_path"
}

CRSBENCH_ROOT="${CRSBENCH_ROOT:-$ROOT/../CRC-Evaluate}"
CRSBENCH_BIN="${CRSBENCH_BIN:-}"
OSS_CRS_CMD="${OSS_CRS_CMD:-$ROOT/oss-crs/.venv/bin/oss-crs}"
RUN_ID=""
OUT_ROOT="$ROOT/generated/crsbench-codex-smoke"
FINDER_RUN_TIMEOUT="360"
PATCHER_RUN_TIMEOUT="600"
CONFIG_ONLY=false

while (($#)); do
  case "$1" in
    --crsbench-root)
      (($# >= 2)) || die '--crsbench-root requires a directory'
      CRSBENCH_ROOT="$2"
      shift
      ;;
    --crsbench-bin)
      (($# >= 2)) || die '--crsbench-bin requires a file'
      CRSBENCH_BIN="$2"
      shift
      ;;
    --oss-crs-cmd)
      (($# >= 2)) || die '--oss-crs-cmd requires a file'
      OSS_CRS_CMD="$2"
      shift
      ;;
    --run-id)
      (($# >= 2)) || die '--run-id requires an ID'
      RUN_ID="$2"
      shift
      ;;
    --out-root)
      (($# >= 2)) || die '--out-root requires a directory'
      OUT_ROOT="$2"
      shift
      ;;
    --finder-run-timeout)
      (($# >= 2)) || die '--finder-run-timeout requires seconds'
      FINDER_RUN_TIMEOUT="$2"
      shift
      ;;
    --patcher-run-timeout)
      (($# >= 2)) || die '--patcher-run-timeout requires seconds'
      PATCHER_RUN_TIMEOUT="$2"
      shift
      ;;
    --config-only)
      CONFIG_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

[[ "$FINDER_RUN_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die '--finder-run-timeout must be a positive integer'
[[ "$PATCHER_RUN_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die '--patcher-run-timeout must be a positive integer'

if [[ -z "$RUN_ID" ]]; then
  RUN_ID="codex-$(date -u +%Y%m%dt%H%M%Sz)-$$"
fi
safe_id "$RUN_ID"

CRSBENCH_ROOT="$(canonical_existing_dir "$CRSBENCH_ROOT")"
if [[ -z "$CRSBENCH_BIN" ]]; then
  CRSBENCH_BIN="$CRSBENCH_ROOT/.venv/bin/crsbench"
fi
[[ -x "$CRSBENCH_BIN" ]] || die "crsbench executable is not runnable: $CRSBENCH_BIN"
CRSBENCH_PYTHON="$CRSBENCH_ROOT/.venv/bin/python"
[[ -x "$CRSBENCH_PYTHON" ]] || die "CRSBench venv python is not runnable: $CRSBENCH_PYTHON"
[[ -x "$OSS_CRS_CMD" ]] || die "oss-crs executable is not runnable: $OSS_CRS_CMD"

BENCHMARKS_ROOT="$CRSBENCH_ROOT/benchmarks"
BENCHMARK_PATH="$BENCHMARKS_ROOT/$BENCHMARK"
OSS_FUZZ_PATH="$CRSBENCH_ROOT/third_party/oss-fuzz"
[[ -d "$BENCHMARK_PATH" ]] || die "Benchmark is missing: $BENCHMARK_PATH"
[[ -d "$OSS_FUZZ_PATH" ]] || die "managed oss-fuzz checkout is missing: $OSS_FUZZ_PATH"

source "$ROOT/scripts/load-local-env.sh"
load_litellm_upstream_env "$ROOT"
if [[ -z "${CRSBENCH_LLM_UPSTREAM_BASE_URL:-}" && -n "${CRC_LITELLM_UPSTREAM_BASE_URL:-}" ]]; then
  export CRSBENCH_LLM_UPSTREAM_BASE_URL="$CRC_LITELLM_UPSTREAM_BASE_URL"
fi
if [[ -z "${CRSBENCH_LLM_UPSTREAM_API_KEY:-}" && -n "${CRC_LITELLM_UPSTREAM_API_KEY:-}" ]]; then
  export CRSBENCH_LLM_UPSTREAM_API_KEY="$CRC_LITELLM_UPSTREAM_API_KEY"
fi
[[ -n "${CRSBENCH_LLM_UPSTREAM_BASE_URL:-}" ]] || die 'CRSBENCH_LLM_UPSTREAM_BASE_URL or CRC_LITELLM_UPSTREAM_BASE_URL is required'
[[ -n "${CRSBENCH_LLM_UPSTREAM_API_KEY:-}" ]] || die 'CRSBENCH_LLM_UPSTREAM_API_KEY or CRC_LITELLM_UPSTREAM_API_KEY is required'

OUT_ROOT="$(canonical_dir "$OUT_ROOT")"
RUN_ROOT="$(canonical_dir "$OUT_ROOT/$RUN_ID")"
REGISTRY_DIR="$(canonical_dir "$RUN_ROOT/registry")"
EXPERIMENTS_ROOT="$(canonical_dir "$RUN_ROOT/experiments")"
REPORTS_ROOT="$(canonical_dir "$RUN_ROOT/reports")"

FINDER_EXP_NAME="template-finder-codex-$RUN_ID"
PATCHER_EXP_NAME="template-patcher-codex-$RUN_ID"
FINDER_FILESTORE="$EXPERIMENTS_ROOT/$FINDER_EXP_NAME"
PATCHER_FILESTORE="$EXPERIMENTS_ROOT/$PATCHER_EXP_NAME"
FINDER_CONFIG="$RUN_ROOT/experiment-finder.yaml"
PATCHER_CONFIG="$RUN_ROOT/experiment-patcher.yaml"

FINDER_EXP_DIR="$FINDER_FILESTORE/$FINDER_EXP_NAME/$FINDER_NAME"
PATCHER_EXP_DIR="$PATCHER_FILESTORE/$PATCHER_EXP_NAME/$PATCHER_NAME"
FINDER_TRIAL_DIR="$FINDER_EXP_DIR/$BENCHMARK/$HARNESS/$MODE/$SANITIZER/trial-1"
PATCHER_TRIAL_DIR="$PATCHER_EXP_DIR/$BENCHMARK/$HARNESS/cpv_1/$MODE/$SANITIZER/trial-1"
FINDER_POV_DIR="$FINDER_TRIAL_DIR/output/povs"
PATCHER_PATCH_DIR="$PATCHER_TRIAL_DIR/output/patches"
PATCHER_POV_DIR="$PATCHER_TRIAL_DIR/output/povs"
FINDER_VERIFY_JSON="$RUN_ROOT/finder-verify.json"
PATCH_VERIFY_JSON="$RUN_ROOT/patch-verify.json"

cat >"$REGISTRY_DIR/$FINDER_NAME.yaml" <<EOF
name: $FINDER_NAME
type:
  - bug-finding
source:
  local_path: $ROOT/crs/crs-finder-codex
required_llms:
  - gpt-5.5
EOF

cat >"$REGISTRY_DIR/$PATCHER_NAME.yaml" <<EOF
name: $PATCHER_NAME
type:
  - bug-fixing
source:
  local_path: $ROOT/crs/crs-patcher-codex
required_llms:
  - gpt-5.5
EOF

cat >"$FINDER_CONFIG" <<EOF
experiment:
  name: $FINDER_EXP_NAME
  task: bugfinding
  mode: $MODE
  benchmarks:
    - $BENCHMARK:
        - $HARNESS

registry_dir: $REGISTRY_DIR
benchmarks_root: $BENCHMARKS_ROOT
oss_fuzz_path: $OSS_FUZZ_PATH

runtime:
  trials: 1
  max_total_time: 1800
  build_timeout: 900
  run_timeout: $FINDER_RUN_TIMEOUT
  verify_timeout: 120
  per_pov_verify_timeout: 30
  snapshot_period: 0
  pov_early_stop: true
  skip_verification: false
  litellm:
    mode: external
    tracking_enabled: false

storage:
  experiment_filestore: $FINDER_FILESTORE
  report_filestore: $REPORTS_ROOT/$FINDER_EXP_NAME
  cleanup_after_trial: false

resources:
  memory_per_trial: "24G"

worker:
  jobs: 1
  cores_per_job: 8

crs_compose:
  oss_crs_cmd: $OSS_CRS_CMD
  oss_crs_infra:
    shared: true
  $FINDER_NAME:
    num_cores: 8
    mem_limit: "24G"
    additional_env:
      CODEX_MODEL: gpt-5.5
      CODEX_MODEL_REASONING_EFFORT: xhigh
EOF

cat >"$PATCHER_CONFIG" <<EOF
experiment:
  name: $PATCHER_EXP_NAME
  task: bugfixing
  mode: $MODE
  benchmarks:
    - $BENCHMARK:
        - $HARNESS

registry_dir: $REGISTRY_DIR
benchmarks_root: $BENCHMARKS_ROOT
oss_fuzz_path: $OSS_FUZZ_PATH

runtime:
  trials: 1
  max_total_time: 2100
  build_timeout: 900
  run_timeout: $PATCHER_RUN_TIMEOUT
  verify_timeout: 120
  per_pov_verify_timeout: 30
  snapshot_period: 0
  skip_verification: false
  inputs:
    pov:
      max_variants_per_cpv: 1
      from_experiment_by_crs:
        $PATCHER_NAME: $FINDER_EXP_DIR
  litellm:
    mode: external
    tracking_enabled: false

storage:
  experiment_filestore: $PATCHER_FILESTORE
  report_filestore: $REPORTS_ROOT/$PATCHER_EXP_NAME
  cleanup_after_trial: false

resources:
  memory_per_trial: "24G"

worker:
  jobs: 1
  cores_per_job: 8

crs_compose:
  oss_crs_cmd: $OSS_CRS_CMD
  oss_crs_infra:
    shared: true
  $PATCHER_NAME:
    num_cores: 8
    mem_limit: "24G"
    additional_env:
      CODEX_MODEL: gpt-5.5
      CODEX_MODEL_REASONING_EFFORT: xhigh
EOF

"$CRSBENCH_PYTHON" - "$FINDER_CONFIG" "$PATCHER_CONFIG" <<'PY'
from pathlib import Path
import sys

from crsbench.run_experiment import load_experiment_config

for config_path in map(Path, sys.argv[1:]):
    load_experiment_config(config_path)
    print(f"[ok] CRSBench config validates: {config_path}")
PY

run_crsbench "$RUN_ROOT/finder-dry-run.log" run --experiment-config "$FINDER_CONFIG" --local-only --dry-run

if [[ "$CONFIG_ONLY" == true ]]; then
  printf 'Config-only check passed. Generated files are under %s\n' "$RUN_ROOT"
  exit 0
fi

require_command docker
if ! docker info >/dev/null 2>&1; then
  die 'Docker is installed but the daemon is not reachable.'
fi

run_crsbench "$RUN_ROOT/finder-run.log" run --experiment-config "$FINDER_CONFIG" --local-only

found_pov="$(find_nonempty_file "$FINDER_POV_DIR" || true)"
if [[ -z "$found_pov" ]]; then
  found_pov="$(find_matching_nonempty_file "$FINDER_EXP_DIR" '*/output/povs/*' || true)"
  [[ -n "$found_pov" ]] || die "Finder produced no non-empty POV below: $FINDER_EXP_DIR"
  FINDER_POV_DIR="$(dirname "$found_pov")"
fi
printf '[ok] Finder produced POV evidence in %s\n' "$FINDER_POV_DIR"

run_crsbench "$RUN_ROOT/finder-verify.log" verify "$BENCHMARK_PATH" \
  --pov-dir "$FINDER_POV_DIR" \
  --harness "$HARNESS" \
  --oss-fuzz-path "$OSS_FUZZ_PATH" \
  --timeout 120 \
  --jobs 1 \
  --cores-per-job 8 \
  --output "$FINDER_VERIFY_JSON" \
  --format json

"$CRSBENCH_PYTHON" - "$FINDER_VERIFY_JSON" <<'PY'
import json
import sys
from pathlib import Path

results = json.loads(Path(sys.argv[1]).read_text())
if isinstance(results, dict):
    candidates = results.get("results", [])
else:
    candidates = results
for item in candidates:
    if item.get("status") == "cpv" and "cpv_1" in item.get("cpv_matched", []):
        print("[ok] Finder independent verify matched cpv_1")
        break
else:
    raise SystemExit("Finder verify did not match cpv_1")
PY

run_crsbench "$RUN_ROOT/patcher-dry-run.log" run --experiment-config "$PATCHER_CONFIG" --local-only --dry-run
run_crsbench "$RUN_ROOT/patcher-run.log" run --experiment-config "$PATCHER_CONFIG" --local-only

found_patch="$(find_nonempty_file "$PATCHER_PATCH_DIR" || true)"
if [[ -z "$found_patch" ]]; then
  found_patch="$(find_matching_nonempty_file "$PATCHER_EXP_DIR" '*/output/patches/*.diff' || true)"
  [[ -n "$found_patch" ]] || die "Patcher produced no non-empty .diff below: $PATCHER_EXP_DIR"
  PATCHER_PATCH_DIR="$(dirname "$found_patch")"
fi
printf '[ok] Patcher produced patch evidence in %s\n' "$PATCHER_PATCH_DIR"

found_patch_pov="$(find_nonempty_file "$PATCHER_POV_DIR" || true)"
if [[ -z "$found_patch_pov" ]]; then
  found_patch_pov="$(find_matching_nonempty_file "$PATCHER_EXP_DIR" '*/output/povs/*' || true)"
  [[ -n "$found_patch_pov" ]] || die "Patcher staged no POV inputs below: $PATCHER_EXP_DIR"
  PATCHER_POV_DIR="$(dirname "$found_patch_pov")"
fi
printf '[ok] Patcher staged POV evidence in %s\n' "$PATCHER_POV_DIR"

run_crsbench "$RUN_ROOT/patch-verify.log" patch-verify "$BENCHMARK_PATH" \
  --patch-dir "$PATCHER_PATCH_DIR" \
  --pov-dir "$PATCHER_POV_DIR" \
  --harness "$HARNESS" \
  --oss-fuzz-path "$OSS_FUZZ_PATH" \
  --test-mode full \
  --sanitizer "$SANITIZER" \
  --timeout 120 \
  --build-timeout 1200 \
  --test-timeout 1800 \
  --jobs 1 \
  --cores-per-job 8 \
  --output "$PATCH_VERIFY_JSON" \
  --format json

"$CRSBENCH_PYTHON" - "$PATCH_VERIFY_JSON" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
results = payload.get("results", payload if isinstance(payload, list) else [])
for item in results:
    if (
        item.get("status") == "valid"
        and item.get("pov_test_passed") is True
        and item.get("unit_tests_passed") is True
        and item.get("security_verdict") == "PASS"
        and "cpv_1" in item.get("cpv_fixed", [])
    ):
        print("[ok] Patch independent verify fixed cpv_1")
        break
else:
    raise SystemExit("Patch verify did not produce a valid cpv_1 fix")
PY

printf 'Codex CRSBench E2E passed. Results are under %s\n' "$RUN_ROOT"
