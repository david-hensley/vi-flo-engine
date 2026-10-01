################################################################################
#                      ZENTRA API DOWNLOAD (v5)                                #
#                                                                              #
# Fetches readings from ZentraCloud through the v5 API and writes them as       #
# Product 1 - one file per download, keyed by DEVICE:                           #
#                                                                              #
#     internal/raw/device-data/zentra/                                          #
#         z6-12874_20260924_20260926_20260927T143022_raw.rds                    #
#                                                                              #
#     serial _ first record _ last record _ when fetched                        #
#                                                                              #
# Station attribution happens at Product 2. A station name in a Product 1       #
# filename would be an attribution, and attributions can be wrong.              #
#                                                                              #
#                                                                              #
# WHY FILE PER DOWNLOAD RATHER THAN ONE FILE PER DEVICE                         #
#                                                                              #
# zentraR's own store keeps one accumulating file per device, rewritten on      #
# every sync. That is simpler, but every rewrite is a new full copy in version  #
# control - roughly 47 GB of stored revisions after five years against 1.8 GB   #
# for files written once and never touched again.                              #
#                                                                              #
# Immutable files also mean a download can be audited: each file is exactly     #
# what one fetch returned, and download_log has one row pointing at it.         #
#                                                                              #
#                                                                              #
# WHERE EACH DEVICE RESUMES FROM                                                #
#                                                                              #
#   1. the latest timestamp in its existing Product 1 files                     #
#   2. failing that, the latest in the parsed backfill exports - this is what   #
#      the first run uses, and it is why the backfill and the API meet without  #
#      a gap or an overlap                                                      #
#   3. failing that, the device's first measurement, from the API               #
#                                                                              #
# Devices are discovered from the API, not from metadata. A logger reporting    #
# to ZentraCloud that VI-FLO does not yet know about still gets downloaded -    #
# an admin oversight should not become data loss. Attribution decides later     #
# what has a station.                                                           #
################################################################################


#' Timestamp of the newest reading already held for a device
#'
#' @param device_sn Character
#' @return POSIXct, or NA if nothing is held
zentra_last_held <- function(device_sn) {

  #### Product 1 files ####
  p1 <- list.files(wds("device_zentra"), pattern = "_raw\\.rds$",
                   full.names = TRUE)
  mine <- p1[startsWith(basename(p1), paste0(device_sn, "_"))]

  if (length(mine) > 0) {
    # The newest file's last record - reading only one file rather than all
    ends <- vapply(basename(mine), function(f) {
      parts <- strsplit(sub("_raw\\.rds$", "", f), "_")[[1]]
      if (length(parts) < 3) return(NA_character_)
      parts[3]                      # the end date segment
    }, character(1), USE.NAMES = FALSE)

    newest <- mine[which.max(as.Date(ends, format = "%Y%m%d"))]
    d <- readRDS(newest)
    if (nrow(d) > 0) return(max(d$datetime, na.rm = TRUE))
  }

  #### Parsed backfill exports ####
  bf <- file.path(wds("device_zentra_backfill"), "parsed",
                  paste0(device_sn, "_parsed.rds"))
  if (file.exists(bf)) {
    d <- readRDS(bf)
    if (nrow(d) > 0) return(max(d$timestamp_utc, na.rm = TRUE))
  }

  as.POSIXct(NA)
}


#' Downloads new readings for every device the key can reach
#'
#' @param devices Character vector of serials, or NULL for all
#' @param end POSIXct or date string. Latest reading to fetch, default now
#' @param max_active Integer. Retained for compatibility; fetching is now
#'   sequential, which costs little for the incremental windows this handles
#' @param dry_run Logical. Report the plan without fetching
#' @param key Character. API key, for a second ZentraCloud account
#' @return Invisible data frame, one row per device
zentra_download <- function(devices = NULL, end = NULL, max_active = 4L,
                            dry_run = FALSE, key = NULL) {

  if (!requireNamespace("zentraR", quietly = TRUE)) {
    stop("zentraR is not installed", call. = FALSE)
  }

  out_dir <- wds("device_zentra")
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  # The run identifies itself before anything is attempted, so a run that
  # fails before fetching still has an id to log itself under. Same form as
  # the filename stamp and UTC for the same reason - a run can be triggered
  # from anywhere.
  run_started <- Sys.time()
  run_id <- format(run_started, "%Y%m%dT%H%M%S", tz = "UTC")

  cat("\n============================================\n")
  cat("  ZentraCloud download\n")
  if (dry_run) cat("  DRY RUN - nothing will be fetched\n")
  cat("============================================\n\n")

  #### Who exists ####
  known <- tryCatch(
    zentraR::zc_list_devices(expand = "max_min_timestamp", key = key),
    error = function(e) {
      cat("X Could not list devices: ", conditionMessage(e), "\n\n", sep = "")
      NULL
    })
  if (is.null(known)) {
    # Logged even though nothing was attempted. A run that cannot reach the
    # service is precisely the silence a run log exists to break.
    if (!dry_run) {
      zentra_log_run(run_id, run_started, Sys.time(),
                     seen = 0, fetched = 0, current = 0, errored = 0, rows = 0,
                     status = "failed",
                     message = "could not list devices")
    }
    return(invisible(NULL))
  }

  if (!is.null(devices)) known <- known[known$device_id %in% devices, ]

  cat("Devices reachable: ", nrow(known), "\n\n", sep = "")

  #### Where each resumes ####
  plan <- data.frame(
    device_sn = known$device_id,
    name      = known$name,
    api_last  = known$last_measurement,
    stringsAsFactors = FALSE
  )
  plan$from <- as.POSIXct(vapply(plan$device_sn, function(s)
    as.numeric(zentra_last_held(s)), numeric(1)), origin = "1970-01-01", tz = "UTC")

  plan$source <- ifelse(is.na(plan$from), "first measurement", "existing data")
  plan$from[is.na(plan$from)] <-
    known$first_measurement[is.na(plan$from)]

  # Nothing newer than what we hold
  plan$skip <- !is.na(plan$api_last) & !is.na(plan$from) &
               plan$api_last <= plan$from

  for (i in seq_len(nrow(plan))) {
    cat("  ", format(plan$device_sn[i], width = 10),
        format(substr(plan$name[i], 1, 20), width = 21),
        if (plan$skip[i]) "up to date" else
          paste0("from ", format(plan$from[i], "%Y-%m-%d %H:%M"),
                 "  (", plan$source[i], ")"),
        "\n", sep = "")
  }

  todo <- plan[!plan$skip & !is.na(plan$from), ]
  cat("\nTo fetch: ", nrow(todo), " device(s)\n", sep = "")

  if (dry_run || nrow(todo) == 0) {
    if (nrow(todo) > 0) cat("\nRe-run with dry_run = FALSE to fetch.\n\n")
    else cat("\nEverything is up to date.\n\n")

    # A real run where everything was current is a correct outcome and logs as
    # ok. It is distinguishable from a run that fetched nothing because it
    # could not: devices_up_to_date carries the difference.
    if (!dry_run) {
      zentra_log_run(run_id, run_started, Sys.time(),
                     seen = nrow(plan), fetched = 0,
                     current = sum(plan$skip, na.rm = TRUE), errored = 0,
                     rows = 0, status = "ok")
    }
    return(invisible(plan))
  }

  #### Fetch ####
  cat("\n--------------------------------------------\n\n")

  # One stamp for the whole run: the file, its download_log row and the
  # run_log row all carry it, so "which run produced this file" and "what did
  # that run produce" are both answerable.
  fetched_at <- run_started
  stamp <- run_id
  results <- list()

  for (i in seq_len(nrow(todo))) {
    sn <- todo$device_sn[i]

    # A second past the last held reading, so nothing is fetched twice
    from <- todo$from[i] + 1

    # zc_get_readings rather than zc_sync. zc_sync returned nothing for
    # windows where zc_get_readings returned thousands of readings, and it did
    # so SILENTLY - reporting success while fetching nothing. For a job that
    # will run unattended that is disqualifying: the archive would go stale
    # and every run would claim to have worked.
    #
    # Dates are passed as plain "YYYY-MM-DD HH:MM:SS" strings. ZentraCloud
    # compares the timezones of start and end and rejects a mismatch with a
    # 422, so both are formatted the same way from UTC.
    from_str <- format(from, "%Y-%m-%d %H:%M:%S", tz = "UTC")
    end_str  <- format(if (is.null(end)) Sys.time() else as.POSIXct(end),
                       "%Y-%m-%d %H:%M:%S", tz = "UTC")

    data <- tryCatch(
      zentraR::zc_get_readings(device_id = sn, start = from_str, end = end_str,
                               key = key),
      error = function(e) {
        cat("  X ", sn, ": ", conditionMessage(e), "\n", sep = "")
        structure(list(), class = "zentra_fetch_error",
                  message = conditionMessage(e))
      })

    # An error and an empty result are different outcomes. Both fetch nothing,
    # but one means the device has nothing new and the other means we could not
    # ask - and a run log that conflates them would report a broken service as
    # a quiet week.
    if (inherits(data, "zentra_fetch_error")) {
      results[[length(results) + 1]] <- data.frame(
        device_sn = sn, rows = 0L, file = NA_character_,
        errored = TRUE,
        error = paste0(sn, ": ", attr(data, "message")),
        stringsAsFactors = FALSE)
      next
    }

    if (is.null(data) || nrow(data) == 0) {
      cat("  - ", format(sn, width = 10), "nothing new\n", sep = "")
      results[[length(results) + 1]] <- data.frame(
        device_sn = sn, rows = 0L, file = NA_character_,
        errored = FALSE, error = NA_character_,
        stringsAsFactors = FALSE)
      next
    }

    first <- min(data$datetime, na.rm = TRUE)
    last  <- max(data$datetime, na.rm = TRUE)

    fname <- paste0(sn, "_",
                    format(first, "%Y%m%d"), "_",
                    format(last,  "%Y%m%d"), "_",
                    stamp, "_raw.rds")

    saveRDS(data, file.path(out_dir, fname))

    zentra_log_download(sn, first, last, nrow(data), fname, fetched_at, run_id)

    cat("  + ", format(sn, width = 10),
        format(nrow(data), width = 8, big.mark = ","), " rows   ",
        format(first, "%Y-%m-%d"), " to ", format(last, "%Y-%m-%d"), "\n",
        sep = "")

    results[[length(results) + 1]] <- data.frame(
      device_sn = sn, rows = nrow(data), file = fname,
      errored = FALSE, error = NA_character_,
      stringsAsFactors = FALSE)
  }

  res <- do.call(rbind, results)

  cat("\n--------------------------------------------\n")
  cat("Fetched ", format(sum(res$rows), big.mark = ","), " reading(s) across ",
      sum(res$rows > 0), " device(s)\n\n", sep = "")

  n_errored <- sum(res$errored, na.rm = TRUE)
  status <- if (n_errored == 0) "ok" else "partial"

  if (n_errored > 0) {
    cat(n_errored, " device(s) errored - see run_log.csv\n\n", sep = "")
  }

  zentra_log_run(run_id, run_started, Sys.time(),
                 seen = nrow(plan),
                 fetched = sum(res$rows > 0),
                 current = sum(plan$skip, na.rm = TRUE),
                 errored = n_errored,
                 rows = sum(res$rows),
                 status = status,
                 message = paste(head(res$error[!is.na(res$error)], 2),
                                 collapse = "; "))

  invisible(res)
}


#' Appends a Product 1 download to download_log.csv
#'
#' station is left NA: a Product 1 download is not attributed to one, and
#' guessing here would bake in exactly the kind of assumption that Product 1
#' exists to avoid.
#'
#' @param device_sn,first,last,n,fname,fetched_at Download details
#' @return Invisible TRUE
zentra_log_download <- function(device_sn, first, last, n, fname, fetched_at,
                                run_id = NA_character_) {

  log_file <- file.path(wds("meta_internal"), "download_log.csv")

  rel <- sub(paste0("^", gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT")), "/?"),
             "", gsub("\\\\", "/", file.path(wds("device_zentra"), fname)))

  # Two timezones, deliberately. A reading belongs to a place with a recorded
  # timezone, so start and end are project-local and match what the HOBO path
  # writes. A run timestamp belongs to a moment and could be triggered from
  # anywhere, so it is UTC - and the column is named for it.
  project_tz <- tryCatch({
    m <- load_zentra_metadata()
    tz <- m$timezone[!is.na(m$timezone)][1]
    if (is.na(tz) || !nzchar(tz)) "America/Puerto_Rico" else tz
  }, error = function(e) "America/Puerto_Rico")

  entry <- data.frame(
    timestamp_utc = format(fetched_at, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    run_id        = run_id,
    station       = NA_character_,
    device_serial = device_sn,
    start_date    = format(first, "%Y-%m-%d %H:%M:%S", tz = project_tz),
    end_date      = format(last,  "%Y-%m-%d %H:%M:%S", tz = project_tz),
    n_records     = n,
    filepath      = rel,
    download_type = "automatic",
    stringsAsFactors = FALSE
  )

  if (!file.exists(log_file)) {
    write.csv(entry, log_file, row.names = FALSE)
    return(invisible(TRUE))
  }

  existing <- read.csv(log_file, stringsAsFactors = FALSE)
  new_cols <- setdiff(names(entry), names(existing))

  # As in zentra_log_run(): a column the file lacks means the schema grew, and
  # an append cannot carry it. Rewriting is the only way the value survives.
  if (length(new_cols) > 0) {
    for (col in new_cols) existing[[col]] <- NA
    for (col in setdiff(names(existing), names(entry))) entry[[col]] <- NA
    entry <- entry[, names(existing), drop = FALSE]
    write.csv(rbind(existing, entry), log_file, row.names = FALSE)
    return(invisible(TRUE))
  }

  for (col in setdiff(names(existing), names(entry))) entry[[col]] <- NA
  entry <- entry[, names(existing), drop = FALSE]
  write.table(entry, log_file, sep = ",", append = TRUE,
              row.names = FALSE, col.names = FALSE, qmethod = "double")

  invisible(TRUE)
}


#' Appends one row per invocation to run_log.csv
#'
#' download_log records what was FETCHED. A run that fetched nothing leaves no
#' row there at all - which is exactly the failure worth catching, since a job
#' that silently stops working looks identical to a quiet week.
#'
#' This records that the run happened, whatever it found. `devices_seen` is
#' worth as much as the rest: if it drops from 27 to 23 one week, something
#' changed in the account and nothing else would say so.
#'
#' @param run_id,started,finished Identify the run
#' @param seen,fetched,current,errored Device counts
#' @param rows Readings fetched
#' @param status "ok", "partial" or "failed"
#' @param message First error, or blank
#' @return Invisible TRUE
zentra_log_run <- function(run_id, started, finished, seen, fetched, current,
                           errored, rows, status, message = "") {

  log_file <- file.path(wds("meta_internal"), "run_log.csv")

  entry <- data.frame(
    run_id             = run_id,
    started_utc        = format(started,  "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    finished_utc       = format(finished, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    job                = "zentra_download",
    # Which computer ran it. One machine is meant to hold the scheduled job;
    # two hostnames alternating in this column is the quickest way to notice
    # that a task was installed somewhere and never removed.
    machine            = unname(Sys.info()[["nodename"]]),
    devices_seen       = seen,
    devices_fetched    = fetched,
    devices_up_to_date = current,
    devices_errored    = errored,
    rows_fetched       = rows,
    status             = status,
    message            = substr(message, 1, 300),
    stringsAsFactors   = FALSE
  )

  if (!file.exists(log_file)) {
    write.csv(entry, log_file, row.names = FALSE)
    return(invisible(TRUE))
  }

  existing <- read.csv(log_file, stringsAsFactors = FALSE)

  # A column the entry has and the file does not means the schema grew. A
  # plain append cannot carry it - the row would be reshaped to the old header
  # and the new value dropped, silently, every run. So the file is rewritten
  # wide enough to hold it, with the older rows blank in that column.
  new_cols <- setdiff(names(entry), names(existing))

  if (length(new_cols) > 0) {
    for (col in new_cols) existing[[col]] <- NA
    for (col in setdiff(names(existing), names(entry))) entry[[col]] <- NA
    entry <- entry[, names(existing), drop = FALSE]
    write.csv(rbind(existing, entry), log_file, row.names = FALSE)
    return(invisible(TRUE))
  }

  # Same shape - append, which is cheaper and leaves the existing rows alone
  for (col in setdiff(names(existing), names(entry))) entry[[col]] <- NA
  entry <- entry[, names(existing), drop = FALSE]
  write.table(entry, log_file, sep = ",", append = TRUE,
              row.names = FALSE, col.names = FALSE, qmethod = "double")

  invisible(TRUE)
}
