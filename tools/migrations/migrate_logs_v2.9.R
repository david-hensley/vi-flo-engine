################################################################################
# migrate_logs_v2.9.R
#
# APPLIED: 2026-11-21
#
# Brings download_log.csv and pending_ingest.csv to their v2.9 shape - step
# 4.2.
#
#   download_log
#     station          dropped   filled on 26 rows of hundreds. A Product 1
#                                file is what a logger recorded; which station
#                                a reading belongs to is Product 2's to decide
#     battery          added     the logger's battery at the end of each file.
#                                Blank on every row so far - it was never kept
#                                with the download, and is not guessed
#
#   pending_ingest
#     device_serial -> unique_id   the deployment whose data is waiting
#     created, updated -> created_utc, updated_utc   local -> UTC
#
# Every other value is carried over unchanged, and checked afterwards. Reads
# both tables raw, since the engine's schema already describes the new shape;
# writes them through the data layer, which backs each up first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_logs_v2.9.R"))
#   migrate_logs()                 # dry run: shows what would change
#   migrate_logs(dry_run = FALSE)  # applies it
################################################################################

migrate_logs <- function(dry_run = TRUE) {

  read_raw <- function(name) {
    p <- table_path(name)
    if (!file.exists(p)) return(NULL)
    utils::read.csv(p, colClasses = "character", na.strings = c("", "NA"),
                    check.names = FALSE, encoding = "UTF-8")
  }
  meta <- read_table("device_metadata", remember = FALSE)
  plans <- list()

  #### download_log ####
  dl_old <- c("timestamp_utc", "run_id", "station", "device_serial", "start_date",
              "end_date", "n_records", "filepath", "download_type")
  dl_new <- names(TABLE_SCHEMA$download_log$columns)
  dl <- read_raw("download_log")
  if (identical(names(dl), dl_new)) {
    cat("✓ download_log.csv is already in its v2.9 shape\n")
  } else if (!identical(names(dl), dl_old)) {
    stop("download_log.csv has neither the old columns nor the new ones:\n  ",
         paste(names(dl), collapse = ", "), "\nNothing written.", call. = FALSE)
  } else {
    new_dl <- dl[, setdiff(dl_old, "station")]
    new_dl$battery <- NA_character_
    plans$download_log <- list(before = dl, after = new_dl)
    cat("download_log.csv: ", nrow(dl), " rows\n",
        "  Dropped:  station (named on ", sum(!is.na(dl$station)), " rows)\n",
        "  Added:    battery, blank on every row so far\n\n", sep = "")
  }

  #### pending_ingest ####
  pi_old <- c("created", "updated", "station_id", "device_serial",
              "field_visit_date", "logged_by", "stage", "notes")
  pi_new <- names(TABLE_SCHEMA$pending_ingest$columns)
  pi <- read_raw("pending_ingest")
  if (is.null(pi) || identical(names(pi), pi_new)) {
    cat("✓ pending_ingest.csv is already in its v2.9 shape\n")
  } else if (!identical(names(pi), pi_old)) {
    stop("pending_ingest.csv has neither the old columns nor the new ones:\n  ",
         paste(names(pi), collapse = ", "), "\nNothing written.", call. = FALSE)
  } else {
    uid <- vapply(seq_len(nrow(pi)), function(i) {
      resolve_deployment(pi$device_serial[i], pi$station_id[i], pi$field_visit_date[i], meta)
    }, character(1))
    lost <- which(is.na(uid))
    if (length(lost) > 0) {
      print(pi[lost, c("station_id", "device_serial", "field_visit_date", "stage")],
            row.names = FALSE)
      stop("\nThese pending tasks name a logger with no row at their station. ",
           "Nothing written.", call. = FALSE)
    }
    to_utc <- function(x) {
      t <- parse_datetime_flexible(x, PROJECT_TZ)
      out <- format(t, "%Y-%m-%d %H:%M:%S", tz = "UTC")
      out[is.na(t)] <- NA
      out
    }
    new_pi <- data.frame(
      created_utc = to_utc(pi$created), updated_utc = to_utc(pi$updated),
      station_id = pi$station_id, unique_id = uid,
      field_visit_date = pi$field_visit_date, logged_by = pi$logged_by,
      stage = pi$stage, notes = pi$notes, stringsAsFactors = FALSE)
    plans$pending_ingest <- list(before = pi, after = new_pi)
    cat("pending_ingest.csv: ", nrow(pi), " task(s)\n", sep = "")
    if (nrow(pi) > 0) {
      print(data.frame(station = pi$station_id, serial = pi$device_serial,
                       deployment = uid, stage = pi$stage), row.names = FALSE)
    }
    cat("  Renamed:  created, updated -> created_utc, updated_utc (local -> UTC)\n\n")
  }

  if (length(plans) == 0) return(invisible(TRUE))
  if (dry_run) {
    cat("Dry run - nothing written. Run migrate_logs(dry_run = FALSE) to apply.\n")
    return(invisible(plans))
  }

  #### Write, then check what landed ####
  for (name in names(plans)) {
    if (!isTRUE(write_table(name, plans[[name]]$after, guard = FALSE,
                            intent = paste("migrating", name, "to v2.9")))) {
      stop(name, " not written.", call. = FALSE)
    }
  }

  if (!is.null(plans$download_log)) {
    back <- read_table("download_log", remember = FALSE, as_text = "timestamp_utc")
    was <- plans$download_log$before
    ok <- nrow(back) == nrow(was) &&
          identical(back$filepath, was$filepath) &&
          identical(back$device_serial, was$device_serial) &&
          identical(back$timestamp_utc, was$timestamp_utc) &&
          identical(back$n_records, as.integer(was$n_records))
    if (!ok) stop("download_log.csv verification failed - restore it from metadata/internal/backups",
                  call. = FALSE)
    cat("✓ download_log.csv migrated: ", nrow(back), " rows, every file, logger, time ",
        "and count unchanged\n", sep = "")
  }
  if (!is.null(plans$pending_ingest)) {
    back <- read_table("pending_ingest", remember = FALSE)
    ok <- nrow(back) == nrow(plans$pending_ingest$before) &&
          all(back$unique_id %in% meta$unique_id)
    if (!ok) stop("pending_ingest.csv verification failed - restore it from metadata/internal/backups",
                  call. = FALSE)
    cat("✓ pending_ingest.csv migrated: ", nrow(back), " task(s)\n", sep = "")
  }
  cat("Backups in metadata/internal/backups.\n")
  invisible(TRUE)
}
