# VI-FLO migration: add download_type column to download_log.csv
#
# ONE-TIME SCRIPT. Adds a `download_type` column recording whether a download
# came through the Zentra API ("automatic") or was offloaded by hand from a
# logger in the field ("manual"). All pre-existing rows are API downloads and
# are backfilled as "automatic".
#
# Safe to run twice - it detects the column and exits without changing anything.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
#   load_functions("metadata")
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrate_download_type.R"))

migrate_download_type <- function() {

  log_file <- file.path(wds("meta_internal"), "download_log.csv")

  cat("\n============================================\n")
  cat("  Migration: add download_type column\n")
  cat("============================================\n\n")

  if (!file.exists(log_file)) {
    cat("X download_log.csv not found at:\n  ", log_file, "\n", sep = "")
    return(invisible(FALSE))
  }

  # Read WITHOUT date parsing so the datetime strings are written back
  # byte-identical. load_download_log() would parse them to POSIXct and
  # reformatting could silently alter them.
  log <- read.csv(log_file, stringsAsFactors = FALSE)

  cat("Found ", nrow(log), " rows\n", sep = "")
  cat("Columns: ", paste(names(log), collapse = ", "), "\n\n", sep = "")

  if ("download_type" %in% names(log)) {
    cat("+ download_type already present - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  #### Back up before touching anything ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)

  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("+ Backed up to: ", basename(backup_file), "\n", sep = "")

  #### Add the column ####
  # Every existing row predates the manual workflow, so all are API downloads.
  log$download_type <- "automatic"

  # write.csv quotes character columns and leaves numerics bare, which matches
  # how the file was originally written.
  write.csv(log, log_file, row.names = FALSE)

  cat("+ Added download_type = 'automatic' to all ", nrow(log), " rows\n", sep = "")

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)

  ok <- TRUE
  if (nrow(check) != nrow(log)) {
    cat("X Row count changed: ", nrow(log), " -> ", nrow(check), "\n", sep = "")
    ok <- FALSE
  }
  if (!"download_type" %in% names(check)) {
    cat("X download_type missing after write\n")
    ok <- FALSE
  }
  if (ok && any(check$download_type != "automatic")) {
    cat("X Unexpected download_type values present\n")
    ok <- FALSE
  }

  if (ok) {
    cat("+ Verified: ", nrow(check), " rows, all download_type = 'automatic'\n\n",
        sep = "")
    cat("Columns now: ", paste(names(check), collapse = ", "), "\n\n", sep = "")
    cat("Migration complete.\n\n")
  } else {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
  }

  invisible(ok)
}

migrate_download_type()
