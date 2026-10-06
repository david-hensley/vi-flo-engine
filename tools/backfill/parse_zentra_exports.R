# VI-FLO: ZentraCloud export parser
#
# ONE-OFF TOOL, kept for audit rather than reuse.
#
# In September 2026 the full history of every reachable ZL6 was downloaded by
# hand from the ZentraCloud web interface - 26 devices, roughly 2.4 million
# records reaching back to 2021. The API could not practically serve this: its
# rate limit of one call per device per minute put a full backfill at about
# three weeks of continuous running.
#
# This reads those exports and produces one tidy file per device. Anyone can
# re-run it against the same zips and get the same output, which is the point:
# the exports are the source of record, this is how they were read.
#
#     internal/device-data/zentra/backfill/
#         exports/   the zips exactly as downloaded - KEPT PERMANENTLY
#         parsed/    output of this script
#
#
# WHAT THE EXPORT FORMAT REQUIRES
#
# Each zip holds two CSVs per CONFIGURATION - a period during which the
# logger's port layout did not change. ZentraCloud splits on its own record of
# sensors being plugged and unplugged, which makes these files a dated port
# history as well as a data set.
#
#   1. Configuration numbers are NOT chronological. A device's cfg3 may start
#      before its cfg1, because they are numbered as ZentraCloud encountered
#      them rather than in time order.
#
#   2. Each configuration has a DIFFERENT column layout. Port 3 may be a TEROS
#      10 in one and a TEROS 21 in another - different units, different
#      physical quantity. They cannot be combined column-wise, which is why
#      the output is long rather than wide.
#
#   3. Timestamps are local EXCEPT where the logger had no timezone set, which
#      the Raw file records as `UTC Offset = Not Set`. Those are UTC. Read as
#      local they land four hours out and appear to overlap the configuration
#      that follows. Confirmed on z6-13388, where correcting it turns an
#      impossible overlap into a smooth battery decline across an afternoon's
#      installation.
#
#   4. Ports 7 and 8 are the logger's own battery and barometer, not field
#      sensors. Kept, and marked as internal.
#
#   5. Configurations holding a handful of records are installation transients
#      - a sensor being plugged in, a moment of "Unrecognized Sensor". Real,
#      but not measurements. Kept and flagged rather than dropped.
#
#
# OUTPUT
#
# One RDS per device, a data frame in long format:
#
#   device_sn, config, port, port_internal, sensor, measurement, unit,
#   timestamp_local, utc_offset, value
#
# Long rather than wide because configurations differ: a device that changed
# sensors has no single set of columns. Reshaping to wide is one line for
# whoever needs it; recovering what a column meant is not.
#
# Plus a run log naming every file read, its record count, and anything odd.
#
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/backfill/parse_zentra_exports.R"))
#
#   parse_zentra_exports(dry_run = TRUE)   # report what it finds
#   parse_zentra_exports()                 # parse everything not yet done
#   parse_zentra_exports(devices = "z6-13388")


ZENTRA_EXPORT_TZ <- "America/Puerto_Rico"


#' Root of the backfill area
zentra_backfill_root <- function() {
  wds("device_zentra_backfill")
}

zentra_exports_dir <- function() {
  d <- normalizePath(file.path(zentra_backfill_root(), "exports"),
                     mustWork = FALSE)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}

zentra_parsed_dir <- function() {
  d <- normalizePath(file.path(zentra_backfill_root(), "parsed"),
                     mustWork = FALSE)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}


#' Pulls the device serial out of an export filename
#'
#' They look like "All-Fish Bay Weather(z6-13375)-1789418643.zip" - the serial
#' is in parentheses, the label before it is whatever the device was called in
#' ZentraCloud at download time.
#'
#' @param filename Character
#' @return List with sn and label, or NULL if it does not parse
parse_export_filename <- function(filename) {
  m <- regmatches(filename, regexec("^All-(.*)\\((z6-[0-9]+)\\)-", filename))[[1]]
  if (length(m) < 3) return(NULL)
  list(label = m[2], sn = m[3])
}


#' Reads one configuration CSV and its Raw partner
#'
#' The processed file carries converted values; the Raw file carries the UTC
#' offset, which appears nowhere else. They align row for row - verified across
#' all 82 configuration pairs in the September 2026 export - so the offset is
#' taken by position.
#'
#' @param proc_path Character. Path to the processed CSV
#' @param device_sn Character
#' @param config Integer
#' @return Long data frame, or NULL if the file holds no records
read_zentra_config <- function(proc_path, device_sn, config) {

  con <- file(proc_path, encoding = "UTF-8-BOM")
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  lines <- readLines(con, warn = FALSE)
  if (length(lines) < 4) return(NULL)

  split_csv <- function(x) scan(text = x, what = "", sep = ",",
                                quiet = TRUE, strip.white = FALSE)

  ports   <- split_csv(lines[1])
  sensors <- split_csv(lines[2])
  units   <- split_csv(lines[3])

  n_col <- length(ports)
  if (n_col < 2) return(NULL)

  #### The measurement name and unit share row 3 ####
  # " m3/m3 Water Content" is unit then name. The unit is the first token, the
  # measurement the rest - except for columns with no unit at all.
  meas <- character(n_col)
  unit <- character(n_col)
  for (i in seq_len(n_col)) {
    piece <- trimws(units[i])
    parts <- strsplit(piece, "\\s+")[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) <= 1) {
      meas[i] <- piece
      unit[i] <- NA_character_
    } else {
      unit[i] <- parts[1]
      meas[i] <- paste(parts[-1], collapse = " ")
    }
  }

  #### Offsets from the Raw partner ####
  raw_path <- sub("-Configuration ", "-Raw-Configuration ", proc_path, fixed = TRUE)
  offsets <- NA_character_

  if (file.exists(raw_path)) {
    rcon <- file(raw_path, encoding = "UTF-8-BOM")
    rlines <- readLines(rcon, warn = FALSE)
    try(close(rcon), silent = TRUE)
    if (length(rlines) >= 4) {
      rcols <- split_csv(rlines[3])
      oi <- which(trimws(rcols) == "UTC Offset")
      if (length(oi) == 1) {
        offsets <- vapply(rlines[-(1:3)], function(l) {
          p <- split_csv(l)
          if (length(p) >= oi) trimws(p[oi]) else NA_character_
        }, character(1), USE.NAMES = FALSE)
      }
    }
  }

  #### The data ####
  body <- lines[-(1:3)]
  body <- body[nzchar(trimws(body))]
  if (length(body) == 0) return(NULL)

  if (length(offsets) != length(body)) {
    offsets <- rep(NA_character_, length(body))
  }

  vals <- do.call(rbind, lapply(body, function(l) {
    p <- split_csv(l)
    length(p) <- n_col
    p
  }))

  stamps <- vals[, 1]

  #### Long format, one row per measurement ####
  out <- vector("list", n_col - 1)

  for (i in 2:n_col) {
    port_num <- suppressWarnings(as.integer(sub("Port", "", ports[i])))
    out[[i - 1]] <- data.frame(
      device_sn       = device_sn,
      config          = config,
      port            = port_num,
      port_internal   = !is.na(port_num) & port_num >= 7,
      sensor          = trimws(sensors[i]),
      measurement     = meas[i],
      unit            = unit[i],
      timestamp_local = stamps,
      utc_offset      = offsets,
      value           = suppressWarnings(as.numeric(vals[, i])),
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}


#' Parses every export not already done
#'
#' @param devices Character vector of serials, or NULL for all
#' @param dry_run Logical. Report what would be parsed without writing
#' @param overwrite Logical. Re-parse devices already done
#' @return Invisible TRUE
parse_zentra_exports <- function(devices = NULL, dry_run = FALSE,
                                 overwrite = FALSE) {

  exports <- zentra_exports_dir()
  parsed  <- zentra_parsed_dir()

  cat("\n============================================\n")
  cat("  Parse ZentraCloud exports\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("============================================\n\n")
  cat("Exports: ", exports, "\n", sep = "")
  cat("Parsed:  ", parsed, "\n\n", sep = "")

  zips <- list.files(exports, pattern = "\\.zip$", full.names = TRUE)

  if (length(zips) == 0) {
    cat("No zip files found. Put the ZentraCloud exports in:\n  ", exports,
        "\n\n", sep = "")
    return(invisible(FALSE))
  }

  #### Which devices ####
  jobs <- list()
  for (z in zips) {
    info <- parse_export_filename(basename(z))
    if (is.null(info)) {
      cat("  ? Cannot read a serial from: ", basename(z), " - skipping\n", sep = "")
      next
    }
    if (!is.null(devices) && !info$sn %in% devices) next
    jobs[[length(jobs) + 1]] <- list(zip = z, sn = info$sn, label = info$label)
  }

  cat("Exports found: ", length(jobs), "\n", sep = "")

  if (!overwrite) {
    done <- vapply(jobs, function(j)
      file.exists(file.path(parsed, paste0(j$sn, "_parsed.rds"))), logical(1))
    if (any(done)) {
      cat("Already parsed, skipping: ", sum(done), "\n", sep = "")
      jobs <- jobs[!done]
    }
  }

  if (length(jobs) == 0) {
    cat("\nNothing to parse.\n\n")
    return(invisible(TRUE))
  }

  cat("To parse: ", length(jobs), "\n\n", sep = "")

  if (dry_run) {
    for (j in jobs) cat("  ", j$sn, "  (", j$label, ")\n", sep = "")
    cat("\nRe-run without dry_run to parse.\n\n")
    return(invisible(TRUE))
  }

  log_rows <- list()
  tmp_root <- file.path(tempdir(), "zentra_parse")

  for (j in jobs) {

    cat("--- ", j$sn, "  (", j$label, ")\n", sep = "")

    tmp <- file.path(tmp_root, j$sn)
    unlink(tmp, recursive = TRUE)
    dir.create(tmp, recursive = TRUE)
    utils::unzip(j$zip, exdir = tmp)

    csvs <- list.files(tmp, pattern = "\\.csv$", full.names = TRUE)
    procs <- csvs[!grepl("-Raw-Configuration ", basename(csvs), fixed = TRUE)]

    if (length(procs) == 0) {
      cat("    no configuration files inside - skipping\n")
      next
    }

    pieces <- list()

    for (p in procs) {
      cfg <- suppressWarnings(as.integer(
        sub(".*-Configuration ([0-9]+)-.*", "\\1", basename(p))))

      df <- tryCatch(read_zentra_config(p, j$sn, cfg),
                     error = function(e) {
                       cat("    ! cfg", cfg, ": ", conditionMessage(e), "\n", sep = "")
                       NULL
                     })

      n_stamps <- if (is.null(df)) 0 else length(unique(df$timestamp_local))
      offs <- if (is.null(df)) character(0) else unique(df$utc_offset)

      log_rows[[length(log_rows) + 1]] <- data.frame(
        device_sn = j$sn, label = j$label, config = cfg,
        file = basename(p), records = n_stamps,
        rows_long = if (is.null(df)) 0 else nrow(df),
        offsets = paste(offs, collapse = "|"),
        stringsAsFactors = FALSE
      )

      if (!is.null(df)) pieces[[length(pieces) + 1]] <- df

      cat("    cfg", cfg, ": ", format(n_stamps, big.mark = ","),
          " records", if (length(offs) > 1) "  [mixed offsets]" else "", "\n",
          sep = "")
    }

    if (length(pieces) == 0) {
      cat("    nothing parsed\n")
      next
    }

    all_df <- do.call(rbind, pieces)

    #### Absolute time ####
    # Local timestamps where an offset is set; UTC where it is "Not Set".
    # Doing this here rather than downstream means every consumer gets an
    # unambiguous instant without having to know the rule.
    parsed_local <- as.POSIXct(all_df$timestamp_local,
                               format = "%m/%d/%Y %I:%M:%S %p",
                               tz = "UTC")

    off_hours <- suppressWarnings(as.numeric(
      sub("^UTC([+-][0-9]{2}):.*$", "\\1", all_df$utc_offset)))
    off_hours[is.na(off_hours)] <- 0   # "Not Set" means the stamp is UTC

    all_df$timestamp_utc <- parsed_local - off_hours * 3600
    all_df$offset_known <- !is.na(all_df$utc_offset) &
                           all_df$utc_offset != "Not Set"

    saveRDS(all_df, file.path(parsed, paste0(j$sn, "_parsed.rds")))

    cat("    -> ", j$sn, "_parsed.rds  (",
        format(nrow(all_df), big.mark = ","), " rows, ",
        format(length(unique(all_df$timestamp_utc)), big.mark = ","),
        " timestamps)\n", sep = "")

    unlink(tmp, recursive = TRUE)
  }

  #### Run log ####
  if (length(log_rows) > 0) {
    log_df <- do.call(rbind, log_rows)
    log_path <- file.path(parsed, "parse_log.csv")
    if (file.exists(log_path)) {
      old <- read.csv(log_path, stringsAsFactors = FALSE)
      log_df <- rbind(old, log_df)
    }
    write.csv(log_df, log_path, row.names = FALSE)
    cat("\nRun log: ", log_path, "\n", sep = "")
  }

  cat("\nDone.\n\n")
  invisible(TRUE)
}
