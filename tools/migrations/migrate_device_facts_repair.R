# VI-FLO: repairing the device facts
#
# ONE-TIME MIGRATION. Run after the backfill import.
#
#
# WHAT WENT WRONG
#
# The first version of update_hobo_device_facts() computed one last_record_date
# per SERIAL and wrote it to every row carrying that serial. Where a device
# served two stations over its life, the earlier deployment inherited the
# later one's figure:
#
#   21179105   both rows said 2026-03-23; the Fish Bay upstream deployment
#              ended 2023-09-26
#   21652376   both rows said 2026-03-23; the Turpentine Run 2 deployment
#              ended 2024-10-22
#   21652377   both rows said 2025-11-06; the St George Mint deployment is
#              still recording
#
# It also wrote interval_min from the observed timestamps. That was wrong in
# principle: the field carries the DECLARED interval, what the logger was
# configured to at its last relaunch. The observed interval belongs to the
# data, and the network memory check reads it there - precisely because a
# declared fifteen against an actual ten cost two stations a month each.
#
# This migration clears what was written wrongly and lets the corrected
# function fill it again.
#
#
# WHAT ELSE IT FIXES
#
#   reach_length_m  is "distance from this device to its station's primary",
#                   so only a secondary or tertiary carries it. Fish Bay's
#                   primary has it and should not.
#
#   bta2_hydro      the elevation survey of 2026-09-02 is in the maintenance
#                   log and was never carried into metadata.
#
#   date formats    some rows read 3/23/2026 rather than 2026-03-23, which is
#                   what a spreadsheet writes when a file is opened and saved.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_device_facts_repair.R"))
#   migrate_device_facts_repair()
#   migrate_device_facts_repair(dry_run = FALSE)

migrate_device_facts_repair <- function(dry_run = TRUE, restore_from = NULL) {

  meta <- load_zentra_metadata()

  cat("\n############################################\n")
  cat("  Device facts, repaired\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n")

  #### 1. Dates a spreadsheet rewrote ####
  #
  # 3/23/2026 instead of 2026-03-23. Normalised wherever it appears, in any
  # date column.
  date_cols <- intersect(c("deploy_datetime","last_visit","last_record_date",
                           "last_download_date","expiry_date",
                           "last_reviewed_utc"), names(meta))
  us <- function(v) grepl("^\\d{1,2}/\\d{1,2}/\\d{4}", as.character(v))

  cat("\n  Dates in US short format\n")
  n_date <- 0
  for (col in date_cols) {
    hit <- which(us(meta[[col]]))
    for (i in hit) {
      was <- as.character(meta[[col]][i])
      parsed <- suppressWarnings(as.POSIXct(was, format = "%m/%d/%Y %H:%M",
                                            tz = "America/Puerto_Rico"))
      if (is.na(parsed))
        parsed <- suppressWarnings(as.Date(was, format = "%m/%d/%Y"))
      if (is.na(parsed)) next
      to <- if (inherits(parsed, "Date")) format(parsed, "%Y-%m-%d")
            else format(parsed, "%Y-%m-%d %H:%M:%S")
      cat(sprintf("    %-10s %-12s %-18s %s -> %s\n", meta$device_serial[i],
                  meta$station_id[i], col, was, to))
      n_date <- n_date + 1
    }
  }
  if (n_date == 0) cat("    none\n")

  #### 2. interval_min, overwritten with an observed value ####
  #
  # The field carries the DECLARED interval - what the logger was set to at its
  # last relaunch, recorded through the metadata manager. The faulty function
  # replaced it with the modal interval across the device's whole life, which
  # for a logger that ran years at ten minutes and was corrected to fifteen
  # gives ten. 21352826's maintenance log says plainly "corrected interval to
  # 15 minutes from 10" on 2026-08-28; its row now reads 10.
  #
  # Restored from a backup taken before the import.
  bdir <- file.path(wds("meta_internal"), "backups")
  backups <- sort(list.files(bdir, pattern = "^device_metadata.*\\.csv$",
                             full.names = TRUE), decreasing = TRUE)

  cat("\n  interval_min, to restore from a backup\n")
  n_iv <- 0; prior <- NULL

  if (length(backups) == 0) {
    cat("    ! no device_metadata backups found\n")
  } else if (is.null(restore_from)) {
    cat("    Backups available, newest first:\n\n")
    for (b in head(backups, 8))
      cat(sprintf("      %-44s %s\n", basename(b),
                  format(file.mtime(b), "%Y-%m-%d %H:%M")))
    cat("\n    Pass the one taken BEFORE the backfill import:\n")
    cat("      migrate_device_facts_repair(restore_from = \"<name>\")\n")
  } else {
    pick <- backups[basename(backups) == restore_from]
    if (length(pick) != 1) {
      cat("    ! no backup called ", restore_from, "\n", sep = "")
    } else {
      prior <- read.csv(pick, stringsAsFactors = FALSE)
      hit <- match(meta$unique_id, prior$unique_id)
      for (i in which(!is.na(hit))) {
        was <- as.character(meta$interval_min[i])
        to  <- as.character(prior$interval_min[hit[i]])
        if (!identical(was, to) && !is.na(to) && nzchar(to)) {
          cat(sprintf("    %-10s %-12s interval %s -> %s\n",
                      meta$device_serial[i], meta$station_id[i], was, to))
          n_iv <- n_iv + 1
        }
      }
      if (n_iv == 0) cat("    nothing differs from that backup\n")
    }
  }

  #### 3. Facts written per serial instead of per deployment ####
  #
  # Cleared only where a serial has more than one row: a single-row device
  # could not have been given the wrong deployment's figure.
  multi <- names(which(table(meta$device_serial) > 1))
  to_clear <- which(meta$device_serial %in% multi &
                    meta$station_type == "hydro")

  cat("\n  Last record dates to clear and recompute\n")
  if (length(to_clear) == 0) cat("    none\n")
  for (i in to_clear)
    cat(sprintf("    %-10s %-12s deployed %s   currently %s\n",
                meta$device_serial[i], meta$station_id[i],
                substr(as.character(meta$deploy_datetime[i]), 1, 10),
                substr(as.character(meta$last_record_date[i]), 1, 10)))

  #### 4. reach_length_m belongs to the secondary alone ####
  cat("\n  reach_length_m on a primary\n")
  wrong_reach <- which(!is.na(meta$reach_length_m) &
                       meta$device_role %in% c("primary") &
                       meta$station_type == "hydro")
  if (length(wrong_reach) == 0) cat("    none\n")
  for (i in wrong_reach) {
    cat(sprintf("    %-10s %-12s %s -> NA\n", meta$device_serial[i],
                meta$station_id[i], meta$reach_length_m[i]))
    cat("           the dictionary defines it as the distance from this\n")
    cat("           device to its primary, so a primary cannot carry one\n")
  }

  #### 5. The Adventure elevation survey ####
  #
  # Logged 2026-09-02: primary 22.160 m, secondary 22.383 m, a difference of
  # 0.223 m. The difference is what matters - the absolute readings are
  # instrument heights, not datum elevations - so the secondary takes the
  # primary's recorded elevation plus 0.223.
  cat("\n  bta2_hydro elevation, from the 2026-09-02 survey\n")
  p <- which(meta$device_serial == "22357376" & meta$station_id == "bta2_hydro")
  s <- which(meta$device_serial == "21652379" & meta$station_id == "bta2_hydro")
  n_bta <- 0
  if (length(p) == 1 && length(s) == 1 && !is.na(meta$elev[p])) {
    to <- round(as.numeric(meta$elev[p]) + 0.223, 3)
    if (!identical(as.character(meta$elev[s]), as.character(to))) {
      cat(sprintf("    21652379   bta2_hydro   elev %s -> %s\n",
                  meta$elev[s], to))
      cat(sprintf("                            primary's %s plus the surveyed 0.223\n",
                  meta$elev[p]))
      n_bta <- 1
    } else cat("    already set\n")
  } else cat("    ! cannot compute - the primary has no elevation\n")

  cat("\n############################################\n")
  cat("  ", n_date, " date(s), ", n_iv, " interval(s), ", length(to_clear),
      " fact(s) cleared,\n  ", length(wrong_reach), " reach, ", n_bta,
      " elevation\n", sep = "")
  cat("############################################\n")

  if (is.null(prior) && length(backups) > 0)
    cat("\n! interval_min will NOT be restored without restore_from\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply, then re-run the importer\n")
    cat("to refill the cleared facts from the data:\n")
    cat("  migrate_device_facts_repair(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("\n+ metadata backed up\n")

  for (col in date_cols) {
    for (i in which(us(meta[[col]]))) {
      was <- as.character(meta[[col]][i])
      parsed <- suppressWarnings(as.POSIXct(was, format = "%m/%d/%Y %H:%M",
                                            tz = "America/Puerto_Rico"))
      if (is.na(parsed))
        parsed <- suppressWarnings(as.Date(was, format = "%m/%d/%Y"))
      if (is.na(parsed)) next
      meta[[col]][i] <- if (inherits(parsed, "Date")) format(parsed, "%Y-%m-%d")
                        else format(parsed, "%Y-%m-%d %H:%M:%S")
    }
  }

  if (!is.null(prior)) {
    hit <- match(meta$unique_id, prior$unique_id)
    for (i in which(!is.na(hit))) {
      to <- prior$interval_min[hit[i]]
      if (!is.na(to) && nzchar(as.character(to))) meta$interval_min[i] <- to
    }
  }

  meta$last_record_date[to_clear]   <- NA
  meta$last_download_date[to_clear] <- NA
  meta$reach_length_m[wrong_reach]  <- NA

  if (n_bta == 1) {
    meta$elev[s] <- round(as.numeric(meta$elev[p]) + 0.223, 3)
    meta$elev_source[s] <- "surveyed_relative"
  }

  save_device_metadata(meta)
  cat("+ applied\n")

  cat("\nNEXT:\n")
  cat("  1. re-run the importer to refill the cleared facts:\n")
  cat("       import_hobo_backfill(<prototype path>, dry_run = FALSE)\n")
  cat("     every file is already held, so it will write nothing and only\n")
  cat("     recompute the device facts\n")
  cat("  2. validate_metadata()\n\n")

  invisible(TRUE)
}
