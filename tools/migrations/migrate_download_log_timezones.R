# VI-FLO migration: normalise timezones in download_log
#
# ONE-TIME SCRIPT.
#
# download_log.csv held two timezones with nothing saying so: `timestamp` was
# local while, for automatic downloads, `start_date` and `end_date` were UTC.
# A single row read 09:47 alongside 12:45 for the same afternoon.
#
# The convention is now:
#
#   timestamp_utc            when the download ran, in UTC
#   start_date, end_date     first and last reading, in PROJECT LOCAL time
#
# The split is deliberate rather than untidy. A reading belongs to a place,
# and that place has a recorded timezone - so local is what a person reading
# the log wants, and it matches what the HOBO path already writes. A run
# timestamp belongs to a moment and could be triggered from anywhere,
# including a cloud runner in another hemisphere, so UTC is the only
# unambiguous choice. The column is named for it so nobody has to look it up.
#
#
# WHAT CHANGES
#
#   all rows          timestamp -> timestamp_utc, converted from local to UTC
#   automatic rows    start_date and end_date converted from UTC to local
#   manual rows       start_date and end_date already local, left alone
#
# Safe to run twice: it exits once the column has been renamed.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_download_log_timezones.R"))

migrate_download_log_timezones <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: download_log timezones\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  if ("timestamp_utc" %in% names(dlog)) {
    cat("+ Already normalised - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  #### The project timezone, from metadata rather than assumed ####
  meta <- load_zentra_metadata()
  project_tz <- meta$timezone[!is.na(meta$timezone)][1]
  if (is.na(project_tz) || !nzchar(project_tz)) project_tz <- "America/Puerto_Rico"

  cat("Project timezone: ", project_tz, "\n", sep = "")
  cat("Rows: ", nrow(dlog), " (",
      sum(dlog$download_type == "automatic"), " automatic, ",
      sum(dlog$download_type != "automatic"), " manual)\n\n", sep = "")

  auto <- dlog$download_type == "automatic"

  #### Preview ####
  new_ts <- format(as.POSIXct(dlog$timestamp, tz = project_tz),
                   "%Y-%m-%d %H:%M:%S", tz = "UTC")

  new_start <- dlog$start_date
  new_end   <- dlog$end_date
  new_start[auto] <- format(as.POSIXct(dlog$start_date[auto], tz = "UTC"),
                            "%Y-%m-%d %H:%M:%S", tz = project_tz)
  new_end[auto]   <- format(as.POSIXct(dlog$end_date[auto], tz = "UTC"),
                            "%Y-%m-%d %H:%M:%S", tz = project_tz)

  show <- c(head(which(auto), 2), head(which(!auto), 2))
  cat("Examples:\n\n")
  for (i in show) {
    cat("  ", dlog$download_type[i], "  ", basename(dlog$filepath[i]), "\n", sep = "")
    cat("    ran    ", dlog$timestamp[i], "  ->  ", new_ts[i], "  (UTC)\n", sep = "")
    cat("    from   ", dlog$start_date[i], "  ->  ", new_start[i], "\n", sep = "")
    cat("    to     ", dlog$end_date[i], "  ->  ", new_end[i], "\n\n", sep = "")
  }

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_download_log_timezones(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("+ Backed up to: ", basename(backup_file), "\n", sep = "")

  dlog$timestamp  <- new_ts
  dlog$start_date <- new_start
  dlog$end_date   <- new_end
  names(dlog)[names(dlog) == "timestamp"] <- "timestamp_utc"

  write.csv(dlog, log_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)

  ok <- "timestamp_utc" %in% names(check) &&
        !"timestamp" %in% names(check) &&
        nrow(check) == nrow(dlog) &&
        !any(is.na(check$timestamp_utc))

  if (!ok) {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Converted ", nrow(check), " row(s)\n", sep = "")
  cat("+ Verified\n\n")
  cat("Columns now:\n  ", paste(names(check), collapse = ", "), "\n\n", sep = "")

  invisible(TRUE)
}

migrate_download_log_timezones(dry_run = TRUE)
