#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./run-dnmb.sh <genbank_path> [output_dir] [options]

Examples:
  ./run-dnmb.sh /path/to/genome.gbff
  ./run-dnmb.sh /path/to/genome.gbk /path/to/output-dir
  ./run-dnmb.sh /path/to/genome.gbff --modules defensefinder,iselement,prophage
  ./run-dnmb.sh /path/to/genome.gbff --skip-modules interproscan,eggnog --cpu 8
  ./run-dnmb.sh /path/to/genome.gbff --dnmb-auto-update --dnmb-auto-update-branch master

Behavior:
  - If output_dir is omitted, DNMB writes results next to the input GenBank file.
  - If output_dir is provided, the input GenBank file is copied into that directory first.
  - Shared caches are stored in ~/.dnmb-cache by default.

Options:
  --modules <list>          Comma-separated module list to enable.
                            Supported names:
                            dbcan, merops, clean, pazy, gapmind,
                            defensefinder, dbapis, acrfinder,
                            padloc, defensepredictor,
                            rebasefinder, iselement,
                            phispy, virsorter2, pide,
                            prophage (deprecated alias), eggnog, interproscan
                            Special values: all, none, core
  --skip-modules <list>     Comma-separated module list to disable.
  --cpu <n>                 Thread count passed to run_DNMB().
  --prophage-backend <x>    Prophage backend: phispy, virsorter2, or pide.
  --keep-previous           Set clean_previous = FALSE.
  --dnmb-auto-update        Opt in to DNMB package auto-update at container startup.
  --dnmb-auto-update-branch <name>
                            Git branch to follow when auto-update is enabled.
  --image <image>           Override the Docker image to run.

GPU defaults:
  CLEAN and PIDE default to ON only when an NVIDIA GPU is detected via
  `nvidia-smi -L`. When CUDA is available, `--gpus all` is passed to
  `docker run`. Force the choice by setting DNMB_CUDA=1 or DNMB_CUDA=0,
  or override per-module with e.g. `--modules clean` / `--skip-modules pide`.
EOF
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not available in PATH." >&2
  exit 1
fi

cleanup_output_dir() {
  local output_dir="$1"

  rm -rf "$output_dir/temp" 2>/dev/null || true
  rm -f "$output_dir/Rplots.pdf" "$output_dir/Rplot.pdf" 2>/dev/null || true
}

ensure_image() {
  local image="$1"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "Pulling Docker image: $image"
    docker pull "$image"
  fi
}

normalize_module_name() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    dbcan) echo "dbcan" ;;
    merops) echo "merops" ;;
    clean) echo "clean" ;;
    pazy) echo "pazy" ;;
    gapmind|gapmindaa|gapmindcarbon) echo "gapmind" ;;
    defensefinder|defense) echo "defensefinder" ;;
    dbapis) echo "dbapis" ;;
    acrfinder|acr) echo "acrfinder" ;;
    padloc) echo "padloc" ;;
    defensepredictor|defense-predictor) echo "defensepredictor" ;;
    rebasefinder|rebase) echo "rebasefinder" ;;
    iselement|iselements|is) echo "iselement" ;;
    phispy) echo "phispy" ;;
    virsorter2|virsorter) echo "virsorter2" ;;
    pide) echo "pide" ;;
    prophage) echo "prophage" ;;
    eggnog) echo "eggnog" ;;
    interproscan|interpro) echo "interproscan" ;;
    all|none|core) echo "$raw" ;;
    *)
      echo ""
      ;;
  esac
}

split_csv() {
  local input="$1"
  local item
  IFS=',' read -r -a __items <<< "$input"
  for item in "${__items[@]}"; do
    item="$(normalize_module_name "$item")"
    if [ -n "$item" ]; then
      printf '%s\n' "$item"
    fi
  done
}

detect_cuda() {
  case "${DNMB_CUDA:-}" in
    1|true|TRUE|yes|YES|on|ON) echo TRUE; return ;;
    0|false|FALSE|no|NO|off|OFF) echo FALSE; return ;;
  esac
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    echo TRUE
  else
    echo FALSE
  fi
}
CUDA_AVAILABLE="$(detect_cuda)"
if [ "$CUDA_AVAILABLE" = TRUE ]; then
  printf '[run-dnmb] CUDA detected — CLEAN/PIDE enabled by default.\n' >&2
else
  printf '[run-dnmb] CUDA not detected — CLEAN/PIDE skipped by default (override: --module clean=true or DNMB_CUDA=1).\n' >&2
fi

MODULE_DBCAN=TRUE
MODULE_MEROPS=TRUE
MODULE_CLEAN="$CUDA_AVAILABLE"
MODULE_PAZY=TRUE
MODULE_GAPMIND=TRUE
MODULE_DEFENSEFINDER=TRUE
MODULE_DBAPIS=TRUE
MODULE_ACRFINDER=TRUE
MODULE_PADLOC=TRUE
MODULE_DEFENSEPREDICTOR=TRUE
MODULE_REBASEFINDER=TRUE
MODULE_ISELEMENT=TRUE
MODULE_PROPHAGE=FALSE
MODULE_PHISPY=TRUE
MODULE_VIRSORTER2=FALSE
MODULE_PIDE="$CUDA_AVAILABLE"
MODULE_EGGNOG=TRUE
MODULE_INTERPROSCAN=TRUE

set_all_modules() {
  local value="$1"
  MODULE_DBCAN="$value"
  MODULE_MEROPS="$value"
  MODULE_CLEAN="$value"
  MODULE_PAZY="$value"
  MODULE_GAPMIND="$value"
  MODULE_DEFENSEFINDER="$value"
  MODULE_DBAPIS="$value"
  MODULE_ACRFINDER="$value"
  MODULE_PADLOC="$value"
  MODULE_DEFENSEPREDICTOR="$value"
  MODULE_REBASEFINDER="$value"
  MODULE_ISELEMENT="$value"
  MODULE_PROPHAGE=FALSE
  MODULE_PHISPY="$value"
  MODULE_VIRSORTER2="$value"
  MODULE_PIDE="$value"
  MODULE_EGGNOG="$value"
  MODULE_INTERPROSCAN="$value"
}

set_module_flag() {
  local module_name="$1"
  local value="$2"
  case "$module_name" in
    dbcan) MODULE_DBCAN="$value" ;;
    merops) MODULE_MEROPS="$value" ;;
    clean) MODULE_CLEAN="$value" ;;
    pazy) MODULE_PAZY="$value" ;;
    gapmind) MODULE_GAPMIND="$value" ;;
    defensefinder) MODULE_DEFENSEFINDER="$value" ;;
    dbapis) MODULE_DBAPIS="$value" ;;
    acrfinder) MODULE_ACRFINDER="$value" ;;
    padloc) MODULE_PADLOC="$value" ;;
    defensepredictor) MODULE_DEFENSEPREDICTOR="$value" ;;
    rebasefinder) MODULE_REBASEFINDER="$value" ;;
    iselement) MODULE_ISELEMENT="$value" ;;
    phispy) MODULE_PHISPY="$value" ;;
    virsorter2) MODULE_VIRSORTER2="$value" ;;
    pide) MODULE_PIDE="$value" ;;
    prophage) MODULE_PROPHAGE="$value" ;;
    eggnog) MODULE_EGGNOG="$value" ;;
    interproscan) MODULE_INTERPROSCAN="$value" ;;
  esac
}

INPUT_PATH=""
OUTPUT_DIR=""
MODULES_SPEC=""
SKIP_MODULES=""
CPU_SPEC=""
PROPHAGE_BACKEND=""
CLEAN_PREVIOUS="TRUE"
DNMB_AUTO_UPDATE="${DNMB_AUTO_UPDATE:-0}"
DNMB_AUTO_UPDATE_BRANCH="${DNMB_AUTO_UPDATE_BRANCH:-master}"
IMAGE="${DNMBSUITE_IMAGE:-ghcr.io/jaeyoonsung/dnmbsuite:latest}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --modules)
      MODULES_SPEC="${2:-}"
      shift 2
      ;;
    --skip-modules)
      SKIP_MODULES="${2:-}"
      shift 2
      ;;
    --cpu)
      CPU_SPEC="${2:-}"
      shift 2
      ;;
    --prophage-backend)
      PROPHAGE_BACKEND="${2:-}"
      shift 2
      ;;
    --keep-previous)
      CLEAN_PREVIOUS="FALSE"
      shift
      ;;
    --dnmb-auto-update)
      DNMB_AUTO_UPDATE="1"
      shift
      ;;
    --dnmb-auto-update-branch)
      DNMB_AUTO_UPDATE_BRANCH="${2:-}"
      shift 2
      ;;
    --image)
      IMAGE="${2:-}"
      shift 2
      ;;
    --*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$INPUT_PATH" ]; then
        INPUT_PATH="$1"
      elif [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$1"
      else
        echo "Error: unexpected positional argument: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$INPUT_PATH" ]; then
  usage >&2
  exit 1
fi

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

if [ -n "$CPU_SPEC" ] && ! [[ "$CPU_SPEC" =~ ^[0-9]+$ ]]; then
  echo "Error: --cpu must be an integer." >&2
  exit 1
fi

if [ -n "$PROPHAGE_BACKEND" ]; then
  case "$PROPHAGE_BACKEND" in
    phispy|virsorter2|pide) ;;
    *)
      echo "Error: --prophage-backend must be one of: phispy, virsorter2, pide" >&2
      exit 1
      ;;
  esac
fi

INPUT_ABS="$(cd "$(dirname "$INPUT_PATH")" && pwd)/$(basename "$INPUT_PATH")"
INPUT_BASENAME="$(basename "$INPUT_ABS")"
INPUT_DIR="$(dirname "$INPUT_ABS")"

if [ -n "$OUTPUT_DIR" ]; then
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

ensure_image "$IMAGE"

if [ -n "$MODULES_SPEC" ]; then
  set_all_modules FALSE

  case "$(normalize_module_name "$MODULES_SPEC")" in
    all)
      set_all_modules TRUE
      ;;
    none|core)
      ;;
    *)
      while IFS= read -r module_name; do
        if [ -n "$module_name" ] && [ "$module_name" != "all" ] && [ "$module_name" != "none" ] && [ "$module_name" != "core" ]; then
          set_module_flag "$module_name" TRUE
        fi
      done < <(split_csv "$MODULES_SPEC")
      ;;
  esac
fi

if [ -n "$SKIP_MODULES" ]; then
  while IFS= read -r module_name; do
    if [ -n "$module_name" ] && [ "$module_name" != "all" ] && [ "$module_name" != "none" ] && [ "$module_name" != "core" ]; then
      set_module_flag "$module_name" FALSE
    fi
  done < <(split_csv "$SKIP_MODULES")
fi

R_ARGS=()
R_ARGS+=("clean_previous = ${CLEAN_PREVIOUS}")
R_ARGS+=("module_cache_root = \"/opt/dnmb-cache\"")
R_ARGS+=("module_dbCAN = ${MODULE_DBCAN}")
R_ARGS+=("module_MEROPS = ${MODULE_MEROPS}")
R_ARGS+=("module_CLEAN = ${MODULE_CLEAN}")
R_ARGS+=("module_PAZy = ${MODULE_PAZY}")
R_ARGS+=("module_GapMind = ${MODULE_GAPMIND}")
R_ARGS+=("module_DefenseFinder = ${MODULE_DEFENSEFINDER}")
R_ARGS+=("module_dbAPIS = ${MODULE_DBAPIS}")
R_ARGS+=("module_AcrFinder = ${MODULE_ACRFINDER}")
R_ARGS+=("module_PADLOC = ${MODULE_PADLOC}")
R_ARGS+=("module_DefensePredictor = ${MODULE_DEFENSEPREDICTOR}")
R_ARGS+=("module_REBASEfinder = ${MODULE_REBASEFINDER}")
R_ARGS+=("module_ISelement = ${MODULE_ISELEMENT}")
R_ARGS+=("module_Prophage = ${MODULE_PROPHAGE}")
R_ARGS+=("module_PhiSpy = ${MODULE_PHISPY}")
R_ARGS+=("module_VirSorter2 = ${MODULE_VIRSORTER2}")
R_ARGS+=("module_PIDE = ${MODULE_PIDE}")
R_ARGS+=("module_EggNOG = ${MODULE_EGGNOG}")
R_ARGS+=("module_InterProScan = ${MODULE_INTERPROSCAN}")

if [ -n "$CPU_SPEC" ]; then
  R_ARGS+=("module_cpu = ${CPU_SPEC}L")
fi

if [ -n "$PROPHAGE_BACKEND" ]; then
  R_ARGS+=("module_Prophage_backend = \"${PROPHAGE_BACKEND}\"")
fi

R_ARG_STRING=""
for arg in "${R_ARGS[@]}"; do
  if [ -n "$R_ARG_STRING" ]; then
    R_ARG_STRING+=", "
  fi
  R_ARG_STRING+="$arg"
done

R_EXPR="library(DNMB); setwd(\"/data\"); run_DNMB(${R_ARG_STRING})"

GPU_ARGS=()
if [ "$CUDA_AVAILABLE" = TRUE ]; then
  GPU_ARGS+=(--gpus all)
fi

if docker run --rm \
  "${GPU_ARGS[@]}" \
  -e "DNMB_AUTO_UPDATE=$DNMB_AUTO_UPDATE" \
  -e "DNMB_AUTO_UPDATE_BRANCH=$DNMB_AUTO_UPDATE_BRANCH" \
  -e "DNMB_CUDA=$CUDA_AVAILABLE" \
  -v "$OUTPUT_ABS:/data" \
  -v "$CACHE_ROOT:/opt/dnmb-cache" \
  --ulimit stack=67108864 \
  "$IMAGE" \
  env -u R_HOME Rscript --vanilla -e "$R_EXPR"; then
  cleanup_output_dir "$OUTPUT_ABS"
else
  exit $?
fi
