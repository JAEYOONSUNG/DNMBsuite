#!/usr/bin/env bash
set -euo pipefail

# Raise the C stack soft limit. DNMB's CAZy carbon plot (and some of
# the other layout-heavy ggplot2/circlize chains) walks a deep helper
# tree that blows the default 8 MB Linux stack with
#   Error: C stack usage XXXXXXX is too close to the limit
# Bumping to 64 MB gives a large safety margin without impacting
# memory (each thread still grows on demand).
if command -v ulimit >/dev/null 2>&1; then
  ulimit -s 65536 2>/dev/null || true
fi

if [ "${DNMB_ENTRYPOINT_SKIP_ROOT_SETUP:-0}" != "1" ]; then
  mkdir -p "${DNMB_CACHE_ROOT:-/opt/dnmb/cache}"

  if [ -z "${JAVA_HOME:-}" ] && [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
  fi

  if [ -d "${JAVA_HOME:-}/lib/server" ]; then
    export LD_LIBRARY_PATH="${JAVA_HOME}/lib/server${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi

  if [ -d "/opt/biotools/lib/R/library" ]; then
    export R_LIBS_SITE="/opt/biotools/lib/R/library${R_LIBS_SITE:+:${R_LIBS_SITE}}"
    export R_LIBS="/opt/biotools/lib/R/library${R_LIBS:+:${R_LIBS}}"
  fi

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
fi

maybe_drop_privileges() {
  if [ "${DNMB_ENTRYPOINT_SKIP_ROOT_SETUP:-0}" = "1" ]; then
    return 0
  fi
  if [ "$(id -u)" != "0" ]; then
    return 0
  fi
  if [ ! -d /data ]; then
    return 0
  fi
  if ! command -v gosu >/dev/null 2>&1; then
    return 0
  fi

  local target_uid target_gid
  target_uid="$(stat -c '%u' /data 2>/dev/null || echo 0)"
  target_gid="$(stat -c '%g' /data 2>/dev/null || echo 0)"

  if [ -z "$target_uid" ] || [ -z "$target_gid" ]; then
    return 0
  fi
  if [ "$target_uid" = "0" ] && [ "$target_gid" = "0" ]; then
    return 0
  fi

  export DNMB_ENTRYPOINT_SKIP_ROOT_SETUP=1
  exec gosu "${target_uid}:${target_gid}" "$0" "$@"
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
    padloc) echo "padloc" ;;
    defensepredictor|defense-predictor) echo "defensepredictor" ;;
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
  MODULE_PADLOC="$value"
  MODULE_DEFENSEPREDICTOR="$value"
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
    padloc) MODULE_PADLOC="$value" ;;
    defensepredictor) MODULE_DEFENSEPREDICTOR="$value" ;;
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

build_r_arg_string() {
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
  MODULE_PADLOC=TRUE
  MODULE_DEFENSEPREDICTOR=TRUE
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
  r_args+=("module_PADLOC = ${MODULE_PADLOC}")
  r_args+=("module_DefensePredictor = ${MODULE_DEFENSEPREDICTOR}")
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

  printf '%s\n' "$arg_string"
}

run_dnmb_in_dir() {
  local workdir="$1"
  local arg_string
  local input_count
  input_count=$(find "$workdir" -maxdepth 1 -type f \( -name '*.gb' -o -name '*.gbk' -o -name '*.gbff' \) | wc -l | tr -d '[:space:]')
  if [ "$input_count" -eq 0 ]; then
    echo "Error: no .gb/.gbk/.gbff input file found in $workdir" >&2
    exit 1
  fi
  arg_string="$(build_r_arg_string)"
  cd "$workdir"
  exec Rscript -e "library(DNMB); run_DNMB(${arg_string})"
}

copy_tree_contents() {
  local src_dir="$1"
  local dest_dir="$2"
  local entry
  mkdir -p "$dest_dir"
  shopt -s dotglob nullglob
  for entry in "$src_dir"/*; do
    cp -R "$entry" "$dest_dir/"
  done
  shopt -u dotglob nullglob
}

run_dnmb_single_file() {
  local input_file="$1"
  local output_dir="${DNMB_OUTPUT_DIR:-$(dirname "$input_file")}"
  local stage_dir
  stage_dir="$(mktemp -d /tmp/dnmb-single-XXXXXX)"
  trap 'rm -rf "$stage_dir"' EXIT
  mkdir -p "$output_dir"
  cp -f "$input_file" "$stage_dir/$(basename "$input_file")"
  local arg_string
  arg_string="$(build_r_arg_string)"
  cd "$stage_dir"
  Rscript -e "library(DNMB); run_DNMB(${arg_string})"
  copy_tree_contents "$stage_dir" "$output_dir"
}

run_dnmb_default() {
  run_dnmb_in_dir /data
}

maybe_drop_privileges "$@"

if [ "$#" -eq 0 ]; then
  run_dnmb_default
fi

case "$1" in
  run|auto)
    shift
    if [ "$#" -eq 0 ]; then
      run_dnmb_default
    elif [ -d "$1" ]; then
      run_dnmb_in_dir "$1"
    elif [ -f "$1" ]; then
      case "$1" in
        *.gb|*.gbk|*.gbff)
          run_dnmb_single_file "$1"
          ;;
        *)
          echo "Error: input file must be .gb, .gbk, or .gbff" >&2
          exit 1
          ;;
      esac
    else
      echo "Error: target not found: $1" >&2
      exit 1
    fi
    ;;
  *)
    if [ -d "$1" ]; then
      run_dnmb_in_dir "$1"
    elif [ -f "$1" ]; then
      case "$1" in
        *.gb|*.gbk|*.gbff)
          run_dnmb_single_file "$1"
          ;;
        *)
          exec "$@"
          ;;
      esac
    else
      exec "$@"
    fi
    ;;
esac
