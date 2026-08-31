# VI-FLO migration: backfill blank last_visit
#
# ONE-TIME SCRIPT.
#
# add_new_device() left last_visit as NA, so a station established through the
# workflow had no visit recorded - even though establishing a station on a
# date means somebody stood at it on that date. Fixed going forward; this
# repairs the rows already written.
#
# The date is taken from the MAINTENANCE LOG, not from deploy_datetime:
#
#   - For stations established under VI-FLO the log holds a
#     `station_established` entry, and its field_visit_date is the real visit.
#   - For stations predating VI-FLO, deploy_datetime may be the earliest
#     ARCHIVED RECORD rather than an actual visit - see the provenance section
#     of README.md. Filling last_visit from it would assert that someone was
#     there on a date nobody recorded.
#
# So: the latest field_visit_date in the maintenance log for that device, and
# where there is none, the field is left blank. A blank is true.
#
# Safe to run twice - it detects that nothing needs filling and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_backfill_last_visit.R"))

migrate_backfill_last_visit <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: backfill last_visit\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_dir  <- wds("meta_internal")
  meta_file <- file.path(meta_dir, "device_metadata.csv")
  mlog_file <- file.path(meta_dir, "maintenance_log.csv")

  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  # Terminal rows are excluded. A relocated or replaced device often shares
  # its serial AND station_id with the row that succeeded it, so the log
  # cannot tell the two deployments apart - backfilling would hand a terminal
  # row a visit date from after it went out of service.
  terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")

  blank <- which((is.na(meta$last_visit) | trimws(meta$last_visit) %in% c("", "NA")) &
                 !tolower(meta$status) %in% terminal_statuses)

  n_terminal <- sum((is.na(meta$last_visit) |
                     trimws(meta$last_visit) %in% c("", "NA")) &
                    tolower(meta$status) %in% terminal_statuses)

  if (n_terminal > 0) {
    cat("Skipping ", n_terminal,
        " terminal row(s) - their deployment has ended, and the log cannot\n",
        "  separate them from the row that succeeded them.\n\n", sep = "")
  }

  cat("Rows with no last_visit: ", length(blank), "\n\n", sep = "")

  if (length(blank) == 0) {
    cat("+ Nothing to backfill.\n\n")
    return(invisible(TRUE))
  }

  if (!file.exists(mlog_file)) {
    cat("X maintenance_log.csv not found - cannot establish visit dates\n")
    return(invisible(FALSE))
  }

  mlog <- read.csv(mlog_file, stringsAsFactors = FALSE)
  mlog$visit_parsed <- parse_date_flexible(mlog$field_visit_date)

  filled  <- integer(0)
  values  <- character(0)
  skipped <- integer(0)

  for (i in blank) {
    entries <- mlog[mlog$device_serial == meta$device_serial[i] &
                    mlog$station_id == meta$station_id[i] &
                    !is.na(mlog$visit_parsed), ]

    if (nrow(entries) == 0) {
      skipped <- c(skipped, i)
      next
    }

    filled <- c(filled, i)
    values <- c(values, format(max(entries$visit_parsed), "%Y-%m-%d"))
  }

  if (length(filled) > 0) {
    cat("To fill, from the maintenance log:\n")
    for (k in seq_along(filled)) {
      i <- filled[k]
      cat("  ", format(meta$station_id[i], width = 14),
          format(meta$device_serial[i], width = 11),
          " -> ", values[k], "\n", sep = "")
    }
    cat("\n")
  }

  if (length(skipped) > 0) {
    cat("Left blank - no maintenance entries, so no visit is on record:\n")
    for (i in skipped) {
      cat("  ", format(meta$station_id[i], width = 14),
          format(meta$device_serial[i], width = 11),
          " deployed ", meta$deploy_datetime[i], "\n", sep = "")
    }
    cat("\n  These predate VI-FLO. deploy_datetime may be the earliest\n")
    cat("  archived record rather than a visit, so it is not used here.\n\n")
  }

  ############################################################################
  #### Known corrections not recoverable from the log
  ############################################################################
  # The Limetree rows were entered into the CSV by hand rather than through
  # the workflow - their deploy time is exactly midnight, which no workflow
  # would write - so no station_established entry exists to derive a visit
  # from. These datetimes come from the operator's own field records, and one
  # of them is a different DAY, not just a different time.
  known <- data.frame(
    device_serial   = c("z6-35061", "z6-35227", "z6-35228"),
    station_id      = c("ltt1_vwc1", "ltt1_vwc2", "ltt1_vwc3"),
    deploy_datetime = c("2026-01-10 10:30:00",
                        "2026-01-10 13:00:00",
                        "2026-01-09 15:45:00"),
    stringsAsFactors = FALSE
  )
  known$last_visit <- format(as.Date(substr(known$deploy_datetime, 1, 10)),
                             "%Y-%m-%d")

  known_rows <- integer(0)
  for (k in seq_len(nrow(known))) {
    i <- which(meta$device_serial == known$device_serial[k] &
               meta$station_id == known$station_id[k])
    if (length(i) == 0) next
    i <- i[1]
    if (identical(trimws(meta$deploy_datetime[i]), known$deploy_datetime[k]) &&
        identical(trimws(meta$last_visit[i]), known$last_visit[k])) next
    known_rows <- c(known_rows, k)
  }

  if (length(known_rows) > 0) {
    cat("Known corrections, from field records:\n")
    for (k in known_rows) {
      i <- which(meta$device_serial == known$device_serial[k] &
                 meta$station_id == known$station_id[k])[1]
      cat("  ", format(known$station_id[k], width = 12),
          " deploy: ", meta$deploy_datetime[i], " -> ", known$deploy_datetime[k],
          "\n", sep = "")
      cat("  ", format("", width = 12),
          " visit:  ", blank_or_value(meta$last_visit[i]), " -> ",
          known$last_visit[k], "\n", sep = "")
    }
    cat("\n")
  }

  cat("--------------------------------------------\n")

  if (dry_run) {
    cat(length(filled), " row(s) would be filled from the log, ",
        length(known_rows), " corrected from field records, ",
        length(skipped) - length(known_rows), " left blank.\n\n", sep = "")
    if (length(filled) > 0 || length(known_rows) > 0) {
      cat("Re-run with dry_run = FALSE to apply:\n")
      cat("  migrate_backfill_last_visit(dry_run = FALSE)\n\n")
    }
    return(invisible(length(filled)))
  }

  if (length(filled) == 0 && length(known_rows) == 0) {
    cat("Nothing to fill.\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  if (length(filled) > 0) meta$last_visit[filled] <- values

  for (k in known_rows) {
    i <- which(meta$device_serial == known$device_serial[k] &
               meta$station_id == known$station_id[k])[1]
    meta$deploy_datetime[i] <- known$deploy_datetime[k]
    meta$last_visit[i]      <- known$last_visit[k]
  }

  write.csv(meta, meta_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)
  still_blank <- which(is.na(check$last_visit) |
                       trimws(check$last_visit) %in% c("", "NA"))

  cat("+ Filled ", length(filled), " from the log, ", length(known_rows),
      " from field records; ", length(still_blank),
      " correctly left blank\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_backfill_last_visit(dry_run = TRUE)
