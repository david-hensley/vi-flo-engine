# VI-FLO migration: metadata_approved and last_reviewed_utc
#
# ONE-TIME SCRIPT.
#
# `download_approved` was named for a job it no longer does. It was meant to
# stop an automated download filing data against a stale record - but Product 1
# downloads apply no metadata at all, so the same file arrives whether the
# record is current or hopelessly out of date. Blocking the download would
# forfeit data and protect nothing.
#
# What the flag actually asserts is that a HUMAN has confirmed the record is
# complete for that station. That matters at Product 2, where station identity
# and sensor depth get applied and a stale record does corrupt something.
#
#   download_approved  ->  metadata_approved
#   (new)                  last_reviewed_utc
#
# The flag alone was never enough. TRUE says someone once confirmed the record;
# it does not say whether that was this morning or in March. The pair answers
# the real question - how long since a human looked at this station.
#
# last_reviewed_utc updates whenever a human ANSWERS the question, not only
# when they answer yes. "I looked and something is missing" is as much a review
# as "I looked and it is fine".
#
# UTC, because a review happens at a keyboard that could be anywhere. The
# station's own times - deploy_datetime, last_visit - stay local, because they
# belong to a place.
#
#
# EXISTING VALUES
#
# A row already TRUE gets a last_reviewed_utc from the most recent maintenance
# entry for its station, since that is when the flag was last set. Where there
# is no such entry the value is left blank rather than invented: an unknown
# review date is honest, and a fabricated one would make a stale record look
# fresh.
#
# Safe to run twice: it exits once the column has been renamed.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_metadata_approved.R"))

migrate_metadata_approved <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: metadata_approved + last_reviewed_utc\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  if ("metadata_approved" %in% names(meta)) {
    cat("+ Already renamed - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  if (!"download_approved" %in% names(meta)) {
    cat("X No download_approved column found\n\n")
    return(invisible(FALSE))
  }

  #### When was each station last touched by a human ####
  # The maintenance log is the record of someone being at a keyboard saying
  # what they knew. Its timestamps are local, so they convert to UTC here.
  mlog <- tryCatch(load_maintenance_log(), error = function(e) NULL)

  project_tz <- meta$timezone[!is.na(meta$timezone)][1]
  if (is.na(project_tz) || !nzchar(project_tz)) project_tz <- "America/Puerto_Rico"

  last_touch <- rep(NA_character_, nrow(meta))

  if (!is.null(mlog) && nrow(mlog) > 0) {
    ts_col <- if ("timestamp" %in% names(mlog)) "timestamp" else NULL
    if (!is.null(ts_col)) {
      for (i in seq_len(nrow(meta))) {
        hits <- mlog[[ts_col]][mlog$station_id == meta$station_id[i]]
        hits <- hits[!is.na(hits)]
        if (length(hits) == 0) next
        newest <- max(as.POSIXct(as.character(hits), tz = project_tz),
                      na.rm = TRUE)
        if (!is.na(newest)) {
          last_touch[i] <- format(newest, "%Y-%m-%d %H:%M:%S", tz = "UTC")
        }
      }
    }
  }

  approved <- as.logical(meta$download_approved)

  # Only a row asserting TRUE has a review to date. FALSE means nobody has
  # confirmed it, so there is no moment to record.
  reviewed <- last_touch
  reviewed[is.na(approved) | !approved] <- NA_character_

  cat("Rows: ", nrow(meta), "\n", sep = "")
  cat("  approved TRUE:  ", sum(approved %in% TRUE), "\n", sep = "")
  cat("  approved FALSE: ", sum(approved %in% FALSE), "\n", sep = "")
  cat("  review date recoverable: ", sum(!is.na(reviewed)), "\n\n", sep = "")

  show <- head(which(approved %in% TRUE), 4)
  if (length(show) > 0) {
    cat("Examples:\n\n")
    for (i in show) {
      cat("  ", format(meta$station_id[i], width = 14),
          format(meta$device_serial[i], width = 11),
          "  approved TRUE  reviewed ",
          if (is.na(reviewed[i])) "(unknown)" else reviewed[i], "\n", sep = "")
    }
    cat("\n")
  }

  no_date <- sum(approved %in% TRUE & is.na(reviewed))
  if (no_date > 0) {
    cat("! ", no_date, " approved row(s) have no maintenance entry to date the\n",
        "  review from. Left blank rather than invented - an unknown review\n",
        "  date is honest, a fabricated one makes a stale record look fresh.\n\n",
        sep = "")
  }

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_metadata_approved(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  names(meta)[names(meta) == "download_approved"] <- "metadata_approved"
  meta$last_reviewed_utc <- reviewed

  # Positioned together - they are one fact in two columns
  cols <- names(meta)
  cols <- cols[cols != "last_reviewed_utc"]
  meta <- meta[, append(cols, "last_reviewed_utc",
                        after = which(cols == "metadata_approved")), drop = FALSE]

  write.csv(meta, meta_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)

  ok <- "metadata_approved" %in% names(check) &&
        "last_reviewed_utc" %in% names(check) &&
        !"download_approved" %in% names(check) &&
        nrow(check) == nrow(meta) &&
        which(names(check) == "last_reviewed_utc") ==
          which(names(check) == "metadata_approved") + 1

  if (!ok) {
    cat("\nX Verification FAILED - restore from metadata/internal/backups/\n\n")
    return(invisible(FALSE))
  }

  cat("+ Renamed download_approved -> metadata_approved\n")
  cat("+ Added last_reviewed_utc (", sum(!is.na(check$last_reviewed_utc)),
      " dated, ", sum(is.na(check$last_reviewed_utc)), " blank)\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_metadata_approved(dry_run = TRUE)
