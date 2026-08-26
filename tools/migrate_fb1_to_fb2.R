# VI-FLO migration: fb1_vwc1 -> fb2_vwc1
#
# ONE-TIME SCRIPT.
#
# A site is a neighbourhood within a watershed, and several station types may
# share one. The Fish Bay soil moisture station sits at the coastal
# neighbourhood, which by the site numbering convention (lower numbers further
# upstream) should be fb2 - leaving fb1 for a possible upstream gauge. The
# Fish Bay weather station is genuinely upstream and is correctly fb1, so this
# is a split rather than a straight rename: fb1_vwc1 moves to its own site.
#
# Touches device_metadata, maintenance_log, download_log, pending_ingest, the
# archived RDS files, and station photos. unique_id is a sequential counter and
# is NOT derived from station_id, so it is left alone.
#
# Safe to run twice - it detects that nothing matches and exits.
#
# AFTER RUNNING: Box will hold both the old and new RDS filenames, because
# rclone copy uploads the new name but never deletes the old. Delete the stale
# fb1_vwc1_*.rds in the Box web interface once you have pushed and verified.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrate_fb1_to_fb2.R"))

migrate_fb1_to_fb2 <- function(dry_run = TRUE) {

  OLD_STATION <- "fb1_vwc1"
  NEW_STATION <- "fb2_vwc1"
  NEW_SITE    <- "fb2"
  NEW_SITE_FULL <- "Fish Bay 2"

  cat("\n============================================\n")
  cat("  Migration: ", OLD_STATION, " -> ", NEW_STATION, "\n", sep = "")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_dir <- wds("meta_internal")
  changes <- 0

  #### Back up before anything ####
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

  if (length(hits) > 0) {
    for (i in hits) {
      cat("  ", meta$unique_id[i], "  ", meta$site[i], " / ", meta$site_full[i],
          " -> ", NEW_SITE, " / ", NEW_SITE_FULL, "\n", sep = "")
    }
    if (!dry_run) {
      meta$station_id[hits] <- NEW_STATION
      meta$site[hits]       <- NEW_SITE
      meta$site_full[hits]  <- NEW_SITE_FULL

      # Read with read.csv, so every column is already a character string and
      # writes back byte-identical. No datetime reformatting is needed here -
      # and applying format_datetime_safe() to characters would error, since
      # format() reads its second argument as 'trim' for a character vector.
      write.csv(meta, meta_file, row.names = FALSE)
    }
    changes <- changes + length(hits)
  }

  ############################################################################
  #### 2. maintenance_log.csv
  ############################################################################
  mlog_file <- file.path(meta_dir, "maintenance_log.csv")
  if (file.exists(mlog_file)) {
    mlog <- read.csv(mlog_file, stringsAsFactors = FALSE)
    mhits <- which(mlog$station_id == OLD_STATION)
    cat("maintenance_log.csv: ", length(mhits), " row(s)\n", sep = "")
    if (length(mhits) > 0 && !dry_run) {
      mlog$station_id[mhits] <- NEW_STATION
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
    for (i in dhits) {
      cat("  ", dlog$filepath[i], "\n", sep = "")
    }
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
  raw_root <- file.path(Sys.getenv("VI_FLO_DATA_ROOT"), "internal", "raw")
  rds_files <- list.files(raw_root, pattern = paste0("^", OLD_STATION, "_.*\\.rds$"),
                          recursive = TRUE, full.names = TRUE)
  cat("archived RDS files: ", length(rds_files), "\n", sep = "")

  for (f in rds_files) {
    new_f <- file.path(dirname(f), sub(paste0("^", OLD_STATION, "_"),
                                       paste0(NEW_STATION, "_"), basename(f)))
    cat("  ", basename(f), " -> ", basename(new_f), "\n", sep = "")
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
    cat("  migrate_fb1_to_fb2(dry_run = FALSE)\n\n")
    return(invisible(changes))
  }

  cat(changes, " change(s) applied. Verifying...\n\n", sep = "")

  ok <- TRUE

  meta_check <- read.csv(meta_file, stringsAsFactors = FALSE)
  if (any(meta_check$station_id == OLD_STATION)) {
    cat("X device_metadata still references ", OLD_STATION, "\n", sep = "")
    ok <- FALSE
  }

  if (file.exists(dlog_file)) {
    dlog_check <- read.csv(dlog_file, stringsAsFactors = FALSE)
    if (any(dlog_check$station == OLD_STATION)) {
      cat("X download_log still references ", OLD_STATION, "\n", sep = "")
      ok <- FALSE
    }
    # Every logged filepath must actually exist - this is the check that
    # catches a half-completed rename, where the log points at nothing.
    for (fp in dlog_check$filepath) {
      full <- file.path(Sys.getenv("VI_FLO_DATA_ROOT"), fp)
      if (!file.exists(full)) {
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
    cat("+ Verified: no references to ", OLD_STATION, " remain, and every\n",
        "  logged filepath exists on disk.\n\n", sep = "")
    cat("NEXT: run validate_metadata(), then push. Afterwards delete the\n")
    cat("stale ", OLD_STATION, "_*.rds from Box by hand - rclone copy uploads\n", sep = "")
    cat("the new name but never removes the old one.\n\n")
  } else {
    cat("\nX Verification FAILED. Restore from metadata/internal/backups/\n\n")
  }

  invisible(ok)
}

migrate_fb1_to_fb2(dry_run = TRUE)
