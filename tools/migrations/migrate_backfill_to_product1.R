# VI-FLO migration: the parsed exports become Product 1
#
# ONE-TIME SCRIPT.
#
# The September 2026 full-history exports were parsed into 26 files named
# {serial}_parsed.rds, sitting in device-data/zentra/backfill/parsed/ as
# intermediate working output. In substance they are already Product 1 - a
# faithful transcription of what the exports said, nothing invented.
#
# What they lack is the bookkeeping. No date range or fetch stamp in the name,
# so zentra_last_held() cannot read them; no download_log row, so the chain
# from file to log to run does not exist for them. They sit outside the system
# that knows about every other file.
#
# This renames them to the Product 1 convention, moves them beside the API
# downloads, and writes their log rows.
#
#
# WHAT IS NOT CHANGED
#
# The columns. Product 1 is a faithful transcription, and the export shape is
# what the exports gave:
#
#   config          which logger configuration a reading came from - this is
#                   how the UVI port depths and the TEROS 21 handover dates
#                   were established, and it has no API equivalent
#   offset_known    whether the export declared a timezone. FALSE means it said
#                   "Not Set" and the reading was taken as UTC - an assumption
#                   worth carrying rather than burying
#   port_internal   ports 7 and 8, the logger's own battery and barometer
#
# Reshaping these into the API's column names would be interpretation, and
# interpretation belongs at Product 2. Attribution reads each source with its
# own reader - it already must, because HOBO is a third shape again.
#
#
# PROVENANCE
#
# download_type is "export", distinguishing these from "automatic" (the API)
# and "manual" (a shuttle offload). That matters because the device-level
# history before 2024 was not systematically recorded, so attribution of this
# era rests on reconstruction rather than on a logged deployment. A user who
# wants nothing to do with it can filter on one column.
#
# Where exactly that boundary falls is per station and is a judgement, not a
# derivation - it lives in record_confirmed.csv, built separately.
#
# Safe to run twice: it skips any export already converted.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_backfill_to_product1.R"))

migrate_backfill_to_product1 <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: parsed exports become Product 1\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  parsed_dir <- file.path(wds("device_zentra_backfill"), "parsed")
  out_dir    <- wds("device_zentra")

  if (!dir.exists(parsed_dir)) {
    cat("X No parsed directory at ", parsed_dir, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  files <- list.files(parsed_dir, pattern = "_parsed\\.rds$", full.names = TRUE)
  if (length(files) == 0) {
    cat("+ No parsed exports to convert.\n\n")
    return(invisible(TRUE))
  }

  #### What is already converted ####
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)
  already <- if ("download_type" %in% names(dlog)) {
    dlog$device_serial[dlog$download_type == "export"]
  } else character(0)

  project_tz <- tryCatch({
    m <- load_zentra_metadata()
    tz <- m$timezone[!is.na(m$timezone)][1]
    if (is.na(tz) || !nzchar(tz)) "America/Puerto_Rico" else tz
  }, error = function(e) "America/Puerto_Rico")

  #### The export date, shared by every file ####
  # One stamp for the whole conversion, as a download run would have. The
  # exports were taken on 2026-09-14 - that is when the data left ZentraCloud,
  # and is more honest than the date this script happens to run.
  exported_at <- as.POSIXct("2026-09-14 00:00:00", tz = "UTC")
  stamp <- format(exported_at, "%Y%m%dT%H%M%S", tz = "UTC")

  #### Plan ####
  plan <- list()
  skipped <- character(0)

  for (f in files) {
    sn <- sub("_parsed\\.rds$", "", basename(f))

    if (sn %in% already) { skipped <- c(skipped, sn); next }

    d <- readRDS(f)
    if (nrow(d) == 0) { skipped <- c(skipped, sn); next }

    first <- min(d$timestamp_utc, na.rm = TRUE)
    last  <- max(d$timestamp_utc, na.rm = TRUE)

    fname <- paste0(sn, "_", format(first, "%Y%m%d", tz = "UTC"), "_",
                    format(last, "%Y%m%d", tz = "UTC"), "_", stamp, "_raw.rds")

    plan[[length(plan) + 1]] <- list(
      src = f, sn = sn, fname = fname, n = nrow(d),
      first = first, last = last,
      configs = length(unique(d$config)),
      unset = sum(!d$offset_known) / nrow(d))
  }

  if (length(skipped) > 0) {
    cat("Already converted, skipping: ", length(skipped), "\n\n", sep = "")
  }

  if (length(plan) == 0) {
    cat("+ Everything is already Product 1.\n\n")
    return(invisible(TRUE))
  }

  cat("To convert: ", length(plan), " device(s)\n\n", sep = "")
  for (p in plan) {
    cat("  ", format(p$sn, width = 10),
        format(format(p$n, big.mark = ","), width = 10, justify = "right"),
        " rows  ", format(p$first, "%Y-%m-%d"), " to ", format(p$last, "%Y-%m-%d"),
        "  ", p$configs, " config(s)",
        if (p$unset > 0) paste0("  [", round(p$unset * 100), "% no timezone]") else "",
        "\n", sep = "")
  }

  total <- sum(vapply(plan, function(p) p$n, numeric(1)))
  cat("\nTotal: ", format(total, big.mark = ","), " readings\n", sep = "")

  #### Nothing may collide ####
  names_out <- vapply(plan, function(p) p$fname, character(1))
  clash <- names_out[file.exists(file.path(out_dir, names_out))]
  if (length(clash) > 0) {
    cat("\nX These names already exist in device-data/zentra:\n")
    for (f in clash) cat("   ", f, "\n", sep = "")
    cat("\n")
    return(invisible(FALSE))
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to convert:\n")
    cat("  migrate_backfill_to_product1(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up the log before writing to it ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  bstamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  file.copy(log_file, file.path(backup_dir, paste0("download_log_", bstamp, ".csv")))
  cat("\n+ download_log backed up\n")

  #### Convert ####
  # COPIED, not moved. The parsed files stay where they are as the record of
  # what the export parser produced - they are its output, and deleting them
  # would make the backfill episode harder to audit, which is the one thing
  # tools/backfill exists for.
  done <- 0
  for (p in plan) {
    ok <- file.copy(p$src, file.path(out_dir, p$fname))
    if (!ok) {
      cat("  X could not write ", p$fname, "\n", sep = "")
      next
    }

    rel <- sub(paste0("^", gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT")), "/?"),
               "", gsub("\\\\", "/", file.path(out_dir, p$fname)))

    entry <- data.frame(
      timestamp_utc = format(exported_at, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      run_id        = stamp,
      station       = NA_character_,
      device_serial = p$sn,
      start_date    = format(p$first, "%Y-%m-%d %H:%M:%S", tz = project_tz),
      end_date      = format(p$last,  "%Y-%m-%d %H:%M:%S", tz = project_tz),
      n_records     = p$n,
      filepath      = rel,
      download_type = "export",
      stringsAsFactors = FALSE
    )

    for (col in setdiff(names(dlog), names(entry))) entry[[col]] <- NA
    entry <- entry[, names(dlog), drop = FALSE]
    dlog <- rbind(dlog, entry)

    done <- done + 1
    cat("  + ", p$fname, "\n", sep = "")
  }

  write.csv(dlog, log_file, row.names = FALSE)
  cat("\n+ Converted ", done, " export(s)\n", sep = "")
  cat("+ Wrote ", done, " download_log row(s) as download_type = export\n", sep = "")

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(Sys.getenv("VI_FLO_DATA_ROOT"), check$filepath))

  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in head(check$filepath[missing], 10)) cat("   ", f, "\n", sep = "")
    cat("\n  Restore the log from backups/ and investigate.\n\n")
    return(invisible(FALSE))
  }

  cat("+ Verified: all ", nrow(check),
      " logged filepath(s) resolve on disk\n\n", sep = "")

  cat("NEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. zentra_download(dry_run = TRUE) - resume points should now reach\n")
  cat("     back to the exports for any device with no API file yet\n\n")

  invisible(TRUE)
}

migrate_backfill_to_product1(dry_run = TRUE)
