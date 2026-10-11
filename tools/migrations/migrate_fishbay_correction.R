# VI-FLO: correcting the Fish Bay entries
#
# ONE-TIME MIGRATION. Run after migrate_prototype_metadata.R and its second
# pass, both of which wrote these values on an account that has since been
# shown wrong.
#
#
# WHAT CHANGED, AND WHY
#
# The earlier reconstruction had FishBay1 (21179105) removed from the upstream
# position on 2023-03-31, because that was the last reading in the files then
# known. A further export has since surfaced - RB_1.csv, in a subfolder that
# earlier scans did not descend into - showing the logger ran from 2023-06-15
# to 2023-09-26.
#
# Its temperature on restarting settles that it was in the gut throughout, not
# in an office: it swings ten to sixteen degrees a day from the first reading,
# matching its neighbour, where a logger carried back out swings two degrees
# for three days first.
#
# So the record has two missing exports rather than a removal, and the logger
# left the gut on 2023-10-09 - recovered after Tropical Storm Philippe, with
# the mounting stake snapped and a boulder on the housing.
#
# See docs/backfill/fb2_hydro.md.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fishbay_correction.R"))
#   migrate_fishbay_correction()
#   migrate_fishbay_correction(dry_run = FALSE)

migrate_fishbay_correction <- function(dry_run = TRUE) {

  meta  <- load_zentra_metadata()
  maint <- load_maintenance_log()

  cat("\n############################################\n")
  cat("  Fish Bay, corrected\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n")

  #### The row for the 2021-2023 deployment ####
  idx <- which(meta$device_serial == "21179105" &
               meta$station_id == "fb2_hydro" &
               as.character(meta$deploy_datetime) == "2021-10-21 11:11:00")

  cat("\n  device_metadata.csv\n")
  n_fix <- 0
  if (length(idx) != 1) {
    cat("    !    no single row for FishBay1's 2021 deployment - nothing to do\n")
  } else {
    was <- as.character(meta$last_visit[idx])
    if (identical(was, "2023-10-09")) {
      cat("    ok   21179105   last_visit already 2023-10-09\n")
    } else {
      cat(sprintf("    FIX  21179105   last_visit  %s -> 2023-10-09\n", was))
      cat("           the day it was dug out, not the last offload before that\n")
      n_fix <- 1
    }
  }

  #### The maintenance entry ####
  cat("\n  maintenance_log.csv\n")
  mdate <- as.character(as.Date(maint$field_visit_date))
  old <- which(mdate == "2023-03-31" & maint$station_id == "fb2_hydro" &
               maint$device_serial == "21179105" &
               maint$action_type == "device_removal")

  n_drop <- length(old)
  if (n_drop) {
    cat("    DROP 2023-03-31 fb2_hydro   device_removal         21179105\n")
    cat("           records a removal that did not happen; the logger ran on\n")
    cat("           until 2023-09-26\n")
  } else {
    cat("    ok   nothing dated 2023-03-31 to remove\n")
  }

  new_entry <- list(
    date = "2023-10-09", station = "fb2_hydro", type = "hydro",
    serial = "21179105", action = "device_removal",
    details = paste("Recovered after Tropical Storm Philippe: mounting stake",
                    "snapped, boulder on the PVC housing, logger dug out and",
                    "intact. Last offload 2023-09-26; the export covering the",
                    "storm is missing."))

  have_new <- any(mdate == new_entry$date & maint$station_id == new_entry$station &
                  maint$device_serial == new_entry$serial &
                  maint$action_type == new_entry$action)
  n_add <- as.integer(!have_new)
  if (have_new) {
    cat("    ok   2023-10-09 entry already present\n")
  } else {
    cat("    ADD  2023-10-09 fb2_hydro   device_removal         21179105\n")
    cat("           ", substr(new_entry$details, 1, 64), "...\n", sep = "")
  }

  cat("\n############################################\n")
  cat("  ", n_fix, " field(s), ", n_drop, " entr(y/ies) dropped, ", n_add,
      " added\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_fishbay_correction(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  if (n_fix + n_drop + n_add == 0) {
    cat("\n+ Nothing to do.\n\n"); return(invisible(TRUE))
  }

  backup_metadata()
  cat("\n+ metadata backed up\n")

  if (n_fix) {
    meta$last_visit[idx] <- "2023-10-09"
    save_device_metadata(meta)
    cat("+ last_visit corrected\n")
  }

  if (n_drop) {
    maint <- maint[-old, , drop = FALSE]
    write.csv(maint, file.path(wds("meta_internal"), "maintenance_log.csv"),
              row.names = FALSE)
    cat("+ the 2023-03-31 entry removed\n")
  }

  if (n_add) {
    suppressMessages(
      write_maintenance_entry(new_entry$date, new_entry$station, new_entry$type,
                              new_entry$serial, new_entry$action,
                              new_entry$details, FALSE, "DAH"))
    cat("+ the 2023-10-09 entry added\n")
  }

  cat("\nNEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. the backfill import\n\n")

  invisible(TRUE)
}
