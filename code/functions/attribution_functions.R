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
# Each row of device_metadata is a deployment, from its deploy_datetime to its #
# end_datetime - written when the row is retired, at the moment the logger     #
# actually left - or open while it runs. A logger removed in October and       #
# redeployed in February spent the months between out of the water, often     #
# still logging in storage, and those readings belong to no station.           #
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

  # Each deployment ends where its row says it did. A retired row with no
  # end is a gap in the record, not an open deployment: it is reported, and
  # left open so that nothing is dropped silently - validate_metadata() names
  # it
  m <- m[order(m$device_serial, m$deploy_datetime), , drop = FALSE]
  terminal <- tolower(m$status) %in% TERMINAL_STATUSES
  ends <- m$end_datetime
  basis <- ifelse(!is.na(ends), "end", ifelse(terminal, "unknown", "open"))

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

  # An excluded sensor was plugged in, but its readings are never used - see
  # excluded_port_windows()
  p <- ports[!is.na(ports$sensor) & ports$sensor != "none" &
               !ports$status %in% "excluded", , drop = FALSE]
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


#' When each excluded port was excluded
#'
#' An excluded sensor was plugged in and recorded, but nothing it measured is
#' ever used - the ECRN-50 rain gauges on the early vwc loggers. Its readings
#' are set aside before attribution, so they are neither placed on a station
#' nor reported as unexplained: what they are is already written down.
#'
#' A blank valid_from or valid_to - an excluded port's dates are often not
#' known - takes its deployment's start or end.
#'
#' @param ports Data frame from load_zentra_ports_data(), or NULL to load
#' @param windows Data frame from deployment_windows(), or NULL to compute
#' @return Data frame: device_serial, port, starts, ends
excluded_port_windows <- function(ports = NULL, windows = NULL) {
  if (is.null(ports)) ports <- load_zentra_ports_data()
  if (is.null(windows)) windows <- deployment_windows()
  x <- ports[ports$status %in% "excluded", , drop = FALSE]
  at <- match(x$unique_id, windows$unique_id)
  starts <- x$valid_from
  ends   <- x$valid_to
  starts[is.na(starts)] <- windows$starts[at][is.na(starts)]
  ends[is.na(ends)]     <- windows$ends[at][is.na(ends)]
  data.frame(device_serial = x$sn, port = x$port, starts = starts, ends = ends,
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
    if (!inherits(x, "POSIXct")) x <- as.POSIXct(x, tz = PROJECT_TZ)
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


#' The timezone a HOBOware export declares for its timestamps
#'
#' "Date Time, GMT-04:00" says what the times mean - better evidence than any
#' assumption, since a file exported on a laptop set to another zone would
#' otherwise be read hours out, silently. As an Etc/GMT zone, whose signs run
#' backwards: GMT-04:00 is Etc/GMT+4.
#'
#' @param header Character. The datetime column's name
#' @return Character zone, or NA if the header declares none
hobo_declared_tz <- function(header) {
  offset <- regmatches(header, regexpr("GMT\\s*[+-]\\s*[0-9]{1,2}:?[0-9]{2}", header))
  if (length(offset) != 1) return(NA_character_)
  hours <- as.integer(sub(".*?([0-9]{1,2}):?[0-9]{2}.*", "\\1", offset))
  paste0("Etc/GMT", if (grepl("-", offset)) "+" else "-", hours)
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

  # The zone the export declares, or the project's if it declares none
  tzspec <- hobo_declared_tz(names(data)[dt_col])
  if (is.na(tzspec)) tzspec <- PROJECT_TZ

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
