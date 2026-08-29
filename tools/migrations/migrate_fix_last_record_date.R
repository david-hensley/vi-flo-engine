# VI-FLO migration: repair epoch-formatted last_record_date values
#
# ONE-TIME SCRIPT.
#
# last_record_date was written as a raw Unix epoch (e.g. 1769927566) rather
# than a datetime string. The cause: until the first ingest that column was
# entirely NA, so read.csv typed it as LOGICAL, and assigning a POSIXct into a
# logical vector silently strips the class and leaves the underlying number.
#
# The values are correct instants, just stored uselessly, so this converts
# rather than clears them. Nothing is guessed.
#
# Safe to run twice - it detects that no numeric values remain and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fix_last_record_date.R"))

migrate_fix_last_record_date <- function() {

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")

  cat("\n============================================\n")
  cat("  Migration: repair last_record_date\n")
  cat("============================================\n\n")

  if (!file.exists(meta_file)) {
    cat("X device_metadata.csv not found\n")
    return(invisible(FALSE))
  }

  meta <- read.csv(meta_file, stringsAsFactors = FALSE, colClasses = "character")

  if (!"last_record_date" %in% names(meta)) {
    cat("X No last_record_date column\n")
    return(invisible(FALSE))
  }

  values <- trimws(meta$last_record_date)
  # A bare run of digits is an epoch; a real datetime contains punctuation
  is_epoch <- grepl("^[0-9]{9,11}$", values)

  cat("Found ", sum(is_epoch), " epoch-formatted value(s)\n\n", sep = "")

  if (!any(is_epoch)) {
    cat("+ Nothing to repair.\n\n")
    return(invisible(TRUE))
  }

  tz <- meta$timezone[1]
  if (is.na(tz) || !nzchar(tz)) tz <- "America/Puerto_Rico"

  converted <- format(as.POSIXct(as.numeric(values[is_epoch]),
                                 origin = "1970-01-01", tz = tz),
                      "%Y-%m-%d %H:%M:%S")

  for (i in seq_along(which(is_epoch))) {
    idx <- which(is_epoch)[i]
    cat("  ", meta$station_id[idx], " (", meta$device_serial[idx], ")  ",
        values[idx], " -> ", converted[i], "\n", sep = "")
  }

  #### Back up before writing ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("device_metadata_", stamp, ".csv"))
  file.copy(meta_file, backup_file)
  cat("\n+ Backed up to: ", basename(backup_file), "\n", sep = "")

  meta$last_record_date[is_epoch] <- converted
  write.csv(meta, meta_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE, colClasses = "character")
  still_epoch <- grepl("^[0-9]{9,11}$", trimws(check$last_record_date))

  if (any(still_epoch)) {
    cat("\nX Verification FAILED - epoch values remain. Restore from:\n  ",
        backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Verified: ", sum(is_epoch), " value(s) converted, none remaining\n\n",
      sep = "")
  cat("Migration complete.\n\n")
  invisible(TRUE)
}

migrate_fix_last_record_date()
