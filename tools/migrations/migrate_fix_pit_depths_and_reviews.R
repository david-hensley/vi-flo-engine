# VI-FLO migration: pit depths, and legacy review flags
#
# ONE-TIME SCRIPT. Two corrections that surfaced together while reviewing the
# stations the network status flagged.
#
#
# 1. PIT DEPTHS
#
# Three loggers carry the same six-port pattern - 10, 30, 10, 30, 10, 30 -
# three replicate pits at two depths each:
#
#   z6-14625  uvi_vwc2    live
#   z6-13376  uvi_vwc3    nonresponsive
#   z6-14640  bta2_vwc2   nonresponsive
#
# The structure is right and the depths are not. These pits were installed at
# 20 and 40 cm. An identical configuration across three devices is the mark of
# a template applied rather than depths measured, and nobody had reason to
# question it until the record was read line by line.
#
# The correction is in place rather than versioned: the sensors have always
# been at 20 and 40 cm, so there is no period during which 10 and 30 were
# true. A valid_to on the old rows would assert a change that never happened.
#
# Two of the three have not reported for months, so this is mostly about
# attributing what they already recorded - bta2_vwc2 ran from 2022 to 2024.
#
#
# 2. LEGACY REVIEW FLAGS
#
# Six stations show "never reviewed" or a review months old. That is a fossil
# of the old meaning: `download_approved` was forced FALSE for anything that
# could not be downloaded automatically, and migrate_metadata_approved.R only
# dated rows that were TRUE. So stations that were fine read as unreviewed.
#
# uvi_weather is different again. It was dated from its most recent maintenance
# entry - March - but the September visit was logged under uvi_vwc1, which
# shares the same logger. One box, two stations, and only the station named in
# the entry was updated. The manager now offers the companion; this fixes the
# record it left behind.
#
# Each date below is the last contact with that station, and the judgement that
# the record was correct at that moment is recorded here rather than inferred.
#
# uvi_vwc2 is left alone: it already carries a real clock time from its own
# maintenance entry on the same date, and overwriting that with a midday guess
# would lose precision for nothing.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fix_pit_depths_and_reviews.R"))

migrate_fix_pit_depths_and_reviews <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: pit depths and legacy reviews\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  ports_file <- file.path(wds("meta_internal"), "zentra_ports.csv")
  meta_file  <- file.path(wds("meta_internal"), "device_metadata.csv")

  ports <- read.csv(ports_file, stringsAsFactors = FALSE)
  meta  <- read.csv(meta_file,  stringsAsFactors = FALSE)

  #### 1. Pit depths ####
  pit_devices <- c("z6-14625", "z6-13376", "z6-14640")

  depth_rows <- which(ports$sn %in% pit_devices &
                      is.na(ports$valid_to) &
                      ports$depth_cm %in% c(10, 30))

  cat("Pit depths - 10 to 20, 30 to 40\n\n")
  if (length(depth_rows) == 0) {
    cat("  nothing to change (already corrected?)\n\n")
  } else {
    for (sn in pit_devices) {
      rows <- depth_rows[ports$sn[depth_rows] == sn]
      if (length(rows) == 0) next
      station <- meta$station_id[meta$device_serial == sn][1]
      cat("  ", sn, "  ", station, "\n", sep = "")
      for (r in rows) {
        cat("    port ", ports$port[r], ": ", ports$depth_cm[r], " -> ",
            ifelse(ports$depth_cm[r] == 10, 20, 40), " cm\n", sep = "")
      }
    }
    cat("\n")
  }

  #### 2. Review flags ####
  # Station, and the date of the last contact at which the record was correct
  # uvi_vwc2 is deliberately absent. It already carries 2026-03-02 20:53 from
  # its own maintenance entry - a real clock time - and the only thing this
  # migration could do is replace it with a midday guess for the same day.
  #
  # uvi_weather takes uvi_vwc1's exact timestamp, not a midday guess: it was
  # the same visit to the same box, and the review it is recording is the one
  # that happened then. The rest were blank, and their maintenance entries hold
  # a date without a time.
  reviews <- data.frame(
    station_id = c("uvi_weather", "uvi_vwc3",
                   "bta2_vwc1", "bta2_vwc2", "fb2_vwc1"),
    reviewed   = c("2026-09-11 21:58:39", "2026-03-02 12:00:00",
                   "2026-03-02 12:00:00", "2026-03-02 12:00:00",
                   "2026-03-23 12:00:00"),
    why        = c("11 Sep work logged under uvi_vwc1, same logger",
                   "last visit", "last visit", "last visit", "last visit"),
    stringsAsFactors = FALSE)

  terminal <- c("removed", "replaced", "relocated", "decommissioned")

  cat("Review flags - set TRUE, dated from the last contact\n\n")
  touched <- 0
  for (i in seq_len(nrow(reviews))) {
    rows <- which(meta$station_id == reviews$station_id[i] &
                  !tolower(meta$status) %in% terminal)
    if (length(rows) == 0) next
    touched <- touched + length(rows)
    cat("  ", format(reviews$station_id[i], width = 13),
        reviews$reviewed[i], "   ", reviews$why[i], "\n", sep = "")
  }
  cat("\n")

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_fix_pit_depths_and_reviews(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  #### Apply depths ####
  if (length(depth_rows) > 0) {
    ports$depth_cm[depth_rows] <- ifelse(ports$depth_cm[depth_rows] == 10, 20, 40)
    write.csv(ports, ports_file, row.names = FALSE)
    cat("+ Corrected ", length(depth_rows), " port depth(s)\n", sep = "")
  }

  #### Apply reviews ####
  for (i in seq_len(nrow(reviews))) {
    rows <- which(meta$station_id == reviews$station_id[i] &
                  !tolower(meta$status) %in% terminal)
    if (length(rows) == 0) next
    meta$metadata_approved[rows] <- TRUE
    # Midday UTC where the maintenance log holds a date without a time. A
    # midnight stamp would read as more precise than it is.
    meta$last_reviewed_utc[rows] <- reviews$reviewed[i]
  }
  write.csv(meta, meta_file, row.names = FALSE)
  cat("+ Recorded ", touched, " review(s)\n", sep = "")

  #### Verify ####
  cp <- read.csv(ports_file, stringsAsFactors = FALSE)
  left <- sum(cp$sn %in% pit_devices & is.na(cp$valid_to) &
              cp$depth_cm %in% c(10, 30), na.rm = TRUE)
  cm <- read.csv(meta_file, stringsAsFactors = FALSE)
  undated <- sum(cm$metadata_approved %in% TRUE &
                 (is.na(cm$last_reviewed_utc) |
                  trimws(cm$last_reviewed_utc) == ""), na.rm = TRUE)

  if (left > 0 || undated > 0) {
    cat("\nX Verification failed - ", left, " depth(s) and ", undated,
        " undated review(s) remain. Restore from backups/\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Verified\n\n")
  cat("NEXT: validate_metadata(), then print_network_status()\n\n")

  invisible(TRUE)
}

migrate_fix_pit_depths_and_reviews(dry_run = TRUE)
