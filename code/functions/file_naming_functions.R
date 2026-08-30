################################################################################
#                          RAW FILE NAMING FUNCTIONS                           #
#                                                                              #
# Single source of truth for the naming of raw data files, used by BOTH the    #
# automated API download path and the manual/local ingest path so the two      #
# cannot drift apart.                                                          #
#                                                                              #
# Convention: {station}_{YYYYMMDD}_{YYYYMMDD}_raw.{ext}                        #
# Example:    sr1_hydro_20260101_20260401_raw.rds                              #
#                                                                              #
# Requires: wds() from setup_functions.R                                       #
################################################################################

#' Coerce a datetime to POSIXct, tolerating Excel damage
#'
#' Raw data reaches us as text files that someone may well have opened in
#' Excel "just to look" - which silently rewrites datetimes into whatever the
#' machine locale prefers, or into a numeric serial. This accepts POSIXct,
#' Date, character in any of the formats parse_datetime_flexible() knows, or
#' an Excel serial number.
#'
#' @param x POSIXct, Date, character, or numeric (Excel serial)
#' @param tz Character. Timezone. Defaults to the timezone in device_metadata.
#' @return POSIXct
coerce_datetime_flexible <- function(x, tz = NULL) {

  if (inherits(x, "POSIXct")) return(x)
  if (inherits(x, "Date"))    return(as.POSIXct(format(x), tz = ifelse(is.null(tz), "", tz)))

  if (is.null(tz)) {
    metadata <- load_zentra_metadata()
    tz <- metadata$timezone[1]
  }

  # Excel serial: days since 1899-12-30. Anything in a plausible range is
  # almost certainly a mangled date rather than a genuine number.
  if (is.numeric(x)) {
    if (all(x > 20000 & x < 80000, na.rm = TRUE)) {
      return(as.POSIXct(x * 86400, origin = "1899-12-30", tz = tz))
    }
    stop("Numeric value ", x[1], " is not a plausible Excel date serial.",
         call. = FALSE)
  }

  parsed <- parse_datetime_flexible(as.character(x), tz)

  # parse_datetime_flexible() only knows formats carrying a time component.
  # For bare dates ("2025-06-01", "6/1/2025") fall through to the codebase's
  # date-only parser rather than duplicating its format list here.
  still_na <- is.na(parsed) & !is.na(x) & nzchar(as.character(x))
  if (any(still_na)) {
    as_date <- parse_date_flexible(as.character(x)[still_na])
    ok <- !is.na(as_date)
    if (any(ok)) {
      parsed[still_na][ok] <- as.POSIXct(format(as_date[ok]), tz = tz)
    }
  }

  # %Y silently accepts a two-digit year and takes it literally, so
  # "03/02/26" parses as the year 26 AD. HOBOware's default export format is
  # MM/DD/YY, so this would otherwise corrupt every logger file we ingest.
  # Detect implausible years and re-parse with two-digit-year formats.
  yrs <- as.numeric(format(parsed, "%Y"))
  if (any(!is.na(yrs) & (yrs < 1970 | yrs > 2100))) {
    two_digit_formats <- c(
      "%m/%d/%y %I:%M:%S %p",
      "%m/%d/%y %H:%M:%S",
      "%m/%d/%y %I:%M %p",
      "%m/%d/%y %H:%M",
      "%m/%d/%y",
      "%y-%m-%d %H:%M:%S",
      "%d/%m/%y %H:%M:%S"
    )
    for (fmt in two_digit_formats) {
      attempt <- suppressWarnings(
        as.POSIXct(as.character(x), format = fmt, tz = tz)
      )
      att_yrs <- as.numeric(format(attempt, "%Y"))
      # Accept only if it parses at least as much AND yields sane years
      if (sum(!is.na(attempt)) >= sum(!is.na(parsed)) &&
          all(is.na(att_yrs) | (att_yrs >= 1970 & att_yrs <= 2100))) {
        parsed <- attempt
        break
      }
    }
  }

  # Final guard: never hand back a date that cannot be real. Silently wrong
  # dates are far more damaging than a refusal, because they propagate into
  # filenames and the download log.
  yrs <- as.numeric(format(parsed, "%Y"))
  bad <- !is.na(yrs) & (yrs < 1970 | yrs > 2100)
  if (any(bad)) {
    stop("Parsed an implausible date (year ", yrs[which(bad)[1]], ") from '",
         as.character(x)[which(bad)[1]], "'. The date format in this file was ",
         "not recognised - check whether it uses an unusual layout.",
         call. = FALSE)
  }

  if (any(is.na(parsed))) {
    stop("Could not parse datetime: '", as.character(x)[which(is.na(parsed))[1]],
         "'. Expected a date (2026-01-31) or datetime (2026-01-31 14:30:00). ",
         "If this file was opened in Excel, the format may have been altered.",
         call. = FALSE)
  }

  parsed
}


#' Build a raw data filename from a station and a date range
#'
#' The dates are a plain truncation of the actual first and last records in the
#' file. Consecutive files for the same station WILL share a boundary date -
#' a logger keeps recording after an offload, so the next file starts on the
#' day the last one ended. That is expected, and it is why overlap is checked
#' against the exact timestamps in download_log rather than these truncated
#' dates. The filename describes the file's contents honestly; genuine
#' duplicate records are resolved at processing by deduplicating on timestamp,
#' not by distorting the filename.
#'
#' A device_serial may be supplied, and must be for anything manually ingested.
#' A paired stream gauge has two loggers at ONE station, so a station-level name
#' cannot distinguish their files - the second would silently overwrite the
#' first. The SERIAL is used rather than the device name because names change:
#' put a mutable thing in a filename and historic files stop matching the
#' moment someone relabels a logger.
#'
#' API downloads pass no serial and keep station-level names, correctly - a
#' Zentra station has one active device and the API collates across
#' replacements.
#'
#' @param station Character. Station ID e.g. "sr1_hydro"
#' @param start POSIXct, Date, character or Excel serial. First record
#' @param end POSIXct, Date, character or Excel serial. Last record
#' @param ext Character. File extension without the dot (default "rds")
#' @param tz Character. Timezone for parsing text dates (default: from metadata)
#' @param device_serial Character. Included in the name when supplied
#' @return Character. The filename
#' @examples
#' \dontrun{
#' build_raw_filename("sr1_hydro", as.POSIXct("2026-01-01"), as.POSIXct("2026-04-01"))
#' # "sr1_hydro_20260101_20260401_raw.rds"
#' }
build_raw_filename <- function(station, start, end, ext = "rds", tz = NULL,
                               device_serial = NULL) {

  if (is.null(station) || is.na(station) || !nzchar(station)) {
    stop("station must be a non-empty character string", call. = FALSE)
  }
  if (is.null(start) || is.null(end) || any(is.na(c(start, end)))) {
    stop("start and end must both be supplied and non-NA", call. = FALSE)
  }

  start <- coerce_datetime_flexible(start, tz)
  end   <- coerce_datetime_flexible(end,   tz)

  if (end < start) {
    stop("end (", format(end, "%Y-%m-%d"), ") is before start (",
         format(start, "%Y-%m-%d"), ")", call. = FALSE)
  }

  ext <- sub("^\\.", "", ext)  # tolerate ".rds" being passed

  stem <- station
  if (!is.null(device_serial) && !is.na(device_serial) &&
      nzchar(trimws(device_serial))) {
    stem <- paste0(station, "_", trimws(device_serial))
  }

  paste0(stem, "_",
         format(start, "%Y%m%d"), "_",
         format(end,   "%Y%m%d"),
         "_raw.", ext)
}


#' Parse a raw data filename back into its components
#'
#' Parses from the right, so station IDs containing underscores (which all of
#' them do - "sr1_hydro", "uvi_vwc2") are handled correctly.
#'
#' @param filename Character. A filename, with or without a leading path
#' @return List with station, start (Date), end (Date), ext - or NULL if the
#'   filename does not match the convention
parse_raw_filename <- function(filename) {

  base <- basename(filename)

  # Must end in _raw.<ext>
  m <- regmatches(base, regexec("^(.*)_raw\\.([A-Za-z0-9]+)$", base))[[1]]
  if (length(m) != 3) return(NULL)

  stem <- m[2]
  ext  <- m[3]

  parts <- strsplit(stem, "_", fixed = TRUE)[[1]]
  if (length(parts) < 3) return(NULL)

  n <- length(parts)
  start_str <- parts[n - 1]
  end_str   <- parts[n]

  # Both date fields must be exactly 8 digits
  if (!grepl("^[0-9]{8}$", start_str) || !grepl("^[0-9]{8}$", end_str)) {
    return(NULL)
  }

  start <- as.Date(start_str, format = "%Y%m%d")
  end   <- as.Date(end_str,   format = "%Y%m%d")
  if (is.na(start) || is.na(end)) return(NULL)

  stem_parts <- parts[1:(n - 2)]
  if (length(stem_parts) == 0) return(NULL)

  # A trailing all-digit segment is a device serial, not part of the station
  # ID - station IDs are always <site>_<type>, never numeric at the end.
  device_serial <- NA_character_
  if (length(stem_parts) > 2 && grepl("^[0-9]+$", stem_parts[length(stem_parts)])) {
    device_serial <- stem_parts[length(stem_parts)]
    stem_parts <- stem_parts[-length(stem_parts)]
  }

  station <- paste(stem_parts, collapse = "_")
  if (!nzchar(station)) return(NULL)

  list(station = station, device_serial = device_serial,
       start = start, end = end, ext = ext)
}


#' List existing raw files for a station, newest coverage last
#'
#' Scans the directory for files matching the naming convention. The files on
#' disk are the ground truth for what has been archived - the download log
#' records intent and provenance, but a file that is not there is not archived.
#'
#' @param station Character. Station ID
#' @param dir Character. Directory to scan. Defaults to the station's raw
#'   directory, resolved from station_type in device_metadata.
#' @return Data frame with filename, start, end - zero rows if none found
list_raw_files <- function(station, dir = NULL) {

  if (is.null(dir)) {
    # Resolve station_type from metadata, NOT by string-munging the station ID.
    # Stripping the last underscore segment gives "hydro" for "sr1_hydro" but
    # "vwc2" for "uvi_vwc2", which is wrong.
    metadata <- load_zentra_metadata()
    station_type <- metadata$station_type[metadata$station_id == station][1]
    if (is.na(station_type)) {
      stop("Station '", station, "' not found in device_metadata - cannot ",
           "resolve its raw data directory.", call. = FALSE)
    }
    dir <- wds(paste0("internal_raw_", station_type))
  }

  empty <- data.frame(filename = character(0),
                      device_serial = character(0),
                      start = as.Date(character(0)),
                      end = as.Date(character(0)),
                      stringsAsFactors = FALSE)

  if (!dir.exists(dir)) return(empty)

  files <- list.files(dir, pattern = "_raw\\.[A-Za-z0-9]+$")
  if (length(files) == 0) return(empty)

  rows <- lapply(files, function(f) {
    p <- parse_raw_filename(f)
    if (is.null(p) || p$station != station) return(NULL)
    data.frame(filename = f, device_serial = p$device_serial,
               start = p$start, end = p$end,
               stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]

  if (length(rows) == 0) return(empty)

  out <- do.call(rbind, rows)
  out[order(out$end, out$start), ]
}


#' Warn if a proposed date range overlaps existing raw files for a station
#'
#' This is deliberately a WARNING, not an error. Boundary-day overlap is
#' normal: a logger downloaded and redeployed the same day produces files that
#' touch. What matters is that the user is told, so that a genuinely wrong date
#' range - a re-download of a period already archived - is visible rather than
#' silent.
#'
#' @param station Character. Station ID
#' @param start POSIXct or Date. Proposed start
#' @param end POSIXct or Date. Proposed end
#' @param dir Character. Directory to scan (default: derived from station_type)
#' @param verbose Logical. Print messages (default TRUE)
#' @param device_serial Character. Restrict the comparison to this device's own
#'   files, so a paired gauge's two loggers do not appear to overlap each other
#' @return List with overlap (logical) and files
#'   (data frame of overlapping files)
check_raw_overlap <- function(station, start, end, dir = NULL, verbose = TRUE,
                              device_serial = NULL) {

  start_dt <- coerce_datetime_flexible(start)
  end_dt   <- coerce_datetime_flexible(end)

  existing <- list_raw_files(station, dir)

  # At a paired gauge both loggers cover the same period by design, so files
  # from the OTHER logger are not an overlap - they are the point. Compare
  # only against this device's own archive. Files with no serial in the name
  # predate that convention and could be from either, so they still count.
  if (!is.null(device_serial) && nrow(existing) > 0) {
    existing <- existing[is.na(existing$device_serial) |
                         existing$device_serial == device_serial, ,
                         drop = FALSE]
  }

  result <- list(overlap = FALSE, files = existing[0, , drop = FALSE])

  if (nrow(existing) == 0) return(result)

  # Filename dates are truncated to the day, so consecutive downloads from one
  # logger ALWAYS appear to touch: the logger keeps recording after an
  # offload, so the new file starts on the day the last one ended. Comparing
  # dates would therefore warn on every download forever, which is noise.
  #
  # download_log holds the exact first and last record timestamps, so use
  # those where available. Then a real overlap - the same records archived
  # twice - is caught precisely, and the ordinary case says nothing at all.
  exact <- tryCatch(load_download_log(), error = function(e) NULL)

  hits <- existing[0, , drop = FALSE]

  for (i in seq_len(nrow(existing))) {
    f <- existing$filename[i]

    file_start <- as.POSIXct(existing$start[i])
    file_end   <- as.POSIXct(existing$end[i]) + 86399  # end of that day

    if (!is.null(exact) && nrow(exact) > 0) {
      match_row <- which(basename(as.character(exact$filepath)) == f)
      if (length(match_row) > 0) {
        file_start <- as.POSIXct(exact$start_date[match_row[1]])
        file_end   <- as.POSIXct(exact$end_date[match_row[1]])
      }
    }

    if (file_start <= end_dt && file_end >= start_dt) {
      hits <- rbind(hits, existing[i, , drop = FALSE])
    }
  }

  if (nrow(hits) == 0) return(result)

  result$overlap <- TRUE
  result$files <- hits

  if (verbose) {
    cat("\n")
    cat("WARNING: This date range overlaps data already archived for\n")
    cat("         station '", station, "':\n", sep = "")
    for (i in seq_len(nrow(hits))) {
      cat("         - ", hits$filename[i], "\n", sep = "")
    }
    cat("         Proposed: ", format(start_dt, "%Y-%m-%d %H:%M"),
        " to ", format(end_dt, "%Y-%m-%d %H:%M"), "\n", sep = "")
    cat("         The same records may be archived twice. Check this is\n")
    cat("         intended before proceeding.\n\n")
  }

  return(result)
}
