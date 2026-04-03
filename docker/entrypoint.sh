#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${DNMB_CACHE_ROOT:-/opt/dnmb/cache}"

CLEAN_CACHE_ROOT="${DNMB_CACHE_ROOT:-/opt/dnmb/cache}/db_modules/clean/split100"
if [ ! -x "$CLEAN_CACHE_ROOT/conda_env/bin/python" ] && [ -f /opt/dnmb-seed/clean/split100/conda_env.tar.gz ]; then
  mkdir -p "$CLEAN_CACHE_ROOT"
  tar -xzf /opt/dnmb-seed/clean/split100/conda_env.tar.gz -C "$CLEAN_CACHE_ROOT"
fi

EGGNOG_CACHE="${DNMB_CACHE_ROOT:-/opt/dnmb/cache}/db_modules/eggnog/data"
if [ -d "$EGGNOG_CACHE" ]; then
  EMAPPER_DATA=$(python3 -c "import os,eggnogmapper;print(os.path.join(os.path.dirname(eggnogmapper.__file__),'data'))" 2>/dev/null || true)
  if [ -n "$EMAPPER_DATA" ] && [ ! -L "$EMAPPER_DATA" ]; then
    rm -rf "$EMAPPER_DATA" 2>/dev/null || true
    ln -sf "$EGGNOG_CACHE" "$EMAPPER_DATA" 2>/dev/null || true
  fi
fi

exec "$@"
