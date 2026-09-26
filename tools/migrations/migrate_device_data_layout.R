# VI-FLO migration: restructure raw data into device-data
#
# ONE-TIME SCRIPT.
#
# Raw readings are reorganised by DEVICE rather than by station, establishing
# the product tiers agreed in September 2026:
#
#   Product 0  source artifacts as received - export zips, .hobo files
#   Product 1  device-keyed readings, port numbers, no station, no depth
#   Product 2  station-attributed and labelled
#
#
# WHY DEVICE-KEYED
#
# A station name in a filename is an attribution, and attributions can be
# wrong. A logger swapped between stations and logged late means files sitting
# under the wrong station, and only a device-keyed original lets the mistake be
# corrected by rebuilding rather than by renaming.
#
# That has already happened twice: the lg3 -> lg1 rename touched archived
# files, and the January API downloads baked port depths into column names and
# had to be discarded when a depth was found wrong.
#
# Device serial is the one identifier that never needs correcting.
#
#
# WHAT MOVES
#
#   internal/raw/streamflow/*.rds
#     -> internal/raw/device-data/hobo/{serial}_{start}_{end}_raw.rds
#
#   internal/raw/streamflow/shuttle_readouts/
#     -> internal/raw/device-data/hobo/shuttle_readouts/
#
#   internal/raw/zentra-backfill/exports/
#     -> internal/raw/device-data/zentra/backfill/exports/
#
#   internal/raw/zentra-backfill/parsed/
#     -> internal/raw/device-data/zentra/backfill/parsed/
#
# download_log.csv filepaths are rewritten in step, so nothing points at a
# file that has moved.
#
# internal/raw/streamflow and internal/raw/vwc remain - they become Product 2,
# where station-attributed data will live.
#
# Safe to run twice: it detects that the move has happened and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_device_data_layout.R"))

migrate_device_data_layout <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: restructure into device-data\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  hydro     <- wds("internal_raw_hydro")
  hobo_dir  <- wds("device_hobo")
  shuttle_new <- wds("shuttle_readouts")
  backfill_new <- wds("device_zentra_backfill")

  shuttle_old  <- file.path(hydro, "shuttle_readouts")
  backfill_old <- normalizePath(file.path(wds("internal_raw_vwc"), "..",
                                          "zentra-backfill"), mustWork = FALSE)

  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  #### 1. HOBO archives: rename to serial-only and move ####
  rds <- list.files(hydro, pattern = "_raw\\.rds$", full.names = FALSE)

  moves <- list()
  for (f in rds) {
    p <- parse_raw_filename(f)
    if (is.null(p) || is.na(p$device_serial)) {
      cat("  ? Cannot read a serial from ", f, " - leaving in place\n", sep = "")
      next
    }
    new_name <- sub(paste0("^", p$station, "_"), "", f)
    moves[[length(moves) + 1]] <- list(old = f, new = new_name)
  }

  cat("HOBO archives to move: ", length(moves), "\n", sep = "")
  for (mv in moves) cat("  ", mv$old, "\n    -> hobo/", mv$new, "\n", sep = "")

  if (length(moves) > 0 && any(duplicated(vapply(moves, function(m) m$new, character(1))))) {
    cat("\nX Two files would land on the same name - not proceeding\n\n")
    return(invisible(FALSE))
  }

  #### 2. Directories to relocate wholesale ####
  dir_moves <- list()
  if (dir.exists(shuttle_old) && length(list.files(shuttle_old)) > 0) {
    dir_moves[[length(dir_moves) + 1]] <-
      list(from = shuttle_old, to = shuttle_new,
           what = paste0("shuttle readouts (",
                         length(list.files(shuttle_old)), " item(s))"))
  }
  for (sub in c("exports", "parsed")) {
    src <- file.path(backfill_old, sub)
    if (dir.exists(src) && length(list.files(src)) > 0) {
      dir_moves[[length(dir_moves) + 1]] <-
        list(from = src, to = file.path(backfill_new, sub),
             what = paste0("zentra backfill/", sub, " (",
                           length(list.files(src)), " file(s))"))
    }
  }

  cat("\nDirectories to relocate: ", length(dir_moves), "\n", sep = "")
  for (dm in dir_moves) cat("  ", dm$what, "\n", sep = "")

  if (length(moves) == 0 && length(dir_moves) == 0) {
    cat("\n+ Nothing to move - already restructured.\n\n")
    return(invisible(TRUE))
  }

  #### 3. download_log rows affected ####
  old_rel <- vapply(moves, function(m) m$old, character(1))
  log_hits <- which(basename(dlog$filepath) %in% old_rel)
  cat("\ndownload_log rows to rewrite: ", length(log_hits), "\n", sep = "")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_device_data_layout(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up ####
  backup_metadata()
  cat("\n+ Metadata backed up\n")

  if (!dir.exists(hobo_dir)) dir.create(hobo_dir, recursive = TRUE)

  #### Move the files ####
  moved <- 0
  for (mv in moves) {
    from <- file.path(hydro, mv$old)
    to   <- file.path(hobo_dir, mv$new)
    if (file.exists(to)) {
      cat("  ! Already present, skipping: ", mv$new, "\n", sep = "")
      next
    }
    if (file.rename(from, to)) moved <- moved + 1
  }
  cat("+ Moved ", moved, " HOBO archive(s)\n", sep = "")

  #### Move the directories ####
  for (dm in dir_moves) {
    parent <- dirname(dm$to)
    if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
    if (!dir.exists(dm$to)) dir.create(dm$to, recursive = TRUE)

    items <- list.files(dm$from, full.names = TRUE)
    n <- 0
    for (it in items) {
      if (file.rename(it, file.path(dm$to, basename(it)))) n <- n + 1
    }
    cat("+ Relocated ", n, " item(s): ", dm$what, "\n", sep = "")

    # Remove the source only if it emptied cleanly
    if (length(list.files(dm$from, all.files = TRUE, no.. = TRUE)) == 0) {
      unlink(dm$from, recursive = TRUE)
    }
  }

  #### Rewrite download_log ####
  hobo_rel <- sub(paste0("^", gsub("\\\\", "/", data_root), "/?"), "",
                  gsub("\\\\", "/", hobo_dir))

  for (i in log_hits) {
    b <- basename(dlog$filepath[i])
    mv <- Filter(function(m) m$old == b, moves)[[1]]
    dlog$filepath[i] <- file.path(hobo_rel, mv$new)
  }
  write.csv(dlog, log_file, row.names = FALSE)
  cat("+ Rewrote ", length(log_hits), " download_log filepath(s)\n", sep = "")

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))

  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in check$filepath[missing]) cat("   ", f, "\n", sep = "")
    cat("\n  Restore from metadata/internal/backups/ and investigate.\n\n")
    return(invisible(FALSE))
  }

  left <- list.files(hydro, pattern = "_raw\\.rds$")
  if (length(left) > 0) {
    cat("\n! Still in streamflow (no serial in the name?): ",
        paste(left, collapse = ", "), "\n", sep = "")
  }

  cat("\n+ Verified: all ", nrow(check),
      " logged filepath(s) resolve on disk\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_device_data_layout(dry_run = TRUE)
