#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${DNMB_CACHE_ROOT:-/opt/dnmb/cache}"

CLEAN_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb/cache}/db_modules/clean/split100"
if [ ! -x "$CLEAN_CACHE_ROOT/conda_env/bin/python" ] && [ -f /opt/dnmb-seed/clean/split100/conda_env.tar.gz ]; then
  mkdir -p "$CLEAN_CACHE_ROOT"
  tar -xzf /opt/dnmb-seed/clean/split100/conda_env.tar.gz -C "$CLEAN_CACHE_ROOT"
fi

if [ -x "$CLEAN_CACHE_ROOT/conda_env/bin/python" ] && [ -f "$CLEAN_CACHE_ROOT/CLEAN/app/build.py" ]; then
  if ! "$CLEAN_CACHE_ROOT/conda_env/bin/python" -c "import CLEAN" >/dev/null 2>&1; then
    (
      cd "$CLEAN_CACHE_ROOT/CLEAN/app"
      "$CLEAN_CACHE_ROOT/conda_env/bin/python" build.py install >/dev/null 2>&1 || true
    )
  fi
fi

EGGNOG_CACHE="${DNMB_CACHE_ROOT:-/opt/dnmb/cache}/db_modules/eggnog/data"
if [ -d "$EGGNOG_CACHE" ]; then
  EMAPPER_DATA=$(python3 -c "import os,eggnogmapper;print(os.path.join(os.path.dirname(eggnogmapper.__file__),'data'))" 2>/dev/null || true)
  if [ -n "$EMAPPER_DATA" ] && [ ! -L "$EMAPPER_DATA" ]; then
    rm -rf "$EMAPPER_DATA" 2>/dev/null || true
    ln -sf "$EGGNOG_CACHE" "$EMAPPER_DATA" 2>/dev/null || true
  fi
fi

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
    rebasefinder|rebase) echo "rebasefinder" ;;
    iselement|iselements|is) echo "iselement" ;;
    prophage) echo "prophage" ;;
    eggnog) echo "eggnog" ;;
    interproscan|interpro) echo "interproscan" ;;
    all|none|core) echo "$raw" ;;
    *)
      echo ""
      ;;
  esac
}

set_all_modules() {
  local value="$1"
  MODULE_DBCAN="$value"
  MODULE_MEROPS="$value"
  MODULE_CLEAN="$value"
  MODULE_PAZY="$value"
  MODULE_GAPMIND="$value"
  MODULE_DEFENSEFINDER="$value"
  MODULE_REBASEFINDER="$value"
  MODULE_ISELEMENT="$value"
  MODULE_PROPHAGE="$value"
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
    rebasefinder) MODULE_REBASEFINDER="$value" ;;
    iselement) MODULE_ISELEMENT="$value" ;;
    prophage) MODULE_PROPHAGE="$value" ;;
    eggnog) MODULE_EGGNOG="$value" ;;
    interproscan) MODULE_INTERPROSCAN="$value" ;;
  esac
}

apply_module_csv() {
  local csv="$1"
  local value="$2"
  local module_name
  IFS=',' read -r -a module_items <<< "$csv"
  for module_name in "${module_items[@]}"; do
    module_name="$(normalize_module_name "$module_name")"
    if [ -n "$module_name" ] && [ "$module_name" != "all" ] && [ "$module_name" != "none" ] && [ "$module_name" != "core" ]; then
      set_module_flag "$module_name" "$value"
    fi
  done
}

run_dnmb_default() {
  local input_count
  input_count=$(find /data -maxdepth 1 -type f \( -name '*.gb' -o -name '*.gbk' -o -name '*.gbff' \) | wc -l | tr -d '[:space:]')
  if [ "$input_count" -eq 0 ]; then
    echo "Error: no .gb/.gbk/.gbff input file found in /data" >&2
    exit 1
  fi

  local clean_previous="${DNMB_CLEAN_PREVIOUS:-TRUE}"
  local module_cpu="${DNMB_MODULE_CPU:-}"
  local prophage_backend="${DNMB_PROPHAGE_BACKEND:-}"
  local modules="${DNMB_MODULES:-}"
  local skip_modules="${DNMB_SKIP_MODULES:-}"

  MODULE_DBCAN=TRUE
  MODULE_MEROPS=TRUE
  MODULE_CLEAN=TRUE
  MODULE_PAZY=TRUE
  MODULE_GAPMIND=TRUE
  MODULE_DEFENSEFINDER=TRUE
  MODULE_REBASEFINDER=TRUE
  MODULE_ISELEMENT=TRUE
  MODULE_PROPHAGE=TRUE
  MODULE_EGGNOG=TRUE
  MODULE_INTERPROSCAN=TRUE

  if [ -n "$modules" ]; then
    case "$(normalize_module_name "$modules")" in
      all)
        set_all_modules TRUE
        ;;
      none|core)
        set_all_modules FALSE
        ;;
      *)
        set_all_modules FALSE
        apply_module_csv "$modules" TRUE
        ;;
    esac
  fi

  if [ -n "$skip_modules" ]; then
    apply_module_csv "$skip_modules" FALSE
  fi

  local r_args=()
  r_args+=("clean_previous = ${clean_previous}")
  r_args+=("module_cache_root = \"/opt/dnmb/cache\"")
  r_args+=("module_dbCAN = ${MODULE_DBCAN}")
  r_args+=("module_MEROPS = ${MODULE_MEROPS}")
  r_args+=("module_CLEAN = ${MODULE_CLEAN}")
  r_args+=("module_PAZy = ${MODULE_PAZY}")
  r_args+=("module_GapMind = ${MODULE_GAPMIND}")
  r_args+=("module_DefenseFinder = ${MODULE_DEFENSEFINDER}")
  r_args+=("module_REBASEfinder = ${MODULE_REBASEFINDER}")
  r_args+=("module_ISelement = ${MODULE_ISELEMENT}")
  r_args+=("module_Prophage = ${MODULE_PROPHAGE}")
  r_args+=("module_EggNOG = ${MODULE_EGGNOG}")
  r_args+=("module_InterProScan = ${MODULE_INTERPROSCAN}")

  if [ -n "$module_cpu" ]; then
    r_args+=("module_cpu = ${module_cpu}L")
  fi

  if [ -n "$prophage_backend" ]; then
    r_args+=("module_Prophage_backend = \"${prophage_backend}\"")
  fi

  local arg_string=""
  local arg
  for arg in "${r_args[@]}"; do
    if [ -n "$arg_string" ]; then
      arg_string+=", "
    fi
    arg_string+="$arg"
  done

  exec Rscript -e "library(DNMB); setwd(\"/data\"); run_DNMB(${arg_string})"
}

if [ "$#" -eq 0 ]; then
  run_dnmb_default
fi

case "$1" in
  run|auto)
    shift
    run_dnmb_default
    ;;
  *)
    exec "$@"
    ;;
esac
