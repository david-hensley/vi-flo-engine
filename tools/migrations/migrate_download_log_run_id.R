# VI-FLO migration: add run_id to download_log
#
# ONE-TIME SCRIPT.
#
# Ties a download to the run that produced it. The scheduled job now writes a
# row per invocation to run_log.csv, and `run_id` is what joins the two: a
# Product 1 file, its download_log row and its run_log row all carry the same
# stamp.
#
# That makes two questions answerable that were not before - which run produced
# this file, and what did that run produce.
#
# Existing rows are filled from their filenames, which carry the fetch stamp
# for automatic downloads. Manual HOBO ingests are left blank: they have no
# run, because a run is a scheduled fetch and a shuttle offload is a person in
# a stream.
#
# Safe to run twice: it exits when the column is present.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_download_log_run_id.R"))

migrate_download_log_run_id <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: run_id in download_log\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  if ("run_id" %in% names(dlog)) {
    cat("+ run_id already present - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  # The fetch stamp is the segment containing a T
  run_ids <- vapply(basename(dlog$filepath), function(f) {
    stem <- sub("_raw\\.rds$", "", f)
    parts <- strsplit(stem, "_")[[1]]
    hit <- grep("^[0-9]{8}T[0-9]{6}$", parts, value = TRUE)
    if (length(hit) == 1) hit else NA_character_
  }, character(1), USE.NAMES = FALSE)

  auto <- dlog$download_type == "automatic"

  cat("Rows: ", nrow(dlog), "\n", sep = "")
  cat("  automatic: ", sum(auto), " (", sum(auto & !is.na(run_ids)),
      " with a recoverable run id)\n", sep = "")
  cat("  manual:    ", sum(!auto), " (left blank - a shuttle offload has no run)\n\n",
      sep = "")

  runs <- sort(unique(run_ids[!is.na(run_ids)]))
  cat("Distinct runs found: ", length(runs), "\n", sep = "")
  for (r in runs) {
    cat("  ", r, "  ", sum(run_ids %in% r), " download(s)\n", sep = "")
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_download_log_run_id(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("\n+ Backed up to: ", basename(backup_file), "\n", sep = "")

  dlog$run_id <- ifelse(auto, run_ids, NA_character_)

  cols <- names(dlog)
  cols <- cols[cols != "run_id"]
  dlog <- dlog[, append(cols, "run_id",
                        after = which(cols == "timestamp_utc")), drop = FALSE]

  write.csv(dlog, log_file, row.names = FALSE)

  check <- read.csv(log_file, stringsAsFactors = FALSE)
  ok <- "run_id" %in% names(check) && nrow(check) == nrow(dlog)

  if (!ok) {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Added run_id after timestamp_utc\n")
  cat("+ ", sum(!is.na(check$run_id)), " row(s) tied to a run\n\n", sep = "")
  cat("Columns now:\n  ", paste(names(check), collapse = ", "), "\n\n", sep = "")

  invisible(TRUE)
}

migrate_download_log_run_id(dry_run = TRUE)
