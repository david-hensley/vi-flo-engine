# VI-FLO migration: restamp Product 1 filenames in UTC
#
# ONE-TIME SCRIPT.
#
# Product 1 filenames end with the moment they were fetched:
#
#     z6-38175_20260917_20260928_20260928T094705_raw.rds
#                                ^^^^^^^^^^^^^^^
#
# That stamp was written in local time while `timestamp_utc` in download_log
# is UTC, so a file and the log row pointing at it disagreed by four hours.
# Neither was wrong, but nothing said which was which.
#
# The stamp is now UTC, matching the log. This renames the files written
# before that change, taking each new stamp from the log row rather than by
# adding four hours - so a run that straddled a DST boundary or came from a
# machine in another timezone is still correct.
#
# The data date segments are NOT touched. They were already written from
# POSIXct in UTC, and they identify the readings rather than the fetch.
#
# Files and download_log filepaths are changed together: a rename without the
# log rewrite would leave every row pointing at a file that no longer exists.
#
# Safe to run twice: it exits when no filename disagrees with its log row.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_utc_filename_stamps.R"))

migrate_utc_filename_stamps <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: UTC stamps in Product 1 filenames\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  log_file  <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  if (!"timestamp_utc" %in% names(dlog)) {
    cat("X download_log has no timestamp_utc - run the timezone migration first\n\n")
    return(invisible(FALSE))
  }

  auto <- which(dlog$download_type == "automatic")
  if (length(auto) == 0) {
    cat("+ No automatic downloads - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  #### Which filenames disagree with their log row ####
  renames <- list()

  for (i in auto) {
    old_name <- basename(dlog$filepath[i])

    # serial _ start _ end _ stamp _raw.rds - the stamp is the segment with a T
    stem  <- sub("_raw\\.rds$", "", old_name)
    parts <- strsplit(stem, "_")[[1]]
    which_stamp <- grep("^[0-9]{8}T[0-9]{6}$", parts)

    if (length(which_stamp) != 1) {
      cat("  ? No fetch stamp in ", old_name, " - leaving alone\n", sep = "")
      next
    }

    # The stamp the log says it should carry
    want <- format(as.POSIXct(dlog$timestamp_utc[i], tz = "UTC"),
                   "%Y%m%dT%H%M%S", tz = "UTC")

    if (identical(parts[which_stamp], want)) next

    parts[which_stamp] <- want
    new_name <- paste0(paste(parts, collapse = "_"), "_raw.rds")

    renames[[length(renames) + 1]] <- list(
      row = i, old = old_name, new = new_name,
      dir = dirname(dlog$filepath[i]))
  }

  if (length(renames) == 0) {
    cat("+ Every filename already matches its log row - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  cat("Files to restamp: ", length(renames), "\n\n", sep = "")
  for (r in head(renames, 5)) {
    cat("  ", r$old, "\n    -> ", r$new, "\n", sep = "")
  }
  if (length(renames) > 5) {
    cat("  ... and ", length(renames) - 5, " more\n", sep = "")
  }

  #### Nothing may collide ####
  new_paths <- vapply(renames, function(r) file.path(r$dir, r$new), character(1))
  if (any(duplicated(new_paths))) {
    cat("\nX Two files would take the same name - not proceeding\n\n")
    return(invisible(FALSE))
  }

  clash <- new_paths[file.exists(file.path(data_root, new_paths)) &
                     !new_paths %in% dlog$filepath[vapply(renames, function(r) r$row, integer(1))]]
  if (length(clash) > 0) {
    cat("\nX A target name already exists on disk:\n")
    for (f in clash) cat("   ", f, "\n", sep = "")
    cat("\n")
    return(invisible(FALSE))
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_utc_filename_stamps(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up the log ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("download_log_", stamp, ".csv"))
  file.copy(log_file, backup_file)
  cat("\n+ Log backed up to: ", basename(backup_file), "\n", sep = "")

  #### Rename, then rewrite the log ####
  done <- 0
  for (r in renames) {
    from <- file.path(data_root, r$dir, r$old)
    to   <- file.path(data_root, r$dir, r$new)

    if (!file.exists(from)) {
      cat("  ! Missing on disk, log updated anyway: ", r$old, "\n", sep = "")
    } else if (!file.rename(from, to)) {
      cat("  X Could not rename ", r$old, " - log left pointing at it\n", sep = "")
      next
    } else {
      done <- done + 1
    }

    dlog$filepath[r$row] <- file.path(r$dir, r$new)
  }

  write.csv(dlog, log_file, row.names = FALSE)
  cat("+ Renamed ", done, " file(s), rewrote ", length(renames),
      " log filepath(s)\n", sep = "")

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))

  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in check$filepath[missing]) cat("   ", f, "\n", sep = "")
    cat("\n  Restore the log from ", basename(backup_file), " and investigate.\n\n",
        sep = "")
    return(invisible(FALSE))
  }

  cat("\n+ Verified: all ", nrow(check),
      " logged filepath(s) resolve on disk\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_utc_filename_stamps(dry_run = TRUE)
