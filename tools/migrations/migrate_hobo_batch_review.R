# VI-FLO migration: record the HOBO batch review
#
# ONE-TIME SCRIPT.
#
# Every HOBO row reads "never reviewed". Not because nobody has looked, but
# because the flag it inherited - download_approved - was forced FALSE for
# manual devices, on the reasoning that a logger with no cloud connection
# cannot be downloaded automatically.
#
# That reasoning does not survive the rename. metadata_approved asserts that
# the record matches what is physically out there, which gates ATTRIBUTION,
# and a HOBO's readings get attributed like any other. So the flag was blank
# for a reason that no longer applies, on records that are in fact correct.
#
# This records a single review of all of them, performed on the date it is
# run. It is not a claim that each was individually walked through - it is the
# honest statement that a human looked at the set and confirmed it.
#
# ONLY ACTIVE ROWS. A terminal row's approval is frozen history, and
# set_metadata_approved() skips them for the same reason.
#
# Safe to run twice: it exits when no active HOBO row is left unreviewed.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_hobo_batch_review.R"))

migrate_hobo_batch_review <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: HOBO batch review\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  if (!all(c("metadata_approved", "last_reviewed_utc") %in% names(meta))) {
    cat("X Columns not present - run migrate_metadata_approved.R first\n\n")
    return(invisible(FALSE))
  }

  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  blank <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")

  is_hobo <- !grepl("^z6", meta$device_serial)
  active  <- !tolower(meta$status) %in% terminal
  unreviewed <- blank(meta$last_reviewed_utc)

  rows <- which(is_hobo & active & unreviewed)

  if (length(rows) == 0) {
    cat("+ Every active HOBO row already carries a review date.\n\n")
    return(invisible(TRUE))
  }

  cat("Active HOBO rows with no review date: ", length(rows), "\n\n", sep = "")
  for (i in rows) {
    cat("  ", format(meta$station_id[i], width = 13),
        format(meta$device_serial[i], width = 10),
        format(ifelse(is.na(meta$device_role[i]), "-", meta$device_role[i]), width = 10),
        format(meta$status[i], width = 8),
        " last visit ", as.character(meta$last_visit[i]), "\n", sep = "")
  }

  # A pair whose slope cannot be computed is a record with something missing,
  # even if nothing in it is wrong. Worth seeing before confirming the set.
  paired <- meta[active & is_hobo & tolower(meta$station_type) == "hydro" &
                 tolower(as.character(meta$device_role)) %in%
                   c("secondary", "tertiary"), ]
  if (nrow(paired) > 0) {
    missing_geom <- paired[blank(paired$elev) | blank(paired$reach_length_m), ]
    if (nrow(missing_geom) > 0) {
      cat("\n! ", nrow(missing_geom), " paired logger(s) still lack the survey\n",
          "  needed for a slope. Confirming the record does not make that\n",
          "  survey exist - it says the record is accurate about what is\n",
          "  there, including what has not been measured yet:\n\n", sep = "")
      for (i in seq_len(nrow(missing_geom))) {
        cat("  ", format(missing_geom$station_id[i], width = 13),
            format(missing_geom$device_serial[i], width = 10),
            " elev ", ifelse(blank(missing_geom$elev[i]), "-",
                             as.character(missing_geom$elev[i])),
            "  reach ", ifelse(blank(missing_geom$reach_length_m[i]), "-",
                               as.character(missing_geom$reach_length_m[i])),
            "\n", sep = "")
      }
    }
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to record the review:\n")
    cat("  migrate_hobo_batch_review(dry_run = FALSE)\n\n")
    return(invisible(length(rows)))
  }

  backup_metadata()
  cat("\n+ Metadata backed up\n")

  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  meta$metadata_approved[rows] <- TRUE
  meta$last_reviewed_utc[rows] <- stamp

  save_device_metadata(meta)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)
  still <- sum(!grepl("^z6", check$device_serial) &
               !tolower(check$status) %in% terminal &
               blank(check$last_reviewed_utc), na.rm = TRUE)

  if (still > 0) {
    cat("\nX ", still, " row(s) still unreviewed - restore from backups/\n\n",
        sep = "")
    return(invisible(FALSE))
  }

  cat("+ Recorded a review of ", length(rows), " HOBO row(s) at ", stamp,
      " UTC\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_hobo_batch_review(dry_run = TRUE)
