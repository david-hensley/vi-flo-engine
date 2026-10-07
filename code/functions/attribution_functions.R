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
#' @param port Integer vector, one per reading
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

  pw <- pwindows[pwindows$device_serial == device_serial, , drop = FALSE]
  dw <- windows[windows$device_serial == device_serial, , drop = FALSE]
  if (nrow(pw) == 0 || nrow(dw) == 0) return(out)

  pw$starts <- as_utc(pw$starts); pw$ends <- as_utc(pw$ends)
  dw$starts <- as_utc(dw$starts); dw$ends <- as_utc(dw$ends)

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
