# VI-FLO migration: correct z6-13388 status and close its port configuration
#
# ONE-TIME SCRIPT.
#
# z6-13388 ("SR2 Hillside") at sr2_vwc1 was recorded as `decommissioned`, but
# the station was not shut down - the device was swapped for z6-12898
# ("SR2-HS v2"), deployed fifteen minutes after the old one last reported.
# That is `replaced`.
#
# Its five sensor port configurations were also never closed, so the record
# still claims those TEROS and ECRN sensors are live on a device that came out
# of the ground in January 2024. Nothing closed them because, until now, only
# device REMOVAL closed ports - replacement and decommissioning did not.
#
# Dates are taken from the record, not chosen:
#   valid_to   = 2024-01-22 13:00:00  (z6-13388's last_update)
#   valid_from = 2022-06-14 14:15:00  (for port 5, which has none; this is the
#                                      device's deploy_datetime, matching its
#                                      four sibling ports exactly)
#
# Safe to run twice - it detects that nothing needs changing and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fix_sr2_vwc1_replacement.R"))

migrate_fix_sr2_vwc1_replacement <- function(dry_run = TRUE) {

  SERIAL      <- "z6-13388"
  STATION     <- "sr2_vwc1"
  OLD_STATUS  <- "decommissioned"
  NEW_STATUS  <- "replaced"
  CLOSE_AT    <- "2024-01-22 13:00:00"
  PORT5_FROM  <- "2022-06-14 14:15:00"

  cat("\n============================================\n")
  cat("  Migration: correct ", SERIAL, "\n", sep = "")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_dir  <- wds("meta_internal")
  meta_file <- file.path(meta_dir, "device_metadata.csv")
  port_file <- file.path(meta_dir, "zentra_ports.csv")
  changes <- 0

  ############################################################################
  #### 1. Status
  ############################################################################
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  s_hits <- which(meta$device_serial == SERIAL &
                  meta$station_id == STATION &
                  meta$status == OLD_STATUS)

  cat("device_metadata.csv:\n")
  if (length(s_hits) == 0) {
    cat("  = No row with status '", OLD_STATUS, "' - already corrected\n", sep = "")
  } else {
    for (i in s_hits) {
      cat("  ", meta$unique_id[i], "  ", meta$device_name[i], "  ",
          OLD_STATUS, " -> ", NEW_STATUS, "\n", sep = "")
    }
    changes <- changes + length(s_hits)
  }

  ############################################################################
  #### 2. Port configurations
  ############################################################################
  ports <- read.csv(port_file, stringsAsFactors = FALSE)

  # Real sensors only - an empty port has nothing to close
  p_open <- which(ports$sn == SERIAL &
                  (is.na(ports$valid_to) | trimws(ports$valid_to) %in% c("", "NA")) &
                  !is.na(ports$sensor) & ports$sensor != "none")

  cat("\nzentra_ports.csv:\n")
  if (length(p_open) == 0) {
    cat("  = No open port configurations - already closed\n")
  } else {
    for (i in p_open) {
      cat("  Port ", ports$port[i], "  ", ports$sensor[i],
          "   valid_to: (open) -> ", CLOSE_AT, "\n", sep = "")
    }
    changes <- changes + length(p_open)
  }

  # Port 5 has no valid_from. Its four siblings all carry the device's
  # deploy_datetime, so that is what it should say - stated here rather than
  # inferred silently.
  p_nofrom <- which(ports$sn == SERIAL &
                    (is.na(ports$valid_from) | trimws(ports$valid_from) %in% c("", "NA")) &
                    !is.na(ports$sensor) & ports$sensor != "none")

  if (length(p_nofrom) > 0) {
    cat("\n  Missing valid_from (set to the device's deploy_datetime,\n")
    cat("  which is what the sibling ports carry):\n")
    for (i in p_nofrom) {
      cat("  Port ", ports$port[i], "  ", ports$sensor[i],
          "   valid_from: (blank) -> ", PORT5_FROM, "\n", sep = "")
    }
    changes <- changes + length(p_nofrom)
  }

  ############################################################################
  #### Apply
  ############################################################################
  cat("\n--------------------------------------------\n")

  if (dry_run) {
    cat(changes, " change(s) would be made.\n\n", sep = "")
    if (changes > 0) {
      cat("Re-run with dry_run = FALSE to apply:\n")
      cat("  migrate_fix_sr2_vwc1_replacement(dry_run = FALSE)\n\n")
    }
    return(invisible(changes))
  }

  if (changes == 0) {
    cat("Nothing to do.\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  if (length(s_hits) > 0) {
    meta$status[s_hits] <- NEW_STATUS
    write.csv(meta, meta_file, row.names = FALSE)
    cat("+ Status corrected to '", NEW_STATUS, "'\n", sep = "")
  }

  if (length(p_open) > 0 || length(p_nofrom) > 0) {
    if (length(p_open) > 0)   ports$valid_to[p_open] <- CLOSE_AT
    if (length(p_nofrom) > 0) ports$valid_from[p_nofrom] <- PORT5_FROM
    write.csv(ports, port_file, row.names = FALSE)
    cat("+ Closed ", length(p_open), " port configuration(s)\n", sep = "")
  }

  ############################################################################
  #### Verify
  ############################################################################
  ok <- TRUE

  meta_check  <- read.csv(meta_file, stringsAsFactors = FALSE)
  ports_check <- read.csv(port_file, stringsAsFactors = FALSE)

  if (any(meta_check$device_serial == SERIAL & meta_check$status == OLD_STATUS)) {
    cat("X Status not corrected\n")
    ok <- FALSE
  }

  still_open <- which(ports_check$sn == SERIAL &
                      (is.na(ports_check$valid_to) |
                       trimws(ports_check$valid_to) %in% c("", "NA")) &
                      !is.na(ports_check$sensor) & ports_check$sensor != "none")
  if (length(still_open) > 0) {
    cat("X ", length(still_open), " port configuration(s) still open\n", sep = "")
    ok <- FALSE
  }

  if (ok) {
    cat("\n+ Verified: status is '", NEW_STATUS,
        "' and no sensor ports remain open\n\n", sep = "")
    cat("NEXT: run validate_metadata()\n\n")
  } else {
    cat("\nX Verification FAILED. Restore from metadata/internal/backups/\n\n")
  }

  invisible(ok)
}

migrate_fix_sr2_vwc1_replacement(dry_run = TRUE)
