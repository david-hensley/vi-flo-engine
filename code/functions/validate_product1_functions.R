# VI-FLO: validating the Product 1 archive
#
# `validate_metadata()` checks that the records agree with each other. This
# checks that the DATA agrees with the records - that every file reads back,
# holds what its log row claims, and contains measurements rather than a parse
# that went quietly wrong.
#
# Worth running before any Product 2 regeneration, not only once: a file that
# cannot be read, or that holds a column of text where numbers should be, is
# invisible until something downstream trips over it.
#
# It reads every file, so it takes a minute or two.


#' Check the Product 1 archive against the download log
#'
#' @param verbose Logical. Print progress and per-check results (default TRUE)
#' @param detail Logical. List every affected file rather than a count
#'   (default FALSE)
#' @param device_type One of "all", "hobo", "zentra" (default "all")
#' @return Invisible list with summary, violations and a per-file table
validate_product1 <- function(verbose = TRUE, detail = FALSE,
                              device_type = "all") {

  TZ <- "America/Puerto_Rico"
  violations <- list(); passes <- character(0)

  record_violation <- function(code, description, data = NULL) {
    violations[[code]] <<- list(description = description, data = data)
    if (verbose) cat("  X", code, "-", description, "\n")
  }
  record_pass <- function(what) {
    passes <<- c(passes, what)
    if (verbose) cat("  +", what, "\n")
  }

  if (verbose) {
    cat("\n=== VI-FLO Product 1 Validation ===\n\n")
    cat("Reading the archive...\n")
  }

  dlog <- tryCatch(load_download_log(), error = function(e) NULL)
  if (is.null(dlog) || nrow(dlog) == 0) {
    cat("X Could not read the download log.\n\n"); return(invisible(NULL))
  }

  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")

  rows <- dlog
  if (device_type == "hobo")   rows <- rows[grepl("hobo",   rows$filepath), ]
  if (device_type == "zentra") rows <- rows[grepl("zentra", rows$filepath), ]
  rows <- rows[grepl("\\.rds$", rows$filepath), ]

  if (nrow(rows) == 0) {
    cat("X No Product 1 rows of that kind.\n\n"); return(invisible(NULL))
  }

  #### Read every file once, recording what it actually holds ####
  seen <- data.frame()
  unreadable <- data.frame()

  for (i in seq_len(nrow(rows))) {
    rel <- as.character(rows$filepath[i])
    abs <- file.path(data_root, rel)
    fn  <- basename(rel)

    if (!file.exists(abs)) next    # validate_metadata() already reports these

    d <- tryCatch(readRDS(abs), error = function(e) NULL)
    if (is.null(d) || !is.data.frame(d) || nrow(d) == 0) {
      unreadable <- rbind(unreadable, data.frame(
        file = fn, why = if (is.null(d)) "readRDS failed"
                         else if (!is.data.frame(d)) "not a data frame"
                         else "no rows", stringsAsFactors = FALSE))
      next
    }

    #### The datetime column, whatever shape the file is ####
    #
    # Three shapes reach Product 1. A HOBOware U20 export keeps its original
    # headers, "Date Time, GMT-04:00" among them. A HOBOlink export is given
    # tidy names when imported, with a parsed `datetime`. A Zentra file
    # arrives tidy from the API. None of them should be assumed.
    # In PRIORITY order, not column order. grep() returns matches in the order
    # the COLUMNS appear, so taking the first match picks whichever candidate
    # happens to sit leftmost. A Zentra file carries timestamp_local as
    # character in column 8 and timestamp_utc as a parsed POSIXct in column
    # 11; the first match is the string, and reaching past a parsed datetime
    # to misparse a string is how one file came to report the year 12.
    dt_col <- NA_integer_
    for (pat in c("^timestamp_utc$", "^datetime$", "^timestamp_local$",
                  "date.*time", "^date$", "timestamp")) {
      hit <- grep(pat, names(d), ignore.case = TRUE)
      if (length(hit) > 0) { dt_col <- hit[1]; break }
    }

    when <- NULL
    if (!is.na(dt_col)) {
      v <- d[[dt_col]]
      # tryCatch, not suppressWarnings: as.POSIXct() on a string it cannot
      # read ERRORS rather than returning NA, and an unreadable timestamp is
      # exactly what this function exists to find. A check that dies on the
      # first bad file reports nothing about the rest.
      try_parse <- function(x, ...) tryCatch(
        suppressWarnings(as.POSIXct(x, ...)),
        error = function(e) rep(as.POSIXct(NA), length(x)))

      when <- if (inherits(v, "POSIXct")) v else try_parse(v, tz = TZ)

      if (all(is.na(when)) && is.character(v)) {
        for (f in c("%m/%d/%y %I:%M:%S %p", "%m/%d/%Y %H:%M:%S",
                    "%m/%d/%y %H:%M:%S", "%Y-%m-%d %H:%M:%S",
                    "%m/%d/%Y %H:%M", "%m/%d/%y %H:%M")) {
          when <- try_parse(v, format = f, tz = TZ)
          if (!all(is.na(when))) break
        }
      }
    }

    #### Columns that hold measurements ####
    num_cols <- names(d)[vapply(d, function(x)
      is.numeric(x) || (is.character(x) &&
        mean(!is.na(suppressWarnings(as.numeric(x)))) > 0.9), logical(1))]
    num_cols <- setdiff(num_cols, names(d)[dt_col])
    num_cols <- num_cols[!grepl("^#$|^line_no$|^no\\.?$|^index$",
                                num_cols, ignore.case = TRUE)]

    good <- if (is.null(when)) logical(0) else !is.na(when)

    seen <- rbind(seen, data.frame(
      file       = fn,
      serial     = as.character(rows$device_serial[i]),
      logged_n   = suppressWarnings(as.integer(rows$n_records[i])),
      actual_n   = nrow(d),
      # Distinct timestamps, which is NOT the same as rows. A Zentra file is
      # long format - one row per port per timestamp - so 24,795 rows can be
      # 1,066 timestamps across 23 port-variables. Both numbers mean
      # something; n_records in the log is rows, so that is what gets
      # compared.
      stamps     = length(unique(when[good])),
      rows_in_f  = nrow(d),
      has_dt     = !is.na(dt_col),
      parsed     = length(good) > 0 && any(good),
      has_tz     = !is.null(when) && nzchar(
                     attr(when, "tzone") %||% ""),
      n_measures = length(num_cols),
      # In PROJECT LOCAL, because that is what the log holds. Without tz,
      # format() uses whatever zone the file carries - a reading at 00:30 UTC
      # then reads as the following day and disagrees with a log row that is
      # perfectly correct.
      first      = if (any(good)) format(min(when[good]), "%Y-%m-%d", tz = TZ) else NA,
      last       = if (any(good)) format(max(when[good]), "%Y-%m-%d", tz = TZ) else NA,
      log_first  = tryCatch(format(as.Date(rows$start_date[i], tz = TZ)),
                            error = function(e) NA_character_),
      log_last   = tryCatch(format(as.Date(rows$end_date[i], tz = TZ)),
                            error = function(e) NA_character_),
      stringsAsFactors = FALSE))
  }

  if (verbose) cat("  read", nrow(seen), "file(s)\n\n")

  show <- function(df, cols) if (detail) df[, cols, drop = FALSE] else
    head(df[, cols, drop = FALSE], 10)

  #### 1. Every file reads back ####
  if (verbose) cat("Checking the files...\n")
  if (nrow(unreadable) > 0) {
    record_violation("UNREADABLE_PRODUCT1_FILE",
      paste(nrow(unreadable), "file(s) could not be read"), unreadable)
  } else record_pass("every file reads back")

  #### 2. Every file has a datetime column that parses ####
  no_dt <- seen[!seen$has_dt, ]
  if (nrow(no_dt) > 0) {
    record_violation("NO_DATETIME_COLUMN",
      paste(nrow(no_dt), "file(s) have no datetime column"),
      show(no_dt, c("file", "serial")))
  } else record_pass("every file has a datetime column")

  unparsed <- seen[seen$has_dt & !seen$parsed, ]
  if (nrow(unparsed) > 0) {
    record_violation("TIMESTAMPS_UNPARSEABLE",
      paste(nrow(unparsed), "file(s) have timestamps that do not parse"),
      show(unparsed, c("file", "serial", "rows_in_f")))
  } else record_pass("timestamps parse")

  #### 3. A timestamp without a zone is ambiguous ####
  #
  # A POSIXct with no tzone attribute is read in whatever zone the session
  # happens to be in. The same file then means different things on two
  # machines, which is the kind of error that never announces itself.
  no_tz <- seen[seen$parsed & !seen$has_tz, ]
  if (nrow(no_tz) > 0) {
    record_violation("TIMESTAMPS_WITHOUT_ZONE",
      paste(nrow(no_tz), "file(s) hold timestamps with no timezone"),
      show(no_tz, c("file", "serial")))
  } else record_pass("timestamps carry a timezone")

  #### 4. The file holds what the log says it holds ####
  #
  # Counted on DISTINCT timestamps, which is what the log records. A file
  # whose count has drifted from its row means one of the two was written
  # from something other than the other.
  miscount <- seen[!is.na(seen$logged_n) & !is.na(seen$actual_n) &
                   seen$logged_n != seen$actual_n, ]
  if (nrow(miscount) > 0) {
    miscount$difference <- miscount$actual_n - miscount$logged_n
    record_violation("READING_COUNT_MISMATCH",
      paste(nrow(miscount), "file(s) hold a different number of rows than logged"),
      show(miscount, c("file", "serial", "logged_n", "actual_n", "stamps",
                       "difference")))
  } else record_pass("row counts match the log")

  span_off <- seen[seen$parsed & !is.na(seen$log_first) & !is.na(seen$log_last) &
                   (seen$first != seen$log_first | seen$last != seen$log_last), ]
  if (nrow(span_off) > 0) {
    record_violation("SPAN_MISMATCH",
      paste(nrow(span_off), "file(s) span different dates than logged"),
      show(span_off, c("file", "first", "log_first", "last", "log_last")))
  } else record_pass("spans match the log")

  #### 5. A file with no measurements is a parse that went wrong ####
  #
  # Timestamps and nothing else means the measurement columns came back as
  # text, or the header was misread. The file looks healthy by every other
  # test and carries nothing usable.
  empty <- seen[seen$n_measures == 0, ]
  if (nrow(empty) > 0) {
    record_violation("NO_MEASUREMENT_COLUMNS",
      paste(nrow(empty), "file(s) hold timestamps but no numeric measurements"),
      show(empty, c("file", "serial", "rows_in_f")))
  } else record_pass("every file holds measurements")

  #### 6. Time runs forward ####
  backwards <- seen[seen$parsed & !is.na(seen$first) & !is.na(seen$last) &
                    seen$first > seen$last, ]
  if (nrow(backwards) > 0) {
    record_violation("SPAN_REVERSED",
      paste(nrow(backwards), "file(s) end before they begin"),
      show(backwards, c("file", "first", "last")))
  } else record_pass("time runs forward")

  #### Summary ####
  n_checks <- length(passes) + length(violations)
  summary <- if (length(violations) == 0)
    paste0("Product 1 OK: ", n_checks, "/", n_checks, " checks passed across ",
           nrow(seen), " file(s)")
  else
    paste0("Product 1 FAILED: ", length(passes), "/", n_checks,
           " checks passed, ", length(violations), " violation(s)")

  if (verbose) {
    cat("\n=== Summary ===\n")
    cat(nrow(seen), "file(s),",
        format(sum(seen$actual_n, na.rm = TRUE), big.mark = ","), "rows,",
        format(sum(seen$stamps, na.rm = TRUE), big.mark = ","),
        "distinct timestamps\n")
    cat("Checks passed:", length(passes), "/", n_checks, "\n")
    if (length(violations) > 0) {
      cat("Violations:", length(violations), "\n")
      if (!detail)
        cat("\nRe-run with detail = TRUE to list every affected file.\n")
    }
    cat("\n", summary, "\n\n", sep = "")
  }

  invisible(list(summary = summary, violations = violations,
                 passes = passes, files = seen))
}


#' Per-device coverage, for comparing the archive against its dossiers
#'
#' @param device_serial Character. One serial, or NULL for all
#' @return Invisible data frame of coverage
product1_coverage <- function(device_serial = NULL) {

  TZ <- "America/Puerto_Rico"
  dlog <- load_download_log()
  dlog <- dlog[grepl("\\.rds$", dlog$filepath), ]
  if (!is.null(device_serial))
    dlog <- dlog[dlog$device_serial %in% device_serial, ]
  if (nrow(dlog) == 0) { cat("Nothing held for that device.\n"); return(invisible(NULL)) }

  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)

  out <- data.frame()
  for (sn in sort(unique(dlog$device_serial))) {
    mine <- dlog[dlog$device_serial == sn, ]
    a <- tryCatch(suppressWarnings(as.POSIXct(mine$start_date, tz = TZ)),
                  error = function(e) as.POSIXct(character(0)))
    b <- tryCatch(suppressWarnings(as.POSIXct(mine$end_date, tz = TZ)),
                  error = function(e) as.POSIXct(character(0)))
    a <- a[!is.na(a)]; b <- b[!is.na(b)]
    if (!length(a)) next

    # A gap over twelve hours between one file ending and the next beginning
    ord <- order(a); a <- a[ord]; b <- b[ord]
    gaps <- 0
    if (length(a) > 1)
      gaps <- sum(as.numeric(difftime(a[-1], b[-length(b)], units = "hours")) > 12)

    stations <- if (!is.null(meta))
      paste(unique(meta$station_id[meta$device_serial == sn]), collapse = ", ")
    else ""

    out <- rbind(out, data.frame(
      serial   = sn,
      station  = if (nzchar(stations)) stations else "(unattributed)",
      files    = nrow(mine),
      from     = format(min(a), "%Y-%m-%d"),
      to       = format(max(b), "%Y-%m-%d"),
      readings = sum(suppressWarnings(as.integer(mine$n_records)), na.rm = TRUE),
      gaps     = gaps,
      stringsAsFactors = FALSE))
  }

  print(out, row.names = FALSE)
  cat("\n", nrow(out), " device(s), ",
      format(sum(out$readings), big.mark = ","), " readings\n",
      "gaps counts breaks over twelve hours between consecutive files\n\n",
      sep = "")
  invisible(out)
}


`%||%` <- function(a, b) if (is.null(a)) b else a
