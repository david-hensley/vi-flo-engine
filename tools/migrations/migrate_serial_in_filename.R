# VI-FLO migration: add device serial to manually-ingested raw filenames
#
# ONE-TIME SCRIPT.
#
# Manually-ingested raw files were named at STATION level. That breaks at a
# paired stream gauge, where two loggers share one station: the second file
# either carries a name that does not say which logger produced it, or
# silently overwrites the first.
#
# Files become {station}_{serial}_{start}_{end}_raw.rds.
#
# The SERIAL is used rather than the device name because names change - put a
# mutable thing in a filename and historic files stop matching the moment
# someone relabels a logger.
#
# Only files logged as download_type == "manual" are touched. API downloads
# keep station-level names, correctly: a Zentra station has one active device
# and the API collates across replacements.
#
# Safe to run twice - already-renamed files are detected and skipped.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_serial_in_filename.R"))

migrate_serial_in_filename <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: serial in manual raw filenames\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  log_file  <- file.path(wds("meta_internal"), "download_log.csv")

  if (!file.exists(log_file)) {
    cat("X download_log.csv not found\n")
    return(invisible(FALSE))
  }

  dlog <- read.csv(log_file, stringsAsFactors = FALSE, colClasses = "character")

  if (!"download_type" %in% names(dlog)) {
    cat("X No download_type column - run migrate_download_type.R first\n")
    return(invisible(FALSE))
  }

  manual_rows <- which(dlog$download_type == "manual")
  cat("Manual download rows: ", length(manual_rows), "\n\n", sep = "")

  if (length(manual_rows) == 0) {
    cat("+ Nothing to migrate.\n\n")
    return(invisible(TRUE))
  }

  #### Work out the new name for each ####
  # The serial comes from the maintenance log entry for that station and date,
  # not guessed. A station with one device is unambiguous either way; a paired
  # station is not, so a row we cannot resolve is reported and skipped rather
  # than assigned a serial that might belong to the other logger.
  metadata <- load_zentra_metadata()

  planned <- list()

  for (i in manual_rows) {
    old_rel  <- dlog$filepath[i]
    old_base <- basename(old_rel)
    station  <- dlog$station[i]

    parsed <- parse_raw_filename(old_base)

    if (is.null(parsed)) {
      cat("  ? Could not parse: ", old_base, " - skipping\n", sep = "")
      next
    }

    if (!is.na(parsed$device_serial)) {
      cat("  = Already has a serial: ", old_base, "\n", sep = "")
      next
    }

    devices <- metadata$device_serial[metadata$station_id == station &
                                      !metadata$status %in%
                                        c("removed", "replaced", "relocated",
                                          "decommissioned")]
    devices <- unique(devices[!is.na(devices)])

    if (length(devices) != 1) {
      cat("  ! ", old_base, " - station has ", length(devices),
          " active devices, cannot tell which produced it. Skipping.\n", sep = "")
      next
    }

    new_base <- sub(paste0("^", station, "_"),
                    paste0(station, "_", devices, "_"), old_base)

    planned[[length(planned) + 1]] <- list(
      row = i, old_rel = old_rel, old_base = old_base,
      new_base = new_base,
      new_rel = file.path(dirname(old_rel), new_base)
    )

    cat("  ", old_base, "\n    -> ", new_base, "\n", sep = "")
  }

  cat("\n", length(planned), " file(s) to rename\n", sep = "")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_serial_in_filename(dry_run = FALSE)\n\n")
    return(invisible(length(planned)))
  }

  if (length(planned) == 0) {
    cat("\n+ Nothing to do.\n\n")
    return(invisible(TRUE))
  }

  #### Back up the log before writing ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("\n+ Backed up download_log to: ", basename(backup_file), "\n", sep = "")

  #### Rename on disk, then update the log ####
  for (p in planned) {
    old_full <- file.path(data_root, p$old_rel)
    new_full <- file.path(data_root, p$new_rel)

    if (!file.exists(old_full)) {
      cat("  ! Missing on disk, log updated anyway: ", p$old_base, "\n", sep = "")
    } else if (file.exists(new_full)) {
      cat("  ! Target already exists, skipping: ", p$new_base, "\n", sep = "")
      next
    } else {
      file.rename(old_full, new_full)
    }

    dlog$filepath[p$row] <- p$new_rel
  }

  write.csv(dlog, log_file, row.names = FALSE)
  cat("+ Renamed ", length(planned), " file(s) and updated the log\n\n", sep = "")

  #### Verify: every logged filepath must resolve ####
  check <- read.csv(log_file, stringsAsFactors = FALSE, colClasses = "character")
  missing <- !file.exists(file.path(data_root, check$filepath))

  if (any(missing)) {
    cat("X Verification FAILED - these logged files do not exist:\n")
    for (f in check$filepath[missing]) cat("   ", f, "\n", sep = "")
    cat("\n  Restore from: ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Verified: all ", nrow(check),
      " logged filepaths resolve on disk\n\n", sep = "")
  cat("NEXT: run validate_metadata(), then push. Afterwards delete the stale\n")
  cat("station-level filenames from Box by hand - rclone copy uploads the new\n")
  cat("name but never removes the old one.\n\n")

  invisible(TRUE)
}

migrate_serial_in_filename(dry_run = TRUE)
