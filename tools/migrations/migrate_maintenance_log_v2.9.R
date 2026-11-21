################################################################################
# migrate_maintenance_log_v2.9.R
#
# APPLIED: not yet
#
# Brings maintenance_log.csv to its v2.9 shape - step 4.1, the first table to
# move. Product 2 never reads this log, so nothing built changes.
#
#   device_serial  ->  unique_id    the deployment the entry concerns
#   timestamp      ->  logged_utc   when the entry was written, local -> UTC
#   station_type       dropped      the station_id says it
#   ports_updated      dropped      a port change is dated in the port table
#   elevation_survey -> survey      a survey now records more than elevations
#
# Each entry's deployment is found as the engine now finds it for a new entry
# - resolve_deployment(): the logger's row at that station, and where it has
# several, the one serving on the day of the visit. Where two cover the day,
# the later: the fb1_weather relocation of 2024-02-06 belongs to the new
# position, as decided on 2026-11-21. Every entry decided that way is listed.
# An entry that names no row at its station stops the migration with nothing
# written - it is never guessed.
#
# Reads the log raw, since the engine's schema already describes the new
# shape; writes it through the data layer, which backs it up first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_maintenance_log_v2.9.R"))
#   migrate_maintenance_log()                 # dry run: shows what would change
#   migrate_maintenance_log(dry_run = FALSE)  # applies it
################################################################################

migrate_maintenance_log <- function(dry_run = TRUE) {

  path <- table_path("maintenance_log")
  old_cols <- c("timestamp", "field_visit_date", "station_id", "station_type",
                "device_serial", "action_type", "details", "ports_updated", "logged_by")
  new_cols <- names(TABLE_SCHEMA$maintenance_log$columns)

  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8")

  #### Already done? ####
  if (identical(names(raw), new_cols)) {
    cat("✓ maintenance_log.csv is already in its v2.9 shape - nothing to do\n")
    return(invisible(TRUE))
  }
  if (!identical(names(raw), old_cols)) {
    stop("maintenance_log.csv has neither the old columns nor the new ones:\n  ",
         paste(names(raw), collapse = ", "), "\nNothing written.", call. = FALSE)
  }

  #### Each entry's deployment ####
  meta <- read_table("device_metadata", remember = FALSE)
  uid <- vapply(seq_len(nrow(raw)), function(i) {
    resolve_deployment(raw$device_serial[i], raw$station_id[i], raw$field_visit_date[i], meta)
  }, character(1))

  # How each was decided, so the ones that took judgment can be shown
  n_rows <- vapply(seq_len(nrow(raw)), function(i) {
    sum(meta$device_serial == raw$device_serial[i] & meta$station_id == raw$station_id[i],
        na.rm = TRUE)
  }, integer(1))

  lost <- which(is.na(uid))
  if (length(lost) > 0) {
    cat("These entries name a logger that has no row at their station:\n\n")
    print(raw[lost, c("field_visit_date", "station_id", "device_serial", "action_type")],
          row.names = FALSE)
    stop("\n", length(lost), " entr", if (length(lost) == 1) "y" else "ies",
         " could not be given a deployment. Nothing written.", call. = FALSE)
  }

  #### The new table ####
  logged <- parse_datetime_flexible(raw$timestamp, PROJECT_TZ)
  bad_time <- !is.na(raw$timestamp) & is.na(logged)
  if (any(bad_time)) {
    stop("Unreadable timestamp(s): ", paste(unique(raw$timestamp[bad_time]), collapse = ", "),
         "\nNothing written.", call. = FALSE)
  }

  new <- data.frame(
    logged_utc       = format(logged, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    field_visit_date = raw$field_visit_date,
    station_id       = raw$station_id,
    unique_id        = uid,
    action_type      = ifelse(raw$action_type %in% "elevation_survey", "survey", raw$action_type),
    details          = raw$details,
    logged_by        = raw$logged_by,
    stringsAsFactors = FALSE
  )
  new$logged_utc[is.na(logged)] <- NA

  #### What would change ####
  cat("maintenance_log.csv: ", nrow(raw), " entries\n\n", sep = "")
  cat("  Deployments:  ", sum(n_rows == 1), " from the logger's only row at the station\n",
      "                ", sum(n_rows > 1), " from the day of the visit, among several rows\n", sep = "")
  several <- which(n_rows > 1)
  if (length(several) > 0) {
    shown <- data.frame(date = raw$field_visit_date[several], station = raw$station_id[several],
                        serial = raw$device_serial[several], action = raw$action_type[several],
                        deployment = uid[several], stringsAsFactors = FALSE)
    cat("\n")
    print(shown, row.names = FALSE)
    cat("\n")
  }
  cat("  Renamed:      ", sum(raw$action_type %in% "elevation_survey"),
      " elevation_survey -> survey\n", sep = "")
  cat("  Times:        timestamp (local) -> logged_utc, e.g. ",
      raw$timestamp[1], " -> ", new$logged_utc[1], "\n", sep = "")
  cat("  Dropped:      station_type, ports_updated\n")

  unknown <- setdiff(unique(new$action_type[!is.na(new$action_type)]), MAINTENANCE_ACTIONS)
  if (length(unknown) > 0) {
    cat("\n  ! Actions not in the list - kept as they are, for you to look at: ",
        paste(unknown, collapse = ", "), "\n", sep = "")
  }

  if (dry_run) {
    cat("\nDry run - nothing written. Run migrate_maintenance_log(dry_run = FALSE) to apply.\n")
    return(invisible(new))
  }

  #### Write, then check what landed ####
  if (!isTRUE(write_table("maintenance_log", new, guard = FALSE,
                          intent = "migrating the maintenance log to v2.9"))) {
    stop("Not written.", call. = FALSE)
  }

  back <- read_table("maintenance_log", remember = FALSE)
  ok_rows    <- nrow(back) == nrow(raw)
  ok_ids     <- all(back$unique_id %in% meta$unique_id)
  ok_station <- all(meta$station_id[match(back$unique_id, meta$unique_id)] == back$station_id)
  ok_details <- identical(back$details, raw$details)
  if (!(ok_rows && ok_ids && ok_station && ok_details)) {
    stop("Verification failed - restore maintenance_log.csv from metadata/internal/backups",
         call. = FALSE)
  }
  cat("\n✓ maintenance_log.csv migrated: ", nrow(back), " entries, each naming a deployment ",
      "at its own station, every note unchanged. Backup in metadata/internal/backups.\n", sep = "")
  invisible(TRUE)
}
