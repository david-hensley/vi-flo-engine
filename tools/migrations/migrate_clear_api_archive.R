# VI-FLO migration: clear the superseded automatic download archive
#
# ONE-TIME SCRIPT.
#
# Seventeen station files were downloaded through the v4 API in January 2026,
# before the ZentraCloud full-history exports existed. They are superseded and
# should not be built on:
#
#   1. DEPTH IS BAKED INTO COLUMN NAMES. Columns are vwc_10cm, vwc_30cm and so
#      on, resolved from zentra_ports.csv at download time. Any later
#      correction to a port's depth silently invalidates the file - which has
#      already happened at uvi_vwc1, where two ports both claimed 10 cm, one
#      overwrote the other, and four years of the shallowest sensor's data was
#      replaced by five impossible readings from a dying sensor.
#
#   2. WIDE FORMAT, MIXED TYPES. One row per timestamp with weather and vwc
#      columns side by side. The uvi_vwc1 file carries solar radiation and wind
#      direction. Neither the export parser nor zentraR produces this shape.
#
#   3. SUPERSEDED IN COVERAGE. Every one of the seventeen stations is covered
#      by the September 2026 exports, which run eight months later.
#
# Nothing is lost. The exports are the source of record through September 2026,
# and the API covers everything after in the matching long format.
#
#
# WHAT IT CLEARS, TOGETHER
#
# Three things reference these downloads, and removing one without the others
# leaves the record lying:
#
#   - the RDS files themselves
#   - their rows in download_log.csv, which validate_metadata() checks resolve
#     to files that exist
#   - last_download_date in device_metadata.csv, which would otherwise claim a
#     download that no longer exists and mislead a future job about where to
#     resume
#
# Only `automatic` downloads are touched. Manual HOBO ingests are a different
# format from a different source and are left alone.
#
# Safe to run twice: it exits when there are no automatic rows left.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_clear_api_archive.R"))

migrate_clear_api_archive <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: clear superseded API archive\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_dir  <- wds("meta_internal")
  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  log_file  <- file.path(meta_dir, "download_log.csv")
  meta_file <- file.path(meta_dir, "device_metadata.csv")

  if (!file.exists(log_file)) {
    cat("X download_log.csv not found\n\n")
    return(invisible(FALSE))
  }

  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  auto <- which(dlog$download_type == "automatic")

  if (length(auto) == 0) {
    cat("+ No automatic downloads remain - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  cat("Automatic downloads to clear: ", length(auto), "\n", sep = "")
  cat("Manual downloads kept:        ", sum(dlog$download_type != "automatic"),
      "\n\n", sep = "")

  #### Files ####
  paths <- file.path(data_root, dlog$filepath[auto])
  present <- file.exists(paths)

  cat("Files:\n\n")
  for (k in seq_along(auto)) {
    cat("  ", format(dlog$station[auto[k]], width = 14),
        format(dlog$n_records[auto[k]], width = 8, big.mark = ","),
        "  ", basename(dlog$filepath[auto[k]]),
        if (!present[k]) "   (already gone)" else "", "\n", sep = "")
  }

  #### Which devices claim one of these downloads ####
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)
  affected_stations <- unique(dlog$station[auto])

  blank <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")
  to_clear <- which(meta$station_id %in% affected_stations &
                    !blank(meta$last_download_date))

  cat("\nlast_download_date to clear: ", length(to_clear), " device row(s)\n",
      sep = "")
  for (i in to_clear) {
    cat("  ", format(meta$station_id[i], width = 14),
        format(meta$device_serial[i], width = 11),
        "  ", as.character(meta$last_download_date[i]), "\n", sep = "")
  }

  if (dry_run) {
    cat("\n--------------------------------------------\n")
    cat("Would delete ", sum(present), " file(s), ", length(auto),
        " log row(s), and clear ", length(to_clear),
        " last_download_date value(s).\n\n", sep = "")
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_clear_api_archive(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up before touching anything ####
  backup_metadata()
  cat("\n+ Metadata backed up\n")

  #### 1. The files ####
  removed <- 0
  for (k in seq_along(auto)) {
    if (present[k] && file.remove(paths[k])) removed <- removed + 1
  }
  cat("+ Deleted ", removed, " file(s)\n", sep = "")

  #### 2. The log rows ####
  dlog <- dlog[-auto, , drop = FALSE]
  write.csv(dlog, log_file, row.names = FALSE)
  cat("+ Removed ", length(auto), " download_log row(s)\n", sep = "")

  #### 3. last_download_date ####
  if (length(to_clear) > 0) {
    meta$last_download_date[to_clear] <- NA
    save_device_metadata(meta)
    cat("+ Cleared ", length(to_clear), " last_download_date value(s)\n",
        sep = "")
  }

  #### Verify ####
  ok <- TRUE

  check_log <- read.csv(log_file, stringsAsFactors = FALSE)
  if (any(check_log$download_type == "automatic")) {
    cat("\nX automatic rows remain in download_log\n"); ok <- FALSE
  }

  # Every remaining logged file must still exist - the check that catches a
  # deletion that went further than intended
  missing <- !file.exists(file.path(data_root, check_log$filepath))
  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in check_log$filepath[missing]) cat("   ", f, "\n", sep = "")
    ok <- FALSE
  }

  check_meta <- read.csv(meta_file, stringsAsFactors = FALSE)
  still <- which(check_meta$station_id %in% affected_stations &
                 !blank(check_meta$last_download_date))
  if (length(still) > 0) {
    cat("\nX last_download_date still set on ", length(still), " row(s)\n",
        sep = "")
    ok <- FALSE
  }

  if (!ok) {
    cat("\nX Verification FAILED. Restore from metadata/internal/backups/\n\n")
    return(invisible(FALSE))
  }

  cat("\n+ Verified: no automatic rows, ", nrow(check_log),
      " manual row(s) all resolving to files that exist\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_clear_api_archive(dry_run = TRUE)
