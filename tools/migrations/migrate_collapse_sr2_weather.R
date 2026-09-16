# VI-FLO migration: collapse the fictional row at sr2_weather
#
# ONE-TIME SCRIPT.
#
# On 2026-09-16 the Salt River 2 weather station was moved AND its logger
# swapped, in one field operation. Logged as two sequential workflows -
# relocation then replacement - that produced three rows where two describe
# what happened:
#
#   z-0001  z6-12866  old position  relocated    <- real: the device that came out
#   z-0030  z6-12866  NEW position  replaced     <- fiction: never deployed there
#   z-0031  z6-37440  new position  online       <- real: the device that went in
#
# z-0030 is an artefact of the workflows being separate. Its deploy_datetime
# equals the moment it went terminal, so it covers zero time and no reading can
# attribute to it - but it clutters every device menu.
#
# This collapses it: z-0031's content moves into z-0030's unique_id, leaving no
# gap in the sequence. z-0001 keeps status `relocated` - the row closed because
# the station moved, and the newer row shows where it went. That the serial
# also changed is visible in the same two rows, and the maintenance log holds
# both the relocation and the replacement with their coordinates.
#
# Safe to run twice - it detects that the collapse has happened and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_collapse_sr2_weather.R"))

migrate_collapse_sr2_weather <- function(dry_run = TRUE) {

  STATION   <- "sr2_weather"
  OLD_SN    <- "z6-12866"
  NEW_SN    <- "z6-37440"

  cat("\n============================================\n")
  cat("  Migration: collapse fictional row at ", STATION, "\n", sep = "")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  at_station <- which(meta$station_id == STATION)

  cat("Current rows at ", STATION, ":\n\n", sep = "")
  for (i in at_station) {
    cat("  ", format(meta$unique_id[i], width = 8),
        format(meta$device_serial[i], width = 11),
        format(meta$status[i], width = 12),
        meta$lat[i], ", ", meta$lon[i],
        "  elev ", meta$elev[i], "\n", sep = "")
  }
  cat("\n")

  #### Identify the three rows ####
  fiction <- which(meta$station_id == STATION &
                   meta$device_serial == OLD_SN &
                   tolower(meta$status) == "replaced")

  real_new <- which(meta$station_id == STATION &
                    meta$device_serial == NEW_SN)

  old_dev <- which(meta$station_id == STATION &
                   meta$device_serial == OLD_SN &
                   tolower(meta$status) == "relocated")

  if (length(fiction) == 0 && length(real_new) == 1) {
    cat("+ Already collapsed - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  if (length(fiction) != 1 || length(real_new) != 1 || length(old_dev) != 1) {
    cat("X Expected exactly one of each row, found:\n")
    cat("   fictional (", OLD_SN, ", replaced): ", length(fiction), "\n", sep = "")
    cat("   real new  (", NEW_SN, "):           ", length(real_new), "\n", sep = "")
    cat("   old device (", OLD_SN, ", relocated): ", length(old_dev), "\n", sep = "")
    cat("\n   Not collapsing - the situation is not the one this script\n")
    cat("   was written for.\n\n")
    return(invisible(FALSE))
  }

  keep_id <- meta$unique_id[fiction]
  drop_id <- meta$unique_id[real_new]

  cat("Planned:\n\n")
  cat("  ", drop_id, " (", NEW_SN, ") moves into unique_id ", keep_id, "\n",
      sep = "")
  cat("  ", drop_id, " is then removed, leaving no gap in the sequence\n", sep = "")
  cat("  ", meta$unique_id[old_dev], " (", OLD_SN, ") is left unchanged\n", sep = "")
  cat("\nResult - two rows:\n\n")
  cat("  ", format(meta$unique_id[old_dev], width = 8),
      format(OLD_SN, width = 11), format("relocated", width = 12),
      meta$lat[old_dev], ", ", meta$lon[old_dev], "\n", sep = "")
  cat("  ", format(keep_id, width = 8),
      format(NEW_SN, width = 11), format(meta$status[real_new], width = 12),
      meta$lat[real_new], ", ", meta$lon[real_new], "\n\n", sep = "")

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_collapse_sr2_weather(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  #### Move the real row's content into the fictional row's unique_id ####
  # Every column except unique_id, so nothing about the new device is lost
  cols <- setdiff(names(meta), "unique_id")
  meta[fiction, cols] <- meta[real_new, cols]

  #### Drop the now-duplicate row ####
  meta <- meta[-real_new, , drop = FALSE]

  write.csv(meta, meta_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)
  rows <- check[check$station_id == STATION, ]

  cat("+ Collapsed\n\n")
  cat("Rows at ", STATION, " now:\n\n", sep = "")
  for (i in seq_len(nrow(rows))) {
    cat("  ", format(rows$unique_id[i], width = 8),
        format(rows$device_serial[i], width = 11),
        format(rows$status[i], width = 12),
        rows$lat[i], ", ", rows$lon[i],
        "  elev ", rows$elev[i], "\n", sep = "")
  }

  ok <- nrow(rows) == 2 && !any(duplicated(check$unique_id))
  if (!ok) {
    cat("\nX Verification FAILED - expected 2 rows and unique ids\n\n")
    return(invisible(FALSE))
  }

  cat("\n+ Verified: 2 rows, unique_ids still unique\n\n")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_collapse_sr2_weather(dry_run = TRUE)
