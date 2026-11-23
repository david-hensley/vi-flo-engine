################################################################################
# migrate_day_end_placeholders_v2.9.R
#
# APPLIED: 2026-11-22 (8 rows: sr2_weather, cal1_weather, sr2_vwc2 twice,
#   sr1_vwc2, fb2_vwc1, tr1_weather, fb1_weather; 12 port rows with them)
#
# Ends each retired row at the moment its successor went in, where it was
# recorded as ending at 23:59:59 on the same day.
#
# Before v2.9, a replacement or relocation ended the old row at the end of the
# day it happened - "sometime that day" - while the new row began at the real
# moment. The two then overlap for the rest of the day: the old logger,
# already in the truck or the office, reads as still deployed at the station.
# Its readings in those hours are either attributed to the station as if they
# were field data, or - where its ports closed at the real moment - belong to
# nothing (Dorothea Weather, 29 October 2026, the first found and corrected by
# hand).
#
# For each such row, the end moves to the successor's deploy time, and any
# port that closed at the placeholder, or later that day, closes then too. Each move is logged as a
# metadata correction. One change: all of it, or none.
#
# Removals, and rows ending at 23:59:59 with no successor that day, are left
# alone - with nothing to say when the logger came out, the end of the day is
# as good a guess as any.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_day_end_placeholders_v2.9.R"))
#   migrate_day_end_placeholders()                 # dry run
#   migrate_day_end_placeholders(dry_run = FALSE)  # applies it
#   then build_p2_stale(), to rebuild the station-years it touched
################################################################################

migrate_day_end_placeholders <- function(dry_run = TRUE, logged_by = "DAH") {
  meta <- load_zentra_metadata()
  ends_at <- function(x) !is.na(x) & format(x, "%H:%M:%S", tz = PROJECT_TZ) == "23:59:59"
  # Replaced and relocated only: those name a successor that took the old
  # logger's place. A removal has none - a logger going in elsewhere that day
  # (rb2_hydro, November 2025: ReefBay_slope came out of its spot while
  # another went into a new one) is not when the removed one came out
  cand <- which(ends_at(meta$end_datetime) &
                  tolower(meta$status) %in% c("replaced", "relocated"))

  fixes <- data.frame(i = integer(0), new_end = as.POSIXct(character(0), tz = PROJECT_TZ))
  for (i in cand) {
    same_day <- meta$station_id == meta$station_id[i] &
      meta$unique_id != meta$unique_id[i] &
      !is.na(meta$deploy_datetime) &
      local_date(meta$deploy_datetime) == local_date(meta$end_datetime[i]) &
      meta$deploy_datetime < meta$end_datetime[i]
    if (any(same_day)) {
      fixes <- rbind(fixes, data.frame(i = i, new_end = min(meta$deploy_datetime[same_day])))
    }
  }

  # Ports closed later that day than the successor went in were stamped
  # when they were entered, not when the sensors came out - SR1 Streambank's
  # at 15:59:35 against 15:59, Glynn Weather's at 17:18 against a move at
  # noon. They close at the successor's time with the row, rather than the
  # row staying open for them
  ports <- load_zentra_ports_data()
  late <- function(k) {
    i <- fixes$i[k]
    ports$unique_id == meta$unique_id[i] & !is.na(ports$valid_to) &
      (ends_at(ports$valid_to) |
         (local_date(ports$valid_to) == local_date(meta$end_datetime[i]) &
            ports$valid_to > fixes$new_end[k]))
  }

  cat("\nRetired rows ending at 23:59:59 on the day a successor went in (",
      nrow(fixes), "):\n\n", sep = "")
  n_ports <- integer(nrow(fixes))
  for (k in seq_len(nrow(fixes))) {
    i <- fixes$i[k]
    n_ports[k] <- sum(late(k))
    cat(sprintf("  %-13s %-28s %-10s ends %s -> %s%s\n",
                meta$station_id[i], device_label(meta[i, ]), meta$status[i],
                format(meta$end_datetime[i], "%Y-%m-%d %H:%M", tz = PROJECT_TZ),
                format(fixes$new_end[k], "%H:%M", tz = PROJECT_TZ),
                if (n_ports[k] > 0) paste0(", ", n_ports[k], " port(s) with it") else ""))
  }

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_day_end_placeholders(dry_run = FALSE) applies it.\n")
    return(invisible(fixes))
  }

  res <- tryCatch(with_metadata_change("ending retired rows when their successor went in", local({
    meta <- load_zentra_metadata()
    ports <- load_zentra_ports_data()
    for (k in seq_len(nrow(fixes))) {
      i <- fixes$i[k]
      old_end <- meta$end_datetime[i]
      hit <- ports$unique_id == meta$unique_id[i] & !is.na(ports$valid_to) &
        (ends_at(ports$valid_to) |
           (local_date(ports$valid_to) == local_date(old_end) & ports$valid_to > fixes$new_end[k]))
      ports$valid_to[hit] <- fixes$new_end[k]
      meta$end_datetime[i] <- fixes$new_end[k]
      out <- create_maintenance_entry(
        field_visit_date = local_date(Sys.time()),
        station_id = meta$station_id[i],
        unique_id = meta$unique_id[i],
        action_type = "metadata_correction",
        details = paste0("end_datetime of ", device_label(meta[i, ]), ": ",
                         format(old_end, "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ), " → ",
                         format(fixes$new_end[k], "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ),
                         ", when its successor went in",
                         if (sum(hit) > 0) paste0("; ", sum(hit), " port row(s) moved with it")),
        logged_by = logged_by)
      if (!isTRUE(out)) return(out)
    }
    save_device_metadata(meta)
    save_zentra_ports(ports, intent = "ending retired rows when their successor went in")
    TRUE
  })), error = function(e) conditionMessage(e))

  if (!isTRUE(res)) {
    cat("\n❌ Not applied - ", res, "\nNothing was changed.\n", sep = "")
    return(invisible(FALSE))
  }
  cat("\n✓ ", nrow(fixes), " row(s) corrected and logged. Run build_p2_stale() next.\n", sep = "")
  invisible(TRUE)
}
