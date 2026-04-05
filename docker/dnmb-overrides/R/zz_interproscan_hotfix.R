# Runtime hotfix for InterProScan auto-install version handling.
# DNMBsuite applies this overlay during image builds so published images can
# pick up the latest compatible InterProScan release without waiting for the
# core package release cycle.

.dnmb_interproscan_fallback_version <- function() "5.72-103.0"

.dnmb_interproscan_normalize_version <- function(version) {
  value <- trimws(as.character(version)[1])
  if (is.na(value) || !nzchar(value)) {
    return("")
  }
  sub("^v", "", value)
}

.dnmb_interproscan_latest_version <- function(default = .dnmb_interproscan_fallback_version()) {
  override <- .dnmb_interproscan_normalize_version(Sys.getenv("DNMB_INTERPROSCAN_VERSION", unset = ""))
  if (nzchar(override)) {
    return(override)
  }

  remote_info <- tryCatch(
    .dnmb_db_remote_check_interproscan(list(version = .dnmb_interproscan_normalize_version(default))),
    error = function(e) NULL
  )
  remote_version <- .dnmb_interproscan_normalize_version(
    if (!is.null(remote_info)) remote_info$remote_version else ""
  )

  if (nzchar(remote_version)) {
    remote_version
  } else {
    .dnmb_interproscan_normalize_version(default)
  }
}

.dnmb_interproscan_installed_script <- function(cache_root = NULL) {
  ipr_root <- file.path(.dnmb_db_cache_root(cache_root = cache_root, create = FALSE), "interproscan")
  if (!dir.exists(ipr_root)) {
    return("")
  }

  version_dirs <- list.dirs(ipr_root, full.names = TRUE, recursive = FALSE)
  if (!length(version_dirs)) {
    return("")
  }

  scripts <- file.path(version_dirs, "interproscan.sh")
  scripts <- scripts[file.exists(scripts)]
  if (!length(scripts)) {
    return("")
  }

  info <- file.info(scripts)
  scripts <- scripts[order(info$mtime, decreasing = TRUE, na.last = TRUE)]
  normalizePath(scripts[[1]], winslash = "/", mustWork = TRUE)
}

.dnmb_interproscan_default_version <- function(cache_root = NULL) {
  .dnmb_interproscan_latest_version(default = .dnmb_interproscan_fallback_version())
}

.dnmb_ensure_interproscan <- function(cache_root = NULL, version = NULL) {
  version <- .dnmb_interproscan_normalize_version(
    if (is.null(version) || !nzchar(trimws(as.character(version)[1]))) {
      .dnmb_interproscan_default_version(cache_root = cache_root)
    } else {
      version
    }
  )
  ipr_dir <- file.path(.dnmb_db_cache_root(cache_root = cache_root, create = TRUE), "interproscan", version)
  ipr_sh <- file.path(ipr_dir, "interproscan.sh")
  if (file.exists(ipr_sh)) {
    if (is.null(dnmb_db_read_manifest("interproscan", version, cache_root = cache_root, required = FALSE))) {
      try(
        dnmb_db_write_manifest(
          "interproscan",
          version,
          manifest = list(source_url = NA_character_, tarball = NA_character_),
          cache_root = cache_root,
          overwrite = FALSE
        ),
        silent = TRUE
      )
    }
    return(ipr_dir)
  }

  message("[InterProScan] Downloading InterProScan ", version, " to cache...")
  message("[InterProScan] This is a one-time download (~15GB). Please wait.")
  dir.create(ipr_dir, recursive = TRUE, showWarnings = FALSE)

  tarball <- paste0("interproscan-", version, "-64-bit.tar.gz")
  url <- paste0("https://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/", version, "/", tarball)
  dest <- file.path(tempdir(), tarball)

  dl <- dnmb_run_external("wget", args = c("-q", "--no-check-certificate", url, "-O", dest), required = FALSE)
  if (!isTRUE(dl$ok) || !file.exists(dest)) {
    stop("[InterProScan] Download failed. Check internet connection.", call. = FALSE)
  }

  message("[InterProScan] Extracting...")
  ex <- dnmb_run_external("tar", args = c("-xzf", dest, "--strip-components=1", "-C", ipr_dir), required = FALSE)
  unlink(dest, force = TRUE)
  if (!isTRUE(ex$ok)) {
    stop("[InterProScan] Extraction failed.", call. = FALSE)
  }

  setup_py <- file.path(ipr_dir, "setup.py")
  if (file.exists(setup_py)) {
    message("[InterProScan] Running setup...")
    dnmb_run_external("python3", args = c(setup_py, "-f", file.path(ipr_dir, "interproscan.properties")), wd = ipr_dir, required = FALSE)
  }

  if (file.exists(ipr_sh)) {
    try(
      dnmb_db_write_manifest(
        "interproscan",
        version,
        manifest = list(source_url = url, tarball = tarball),
        cache_root = cache_root,
        overwrite = TRUE
      ),
      silent = TRUE
    )
    message("[InterProScan] Installation complete: ", ipr_dir)
    return(ipr_dir)
  }
  stop("[InterProScan] Installation failed.", call. = FALSE)
}

.dnmb_find_interproscan <- function(path = NULL, cache_root = NULL) {
  if (!is.null(path) && nzchar(trimws(path))) {
    path <- path.expand(trimws(path))
    if (file.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
    stop("interproscan.sh not found at: ", path, call. = FALSE)
  }

  home <- Sys.getenv("INTERPROSCAN_HOME", "")
  if (nzchar(home)) {
    candidate <- file.path(home, "interproscan.sh")
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  on_path <- Sys.which("interproscan.sh")
  if (nzchar(on_path)) {
    return(normalizePath(on_path, winslash = "/", mustWork = TRUE))
  }

  cached_candidate <- .dnmb_interproscan_installed_script(cache_root = cache_root)
  ipr_dir <- tryCatch(
    .dnmb_ensure_interproscan(cache_root = cache_root),
    error = function(e) {
      if (nzchar(cached_candidate)) {
        warning(
          "[InterProScan] Could not prepare the latest cached release (",
          conditionMessage(e),
          "). Falling back to existing cached installation at ",
          cached_candidate,
          call. = FALSE
        )
      }
      NULL
    }
  )
  if (!is.null(ipr_dir)) {
    candidate <- file.path(ipr_dir, "interproscan.sh")
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  if (nzchar(cached_candidate)) {
    return(cached_candidate)
  }

  stop(
    "interproscan.sh not found. ",
    "Set the INTERPROSCAN_HOME environment variable or pass the path explicitly. ",
    "InterProScan is only available on Linux; use the DNMB Docker image for macOS/Windows.",
    call. = FALSE
  )
}
