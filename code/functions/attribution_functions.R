################################################################################
#                              ATTRIBUTION                                     #
#                                                                              #
# Product 1 records what a DEVICE measured. Product 2 records what a STATION   #
# measured. Attribution is the step between, and the question it answers is:   #
#                                                                              #
#     this device, this port, this moment - which station, which variable?     #
#                                                                              #
#                                                                              #
# WHY PORT AND NOT JUST DEVICE                                                 #
#                                                                              #
# One ZL6 can serve two stations at once. z6-13368 has an ATMOS on port 1 and  #
# TEROS sensors on ports 3-6: the first is uvi_weather, the rest are           #
# uvi_vwc1, and both are live simultaneously. No rule based on device and time #
# can separate them - the port is what distinguishes one station from the      #
# other.                                                                       #
#                                                                              #
# So the path runs: port -> sensor type (from zentra_ports), then device +     #
# type + time -> station (from device_metadata).                               #
#                                                                              #
#                                                                              #
# DEPLOYMENT WINDOWS                                                           #
#                                                                              #
# device_metadata records when a deployment began and not when it ended, so    #
# the end is derived:                                                          #
#                                                                              #
#   1. the next row for the same device AND station type - not simply the next #
#      row, because uvi_vwc1 starting in 2023 did not end uvi_weather, which   #
#      began in 2021 and runs still                                            #
#   2. for a terminal row with no successor, its last_visit                    #
#   3. otherwise open - the deployment continues                               #
#                                                                              #
# A derived end is softer evidence than a recorded start, and (2) in           #
# particular is only as good as the last logged visit.                         #
#                                                                              #
#                                                                              #
# WHAT GOES UNATTRIBUTED                                                       #
#                                                                              #
# A reading that resolves to no station is not an error. z6-13391 recorded for #
# two years as a TEROS 21 experiment logger and then at an Agrifest            #
# demonstration before becoming bta2_vwc1 in October 2023; metadata has no row #
# for those lives, so those readings belong to no VI-FLO station and should    #
# not be forced into one. They are reported, not discarded - Product 1 keeps   #
# them regardless.                                                             #
################################################################################


TERMINAL_STATUSES <- c("removed", "replaced", "relocated", "decommissioned")


#' Every deployment window, with derived ends
#'
#' One row per device-station-period: which station a device served, of which
#' type, between which moments.
#'
#' @param metadata Data frame, or NULL to load
#' @return Data frame: device_serial, station_id, station_type, unique_id,
#'   starts, ends (NA where open), end_basis
deployment_windows <- function(metadata = NULL) {

  if (is.null(metadata)) metadata <- load_zentra_metadata()

  m <- metadata[!is.na(metadata$deploy_datetime), , drop = FALSE]
  if (nrow(m) == 0) {
    return(data.frame(device_serial = character(0), station_id = character(0),
                      station_type = character(0), unique_id = character(0),
                      starts = as.POSIXct(character(0)),
                      ends = as.POSIXct(character(0)),
                      end_basis = character(0), stringsAsFactors = FALSE))
  }

  # Within a device AND station type, rows are sequential: one replaces the
  # last. Across types they are concurrent, which is the co-located case.
  m$key <- paste(m$device_serial, tolower(m$station_type), sep = "|")
  m <- m[order(m$key, m$deploy_datetime), , drop = FALSE]

  ends <- as.POSIXct(rep(NA, nrow(m)), tz = "America/Puerto_Rico")
  basis <- rep(NA_character_, nrow(m))

  for (i in seq_len(nrow(m))) {
    later <- which(m$key == m$key[i] & m$deploy_datetime > m$deploy_datetime[i])

    if (length(later) > 0) {
      ends[i] <- min(m$deploy_datetime[later])
      basis[i] <- "successor"
    } else if (tolower(m$status[i]) %in% TERMINAL_STATUSES) {
      if (!is.na(m$last_visit[i])) {
        ends[i] <- as.POSIXct(paste(m$last_visit[i], "23:59:59"),
                              tz = "America/Puerto_Rico")
        basis[i] <- "last visit"
      } else {
        # Terminal, no successor, no visit recorded. The deployment ended at
        # some unknown point; leaving it open would attribute readings to a
        # station that was gone.
        basis[i] <- "unknown"
      }
    } else {
      basis[i] <- "open"
    }
  }

  data.frame(device_serial = m$device_serial,
             station_id    = m$station_id,
             station_type  = tolower(m$station_type),
             unique_id     = m$unique_id,
             starts        = m$deploy_datetime,
             ends          = ends,
             end_basis     = basis,
             stringsAsFactors = FALSE)
}


#' What each port was, over time
#'
#' zentra_ports already records valid_from and valid_to, so this is mostly a
#' tidy: active sensors only, with the variable name a reading will carry at
#' Product 2.
#'
#' @param ports Data frame, or NULL to load
#' @return Data frame: device_serial, port, type, sensor, depth_cm, variable,
#'   starts, ends
port_windows <- function(ports = NULL) {

  if (is.null(ports)) ports <- load_zentra_ports_data()

  p <- ports[!is.na(ports$sensor) & ports$sensor != "none", , drop = FALSE]
  if (nrow(p) == 0) {
    return(data.frame(device_serial = character(0), port = integer(0),
                      type = character(0), sensor = character(0),
                      depth_cm = numeric(0), variable = character(0),
                      starts = as.POSIXct(character(0)),
                      ends = as.POSIXct(character(0)),
                      stringsAsFactors = FALSE))
  }

  data.frame(device_serial = p$sn,
             port          = p$port,
             type          = tolower(p$type),
             sensor        = p$sensor,
             depth_cm      = p$depth_cm,
             starts        = p$valid_from,
             ends          = p$valid_to,
             stringsAsFactors = FALSE)
}


#' Which station a device's port belonged to at a given moment
#'
#' Vectorised: give it the timestamps of a whole file at once rather than
#' calling it per reading.
#'
#' @param device_serial Character, length one
#' @param port Integer vector, one per reading - NA throughout for a device
#'   with no ports, such as a HOBO
#' @param when POSIXct vector, one per reading
#' @param windows Data frame from deployment_windows(), or NULL to compute
#' @param pwindows Data frame from port_windows(), or NULL to compute
#' @return Data frame, one row per reading: station_id, station_type,
#'   sensor, depth_cm
resolve_readings <- function(device_serial, port, when,
                             windows = NULL, pwindows = NULL) {

  if (is.null(windows))  windows  <- deployment_windows()
  if (is.null(pwindows)) pwindows <- port_windows()

  # Everything to UTC before comparing. Product 1 timestamps are UTC and
  # metadata datetimes are Atlantic; comparing them directly gives the right
  # answer, since POSIXct compares instants, but warns on every operation - and
  # a correct result that depends on a warning being ignored is one keystroke
  # from becoming an incorrect one.
  as_utc <- function(x) {
    if (!inherits(x, "POSIXct")) x <- as.POSIXct(x, tz = "America/Puerto_Rico")
    attr(x, "tzone") <- "UTC"
    x
  }
  when <- as_utc(when)

  n <- length(when)
  out <- data.frame(station_id = rep(NA_character_, n),
                    station_type = rep(NA_character_, n),
                    sensor = rep(NA_character_, n),
                    depth_cm = rep(NA_real_, n),
                    stringsAsFactors = FALSE)

  dw <- windows[windows$device_serial == device_serial, , drop = FALSE]
  if (nrow(dw) == 0) return(out)
  dw$starts <- as_utc(dw$starts); dw$ends <- as_utc(dw$ends)

  #### A device with no ports ####
  # A HOBO has one sensor assembly and serves one station at a time, so there
  # is nothing for a port to distinguish. Resolution is device and moment
  # alone - zentra_ports holds nothing for these serials, and should not.
  pw <- pwindows[pwindows$device_serial == device_serial, , drop = FALSE]

  if (nrow(pw) == 0) {
    for (i in seq_len(nrow(dw))) {
      in_dep <- when >= dw$starts[i] &
                (is.na(dw$ends[i]) | when < dw$ends[i])
      in_dep[is.na(in_dep)] <- FALSE
      if (!any(in_dep)) next
      out$station_id[in_dep]   <- dw$station_id[i]
      out$station_type[in_dep] <- dw$station_type[i]
    }
    return(out)
  }

  pw$starts <- as_utc(pw$starts); pw$ends <- as_utc(pw$ends)

  # Port first: what kind of sensor was on it, and what was it measuring
  for (i in seq_len(nrow(pw))) {
    in_port <- port == pw$port[i] &
               when >= pw$starts[i] &
               (is.na(pw$ends[i]) | when < pw$ends[i])
    in_port[is.na(in_port)] <- FALSE
    if (!any(in_port)) next

    out$station_type[in_port] <- pw$type[i]
    out$sensor[in_port]       <- pw$sensor[i]
    out$depth_cm[in_port]     <- pw$depth_cm[i]
  }

  # Then the station: the deployment of that type covering that moment
  for (i in seq_len(nrow(dw))) {
    in_dep <- out$station_type == dw$station_type[i] &
              when >= dw$starts[i] &
              (is.na(dw$ends[i]) | when < dw$ends[i])
    in_dep[is.na(in_dep)] <- FALSE
    if (!any(in_dep)) next

    out$station_id[in_dep] <- dw$station_id[i]
  }

  out
}


#' The variable name a reading carries at Product 2
#'
#' A measurement plus, where the sensor has one, its depth. `vwc_30cm` rather
#' than `port_3` - which is the whole point of Product 2, and why the depth
#' must come from metadata at this moment rather than having been baked into
#' the archive. A corrected depth is then a re-run, not a lost file.
#'
#' @param measurement Character vector, as the device reported it
#' @param depth_cm Numeric vector, NA where the sensor has no depth
#' @return Character vector
variable_name <- function(measurement, depth_cm = NA) {

  base <- tolower(trimws(measurement))

  # The names a reading arrives with, and what VI-FLO calls them
  known <- c(
    "abs pres"              = "abs_pressure",
    "abs pres, barom. comp" = "level",
    "temp"                  = "water_temp",
    "water level"           = "level",
    "water content"         = "vwc",
    "raw vwc"               = "raw_vwc",
    "soil temperature"      = "soil_temp",
    "saturation extract ec" = "soil_ec",
    "bulk ec"               = "soil_ec",
    "precipitation"         = "precip",
    "air temperature"       = "temp",
    "relative humidity"     = "rh",
    "atmospheric pressure"  = "pressure",
    "vapor pressure"        = "vapor_pressure",
    "wind speed"            = "wind_speed",
    "wind direction"        = "wind_direction",
    "gust speed"            = "gust_speed",
    "solar radiation"       = "solar_radiation",
    "lightning activity"    = "lightning_count",
    "lightning distance"    = "lightning_distance",
    "max precip rate"       = "precip_rate_max",
    "battery percent"       = "battery_pct",
    "battery voltage"       = "battery_mv",
    "reference pressure"    = "reference_pressure",
    "logger temperature"    = "logger_temp")

  out <- unname(known[base])

  # Anything unrecognised keeps its own name, tidied. Better a variable called
  # x_axis_level than a reading silently dropped for want of a translation.
  unknown <- is.na(out)
  if (any(unknown)) {
    out[unknown] <- gsub("[^a-z0-9]+", "_", base[unknown])
    out[unknown] <- gsub("^_|_$", "", out[unknown])
  }

  # Depth, where there is one. A TEROS at 30 cm gives vwc_30cm; an ATMOS has
  # no depth and keeps its bare name.
  # Every per-sensor measurement takes the depth, not only the headline one.
  # Four TEROS on one logger all report Raw VWC; without the suffix they
  # collide on a single variable name and three of them vanish.
  has_depth <- !is.na(depth_cm) &
               out %in% c("vwc", "raw_vwc", "soil_temp", "soil_ec")
  out[has_depth] <- paste0(out[has_depth], "_", depth_cm[has_depth], "cm")

  out
}


################################################################################
#                            HOBO FILES                                        #
#                                                                              #
# A third shape again. Where a ZL6 reading names its port and measurement in   #
# columns, a HOBOware export puts everything in the column HEADER:             #
#                                                                              #
#   Abs Pres, kPa (LGR S/N: 21179105, SEN S/N: 21179105, LBL: Pressure)        #
#   ^^^^^^^^  ^^^           ^^^^^^^^                          ^^^^^^^^        #
#   measure   unit          serial                            label           #
#                                                                              #
# And the datetime column declares its own offset - "Date Time, GMT-04:00" -   #
# which is better evidence than assuming the project timezone, and is used.    #
#                                                                              #
# There is no port. A HOBO serves one station at a time, so resolution needs   #
# only the device and the moment.                                             #
#                                                                              #
# What it measures is ABSOLUTE PRESSURE, not water level. Level is derived     #
# from this minus a barometric reference, corrected for the elevation          #
# difference between the gauge and the weather station - which is why level is #
# a derived series rather than something the logger hands over.               #
################################################################################


#' Pulls apart a HOBOware column header
#'
#' @param name Character, one column name
#' @return List with measurement, unit, serial, label - NA where absent
parse_hobo_header <- function(name) {

  none <- list(measurement = NA_character_, unit = NA_character_,
               serial = NA_character_, label = NA_character_)

  # Everything before the first bracket is "Measurement, unit"
  front <- trimws(sub("\\(.*$", "", name))
  if (!nzchar(front)) return(none)

  parts <- strsplit(front, ",", fixed = TRUE)[[1]]
  measurement <- trimws(parts[1])
  unit <- if (length(parts) > 1) trimws(parts[2]) else NA_character_

  inside <- sub("^[^(]*\\(", "", name)
  inside <- sub("\\)[^)]*$", "", inside)

  grab <- function(key) {
    m <- regmatches(inside, regexpr(paste0(key, ":\\s*[^,)]+"), inside))
    if (length(m) == 0) return(NA_character_)
    trimws(sub(paste0("^", key, ":\\s*"), "", m))
  }

  list(measurement = measurement,
       unit        = unit,
       serial      = grab("LGR S/N"),
       label       = grab("LBL"))
}


#' A HOBOware export, in the long shape attribution works with
#'
#' One row per reading per measurement, matching what the ZL6 path produces -
#' not because Product 1 was reshaped, which it was not, but because
#' attribution has to meet somewhere and this is where.
#'
#' @param data Data frame as read from a Product 1 HOBO file
#' @param device_serial Character. Expected serial, for a cross-check
#' @return Data frame: device_serial, datetime, measurement, unit, label, value
hobo_to_long <- function(data, device_serial = NULL) {

  #### The datetime column, and the offset it declares ####
  dt_col <- grep("date.*time|^date$|timestamp", names(data),
                 ignore.case = TRUE)[1]
  if (is.na(dt_col)) {
    stop("No date/time column found. Columns: ",
         paste(names(data), collapse = ", "), call. = FALSE)
  }

  # "Date Time, GMT-04:00" says what the timestamps mean. Taking it is better
  # than assuming the project timezone - a file exported on a laptop set to
  # another zone would otherwise be read four hours out, silently.
  offset <- regmatches(names(data)[dt_col],
                       regexpr("GMT\\s*[+-]\\s*[0-9]{1,2}:?[0-9]{2}",
                               names(data)[dt_col]))

  tzspec <- if (length(offset) == 1) {
    sign <- if (grepl("-", offset)) 1 else -1   # Etc/GMT signs are inverted
    hours <- as.integer(sub(".*?([0-9]{1,2}):?[0-9]{2}.*", "\\1", offset))
    paste0("Etc/GMT", if (sign > 0) "+" else "-", hours)
  } else "America/Puerto_Rico"

  when <- suppressWarnings(as.POSIXct(data[[dt_col]],
                                      format = "%m/%d/%y %I:%M:%S %p",
                                      tz = tzspec))
  if (all(is.na(when))) {
    when <- suppressWarnings(coerce_datetime_flexible(data[[dt_col]], tzspec))
  }
  if (all(is.na(when))) {
    stop("Could not parse the date column '", names(data)[dt_col], "'",
         call. = FALSE)
  }
  attr(when, "tzone") <- "UTC"

  #### Every column that holds a measurement ####
  # A column with a parseable header and numeric content - and a name that is
  # actually a measurement. HOBOware opens every export with a row counter
  # headed "#", which is numeric and parses perfectly well; without excluding
  # it a third of every file would be a sequence from 1 upward, attributed to
  # a station as though it meant something.
  #
  # Excluded by name rather than by guessing: a counter is a counter.
  not_measurements <- c("#", "", "no", "no.", "n", "index", "record")

  out <- list()
  for (i in seq_along(data)) {
    if (i == dt_col) next

    h <- parse_hobo_header(names(data)[i])
    if (is.na(h$measurement) || !nzchar(h$measurement)) next
    if (tolower(trimws(h$measurement)) %in% not_measurements) next

    v <- suppressWarnings(as.numeric(data[[i]]))
    if (all(is.na(v))) next

    # The serial is in the header, so a file can say whose it is. Worth
    # checking against the name it was filed under.
    if (!is.null(device_serial) && !is.na(h$serial) &&
        h$serial != device_serial) {
      warning("Column '", names(data)[i], "' names serial ", h$serial,
              " but the file is filed under ", device_serial, call. = FALSE)
    }

    out[[length(out) + 1]] <- data.frame(
      device_serial = if (!is.na(h$serial)) h$serial else device_serial,
      datetime      = when,
      measurement   = h$measurement,
      unit          = h$unit,
      label         = h$label,
      value         = v,
      stringsAsFactors = FALSE)
  }

  if (length(out) == 0) {
    stop("No measurement columns found. Columns: ",
         paste(names(data), collapse = ", "), call. = FALSE)
  }

  do.call(rbind, out)
}


################################################################################
#                        EVEN SPACING AND GAPS                                 #
#                                                                              #
# A logger records on a schedule, so its readings should arrive at a fixed     #
# interval. In practice they do not always: a reading can be duplicated by a   #
# re-download, lost to a flat battery, or shifted by a clock reset.            #
#                                                                              #
# Product 2 is regular. Every expected moment has a row - with a value where   #
# one was recorded, and flagged `missing` where none was. A gap then reads as  #
# a gap rather than as two rows that happen to be far apart, which is what     #
# makes it countable.                                                          #
#                                                                              #
# No filling here. P2 says what was recorded and what was not; P3 decides      #
# what, if anything, to do about it.                                           #
################################################################################


#' The logging interval for a device over a period
#'
#' Metadata declares it and the timestamps show it, and they can disagree -
#' a logger reconfigured in the field and not logged, most obviously. The
#' declared value is used, and a disagreement is reported rather than silently
#' resolved: a mismatch means the metadata is wrong or the logger is, and
#' either is worth knowing.
#'
#' @param device_serial Character
#' @param when POSIXct vector of the readings actually present
#' @param metadata Data frame, or NULL to load
#' @return List with declared, observed, agree
logging_interval <- function(device_serial, when, metadata = NULL) {

  if (is.null(metadata)) metadata <- load_zentra_metadata()

  declared <- metadata$interval_min[metadata$device_serial == device_serial]
  declared <- unique(declared[!is.na(declared)])
  declared <- if (length(declared) == 1) declared else NA_real_

  observed <- NA_real_
  u <- sort(unique(when))
  if (length(u) > 2) {
    d <- as.numeric(diff(u), units = "mins")
    d <- d[d > 0]
    # The mode rather than the mean or median: a run of readings at the real
    # interval, however many gaps surround them, is what the logger was set to.
    if (length(d) > 0) {
      tab <- table(round(d, 3))
      observed <- as.numeric(names(tab)[which.max(tab)])
    }
  }

  list(declared = declared,
       observed = observed,
       agree    = !is.na(declared) && !is.na(observed) &&
                  abs(declared - observed) < 0.001)
}


#' One row per expected moment, over a period
#'
#' Duplicates dropped, missing moments inserted. The grid runs from the first
#' reading to the last, on the interval given - not from the deployment dates,
#' because a station deployed in March whose logger only started in April
#' should not carry a month of rows asserting it recorded nothing.
#'
#' @param when POSIXct vector
#' @param value Numeric vector, same length
#' @param interval_min Numeric. The expected interval
#' @param from,to POSIXct. Grid bounds, or NULL for the data's own extent
#' @return Data frame: datetime, value, flag
regularise <- function(when, value, interval_min, from = NULL, to = NULL) {

  if (is.na(interval_min) || interval_min <= 0) {
    stop("A logging interval is required to regularise", call. = FALSE)
  }

  keep <- !is.na(when)
  when <- when[keep]; value <- value[keep]

  if (length(when) == 0) {
    return(data.frame(datetime = as.POSIXct(character(0), tz = "UTC"),
                      value = numeric(0), flag = character(0),
                      stringsAsFactors = FALSE))
  }

  # A duplicated timestamp is a re-download, not two readings. The first is
  # kept: later copies of the same moment have been through more handling.
  dup <- duplicated(when)
  when <- when[!dup]; value <- value[!dup]

  ord <- order(when)
  when <- when[ord]; value <- value[ord]

  step <- interval_min * 60
  start <- if (is.null(from)) min(when) else from
  end   <- if (is.null(to))   max(when) else to

  # Snapped to the interval, so a clock a few seconds out does not shift every
  # subsequent row onto its own grid
  start <- as.POSIXct(round(as.numeric(start) / step) * step,
                      origin = "1970-01-01", tz = "UTC")

  grid <- seq(start, end, by = step)

  nearest <- round((as.numeric(when) - as.numeric(start)) / step)
  nearest[nearest < 0 | nearest >= length(grid)] <- NA

  out <- data.frame(datetime = grid,
                    value = rep(NA_real_, length(grid)),
                    flag = rep("missing", length(grid)),
                    stringsAsFactors = FALSE)

  placed <- !is.na(nearest)
  out$value[nearest[placed] + 1] <- value[placed]
  out$flag[nearest[placed] + 1] <- "observed"

  # A value that is NA in the source is not the same as a moment with no
  # reading: the logger recorded, and recorded nothing usable.
  recorded_na <- placed & is.na(value)
  if (any(recorded_na)) out$flag[nearest[recorded_na] + 1] <- "missing"

  out
}


#' Every gap in a regularised series
#'
#' @param regular Data frame from regularise()
#' @param interval_min Numeric
#' @return Data frame: starts, ends, n, minutes
find_gaps <- function(regular, interval_min) {

  miss <- regular$flag == "missing"
  if (!any(miss)) {
    return(data.frame(starts = as.POSIXct(character(0), tz = "UTC"),
                      ends = as.POSIXct(character(0), tz = "UTC"),
                      n = integer(0), minutes = numeric(0),
                      stringsAsFactors = FALSE))
  }

  r <- rle(miss)
  ends_at <- cumsum(r$lengths)
  starts_at <- ends_at - r$lengths + 1

  keep <- r$values
  data.frame(starts  = regular$datetime[starts_at[keep]],
             ends    = regular$datetime[ends_at[keep]],
             n       = r$lengths[keep],
             minutes = r$lengths[keep] * interval_min,
             stringsAsFactors = FALSE)
}
