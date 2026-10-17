################################################################################
#                              PRODUCT 2                                       #
#                                                                              #
# Product 2 is one file per station, variable and year, where the series is:   #
#                                                                              #
#   1. attributed - only readings that belonged to that station, by metadata   #
#      as it stood at that moment                                              #
#   2. deduplicated - where downloads overlap, the later fetch wins, and a     #
#      disagreement is marked                                                  #
#   3. on the network's 15-minute grid - every moment the station was          #
#      recording has a row, and a gap is a row flagged `missing`               #
#   4. consistently named and in consistent units                              #
#   5. neither judged nor invented - values as recorded, flagged only          #
#      `observed` or `missing`                                                 #
#                                                                              #
# In order: the VARIABLE REGISTRY, one READER that turns every shape of        #
# Product 1 into the same long form, DEDUPLICATION across overlapping          #
# downloads, ATTRIBUTION to stations, the 15-MINUTE GRID, and the WRITER and   #
# its manifest. build_p2() runs the lot.                                       #
#                                                                              #
# Product 1 arrives four ways, and they do not even agree on what time it is:  #
#                                                                              #
#   ZENTRA (ZL6)  long already - one row per port, measurement and moment.     #
#                 Times in UTC. Every reading carries an error code            #
#   ZENTRA EXPORT the full-history exports the backfill parsed - long, but     #
#                 with export column names, sensors spelled out in full        #
#                 ("ATMOS 41 All-in-one Weather Station"), and no error code   #
#   HOBO (U20)    a HOBOware export - one column per measurement, the unit and #
#                 serial in the header, times as text with a declared offset   #
#   HOBOLINK      parsed during the backfill - one column per measurement, the #
#                 unit in the column NAME, times in project-local time         #
#                                                                              #
# The reader brings all four to UTC, one row per measurement per moment.       #
################################################################################


#### The variable registry ####

#' Every measurement the network reports, and what Product 2 makes of it
#'
#' `data/variables.csv`, one row per source, sensor and measurement as
#' reported. The sensor is part of the key because two instruments can report
#' a measurement of the same name - an ATMOS 41 and an ECRN-50 both report
#' "Precipitation", and they are not the same series. A blank sensor matches
#' any, for a source with only one kind of instrument. Each row is
#' kept or dropped, the VI-FLO variable name, its unit, and its kind -
#' instantaneous, accumulated or maximum, which decides how a finer interval
#' is brought onto the 15-minute grid. `depth` marks a variable named with its
#' sensor's depth, `vwc_30cm`. `source_unit` is the unit for a source that
#' does not report one per reading.
#'
#' A plain CSV rather than a list in code, so it can be read and corrected
#' without opening R.
#'
#' @return Data frame
load_variable_registry <- function() {
  path <- file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "data", "variables.csv")
  reg <- read.csv(path, stringsAsFactors = FALSE, na.strings = "",
                  encoding = "UTF-8")
  reg$keep  <- as.logical(reg$keep)
  reg$depth <- as.logical(reg$depth)
  reg$sensor[is.na(reg$sensor)] <- ""
  reg
}

#' A sensor as reported, in the registry's spelling
#'
#' The live API says "ATMOS 41"; the full-history exports say "ATMOS 41
#' All-in-one Weather Station". The registry's name is the longest one the
#' reported name starts with, so "ATMOS 41 G2" is never mistaken for an
#' "ATMOS 41". Anything that matches none comes back unchanged.
#'
#' @param x Character
#' @param known Character. The registry's sensor names
#' @return Character
canonical_sensor <- function(x, known) {
  known <- unique(known[nzchar(known)])
  known <- known[order(-nchar(known))]
  x <- as.character(x)
  # Each distinct name once - a station-year is a million rows and a handful
  # of sensor names
  u <- unique(x)
  mapped <- u
  for (i in seq_along(u)) {
    if (is.na(u[i])) next
    hit <- known[startsWith(tolower(u[i]), tolower(known))]
    if (length(hit) > 0) mapped[i] <- hit[1]
  }
  mapped[match(x, u)]
}

# The units a kept variable can be in
CANONICAL_UNITS <- c("degC", "%", "kPa", "m/s", "deg", "W/m2", "mm", "mm/h",
                     "count", "km", "m3/m3", "dS/m", "m")

VARIABLE_KINDS <- c("instantaneous", "accumulated", "maximum", "minimum")


#### Units ####

#' A unit as reported, in VI-FLO's spelling
#'
#' The same unit arrives spelled several ways - "°C" from ZENTRA, "°C" or
#' "°F" from a HOBOware export depending on its settings, sometimes mangled by
#' an encoding round trip. Anything not recognized comes back as it was, and
#' convert_units() then refuses it rather than guessing.
#'
#' @param x Character
#' @return Character
normalize_unit <- function(x) {
  x <- trimws(enc2utf8(as.character(x)))
  x[is.na(x)] <- ""
  # The degree sign, however it survived the trip
  x <- gsub("\u00b0|<U\\+00B0>|\u00ba", "deg", x)
  x <- gsub("\u00b2|<U\\+00B2>", "2", x)
  x <- gsub("\u00b3|<U\\+00B3>", "3", x)
  x <- gsub("\\s+", "", x)

  map <- c(
    "degC" = "degC", "C" = "degC", "celsius" = "degC", "degree_C" = "degC",
    "degF" = "degF", "F" = "degF", "fahrenheit" = "degF",
    "kPa" = "kPa", "kpa" = "kPa", "psi" = "psi", "hPa" = "hPa",
    "mbar" = "hPa", "mb" = "hPa",
    "m/s" = "m/s", "deg" = "deg", "degrees" = "deg",
    "W/m2" = "W/m2", "mm" = "mm", "mm/hr" = "mm/h", "mm/h" = "mm/h",
    "km" = "km", "m3/m3" = "m3/m3", "mS/cm" = "mS/cm", "dS/m" = "dS/m",
    "%" = "%", "m" = "m", "ft" = "ft", "mV" = "mV", "raw" = "raw",
    "count" = "count", "Lightning" = "count"
  )
  hit <- x %in% names(map)
  x[hit] <- unname(map[x[hit]])
  x
}

#' Converts values between units
#'
#' Only the conversions VI-FLO actually meets. An unknown pair is an error,
#' never a guess: a HOBO export saved in an unexpected unit should stop a
#' build, not put feet into a column of meters.
#'
#' @param value Numeric
#' @param from,to Character, normalized units
#' @return Numeric
convert_units <- function(value, from, to) {
  if (identical(from, to)) return(value)
  key <- paste(from, to, sep = "->")
  f <- switch(key,
    "degF->degC"  = function(v) (v - 32) * 5 / 9,
    "psi->kPa"    = function(v) v * 6.894757,
    "hPa->kPa"    = function(v) v / 10,
    "ft->m"       = function(v) v * 0.3048,
    "mS/cm->dS/m" = function(v) v,
    NULL)
  if (is.null(f)) {
    stop("No conversion from '", from, "' to '", to, "'", call. = FALSE)
  }
  f(value)
}


#### Reading Product 1 ####

#' Which of the three Product 1 shapes a file is
#'
#' @param data Data frame as read from a Product 1 file
#' @return "zentra", "zentra_export", "hobo" or "hobolink"
p1_shape <- function(data) {
  n <- names(data)
  if (all(c("device_id", "datetime", "measurement", "value") %in% n)) return("zentra")
  if (all(c("device_sn", "timestamp_utc", "measurement", "value") %in% n)) return("zentra_export")
  if (any(grepl("^Date Time", n))) return("hobo")
  if ("datetime" %in% n && any(c("water_pressure_kpa", "barometric_kpa",
                                 "water_level_m") %in% n)) return("hobolink")
  stop("Unrecognized Product 1 shape. Columns: ", paste(n, collapse = ", "),
       call. = FALSE)
}

#' A Product 1 file in the common long form
#'
#' One row per measurement per moment, whatever the source:
#'
#'   device_serial, datetime (UTC), source, port, sensor, measurement, unit,
#'   value, error_code, source_file
#'
#' Both ZENTRA shapes come out as source "zentra". `port` and `sensor` are NA
#' for a HOBO, which has neither; `error_code` is NA where the source does
#' not report one. Nothing is renamed, converted or dropped here -
#' that is map_measurements() - so this stays a faithful re-shaping.
#'
#' @param path Character. A Product 1 .rds file
#' @param device_serial Character, or NULL to take it from the filename
#' @return Data frame
read_p1_long <- function(path, device_serial = NULL) {
  if (is.null(device_serial)) {
    device_serial <- parse_raw_filename(basename(path))$device_serial
  }
  data <- readRDS(path)
  shape <- p1_shape(data)

  to_utc <- function(x) { attr(x, "tzone") <- "UTC"; x }

  out <- switch(shape,
    zentra = {
      data.frame(device_serial = as.character(data$device_id),
                 datetime      = to_utc(data$datetime),
                 source        = "zentra",
                 port          = as.integer(data$port_num),
                 sensor        = as.character(data$sensor_name),
                 measurement   = as.character(data$measurement),
                 unit          = as.character(data$unit),
                 value         = as.numeric(data$value),
                 error_code    = if ("error_code" %in% names(data))
                                   as.integer(data$error_code) else NA_integer_,
                 stringsAsFactors = FALSE)
    },
    zentra_export = {
      # timestamp_utc is the time to use: where the logger had no offset set,
      # its clock was UTC and the export's "local" column is the same moment
      data.frame(device_serial = as.character(data$device_sn),
                 datetime      = to_utc(data$timestamp_utc),
                 source        = "zentra",
                 port          = as.integer(data$port),
                 sensor        = as.character(data$sensor),
                 measurement   = as.character(data$measurement),
                 unit          = as.character(data$unit),
                 value         = as.numeric(data$value),
                 error_code    = NA_integer_,
                 stringsAsFactors = FALSE)
    },
    hobo = {
      l <- hobo_to_long(as.data.frame(data), device_serial)
      data.frame(device_serial = as.character(l$device_serial),
                 datetime      = to_utc(l$datetime),
                 source        = "hobo",
                 port          = NA_integer_,
                 sensor        = NA_character_,
                 measurement   = l$measurement,
                 unit          = l$unit,
                 value         = l$value,
                 error_code    = NA_integer_,
                 stringsAsFactors = FALSE)
    },
    hobolink = {
      # The backfill stored local times, so the zone is whatever the column
      # carries - not assumed
      when <- data$datetime
      if (!inherits(when, "POSIXct")) {
        when <- as.POSIXct(when, tz = "America/Puerto_Rico")
      }
      cols <- setdiff(names(data), "datetime")
      do.call(rbind, lapply(cols, function(col) {
        data.frame(device_serial = device_serial,
                   datetime      = to_utc(when),
                   source        = "hobolink",
                   port          = NA_integer_,
                   sensor        = NA_character_,
                   measurement   = col,
                   unit          = NA_character_,
                   value         = suppressWarnings(as.numeric(data[[col]])),
                   error_code    = NA_integer_,
                   stringsAsFactors = FALSE)
      }))
    })

  out$source_file <- basename(path)
  out[!is.na(out$datetime), , drop = FALSE]
}

#' Long readings, named, converted and filtered by the registry
#'
#' - A measurement the registry drops is removed
#' - A measurement the registry has never heard of is removed too, but
#'   REPORTED, never silently: a new sensor or a renamed field should be
#'   added to the table, not lost without anyone knowing
#' - Units are converted to the registry's, from the unit the reading carries
#'   or, where it carries none, the registry's source_unit. A unit with no
#'   known conversion stops the build
#' - A nonzero error code empties the value: the logger asked and the sensor
#'   gave no valid measurement. The row stays, so the moment is known to have
#'   been recorded - Product 2 shows it as missing with the device named
#'
#' @param long Data frame from read_p1_long()
#' @param registry Data frame from load_variable_registry(), or NULL to load
#' @return Data frame: the long columns plus variable, kind, depth. Attribute
#'   "unmapped": source, sensor, measurement and row count of anything the
#'   registry does not know
map_measurements <- function(long, registry = NULL) {
  if (is.null(registry)) registry <- load_variable_registry()

  # Sensor first, in the registry's spelling; then match on source, sensor and
  # measurement, falling back to a blank-sensor row for sources that have one.
  # Matched once per distinct combination and spread back: a station-year is
  # a million rows and a few dozen combinations.
  sensor <- canonical_sensor(long$sensor, registry$sensor)
  sensor[is.na(sensor)] <- ""
  long$sensor <- sensor

  combo <- paste(long$source, sensor, long$measurement, sep = "|")
  u <- unique(combo)
  parts <- do.call(rbind, strsplit(u, "|", fixed = TRUE))
  if (is.null(dim(parts))) parts <- matrix(parts, ncol = 3)
  key_reg <- paste(registry$source, registry$sensor, registry$measurement, sep = "|")
  u_hit <- match(u, key_reg)
  u_any <- match(paste(parts[, 1], "", parts[, 3], sep = "|"), key_reg)
  u_hit[is.na(u_hit)] <- u_any[is.na(u_hit)]
  hit <- u_hit[match(combo, u)]

  #### Unknown measurements: reported ####
  unknown <- is.na(hit)
  unmapped <- if (any(unknown)) {
    u <- long[unknown, c("source", "sensor", "measurement")]
    aggregate(list(rows = rep(1L, nrow(u))), u, length)
  } else {
    data.frame(source = character(0), sensor = character(0),
               measurement = character(0), rows = integer(0))
  }

  #### Dropped and unknown: removed ####
  keep <- !unknown & registry$keep[hit] %in% TRUE
  out <- long[keep, , drop = FALSE]
  r <- registry[hit[keep], , drop = FALSE]

  out$variable <- r$variable
  out$kind     <- r$kind
  out$depth    <- r$depth

  #### Units ####
  # Normalized once per distinct spelling
  raw_unit <- ifelse(is.na(out$unit), "", out$unit)
  uu <- unique(raw_unit)
  from <- normalize_unit(uu)[match(raw_unit, uu)]
  need <- from == "" & !is.na(r$source_unit)
  from[need] <- r$source_unit[need]
  # A count arrives with no unit at all
  from[from == "" & r$unit == "count"] <- "count"
  to <- r$unit

  pair <- paste(from, to, out$variable, sep = "|")
  for (p in unique(pair)) {
    sel <- pair == p
    bits <- strsplit(p, "|", fixed = TRUE)[[1]]
    if (identical(bits[1], bits[2])) next
    out$value[sel] <- tryCatch(
      convert_units(out$value[sel], bits[1], bits[2]),
      error = function(e) {
        stop("Cannot convert ", bits[3], ": ", conditionMessage(e), call. = FALSE)
      })
  }
  out$unit <- to

  #### Error codes: the sensor gave nothing usable ####
  bad <- !is.na(out$error_code) & out$error_code != 0
  out$value[bad] <- NA_real_

  rownames(out) <- NULL
  attr(out, "unmapped") <- unmapped
  out
}


#### Deduplication ####

#' When each Product 1 file was fetched, from the download log
#'
#' The fetch time decides which of two overlapping downloads wins. It comes
#' from the log's `timestamp_utc` rather than `run_id`, because a manual HOBO
#' offload has no run_id but every row has a timestamp. A file the log does
#' not know is an error: its readings could not be ordered against anything.
#'
#' @param files Character. Product 1 filenames, or paths
#' @param log Data frame from load_download_log(), or NULL to load
#' @return POSIXct, UTC, one per file
p1_fetch_times <- function(files, log = NULL) {
  if (is.null(log)) log <- load_download_log()
  stamp <- as.POSIXct(as.character(log$timestamp_utc), tz = "UTC")
  i <- match(basename(files), basename(log$filepath))
  if (any(is.na(i))) {
    stop("Not in the download log: ",
         paste(basename(files)[is.na(i)], collapse = ", "), call. = FALSE)
  }
  stamp[i]
}

#' One reading per device, port, measurement and moment
#'
#' Product 1 keeps every download whole, so two that overlap - a re-run, a
#' catch-up after a failure, an offload that repeats the end of the last -
#' hold some moments twice. The copy from the LATER FETCH is kept: it has
#' been through the same logger and more recent handling, and is the one a
#' re-download was made to get.
#'
#' Where the copies disagree on the value, the kept row is marked
#' `conflict = TRUE` rather than the disagreement being resolved silently.
#' Two copies that are both empty agree. A moment repeated within a single
#' file keeps its last occurrence, and is marked the same way if the copies
#' differ.
#'
#' @param readings Data frame from map_measurements(), with source_file
#' @param fetched POSIXct, one per row - when that row's file was fetched
#' @return Data frame: the readings, one row per key, plus `conflict`.
#'   Attribute "dedup": rows in, rows out, duplicate rows removed, conflicts
dedupe_readings <- function(readings, fetched) {
  n_in <- nrow(readings)
  if (n_in == 0) {
    readings$conflict <- logical(0)
    attr(readings, "dedup") <- c(rows_in = 0, rows_out = 0, removed = 0, conflicts = 0)
    return(readings)
  }

  # A series is device, port, sensor and measurement - a few dozen of them,
  # numbered, so the million-row sort is on numbers rather than text
  series <- paste(readings$device_serial, readings$port, readings$sensor,
                  readings$measurement, sep = "|")
  sid <- match(series, unique(series))
  when <- as.numeric(readings$datetime)

  # Latest fetch first, and within a file the last occurrence first
  ord <- order(sid, when, -as.numeric(fetched), -seq_len(n_in))
  s_o <- sid[ord]; w_o <- when[ord]
  first <- c(TRUE, s_o[-1] != s_o[-length(s_o)] | w_o[-1] != w_o[-length(w_o)])

  # Each copy compared with the copy its key keeps - the first of its run
  run <- cumsum(first)
  v <- readings$value[ord]
  k <- v[first][run]
  same <- (is.na(v) & is.na(k)) | (!is.na(v) & !is.na(k) & v == k)
  conflicted_run <- unique(run[!same])

  out <- readings[ord[first], , drop = FALSE]
  out$conflict <- seq_len(sum(first)) %in% conflicted_run
  out <- out[order(out$device_serial, out$measurement, out$datetime), , drop = FALSE]
  rownames(out) <- NULL

  attr(out, "dedup") <- c(rows_in   = n_in,
                          rows_out  = nrow(out),
                          removed   = n_in - nrow(out),
                          conflicts = sum(out$conflict))
  out
}

#' Every reading from a set of Product 1 files, mapped and deduplicated
#'
#' The first two pieces of Product 2 joined: read each file, apply the
#' registry, and keep one reading per device, port, measurement and moment.
#' Anything the registry did not know is gathered from every file into one
#' report.
#'
#' @param paths Character. Product 1 files
#' @param log Data frame from load_download_log(), or NULL to load
#' @param registry Data frame, or NULL to load
#' @return Data frame from dedupe_readings(), with attributes "dedup" and
#'   "unmapped"
read_p1_set <- function(paths, log = NULL, registry = NULL) {
  if (is.null(registry)) registry <- load_variable_registry()
  if (is.null(log)) log <- load_download_log()

  fetched <- p1_fetch_times(paths, log)
  parts <- list(); unmapped <- list()
  for (i in seq_along(paths)) {
    m <- map_measurements(read_p1_long(paths[i]), registry)
    if (nrow(attr(m, "unmapped")) > 0) {
      unmapped[[length(unmapped) + 1]] <- cbind(source_file = basename(paths[i]),
                                                attr(m, "unmapped"))
    }
    if (nrow(m) > 0) {
      m$fetched_utc <- rep(fetched[i], nrow(m))
      parts[[length(parts) + 1]] <- m
    }
  }
  all <- if (length(parts) > 0) do.call(rbind, parts) else NULL
  if (is.null(all)) stop("No readings in these files", call. = FALSE)

  out <- dedupe_readings(all, all$fetched_utc)
  attr(out, "unmapped") <- if (length(unmapped) > 0) do.call(rbind, unmapped) else
    data.frame(source_file = character(0), source = character(0),
               sensor = character(0), measurement = character(0), rows = integer(0))
  out
}


#### Attribution ####

# Measured by the logger itself, not by a sensor on a port - the ZL6's
# barometer, on an internal port that no station's ports list. Attributed by
# device and moment alone (see attribute_readings).
DEVICE_LEVEL_VARIABLES <- c("logger_pressure")

#' Readings, each assigned to the station it belonged to
#'
#' Uses the deployment and port windows already in attribution_functions.R:
#' device and moment for a HOBO, device, port and moment for a ZL6. A sensor
#' with a depth takes it into its name here - `vwc` on a 30 cm port becomes
#' `vwc_30cm` - from the port as it stood at that moment, so a corrected
#' depth is a rebuild, not a lost file.
#'
#' A logger's own barometer belongs to no port. It goes to the weather
#' station where the logger serves one - a co-located ZL6 would otherwise
#' carry the same series twice - and otherwise to the one station it serves.
#'
#' Readings that belong to no station are not an error - a logger before its
#' deployment, or in a life metadata never recorded. They are returned
#' separately, counted, never forced onto a station.
#'
#' @param readings Data frame from read_p1_set()
#' @param windows,pwindows From deployment_windows() and port_windows(), or
#'   NULL to compute
#' @return Data frame: the readings that resolved, with station_id and the
#'   full variable name. Attribute "unattributed": device, variable, first,
#'   last and count of readings that resolved to no station
attribute_readings <- function(readings, windows = NULL, pwindows = NULL) {
  if (is.null(windows))  windows  <- deployment_windows()
  if (is.null(pwindows)) pwindows <- port_windows()

  readings$station_id <- NA_character_
  readings$depth_cm   <- NA_real_

  for (dev in unique(readings$device_serial)) {
    rows <- which(readings$device_serial == dev)
    device_level <- readings$variable[rows] %in% DEVICE_LEVEL_VARIABLES

    #### Sensor readings: by port, or by device for a HOBO ####
    sr <- rows[!device_level]
    if (length(sr) > 0) {
      res <- resolve_readings(dev, readings$port[sr], readings$datetime[sr],
                              windows, pwindows)
      readings$station_id[sr] <- res$station_id
      readings$depth_cm[sr]   <- res$depth_cm
    }

    #### The logger's own barometer: weather first ####
    dr <- rows[device_level]
    if (length(dr) > 0) {
      dw <- windows[windows$device_serial == dev, , drop = FALSE]
      when <- readings$datetime[dr]
      utc <- function(x) { attr(x, "tzone") <- "UTC"; x }
      # Weather deployments first, then by station id, so the first match wins
      dw <- dw[order(dw$station_type != "weather", dw$station_id), , drop = FALSE]
      for (i in seq_len(nrow(dw))) {
        open <- is.na(readings$station_id[dr])
        inside <- when >= utc(dw$starts[i]) &
                  (is.na(dw$ends[i]) | when < utc(dw$ends[i]))
        inside[is.na(inside)] <- FALSE
        readings$station_id[dr[open & inside]] <- dw$station_id[i]
      }
    }
  }

  #### Depth into the name ####
  named <- readings$depth %in% TRUE & !is.na(readings$depth_cm)
  readings$variable[named] <- paste0(readings$variable[named], "_",
                                     readings$depth_cm[named], "cm")
  # A depth variable on a port with no recorded depth cannot be named - three
  # sensors would collide on one series. Treated as unattributed and reported.
  no_depth <- readings$depth %in% TRUE & is.na(readings$depth_cm)
  readings$station_id[no_depth] <- NA

  #### What resolved to nothing ####
  lost <- is.na(readings$station_id)
  unattributed <- if (any(lost)) {
    u <- readings[lost, ]
    agg <- aggregate(list(rows = rep(1L, nrow(u))),
                     list(device_serial = u$device_serial, variable = u$variable), length)
    agg$first <- as.POSIXct(tapply(as.numeric(u$datetime), paste(u$device_serial, u$variable), min)[
      paste(agg$device_serial, agg$variable)], origin = "1970-01-01", tz = "UTC")
    agg$last <- as.POSIXct(tapply(as.numeric(u$datetime), paste(u$device_serial, u$variable), max)[
      paste(agg$device_serial, agg$variable)], origin = "1970-01-01", tz = "UTC")
    agg
  } else {
    data.frame(device_serial = character(0), variable = character(0),
               rows = integer(0))
  }

  out <- readings[!lost, , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "unattributed") <- unattributed
  out
}


#### The 15-minute grid ####

P2_STEP <- 900   # seconds: the network's quarter hour

#' The interval a series was actually logged at
#'
#' The most common gap between consecutive readings - a run at the real
#' interval is what the logger was set to, however many gaps surround it.
#'
#' @param when POSIXct or numeric seconds
#' @return Numeric seconds, NA for fewer than three readings
observed_interval <- function(when) {
  u <- sort(unique(as.numeric(when)))
  if (length(u) < 3) return(NA_real_)
  d <- diff(u)
  tab <- table(round(d))
  as.numeric(names(tab)[which.max(tab)])
}

#' One device's series of one variable, on the quarter hour
#'
#' How a reading reaches the quarter hour depends on what it is:
#'
#'   INSTANTANEOUS - a reading exactly on the quarter hour is used as is.
#'     Otherwise the value is interpolated between the readings either side,
#'     provided both are real and no more than 15 minutes apart: U20s logging
#'     at :08:37 come out on :00, :15, :30, :45. Never across a gap, and
#'     never from a series logged more coarsely than 15 minutes - that would
#'     be inventing readings, which is Product 3's business
#'   ACCUMULATED - from a finer series, the sum of the readings in the 15
#'     minutes ending at the quarter hour, only if all of them are present: a
#'     partial sum would undercount the rain without saying so
#'   MAXIMUM / MINIMUM - the same, taking the highest or lowest
#'
#' A series of either of the last kinds that is not on the quarter hour and
#' not finer than it cannot be aligned without inventing, and is reported.
#'
#' @param when POSIXct, UTC
#' @param value Numeric
#' @param kind Character
#' @param source_file Character, per reading
#' @param conflict Logical, per reading
#' @return List: rows (data frame of quarter hours this series covers -
#'   datetime, value, recorded, source_file, conflict), method (how it was
#'   aligned), problem (NA, or why it could not be)
align_to_grid <- function(when, value, kind, source_file, conflict) {
  t <- as.numeric(when)
  o <- order(t)
  t <- t[o]; v <- value[o]; f <- source_file[o]; c <- conflict[o]
  native <- observed_interval(t)
  on_grid <- all(t %% P2_STEP == 0)
  empty <- list(rows = data.frame(datetime = as.POSIXct(character(0), tz = "UTC"),
                                  value = numeric(0), recorded = logical(0),
                                  source_file = character(0), conflict = logical(0)),
                method = NA_character_, problem = NA_character_)
  if (length(t) == 0) return(empty)
  if (is.na(native)) native <- P2_STEP

  as_rows <- function(q, val, rec, file, conf) {
    data.frame(datetime = as.POSIXct(q, origin = "1970-01-01", tz = "UTC"),
               value = val, recorded = rec, source_file = file, conflict = conf,
               stringsAsFactors = FALSE)
  }

  q <- seq(ceiling(t[1] / P2_STEP) * P2_STEP, floor(t[length(t)] / P2_STEP) * P2_STEP,
           by = P2_STEP)
  if (length(q) == 0) return(empty)

  #### Readings that sit on the quarter hour, any kind ####
  exact <- match(q, t)

  if (kind == "instantaneous") {
    val <- v[exact]; rec <- !is.na(exact); file <- f[exact]; conf <- c[exact]
    method <- if (on_grid) "on the quarter hour" else NA_character_

    # Between two readings no more than 15 minutes apart
    need <- is.na(exact)
    if (any(need)) {
      j <- findInterval(q[need], t)
      ok <- j >= 1 & j < length(t)
      jj <- ifelse(ok, j, 1)
      gap <- t[pmin(jj + 1, length(t))] - t[jj]
      ok <- ok & gap <= P2_STEP + 60
      w <- (q[need] - t[jj]) / gap
      interp <- v[jj] + (v[pmin(jj + 1, length(t))] - v[jj]) * w
      idx <- which(need)
      val[idx[ok]]  <- interp[ok]
      rec[idx[ok]]  <- TRUE
      file[idx[ok]] <- f[jj[ok]]
      conf[idx[ok]] <- c[jj[ok]] | c[pmin(jj + 1, length(t))[ok]]
      if (any(ok)) method <- "interpolated to the quarter hour"
    }
    if (is.na(method)) method <- "on the quarter hour"
    keep <- rec
    return(list(rows = as_rows(q[keep], val[keep], rec[keep], file[keep], conf[keep]),
                method = method, problem = NA_character_))
  }

  #### Accumulated, maximum, minimum ####
  if (on_grid && native >= P2_STEP) {
    keep <- !is.na(exact)
    return(list(rows = as_rows(q[keep], v[exact[keep]], TRUE, f[exact[keep]], c[exact[keep]]),
                method = "on the quarter hour", problem = NA_character_))
  }
  if (native < P2_STEP && (P2_STEP %% native) == 0 && all(t %% native == 0)) {
    expected <- P2_STEP / native
    bin <- ceiling(t / P2_STEP) * P2_STEP     # the quarter hour each reading ends in
    agg <- switch(kind, accumulated = sum, maximum = max, minimum = min)
    # One grouped pass, not a search per quarter hour - a year of 5-minute
    # readings is a hundred thousand of them
    qs <- sort(unique(bin))
    g <- match(bin, qs)
    n_in <- tabulate(g, length(qs))
    n_na <- tabulate(g[is.na(v)], length(qs))
    val <- as.numeric(tapply(v, g, function(x) agg(x)))
    val[n_in != expected | n_na > 0] <- NA_real_
    last <- !duplicated(g, fromLast = TRUE)
    file <- f[last][order(g[last])]
    conf <- as.logical(tapply(c, g, any))
    return(list(rows = as_rows(qs, val, TRUE, file, conf),
                method = paste0(switch(kind, accumulated = "summed", maximum = "highest",
                                       minimum = "lowest"), " from ", native / 60,
                                "-minute readings"),
                problem = NA_character_))
  }
  list(rows = empty$rows, method = NA_character_,
       problem = paste0("a ", kind, " series logged every ", round(native / 60, 2),
                        " minutes, not on the quarter hour, cannot be aligned without inventing"))
}

#' Product 2 for one station and variable, on a continuous quarter-hour grid
#'
#' Each device's stint is aligned on its own - a logger replaced partway
#' through can have a different interval and phase - and the stints are laid
#' onto one grid running from the station's first reading to its last. A
#' quarter hour no stint covers is a row flagged `missing` with no device: the
#' gap is a row, not two rows far apart.
#'
#' @param readings Attributed readings for one station and variable
#' @return List: series (datetime UTC, value, flag, device_serial,
#'   source_file, conflict), methods (one per device), problems
p2_series <- function(readings) {
  kind <- readings$kind[1]
  parts <- list(); methods <- character(0); problems <- character(0)
  for (dev in unique(readings$device_serial)) {
    r <- readings[readings$device_serial == dev, , drop = FALSE]
    a <- align_to_grid(r$datetime, r$value, kind, r$source_file, r$conflict)
    if (!is.na(a$problem)) problems <- c(problems, paste0(dev, ": ", a$problem))
    if (!is.na(a$method)) methods[dev] <- a$method
    if (nrow(a$rows) > 0) parts[[dev]] <- cbind(a$rows, device_serial = dev,
                                                stringsAsFactors = FALSE)
  }
  covered <- if (length(parts) > 0) do.call(rbind, parts) else NULL
  if (is.null(covered) || nrow(covered) == 0) {
    return(list(series = NULL, methods = methods, problems = problems))
  }

  # A quarter hour two stints both claim - a swap logged a little early or
  # late - keeps the value of the device whose stint began later, and is
  # reported
  began <- tapply(as.numeric(covered$datetime), covered$device_serial, min)
  covered <- covered[order(covered$datetime, -began[covered$device_serial]), ]
  dup <- duplicated(covered$datetime)
  if (any(dup)) {
    problems <- c(problems, paste0(sum(dup), " quarter hour(s) covered by two devices; ",
                                   "the later deployment's kept"))
    covered <- covered[!dup, ]
  }

  t <- as.numeric(covered$datetime)
  grid <- seq(min(t), max(t), by = P2_STEP)
  i <- match(grid, t)
  series <- data.frame(
    datetime      = as.POSIXct(grid, origin = "1970-01-01", tz = "UTC"),
    value         = covered$value[i],
    flag          = ifelse(!is.na(i) & !is.na(covered$value[i]), "observed", "missing"),
    device_serial = covered$device_serial[i],
    source_file   = covered$source_file[i],
    conflict      = !is.na(i) & covered$conflict[i] %in% TRUE,
    stringsAsFactors = FALSE)
  list(series = series, methods = methods, problems = problems)
}

#' Every Product 2 series a set of attributed readings makes, by station-year
#'
#' Split by station, variable and the project-local year, so 31 December
#' 23:45 belongs to the year it is in here, not the one it is in at
#' Greenwich.
#'
#' @param readings Data frame from attribute_readings()
#' @param tz Character. The project timezone
#' @return Named list, "<station>|<variable>|<year>" -> list(series, methods,
#'   problems)
assemble_p2 <- function(readings, tz = "America/Puerto_Rico") {
  out <- list()
  for (key in unique(paste(readings$station_id, readings$variable, sep = "|"))) {
    r <- readings[paste(readings$station_id, readings$variable, sep = "|") == key, , drop = FALSE]
    s <- p2_series(r)
    if (is.null(s$series)) {
      out[[paste0(key, "|NA")]] <- s
      next
    }
    yr <- as.integer(format(s$series$datetime, "%Y", tz = tz))
    for (y in sort(unique(yr))) {
      out[[paste(key, y, sep = "|")]] <- list(series = s$series[yr == y, , drop = FALSE],
                                              methods = s$methods, problems = s$problems)
    }
  }
  out
}


#### Writing Product 2 ####

P2_COLUMNS <- c("datetime", "value", "flag", "device_serial", "source_file", "conflict")

#' Which commit of the engine built something
#'
#' With "+uncommitted" when the working copy has changes - a file built from
#' code that was never committed cannot be rebuilt exactly, and should say so.
#'
#' @return Character, NA where git is not available
engine_version <- function() {
  repo <- Sys.getenv("VI_FLO_ENGINE_ROOT")
  if (!exists("git_run")) return(NA_character_)
  head <- git_run(c("rev-parse", "--short", "HEAD"), repo)
  if (is.null(head) || length(head) == 0) return(NA_character_)
  dirty <- git_run(c("status", "--porcelain"), repo)
  paste0(trimws(head[1]), if (length(dirty) > 0) "+uncommitted" else "")
}

#' Writes one Product 2 file
#'
#' Plain local datetimes - the project's zone is part of the context a file
#' is read in, recorded in the manifest. Written to a temporary name and
#' renamed, so a build interrupted halfway never leaves half a file where a
#' whole one is expected.
#'
#' @param series Data frame from p2_series()
#' @param path Character, from product_path()
#' @param tz Character. The project timezone
#' @return TRUE
write_p2_file <- function(series, path, tz = "America/Puerto_Rico") {
  out <- series[, P2_COLUMNS]
  out$datetime <- format(out$datetime, "%Y-%m-%d %H:%M:%S", tz = tz)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".partial")
  con <- gzfile(tmp, "w")
  write.csv(out, con, row.names = FALSE, na = "")
  close(con)
  if (file.exists(path)) file.remove(path)
  if (!file.rename(tmp, path)) stop("Could not move ", tmp, " into place", call. = FALSE)
  TRUE
}

#' Reads a Product 2 file back
#'
#' @param path Character
#' @param tz Character. The project timezone
#' @return Data frame, datetime as POSIXct in the project timezone
read_p2_file <- function(path, tz = "America/Puerto_Rico") {
  x <- read.csv(path, stringsAsFactors = FALSE, na.strings = "",
                colClasses = c(datetime = "character", value = "numeric",
                               flag = "character", device_serial = "character",
                               source_file = "character", conflict = "logical"))
  x$datetime <- as.POSIXct(x$datetime, format = "%Y-%m-%d %H:%M:%S", tz = tz)
  x
}

#' The manifest for one product level
#'
#' One row per file: what it holds, what built it, and anything a reader
#' should know. `products/p<n>/manifest.csv`. A rebuilt file replaces its row;
#' a file removed takes its row with it. An old version is recovered by
#' rebuilding from what its row names, not by keeping a copy.
#'
#' @param product Integer
#' @return Character path
manifest_path <- function(product) {
  file.path(wds("products"), paste0("p", product), "manifest.csv")
}

read_manifest <- function(product) {
  p <- manifest_path(product)
  if (!file.exists(p)) return(NULL)
  read.csv(p, stringsAsFactors = FALSE, colClasses = "character")
}

write_manifest <- function(manifest, product) {
  p <- manifest_path(product)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  manifest <- manifest[order(manifest$station_id, manifest$variable, manifest$year), , drop = FALSE]
  write.csv(manifest, p, row.names = FALSE)
}


#### Building Product 2 ####

#' The Product 1 files that can hold readings for a station-year
#'
#' Every device deployed at the station at any point in the year, and every
#' file of theirs whose span - from its filename - touches the year. A day's
#' margin either side, because a filename's dates are local and a file's
#' first or last reading can sit either side of midnight.
#'
#' @param station Character
#' @param year Integer
#' @param windows Data frame from deployment_windows()
#' @return Character paths
p1_files_for <- function(station, year, windows) {
  tz <- "America/Puerto_Rico"
  y0 <- as.POSIXct(paste0(year, "-01-01 00:00:00"), tz = tz)
  y1 <- as.POSIXct(paste0(year + 1, "-01-01 00:00:00"), tz = tz)
  w <- windows[windows$station_id == station, , drop = FALSE]
  w <- w[w$starts < y1 & (is.na(w$ends) | w$ends >= y0), , drop = FALSE]
  devices <- unique(w$device_serial)
  if (length(devices) == 0) return(character(0))

  files <- c(list.files(wds("device_zentra"), pattern = "_raw\\.rds$", full.names = TRUE),
             list.files(wds("device_hobo"),   pattern = "_raw\\.rds$", full.names = TRUE))
  keep <- vapply(files, function(f) {
    p <- parse_raw_filename(basename(f))
    !is.null(p) && !is.na(p$device_serial) && p$device_serial %in% devices &&
      p$start <= as.Date(y1) && p$end >= as.Date(y0) - 1
  }, logical(1), USE.NAMES = FALSE)
  files[keep]
}

#' The years a station has readings in, by its devices' files
#'
#' @param station Character
#' @param windows Data frame from deployment_windows()
#' @return Integer years
p2_years_for <- function(station, windows) {
  devices <- unique(windows$device_serial[windows$station_id == station])
  files <- c(list.files(wds("device_zentra"), pattern = "_raw\\.rds$"),
             list.files(wds("device_hobo"),   pattern = "_raw\\.rds$"))
  yrs <- integer(0)
  for (f in files) {
    p <- parse_raw_filename(f)
    if (is.null(p) || is.na(p$device_serial) || !p$device_serial %in% devices) next
    yrs <- c(yrs, seq(as.integer(format(p$start, "%Y")), as.integer(format(p$end, "%Y"))))
  }
  sort(unique(yrs))
}

#' Each device's declared interval against the one it actually logged
#'
#' A disagreement means the metadata is wrong or the logger is, and either is
#' worth knowing - it is reported, not resolved.
#'
#' @param readings Attributed readings for one station-variable
#' @param station Character
#' @param metadata Data frame
#' @return Character, one entry per device: "21652379 15 min" or
#'   "21652379 declared 15 min, logged 5 min"
interval_check <- function(readings, station, metadata) {
  vapply(unique(readings$device_serial), function(dev) {
    obs <- observed_interval(readings$datetime[readings$device_serial == dev])
    obs_min <- if (is.na(obs)) NA else round(obs / 60, 2)
    dec <- suppressWarnings(as.numeric(metadata$interval_min[
      metadata$station_id == station & metadata$device_serial == dev]))
    dec <- unique(dec[!is.na(dec)])
    if (length(dec) == 0 || is.na(obs_min)) {
      paste0(dev, " logged ", if (is.na(obs_min)) "?" else obs_min, " min, none declared")
    } else if (any(abs(dec - obs_min) < 0.01)) {
      paste0(dev, " ", obs_min, " min")
    } else {
      paste0(dev, " declared ", paste(dec, collapse = "/"), " min, logged ", obs_min, " min")
    }
  }, character(1), USE.NAMES = FALSE)
}

#' Builds Product 2 for stations and years, writing files and the manifest
#'
#' One station-year at a time: its devices' Product 1 files are read, mapped,
#' deduplicated and attributed, and every variable the station has that year
#' is written. A file from an earlier build that this one no longer produces
#' - a reading reattributed, a variable dropped from the registry - is
#' removed with its manifest row, so the products never hold something the
#' current inputs would not make.
#'
#' @param stations Character, or NULL for every station with a deployment
#' @param years Integer, or NULL for every year each station has files in
#' @param quiet Logical
#' @return Invisibly, a data frame of what was written and anything reported
build_p2 <- function(stations = NULL, years = NULL, quiet = FALSE) {
  product <- 2
  metadata <- load_zentra_metadata()
  windows  <- deployment_windows(metadata)
  pwindows <- port_windows()
  registry <- load_variable_registry()
  log      <- load_download_log()

  meta_dir <- wds("meta_internal")
  md5 <- function(f) if (file.exists(f)) unname(tools::md5sum(f)) else NA_character_
  inputs <- list(
    metadata = md5(file.path(meta_dir, "device_metadata.csv")),
    ports    = md5(file.path(meta_dir, "zentra_ports.csv")),
    registry = md5(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "data", "variables.csv")),
    engine   = engine_version())

  if (is.null(stations)) stations <- sort(unique(windows$station_id))
  manifest <- read_manifest(product)
  report <- list()

  for (st in stations) {
    yrs <- if (is.null(years)) p2_years_for(st, windows) else years
    for (yr in yrs) {
      files <- p1_files_for(st, yr, windows)
      written <- character(0)
      notes <- character(0)

      if (length(files) > 0) {
        r <- read_p1_set(files, log, registry)
        a <- attribute_readings(r, windows, pwindows)
        a <- a[a$station_id == st, , drop = FALSE]
        if (nrow(attr(r, "unmapped")) > 0) {
          notes <- c(notes, paste0("unrecognized: ",
                                   paste(unique(attr(r, "unmapped")$measurement), collapse = ", ")))
        }
        parts <- if (nrow(a) > 0) assemble_p2(a) else list()
        parts <- parts[grepl(paste0("\\|", yr, "$"), names(parts))]

        for (key in names(parts)) {
          s <- parts[[key]]$series
          variable <- strsplit(key, "|", fixed = TRUE)[[1]][2]
          path <- product_path(product, st, variable, yr, create = TRUE)
          write_p2_file(s, path)
          written <- c(written, path)

          ra <- a[a$variable == variable, , drop = FALSE]
          row <- data.frame(
            station_id   = st, variable = variable, year = as.character(yr),
            file         = sub(paste0("^", wds("products"), "/?"), "", path),
            rows         = nrow(s),
            observed     = sum(s$flag == "observed"),
            missing      = sum(s$flag == "missing"),
            conflicts    = sum(s$conflict),
            first        = format(min(s$datetime), "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico"),
            last         = format(max(s$datetime), "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico"),
            timezone     = "America/Puerto_Rico",
            unit         = registry$unit[match(sub("_[0-9]+cm$", "", variable), registry$variable)],
            devices      = paste(unique(s$device_serial[!is.na(s$device_serial)]), collapse = "; "),
            alignment    = paste(paste(names(parts[[key]]$methods), parts[[key]]$methods), collapse = "; "),
            intervals    = paste(interval_check(ra, st, metadata), collapse = "; "),
            problems     = paste(c(parts[[key]]$problems, notes), collapse = "; "),
            source_files = paste(sort(unique(s$source_file[!is.na(s$source_file)])), collapse = "; "),
            metadata_md5 = inputs$metadata, ports_md5 = inputs$ports,
            registry_md5 = inputs$registry, engine = inputs$engine,
            built_utc    = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
            stringsAsFactors = FALSE)
          row[] <- lapply(row, as.character)

          if (!is.null(manifest)) {
            manifest <- manifest[!(manifest$station_id == st & manifest$variable == variable &
                                     manifest$year == as.character(yr)), , drop = FALSE]
          }
          manifest <- if (is.null(manifest)) row else rbind(manifest, row)
          report[[length(report) + 1]] <- row[, c("station_id", "variable", "year", "rows",
                                                  "observed", "missing", "conflicts",
                                                  "intervals", "problems")]
        }
      }

      #### Anything an earlier build made that this one did not ####
      stale <- list_product_files(product, station = st, years = yr)
      stale <- stale[!normalizePath(stale, winslash = "/", mustWork = FALSE) %in%
                       normalizePath(written, winslash = "/", mustWork = FALSE)]
      if (length(stale) > 0) {
        file.remove(stale)
        if (!is.null(manifest)) {
          rel <- sub(paste0("^", wds("products"), "/?"), "", stale)
          manifest <- manifest[!manifest$file %in% rel, , drop = FALSE]
        }
      }

      if (!quiet) {
        cat(sprintf("  %-14s %d  %2d file(s)%s\n", st, yr, length(written),
                    if (length(stale) > 0) paste0(", ", length(stale), " stale removed") else ""))
      }
    }
  }

  if (!is.null(manifest)) write_manifest(manifest, product)
  out <- if (length(report) > 0) do.call(rbind, report) else NULL
  if (!quiet && !is.null(out)) {
    flagged <- out[nzchar(out$problems) | grepl("declared", out$intervals) | out$conflicts != "0", ]
    if (nrow(flagged) > 0) {
      cat("\nWorth a look:\n")
      for (i in seq_len(nrow(flagged))) {
        f <- flagged[i, ]
        cat(sprintf("  %s %s %s: %s%s%s\n", f$station_id, f$variable, f$year,
                    if (f$conflicts != "0") paste0(f$conflicts, " conflict(s) ") else "",
                    if (grepl("declared", f$intervals)) paste0(f$intervals, " ") else "",
                    f$problems))
      }
    }
  }
  invisible(out)
}
