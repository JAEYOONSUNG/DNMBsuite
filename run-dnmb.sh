#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./run-dnmb.sh <genbank_path> [output_dir]

Examples:
  ./run-dnmb.sh /path/to/genome.gbff
  ./run-dnmb.sh /path/to/genome.gbk /path/to/output-dir

Behavior:
  - If output_dir is omitted, DNMB writes results next to the input GenBank file.
  - If output_dir is provided, the input GenBank file is copied into that directory first.
  - Shared caches are stored in ~/.dnmb-cache by default.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not available in PATH." >&2
  exit 1
fi

INPUT_PATH="$1"
if [ ! -f "$INPUT_PATH" ]; then
  echo "Error: input file not found: $INPUT_PATH" >&2
  exit 1
fi

case "$INPUT_PATH" in
  *.gb|*.gbk|*.gbff) ;;
  *)
    echo "Error: input must be a .gb, .gbk, or .gbff file." >&2
    exit 1
    ;;
esac

INPUT_ABS="$(cd "$(dirname "$INPUT_PATH")" && pwd)/$(basename "$INPUT_PATH")"
INPUT_BASENAME="$(basename "$INPUT_ABS")"
INPUT_DIR="$(dirname "$INPUT_ABS")"

if [ "$#" -ge 2 ]; then
  OUTPUT_DIR="$2"
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"
else
  OUTPUT_ABS="$INPUT_DIR"
fi

CACHE_ROOT="${DNMB_CACHE_ROOT_HOST:-$HOME/.dnmb-cache}"
mkdir -p "$CACHE_ROOT"

if [ "$OUTPUT_ABS" != "$INPUT_DIR" ]; then
  cp -f "$INPUT_ABS" "$OUTPUT_ABS/$INPUT_BASENAME"
fi

IMAGE="${DNMBSUITE_IMAGE:-ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2}"

docker run --rm \
  -v "$OUTPUT_ABS:/data" \
  -v "$CACHE_ROOT:/opt/dnmb/cache" \
  "$IMAGE" \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(clean_previous = TRUE)'
