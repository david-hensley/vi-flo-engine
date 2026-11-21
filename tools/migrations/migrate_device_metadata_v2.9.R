################################################################################
# migrate_device_metadata_v2.9.R
#
# APPLIED: 2026-11-21
#
# Brings device_metadata.csv to its v2.9 shape - step 4.4.
#
#   end_datetime   added     when each retired deployment ended. Until now it
#                            was worked out on every build - from the
#                            deployment that followed, or the end of the
#                            row's last-visit day - and a later visit could
#                            move it. Each row gets exactly the end Product 2
#                            already uses, so nothing it builds changes; and
#                            three rows get the end the record shows instead,
#                            as decided on 2026-11-21:
#
#       SR1 Hillside (sr1_vwc1)      2026-09-04 13:12:45  decommissioned that
#       SR2-HS v2 (sr2_vwc1)         2026-09-04 15:53:23  day; ended at the
#                                                         March visit before
#       SR2 Hillside (sr2_vwc1)      2024-01-22 13:00:00  replaced by SR2-HS
#                                                         v2; never ended
#
#   battery, last_update, last_download_date, last_record_date
#                  dropped   worked out from download_log.csv when needed
#   expiry_date    dropped   typed by hand and gone stale
#   nonresponsive  -> online the status is retired; going quiet is something
#                            the network report notices, not a status
#
# A retired row with no end Product 2 can name, and no decision above, stops
# the migration with nothing written - it is never guessed.
#
# Reads the table raw, since the engine's schema already describes the new
# shape; writes it through the data layer, which backs it up first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_device_metadata_v2.9.R"))
#   migrate_device_metadata()                 # dry run: shows what would change
#   migrate_device_metadata(dry_run = FALSE)  # applies it
################################################################################

# The ends decided by hand: unique_id -> station it must be at, and the end
DEVICE_END_DECISIONS <- data.frame(
  unique_id  = c("z-0009", "z-0018", "z-0010"),
  station_id = c("sr1_vwc1", "sr2_vwc1", "sr2_vwc1"),
  end        = c("2026-09-04 13:12:45", "2026-09-04 15:53:23", "2024-01-22 13:00:00"),
  why        = c("decommissioned 2026-09-04", "decommissioned 2026-09-04",
                 "replaced by SR2-HS v2; ports closed then"),
  stringsAsFactors = FALSE)

#' The deployment ends Product 2 used before v2.9, worked out as it did
#'
#' Within one logger and station type, a row ended where the next began; a
#' retired row ended at the end of its last-visit day if that came first, or
#' if nothing followed it. A copy of the rule end_datetime replaces, kept here
#' so the migration can reproduce it exactly.
pre_v29_ends <- function(m) {
  tz <- PROJECT_TZ
  key <- paste(m$device_serial, tolower(m$station_type), sep = "|")
  ends <- as.POSIXct(rep(NA, nrow(m)), tz = tz)
  basis <- rep("open", nrow(m))
  for (i in seq_len(nrow(m))) {
    if (is.na(m$deploy_datetime[i])) next
    later <- which(key == key[i] & m$deploy_datetime > m$deploy_datetime[i])
    terminal <- tolower(m$status[i]) %in% TERMINAL_STATUSES
    visit_end <- if (!is.na(m$last_visit[i])) {
      as.POSIXct(paste(m$last_visit[i], "23:59:59"), tz = tz)
    } else as.POSIXct(NA, tz = tz)
    if (length(later) > 0) {
      ends[i] <- min(m$deploy_datetime[later]); basis[i] <- "successor"
      if (terminal && !is.na(visit_end) && visit_end < ends[i]) {
        ends[i] <- visit_end; basis[i] <- "last visit"
      }
    } else if (terminal) {
      if (!is.na(visit_end)) { ends[i] <- visit_end; basis[i] <- "last visit" }
      else basis[i] <- "unknown"
    }
  }
  data.frame(unique_id = m$unique_id, ends = ends, basis = basis, stringsAsFactors = FALSE)
}

migrate_device_metadata <- function(dry_run = TRUE, decisions = DEVICE_END_DECISIONS) {

  path <- table_path("device_metadata")
  old_cols <- c("unique_id", "watershed", "area", "site_full", "site", "station_type",
                "station_id", "device_serial", "device_role", "device_name", "mfger",
                "model", "lat", "lon", "elev", "elev_source", "sensor_height_cm",
                "reach_length_m", "interval_min", "timezone", "deploy_datetime", "status",
                "last_update", "battery", "last_visit", "expiry_date",
                "last_download_date", "last_record_date", "metadata_approved",
                "last_reviewed_utc")
  new_cols <- names(TABLE_SCHEMA$device_metadata$columns)

  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8")
  if (identical(names(raw), new_cols)) {
    cat("✓ device_metadata.csv is already in its v2.9 shape - nothing to do\n")
    return(invisible(TRUE))
  }
  if (!identical(names(raw), old_cols)) {
    stop("device_metadata.csv has neither the old columns nor the new ones:\n  ",
         paste(names(raw), collapse = ", "), "\nNothing written.", call. = FALSE)
  }

  # The few columns the old rule needs, read as their types
  m <- data.frame(
    unique_id = raw$unique_id, device_serial = raw$device_serial,
    station_id = raw$station_id, station_type = raw$station_type,
    device_name = raw$device_name, status = raw$status,
    deploy_datetime = parse_datetime_flexible(raw$deploy_datetime, PROJECT_TZ),
    last_visit = parse_date_flexible(raw$last_visit), stringsAsFactors = FALSE)
  old <- pre_v29_ends(m)

  #### Each row's end ####
  end <- old$ends
  terminal <- tolower(m$status) %in% TERMINAL_STATUSES
  end[!terminal] <- NA          # a current deployment has no end

  stray <- which(!terminal & !is.na(old$ends))
  if (length(stray) > 0) {
    print(data.frame(row = m$unique_id[stray], station = m$station_id[stray],
                     status = m$status[stray], ended = format(old$ends[stray])),
          row.names = FALSE)
    stop("\nThese current rows were ended by a later row of their logger. ",
         "Nothing written.", call. = FALSE)
  }

  applied <- character(0)
  for (k in seq_len(nrow(decisions))) {
    d <- decisions[k, ]
    i <- which(m$unique_id == d$unique_id)
    if (length(i) != 1) next                                  # not in this table
    if (m$station_id[i] != d$station_id || !terminal[i]) {
      stop(d$unique_id, " is not the retired ", d$station_id, " row the decision ",
           "was made for. Nothing written.", call. = FALSE)
    }
    was <- if (is.na(end[i])) "never ended" else format(end[i], "%Y-%m-%d %H:%M")
    end[i] <- as.POSIXct(d$end, tz = PROJECT_TZ)
    applied <- c(applied, paste0(m$device_name[i], " (", m$station_id[i], ", ", d$unique_id,
                                 "): ", was, " -> ", d$end, "  [", d$why, "]"))
  }

  unended <- which(terminal & is.na(end))
  if (length(unended) > 0) {
    print(data.frame(row = m$unique_id[unended], station = m$station_id[unended],
                     name = m$device_name[unended], status = m$status[unended]),
          row.names = FALSE)
    stop("\nThese retired rows have no end Product 2 could name, and no decision. ",
         "Nothing written.", call. = FALSE)
  }

  #### The new table ####
  new <- raw[, setdiff(old_cols, c("last_update", "battery", "expiry_date",
                                   "last_download_date", "last_record_date"))]
  new$end_datetime <- ifelse(is.na(end), NA,
                             format(end, "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ))
  quiet <- which(new$status %in% "nonresponsive")
  new$status[quiet] <- "online"
  new <- new[, new_cols]

  #### What would change ####
  cat("device_metadata.csv: ", nrow(raw), " rows\n\n", sep = "")
  cat("  end_datetime:  ", sum(terminal), " retired rows dated - ",
      sum(terminal) - length(applied), " exactly as Product 2 ended them, ",
      length(applied), " by decision:\n", sep = "")
  for (a in applied) cat("      ", a, "\n", sep = "")
  cat("                 ", sum(!terminal), " current rows left open\n", sep = "")
  cat("  Status:         ", length(quiet), " nonresponsive -> online",
      if (length(quiet)) paste0(" (", paste(paste0(raw$device_name[quiet], ", ",
                                                   raw$station_id[quiet]), collapse = "; "), ")"),
      "\n", sep = "")
  cat("  Dropped:        battery, last_update, last_download_date, last_record_date,",
      " expiry_date\n", sep = "")

  if (dry_run) {
    cat("\nDry run - nothing written. Run migrate_device_metadata(dry_run = FALSE) to apply.\n")
    return(invisible(new))
  }

  #### Write, then check what landed ####
  if (!isTRUE(write_table("device_metadata", new, guard = FALSE,
                          intent = "migrating the device table to v2.9"))) {
    stop("Not written.", call. = FALSE)
  }

  back <- read_table("device_metadata", remember = FALSE)
  w <- deployment_windows(back)
  now_end <- w$ends[match(m$unique_id, w$unique_id)]
  decided <- m$unique_id %in% decisions$unique_id
  same <- (is.na(now_end) & is.na(old$ends)) |
          (!is.na(now_end) & !is.na(old$ends) & now_end == old$ends)
  # Every row ends where it ended before, but the decided ones; and every other
  # column is unchanged
  kept <- setdiff(new_cols, c("end_datetime", "status"))
  ok_cols <- identical(back$unique_id, raw$unique_id) &&
             all(vapply(kept, function(k) {
               a <- table_parse_column(raw[[k]], TABLE_SCHEMA$device_metadata$columns[[k]], k, "")
               b <- back[[k]]
               all((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b))
             }, logical(1)))
  if (!(all(same | decided) && ok_cols)) {
    stop("Verification failed - restore device_metadata.csv from metadata/internal/backups",
         call. = FALSE)
  }
  cat("\n✓ device_metadata.csv migrated: ", nrow(back), " rows; every deployment ends ",
      "where Product 2 ended it, but the ", sum(decided), " decided; every other value ",
      "unchanged. Backup in metadata/internal/backups.\n", sep = "")
  invisible(TRUE)
}
