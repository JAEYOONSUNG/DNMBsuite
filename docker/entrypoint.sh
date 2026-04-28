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

dnmb_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dnmb_detect_cuda() {
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

dnmb_rscript() {
  env -u R_HOME Rscript --vanilla "$@"
}

dnmb_cleanup_outputs() {
  local output_dir="$1"

  rm -rf "$output_dir/temp" 2>/dev/null || true
  rm -f "$output_dir/Rplots.pdf" "$output_dir/Rplot.pdf" 2>/dev/null || true
}

dnmb_run_pipeline() {
  local workdir="$1"
  local arg_string="$2"

  cd "$workdir"
  if dnmb_rscript -e "library(DNMB); run_DNMB(${arg_string})"; then
    dnmb_cleanup_outputs "$workdir"
    return 0
  else
    return $?
  fi
}

dnmb_installed_sha() {
  dnmb_rscript -e 'desc <- suppressWarnings(utils::packageDescription("DNMB")); sha <- desc[["GithubSHA1"]]; if (is.null(sha) || is.na(sha)) sha <- ""; cat(sha)' 2>/dev/null | tr -d '\r\n'
}

dnmb_prepare_runtime_env() {
  local runtime_uid runtime_gid runtime_home runtime_cache

  runtime_uid="$(id -u)"
  runtime_gid="$(id -g)"

  if [ "$runtime_uid" = "0" ] && [ -d /data ]; then
    runtime_uid="$(stat -c '%u' /data 2>/dev/null || echo 0)"
    runtime_gid="$(stat -c '%g' /data 2>/dev/null || echo 0)"
    if [ -n "$runtime_uid" ] && [ "$runtime_uid" != "0" ]; then
      runtime_home="${DNMB_RUNTIME_HOME:-/tmp/dnmb-home-${runtime_uid}}"
      runtime_cache="${XDG_CACHE_HOME:-${runtime_home}/.cache}"
      export HOME="$runtime_home"
      export XDG_CACHE_HOME="$runtime_cache"
      export FONTCONFIG_PATH="${FONTCONFIG_PATH:-/etc/fonts}"
      mkdir -p "$runtime_cache/fontconfig" "$runtime_home" 2>/dev/null || true
      chown -R "${runtime_uid}:${runtime_gid}" "$runtime_home" 2>/dev/null || true
      chmod 700 "$runtime_home" 2>/dev/null || true
      return 0
    fi
  fi

  if [ -z "${HOME:-}" ] || [ ! -w "${HOME:-/nonexistent}" ]; then
    runtime_home="${DNMB_RUNTIME_HOME:-/tmp/dnmb-home-$(id -u)}"
    export HOME="$runtime_home"
  else
    runtime_home="$HOME"
  fi

  runtime_cache="${XDG_CACHE_HOME:-${runtime_home}/.cache}"
  export XDG_CACHE_HOME="$runtime_cache"
  export FONTCONFIG_PATH="${FONTCONFIG_PATH:-/etc/fonts}"
  mkdir -p "$runtime_cache/fontconfig" "$runtime_home" 2>/dev/null || true
}

if [ "${DNMB_ENTRYPOINT_SKIP_ROOT_SETUP:-0}" != "1" ]; then
  mkdir -p "${DNMB_CACHE_ROOT:-/opt/dnmb-cache}"

  if [ -z "${JAVA_HOME:-}" ] && [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
  fi

  if [ -d "${JAVA_HOME:-}/lib/server" ]; then
    export LD_LIBRARY_PATH="${JAVA_HOME}/lib/server${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi

  dnmb_prepare_runtime_env

  if [ -d "/opt/biotools/lib/R/library" ]; then
    export R_LIBS_SITE="/opt/biotools/lib/R/library${R_LIBS_SITE:+:${R_LIBS_SITE}}"
    export R_LIBS="/opt/biotools/lib/R/library${R_LIBS:+:${R_LIBS}}"
  fi

  # DNMB auto-update is opt-in so release images stay reproducible by default.
  if command -v git >/dev/null 2>&1 && command -v Rscript >/dev/null 2>&1; then
    _installed_sha="$(dnmb_installed_sha || true)"
    if dnmb_truthy "${DNMB_AUTO_UPDATE:-0}"; then
      _update_branch="${DNMB_AUTO_UPDATE_BRANCH:-master}"
      _remote_sha="$(git ls-remote https://github.com/JAEYOONSUNG/DNMB.git "refs/heads/${_update_branch}" 2>/dev/null | cut -f1 | head -c 40 || echo "")"
      _installed_sha_short="${_installed_sha:0:7}"
      if [ -z "$_installed_sha_short" ]; then
        _installed_sha_short="unknown"
      fi
      if [ -n "$_remote_sha" ] && { [ -z "$_installed_sha" ] || [ "$_remote_sha" != "$_installed_sha" ]; }; then
        echo "[DNMBsuite] Auto-updating DNMB from ${_update_branch} (installed: ${_installed_sha_short}, remote: ${_remote_sha:0:7})..."
        if dnmb_rscript -e 'branch <- Sys.getenv("DNMB_AUTO_UPDATE_BRANCH", unset = "master"); pak::pkg_install(sprintf("github::JAEYOONSUNG/DNMB@%s", branch), lib = .libPaths()[1])' 2>&1 | tail -3; then
          _updated_sha="$(dnmb_installed_sha || true)"
          if [ -n "$_updated_sha" ]; then
            echo "[DNMBsuite] DNMB auto-update complete (current: ${_updated_sha:0:7})."
          else
            echo "[DNMBsuite] DNMB auto-update completed."
          fi
        else
          echo "[DNMBsuite] DNMB auto-update failed; continuing with installed package." >&2
        fi
      elif [ -n "$_remote_sha" ] && [ -n "$_installed_sha" ]; then
        echo "[DNMBsuite] DNMB auto-update enabled; installed core already matches ${_update_branch} (${_installed_sha:0:7})."
      else
        echo "[DNMBsuite] DNMB auto-update enabled but installed or remote SHA could not be resolved; continuing with installed package." >&2
      fi
    fi
  fi

  CLEAN_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb-cache}/db_modules/clean/split100"
  if [ ! -x "$CLEAN_CACHE_ROOT/conda_env/bin/python" ] && [ -f /opt/dnmb-seed/clean/split100/conda_env.tar.gz ]; then
    mkdir -p "$CLEAN_CACHE_ROOT"
    tar -xzf /opt/dnmb-seed/clean/split100/conda_env.tar.gz -C "$CLEAN_CACHE_ROOT"
  fi

  DEFENSEFINDER_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb-cache}/db_modules/defensefinder"
  if [ ! -x "$DEFENSEFINDER_CACHE_ROOT/current/venv/bin/defense-finder" ] && [ -f /opt/dnmb-seed/defensefinder/current.tar.gz ]; then
    mkdir -p "$DEFENSEFINDER_CACHE_ROOT"
    tar -xzf /opt/dnmb-seed/defensefinder/current.tar.gz -C "$DEFENSEFINDER_CACHE_ROOT"
  fi

  DBAPIS_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb-cache}/db_modules/dbapis"
  if [ ! -f "$DBAPIS_CACHE_ROOT/current/data_download/dbAPIS.hmm" ] && [ -f /opt/dnmb-seed/dbapis/current.tar.gz ]; then
    mkdir -p "$DBAPIS_CACHE_ROOT"
    tar -xzf /opt/dnmb-seed/dbapis/current.tar.gz -C "$DBAPIS_CACHE_ROOT"
  fi

  ACRFINDER_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb-cache}/db_modules/acrfinder"
  if [ ! -x "$ACRFINDER_CACHE_ROOT/current/venv/bin/python" ] && [ -f /opt/dnmb-seed/acrfinder/current.tar.gz ]; then
    mkdir -p "$ACRFINDER_CACHE_ROOT"
    tar -xzf /opt/dnmb-seed/acrfinder/current.tar.gz -C "$ACRFINDER_CACHE_ROOT"
  fi

  if [ -x "$CLEAN_CACHE_ROOT/conda_env/bin/python" ] && [ -f "$CLEAN_CACHE_ROOT/CLEAN/app/build.py" ]; then
    if ! "$CLEAN_CACHE_ROOT/conda_env/bin/python" -c "import CLEAN" >/dev/null 2>&1; then
      (
        cd "$CLEAN_CACHE_ROOT/CLEAN/app"
        "$CLEAN_CACHE_ROOT/conda_env/bin/python" build.py install >/dev/null 2>&1 || true
      )
    fi
  fi

  EGGNOG_CACHE="${DNMB_CACHE_ROOT:-/opt/dnmb-cache}/db_modules/eggnog/data"
  if [ -d "$EGGNOG_CACHE" ]; then
    EMAPPER_DATA=$(python3 -c "import os,eggnogmapper;print(os.path.join(os.path.dirname(eggnogmapper.__file__),'data'))" 2>/dev/null || true)
    if [ -n "$EMAPPER_DATA" ] && [ ! -L "$EMAPPER_DATA" ]; then
      rm -rf "$EMAPPER_DATA" 2>/dev/null || true
      ln -sf "$EGGNOG_CACHE" "$EMAPPER_DATA" 2>/dev/null || true
    fi
  fi
fi

dnmb_prepare_runtime_env

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
    dbapis) echo "dbapis" ;;
    acrfinder|acr) echo "acrfinder" ;;
    padloc) echo "padloc" ;;
    defensepredictor|defense-predictor) echo "defensepredictor" ;;
    rebasefinder|rebase) echo "rebasefinder" ;;
    iselement|iselements|is) echo "iselement" ;;
    phispy) echo "phispy" ;;
    virsorter2) echo "virsorter2" ;;
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
  local comparative="${DNMB_COMPARATIVE:-}"
  local comparative_data_root="${DNMB_COMPARATIVE_DATA_ROOT:-}"
  local modules="${DNMB_MODULES:-}"
  local skip_modules="${DNMB_SKIP_MODULES:-}"
  local cuda_available
  cuda_available="$(dnmb_detect_cuda)"
  local force_cpu_heavy="${DNMB_FORCE_CPU_HEAVY:-${DNMB_FORCE_CPU_MODULES:-}}"

  MODULE_DBCAN=TRUE
  MODULE_MEROPS=TRUE
  MODULE_CLEAN="$cuda_available"
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
  MODULE_PIDE="$cuda_available"
  MODULE_EGGNOG=TRUE
  MODULE_INTERPROSCAN=TRUE

  if [ "$cuda_available" = TRUE ]; then
    echo "[DNMBsuite] CUDA detected; CLEAN/PIDE enabled by default." >&2
  elif dnmb_truthy "$force_cpu_heavy"; then
    MODULE_CLEAN=TRUE
    MODULE_PIDE=TRUE
    echo "[DNMBsuite] CUDA not detected; forcing CPU execution for CLEAN/PIDE because DNMB_FORCE_CPU_HEAVY=1." >&2
  else
    echo "[DNMBsuite] CUDA not detected; CLEAN/PIDE skipped by default. Override with DNMB_FORCE_CPU_HEAVY=1 or DNMB_MODULES=clean,pide." >&2
  fi

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
  r_args+=("module_cache_root = \"/opt/dnmb-cache\"")
  r_args+=("module_dbCAN = ${MODULE_DBCAN}")
  r_args+=("module_MEROPS = ${MODULE_MEROPS}")
  r_args+=("module_CLEAN = ${MODULE_CLEAN}")
  r_args+=("module_PAZy = ${MODULE_PAZY}")
  r_args+=("module_GapMind = ${MODULE_GAPMIND}")
  r_args+=("module_DefenseFinder = ${MODULE_DEFENSEFINDER}")
  r_args+=("module_dbAPIS = ${MODULE_DBAPIS}")
  r_args+=("module_AcrFinder = ${MODULE_ACRFINDER}")
  r_args+=("module_PADLOC = ${MODULE_PADLOC}")
  r_args+=("module_DefensePredictor = ${MODULE_DEFENSEPREDICTOR}")
  r_args+=("module_REBASEfinder = ${MODULE_REBASEFINDER}")
  r_args+=("module_ISelement = ${MODULE_ISELEMENT}")
  r_args+=("module_Prophage = ${MODULE_PROPHAGE}")
  r_args+=("module_PhiSpy = ${MODULE_PHISPY}")
  r_args+=("module_VirSorter2 = ${MODULE_VIRSORTER2}")
  r_args+=("module_PIDE = ${MODULE_PIDE}")
  r_args+=("module_EggNOG = ${MODULE_EGGNOG}")
  r_args+=("module_InterProScan = ${MODULE_INTERPROSCAN}")

  if [ -n "$module_cpu" ]; then
    r_args+=("module_cpu = ${module_cpu}L")
  fi

  if [ -n "$prophage_backend" ]; then
    r_args+=("module_Prophage_backend = \"${prophage_backend}\"")
  fi

  if dnmb_truthy "$comparative"; then
    r_args+=("comparative = TRUE")
    if [ -n "$comparative_data_root" ]; then
      r_args+=("comparative_data_root = \"${comparative_data_root}\"")
    fi
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
  dnmb_run_pipeline "$workdir" "$arg_string"
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
  trap 'rm -rf "${stage_dir:-}"' EXIT
  mkdir -p "$output_dir"
  cp -f "$input_file" "$stage_dir/$(basename "$input_file")"
  local arg_string
  arg_string="$(build_r_arg_string)"
  dnmb_run_pipeline "$stage_dir" "$arg_string"
  copy_tree_contents "$stage_dir" "$output_dir"
  dnmb_cleanup_outputs "$output_dir"
}

run_dnmb_default() {
  run_dnmb_in_dir /data
}

run_dnmb_comparative() {
  local data_root="${1:-${DNMB_COMPARATIVE_DATA_ROOT:-/data}}"
  local module_cpu="${DNMB_MODULE_CPU:-}"
  local module_install="${DNMB_MODULE_INSTALL:-TRUE}"

  if [ ! -d "$data_root" ]; then
    echo "Error: comparative data root not found: $data_root" >&2
    exit 1
  fi

  dnmb_rscript -e '
    library(DNMB)
    data_root <- normalizePath(Sys.getenv("DNMB_COMPARATIVE_DATA_ROOT", unset = commandArgs(TRUE)[1]), mustWork = TRUE)
    module_cpu_raw <- Sys.getenv("DNMB_MODULE_CPU", unset = "")
    module_cpu <- if (nzchar(module_cpu_raw)) suppressWarnings(as.integer(module_cpu_raw)) else NULL
    module_install_raw <- Sys.getenv("DNMB_MODULE_INSTALL", unset = "TRUE")
    module_install <- module_install_raw %in% c("1", "true", "TRUE", "yes", "YES", "on", "ON")
    DNMB:::.dnmb_run_comparative_suite(
      data_root = data_root,
      module_cache_root = Sys.getenv("DNMB_CACHE_ROOT", unset = "/opt/dnmb-cache"),
      module_install = module_install,
      module_cpu = module_cpu
    )
  ' "$data_root"
}

maybe_drop_privileges "$@"

if [ "$#" -eq 0 ]; then
  run_dnmb_default
fi

case "$1" in
  comparative)
    shift
    run_dnmb_comparative "${1:-${DNMB_COMPARATIVE_DATA_ROOT:-/data}}"
    ;;
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
