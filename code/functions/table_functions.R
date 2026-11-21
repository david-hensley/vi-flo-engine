################################################################################
#                           TABLE FUNCTIONS                                    #
#                                                                              #
# The one way into and out of the metadata tables.                             #
#                                                                              #
# Every table in metadata/internal is described once, below, in TABLE_SCHEMA:  #
# its columns in order, each column's type, its key, and who writes it. Three  #
# functions read the schema and do everything else:                            #
#                                                                              #
#   read_table(name)          the table, its columns typed                     #
#   write_table(name, data)   the whole table, replaced                        #
#   append_rows(name, rows)   rows added to the end of a log                   #
#                                                                              #
# Nothing else should open a metadata file. Before this layer, each function   #
# that needed a table read and wrote it itself, choosing its own folder, date  #
# format, quoting and missing-value marker. Most choices were right; each was  #
# a separate chance to be wrong, and when one was, only that path broke,       #
# usually silently - a port deletion written to the working directory, a log  #
# row appended by position into the wrong columns.                             #
#                                                                              #
# How a table is written, always:                                              #
#                                                                              #
#   - columns in schema order, and only the schema's columns                   #
#   - text quoted, with a quote inside a value doubled; numbers and TRUE/FALSE #
#     bare                                                                     #
#   - a missing value written as nothing at all - an empty cell. Unknown is    #
#     blank, never "NA"                                                        #
#   - local datetimes as YYYY-MM-DD HH:MM:SS in the project time zone; UTC     #
#     datetimes the same, in UTC; dates as YYYY-MM-DD                          #
#   - numbers in full, never in scientific notation                            #
#   - Unix line endings, so every machine writes identical bytes               #
#                                                                              #
# The schema moves to v2.9's, described in data/DATA_DICTIONARY.md, one table  #
# at a time - each by a migration in tools/migrations.                         #
#                                                                              #
# Requires: wds() from setup_functions.R; remember_file_hash(),                #
#           remembered_file_hash() and report_write_conflict() from            #
#           guard_functions.R; parse_datetime_flexible() and                   #
#           parse_date_flexible() from setup_functions.R                       #
################################################################################


#### The schema ####

PROJECT_TZ <- "America/Puerto_Rico"

# Column types:
#
#   text            character, quoted
#   integer         a whole number - a count, a port - bare
#   number          numeric, bare
#   logical         TRUE/FALSE, bare
#   date            a calendar date, YYYY-MM-DD
#   datetime_local  a field time, in the project time zone
#   datetime_utc    when something was written, in UTC
#
# writer: "person" (through the metadata manager), "machine" (the job, an
# ingest), or "both" - which v2.9 ends.
TABLE_SCHEMA <- list(

  device_metadata = list(
    file = "device_metadata.csv", key = "unique_id", writer = "person",
    columns = c(
      unique_id = "text", watershed = "text", area = "text", site_full = "text",
      site = "text", station_type = "text", station_id = "text",
      device_serial = "text", device_role = "text", device_name = "text",
      mfger = "text", model = "text", lat = "number", lon = "number",
      elev = "number", elev_source = "text",
      interval_min = "integer", timezone = "text",
      deploy_datetime = "datetime_local", end_datetime = "datetime_local",
      status = "text", last_visit = "date", metadata_approved = "logical",
      last_reviewed_utc = "datetime_utc"
    )
  ),

  zentra_ports = list(
    file = "zentra_ports.csv", key = NULL, writer = "person",
    columns = c(
      unique_id = "text", port = "integer", sensor = "text",
      depth_cm = "number", status = "text",
      valid_from = "datetime_local", valid_to = "datetime_local"
    )
  ),

  maintenance_log = list(
    file = "maintenance_log.csv", key = NULL, writer = "person",
    columns = c(
      logged_utc = "datetime_utc", field_visit_date = "date",
      station_id = "text", unique_id = "text", action_type = "text",
      details = "text", logged_by = "text"
    )
  ),

  download_log = list(
    file = "download_log.csv", key = "filepath", writer = "machine",
    columns = c(
      timestamp_utc = "datetime_utc", run_id = "text",
      device_serial = "text", start_date = "datetime_local",
      end_date = "datetime_local", n_records = "integer", filepath = "text",
      download_type = "text", battery = "number"
    )
  ),

  run_log = list(
    file = "run_log.csv", key = "run_id", writer = "machine",
    columns = c(
      run_id = "text", started_utc = "datetime_utc", finished_utc = "datetime_utc",
      job = "text", devices_seen = "integer", devices_fetched = "integer",
      devices_up_to_date = "integer", devices_errored = "integer",
      rows_fetched = "integer", status = "text", message = "text",
      machine = "text"
    )
  ),

  known_unattributed = list(
    file = "known_unattributed.csv", key = NULL, writer = "person",
    columns = c(
      device_serial = "text", device_name = "text", port = "integer",
      from = "datetime_local", to = "datetime_local", reason = "text"
    )
  ),

  record_confirmed = list(
    file = "record_confirmed.csv", key = "station_id", writer = "person",
    columns = c(station_id = "text", confirmed_from = "date", reason = "text")
  ),

  surveys = list(
    file = "surveys.csv", key = NULL, writer = "person",
    columns = c(
      station_id = "text", unique_id = "text", measured_on = "date",
      quantity = "text", point = "text", value = "number",
      relative_to = "text", relative_to_id = "text", method = "text",
      carried_from = "text", notes = "text"
    )
  ),

  pending_ingest = list(
    file = "pending_ingest.csv", key = NULL, writer = "person",
    columns = c(
      created_utc = "datetime_utc", updated_utc = "datetime_utc",
      station_id = "text", unique_id = "text", field_visit_date = "date",
      logged_by = "text", stage = "text", notes = "text"
    )
  )
)

#### Vocabularies ####

# What a maintenance entry can record. Chosen by hand for a routine visit, or
# written by the workflow that makes the change - never both: an action a
# workflow writes is not offered for hand entry, since logging it by hand
# would record a change that was never made.
MAINTENANCE_ACTIONS_BY_HAND <- c(
  "inspection", "cleaning", "maintenance", "battery",
  "logger_relaunch"          # HOBO only - a ZL6 is not launched and relaunched
)
MAINTENANCE_ACTIONS_BY_WORKFLOW <- c(
  "download",
  "station_established", "station_relocation", "station_decommissioned",
  "station_reactivated",
  "device_added", "device_replacement", "device_removal", "device_renamed",
  "port_config_change",
  "survey",                  # the numbers themselves are in the survey records
  "metadata_correction", "metadata_deletion"
)
MAINTENANCE_ACTIONS <- c(MAINTENANCE_ACTIONS_BY_HAND, MAINTENANCE_ACTIONS_BY_WORKFLOW)

# A deployment's status. Active statuses say how a working device's data
# reaches the archive; terminal ones how its deployment ended. TERMINAL_STATUSES
# itself is defined in attribution_functions.R, which loads first
ACTIVE_STATUSES <- c(
  "online",                  # reports to the cloud over cellular
  "local",                   # offloaded on site, then uploaded
  "manual",                  # no cloud pathway; archived by hand
  "defunct"                  # broken or assumed lost, still deployed
)

# A port row's status. Blank is a working sensor
PORT_STATUSES <- c(
  "defunct",                 # failed, still plugged in; its readings are kept
  "excluded"                 # plugged in and recorded, never ingested
)

# A survey row is a distance between two points: what kind of distance, which
# points, and how it was measured. See surveys.csv in data/DATA_DICTIONARY.md
SURVEY_QUANTITIES <- c(
  "height_cm",               # vertical: point above relative_to; negative is below
  "reach_m"                  # along the channel, to the logger in relative_to_id
)
SURVEY_POINTS <- c(
  "rebar",                   # the top of the logger's rebar
  "sensor",                  # the logger's measuring point
  "bed",                     # the streambed, or pond bed, at the logger
  "ground",                  # the ground at the station's coordinates
  "overflow"                 # where the pool spills - the gauge of zero flow
)
SURVEY_METHODS <- c(
  "laser", "level", "tape",
  "nominal"                  # a standard value, not measured
)

# The tables a person writes, through the metadata manager. A save to one of
# these is checked first, and refused if it would add a problem
# validate_metadata() finds - see validation_blocks_write(). The machine-written
# logs are not: the job's record of what it archived is never held back
VALIDATED_TABLES <- c("device_metadata", "zentra_ports", "maintenance_log",
                      "surveys", "pending_ingest")

#' One table's schema, or an error naming the tables there are
table_schema <- function(name) {
  s <- TABLE_SCHEMA[[name]]
  if (is.null(s)) {
    stop("No table called '", name, "'. The tables are: ",
         paste(names(TABLE_SCHEMA), collapse = ", "), call. = FALSE)
  }
  s
}

#' Where a table lives
table_path <- function(name) {
  file.path(wds("meta_internal"), table_schema(name)$file)
}


#### Reading ####

#' Reads a table, its columns typed by the schema
#'
#' The header must match the schema exactly - same columns, same order. A
#' value that cannot be read as its column's type is an error naming the row
#' and the value, never a silent NA: a value lost on reading would be lost
#' again on the next write.
#'
#' "NA" and an empty cell both read as missing.
#'
#' @param name Character. A table in TABLE_SCHEMA
#' @param path Character. Read from here instead - for tests and checks
#' @param remember Logical. Record what was read, so a later write_table()
#'   can refuse if the file changes in between
#' @param as_text Character. Columns to return as their written text - a
#'   datetime as "YYYY-MM-DD HH:MM:SS" - rather than typed, missing as NA.
#'   For callers written before the layer that still expect text there; each
#'   use is a column whose callers have not yet been moved onto its type
#' @return Data frame. An empty one, with the schema's columns, if the file
#'   does not exist
read_table <- function(name, path = NULL, remember = TRUE, as_text = NULL) {
  s <- table_schema(name)
  if (is.null(path)) {
    # A table as it WOULD be after a save, read in its place while the save
    # is checked - see validation_blocks_write()
    over <- getOption("viflo.table_override")[[name]]
    path <- if (!is.null(over)) over else table_path(name)
  }
  cols <- s$columns

  if (!file.exists(path)) return(table_text_columns(table_empty(name), name, as_text))

  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8",
                         stringsAsFactors = FALSE)
  if (!identical(names(raw), names(cols))) {
    stop(basename(path), " does not have the columns its schema expects.\n",
         "  In the file:  ", paste(names(raw), collapse = ", "), "\n",
         "  Expected:     ", paste(names(cols), collapse = ", "), call. = FALSE)
  }
  if (remember && exists("remember_file_hash")) remember_file_hash(path)

  out <- raw
  for (col in names(cols)) {
    out[[col]] <- table_parse_column(raw[[col]], cols[[col]], col, basename(path))
  }
  table_text_columns(out, name, as_text)
}

#' Turns the named columns of a typed table back into their written text
table_text_columns <- function(data, name, as_text) {
  if (length(as_text) == 0) return(data)
  cols <- table_schema(name)$columns
  unknown <- setdiff(as_text, names(cols))
  if (length(unknown) > 0) {
    stop("Not a column of ", name, ": ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  for (col in as_text) {
    text <- table_format_column(data[[col]], cols[[col]])$text
    text[text == ""] <- NA_character_
    data[[col]] <- as.character(text)
  }
  data
}

#' An empty table with the schema's columns, typed
table_empty <- function(name) {
  cols <- table_schema(name)$columns
  out <- as.data.frame(lapply(cols, function(type) {
    table_parse_column(character(0), type, "", "")
  }), stringsAsFactors = FALSE, check.names = FALSE)
  names(out) <- names(cols)
  out
}

#' Turns one column of text into its schema type, or says what will not
table_parse_column <- function(x, type, col, file) {
  present <- !is.na(x)
  parsed <- switch(type,
    text           = x,
    number         = suppressWarnings(as.numeric(x)),
    integer        = {
                       v <- suppressWarnings(as.numeric(x))
                       v[!is.na(v) & v != round(v)] <- NA     # 2.5 is not a count
                       as.integer(v)
                     },
    logical        = c("TRUE" = TRUE, "FALSE" = FALSE)[toupper(x)],
    date           = parse_date_flexible(x),
    datetime_local = parse_datetime_flexible(x, PROJECT_TZ),
    datetime_utc   = parse_datetime_flexible(x, "UTC"),
    stop("Unknown column type '", type, "' for ", col, call. = FALSE)
  )
  if (type == "logical") parsed <- unname(parsed)
  if (type == "date") parsed <- as.Date(parsed)

  bad <- present & is.na(parsed)
  if (any(bad)) {
    rows <- which(bad)
    shown <- paste0("row ", rows + 1, ": \"", x[rows], "\"")
    stop(file, ": `", col, "` holds value(s) that are not a ", type, "\n  ",
         paste(head(shown, 10), collapse = "\n  "),
         if (length(rows) > 10) paste0("\n  ... and ", length(rows) - 10, " more"),
         call. = FALSE)
  }
  parsed
}


#### Writing ####

#' Turns one column into the text written to the file
#'
#' @return List: text (character, "" for missing) and quote (logical, whether
#'   this column's values are quoted)
table_format_column <- function(x, type) {
  # A value handed over as text - "41.96", "TRUE", "3/2/2026" - is read as
  # its type first. One that will not read is an error: written as it
  # stands, it would land bare in a number column or vanish from a date one
  given <- !is.na(x) & nzchar(as.character(x))
  as_type <- switch(type,
    number   = suppressWarnings(as.numeric(x)),
    integer  = suppressWarnings(as.numeric(x)),
    logical  = if (is.logical(x)) x else c("TRUE" = TRUE, "FALSE" = FALSE)[toupper(as.character(x))],
    date     = if (inherits(x, "Date")) x else parse_date_flexible(as.character(x)),
    x)
  if (type %in% c("number", "integer", "logical", "date")) {
    bad <- given & is.na(as_type)
    if (type == "integer") bad <- bad | (given & !is.na(as_type) & as_type != round(as_type))
    if (any(bad)) {
      stop("Not a ", type, ": ", paste(head(unique(as.character(x[bad])), 5), collapse = ", "),
           call. = FALSE)
    }
    x <- unname(as_type)
  }
  missing <- is.na(x) | !given
  if (type %in% c("datetime_local", "datetime_utc") && inherits(x, "POSIXct")) {
    missing <- is.na(x)
  }
  text <- switch(type,
    text           = as.character(x),
    number         = vapply(x, function(v) {
                       if (is.na(v)) "" else format(v, digits = 15, scientific = FALSE, trim = TRUE)
                     }, character(1), USE.NAMES = FALSE),
    integer        = ifelse(is.na(x), "", format(as.integer(round(x)), scientific = FALSE, trim = TRUE)),
    logical        = ifelse(x, "TRUE", "FALSE"),
    date           = format(as.Date(x), "%Y-%m-%d"),
    datetime_local = format(table_as_datetime(x, PROJECT_TZ), "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ),
    datetime_utc   = format(table_as_datetime(x, "UTC"), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  )
  text[missing] <- ""
  list(text = text, quote = !type %in% c("integer", "number", "logical"))
}

#' A datetime column as POSIXct, whatever it arrived as
#'
#' Callers hand over POSIXct, or text they formatted themselves. Text is
#' parsed in the column's own zone; anything that will not parse is an error,
#' never an empty cell.
table_as_datetime <- function(x, tz) {
  if (inherits(x, "POSIXct")) return(x)
  parsed <- parse_datetime_flexible(x, tz)
  bad <- !is.na(x) & nzchar(as.character(x)) & is.na(parsed)
  if (any(bad)) {
    stop("Not a datetime: ", paste(head(unique(as.character(x[bad])), 5), collapse = ", "),
         call. = FALSE)
  }
  parsed
}

#' A table as the lines of its file
table_lines <- function(name, data, header = TRUE) {
  cols <- table_schema(name)$columns
  quote <- function(v) paste0("\"", gsub("\"", "\"\"", v, fixed = TRUE), "\"")
  fields <- lapply(names(cols), function(col) {
    f <- table_format_column(data[[col]], cols[[col]])
    ifelse(f$text == "", "", if (f$quote) quote(f$text) else f$text)
  })
  body <- if (nrow(data) == 0) character(0) else do.call(paste, c(fields, sep = ","))
  if (header) c(paste(quote(names(cols)), collapse = ","), body) else body
}

#' The columns a write must have: the schema's, in order, and no others
table_conform <- function(name, data) {
  cols <- names(table_schema(name)$columns)
  extra <- setdiff(names(data), cols)
  if (length(extra) > 0) {
    stop("Not a column of ", table_schema(name)$file, ": ", paste(extra, collapse = ", "),
         call. = FALSE)
  }
  missing <- setdiff(cols, names(data))
  if (length(missing) > 0) {
    stop(name, " is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  data[, cols, drop = FALSE]
}

#' Writes lines to a file: UTF-8, Unix line endings, through a temporary file
#'
#' Written beside the target and then moved into place, so a crash halfway
#' leaves the old file whole rather than a new one half-written.
table_write_lines <- function(lines, path) {
  tmp <- paste0(path, ".partial")
  con <- file(tmp, open = "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
  close(con)
  if (!file.rename(tmp, path)) {
    file.remove(path)
    if (!file.rename(tmp, path)) stop("Could not move ", tmp, " into place", call. = FALSE)
  }
  invisible(TRUE)
}

# The tables this session has already backed up
.table_backups <- new.env(parent = emptyenv())

#' Copies a table into metadata/internal/backups before it is replaced
#'
#' Every table, logs included. Once per table per R session - the first
#' write - so what is kept is the table as it stood before the session
#' touched it: a metadata manager session that saves seven times leaves one
#' copy, not seven, and each run of the job leaves one. Skipped too when the
#' newest backup is already identical.
table_backup <- function(path) {
  if (!file.exists(path)) return(invisible(NA_character_))
  key <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (isTRUE(.table_backups[[key]])) return(invisible(NA_character_))
  assign(key, TRUE, envir = .table_backups)
  dir <- file.path(dirname(path), "backups")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  base <- tools::file_path_sans_ext(basename(path))
  existing <- list.files(dir, pattern = paste0("^", base, "_[0-9]{8}_[0-9]{6}(_[0-9]+)?\\.csv$"),
                         full.names = TRUE)
  if (length(existing) > 0) {
    newest <- existing[order(file.info(existing)$mtime, existing)][length(existing)]
    if (identical(unname(tools::md5sum(newest)), unname(tools::md5sum(path)))) {
      return(invisible(newest))
    }
  }
  # Two writes in one second must not share a backup name, or the second
  # copy would silently fail to land
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = PROJECT_TZ)
  dest <- file.path(dir, paste0(base, "_", stamp, ".csv"))
  k <- 1
  while (file.exists(dest)) {
    k <- k + 1
    dest <- file.path(dir, paste0(base, "_", stamp, "_", k, ".csv"))
  }
  if (!file.copy(path, dest)) stop("Could not back up ", basename(path), call. = FALSE)
  invisible(dest)
}

#' Replaces a whole table
#'
#' In order: the columns are checked against the schema; every value is
#' formatted the one way; the write is refused if the file changed since this
#' session read it; the current file is backed up; and the new one is written
#' beside it and moved into place.
#'
#' @param name Character. A table in TABLE_SCHEMA
#' @param data Data frame with exactly the schema's columns, in any order
#' @param path Character. Write here instead - for tests and checks. Skips
#'   the guard and the backup
#' @param guard Logical. Refuse if the file changed since it was read. Off
#'   only where the caller means to replace the file wholesale and says so -
#'   a migration, a restore
#' @param intent Character. What the caller was doing, for the refusal
#' @return Invisibly TRUE if written, FALSE if refused
write_table <- function(name, data, path = NULL, guard = TRUE, intent = NULL) {
  data <- table_conform(name, data)
  lines <- table_lines(name, data)       # formatting errors stop us here, before anything is touched

  if (!is.null(path)) return(table_write_lines(lines, path))
  path <- table_path(name)

  if (guard && file.exists(path) && exists("remembered_file_hash")) {
    expected <- remembered_file_hash(path)
    if (!is.na(expected) && !identical(expected, unname(tools::md5sum(path)))) {
      report_write_conflict(path, data, intent)
      return(invisible(FALSE))
    }
  }

  # Checked against everything validate_metadata() knows, before anything is
  # touched. Only with the guard: a migration or a test writing guard = FALSE
  # is reshaping the table on purpose
  if (guard && name %in% VALIDATED_TABLES && exists("validation_blocks_write")) {
    if (validation_blocks_write(name, data = data, intent = intent)) return(invisible(FALSE))
  }

  table_backup(path)
  table_write_lines(lines, path)
  if (exists("remember_file_hash")) remember_file_hash(path)
  invisible(TRUE)
}

#' Replaces a whole table, or stops
#'
#' For callers inside a tryCatch() that turns errors into a message: a refused
#' write becomes an error like any other failure, rather than a FALSE that is
#' easy to mistake for nothing to do.
write_table_or_stop <- function(name, data, intent = NULL) {
  if (!isTRUE(write_table(name, data, intent = intent))) {
    stop(table_schema(name)$file, " was not saved - the reason is above",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Adds rows to the end of a table
#'
#' For the logs, which only ever grow. Each value goes under its own column by
#' name; a column the rows do not have is left empty, and a column the table
#' does not have is refused rather than dropped. Not backed up - an append
#' changes nothing already there.
#'
#' @param name Character. A table in TABLE_SCHEMA
#' @param rows Data frame
#' @param path Character. Append here instead - for tests
#' @return Invisibly TRUE
append_rows <- function(name, rows, path = NULL) {
  cols <- names(table_schema(name)$columns)
  extra <- setdiff(names(rows), cols)
  if (length(extra) > 0) {
    stop("Not a column of ", table_schema(name)$file, ": ", paste(extra, collapse = ", "),
         call. = FALSE)
  }
  for (col in setdiff(cols, names(rows))) rows[[col]] <- rep(NA, nrow(rows))
  rows <- rows[, cols, drop = FALSE]

  # A log a person writes is checked like a whole-table save: the table as it
  # would be with these rows, against everything validate_metadata() knows
  if (is.null(path) && name %in% VALIDATED_TABLES && exists("validation_blocks_write") &&
      file.exists(table_path(name))) {
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    current <- readLines(table_path(name), warn = FALSE, encoding = "UTF-8")
    writeLines(c(current, table_lines(name, rows, header = FALSE)), tmp, useBytes = TRUE)
    if (validation_blocks_write(name, path = tmp, intent = "adding rows")) {
      stop(table_schema(name)$file, ": nothing added - the reason is above", call. = FALSE)
    }
  }
  if (is.null(path)) path <- table_path(name)

  # Rows shaped by the schema can only go onto a file shaped by it. Appended
  # to anything else, every value would sit under the wrong column - the
  # failure that hid the October 2026 HOBO offloads
  if (file.exists(path) && file.size(path) > 0) {
    header <- names(utils::read.csv(path, nrows = 0, check.names = FALSE))
    if (!identical(header, cols)) {
      stop(basename(path), " does not have the columns its schema expects, ",
           "so nothing was appended.\n",
           "  In the file:  ", paste(header, collapse = ", "), "\n",
           "  Expected:     ", paste(cols, collapse = ", "), call. = FALSE)
    }
  }

  if (!file.exists(path)) {
    table_write_lines(table_lines(name, rows), path)
  } else {
    lines <- table_lines(name, rows, header = FALSE)
    # A file that does not end in a newline would have the first new row
    # glued onto its last one
    size <- file.size(path)
    ends_clean <- size == 0 || {
      con <- file(path, "rb"); seek(con, size - 1); last <- readBin(con, "raw", 1); close(con)
      identical(last, charToRaw("\n"))
    }
    con <- file(path, open = "ab")
    if (!ends_clean) writeBin(charToRaw("\n"), con)
    writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
    close(con)
  }
  if (exists("remember_file_hash")) remember_file_hash(path)
  invisible(TRUE)
}


#### Checking ####

#' Reads a table and writes it back to a temporary file, and compares
#'
#' The test that the layer reads and writes faithfully. Every value must
#' survive: compared by meaning, so a datetime written once as
#' "2023-11-06 10:45" and now as "2023-11-06 10:45:00" is the same value, and
#' "NA" and an empty cell are both missing. The bytes are compared too, and
#' reported separately - they differ the first time a table written before the
#' layer passes through it, which normalizes its formatting once, and never
#' after that.
#'
#' @param name Character. A table in TABLE_SCHEMA
#' @param path Character. The file to test; defaults to the live table
#' @return List: values_identical, bytes_identical (logical), differences
#'   (character, empty when values are identical)
table_round_trip <- function(name, path = NULL) {
  if (is.null(path)) path <- table_path(name)
  if (!file.exists(path)) {
    return(list(values_identical = TRUE, bytes_identical = TRUE, differences = character(0)))
  }
  before <- read_table(name, path, remember = FALSE)
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  write_table(name, before, path = tmp)
  after <- read_table(name, tmp, remember = FALSE)

  # Compare the original text with the rewritten text, column by column, by
  # meaning: each parsed through its schema type
  orig <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                          check.names = FALSE, encoding = "UTF-8")
  differences <- character(0)
  cols <- table_schema(name)$columns
  if (nrow(orig) != nrow(after)) {
    differences <- c(differences, paste0(nrow(orig), " rows read, ", nrow(after), " written"))
  } else {
    for (col in names(cols)) {
      a <- table_parse_column(orig[[col]], cols[[col]], col, basename(path))
      b <- after[[col]]
      same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
      if (!all(same)) {
        k <- which(!same)
        differences <- c(differences, paste0(
          "`", col, "`, ", length(k), " value(s), e.g. row ", k[1] + 1, ": \"",
          orig[[col]][k[1]], "\" became \"", as.character(b[k[1]]), "\""))
      }
    }
  }

  bytes_identical <- identical(unname(tools::md5sum(path)), unname(tools::md5sum(tmp)))
  list(values_identical = length(differences) == 0,
       bytes_identical = bytes_identical,
       differences = differences)
}

#' Round-trips every table and prints the result
#'
#' @return Invisibly TRUE if every table's values survived
check_all_tables <- function() {
  ok <- TRUE
  for (name in names(TABLE_SCHEMA)) {
    res <- tryCatch(table_round_trip(name), error = function(e) conditionMessage(e))
    if (is.character(res)) {
      cat("  ✗ ", name, ": ", res, "\n", sep = ""); ok <- FALSE
    } else if (!res$values_identical) {
      cat("  ✗ ", name, ": values changed\n", sep = "")
      for (d in res$differences) cat("      ", d, "\n", sep = "")
      ok <- FALSE
    } else if (res$bytes_identical) {
      cat("  ✓ ", name, ": identical\n", sep = "")
    } else {
      cat("  ✓ ", name, ": values identical; formatting will be normalized on its next write\n", sep = "")
    }
  }
  invisible(ok)
}
