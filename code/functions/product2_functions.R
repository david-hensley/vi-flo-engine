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
# This file holds the first piece: the VARIABLE REGISTRY, and one READER that  #
# turns every shape of Product 1 into the same long form.                      #
#                                                                              #
# Product 1 arrives three ways, and they do not even agree on what time it is: #
#                                                                              #
#   ZENTRA (ZL6)  long already - one row per port, measurement and moment.     #
#                 Times in UTC. Every reading carries an error code            #
#   HOBO (U20)    a HOBOware export - one column per measurement, the unit and #
#                 serial in the header, times as text with a declared offset   #
#   HOBOLINK      parsed during the backfill - one column per measurement, the #
#                 unit in the column NAME, times in project-local time         #
#                                                                              #
# The reader brings all three to UTC, one row per measurement per moment.      #
################################################################################


#### The variable registry ####

#' Every measurement the network reports, and what Product 2 makes of it
#'
#' `data/variables.csv`, one row per source and measurement as reported:
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
  reg
}

# The units a kept variable can be in
CANONICAL_UNITS <- c("degC", "%", "kPa", "m/s", "deg", "W/m2", "mm", "mm/h",
                     "count", "km", "m3/m3", "dS/m", "m")

VARIABLE_KINDS <- c("instantaneous", "accumulated", "maximum")


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
    "degC" = "degC", "C" = "degC", "celsius" = "degC",
    "degF" = "degF", "F" = "degF", "fahrenheit" = "degF",
    "kPa" = "kPa", "kpa" = "kPa", "psi" = "psi", "hPa" = "hPa",
    "mbar" = "hPa", "mb" = "hPa",
    "m/s" = "m/s", "deg" = "deg",
    "W/m2" = "W/m2", "mm" = "mm", "mm/hr" = "mm/h", "mm/h" = "mm/h",
    "km" = "km", "m3/m3" = "m3/m3", "mS/cm" = "mS/cm", "dS/m" = "dS/m",
    "%" = "%", "m" = "m", "ft" = "ft", "mV" = "mV", "raw" = "raw",
    "count" = "count"
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
#' @return "zentra", "hobo" or "hobolink"
p1_shape <- function(data) {
  n <- names(data)
  if (all(c("device_id", "datetime", "measurement", "value") %in% n)) return("zentra")
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
#'   device_serial, datetime (UTC), source, port, measurement, unit, value,
#'   error_code
#'
#' `port` is NA for a HOBO, which has none; `error_code` is NA where the
#' source does not report one. Nothing is renamed, converted or dropped here -
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
                 measurement   = as.character(data$measurement),
                 unit          = as.character(data$unit),
                 value         = as.numeric(data$value),
                 error_code    = if ("error_code" %in% names(data))
                                   as.integer(data$error_code) else NA_integer_,
                 stringsAsFactors = FALSE)
    },
    hobo = {
      l <- hobo_to_long(as.data.frame(data), device_serial)
      data.frame(device_serial = as.character(l$device_serial),
                 datetime      = to_utc(l$datetime),
                 source        = "hobo",
                 port          = NA_integer_,
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
                   measurement   = col,
                   unit          = NA_character_,
                   value         = suppressWarnings(as.numeric(data[[col]])),
                   error_code    = NA_integer_,
                   stringsAsFactors = FALSE)
      }))
    })

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
#'   "unmapped": source, measurement, unit and row count of anything the
#'   registry does not know
map_measurements <- function(long, registry = NULL) {
  if (is.null(registry)) registry <- load_variable_registry()

  key_long <- paste(long$source, long$measurement, sep = "|")
  key_reg  <- paste(registry$source, registry$measurement, sep = "|")
  hit <- match(key_long, key_reg)

  #### Unknown measurements: reported ####
  unknown <- is.na(hit)
  unmapped <- if (any(unknown)) {
    u <- long[unknown, c("source", "measurement", "unit")]
    agg <- aggregate(list(rows = rep(1L, nrow(u))), u[, c("source", "measurement")], sum)
    agg
  } else {
    data.frame(source = character(0), measurement = character(0), rows = integer(0))
  }

  #### Dropped and unknown: removed ####
  keep <- !unknown & registry$keep[hit] %in% TRUE
  out <- long[keep, , drop = FALSE]
  r <- registry[hit[keep], , drop = FALSE]

  out$variable <- r$variable
  out$kind     <- r$kind
  out$depth    <- r$depth

  #### Units ####
  from <- normalize_unit(out$unit)
  from[from == "" & !is.na(r$source_unit)] <- r$source_unit[from == "" & !is.na(r$source_unit)]
  # A count arrives with no unit at all
  from[from == "" & r$unit == "count"] <- "count"
  to <- r$unit

  pairs <- unique(data.frame(from = from, to = to, variable = out$variable,
                             stringsAsFactors = FALSE))
  for (i in seq_len(nrow(pairs))) {
    sel <- from == pairs$from[i] & to == pairs$to[i]
    out$value[sel] <- tryCatch(
      convert_units(out$value[sel], pairs$from[i], pairs$to[i]),
      error = function(e) {
        stop("Cannot convert ", pairs$variable[i], ": ", conditionMessage(e),
             call. = FALSE)
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
