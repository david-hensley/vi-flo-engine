################################################################################
# migrate_known_unattributed.R
#
# APPLIED: not yet
#
# Creates metadata/internal/known_unattributed.csv: periods of readings that
# belong to no station and are explained, so a Product 2 build prints them
# as KNOWN rather than as something to look at. Every row was verified with
# DAH from the logger's record, the prototype's notes or the dissertation
# (October 2026) - see docs/backfill/README.md, "Unattributed readings,
# explained", for the story behind each.
#
# Times are project-local. A blank `from` means the start of the logger's
# record, a blank `to` that the period is still open, a blank `port` the whole
# logger. Newest first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_known_unattributed.R"))
#   migrate_known_unattributed()                 # dry run
#   migrate_known_unattributed(dry_run = FALSE)  # applies it
################################################################################

migrate_known_unattributed <- function(dry_run = TRUE) {

  rows <- data.frame(
    device_serial = c("z6-14637", "21751136", "z6-13368", "21352826", "21352827",
                      "z6-14635", "z6-13376", "z6-12893", "z6-13388", "z6-13366", "z6-13363"),
    port          = c(NA, NA, 2, NA, NA, NA, NA, NA, NA, NA, NA),
    from          = c("2026-09-11 13:46:06", "2024-08-14 12:15:00", "2024-02-16 00:00:00",
                      "2023-10-28 00:00:00", "2023-09-13 00:00:00", NA, NA, NA, NA, NA, NA),
    to            = c(NA, NA, NA, "2023-11-14 11:30:00", "2023-09-19 15:48:00",
                      "2022-09-13 13:00:00", "2022-09-09 16:45:00", "2022-06-15 13:45:00",
                      "2022-06-14 14:15:00", "2022-05-26 16:30:00", "2022-05-17 16:15:00"),
    reason        = c(
      "Replaced at cal1_weather; in a storage shed, still logging",
      "Destroyed in Hurricane Ernesto; kept reporting",
      "Port 2's TEROS 10 retired 2024-02-16; the port kept reporting",
      "Emergency placement at SR1, mostly out of the water, before its proper deployment",
      "Logging at one minute by accident, before deployment",
      "La Grange breadfruit orchard, before SR1 (prototype sr1_2024-09-23.R)",
      "Plantain experiment (Hensley 2025, ch. 2), before uvi_vwc3",
      "Plantain experiment (Hensley 2025, ch. 2), before sr1_vwc2",
      "Plantain experiment (Hensley 2025, ch. 2), before sr2_vwc1",
      "Plantain experiment (Hensley 2025, ch. 2), before sr1_vwc1",
      "Plantain experiment (Hensley 2025, ch. 2), before sr2_vwc2"),
    stringsAsFactors = FALSE)

  path <- file.path(wds("meta_internal"), "known_unattributed.csv")

  #### Prior application ####
  if (file.exists(path)) {
    have <- read.csv(path, stringsAsFactors = FALSE, colClasses = "character",
                     na.strings = c("", "NA"))
    if (nrow(have) > 0 && all(rows$device_serial %in% have$device_serial)) {
      message("\u2713 Already applied: known_unattributed.csv holds these periods. Nothing to do.")
      return(invisible(TRUE))
    }
    if (nrow(have) > 0) {
      stop("known_unattributed.csv already has other rows - look at it before running this")
    }
  }

  #### The serials must be real; their names are the metadata's ####
  meta <- load_zentra_metadata()
  missing <- setdiff(rows$device_serial, meta$device_serial)
  if (length(missing) > 0) stop("Not in device_metadata: ", paste(missing, collapse = ", "))
  rows <- data.frame(device_serial = rows$device_serial,
                     device_name = device_short_name(rows$device_serial, meta),
                     rows[, setdiff(names(rows), "device_serial")], stringsAsFactors = FALSE)

  cat("\n--- KNOWN UNATTRIBUTED PERIODS ---\n\n")
  for (i in seq_len(nrow(rows))) {
    cat(sprintf("  %-20s %-9s %-7s %-16s to %-16s\n      %s\n", rows$device_name[i],
                rows$device_serial[i], if (is.na(rows$port[i])) "" else paste("port", rows$port[i]),
                if (is.na(rows$from[i])) "(start)" else substr(rows$from[i], 1, 16),
                if (is.na(rows$to[i])) "(open)" else substr(rows$to[i], 1, 16), rows$reason[i]))
  }

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(NULL))
  }

  write.csv(rows, path, row.names = FALSE, na = "")

  #### Verify ####
  k <- load_known_unattributed()
  ok_rows  <- nrow(k) == nrow(rows)
  ok_times <- all(is.na(rows$from) == is.na(k$from)) && all(is.na(rows$to) == is.na(k$to))
  cat("\n--- VERIFICATION ---\n")
  cat(if (ok_rows)  "\u2713" else "\u274c", " ", nrow(k), " periods written\n", sep = "")
  cat(if (ok_times) "\u2713" else "\u274c", " Every date reads back as a date\n", sep = "")
  if (!(ok_rows && ok_times)) stop("Verification failed")
  cat("\n\u2713 known_unattributed.csv created\n")
  invisible(TRUE)
}
