# VI-FLO migration: add device_serial to download_log
#
# ONE-TIME SCRIPT.
#
# download_log.csv records one row per download, keyed by `station`. That made
# sense when every archived file was named for a station - but Product 1 files
# are keyed by DEVICE and carry no station at all, so an automatic download has
# no station to record.
#
# `device_serial` is added after `station`. Going forward:
#
#   automatic downloads   device_serial set, station NA - attribution happens
#                         at Product 2, not at download time
#   manual HOBO ingests   both set - the operator selected a station, and that
#                         is worth recording even though the file is named for
#                         the device
#
# Existing rows are filled from their filenames, which already carry the
# serial after the device-data restructuring.
#
# Safe to run twice: it exits when the column is present.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_download_log_serial.R"))

migrate_download_log_serial <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: device_serial in download_log\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  log_file <- file.path(wds("meta_internal"), "download_log.csv")

  if (!file.exists(log_file)) {
    cat("X download_log.csv not found\n\n")
    return(invisible(FALSE))
  }

  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  if ("device_serial" %in% names(dlog)) {
    cat("+ device_serial already present - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  #### Recover the serial from each filename ####
  serials <- vapply(basename(dlog$filepath), function(f) {
    p <- tryCatch(parse_raw_filename(f), error = function(e) NULL)
    if (is.null(p) || is.na(p$device_serial)) NA_character_ else p$device_serial
  }, character(1), USE.NAMES = FALSE)

  cat("Rows: ", nrow(dlog), "\n", sep = "")
  cat("Serial recovered from filename: ", sum(!is.na(serials)), "\n\n", sep = "")

  for (i in seq_len(nrow(dlog))) {
    cat("  ", format(dlog$station[i], width = 13),
        format(ifelse(is.na(serials[i]), "(none)", serials[i]), width = 11),
        "  ", basename(dlog$filepath[i]), "\n", sep = "")
  }

  if (any(is.na(serials))) {
    cat("\n! Some rows have no recoverable serial. They will be left blank -\n")
    cat("  the filename does not carry one, and nothing else can supply it.\n")
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_download_log_serial(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("\n+ Backed up to: ", basename(backup_file), "\n", sep = "")

  #### Insert after station ####
  dlog$device_serial <- serials
  cols <- names(dlog)
  cols <- cols[cols != "device_serial"]
  dlog <- dlog[, append(cols, "device_serial",
                        after = which(cols == "station")), drop = FALSE]

  write.csv(dlog, log_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)

  ok <- "device_serial" %in% names(check) &&
        nrow(check) == nrow(dlog) &&
        which(names(check) == "device_serial") == which(names(check) == "station") + 1

  if (!ok) {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Added device_serial after station\n")
  cat("+ Verified: ", nrow(check), " row(s), ",
      sum(!is.na(check$device_serial)), " with a serial\n\n", sep = "")
  cat("Columns now:\n  ", paste(names(check), collapse = ", "), "\n\n", sep = "")

  invisible(TRUE)
}

migrate_download_log_serial(dry_run = TRUE)
