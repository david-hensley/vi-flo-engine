# VI-FLO: repairing datetime formats and two filenames
#
# ONE-TIME MIGRATION.
#
# Three things to put right, all of them instances of rules the data
# dictionary already states.
#
#   1. Eighteen Zentra rows hold a UNIX epoch in last_record_date, because
#      zentra_update_device_facts() assigned a POSIXct into a character
#      column without formatting it. The values are correct; the format is
#      unreadable by anything downstream.
#
#   2. Thirty-one Zentra rows have no last_download_date, which the dictionary
#      defines for every device, not only manual ones.
#
#   3. Two Product 1 filenames carry a span a day ahead of their data:
#      21179105_20211203_20220218_raw.rds and its Fish Bay twin. The last
#      reading is 2022-02-17 21:58 local, which falls on the 18th in UTC. A
#      filename's span dates are reading times and belong in project local -
#      only the fetch stamp is UTC.
#
# The writers that caused 1 and 2 are fixed separately, and two validation
# checks now catch both classes. This repairs what they already wrote.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_datetime_repair.R"))
#   migrate_datetime_repair()
#   migrate_datetime_repair(dry_run = FALSE)

migrate_datetime_repair <- function(dry_run = TRUE) {

  TZ <- "America/Puerto_Rico"
  meta <- load_zentra_metadata()
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)

  cat("\n############################################\n")
  cat("  Datetime formats and filenames\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n")

  dt_fields <- intersect(c("deploy_datetime", "last_update", "last_visit",
                           "expiry_date", "last_download_date",
                           "last_record_date", "last_reviewed_utc"),
                         names(meta))

  #### 1. Epochs ####
  cat("\n  1. UNIX epochs in datetime fields\n\n")
  epochs <- list()
  for (field in dt_fields) {
    v <- as.character(meta[[field]])
    for (i in which(!is.na(v) & grepl("^[0-9]{9,13}$", v))) {
      to <- format(as.POSIXct(as.numeric(v[i]), origin = "1970-01-01", tz = TZ),
                   "%Y-%m-%d %H:%M:%S")
      cat(sprintf("    %-8s %-10s %-12s %-18s %s -> %s\n", meta$unique_id[i],
                  meta$device_serial[i], meta$station_id[i], field, v[i], to))
      epochs[[length(epochs) + 1]] <- list(i = i, field = field, to = to)
    }
  }
  if (length(epochs) == 0) cat("    none\n")

  #### 2. Zentra rows with no last_download_date ####
  #
  # Taken from the log's timestamp_utc - when the download ran - which is the
  # same rule the HOBO path now follows. Each download is matched to a
  # deployment by the span it covers, so a device that moved station gets the
  # right date on each row.
  cat("\n  2. last_download_date, from the download log\n\n")
  ran   <- suppressWarnings(as.POSIXct(dlog$timestamp_utc, tz = "UTC"))
  cover <- suppressWarnings(as.POSIXct(dlog$end_date, tz = TZ))
  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  fills <- list()

  for (sn in unique(meta$device_serial)) {
    idx <- which(meta$device_serial == sn)
    starts <- suppressWarnings(as.POSIXct(meta$deploy_datetime[idx], tz = TZ))
    idx <- idx[order(starts)]; starts <- sort(starts)

    for (k in seq_along(idx)) {
      i <- idx[k]
      if (!is.na(meta$last_download_date[i]) &&
          nzchar(as.character(meta$last_download_date[i]))) next
      from <- starts[k]
      if (is.na(from)) next

      bounds <- as.POSIXct(character(0), tz = TZ)
      if (k < length(idx)) bounds <- c(bounds, starts[k + 1])
      if (tolower(meta$status[i]) %in% terminal &&
          !is.na(meta$last_visit[i]) && nzchar(as.character(meta$last_visit[i])))
        bounds <- c(bounds, suppressWarnings(as.POSIXct(
          paste(as.character(meta$last_visit[i]), "23:59:59"), tz = TZ)))
      to <- if (length(bounds)) min(bounds) else Sys.time()

      hit <- which(dlog$device_serial == sn & !is.na(ran) & !is.na(cover) &
                   cover >= from & cover < to)
      if (length(hit) == 0) next

      val <- format(max(ran[hit]), "%Y-%m-%d %H:%M:%S", tz = TZ)
      cat(sprintf("    %-8s %-10s %-12s -> %s\n", meta$unique_id[i],
                  sn, meta$station_id[i], val))
      fills[[length(fills) + 1]] <- list(i = i, to = val)
    }
  }
  if (length(fills) == 0) cat("    none to fill\n")

  #### 3. Filenames whose span is a day out ####
  cat("\n  3. Filenames disagreeing with their logged span\n\n")
  pattern <- "^(.+)_([0-9]{8})_([0-9]{8})((?:_[0-9]{8}T[0-9]{6})?_raw\\.rds)$"
  renames <- list()
  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")

  for (r in seq_len(nrow(dlog))) {
    fn <- basename(as.character(dlog$filepath[r]))
    m <- regmatches(fn, regexec(pattern, fn))[[1]]
    if (length(m) < 5) next
    # Explicit, even though read.csv gives character here: as.Date() on a
    # POSIXct silently uses UTC, which is the mistake being repaired.
    a <- suppressWarnings(as.Date(dlog$start_date[r], tz = TZ))
    b <- suppressWarnings(as.Date(dlog$end_date[r], tz = TZ))
    if (is.na(a) || is.na(b)) next
    want <- paste0(m[2], "_", format(a, "%Y%m%d"), "_", format(b, "%Y%m%d"), m[5])
    if (identical(want, fn)) next
    cat(sprintf("    %s\n      -> %s\n", fn, want))
    renames[[length(renames) + 1]] <- list(row = r, from = fn, to = want)
  }
  if (length(renames) == 0) cat("    none\n")

  cat("\n############################################\n")
  cat("  ", length(epochs), " epoch(s), ", length(fills),
      " download date(s), ", length(renames), " rename(s)\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_datetime_repair(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  if (length(epochs) + length(fills) + length(renames) == 0) {
    cat("\n+ Nothing to do.\n\n"); return(invisible(TRUE))
  }

  backup_metadata()
  bdir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(bdir)) dir.create(bdir, recursive = TRUE)
  file.copy(log_file, file.path(bdir, paste0("download_log_",
            format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")))
  cat("\n+ metadata and download log backed up\n")

  for (e in epochs) meta[[e$field]][e$i] <- e$to
  for (f in fills)  meta$last_download_date[f$i] <- f$to
  if (length(epochs) + length(fills) > 0) {
    save_device_metadata(meta)
    cat("+ metadata written\n")
  }

  #### Rename the files, then the log rows - in that order ####
  #
  # If a rename fails the log still points at the file that exists. The
  # reverse would leave the log dangling, which validation would flag but
  # only after the fact.
  done <- 0
  for (r in renames) {
    old_rel <- as.character(dlog$filepath[r$row])
    new_rel <- file.path(dirname(old_rel), r$to)
    old_abs <- file.path(data_root, old_rel)
    new_abs <- file.path(data_root, new_rel)

    if (!file.exists(old_abs)) {
      cat("  ! ", r$from, " is not on disk - skipped\n", sep = ""); next
    }
    if (file.exists(new_abs)) {
      cat("  ! ", r$to, " already exists - skipped\n", sep = ""); next
    }
    if (!file.rename(old_abs, new_abs)) {
      cat("  ! could not rename ", r$from, "\n", sep = ""); next
    }
    dlog$filepath[r$row] <- new_rel
    done <- done + 1
    cat("  + ", r$to, "\n", sep = "")
  }

  if (done > 0) {
    write.csv(dlog, log_file, row.names = FALSE)
    cat("+ download log updated\n")
  }

  cat("\nNEXT:\n")
  cat("  1. validate_metadata() - the two new checks should pass\n")
  cat("  2. run a Zentra download to confirm it now writes ISO\n\n")

  invisible(TRUE)
}
