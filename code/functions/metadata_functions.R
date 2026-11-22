# Local metadata management functions
# Load, validate, edit, local metadata files

######################          LOADING FUNCTIONS         ######################

# Every loader reads through read_table() in table_functions.R, which knows
# where each table lives and what type each column is, and refuses a value it
# cannot read rather than turning it into NA.
#
# Where a loader passes `as_text`, it returns those columns as text, as it did
# before the data layer, because some of its callers still treat them as text.
# Each is a column whose callers have yet to move onto its proper type.

#' Loads device_metadata.csv
#'
#' Datetimes as POSIXct in the project time zone, dates as Date,
#' metadata_approved as logical. last_reviewed_utc comes back as text: its
#' callers assign formatted text into it.
#'
#' @return Data frame
load_zentra_metadata <- function(){
  read_table("device_metadata", as_text = "last_reviewed_utc")
}

#' Loads zentra_ports.csv
#'
#' Each row names the deployment its sensor serves, by unique_id. For the
#' callers that ask by logger and kind of station, two columns are added from
#' that deployment, never stored: `sn`, its logger's serial, and `type`, its
#' station type. save_zentra_ports() drops them again.
#'
#' valid_from and valid_to as POSIXct in the project time zone.
#'
#' @return Data frame. Port configuration history
load_zentra_ports_data <- function(){
  ports <- read_table("zentra_ports")
  meta <- read_table("device_metadata", remember = FALSE)
  at <- match(ports$unique_id, meta$unique_id)
  ports$sn   <- meta$device_serial[at]
  ports$type <- tolower(meta$station_type[at])
  ports
}

#' Writes the port table, without the columns load_zentra_ports_data() adds
#'
#' @param ports Data frame, as load_zentra_ports_data() returns it
#' @param intent Character. What the caller was doing
#' @return Invisibly TRUE; an error if the write was refused
save_zentra_ports <- function(ports, intent = NULL) {
  ports <- ports[, names(TABLE_SCHEMA$zentra_ports$columns), drop = FALSE]
  write_table_or_stop("zentra_ports", ports, intent = intent)
}

#' The deployment a logger's sensors of one kind serve now
#'
#' On a ZL6 shared between a weather and a vwc station, the ATMOS serves the
#' weather row and the TEROS sensors the vwc row: the kind of sensor says
#' which of the logger's active rows a port belongs to.
#'
#' @param device_serial Character
#' @param type Character. A station type - "weather", "vwc"
#' @param metadata Data frame. Optional
#' @return Character unique_id; an error if the logger has no active row of
#'   that type
port_deployment <- function(device_serial, type, metadata = NULL) {
  if (is.null(metadata)) metadata <- read_table("device_metadata", remember = FALSE)
  terminal <- TERMINAL_STATUSES
  rows <- metadata[!is.na(metadata$device_serial) & metadata$device_serial == device_serial &
                     tolower(metadata$station_type) == tolower(type) &
                     !tolower(metadata$status) %in% terminal, , drop = FALSE]
  if (nrow(rows) == 0) {
    stop("logger ", device_serial, " has no active ", type, " station for this sensor",
         call. = FALSE)
  }
  rows$unique_id[which.max(as.numeric(rows$deploy_datetime))]
}

#' One port row, with the columns load_zentra_ports_data() adds
new_port_row <- function(unique_id, port, sensor, depth_cm, status, valid_from,
                         device_serial, type) {
  data.frame(unique_id = unique_id, port = as.integer(port), sensor = sensor,
             depth_cm = suppressWarnings(as.numeric(depth_cm)),
             status = if (is.null(status) || is.na(status) || !nzchar(status)) NA_character_
                      else as.character(status),
             valid_from = as.POSIXct(valid_from, tz = PROJECT_TZ),
             valid_to = as.POSIXct(NA, tz = PROJECT_TZ),
             sn = device_serial, type = tolower(type), stringsAsFactors = FALSE)
}

#' Loads download_log.csv
#'
#' start_date and end_date as POSIXct in the project time zone. timestamp_utc
#' comes back as text, as its callers expect.
#'
#' The previous version also parsed a column called `timestamp`, which the log
#' stopped having when it became `timestamp_utc`. R's partial matching of `$`
#' quietly handed it `timestamp_utc` instead, and it was parsed as LOCAL time,
#' so the returned table carried an extra column four hours wrong. Nothing
#' read it, and it is gone.
#'
#' @return Data frame
load_download_log <- function() {
  read_table("download_log", as_text = "timestamp_utc")
}

#' Loads maintenance_log.csv
#'
#' timestamp as POSIXct in the project time zone, field_visit_date as Date,
#' ports_updated as logical.
#'
#' @return Data frame
load_maintenance_log <- function() {
  read_table("maintenance_log")
}

######################          BACK-UP FUNCTIONS         ######################

#' Appends one row to a log, by column name
#'
#' Through append_rows() in table_functions.R: each value under its own
#' column, a column the row lacks left empty, a column the table lacks
#' refused, and nothing appended to a file whose header is not the schema's.
#' A log row written by position once landed two columns early - the HOBO
#' ingest's row lacked run_id and device_serial, added after it was written -
#' and the October 2026 offloads were never seen as logged.
#'
#' @param entry One-row data frame
#' @param log_file Character. A table's file - which table is told by its name
#' @return Invisibly TRUE; an error naming any column the table lacks
append_log_row <- function(entry, log_file) {
  name <- names(TABLE_SCHEMA)[vapply(TABLE_SCHEMA, function(s) s$file, "") == basename(log_file)]
  if (length(name) != 1) {
    stop(basename(log_file), " is not a table the data layer knows", call. = FALSE)
  }
  append_rows(name, entry, path = log_file)
}

######################          EDITING FUNCTIONS         ######################

#' Sets metadata_approved flag for device(s) in device_metadata.csv
#' Can approve single device, all devices at a station, or all devices
#' @param device_serial Character. Device serial number (optional if station_id provided)
#' @param station_id Character. Station ID - approves all devices at station (optional)
#' @param approve_all Logical. If TRUE, approves all devices (default FALSE)
#' @param value Logical. TRUE to approve, FALSE to un-approve (default TRUE)
#' @return Invisible TRUE on success
set_metadata_approved <- function(device_serial = NULL, station_id = NULL, approve_all = FALSE, value = TRUE) {
  # Load metadata
  metadata <- load_zentra_metadata()
  # Determine which rows to update
  if (approve_all) {
    # Approve all devices
    rows_to_update <- rep(TRUE, nrow(metadata))
    message("Setting metadata_approved = ", value, " for ALL devices")
  } else if (!is.null(station_id)) {
    # ACTIVE devices at this station only. A terminal row describes a
    # deployment that has ended - nobody reviewed it today, and re-dating it
    # would claim they had. Its own approval and date stay as they were when
    # it was current, which is what makes its archived data attributable.
    terminal <- TERMINAL_STATUSES
    rows_to_update <- metadata$station_id == station_id &
                      !tolower(metadata$status) %in% terminal
    if (sum(rows_to_update) == 0) {
      stop("No active devices found for station: ", station_id, call. = FALSE)
    }
    message("Setting metadata_approved = ", value, " for station: ", station_id, 
            " (", sum(rows_to_update), " device(s))")
  } else if (!is.null(device_serial)) {
    # Active rows for this serial, for the same reason. A serial can carry a
    # terminal row plus its successor, or serve two stations at once.
    terminal <- TERMINAL_STATUSES
    rows_to_update <- metadata$device_serial == device_serial &
                      !tolower(metadata$status) %in% terminal
    if (sum(rows_to_update) == 0) {
      stop("No active row found for device: ", device_serial, call. = FALSE)
    }
    message("Setting metadata_approved = ", value, " for device: ", device_serial)
  } else {
    stop("Must provide device_serial, station_id, or set approve_all = TRUE", call. = FALSE)
  }
  # Update the flag AND when it was set. The flag alone says someone once
  # confirmed the record; it does not say whether that was this morning or in
  # March. The pair answers the question that matters - how long since a human
  # looked at this station.
  #
  # The timestamp updates for FALSE as well as TRUE. "I looked and something is
  # missing" is as much a review as "I looked and it is fine".
  metadata$metadata_approved[rows_to_update] <- value

  if ("last_reviewed_utc" %in% names(metadata)) {
    # UTC: a review happens at a keyboard that could be anywhere. The station's
    # own times stay local, because they belong to a place.
    metadata$last_reviewed_utc[rows_to_update] <-
      format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  }

  # save_device_metadata() handles whatever datetime columns are present.
  save_device_metadata(metadata)
  message("✓ Recorded metadata review for device_metadata.csv")
  invisible(TRUE)
}

#' Writes a maintenance entry to maintenance_log.csv
#'
#' An entry names the deployment it concerns by unique_id - a logger can have
#' several rows at one station, and a serial alone cannot say which.
#'
#' @param field_visit_date Character or Date. The day of the visit
#' @param station_id Character
#' @param unique_id Character. The deployment the entry concerns
#' @param action_type Character. One of MAINTENANCE_ACTIONS
#' @param details Character. Free text
#' @param logged_by Character. Initials
#' @return Invisible TRUE on success
write_maintenance_entry <- function(field_visit_date, station_id, unique_id,
                                    action_type, details, logged_by) {
  new_entry <- data.frame(
    logged_utc       = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    field_visit_date = as.character(field_visit_date),
    station_id       = station_id,
    unique_id        = unique_id,
    action_type      = action_type,
    details          = details,
    logged_by        = logged_by,
    stringsAsFactors = FALSE
  )

  # By column name, through the data layer
  append_rows("maintenance_log", new_entry)

  message("✓ Maintenance entry logged for ", station_id, " (", unique_id, ")")
  invisible(TRUE)
}


#' The deployment a logger was serving at a station on a given day
#'
#' A serial does not name a row: a logger can have several at one station -
#' moved within it, or deployed there twice. Which one is meant is told by the
#' day, through the same deployment windows Product 2 uses. Where two cover the
#' day - the old position ends and the new one begins on the day of a move -
#' the later is taken: what a move, a replacement or a new deployment records
#' is the deployment it created. Where none covers it, the latest of the
#' logger's rows at the station.
#'
#' Reads the device table without remembering it, so asking does not refresh
#' what a caller's own read of the table has the write guard expect.
#'
#' @param device_serial Character
#' @param station_id Character
#' @param when Date, or text a date can be read from
#' @param metadata Data frame. Optional; read if not given
#' @return Character unique_id, or NA if the logger has no row at the station
resolve_deployment <- function(device_serial, station_id, when, metadata = NULL) {
  if (is.null(metadata)) metadata <- read_table("device_metadata", remember = FALSE)
  rows <- metadata[!is.na(metadata$device_serial) & metadata$device_serial == device_serial &
                     !is.na(metadata$station_id) & metadata$station_id == station_id, ,
                   drop = FALSE]
  if (nrow(rows) == 0) return(NA_character_)
  if (nrow(rows) == 1) return(rows$unique_id)

  w <- deployment_windows(metadata)
  w <- w[w$unique_id %in% rows$unique_id, , drop = FALSE]
  day0 <- as.POSIXct(paste(as.Date(when), "00:00:00"), tz = PROJECT_TZ)
  day1 <- day0 + 86400
  covering <- w[w$starts < day1 & (is.na(w$ends) | w$ends >= day0), , drop = FALSE]
  pool <- if (nrow(covering) > 0) covering else w
  pool$unique_id[which.max(as.numeric(pool$starts))]
}


#' Is this device a HOBO logger?
#'
#' Single place where the accepted manufacturer spellings live. "HOBO" is the
#' value VI-FLO writes - it is what the loggers are called operationally, what
#' the software is named, and what the file extension says. "Onset" is kept as
#' an accepted alias because it is the manufacturer name printed on older
#' devices and someone will eventually type it.
#'
#' @param mfger Character. Manufacturer value from device metadata
#' @return Logical
is_hobo_device <- function(mfger) {
  tolower(trimws(as.character(mfger))) %in% c("hobo", "onset")
}

################################################################################
#  Moved here from metadata_manager_functions.R
#
#  These are operations on metadata that do no prompting - validators,
#  getters, and writers. They belong with the loaders rather than with the
#  interactive workflows, which is where they had accumulated.
################################################################################
#' @return TRUE if exists, character error message if not
validate_device_exists <- function(device_serial) {
  metadata <- load_zentra_metadata()
  
  if (!device_serial %in% metadata$device_serial) {
    return(paste0("Device '", device_serial, "' not found in metadata"))
  }
  
  return(TRUE)
}

#' Check if a station exists in metadata
#' @param station_id Character. Station ID to check
#' @return TRUE if exists, character error message if not
validate_station_exists <- function(station_id) {
  metadata <- load_zentra_metadata()
  
  if (!station_id %in% metadata$station_id) {
    return(paste0("Station '", station_id, "' not found in metadata"))
  }
  
  return(TRUE)
}

#' Check for duplicate port assignments in a configuration
#' @param port_config Data frame with 'port' column
#' @return TRUE if valid, character error message if duplicates found
validate_no_duplicate_ports <- function(port_config) {
  if (any(duplicated(port_config$port))) {
    dup_ports <- port_config$port[duplicated(port_config$port)]
    return(paste0("Duplicate port(s) assigned: ", paste(dup_ports, collapse = ", ")))
  }
  
  return(TRUE)
}

################################################################################
#### QUERY FUNCTIONS ####
################################################################################
# These retrieve data from metadata files
# Return: Data structures (lists, data frames, vectors)

#' Get list of all stations
#' @return Character vector of station IDs with site names
get_station_list <- function(include_retired = FALSE) {
  metadata <- load_zentra_metadata()

  # A station whose every device has gone terminal is history. It cannot be
  # maintained, downloaded from or surveyed, so listing it among thirty live
  # stations is noise in every workflow except 'Correct device details', which
  # exists partly to reach exactly those rows.
  terminal_statuses <- TERMINAL_STATUSES

  if (!include_retired) {
    live <- metadata$station_id[!tolower(metadata$status) %in% terminal_statuses]
    metadata <- metadata[metadata$station_id %in% unique(live), , drop = FALSE]
  }

  stations <- sort(unique(metadata$station_id))

  station_list <- list()
  for (station in stations) {
    rows <- metadata[metadata$station_id == station, , drop = FALSE]

    # Devices that have gone out of service are dropped from the label. A live
    # station whose logger was swapped last week would otherwise advertise the
    # old one - sr2_weather reading ("Glynn Weather" / "SR2 weather") when
    # only the second is there.
    #
    # Except when retired stations are being shown, which is the case where
    # someone is reaching into history deliberately and an old name is what
    # they would search by.
    if (!include_retired) {
      live_rows <- rows[!tolower(rows$status) %in% terminal_statuses, , drop = FALSE]
      if (nrow(live_rows) > 0) rows <- live_rows
    }

    # What a menu shows in brackets. The site name is already implied by the
    # abbreviation and the watershed heading, so it earns nothing there -
    # whereas vwc1/vwc2/vwc3 are arbitrary and say nothing about which station
    # is which.
    #
    # Area first where it is set, since it was written to group stations that
    # belong together. Then the device name, which was written to identify a
    # logger, falling back to the serial where no name was given. Several
    # devices are joined, so a paired gauge shows both.
    # Names in quotes, serials not. A device name is a nickname someone typed
    # into the logger's own software - "RB-standby2", "tr1slope" - and the
    # quotes say so, keeping it from reading as an identifier the system
    # assigned.
    names_here <- rows$device_name
    blank <- is.na(names_here) | trimws(as.character(names_here)) == ""
    names_here[!blank] <- paste0('"', trimws(names_here[!blank]), '"')
    names_here[blank] <- rows$device_serial[blank]
    names_here <- unique(names_here[!is.na(names_here)])

    area_here <- rows$area[1]
    has_area <- !is.na(area_here) && nzchar(trimws(as.character(area_here)))

    label <- if (length(names_here) > 0) {
      paste(names_here, collapse = " / ")
    } else NA_character_

    if (has_area && !is.na(label)) label <- paste0(area_here, ", ", label)
    else if (has_area)             label <- area_here

    station_list[[station]] <- list(
      station_id = station,
      site_full  = rows$site_full[1],
      # Grouping. Derived from site_full it would mean stripping a trailing
      # number, which breaks on sites carrying an area - "Bethlehem Adventure 2"
      # belongs to the Bethlehem watershed.
      watershed  = rows$watershed[1],
      label      = if (is.na(label)) rows$site_full[1] else label
    )
  }

  return(station_list)
}

#' Get devices at a specific station
#' @param station_id Character. Station to query
#' @return Data frame of devices at that station
get_station_devices <- function(station_id) {
  metadata <- load_zentra_metadata()
  station_devices <- metadata[metadata$station_id == station_id, ]
  return(station_devices)
}

#' Get active devices at a station (excludes terminal statuses)
#' @param station_id Character. Station to query
#' @return Data frame of active devices (excludes removed, replaced, decommissioned)
get_active_station_devices <- function(station_id) {
  all_devices <- get_station_devices(station_id)
  terminal_statuses <- TERMINAL_STATUSES
  active_devices <- all_devices[!all_devices$status %in% terminal_statuses, ]
  return(active_devices)
}

#' Get active devices with UI feedback if empty
#' @param station_id Character. Station to query
#' @param workflow_name Character. Name of workflow for error message
#' @return Data frame of active devices, or NULL if none found (with message)
get_active_devices_or_notify <- function(station_id, workflow_name = "this workflow") {
  active_devices <- get_active_station_devices(station_id)
  
  if (nrow(active_devices) == 0) {
    cat("❌ No active devices at station '", station_id, "'\n", sep = "")
    cat("   All devices are removed, replaced, or decommissioned.\n")
    cat("   Cannot proceed with ", workflow_name, ".\n", sep = "")
    return(NULL)
  }
  
  return(active_devices)
}

#' Prompt for logger initials with DAH as default
#' @return Character. Three-letter initials
ui_ask_whois_logging <- function() {
  cat("\nWho is logging this?\n")
  cat("  1. DAH\n")
  cat("  2. Enter custom initials (3 letters)\n")
  cat("\nEnter selection: ")
  logged_by_input <- trimws(readline())
  
  if (logged_by_input == "1" || logged_by_input == "") {
    return("DAH")
  } else if (logged_by_input == "2") {
    repeat {
      cat("Enter 3-letter initials: ")
      custom_initials <- toupper(trimws(readline()))
      if (nchar(custom_initials) == 3) {
        return(custom_initials)
      } else {
        cat("⚠️  Please enter exactly 3 letters\n")
      }
    }
  } else {
    return("DAH")  # Default for any other input
  }
}

#' Get current port configuration for a device
#' @param device_serial Character. Device to query (maps to 'sn' column)
#' @return Data frame with port, type, sensor, depth_cm, status for active configs
#'         Empty ports have sensor="none"
get_current_port_config <- function(device_serial) {
  ports <- load_zentra_ports_data()
  
  device_ports <- ports[ports$sn %in% device_serial, ]
  
  # Get all ports with valid_to = NA (potentially multiple sextuplets)
  active_ports <- device_ports[is.na(device_ports$valid_to), ]
  
  if (nrow(active_ports) == 0) {
    stop("No active port configuration found for device: ", device_serial)
  }
  
  # A ZL6 has six ports, but not six ACTIVE rows: closing one - a sensor
  # removed when a shared station was retired - leaves five.
  #
  # The result must therefore be built by PORT NUMBER, not by position.
  # Returning whatever rows happen to be active, sorted, shifted every
  # subsequent port up by one: port 2's sensor was displayed as port 1's, and
  # callers indexing 1:6 ran off the end.
  if (nrow(active_ports) > 6) {
    active_ports <- tail(active_ports, 6)
  }
  
  result <- data.frame(
    port     = 1:6,
    type     = "none",
    sensor   = "none",
    depth_cm = NA,
    status   = NA,
    stringsAsFactors = FALSE
  )
  
  for (i in seq_len(nrow(active_ports))) {
    p <- suppressWarnings(as.numeric(active_ports$port[i]))
    if (is.na(p) || p < 1 || p > 6) next
    result$type[p]     <- active_ports$type[i]
    result$sensor[p]   <- active_ports$sensor[i]
    result$depth_cm[p] <- active_ports$depth_cm[i]
    result$status[p]   <- active_ports$status[i]
  }
  
  return(result)
}

#' Get unique values for a metadata field (for dropdown menus)
#' @param field Character. Field name to query
#' @return Character vector of unique values (sorted, NAs removed)
get_metadata_unique_values <- function(field) {
  metadata <- load_zentra_metadata()
  
  if (!field %in% names(metadata)) {
    return(character())
  }
  
  values <- unique(metadata[[field]])
  values <- values[!is.na(values)]
  return(sort(values))
}

#' Get unique sensor types from ports data (excluding 'none')
#' @return Character vector of sensor types
get_unique_sensor_types <- function() {
  ports <- load_zentra_ports_data()
  sensor_types <- unique(ports$sensor)
  sensor_types <- sensor_types[!is.na(sensor_types) & sensor_types != "none"]
  return(sort(sensor_types))
}

#' Determine sensor type category from sensor name
#' @param sensor Character. Sensor name (e.g., "TEROS 10", "ATMOS 41")
#' @return Character. Type category: "vwc", "weather", or "none"
determine_sensor_type <- function(sensor) {
  if (is.na(sensor) || sensor == "none") {
    return("none")
  }
  
  # VWC sensors
  if (grepl("TEROS", sensor, ignore.case = TRUE)) {
    return("vwc")
  }
  
  # Weather sensors
  if (grepl("ATMOS", sensor, ignore.case = TRUE)) {
    return("weather")
  }
  
  # Default to vwc for unknown sensors
  # (can be manually corrected if needed)
  return("vwc")
}

################################################################################
#### METADATA MODIFICATION FUNCTIONS ####
################################################################################
# These modify metadata files
# Return: TRUE if successful, character error message if failed
# IMPORTANT: These functions WRITE to files

#' Create a new maintenance log entry
#'
#' Names the deployment by unique_id where the caller has it. Given a serial
#' instead, it finds the deployment that logger was serving at the station on
#' the day of the visit - see resolve_deployment().
#'
#' @param field_visit_date Character or Date. Date of field visit
#' @param station_id Character. Station visited
#' @param action_type Character. What was done - one of MAINTENANCE_ACTIONS
#' @param details Character. Description
#' @param logged_by Character. Who logged this (initials)
#' @param unique_id Character. The deployment the entry concerns
#' @param device_serial Character. Or the logger, to find it by
#' @return TRUE if successful, error message if failed
create_maintenance_entry <- function(field_visit_date, station_id, action_type,
                                     details, logged_by, unique_id = NULL,
                                     device_serial = NULL) {
  tryCatch({
    if (is.null(unique_id)) {
      if (is.null(device_serial)) stop("give the deployment's unique_id, or the logger's serial")
      unique_id <- resolve_deployment(device_serial, station_id, field_visit_date)
      if (is.na(unique_id)) {
        stop("logger ", device_serial, " has no row at ", station_id)
      }
    }
    write_maintenance_entry(
      field_visit_date = field_visit_date,
      station_id       = station_id,
      unique_id        = unique_id,
      action_type      = action_type,
      details          = details,
      logged_by        = logged_by
    )
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to create maintenance entry: ", e$message))
  })
}

#' Delete the most recent maintenance log entry for a device
#' Used when user realizes they selected wrong workflow
#' @param device_serial Character. Device whose last entry should be deleted
#' @param station_id Character. The station it was logged at
#' @return TRUE if successful, error message if failed
delete_last_maintenance_entry <- function(device_serial, station_id) {
  tryCatch({
    maint_log <- load_maintenance_log()

    # Entries name deployments: the logger's at this station, not at every
    # station it has served - the entry being undone was just logged here
    meta <- read_table("device_metadata", remember = FALSE)
    its_rows <- meta$unique_id[!is.na(meta$device_serial) & meta$device_serial == device_serial &
                                 meta$station_id %in% station_id]
    mine <- which(maint_log$unique_id %in% its_rows)

    if (length(mine) == 0) {
      return("No maintenance entries found for this device")
    }

    # The last entry (most recent row)
    last_entry_index <- mine[length(mine)]
    
    # Remove that row
    maint_log <- maint_log[-last_entry_index, ]
    
    if (!isTRUE(write_table("maintenance_log", maint_log,
                            intent = "deleting the last maintenance entry"))) {
      return("Not deleted - the maintenance log changed since it was read")
    }
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to delete entry: ", e$message))
  })
}

#' Update last_visit date for active devices at a station
#' @param station_id Character. Station to update
#' @param visit_date Date or character. Date of visit
#' @return TRUE if successful, error message if failed
update_last_visit <- function(station_id, visit_date) {
  tryCatch({
    metadata <- load_zentra_metadata()
    station_devices <- metadata[metadata$station_id == station_id, ]
    
    # Only the deployments still there. For a retired row - removed,
    # replaced, relocated, decommissioned - last_visit is the day it left,
    # which is where Product 2 ends its deployment. A later visit to the
    # station is not a visit to it: TR1's HOBOlink, destroyed 2024-08-14, was
    # re-dated by a visit in October 2026, and its post-hurricane readings
    # came back into tr1_hydro. A retired row is dated once, by the workflow
    # that retires it - see retire_row().
    active_mask <- !tolower(station_devices$status) %in%
      TERMINAL_STATUSES
    active_unique_ids <- station_devices$unique_id[active_mask]
    
    if (length(active_unique_ids) == 0) {
      return("No active devices found at this station")
    }
    
    # Update last_visit
    metadata$last_visit[metadata$unique_id %in% active_unique_ids] <- as.Date(visit_date)
    save_device_metadata(metadata)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_visit: ", e$message))
  })
}

#' Update status for a specific device
#' @param device_serial Character. Device to update
#' @param new_status Character. New status value
#' @return TRUE if successful, error message if failed
update_device_status <- function(device_serial, new_status, station_id = NULL) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Check device exists
    if (!device_serial %in% metadata$device_serial) {
      return(paste0("Device '", device_serial, "' not found"))
    }
    
    # A serial does NOT identify a row. One serial can have several:
    #   - a relocated row plus the row that succeeded it, same station
    #   - two active rows, where one ZL6 serves a weather and a vwc station
    #
    # Matching on serial alone would restatus all of them - overwriting a
    # closed historical row, or dragging a second station along for the ride.
    #
    # Terminal rows are excluded because they are closed history. Where the
    # caller knows which station it is acting on, that narrows it further.
    terminal_statuses <- TERMINAL_STATUSES
    # A working status only. Ending a deployment is a workflow's job - removal,
    # replacement, relocation, decommissioning - each of which dates the end,
    # closes the ports and logs it; a status flipped here would do none of that
    if (!new_status %in% ACTIVE_STATUSES) {
      return(paste0("'", new_status, "' is not a working status - use the workflow that ends a deployment"))
    }
    
    rows <- metadata$device_serial == device_serial &
            !tolower(metadata$status) %in% terminal_statuses
    
    if (!is.null(station_id)) {
      rows <- rows & metadata$station_id == station_id
    }
    
    if (!any(rows)) {
      return(paste0("No active row found for device '", device_serial, "'",
                    if (!is.null(station_id)) paste0(" at ", station_id) else ""))
    }
    
    metadata$status[rows] <- new_status
    
    # The approval is NOT cleared on a terminal transition, though it used to
    # be. That made sense when the flag gated downloading - a device out of
    # service cannot be downloaded, so the flag stopped meaning anything.
    #
    # It now asserts that the record is accurate, and a terminal row's record
    # is both accurate and frozen: it describes a deployment that really
    # happened. More to the point, the data from that deployment is still in
    # the archive and still has to be attributed. Clearing the flag would
    # block that, on the strength of the device having since been moved.
    save_device_metadata(metadata)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update device status: ", e$message))
  })
}

#' Update status for all devices at a station
#' Handles special logic for decommissioning (preserves historical statuses)
#' @param station_id Character. Station to update
#' @param new_status Character. New status to apply
#' @return TRUE if successful, error message if failed
update_station_status <- function(...) {
  # One change: statuses, ends and the ports closed with them
  with_metadata_change("changing a station's status", update_station_status_unchecked(...))
}

#' The saves of a station status change, unchecked - see update_station_status()
update_station_status_unchecked <- function(station_id, new_status, when = Sys.time()) {
  tryCatch({
    # Decommissioning only. Every other status has its own workflow -
    # removal, replacement, relocation - and a blanket status for a whole
    # station would rewrite its retired rows' history along with it
    if (!identical(new_status, "decommissioned")) {
      stop("only decommissioning changes a whole station's status")
    }
    metadata <- load_zentra_metadata()
    
    if (new_status == "decommissioned") {
      # Get devices at this station
      station_devices <- metadata[metadata$station_id == station_id, ]
      
      # Check if any active devices exist
      active_statuses <- ACTIVE_STATUSES
      active_devices <- station_devices[station_devices$status %in% active_statuses, ]
      
      if (nrow(active_devices) > 0) {
        # Normal case: mark all active devices as decommissioned, and date
        # them. A decommissioned row with no end has no end to its deployment
        ending <- metadata$station_id == station_id & metadata$status %in% active_statuses
        metadata$status[ending] <- new_status
        metadata$end_datetime[ending] <- as.POSIXct(when, tz = PROJECT_TZ)
        
        # A decommissioned station's sensors are no longer deployed, so its
        # deployments' port rows stop being true and close. Only its own: a
        # ZL6 running another station as well keeps that station's ports
        close_deployment_ports(metadata$unique_id[ending], when)
      } else {
        # No active devices - check for removed devices
        removed_devices <- station_devices[station_devices$status == "removed", ]
        
        if (nrow(removed_devices) > 0) {
          # Find most recently removed device (by last_visit date)
          removed_devices$last_visit_date <- as.Date(removed_devices$last_visit)
          most_recent_idx <- which.max(removed_devices$last_visit_date)
          most_recent_serial <- removed_devices$device_serial[most_recent_idx]
          
          # Mark only the most recent removal as decommissioned
          metadata$status[metadata$station_id == station_id & 
                            metadata$device_serial == most_recent_serial & 
                            metadata$status == "removed"] <- new_status
        }
        # If no removed devices either, nothing to mark (all replaced/relocated)
      }
    }
    
    # As in update_device_status(), the approval is not cleared here. A
    # decommissioned station's record still describes what was there, and its
    # archived data still has to be attributed.
    save_device_metadata(metadata)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update station status: ", e$message))
  })
}

#' Records a human's review of a station's metadata
#'
#' Sets metadata_approved and last_reviewed_utc together for every device at
#' the station. Both values are written whether the answer was yes or no.
#'
#' @param station_id Character. Station to update
#' @param approved Logical. Whether the record was confirmed complete
#' @return TRUE if successful, error message if failed
update_metadata_approval <- function(station_id, approved) {
  tryCatch({
    set_metadata_approved(station_id = station_id, value = approved)
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to record metadata review: ", e$message))
  })
}

#' Update device location coordinates
#' @param device_serial Character. Device to update
#' @param lat Numeric. New latitude
#' @param lon Numeric. New longitude  
#' @param elev Numeric or NA. New elevation
#' @return TRUE if successful, error message if failed
update_device_location <- function(device_serial, lat, lon, elev,
                                  elev_source = NA, station_id = NULL) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Scoped to active rows, and to a station where the caller knows it. A
    # serial can carry several rows, and writing a new location onto a closed
    # historical one would move a station that never went anywhere.
    terminal <- TERMINAL_STATUSES
    device_index <- which(metadata$device_serial == device_serial &
                          !tolower(metadata$status) %in% terminal)
    if (!is.null(station_id)) {
      scoped <- device_index[metadata$station_id[device_index] == station_id]
      if (length(scoped) > 0) device_index <- scoped
    }
    
    if (length(device_index) == 0) {
      return("No active row found for this device")
    }
    
    metadata$lat[device_index] <- lat
    metadata$lon[device_index] <- lon
    metadata$elev[device_index] <- elev
    if ("elev_source" %in% names(metadata)) {
      metadata$elev_source[device_index] <- elev_source
    }
    save_device_metadata(metadata)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update location: ", e$message))
  })
}

#' Writes a surveyed ground elevation to device rows
#'
#' Scoped by unique_id: the rows named, never every row with a serial. `elev`
#' is the ground at the station - what was measured between loggers is in
#' surveys.csv, not here. At a paired gauge every logger carries the
#' primary's, so the caller names them all.
#'
#' @param unique_id Character. The row or rows to update
#' @param elev Numeric. New ground elevation (meters)
#' @param elev_source Character. Written with the elevation
#' @return TRUE if successful, error message if failed
survey_device_elevation <- function(unique_id, elev, elev_source) {
  tryCatch({
    metadata <- load_zentra_metadata()
    idx <- which(metadata$unique_id %in% unique_id)
    if (length(idx) != length(unique(unique_id))) {
      return(paste0("Expected a row for each of ", paste(unique_id, collapse = ", "),
                    ", found ", length(idx)))
    }
    metadata$elev[idx] <- elev
    metadata$elev_source[idx] <- elev_source
    save_device_metadata(metadata)
    TRUE
  }, error = function(e) {
    paste0("Failed to update elevation: ", e$message)
  })
}

################################################################################
#### PORT CONFIGURATION FUNCTIONS ####
################################################################################

#' Initialize port configuration for a new device
#' @param device_serial Character. Device to configure
#' @param port_config Data frame with columns: port, type, sensor, depth_cm, status
#'                    Must include all 6 ports (use sensor="none" for empty)
#' @return TRUE if successful, error message if failed
initialize_ports <- function(device_serial, port_config) {
  tryCatch({
    # Validate - must have exactly 6 ports
    if (nrow(port_config) != 6 || !all(1:6 %in% port_config$port)) {
      return("Port configuration must include all 6 ports")
    }
    
    # Validate no duplicates
    valid <- validate_no_duplicate_ports(port_config)
    if (!isTRUE(valid)) return(valid)
    
    metadata <- read_table("device_metadata", remember = FALSE)
    ports <- load_zentra_ports_data()

    # An empty port has no row. Each sensor's row names the deployment it
    # serves - the logger's active row of that sensor's kind - and opens when
    # that deployment began
    for (i in seq_len(nrow(port_config))) {
      if (port_config$sensor[i] == "none") next
      uid <- port_deployment(device_serial, port_config$type[i], metadata)
      starts <- metadata$deploy_datetime[metadata$unique_id == uid]
      ports <- rbind(ports, new_port_row(
        uid, port_config$port[i], port_config$sensor[i], port_config$depth_cm[i],
        port_config$status[i], starts, device_serial, port_config$type[i]))
    }

    save_zentra_ports(ports, intent = "recording a port configuration")
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to initialize ports: ", e$message))
  })
}

#' Update port configuration for an existing device
#' @param device_serial Character. Device to update
#' @param port_config Data frame with columns: port, type, sensor, depth_cm, status
#'                    Must include all 6 ports (use sensor="none" for empty)
#' @param change_datetime POSIXct. When the change occurred
#' @return TRUE if successful, error message if failed
update_ports <- function(device_serial, port_config, change_datetime) {
  tryCatch({
    # Validate - must have exactly 6 ports
    if (nrow(port_config) != 6 || !all(1:6 %in% port_config$port)) {
      return("Port configuration must include all 6 ports")
    }
    
    # Validate no duplicates
    valid <- validate_no_duplicate_ports(port_config)
    if (!isTRUE(valid)) return(valid)
    
    ports <- load_zentra_ports_data()
    current_config <- get_current_port_config(device_serial)
    
    # Get OLD port rows with full timestamp info
    old_port_rows <- ports[ports$sn %in% device_serial & is.na(ports$valid_to), ]
    
    # Which ports actually changed?
    #
    # This previously asked only whether ANY port changed and then rewrote all
    # six. That is defensible when a logger serves one station, but a ZL6 can
    # serve two - and rewriting all six writes a configuration-change event for
    # the other station's sensors, which nobody touched. The record then shows
    # a discontinuity that never physically happened.
    #
    # Versioning each port separately is more honest, and the full state at any
    # moment is still recoverable: for each port, take the row valid then.
    changed <- logical(6)

    for (i in 1:6) {
      current_port <- current_config[current_config$port == i, ]
      new_port <- port_config[port_config$port == i, ]

      sensor_changed <- !identical(as.character(current_port$sensor[1]),
                                   as.character(new_port$sensor))
      type_changed   <- !identical(as.character(current_port$type[1]),
                                   as.character(new_port$type))
      depth_changed  <- !isTRUE(all.equal(as.numeric(current_port$depth_cm[1]),
                                          as.numeric(new_port$depth_cm),
                                          tolerance = 0.01))
      status_changed <- !isTRUE(all.equal(as.character(current_port$status[1]),
                                          as.character(new_port$status)))

      changed[i] <- sensor_changed || type_changed || depth_changed || status_changed
    }

    if (!any(changed)) {
      return(TRUE)  # Success - no changes needed
    }

    # Close and recreate ONLY the ports that changed
    new_rows_list <- list()

    for (port_num in which(changed)) {
      new_port <- port_config[port_config$port == port_num, ]
      old_port <- old_port_rows[old_port_rows$port == port_num, ]

      # The sensor that was there, if any, stops being true now
      if (nrow(old_port) > 0) {
        ports$valid_to[ports$sn %in% device_serial & ports$port == port_num &
                         is.na(ports$valid_to)] <- change_datetime
      }

      # An empty port has no row
      if (new_port$sensor == "none") next

      new_rows_list[[as.character(port_num)]] <- new_port_row(
        port_deployment(device_serial, new_port$type), port_num, new_port$sensor,
        new_port$depth_cm, new_port$status, change_datetime, device_serial, new_port$type)
    }

    if (length(new_rows_list) > 0) {
      ports <- rbind(ports, do.call(rbind, new_rows_list))
    }
    
    save_zentra_ports(ports, intent = "recording a port configuration")
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update ports: ", e$message))
  })
}

################################################################################
#### DEVICE MANAGEMENT FUNCTIONS ####
################################################################################

#' Add a new device to metadata
#' @param device_data List containing all device fields
#' @return TRUE if successful, error message string if failed
add_new_device <- function(device_data) {
  # One change: the row and the sensor height measured as it went in - a
  # device recorded without the height it was given is half an entry
  with_metadata_change("adding a device", add_new_device_unchecked(device_data))
}

#' The saves of adding a device, unchecked - see add_new_device()
add_new_device_unchecked <- function(device_data) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Check if device_serial already exists and is still active
    existing <- metadata[metadata$device_serial == device_data$device_serial, ]
    
    if (nrow(existing) > 0) {
      terminal_statuses <- TERMINAL_STATUSES
      
      # A serial active at a DIFFERENT station type is legitimate: one ZL6
      # serves both a weather station and a vwc station, which is what
      # validate_metadata() permits - one active row per serial per station
      # type. Only the same serial at the same station type is a duplicate.
      active <- existing[!existing$status %in% terminal_statuses, , drop = FALSE]
      same_type <- active[tolower(active$station_type) ==
                          tolower(device_data$station_type), , drop = FALSE]
      
      if (nrow(same_type) > 0) {
        return(paste0("Device serial '", device_data$device_serial,
                      "' is already active as a ", device_data$station_type,
                      " device at ", same_type$station_id[1]))
      }
      # Otherwise allow: either every prior entry is terminal, or this is the
      # same logger serving a second station type
    }
    
    
    
    # Generate unique_id based on manufacturer
    if (tolower(device_data$mfger) == "meter") {
      prefix <- "z"
    } else if (is_hobo_device(device_data$mfger)) {
      prefix <- "h"
    } else {
      return("Unknown manufacturer, cannot determine unique_id prefix")
    }
    
    # Get next available number
    all_unique_ids <- metadata$unique_id
    matching_prefix <- all_unique_ids[grepl(paste0("^", prefix, "-"), all_unique_ids)]
    existing_numbers <- as.numeric(sub(paste0("^", prefix, "-"), "", matching_prefix))
    next_number <- ifelse(length(existing_numbers) == 0, 1, max(existing_numbers, na.rm = TRUE) + 1)
    unique_id <- sprintf("%s-%04d", prefix, next_number)
    
    # Create new row
    new_row <- data.frame(
      unique_id = unique_id,
      watershed = device_data$watershed,
      area = device_data$area,
      site_full = device_data$site_full,
      site = device_data$site,
      station_type = device_data$station_type,
      station_id = device_data$station_id,
      device_serial = device_data$device_serial,
      device_role = device_data$device_role,
      device_name = device_data$device_name,
      mfger = device_data$mfger,
      model = device_data$model,
      lat = device_data$lat,
      lon = device_data$lon,
      elev = device_data$elev,
      elev_source = device_data$elev_source,
      interval_min = device_data$interval_min,
      timezone = device_data$timezone,
      deploy_datetime = device_data$deploy_datetime,
      end_datetime = as.POSIXct(NA, tz = PROJECT_TZ),
      status = device_data$status,
      # Establishing a station on a date means somebody stood at it on that
      # date. The deploy datetime IS a field visit, so recording it as one is
      # not an inference - it is the same fact stated in the field that asks
      # "when was this last visited?"
      last_visit = local_date(device_data$deploy_datetime),
      metadata_approved = device_data$metadata_approved,
      # Written together: the flag says a human confirmed the record, the
      # timestamp says when. Establishing a station IS that confirmation, so
      # the row is dated from the moment it is created.
      last_reviewed_utc = if (isTRUE(device_data$metadata_approved)) {
        format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
      } else NA_character_,
      stringsAsFactors = FALSE
    )
    
    # Add to metadata
    metadata <- rbind(metadata, new_row)
    save_device_metadata(metadata)

    # The sensor height asked for on the way in is a measurement, so it goes
    # to surveys.csv against the new deployment - dated when it went in.
    # Above the ground for a weather station, the bed for anything else
    h <- device_data$sensor_height_cm
    if (!is.null(h) && !is.na(h)) {
      weather <- tolower(device_data$station_type) == "weather"
      method <- attr(h, "method")
      if (is.null(method)) method <- if (weather && h == 200) "nominal" else "tape"
      res <- add_survey_rows(survey_row(
        station_id = device_data$station_id, unique_id = unique_id,
        measured_on = local_date(device_data$deploy_datetime), quantity = "height_cm",
        point = "sensor", value = as.numeric(h),
        relative_to = if (weather) "ground" else "bed", method = method))
      if (!isTRUE(res)) {
        return(paste0("Device not added - its sensor height could not be recorded: ", res))
      }
    }

    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to add device: ", e$message))
  })
}

#' Relocate a station to a new location
#' @param station_id Character. Station being relocated
#' @param new_lat Numeric. New latitude
#' @param new_lon Numeric. New longitude  
#' @param deploy_datetime POSIXct. When relocation occurred
#' @param new_status Character. Status at new location
#' @param metadata_approved Logical. Approval for download
#' @return List with success status and new unique_ids
relocate_station <- function(...) {
  # One change: the old rows retired, the new ones created, their ports
  # carried over. Checked once, at the end - halfway, the old rows have ended
  # with their ports still open
  res <- with_metadata_change("relocating a station", relocate_station_unchecked(...))
  if (is.character(res)) list(success = FALSE, error = res) else res
}

#' The saves of a relocation, unchecked - see relocate_station()
relocate_station_unchecked <- function(station_id, new_lat, new_lon, deploy_datetime,
                            new_status, metadata_approved,
                            new_device = NULL,
                            new_elev = NA, new_elev_source = NA,
                            also_moving = character(0),
                            staying_behind = character(0)) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # One logger can serve several stations, and what physically moves is the
    # DEVICE. Relocating only the station that was named leaves any companion
    # sitting at the old coordinates on a box that is no longer there.
    #
    # `also_moving` names the companion stations going along; `staying_behind`
    # names those whose sensors came out and did not travel. The caller asks,
    # because only a person knows which.
    moving <- unique(c(station_id, also_moving))

    station_devices <- metadata[metadata$station_id %in% moving, ]

    # Current deployments only. This once left out only decommissioned and
    # relocated rows, so a station's removed and replaced loggers would have
    # been "moved" with it too, each given a new row at the new position
    active_mask <- !tolower(station_devices$status) %in% TERMINAL_STATUSES
    active_devices <- station_devices[active_mask, ]
    
    if (nrow(active_devices) == 0) {
      return(list(success = FALSE, error = "No active devices at this station"))
    }
    
    # Mark old devices as relocated
    metadata$status[metadata$unique_id %in% active_devices$unique_id] <- "relocated"
    # The old position's deployment ends where the new one begins
    metadata$end_datetime[metadata$unique_id %in% active_devices$unique_id] <-
      as.POSIXct(deploy_datetime, tz = PROJECT_TZ)

    # A station whose sensors came out while the logger went elsewhere. Its
    # row ends as `removed` - the sensors that constituted the station were
    # taken out. Not `relocated`, which would claim it moved; not
    # `decommissioned`, which implies a site nobody returns to.
    # It ends at the move, like any retired row, and its ports close with it
    left_ids <- character(0)
    if (length(staying_behind) > 0) {
      left <- metadata$station_id %in% staying_behind &
              !tolower(metadata$status) %in% TERMINAL_STATUSES
      metadata$status[left] <- "removed"
      metadata$end_datetime[left] <- as.POSIXct(deploy_datetime, tz = PROJECT_TZ)
      left_ids <- metadata$unique_id[left]
    }
    
    # Create new rows for each device at new location
    new_unique_ids <- character()
    for (i in 1:nrow(active_devices)) {
      old_device <- active_devices[i, ]
      
      # Generate new unique_id
      prefix <- substr(old_device$unique_id, 1, 1)
      all_unique_ids <- metadata$unique_id
      matching_prefix <- all_unique_ids[grepl(paste0("^", prefix, "-"), all_unique_ids)]
      existing_numbers <- as.numeric(sub(paste0("^", prefix, "-"), "", matching_prefix))
      next_number <- max(existing_numbers, na.rm = TRUE) + 1
      new_unique_id <- sprintf("%s-%04d", prefix, next_number)
      
      # Create new row (copy most fields, update location/status)
      new_row <- old_device
      new_row$unique_id <- new_unique_id
      new_row$lat <- new_lat
      new_row$lon <- new_lon
      # new_row is a copy of the old device, so without this it would carry the
      # OLD location's elevation to the new coordinates - a value describing a
      # place the station is no longer at.
      new_row$elev <- new_elev
      if ("elev_source" %in% names(new_row)) {
        new_row$elev_source <- new_elev_source
      }
      # Surveys need no clearing: they belong to the old deployment, which is
      # where they were measured
      new_row$deploy_datetime <- deploy_datetime
      new_row$end_datetime <- as.POSIXct(NA, tz = PROJECT_TZ)
      new_row$status <- new_status
      new_row$last_visit <- local_date(deploy_datetime)
      new_row$metadata_approved <- metadata_approved

      # A station can move AND get a different logger in one field operation.
      # Logged as two workflows - relocate, then replace - that produces a
      # third row asserting the OLD device was deployed at the NEW position,
      # which never happened. Taking the new device here gives two rows and no
      # fiction.
      #
      # The old row keeps status 'relocated': it closed because the station
      # moved, and the newer row shows both where it went and that the serial
      # changed.
      if (!is.null(new_device)) {
        new_row$device_serial <- new_device$device_serial
        if (!is.null(new_device$mfger))       new_row$mfger       <- new_device$mfger
        if (!is.null(new_device$model))       new_row$model       <- new_device$model
        if (!is.null(new_device$device_name)) new_row$device_name <- new_device$device_name

      }
      # new_row is a copy of the old device, so without this it would inherit
      # the review date from BEFORE the move - claiming the record was
      # confirmed at a position the station has since left.
      if ("last_reviewed_utc" %in% names(new_row)) {
        new_row$last_reviewed_utc <- if (isTRUE(metadata_approved)) {
          format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
        } else NA_character_
      }
      
      metadata <- rbind(metadata, new_row)
      new_unique_ids <- c(new_unique_ids, new_unique_id)
    }
    save_device_metadata(metadata)
    if (length(left_ids) > 0) close_deployment_ports(left_ids, deploy_datetime)

    # The old logger's ports describe sensors that came out with it. Leaving
    # them open would have a device in a cupboard still carrying a live
    # configuration, and the check for active ports on a terminal device would
    # rightly complain.
    if (!is.null(new_device)) {
      close_deployment_ports(active_devices$unique_id, deploy_datetime)
    } else {
      # The same logger moved, and its sensors with it. A port row belongs to
      # one deployment, so each open one closes at the move and opens again,
      # unchanged, on the deployment the move created
      carried <- carry_ports_over(active_devices$unique_id, new_unique_ids, deploy_datetime)
      if (!isTRUE(carried)) stop(carried)
    }

    return(list(success = TRUE, new_unique_ids = new_unique_ids,
                device_changed = !is.null(new_device)))
  }, error = function(e) {
    return(list(success = FALSE, error = paste0("Failed to relocate station: ", e$message)))
  })
}

#' Dates a retired row, and closes its logger's ports, at the moment it left
#'
#' For a retired row, last_visit is the day the deployment ended - Product 2
#' ends it there - so the workflow that retires a row sets it, to the day the
#' logger actually came out: a removal's date, or a replacement's new logger
#' going in. Not the day it is typed in, and never by a later routine visit.
#' The ports close at the same moment, for the same reason.
#'
#' @param unique_id Character. The row being retired
#' @param when POSIXct. When the logger left: removal, or its replacement's
#'   deployment
#' @param close_ports Logical. Close the logger's open ports at `when`
#' @return TRUE, or an error message
retire_row <- function(unique_id, when, close_ports = TRUE, status = NULL) {
  with_metadata_change(paste("retiring row", unique_id), tryCatch({
    metadata <- load_zentra_metadata()
    i <- which(metadata$unique_id == unique_id)
    if (length(i) != 1) return(paste0("No single row '", unique_id, "'"))
    # The moment the deployment ended - the logger's removal, or its
    # replacement going in. Set once, here; a later visit to the station never
    # moves it. The terminal status goes with it, in the same save: a row that
    # has ended but still reads as current, or the reverse, is a contradiction
    metadata$end_datetime[i] <- as.POSIXct(when, tz = PROJECT_TZ)
    if (!is.null(status)) metadata$status[i] <- status
    if (!isTRUE(save_device_metadata(metadata, intent = paste("retiring row", unique_id)))) {
      stop("the device table was not saved")
    }

    # Its own ports, still open, close at its end. A port already closed
    # keeps its own date; a ZL6's other station keeps its ports
    if (close_ports) close_deployment_ports(unique_id, when)
    TRUE
  }, error = function(e) paste0("Failed to retire row: ", e$message)))
}

#' The current deployments a logger is serving
#'
#' One, usually; two on a ZL6 serving a weather and a vwc station at once.
#'
#' @param unique_id Character. Any one of them
#' @param metadata Data frame, or NULL to read
#' @return Data frame of device rows, the given one first
logger_current_rows <- function(unique_id, metadata = NULL) {
  if (is.null(metadata)) metadata <- load_zentra_metadata()
  r <- metadata[metadata$unique_id == unique_id, , drop = FALSE]
  if (nrow(r) != 1) return(r)
  all <- metadata[metadata$device_serial == r$device_serial &
                    !tolower(metadata$status) %in% TERMINAL_STATUSES, , drop = FALSE]
  rbind(r, all[all$unique_id != unique_id, , drop = FALSE])
}


#' Remove a logger from service
#'
#' The box came out of the field, so every deployment it was serving ends at
#' that moment - both of a ZL6's stations, not just the one it was chosen
#' at. A station ending while its logger stays on site is not a removal: it is
#' a decommissioning, or a port change if only the sensors came off.
#'
#' @param unique_id Character. The deployment it was chosen by
#' @param removal_datetime POSIXct. When the logger came out
#' @return TRUE if successful, error message if failed
remove_device <- function(unique_id, removal_datetime) {
  tryCatch({
    metadata <- load_zentra_metadata()
    device_row <- metadata[metadata$unique_id == unique_id, , drop = FALSE]
    if (nrow(device_row) != 1) return(paste0("No single row '", unique_id, "'"))
    if (tolower(device_row$status) %in% TERMINAL_STATUSES) {
      return(paste0(unique_id, " has already ended (", device_row$status, ")"))
    }
    rows <- logger_current_rows(unique_id, metadata)

    # 1. Every deployment it served ends at the removal - status, end and
    # ports - as one change
    result <- with_metadata_change(paste("removing logger", device_row$device_serial), {
      out <- TRUE
      for (uid in rows$unique_id) {
        r <- retire_row(uid, removal_datetime, status = "removed")
        if (!isTRUE(r)) { out <- r; break }
      }
      out
    })
    if (!isTRUE(result)) return(result)

    for (st in unique(rows$station_id)) {
      # 2. Disable downloads
      update_metadata_approval(st, FALSE)
      # 3. The station's other deployments were visited too - a pair's
      # partner. update_last_visit() leaves the removed rows alone;
      # retire_row() dated them
      update_last_visit(st, local_date(removal_datetime))
    }

    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to remove device: ", e$message))
  })
}

################################################################################
# End of UI-independent metadata_manager_functions.R
################################################################################

################################################################################
#### CONSOLE UI HELPER FUNCTIONS ####
################################################################################
# Reusable UI components for console interaction
# These handle common patterns like Y/N prompts, menus, etc.

#' Writes device_metadata.csv
#'
#' Through write_table() in table_functions.R, which formats every column by
#' the schema, refuses a write over a file that changed since this session
#' read it, backs the table up, and writes it through a temporary file.
#'
#' This function once held its own formatting block, after sixteen slightly
#' different copies of it had been gathered here - each copy a place a new
#' column could be forgotten, which is how last_record_date came to be written
#' as a Unix epoch. The schema now holds the one description of each column.
#'
#' Callers may hand datetimes as POSIXct or as formatted text, in any column
#' order; a column the table does not have is refused.
#'
#' @param metadata Data frame. The full device table
#' @param path Character. Write here instead - a migration's or a test's
#'   copy. Skips the guard and the backup
#' @param intent Character. What the caller was doing, for a refusal
#' @param guard Logical. Refuse if the file changed since it was read. Off
#'   only where the caller replaces the file wholesale and says so
#' A refused save is an error, as it is for the port table: returning FALSE
#' let eleven callers that never looked report a refused save as done.
#'
#' @return Invisibly TRUE; an error if the save was refused
save_device_metadata <- function(metadata, path = NULL, intent = NULL,
                                 guard = TRUE) {
  if (!is.null(path)) {
    return(invisible(write_table("device_metadata", metadata, path = path)))
  }
  if (!isTRUE(write_table("device_metadata", metadata, guard = guard, intent = intent))) {
    stop("device_metadata.csv was not saved - the reason is above", call. = FALSE)
  }
  invisible(TRUE)
}

#' Resolves a device serial to a single metadata row
#'
#' A serial does NOT identify a row. One can carry several: a terminal row plus
#' the deployment that succeeded it, or two active rows where a single ZL6
#' serves both a weather and a vwc station.
#'
#' Taking `metadata[metadata$device_serial == x, ][1, ]` therefore picks an
#' arbitrary one. Mostly harmless for fields that are the same across rows -
#' mfger, timezone - but deploy_datetime and station_type genuinely differ, and
#' the wrong one silently produces a wrong port start time or the wrong station
#' type.
#'
#' Terminal rows are excluded, and where the caller knows which station it is
#' acting on, that narrows it further.
#'
#' @param device_serial Character
#' @param station_id Character. Optional, narrows to one station
#' @param metadata Data.frame. Optional, avoids re-reading
#' @return One row, or NULL if none matches
get_device_row <- function(device_serial, station_id = NULL, metadata = NULL) {

  if (is.null(metadata)) metadata <- load_zentra_metadata()

  terminal_statuses <- TERMINAL_STATUSES

  rows <- metadata[metadata$device_serial == device_serial &
                   !tolower(metadata$status) %in% terminal_statuses, , drop = FALSE]

  # Fall back to terminal rows only if there is no active one - a caller
  # inspecting a retired device still needs an answer
  if (nrow(rows) == 0) {
    rows <- metadata[metadata$device_serial == device_serial, , drop = FALSE]
  }

  if (!is.null(station_id)) {
    scoped <- rows[rows$station_id == station_id, , drop = FALSE]
    if (nrow(scoped) > 0) rows <- scoped
  }

  if (nrow(rows) == 0) return(NULL)

  rows[1, ]
}

#' Does this device already have an active port configuration?
#'
#' One ZL6 commonly serves two stations - an ATMOS on one port and TEROS
#' sensors on the others, registered as a weather station and a vwc station
#' sharing a serial. The ports belong to the DEVICE, not the station, so the
#' second station must not configure them again: that would create a second
#' active set and fail validation.
#'
#' @param device_serial Character
#' @return Data frame of active port rows, zero rows if none
get_active_ports <- function(device_serial, station_type = NULL) {
  ports <- tryCatch(load_zentra_ports_data(), error = function(e) NULL)

  empty <- data.frame()
  if (is.null(ports) || nrow(ports) == 0) return(empty)

  active <- ports[ports$sn %in% device_serial & is.na(ports$valid_to), , drop = FALSE]

  # A shared logger has ports of more than one type. "Does this device have
  # active ports?" is the wrong question when a weather station is being set
  # up on a box whose vwc ports are open but whose ATMOS was taken off - the
  # answer is yes, and the weather station ends up with no sensor recorded.
  if (!is.null(station_type) && nrow(active) > 0) {
    active <- active[tolower(active$type) == tolower(station_type), , drop = FALSE]
  }

  active
}

#' Closes a deployment's open port configurations
#'
#' A port configuration says "this sensor is on this port, for this
#' deployment, from this time". When the deployment ends that statement stops
#' being true, so valid_to has to be set - otherwise the record claims
#' sensors are live on a device that is in a drawer.
#'
#' By deployment, never by logger. One ZL6 can serve a weather station and a
#' vwc station at once, each with its own ports; ending one leaves the other's
#' alone. A port already closed keeps its own date.
#'
#' On a relocation the logger's sensors move with it: relocate_station()
#' carries its open ports over to the new deployment rather than closing them.
#'
#' @param unique_ids Character. The deployments ending
#' @param close_datetime POSIXct or Date. When they stopped being true
#' @return Number of port rows closed, or an error message string
close_deployment_ports <- function(unique_ids, close_datetime) {
  tryCatch({
    ports <- load_zentra_ports_data()
    open_rows <- which(ports$unique_id %in% unique_ids & is.na(ports$valid_to))
    if (length(open_rows) == 0) return(0)
    ports$valid_to[open_rows] <- as.POSIXct(close_datetime, tz = PROJECT_TZ)
    save_zentra_ports(ports, intent = "closing port windows")
    length(open_rows)
  }, error = function(e) {
    paste0("Failed to close ports: ", e$message)
  })
}

#' Moves a relocated deployment's open ports to the deployment that replaced it
#'
#' @param old_ids,new_ids Character. unique_ids, old and new, in step
#' @param when POSIXct. The move
#' @return TRUE, or an error message string
carry_ports_over <- function(old_ids, new_ids, when) {
  tryCatch({
    ports <- load_zentra_ports_data()
    moved <- list()
    for (k in seq_along(old_ids)) {
      open <- which(ports$unique_id == old_ids[k] & is.na(ports$valid_to))
      if (length(open) == 0) next
      copy <- ports[open, , drop = FALSE]
      copy$unique_id  <- new_ids[k]
      copy$valid_from <- as.POSIXct(when, tz = PROJECT_TZ)
      ports$valid_to[open] <- as.POSIXct(when, tz = PROJECT_TZ)
      moved[[length(moved) + 1]] <- copy
    }
    if (length(moved) == 0) return(TRUE)
    ports <- rbind(ports, do.call(rbind, moved))
    save_zentra_ports(ports, intent = "carrying ports over to a relocated station")
    TRUE
  }, error = function(e) paste0("Failed to carry ports over: ", e$message))
}

#' Is this serial a HOBO logger? (serial-shaped test, for use without metadata)
#' @param device_serial Character
#' @return Logical
is_hobo_device_serial <- function(device_serial) {
  !grepl("^z", device_serial, ignore.case = TRUE)
}

#' Suggests the next station ID for a site and station type
#'
#' station_id is site + station_type, sometimes with a counter. Whether the
#' counter applies is not a property of the type in the abstract - it is
#' whatever that type does at that site. Weather stations are unnumbered
#' because there is only ever one; vwc stations are numbered because there are
#' several. So the rule is read from the existing data rather than hardcoded.
#'
#' If numbered stations of this type already exist at this site, the next
#' number is suggested. If an unnumbered one exists, the site already has the
#' one it gets, and a counter is started at 2. Otherwise the bare form.
#'
#' @param site Character. Site abbreviation, e.g. "sr1"
#' @param station_type Character. e.g. "hydro", "vwc"
#' @return Character. Suggested station_id
suggest_station_id <- function(site, station_type) {

  base <- paste0(tolower(site), "_", tolower(station_type))

  metadata <- load_zentra_metadata()
  existing <- unique(metadata$station_id[!is.na(metadata$station_id)])

  # Anything at this site of this type, numbered or not
  pattern <- paste0("^", base, "([0-9]+)?$")
  hits <- existing[grepl(pattern, existing)]

  if (length(hits) == 0) {
    # No precedent at THIS site, so take the convention from the station type
    # across every site. vwc stations are always numbered because a site has
    # several; weather stations are not because a site has one. Without this,
    # the first vwc station at a new site would be suggested as "lg3_vwc".
    type_pattern <- paste0("_", tolower(station_type), "[0-9]+$")
    numbered_elsewhere <- any(grepl(type_pattern, existing))
    if (numbered_elsewhere) return(paste0(base, "1"))
    return(base)
  }

  # Pull the numeric suffixes that are present
  suffixes <- sub(paste0("^", base), "", hits)
  numbers <- suppressWarnings(as.numeric(suffixes[suffixes != ""]))
  numbers <- numbers[!is.na(numbers)]

  if (length(numbers) > 0) {
    return(paste0(base, max(numbers) + 1))
  }

  # Only an unnumbered one exists - this site already has its single station
  # of this type, so a second needs a counter. Start at 2; the existing
  # unnumbered station is understood as number 1.
  paste0(base, "2")
}

#' Orders devices at a station by role
#'
#' Two loggers at a gauge mean nothing in metadata order; primary then
#' secondary is how they are thought about in the field, so it is how they
#' should be listed. Anything with an unrecognized or missing role sorts last
#' rather than being hidden or dropped.
#'
#' @param devices Data frame of device rows
#' @return The same rows, reordered
order_devices_by_role <- function(devices) {
  if (nrow(devices) < 2) return(devices)

  known <- c("primary", "secondary", "tertiary")
  rank <- match(tolower(trimws(as.character(devices$device_role))), known)
  rank[is.na(rank)] <- length(known) + 1

  devices[order(rank, devices$device_serial), , drop = FALSE]
}

#' Renders a metadata value for display, or "(blank)" if it is empty
#'
#' Comparing a value to "" only works for characters. On a POSIXct it tries to
#' coerce "" into a datetime and errors; on a numeric it yields NA, which if()
#' cannot use. Convert to character first, then test.
#'
#' @param value A single metadata value of any type
#' @return Character, either the value or "(blank)"
blank_or_value <- function(value) {
  if (length(value) == 0 || is.na(value)) return("(blank)")
  as_text <- as.character(value)
  if (!nzchar(trimws(as_text))) return("(blank)")
  as_text
}

#' The name a device goes by
#'
#' The one rule for naming a logger anywhere the engine shows one. A name
#' means something to the person standing at the station; a serial does not.
#'
#'   1. its metadata name - the current row at `station` if given, otherwise
#'      its current row anywhere, otherwise its newest
#'   2. its ZentraCloud name, when `devices` (zc_list_devices) is given
#'   3. its serial
#'
#' @param serial Character vector of device serials
#' @param meta Device metadata; loaded if NULL
#' @param station Character. The station the name is wanted at, or NULL
#' @param devices ZentraCloud device list, or NULL
#' @return Character, one name per serial
device_display_name <- function(serial, meta = NULL, station = NULL, devices = NULL) {
  if (is.null(meta)) meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
  has <- function(x) length(x) == 1 && !is.na(x) && nzchar(trimws(x))
  vapply(as.character(serial), function(sn) {
    if (!has(sn)) return("")
    if (!is.null(meta)) {
      r <- meta[meta$device_serial %in% sn, , drop = FALSE]
      if (!is.null(station) && any(r$station_id %in% station)) r <- r[r$station_id %in% station, , drop = FALSE]
      if (nrow(r) > 0) {
        cur <- r[!tolower(r$status) %in% TERMINAL_STATUSES, , drop = FALSE]
        r <- if (nrow(cur) > 0) cur else r[order(r$deploy_datetime, decreasing = TRUE), , drop = FALSE]
        named <- r$device_name[vapply(r$device_name, has, logical(1))]
        if (length(named) > 0) return(trimws(named[1]))
      }
    }
    if (!is.null(devices) && all(c("device_id", "name") %in% names(devices))) {
      n <- devices$name[match(sn, devices$device_id)]
      if (has(n)) return(trimws(n))
    }
    sn
  }, character(1), USE.NAMES = FALSE)
}

#' Names a device for display: its own name first, serial as the qualifier
#'
#' "Glynn weather (z6-12866)". The serial is left off when the name already
#' carries it ("z6-35228 - ET2"), and stands alone when there is no name.
#'
#' @param x One row of device metadata, or a device serial
#' @param with_role Logical. Add the row's device_role (rows only)
#' @param meta,station,devices For a serial: as device_display_name()
#' @return Character
device_label <- function(x, with_role = FALSE, meta = NULL, station = NULL, devices = NULL) {
  has <- function(v) !is.null(v) && length(v) > 0 && !is.na(v[1]) && nzchar(trimws(v[1]))
  if (is.character(x)) {
    sn <- x[1]
    nm <- device_display_name(sn, meta, station, devices)
    rl <- NA
  } else {
    sn <- as.character(x$device_serial)
    nm <- if (has(x$device_name)) trimws(x$device_name) else sn
    rl <- if (with_role && has(x$device_role)) trimws(x$device_role) else NA
  }
  if (!has(sn)) return("")
  qual <- c(if (!grepl(sn, nm, fixed = TRUE)) sn, if (!is.na(rl)) rl)
  if (length(qual) == 0) nm else paste0(nm, " (", paste(qual, collapse = ", "), ")")
}


################################################################################


#' The row describing a station's CURRENT state
#'
#' get_station_devices() returns every row a station has ever had, including
#' relocated, replaced and removed ones. Taking the first is wrong whenever a
#' station has history: a device added after a relocation inherited the
#' coordinates of the row the relocation had just retired, and landed at the
#' old position.
#'
#' Active rows are preferred, and among them the most recently deployed, since
#' that is what the station looks like now. Where every row is terminal - a
#' decommissioned station being reactivated - the most recent is still the best
#' available answer.
#'
#' @param station_id Character
#' @return One row, or NULL if the station has none
get_station_current_row <- function(station_id) {

  metadata <- load_zentra_metadata()
  rows <- metadata[metadata$station_id == station_id, , drop = FALSE]

  if (nrow(rows) == 0) return(NULL)

  terminal <- TERMINAL_STATUSES
  active <- rows[!tolower(rows$status) %in% terminal, , drop = FALSE]
  if (nrow(active) > 0) rows <- active

  deployed <- suppressWarnings(as.POSIXct(rows$deploy_datetime))
  if (all(is.na(deployed))) return(rows[nrow(rows), ])

  rows[which.max(deployed), ]
}


#' The ground elevation a new logger at a station takes
#'
#' At a paired gauge, the primary's: every logger at the station carries the
#' one elevation, so that a re-lookup can never put a few centimeters of DEM
#' noise between two rows that describe the same place. The difference
#' between the loggers is measured, and kept in surveys.csv. Anywhere else,
#' the station's current row's.
#'
#' @param station_id Character
#' @param metadata Data frame, or NULL to read
#' @return List: elev, elev_source; NULL if the station has no rows
station_elevation <- function(station_id, metadata = NULL) {
  if (is.null(metadata)) metadata <- load_zentra_metadata()
  current <- metadata[metadata$station_id == station_id &
                        !tolower(metadata$status) %in% TERMINAL_STATUSES, , drop = FALSE]
  p <- current[tolower(as.character(current$device_role)) %in% "primary", , drop = FALSE]
  row <- if (nrow(p) == 1) p else get_station_current_row(station_id)
  if (is.null(row)) return(NULL)
  list(elev = row$elev, elev_source = row$elev_source)
}


#' The rows that share a paired gauge's elevation with this one
#'
#' Every current logger at the station that has a role, when this one does;
#' otherwise just this one.
#'
#' @param unique_id Character
#' @param metadata Data frame, or NULL to read
#' @return Character unique_ids
elevation_shared_with <- function(unique_id, metadata = NULL) {
  if (is.null(metadata)) metadata <- load_zentra_metadata()
  r <- metadata[metadata$unique_id == unique_id, ]
  if (nrow(r) != 1 || is.na(r$device_role) || tolower(r$station_type) != "hydro") {
    return(unique_id)
  }
  pair <- metadata$unique_id[metadata$station_id == r$station_id &
                               !tolower(metadata$status) %in% TERMINAL_STATUSES &
                               !is.na(metadata$device_role)]
  unique(c(unique_id, pair))
}


#' Adds the station label to a set of bare station ids, for a menu
#'
#' The viewers build their lists from whatever file they are showing -
#' metadata, the maintenance log, the download log - so they hold bare ids
#' where the workflows hold "id (label)". This gives them the same labels
#' without having to know how one is built.
#'
#' Retired stations are included: a viewer is where someone looks at history.
#' An id with no metadata row is passed through unchanged rather than dropped,
#' since a log can name a station that no longer exists.
#'
#' @param station_ids Character vector
#' @return Character vector of "id (label)", or the bare id where none exists
label_station_options <- function(station_ids) {
  sl <- tryCatch(get_station_list(include_retired = TRUE),
                 error = function(e) NULL)
  if (is.null(sl)) return(station_ids)

  vapply(station_ids, function(id) {
    entry <- sl[[id]]
    if (is.null(entry) || is.null(entry$label) || is.na(entry$label)) id
    else paste0(id, " (", entry$label, ")")
  }, character(1), USE.NAMES = FALSE)
}


################################################################################
#                   WHEN A STATION'S RECORD BECAME TRUSTWORTHY                 #
#                                                                              #
# The ZentraCloud exports reach back to 2021, but device-level history of that #
# era was not systematically recorded. Attribution needs to know which station #
# a device was serving; before some point per station, that is a               #
# reconstruction from notes rather than a contemporaneous log.                 #
#                                                                              #
# Where exactly is a judgement, recorded in record_confirmed.csv. It cannot be #
# derived - the obvious rule, that an entry written long after the visit it    #
# describes was reconstructed, fails because some real entries were logged     #
# from field notes six months late.                                            #
#                                                                              #
# The file holds exceptions plus a default row. A station absent from it is    #
# confirmed from the default, so it does not grow into a list of rows saying   #
# "yes, this one is fine". Written through review_station_records() in tools/. #
################################################################################

RECORD_CONFIRMED_DEFAULT <- "2026-09-01"


#' Reads record_confirmed.csv, creating it with its default row if absent
#'
#' @return Data frame: station_id, confirmed_from, reason
load_record_confirmed <- function() {

  if (!file.exists(table_path("record_confirmed"))) {
    seed <- data.frame(
      station_id     = "(default)",
      confirmed_from = RECORD_CONFIRMED_DEFAULT,
      reason         = paste("metadata manager in routine use from this date;",
                             "any station not listed is confirmed from here"),
      stringsAsFactors = FALSE)
    write_table("record_confirmed", seed)
  }

  # confirmed_from as text: a date entered by hand, read as written
  read_table("record_confirmed", as_text = "confirmed_from")
}


#' The date from which a station's record is considered trustworthy
#'
#' @param station_id Character
#' @return Date
record_confirmed_from <- function(station_id) {
  rc <- load_record_confirmed()
  hit <- rc$confirmed_from[rc$station_id == station_id]
  if (length(hit) == 1 && !is.na(hit)) return(as.Date(hit))

  d <- rc$confirmed_from[rc$station_id == "(default)"]
  as.Date(if (length(d) == 1) d else RECORD_CONFIRMED_DEFAULT)
}


