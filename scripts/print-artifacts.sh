#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

DEFAULT_COMPOSE_FILE="$ROOT/configs/finder-claude-code.yaml"
DEFAULT_WORK_DIR="$ROOT/generated/oss-crs-work"

usage() {
  cat <<'EOF'
Usage: scripts/print-artifacts.sh --fuzz-proj-path PATH --target-harness NAME (--run-id ID | --latest) [options]

Prints the JSON returned by `oss-crs artifacts`. The finder-specific result is
available at `.crs["crs-finder-claude-code"]`.

Options:
  --build-id ID               Resolve build output for a specific build
  --sanitizer NAME            Sanitizer (default: address)
  --target-source-path PATH   Optional target source override
  --source-override PATH      Alias for --target-source-path
  --compose-file FILE         Compose file (default: configs/finder-claude-code.yaml)
  --work-dir DIR              OSS-CRS work directory (default: generated/oss-crs-work)
  -h, --help                  Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

FUZZ_PROJ_PATH=""
TARGET_HARNESS=""
TARGET_SOURCE_PATH=""
RUN_ID=""
BUILD_ID=""
SANITIZER="address"
COMPOSE_FILE="$DEFAULT_COMPOSE_FILE"
WORK_DIR="$DEFAULT_WORK_DIR"
LATEST=false

while (($#)); do
  case "$1" in
    --fuzz-proj-path|--target|--target-path)
      (($# >= 2)) || die "$1 requires a path"
      FUZZ_PROJ_PATH="$2"
      shift
      ;;
    --target-harness|--harness)
      (($# >= 2)) || die "$1 requires a harness name"
      TARGET_HARNESS="$2"
      shift
      ;;
    --target-source-path|--source-override)
      (($# >= 2)) || die "$1 requires a path"
      TARGET_SOURCE_PATH="$2"
      shift
      ;;
    --run-id)
      (($# >= 2)) || die '--run-id requires an ID'
      RUN_ID="$2"
      shift
      ;;
    --latest)
      LATEST=true
      ;;
    --build-id)
      (($# >= 2)) || die '--build-id requires an ID'
      BUILD_ID="$2"
      shift
      ;;
    --sanitizer)
      (($# >= 2)) || die '--sanitizer requires a value'
      SANITIZER="$2"
      shift
      ;;
    --compose-file)
      (($# >= 2)) || die '--compose-file requires a file'
      COMPOSE_FILE="$2"
      shift
      ;;
    --work-dir)
      (($# >= 2)) || die '--work-dir requires a directory'
      WORK_DIR="$2"
      shift
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

[[ -n "$FUZZ_PROJ_PATH" ]] || die '--fuzz-proj-path is required'
[[ -n "$TARGET_HARNESS" ]] || die '--target-harness is required'
[[ -d "$FUZZ_PROJ_PATH" ]] || die "Fuzz project directory does not exist: $FUZZ_PROJ_PATH"
[[ -f "$COMPOSE_FILE" ]] || die "Compose file does not exist: $COMPOSE_FILE"
[[ -z "$TARGET_SOURCE_PATH" || -d "$TARGET_SOURCE_PATH" ]] || die "Target source override is not a directory: $TARGET_SOURCE_PATH"
[[ -z "$RUN_ID" || "$LATEST" == false ]] || die 'Use either --run-id or --latest, not both'
[[ -n "$RUN_ID" || "$LATEST" == true ]] || die 'Provide --run-id or --latest to avoid an interactive selection'

command -v uv >/dev/null 2>&1 || die 'uv is required. Run scripts/setup.sh for diagnostics.'

OSS_CRS=(uv run --project "$ROOT/oss-crs" oss-crs)
ARGS=(artifacts --compose-file "$COMPOSE_FILE" --work-dir "$WORK_DIR" --fuzz-proj-path "$FUZZ_PROJ_PATH" --target-harness "$TARGET_HARNESS" --sanitizer "$SANITIZER")
if [[ -n "$TARGET_SOURCE_PATH" ]]; then
  ARGS+=(--target-source-path "$TARGET_SOURCE_PATH")
fi
if [[ -n "$BUILD_ID" ]]; then
  ARGS+=(--build-id "$BUILD_ID")
fi
if [[ -n "$RUN_ID" ]]; then
  ARGS+=(--run-id "$RUN_ID")
else
  ARGS+=(--latest)
fi

"${OSS_CRS[@]}" "${ARGS[@]}"
