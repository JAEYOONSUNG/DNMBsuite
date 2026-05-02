#!/usr/bin/env sh
set -eu

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required binary: $1" >&2
    exit 1
  }
}

for bin in \
  Rscript hmmsearch hmmpress hmmscan blastp blastn makeblastdb diamond prodigal \
  run_dbcan padloc emapper.py phispy RNAfold RNAplfold RNAduplex \
  vmatch2 mkvtree2 vsubseqselect2 rpsblast rpsblast+ clustalw clustalw2 muscle
do
  need_bin "$bin"
done

test -f "${DNMB_VMATCH_SEL392}"
test -f /usr/lib/vmatch/SELECT/sel392.so

/opt/biotools/bin/python - <<'PY'
mods = ["numpy", "pandas", "joblib", "Bio", "progressbar", "sklearn"]
for mod in mods:
    __import__(mod)
PY

Rscript - <<'RS'
required <- c(
  "DNMB", "dplyr", "ggplot2", "ggtext", "openxlsx",
  "Biostrings", "ComplexHeatmap", "DefenseViz"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing R packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

library(DNMB)

promotech_status <- DNMB:::.dnmb_promotech_python_status(python = "python3", model = "RF-HOT")
promotech_bad <- promotech_status$status %in% c("missing", "failed")
if (any(promotech_bad)) {
  stop(
    "Promotech runtime check failed: ",
    paste(promotech_status$detail[promotech_bad], collapse = "; "),
    call. = FALSE
  )
}

acr_module <- DNMB:::dnmb_acrfinder_get_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), required = TRUE)
acr_paths <- strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1]]
acr_status <- DNMB:::.dnmb_acrfinder_runtime_status(acr_paths, repo_dir = acr_module$manifest$repo_dir)
acr_bad <- acr_status$status %in% c("missing", "failed")
if (any(acr_bad)) {
  stop(
    "AcrFinder runtime check failed: ",
    paste(acr_status$detail[acr_bad], collapse = "; "),
    call. = FALSE
  )
}

dbcan_sig <- DNMB:::.dnmb_collect_module_db_signatures("dbCAN", module_cache_root = Sys.getenv("DNMB_CACHE_ROOT"))
if (!isTRUE(dbcan_sig[["dbCAN"]][["run_dbcan_available"]])) {
  stop("dbCAN runtime check failed: run_dbcan is not available.", call. = FALSE)
}

cat("DNMBsuite runtime verification passed\n")
RS
