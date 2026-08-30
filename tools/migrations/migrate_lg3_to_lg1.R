# VI-FLO migration: lg3_hydro -> lg1_hydro
#
# ONE-TIME SCRIPT.
#
# The La Grange stream gauge was named lg3, but it sits UPSTREAM of the
# La Grange weather station. Under the site numbering convention - lower
# numbers further upstream - the gauge should carry the lower number.
#
# This is a SPLIT rather than a rename: lg3 remains in use by the weather
# station, and the gauge moves to a site of its own.
#
#   lg3_hydro   -> lg1_hydro,  site lg1, "La Grange 1"
#   lg3_weather -> unchanged,  site lg3, "La Grange 3"
#
# lg2 is deliberately left free for a plausible future mid-catchment station,
# and lg3 will one day also carry a gauge near the mouth.
#
# Touches device_metadata, maintenance_log, download_log, pending_ingest, the
# archived RDS files, and station photos. unique_id is a sequential counter and
# is NOT derived from station_id, so it is left alone.
#
# Safe to run twice - it detects that nothing matches and exits.
#
# AFTER RUNNING: Box will hold both the old and new RDS filenames, because
# rclone copy uploads the new name but never deletes the old. Delete the stale
# lg3_hydro_*.rds in the Box web interface once you have pushed and verified.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_lg3_to_lg1.R"))

migrate_lg3_to_lg1 <- function(dry_run = TRUE) {

  OLD_STATION   <- "lg3_hydro"
  NEW_STATION   <- "lg1_hydro"
  NEW_SITE      <- "lg1"
  NEW_SITE_FULL <- "La Grange 1"
  OLD_SITE      <- "lg3"
  OLD_SITE_FULL <- "La Grange 3"

  cat("\n============================================\n")
  cat("  Migration: ", OLD_STATION, " -> ", NEW_STATION, "\n", sep = "")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_dir  <- wds("meta_internal")
  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  changes <- 0

  if (!dry_run) {
    backup_metadata()
    cat("+ Metadata backed up\n\n")
  }

  ############################################################################
  #### 1. device_metadata.csv
  ############################################################################
  meta_file <- file.path(meta_dir, "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  hits <- which(meta$station_id == OLD_STATION)
  cat("device_metadata.csv: ", length(hits), " row(s)\n", sep = "")

  for (i in hits) {
    cat("  ", meta$unique_id[i], " (", meta$device_serial[i], ")  ",
        meta$site[i], " / ", meta$site_full[i],
        " -> ", NEW_SITE, " / ", NEW_SITE_FULL, "\n", sep = "")
  }

  if (length(hits) > 0 && !dry_run) {
    meta$station_id[hits] <- NEW_STATION
    meta$site[hits]       <- NEW_SITE
    meta$site_full[hits]  <- NEW_SITE_FULL
    # Read with read.csv, so every column is a character string and writes
    # back byte-identical - no datetime reformatting needed or wanted
    write.csv(meta, meta_file, row.names = FALSE)
  }
  changes <- changes + length(hits)

  ############################################################################
  #### 2. maintenance_log.csv
  ############################################################################
  mlog_file <- file.path(meta_dir, "maintenance_log.csv")
  if (file.exists(mlog_file)) {
    mlog <- read.csv(mlog_file, stringsAsFactors = FALSE)
    mhits <- which(mlog$station_id == OLD_STATION)
    cat("maintenance_log.csv: ", length(mhits), " row(s)\n", sep = "")
    for (i in mhits) {
      cat("  ", mlog$field_visit_date[i], "  ", mlog$action_type[i], "\n", sep = "")
    }

    # The establishment note names the site - "New station established:
    # La Grange 3" - and that is metadata about the station rather than a
    # record of anything done in the field, so it is corrected with the rest.
    #
    # Deliberately narrow: only station_established rows for THIS station, and
    # only the site name inside them. Notes describing physical actions - a
    # relaunch, a device rename - say what was actually done at the time and
    # are left exactly as written, even where they name the old identity.
    est <- mhits[mlog$action_type[mhits] == "station_established"]
    est <- est[grepl(OLD_SITE_FULL, mlog$details[est], fixed = TRUE)]

    if (length(est) > 0) {
      cat("\n  Details to correct (station_established only):\n")
      for (i in est) {
        cat("    \"", mlog$details[i], "\"\n", sep = "")
        cat("      -> \"", sub(OLD_SITE_FULL, NEW_SITE_FULL, mlog$details[i],
                              fixed = TRUE), "\"\n", sep = "")
      }
      cat("\n")
    }

    other <- setdiff(mhits, est)
    keep_mentions <- other[grepl(OLD_SITE_FULL, mlog$details[other], fixed = TRUE) |
                           grepl(OLD_SITE, mlog$details[other], fixed = TRUE)]
    if (length(keep_mentions) > 0) {
      cat("  Details left untouched (they record what was physically done):\n")
      for (i in keep_mentions) {
        cat("    ", mlog$action_type[i], ": \"", mlog$details[i], "\"\n", sep = "")
      }
      cat("\n")
    }

    if (length(mhits) > 0 && !dry_run) {
      mlog$station_id[mhits] <- NEW_STATION
      if (length(est) > 0) {
        mlog$details[est] <- sub(OLD_SITE_FULL, NEW_SITE_FULL,
                                 mlog$details[est], fixed = TRUE)
      }
      write.csv(mlog, mlog_file, row.names = FALSE)
    }
    changes <- changes + length(mhits)
  }

  ############################################################################
  #### 3. download_log.csv - station AND the filepath referencing it
  ############################################################################
  dlog_file <- file.path(meta_dir, "download_log.csv")
  if (file.exists(dlog_file)) {
    dlog <- read.csv(dlog_file, stringsAsFactors = FALSE)
    dhits <- which(dlog$station == OLD_STATION)
    cat("download_log.csv: ", length(dhits), " row(s)\n", sep = "")
    for (i in dhits) cat("  ", dlog$filepath[i], "\n", sep = "")

    if (length(dhits) > 0 && !dry_run) {
      dlog$station[dhits] <- NEW_STATION
      dlog$filepath[dhits] <- sub(paste0("(^|/)", OLD_STATION, "_"),
                                  paste0("\\1", NEW_STATION, "_"),
                                  dlog$filepath[dhits])
      write.csv(dlog, dlog_file, row.names = FALSE)
    }
    changes <- changes + length(dhits)
  }

  ############################################################################
  #### 4. pending_ingest.csv
  ############################################################################
  plog_file <- file.path(meta_dir, "pending_ingest.csv")
  if (file.exists(plog_file)) {
    plog <- read.csv(plog_file, stringsAsFactors = FALSE, colClasses = "character")
    if (nrow(plog) > 0) {
      phits <- which(plog$station_id == OLD_STATION)
      cat("pending_ingest.csv: ", length(phits), " row(s)\n", sep = "")
      if (length(phits) > 0 && !dry_run) {
        plog$station_id[phits] <- NEW_STATION
        write.csv(plog, plog_file, row.names = FALSE)
      }
      changes <- changes + length(phits)
    }
  }

  ############################################################################
  #### 5. Archived RDS files
  ############################################################################
  # Scan every raw directory, not just the expected one - a misfiled archive
  # should still be found and renamed rather than silently left behind.
  raw_root <- file.path(data_root, "internal", "raw")
  rds_files <- list.files(raw_root, pattern = paste0("^", OLD_STATION, "_.*\\.rds$"),
                          recursive = TRUE, full.names = TRUE)
  cat("archived RDS files: ", length(rds_files), "\n", sep = "")

  for (f in rds_files) {
    new_f <- file.path(dirname(f), sub(paste0("^", OLD_STATION, "_"),
                                       paste0(NEW_STATION, "_"), basename(f)))
    cat("  ", basename(f), "\n    -> ", basename(new_f), "\n", sep = "")
    if (!dry_run) {
      if (file.exists(new_f)) {
        cat("  ! Target already exists, skipping\n")
      } else {
        file.rename(f, new_f)
      }
    }
    changes <- changes + 1
  }

  ############################################################################
  #### 6. Station photos
  ############################################################################
  photo_dir <- file.path(meta_dir, "station_photos")
  if (dir.exists(photo_dir)) {
    photos <- list.files(photo_dir, pattern = paste0("^", OLD_STATION, "_"),
                         full.names = TRUE)
    cat("station photos: ", length(photos), "\n", sep = "")
    for (f in photos) {
      new_f <- file.path(dirname(f), sub(paste0("^", OLD_STATION, "_"),
                                         paste0(NEW_STATION, "_"), basename(f)))
      cat("  ", basename(f), " -> ", basename(new_f), "\n", sep = "")
      if (!dry_run) file.rename(f, new_f)
      changes <- changes + 1
    }
  }

  ############################################################################
  #### Summary / verification
  ############################################################################
  cat("\n--------------------------------------------\n")

  if (dry_run) {
    cat(changes, " change(s) would be made.\n\n", sep = "")
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_lg3_to_lg1(dry_run = FALSE)\n\n")
    return(invisible(changes))
  }

  cat(changes, " change(s) applied. Verifying...\n\n", sep = "")

  ok <- TRUE

  meta_check <- read.csv(meta_file, stringsAsFactors = FALSE)
  if (any(meta_check$station_id == OLD_STATION)) {
    cat("X device_metadata still references ", OLD_STATION, "\n", sep = "")
    ok <- FALSE
  }

  # lg3 must survive - the weather station still uses it
  if (!any(meta_check$site == "lg3")) {
    cat("X site 'lg3' has vanished - the weather station should still use it\n")
    ok <- FALSE
  }

  if (file.exists(dlog_file)) {
    dlog_check <- read.csv(dlog_file, stringsAsFactors = FALSE)
    if (any(dlog_check$station == OLD_STATION)) {
      cat("X download_log still references ", OLD_STATION, "\n", sep = "")
      ok <- FALSE
    }
    # Every logged filepath must resolve - this is the check that catches a
    # half-completed rename, where the log points at nothing
    for (fp in dlog_check$filepath) {
      if (!file.exists(file.path(data_root, fp))) {
        cat("X download_log points at a missing file: ", fp, "\n", sep = "")
        ok <- FALSE
      }
    }
  }

  leftover <- list.files(raw_root, pattern = paste0("^", OLD_STATION, "_"),
                         recursive = TRUE)
  if (length(leftover) > 0) {
    cat("X RDS files still named ", OLD_STATION, ": ",
        paste(leftover, collapse = ", "), "\n", sep = "")
    ok <- FALSE
  }

  if (ok) {
    cat("+ Verified: no references to ", OLD_STATION, " remain, site 'lg3'\n",
        "  survives for the weather station, and every logged filepath\n",
        "  exists on disk.\n\n", sep = "")
    cat("NEXT: run validate_metadata(), then push. Afterwards delete the\n")
    cat("stale ", OLD_STATION, "_*.rds from Box by hand - rclone copy uploads\n", sep = "")
    cat("the new name but never removes the old one.\n\n")
  } else {
    cat("\nX Verification FAILED. Restore from metadata/internal/backups/\n\n")
  }

  invisible(ok)
}

migrate_lg3_to_lg1(dry_run = TRUE)
