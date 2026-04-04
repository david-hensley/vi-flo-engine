# metadata_manager_functions.R
# Core logic functions for VI-FLO Engine metadata management
# 
# This file contains "pure" logic functions that are GUI-independent.
# They accept parameters and return results without using readline() or cat().
# This makes them easy to call from either:
#   - R console UI (current implementation)
#   - Future GUI (Shiny, Python, etc.)
#
# Dependencies: Assumes metadata_functions.R is already loaded
#   (provides: load_zentra_metadata, load_zentra_ports_data, 
#    load_maintenance_log, format_datetime_safe, etc.)

################################################################################
#### VALIDATION FUNCTIONS ####
################################################################################
# These check if data exists and is valid
# Return: TRUE if valid, error message string if invalid

#' Check if a device exists in metadata
#' @param device_serial Character. Device serial to check
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
get_station_list <- function() {
  metadata <- load_zentra_metadata()
  stations <- sort(unique(metadata$station_id))
  
  # Build list with site names for display
  station_list <- list()
  for (station in stations) {
    site_full <- metadata$site_full[metadata$station_id == station][1]
    station_list[[station]] <- list(
      station_id = station,
      site_full = site_full
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

#' Get current port configuration for a device
#' @param device_serial Character. Device to query (maps to 'sn' column)
#' @return Data frame with port, type, sensor, depth_cm, status for active configs
#'         Empty ports have sensor="none"
get_current_port_config <- function(device_serial) {
  ports <- load_zentra_ports_data()
  
  device_ports <- ports[ports$sn == device_serial, ]
  
  # Get all ports with valid_to = NA (potentially multiple sextuplets)
  active_ports <- device_ports[is.na(device_ports$valid_to), ]
  
  if (nrow(active_ports) == 0) {
    stop("No active port configuration found for device: ", device_serial)
  }
  
  # If more than 6 rows, take the LAST 6 (most recent sextuplet)
  if (nrow(active_ports) > 6) {
    # Get row indices and take last 6
    active_ports <- tail(active_ports, 6)
  }
  
  # Should now have exactly 6 rows
  if (nrow(active_ports) != 6) {
    warning("Device ", device_serial, " has ", nrow(active_ports), 
            " active ports instead of 6")
  }
  
  # Ensure sorted by port number
  active_ports <- active_ports[order(active_ports$port), ]
  
  return(active_ports[, c("port", "type", "sensor", "depth_cm", "status")])
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

#' Get unique action types from maintenance log
#' @return Character vector of action types
get_unique_action_types <- function() {
  maint_log <- load_maintenance_log()
  
  if (is.null(maint_log) || nrow(maint_log) == 0) {
    return(character())
  }
  
  action_types <- unique(maint_log$action_type)
  return(sort(action_types))
}

################################################################################
#### METADATA MODIFICATION FUNCTIONS ####
################################################################################
# These modify metadata files
# Return: TRUE if successful, character error message if failed
# IMPORTANT: These functions WRITE to files

#' Create a new maintenance log entry
#' @param field_visit_date Character or Date. Date of field visit
#' @param station_id Character. Station visited
#' @param station_type Character. Type of station
#' @param device_serial Character. Device worked on
#' @param action_type Character. What was done
#' @param details Character. Description
#' @param ports_updated Logical. Whether ports were updated
#' @param logged_by Character. Who logged this (initials)
#' @return TRUE if successful, error message if failed
create_maintenance_entry <- function(field_visit_date, station_id, station_type,
                                    device_serial, action_type, details,
                                    ports_updated, logged_by) {
  tryCatch({
    # Use the existing write_maintenance_entry function
    # (from metadata_functions.R)
    write_maintenance_entry(
      field_visit_date = field_visit_date,
      station_id = station_id,
      station_type = station_type,
      device_serial = device_serial,
      action_type = action_type,
      details = details,
      ports_updated = ports_updated,
      logged_by = logged_by
    )
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to create maintenance entry: ", e$message))
  })
}

#' Delete the most recent maintenance log entry for a device
#' Used when user realizes they selected wrong workflow
#' @param device_serial Character. Device whose last entry should be deleted
#' @return TRUE if successful, error message if failed
delete_last_maintenance_entry <- function(device_serial) {
  tryCatch({
    maint_log <- load_maintenance_log()
    
    # Find the most recent entry for this device
    device_entries <- maint_log[maint_log$device_serial == device_serial, ]
    
    if (nrow(device_entries) == 0) {
      return("No maintenance entries found for this device")
    }
    
    # Get the last entry (most recent row)
    last_entry_index <- which(maint_log$device_serial == device_serial)
    last_entry_index <- last_entry_index[length(last_entry_index)]
    
    # Remove that row
    maint_log <- maint_log[-last_entry_index, ]
    
    # Save
    setwd(wds("meta_internal"))
    
    # Format datetime columns before saving
    if ("field_visit_date" %in% names(maint_log)) {
      maint_log$field_visit_date <- as.character(maint_log$field_visit_date)
    }
    if ("timestamp" %in% names(maint_log)) {
      maint_log$timestamp <- format_datetime_safe(maint_log$timestamp)
    }
    
    write.csv(maint_log, "maintenance_log.csv", row.names = FALSE)
    
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
    
    # Find active devices (not decommissioned or relocated)
    active_mask <- !(station_devices$status %in% c("decommissioned", "relocated"))
    active_unique_ids <- station_devices$unique_id[active_mask]
    
    if (length(active_unique_ids) == 0) {
      return("No active devices found at this station")
    }
    
    # Update last_visit
    metadata$last_visit[metadata$unique_id %in% active_unique_ids] <- as.Date(visit_date)
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_visit: ", e$message))
  })
}

#' Update status for active devices at a station
#' @param station_id Character. Station to update
#' @param new_status Character. New status value
#' @return TRUE if successful, error message if failed
update_station_status <- function(station_id, new_status) {
  tryCatch({
    metadata <- load_zentra_metadata()
    station_devices <- metadata[metadata$station_id == station_id, ]
    
    # Find active devices (not decommissioned or relocated)
    active_mask <- !(station_devices$status %in% c("decommissioned", "relocated"))
    active_unique_ids <- station_devices$unique_id[active_mask]
    
    if (length(active_unique_ids) == 0) {
      return("No active devices found at this station")
    }
    
    # Update status
    metadata$status[metadata$unique_id %in% active_unique_ids] <- new_status
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update status: ", e$message))
  })
}

#' Update download approval flag for a station
#' @param station_id Character. Station to update
#' @param approved Logical. Approval status
#' @return TRUE if successful, error message if failed
update_download_approval <- function(station_id, approved) {
  tryCatch({
    # Use existing set_download_approved function
    set_download_approved(station_id = station_id, value = approved)
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update download approval: ", e$message))
  })
}

#' Update device location coordinates
#' @param device_serial Character. Device to update
#' @param lat Numeric. New latitude
#' @param lon Numeric. New longitude  
#' @param elev Numeric or NA. New elevation
#' @return TRUE if successful, error message if failed
update_device_location <- function(device_serial, lat, lon, elev) {
  tryCatch({
    metadata <- load_zentra_metadata()
    device_index <- which(metadata$device_serial == device_serial)
    
    if (length(device_index) == 0) {
      return("Device not found in metadata")
    }
    
    metadata$lat[device_index] <- lat
    metadata$lon[device_index] <- lon
    metadata$elev[device_index] <- elev
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$data_expiry <- as.character(metadata$data_expiry)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update location: ", e$message))
  })
}

#' Update last_download_date for a device
#' @param device_serial Character. Device to update
#' @param download_date Date or character. Date of download
#' @return TRUE if successful, error message if failed
update_last_download_date <- function(device_serial, download_date) {
  tryCatch({
    metadata <- load_zentra_metadata()
    device_index <- which(metadata$device_serial == device_serial)
    
    if (length(device_index) == 0) {
      return("Device not found in metadata")
    }
    # Get device timezone
    device_tz <- metadata$timezone[device_index]
    # Convert date to datetime at noon (realistic for field visits)
    download_datetime <- as.POSIXct(paste(download_date, "12:00:00"), 
                                    tz = device_tz)
    # Update last_download_date
    metadata$last_download_date[device_index] <- download_datetime
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    # Only format data_expiry if it exists
    if ("data_expiry" %in% names(metadata)) {
      metadata$data_expiry <- as.character(metadata$data_expiry)
    }
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_download_date: ", e$message))
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
    
    metadata <- load_zentra_metadata()
    ports <- load_zentra_ports_data()
    
    # Get device deployment datetime
    device_row <- metadata[metadata$device_serial == device_serial, ][1, ]
    deploy_datetime <- parse_datetime_flexible(device_row$deploy_datetime, device_row$timezone)
    
    # Add all 6 port rows
    for (i in 1:nrow(port_config)) {
      # For empty ports, set valid_from and valid_to to NA
      if (port_config$sensor[i] == "none") {
        new_row <- data.frame(
          sn = device_serial,
          port = port_config$port[i],
          type = "none",
          sensor = "none",
          depth_cm = NA,
          status = NA,
          valid_from = NA,
          valid_to = NA,
          stringsAsFactors = FALSE
        )
      } else {
        new_row <- data.frame(
          sn = device_serial,
          port = port_config$port[i],
          type = port_config$type[i],
          sensor = port_config$sensor[i],
          depth_cm = port_config$depth_cm[i],
          status = port_config$status[i],
          valid_from = deploy_datetime,
          valid_to = NA,
          stringsAsFactors = FALSE
        )
      }
      ports <- rbind(ports, new_row)
    }
    
    # Save
    setwd(wds("meta_internal"))
    ports$valid_from <- format_datetime_safe(ports$valid_from)
    ports$valid_to <- format_datetime_safe(ports$valid_to)
    
    write.csv(ports, "zentra_ports.csv", row.names = FALSE)
    
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
    old_port_rows <- ports[ports$sn == device_serial & is.na(ports$valid_to), ]
    
    # Determine if ANY port changed
    any_port_changed <- FALSE
    
    for (i in 1:6) {
      current_port <- current_config[current_config$port == i, ]
      new_port <- port_config[port_config$port == i, ]
      
      # Check if sensor changed
      if (current_port$sensor[1] != new_port$sensor) {
        any_port_changed <- TRUE
        break
      }
      # Check if type changed
      if (current_port$type[1] != new_port$type) {
        any_port_changed <- TRUE
        break
      }
      # Check if depth changed (handle class differences and NAs)
      if (!isTRUE(all.equal(as.numeric(current_port$depth_cm[1]), 
                            as.numeric(new_port$depth_cm), 
                            tolerance = 0.01))) {
        any_port_changed <- TRUE
        break
      }
      # Check if status changed (handle class differences and NAs)
      if (!isTRUE(all.equal(as.character(current_port$status[1]), 
                            as.character(new_port$status)))) {
        any_port_changed <- TRUE
        break
      }
    }
    
    # If nothing changed, don't update
    if (!any_port_changed) {
      return(TRUE)  # Success - no changes needed
    }
    
    # Something changed - handle each port
    
    # Process each port: close old (unless NA/NA empty), create new
    for (port_num in 1:6) {
      new_port <- port_config[port_config$port == port_num, ]
      old_port <- old_port_rows[old_port_rows$port == port_num, ]
      
      # Check if this is an empty-staying-empty with NA/NA
      is_empty_na_na <- (old_port$sensor[1] == "none" && 
                           is.na(old_port$valid_from[1]) && 
                           is.na(old_port$valid_to[1]) &&
                           new_port$sensor == "none")
      
      if (!is_empty_na_na) {
        # Normal case: close the old row
        ports$valid_to[ports$sn == device_serial & 
                         ports$port == port_num & 
                         is.na(ports$valid_to)] <- change_datetime
      }
      # If is_empty_na_na, don't close the old row (leave it NA/NA)
    }
    
    # Create 6 new rows
    new_rows_list <- list()
    
    for (port_num in 1:6) {
      new_port <- port_config[port_config$port == port_num, ]
      old_port <- old_port_rows[old_port_rows$port == port_num, ]
      
      # Check if this is an empty-staying-empty with NA/NA
      is_empty_na_na <- (old_port$sensor[1] == "none" && 
                           is.na(old_port$valid_from[1]) && 
                           is.na(old_port$valid_to[1]) &&
                           new_port$sensor == "none")
      
      if (is_empty_na_na) {
        # Empty staying empty - keep NA/NA
        new_rows_list[[port_num]] <- data.frame(
          sn = as.character(device_serial),
          port = as.integer(port_num),
          type = "none",
          sensor = "none",
          depth_cm = NA_integer_,
          status = NA_character_,
          valid_from = as.POSIXct(NA),
          valid_to = as.POSIXct(NA),
          stringsAsFactors = FALSE
        )
      } else if (new_port$sensor == "none") {
        # Becoming empty or was occupied-empty - use timestamp
        new_rows_list[[port_num]] <- data.frame(
          sn = as.character(device_serial),
          port = as.integer(port_num),
          type = "none",
          sensor = "none",
          depth_cm = NA_integer_,
          status = NA_character_,
          valid_from = change_datetime,
          valid_to = as.POSIXct(NA),
          stringsAsFactors = FALSE
        )
      } else {
        # Occupied port - use timestamp
        new_rows_list[[port_num]] <- data.frame(
          sn = as.character(device_serial),
          port = as.integer(port_num),
          type = as.character(new_port$type),
          sensor = as.character(new_port$sensor),
          depth_cm = as.integer(new_port$depth_cm),
          status = if(is.na(new_port$status)) NA_character_ else as.character(new_port$status),
          valid_from = change_datetime,
          valid_to = as.POSIXct(NA),
          stringsAsFactors = FALSE
        )
      }
    }
    
    # Combine all 6 new rows into one data frame
    new_rows <- do.call(rbind, new_rows_list)
    
    # Add all 6 rows at once
    ports <- rbind(ports, new_rows)
    
    # Save
    setwd(wds("meta_internal"))
    ports$valid_from <- format_datetime_safe(ports$valid_from)
    ports$valid_to <- format_datetime_safe(ports$valid_to)
    
    write.csv(ports, "zentra_ports.csv", row.names = FALSE)
    
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
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Generate unique_id based on manufacturer
    if (tolower(device_data$mfger) == "meter") {
      prefix <- "z"
    } else if (tolower(device_data$mfger) %in% c("onset", "hobo")) {
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
      lat = device_data$lat,
      lon = device_data$lon,
      elev = device_data$elev,
      interval_min = device_data$interval_min,
      timezone = device_data$timezone,
      deploy_datetime = device_data$deploy_datetime,
      status = device_data$status,
      last_update = NA,
      battery = NA,
      last_visit = NA,
      expiry_date = device_data$expiry_date,
      last_download_date = NA,
      last_record_date = NA,
      download_approved = device_data$download_approved,
      stringsAsFactors = FALSE
    )
    
    # Add to metadata
    metadata <- rbind(metadata, new_row)
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
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
#' @param download_approved Logical. Approval for download
#' @return List with success status and new unique_ids
relocate_station <- function(station_id, new_lat, new_lon, deploy_datetime,
                            new_status, download_approved) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Get all devices at this station
    station_devices <- metadata[metadata$station_id == station_id, ]
    
    # Filter to active devices only
    active_mask <- !(station_devices$status %in% c("decommissioned", "relocated"))
    active_devices <- station_devices[active_mask, ]
    
    if (nrow(active_devices) == 0) {
      return(list(success = FALSE, error = "No active devices at this station"))
    }
    
    # Mark old devices as relocated
    metadata$status[metadata$unique_id %in% active_devices$unique_id] <- "relocated"
    
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
      new_row$deploy_datetime <- deploy_datetime
      new_row$status <- new_status
      new_row$last_update <- old_device$last_update  # Copy from old
      new_row$last_visit <- as.Date(deploy_datetime)
      new_row$download_approved <- download_approved
      
      metadata <- rbind(metadata, new_row)
      new_unique_ids <- c(new_unique_ids, new_unique_id)
    }
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(list(success = TRUE, new_unique_ids = new_unique_ids))
  }, error = function(e) {
    return(list(success = FALSE, error = paste0("Failed to relocate station: ", e$message)))
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

#' Prompt user for Y/N response
#' @param prompt Character. Question to ask
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return "Y", "N", or "Q" (if allow_quit=TRUE and user quits)
ui_yes_no <- function(prompt, allow_quit = TRUE) {
  repeat {
    if (allow_quit) {
      cat(prompt, "(Y/N or 'q' to quit): ")
    } else {
      cat(prompt, "(Y/N): ")
    }
    
    response <- toupper(trimws(readline()))
    
    # Accept 1 for Y, 2 for N
    if (response == "1") response <- "Y"
    if (response == "2") response <- "N"
    
    if (allow_quit && tolower(response) == "q") {
      return("Q")
    }
    
    if (response %in% c("Y", "N")) {
      return(response)
    }
    
    cat("⚠️  Please enter Y or N\n")
  }
}

#' Prompt user to select from a numbered menu
#' @param prompt Character. Question to ask
#' @param options Character vector. Menu options
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Selected option string, or NULL if user quit
ui_select_from_menu <- function(prompt, options, allow_quit = TRUE) {
  repeat {
    cat("\n", prompt, "\n", sep = "")
    for (i in seq_along(options)) {
      cat("  ", i, ". ", options[i], "\n", sep = "")
    }
    
    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }
    
    selection <- trimws(readline())
    
    if (allow_quit && tolower(selection) == "q") {
      return(NULL)
    }
    
    if (grepl("^[0-9]+$", selection)) {
      selection_num <- as.numeric(selection)
      if (selection_num >= 1 && selection_num <= length(options)) {
        return(options[selection_num])
      } else {
        cat("⚠️  Invalid number. Please enter 1-", length(options), "\n", sep = "")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
}

#' Prompt user to select from menu with "other (specify)" option
#' @param prompt Character. Question to ask
#' @param existing_options Character vector. Existing options to show
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Selected/entered value, or NULL if user quit
ui_select_or_specify <- function(prompt, existing_options, allow_quit = TRUE) {
  repeat {
    cat("\n", prompt, "\n", sep = "")
    for (i in seq_along(existing_options)) {
      cat("  ", i, ". ", existing_options[i], "\n", sep = "")
    }
    cat("  ", length(existing_options) + 1, ". other (specify)\n", sep = "")
    
    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }
    
    selection <- trimws(readline())
    
    if (allow_quit && tolower(selection) == "q") {
      return(NULL)
    }
    
    if (grepl("^[0-9]+$", selection)) {
      selection_num <- as.numeric(selection)
      
      if (selection_num >= 1 && selection_num <= length(existing_options)) {
        return(existing_options[selection_num])
      } else if (selection_num == length(existing_options) + 1) {
        # Other - specify custom value
        cat("Enter value: ")
        custom_value <- trimws(readline())
        if (custom_value != "") {
          return(custom_value)
        } else {
          cat("⚠️  Value cannot be empty\n")
        }
      } else {
        cat("⚠️  Invalid number\n")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
}

#' Prompt user for a date
#' @param prompt Character. Question to ask
#' @param allow_today Logical. Allow pressing Enter for today (default TRUE)
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Date string (YYYY-MM-DD) or NULL if quit
ui_prompt_date <- function(prompt, allow_today = TRUE, allow_quit = TRUE) {
  repeat {
    if (allow_today) {
      cat(prompt, " (YYYY-MM-DD)\n")
      cat("Or press Enter for today: ")
    } else {
      cat(prompt, " (YYYY-MM-DD): ")
    }
    
    date_input <- trimws(readline())
    
    if (allow_quit && tolower(date_input) == "q") {
      return(NULL)
    }
    
    if (allow_today && date_input == "") {
      return(as.character(Sys.Date()))
    }
    
    # Try to parse date
    parsed_date <- tryCatch({
      as.Date(date_input)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(parsed_date)) {
      return(as.character(parsed_date))
    }
    
    cat("⚠️  Invalid date format. Please use YYYY-MM-DD\n")
  }
}

#' Prompt user for a datetime
#' @param prompt Character. Question to ask
#' @param allow_now Logical. Allow pressing Enter for now (default TRUE)
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @param timezone Character. Timezone to use (default "America/Puerto_Rico")
#' @return POSIXct datetime or NULL if quit
ui_prompt_datetime <- function(prompt, allow_now = TRUE, allow_quit = TRUE, 
                               timezone = "America/Puerto_Rico") {
  repeat {
    if (allow_now) {
      cat(prompt, " (YYYY-MM-DD HH:MM:SS)\n")
      cat("Or press Enter for now: ")
    } else {
      cat(prompt, " (YYYY-MM-DD HH:MM:SS): ")
    }
    
    datetime_input <- trimws(readline())
    
    if (allow_quit && tolower(datetime_input) == "q") {
      return(NULL)
    }
    
    if (allow_now && datetime_input == "") {
      return(as.POSIXct(Sys.time(), tz = timezone))
    }
    
    # Try to parse datetime
    parsed_datetime <- tryCatch({
      as.POSIXct(datetime_input, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(parsed_datetime) && !is.na(parsed_datetime)) {
      return(parsed_datetime)
    }
    
    cat("⚠️  Invalid datetime format. Please use YYYY-MM-DD HH:MM:SS\n")
  }
}

#' Display status reference and prompt for status change
#' @param current_status Character. Current status value
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return New status string, or NULL if user quit, or current_status if no change
ui_prompt_status_change <- function(current_status, allow_quit = TRUE) {
  cat("\nCurrent status: ", current_status, "\n", sep = "")
  cat("\nStatus options:\n")
  cat("  online/local     = working normally\n")
  cat("  defunct          = broken but still deployed\n")
  cat("  nonresponsive    = device not communicating (might recover?)\n")
  cat("  replaced         = swapped for new device\n")
  cat("  relocated        = station moved to a new location\n")
  cat("  decommissioned   = station shut down (can reactivate later)\n\n")
  
  change_response <- ui_yes_no("Change status?", allow_quit = allow_quit)
  
  if (is.null(change_response) || change_response == "Q") {
    return(NULL)  # User quit
  }
  
  if (change_response == "N") {
    return(current_status)  # No change
  }
  
  # User wants to change - show menu
  existing_statuses <- get_metadata_unique_values("status")
  new_status <- ui_select_or_specify("Select new status:", existing_statuses, 
                                     allow_quit = allow_quit)
  
  return(new_status)
}

################################################################################
#### CONSOLE UI MAIN FUNCTIONS ####
################################################################################
# These are the main interactive functions that users call
# Each handles a specific workflow

# --- MAINTENANCE & LOGGING ---
#' Interactive maintenance logging - SIMPLIFIED for routine maintenance only
#' Logs a maintenance entry and updates metadata as needed
#' Relocation, device replacement, and port changes are separate workflows
#' @return List with device_serial, station_id, action_type, or NULL if quit
ui_log_maintenance <- function() {
  cat("\n============================================\n")
  cat("  Routine Maintenance Logger\n")
  cat("============================================\n\n")
  
  #### 1 - Field visit date
  field_visit_date <- ui_prompt_date("When did you visit the field?")
  if (is.null(field_visit_date)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Field visit date:", field_visit_date, "\n\n")
  
  #### 2 - Station selection
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id from selection
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  device_options <- station_devices$device_serial
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  device_serial <- selected_device
  cat("✓ Device:", device_serial, "\n")
  
  #### 4 - Action type (ROUTINE MAINTENANCE ONLY)
  # Standard actions for routine maintenance
  # Removed: relocation, device_removed, device_installed (separate workflows)
  standard_actions <- c("cleaning", "battery", "inspection", "maintenance", "other")
  
  # Add custom actions from log history (exclude the ones with separate workflows)
  custom_actions <- get_unique_action_types()
  excluded_actions <- c(standard_actions, "other", "download", "sensor_swap", 
                        "depth_change", "relocation", "device_removed", "device_installed")
  custom_actions <- setdiff(custom_actions, excluded_actions)
  
  all_actions <- c(standard_actions, custom_actions)
  
  action_type <- ui_select_or_specify("What action was performed?", all_actions)
  if (is.null(action_type)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Action:", action_type, "\n")
  
  #### 5 - Details
  cat("\nEnter details (one line):\n")
  details <- readline()
  cat("✓ Details recorded\n")
  
  #### 6 - Who logged this?
  cat("\nWho is logging this entry?\n")
  cat("  1. DAH\n")
  cat("  2. Enter custom initials (3 letters)\n")
  cat("\nEnter selection: ")
  logged_by_input <- trimws(readline())
  
  if (logged_by_input == "1") {
    logged_by <- "DAH"
  } else if (logged_by_input == "2") {
    repeat {
      cat("Enter 3-letter initials: ")
      custom_initials <- toupper(trimws(readline()))
      if (nchar(custom_initials) == 3) {
        logged_by <- custom_initials
        break
      } else {
        cat("⚠️  Please enter exactly 3 letters\n")
      }
    }
  } else {
    logged_by <- "DAH"  # Default
  }
  cat("✓ Logged by:", logged_by, "\n")
  
  #### 7 - Status update (uses helper function for consistency)
  current_status <- station_devices$status[1]
  new_status <- ui_prompt_status_change(current_status, allow_quit = TRUE)
  
  if (is.null(new_status)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  if (new_status != current_status) {
    cat("✓ New status:", new_status, "\n")
  } else {
    cat("✓ Status unchanged:", current_status, "\n")
  }
  
  #### 8 - Confirmation
  cat("\n============================================\n")
  cat("Ready to log this maintenance entry:\n")
  cat("  Date:", field_visit_date, "\n")
  cat("  Station:", station_id, "\n")
  cat("  Device:", device_serial, "\n")
  cat("  Action:", action_type, "\n")
  cat("  Details:", details, "\n")
  cat("  Logged by:", logged_by, "\n")
  if (new_status != current_status) {
    cat("  Status change: ", current_status, " → ", new_status, "\n", sep = "")
  } else {
    cat("  Status: ", current_status, " (unchanged)\n", sep = "")
  }
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - no entry logged\n")
    return(NULL)
  }
  
  #### 9 - Write maintenance entry
  result <- create_maintenance_entry(
    field_visit_date = field_visit_date,
    station_id = station_id,
    station_type = station_type,
    device_serial = device_serial,
    action_type = action_type,
    details = details,
    ports_updated = FALSE,  # Always FALSE for routine maintenance
    logged_by = logged_by
  )
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Maintenance entry logged\n")
  
  #### 10 - Update last_visit
  result <- update_last_visit(station_id, field_visit_date)
  if (!isTRUE(result)) {
    cat("⚠️  Warning: Could not update last_visit:", result, "\n")
  } else {
    cat("✓ Updated last_visit\n")
  }
  
  #### 11 - Update status if changed
  if (new_status != current_status) {
    result <- update_station_status(station_id, new_status)
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update status:", result, "\n")
    } else {
      cat("✓ Updated status to:", new_status, "\n")
    }
  }
  
  #### 12 - Download approval
  approve_response <- ui_yes_no("\nApprove this station for download?")
  if (approve_response == "Y") {
    result <- update_download_approval(station_id, TRUE)
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update download approval:", result, "\n")
    } else {
      cat("✓ Station approved for download\n")
    }
  } else {
    cat("⚠️  Station NOT approved - remember to approve later if needed\n")
  }
  
  cat("\n✓ All done!\n")
  
  # Return info (removed ports_updated since always FALSE)
  return(list(
    device_serial = device_serial,
    station_id = station_id,
    action_type = action_type
  ))
}

#' Interactive download logging
#' Logs manual data download (for HOBO or local Zentra devices)
#' Simpler than routine maintenance - focused on download event
#' @return List with device_serial, station_id, or NULL if quit
ui_log_download <- function() {
  cat("\n============================================\n")
  cat("  Manual Download Logger\n")
  cat("============================================\n\n")
  
  #### 1 - Field visit date
  field_visit_date <- ui_prompt_date("When did you download data?")
  if (is.null(field_visit_date)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Download date:", field_visit_date, "\n\n")
  
  #### 2 - Station selection
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id from selection
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  device_options <- station_devices$device_serial
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  device_serial <- selected_device
  cat("✓ Device:", device_serial, "\n")
  
  #### 4 - Download details
  cat("\nEnter download details (one line):\n")
  cat("  (e.g., 'Downloaded via waterproof shuttle' or 'Zentra download to iPhone')\n")
  details <- readline()
  if (details == "") {
    details <- "Manual download"
  }
  cat("✓ Details recorded\n")
  
  #### 5 - Who logged this?
  cat("\nWho is logging this entry?\n")
  cat("  1. DAH\n")
  cat("  2. Enter custom initials (3 letters)\n")
  cat("\nEnter selection: ")
  logged_by_input <- trimws(readline())
  
  if (logged_by_input == "1") {
    logged_by <- "DAH"
  } else if (logged_by_input == "2") {
    repeat {
      cat("Enter 3-letter initials: ")
      custom_initials <- toupper(trimws(readline()))
      if (nchar(custom_initials) == 3) {
        logged_by <- custom_initials
        break
      } else {
        cat("⚠️  Please enter exactly 3 letters\n")
      }
    }
  } else {
    logged_by <- "DAH"  # Default
  }
  cat("✓ Logged by:", logged_by, "\n")
  
  #### 6 - Confirmation
  cat("\n============================================\n")
  cat("Ready to log this download:\n")
  cat("  Date:", field_visit_date, "\n")
  cat("  Station:", station_id, "\n")
  cat("  Device:", device_serial, "\n")
  cat("  Details:", details, "\n")
  cat("  Logged by:", logged_by, "\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - no entry logged\n")
    return(NULL)
  }
  
  #### 7 - Write maintenance entry
  result <- create_maintenance_entry(
    field_visit_date = field_visit_date,
    station_id = station_id,
    station_type = station_type,
    device_serial = device_serial,
    action_type = "download",
    details = details,
    ports_updated = FALSE,
    logged_by = logged_by
  )
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Download entry logged\n")
  
  #### 8 - Update last_visit
  result <- update_last_visit(station_id, field_visit_date)
  if (!isTRUE(result)) {
    cat("⚠️  Warning: Could not update last_visit:", result, "\n")
  } else {
    cat("✓ Updated last_visit\n")
  }
  
  #### 9 - Update last_download_date
  result <- update_last_download_date(device_serial, field_visit_date)
  if (!isTRUE(result)) {
    cat("⚠️  Warning: Could not update last_download_date:", result, "\n")
  } else {
    cat("✓ Updated last_download_date\n")
  }
  
  #### 10 - Download approval (optional)
  approve_response <- ui_yes_no("\nApprove this station for future downloads?")
  if (approve_response == "Y") {
    result <- update_download_approval(station_id, TRUE)
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update download approval:", result, "\n")
    } else {
      cat("✓ Station approved for download\n")
    }
  }
  
  cat("\n✓ All done!\n")
  
  # Return info
  return(list(
    device_serial = device_serial,
    station_id = station_id
  ))
}

# --- DEVICE & STATION MANAGEMENT ---
#' Interactive device addition
#' Adds a new device to metadata - either at new station or existing station
#' @param is_new_station Logical. TRUE for brand new station, FALSE for existing
#' @param preset_station_id Character. Optional. If provided, skips station selection
#' @return List with device_serial, or NULL if quit
ui_add_device <- function(is_new_station = TRUE, preset_station_id = NULL) {
  cat("\n============================================\n")
  if (is_new_station) {
    cat("  Add Device - New Station\n")
  } else {
    cat("  Add Device - Existing Station\n")
  }
  cat("============================================\n\n")
  
  # Initialize variables
  station_id <- preset_station_id  # May be NULL
  site_full <- NULL
  site <- NULL
  watershed <- NULL
  area <- NULL
  station_type <- NULL
  
  ################################################################################
  #### SECTION A: STATION INFORMATION ####
  ################################################################################
  
  if (is_new_station) {
    cat("--- NEW STATION INFORMATION ---\n\n")
    
    ## Watershed
    existing_watersheds <- get_metadata_unique_values("watershed")
    watershed <- ui_select_or_specify("Select watershed:", existing_watersheds)
    if (is.null(watershed)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Watershed:", watershed, "\n")
    
    ## Area
    existing_areas <- get_metadata_unique_values("area")
    area <- ui_select_or_specify("Select area:", existing_areas)
    if (is.null(area)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Area:", area, "\n")
    
    ## Site full name
    cat("\nEnter site full name (e.g., 'Salt River 1'):\n")
    site_full <- trimws(readline())
    if (site_full == "") {
      cat("❌ Site name cannot be empty\n")
      return(NULL)
    }
    cat("✓ Site:", site_full, "\n")
    
    ## Site abbreviation
    cat("\nEnter site abbreviation (e.g., 'SR1'):\n")
    site <- trimws(readline())
    if (site == "") {
      cat("❌ Site abbreviation cannot be empty\n")
      return(NULL)
    }
    cat("✓ Site abbrev:", site, "\n")
    
    ## Station type
    existing_types <- get_metadata_unique_values("station_type")
    station_type <- ui_select_or_specify("Select station type:", existing_types)
    if (is.null(station_type)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Station type:", station_type, "\n")
    
    ## Station ID
    cat("\nEnter station ID (e.g., 'sr1_weather'):\n")
    station_id <- trimws(readline())
    if (station_id == "") {
      cat("❌ Station ID cannot be empty\n")
      return(NULL)
    }
    
    # Check if station already exists
    existing_check <- validate_station_exists(station_id)
    if (isTRUE(existing_check)) {
      cat("⚠️  Warning: Station '", station_id, "' already exists!\n", sep = "")
      cat("Use 'New device at existing station' instead.\n")
      return(NULL)
    }
    cat("✓ Station ID:", station_id, "\n")
    
  } else {
    # Existing station
    
    if (is.null(preset_station_id)) {
      # No preset - prompt user to select
      cat("--- SELECT EXISTING STATION ---\n\n")
      
      station_list <- get_station_list()
      station_options <- sapply(station_list, function(s) {
        paste0(s$station_id, " (", s$site_full, ")")
      })
      
      selected <- ui_select_from_menu("Select station:", station_options)
      if (is.null(selected)) {
        cat("❌ Cancelled\n")
        return(NULL)
      }
      
      # Extract station_id
      station_id <- sub(" \\(.*\\)$", "", selected)
    } else {
      # Preset station provided (from replacement workflow)
      cat("--- ADDING TO EXISTING STATION ---\n\n")
      cat("Station:", preset_station_id, "\n\n")
    }
    
    # Get station devices and inherit metadata
    station_devices <- get_station_devices(station_id)
    
    # Inherit from first device at station
    watershed <- station_devices$watershed[1]
    area <- station_devices$area[1]
    site_full <- station_devices$site_full[1]
    site <- station_devices$site[1]
    station_type <- station_devices$station_type[1]
    
    if (is.null(preset_station_id)) {
      cat("✓ Station:", station_id, "\n")
      cat("✓ Inherited: ", watershed, " / ", area, " / ", site_full, "\n", sep = "")
    } else {
      cat("✓ Inherited metadata: ", watershed, " / ", area, " / ", site_full, "\n", sep = "")
    }
  }
  
  ################################################################################
  #### SECTION B: DEVICE INFORMATION ####
  ################################################################################
  
  cat("\n--- DEVICE INFORMATION ---\n\n")
  
  ## Device serial
  cat("Enter device serial number:\n")
  cat("  For Zentra ZL6: format 'z6-12345'\n")
  cat("  For HOBO: format '123456' or actual serial\n")
  cat("Serial: ")
  device_serial <- trimws(readline())
  if (device_serial == "") {
    cat("❌ Device serial cannot be empty\n")
    return(NULL)
  }
  cat("✓ Device serial:", device_serial, "\n")
  
  ## Manufacturer
  existing_mfgers <- get_metadata_unique_values("mfger")
  mfger <- ui_select_or_specify("Select manufacturer:", existing_mfgers)
  if (is.null(mfger)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Manufacturer:", mfger, "\n")
  
  ## Device role (optional)
  specify_role <- ui_yes_no("Specify a device role?", allow_quit = FALSE)
  if (specify_role == "N") {
    device_role <- NA
    cat("✓ No device role recorded\n")
  } else {
    existing_roles <- get_metadata_unique_values("device_role")
    device_role <- ui_select_or_specify("Select device role:", existing_roles)
    if (is.null(device_role)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Device role:", device_role, "\n")
  }
  
  ## Device name (optional)
  cat("\nEnter device name (optional, press Enter to skip):\n")
  device_name <- trimws(readline())
  if (device_name == "") {
    device_name <- NA
    cat("✓ No device name\n")
  } else {
    cat("✓ Device name:", device_name, "\n")
  }
  
  ################################################################################
  #### SECTION C: LOCATION ####
  ################################################################################
  
  cat("\n--- LOCATION ---\n\n")
  
  ## Latitude
  repeat {
    cat("Enter latitude (decimal degrees, e.g., 18.3456):\n")
    lat_input <- trimws(readline())
    lat <- suppressWarnings(as.numeric(lat_input))
    
    if (!is.na(lat) && lat >= -90 && lat <= 90) {
      cat("✓ Latitude:", lat, "\n")
      break
    } else {
      cat("⚠️  Invalid latitude. Must be between -90 and 90.\n")
    }
  }
  
  ## Longitude
  repeat {
    cat("Enter longitude (decimal degrees, e.g., -64.7890):\n")
    lon_input <- trimws(readline())
    lon <- suppressWarnings(as.numeric(lon_input))
    
    if (!is.na(lon) && lon >= -180 && lon <= 180) {
      cat("✓ Longitude:", lon, "\n")
      break
    } else {
      cat("⚠️  Invalid longitude. Must be between -180 and 180.\n")
    }
  }
  
  ## Elevation
  cat("\nEnter elevation in meters (or press Enter to skip):\n")
  elev_input <- trimws(readline())
  if (elev_input == "") {
    elev <- NA
    cat("✓ No elevation recorded\n")
  } else {
    elev <- suppressWarnings(as.numeric(elev_input))
    if (!is.na(elev)) {
      cat("✓ Elevation:", elev, "m\n")
    } else {
      cat("⚠️  Invalid number, skipping elevation\n")
      elev <- NA
    }
  }
  
  ################################################################################
  #### SECTION D: TIMING ####
  ################################################################################
  
  cat("\n--- TIMING ---\n\n")
  
  ## Logging interval
  repeat {
    cat("Enter logging interval in minutes (e.g., 15, 30, 60):\n")
    interval_input <- trimws(readline())
    interval <- suppressWarnings(as.numeric(interval_input))
    
    if (!is.na(interval) && interval > 0) {
      cat("✓ Interval:", interval, "minutes\n")
      break
    } else {
      cat("⚠️  Invalid interval. Must be a positive number.\n")
    }
  }
  
  ## Timezone
  existing_timezones <- get_metadata_unique_values("timezone")
  if (length(existing_timezones) > 0) {
    timezone <- ui_select_or_specify("Select timezone:", existing_timezones)
  } else {
    # Default if no existing timezones
    cat("Enter timezone (e.g., 'America/Puerto_Rico'):\n")
    timezone <- trimws(readline())
  }
  if (is.null(timezone) || timezone == "") {
    cat("❌ Timezone required\n")
    return(NULL)
  }
  cat("✓ Timezone:", timezone, "\n")
  
  ## Deploy datetime
  deploy_datetime <- ui_prompt_datetime("When was device deployed?", 
                                        allow_now = TRUE, 
                                        timezone = timezone)
  if (is.null(deploy_datetime)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Deploy datetime:", format(deploy_datetime), "\n")
  
  ################################################################################
  #### SECTION E: STATUS & SETTINGS ####
  ################################################################################
  
  cat("\n--- STATUS & SETTINGS ---\n\n")
  
  ## Status
  existing_statuses <- get_metadata_unique_values("status")
  status <- ui_select_or_specify("Select device status:", existing_statuses)
  if (is.null(status)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Status:", status, "\n")
  
  ## Download approval
  download_approved_response <- ui_yes_no("Approve this device for automatic download?", 
                                          allow_quit = FALSE)
  download_approved <- (download_approved_response == "Y")
  cat("✓ Download approved:", download_approved, "\n")
  
  ## Expiry date (optional)
  cat("\nEnter data expiry date (YYYY-MM-DD) or press Enter to skip:\n")
  expiry_input <- trimws(readline())
  if (expiry_input == "") {
    data_expiry <- NA
    cat("✓ No expiry date\n")
  } else {
    data_expiry <- tryCatch({
      as.Date(expiry_input)
    }, error = function(e) {
      NA
    })
    
    if (!is.na(data_expiry)) {
      cat("✓ Data expiry:", as.character(data_expiry), "\n")
    } else {
      cat("⚠️  Invalid date format, skipping expiry\n")
      data_expiry <- NA
    }
  }
  
  ################################################################################
  #### SECTION F: CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Ready to add this device:\n")
  cat("  Station:", station_id, "(", site_full, ")\n")
  cat("  Device:", device_serial, "(", mfger, ")\n")
  cat("  Location:", lat, ",", lon, "\n")
  cat("  Deploy:", format(deploy_datetime), "\n")
  cat("  Status:", status, "\n")
  cat("  Download approved:", download_approved, "\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - device not added\n")
    return(NULL)
  }
  
  ################################################################################
  #### SECTION G: CALL LOGIC FUNCTION ####
  ################################################################################
  
  # Build device data structure
  device_data <- list(
    device_serial = device_serial,
    station_id = station_id,
    watershed = watershed,
    area = area,
    site_full = site_full,
    site = site,
    station_type = station_type,
    device_role = device_role,
    device_name = device_name,
    mfger = mfger,
    lat = lat,
    lon = lon,
    elev = elev,
    interval_min = interval,
    timezone = timezone,
    deploy_datetime = deploy_datetime,
    status = status,
    download_approved = download_approved,
    expiry_date = data_expiry
  )
  
  # Call logic function
  result <- add_new_device(device_data)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Device added successfully!\n")
  
  # Return device_serial for potential port initialization
  return(list(device_serial = device_serial))
}

#' Interactive device replacement
#' Marks old device as "replaced" and adds new device at same station
#' @return List with old_device_serial and new_device_serial, or NULL if quit
ui_replace_device <- function() {
  cat("\n============================================\n")
  cat("  Device Replacement\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION & OLD DEVICE ####
  ################################################################################
  
  cat("--- SELECT DEVICE TO REPLACE ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  cat("✓ Station:", station_id, "\n\n")
  
  # Show devices at this station
  cat("Devices at this station:\n")
  for (i in 1:nrow(station_devices)) {
    cat("  ", i, ". ", station_devices$device_serial[i], 
        " (", station_devices$mfger[i], " - ", 
        station_devices$status[i], ")\n", sep = "")
  }
  
  # Select device to replace
  device_options <- station_devices$device_serial
  selected_device <- ui_select_from_menu("\nSelect device to replace:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  old_device_serial <- selected_device
  old_device_row <- station_devices[station_devices$device_serial == old_device_serial, ][1, ]
  
  cat("✓ Replacing device:", old_device_serial, "\n")
  cat("  Manufacturer:", old_device_row$mfger, "\n")
  cat("  Current status:", old_device_row$status, "\n\n")
  
  # Confirm replacement
  confirm_replace <- ui_yes_no(
    paste0("Mark '", old_device_serial, "' as replaced and add new device?"),
    allow_quit = FALSE
  )
  
  if (confirm_replace != "Y") {
    cat("❌ Cancelled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### MARK OLD DEVICE AS REPLACED ####
  ################################################################################
  
  result <- update_station_status(station_id, "replaced")
  if (!isTRUE(result)) {
    cat("❌ Error marking old device as replaced:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Old device marked as 'replaced'\n\n")
  
  ################################################################################
  #### ADD NEW DEVICE (using ui_add_device with preset station) ####
  ################################################################################
  
  cat("--- ADD REPLACEMENT DEVICE ---\n")
  cat("Station: ", station_id, " (", old_device_row$site_full, ")\n\n", sep = "")
  
  # Call ui_add_device with preset station
  add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id)
  
  if (is.null(add_result)) {
    cat("❌ New device not added\n")
    cat("⚠️  Note: Old device was already marked as 'replaced'\n")
    cat("   You may need to manually update its status if needed\n")
    return(NULL)
  }
  
  new_device_serial <- add_result$device_serial
  
  cat("\n✓ Device replacement complete!\n")
  cat("  Old:", old_device_serial, "(replaced)\n")
  cat("  New:", new_device_serial, "\n")
  
  # Return both device serials
  return(list(
    old_device_serial = old_device_serial,
    new_device_serial = new_device_serial
  ))
}

#' Interactive station relocation
#' Moves a station to a new location - marks old device as "relocated" and creates new entry
#' @return TRUE if successful, NULL if quit
ui_relocate_station <- function() {
  cat("\n============================================\n")
  cat("  Station Relocation\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO RELOCATE ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  
  # Get current device (should only be one active)
  current_device <- station_devices[1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", current_device$site_full, "\n")
  cat("  Current device:", current_device$device_serial, "\n")
  cat("  Current location:", current_device$lat, ",", current_device$lon, sep = " ")
  if (!is.na(current_device$elev)) {
    cat(" (", current_device$elev, "m)", sep = "")
  }
  cat("\n\n")
  
  ################################################################################
  #### CONFIRM RELOCATION ####
  ################################################################################
  
  confirm_relocate <- ui_yes_no(
    paste0("Relocate station '", station_id, "' to a new location?"),
    allow_quit = FALSE
  )
  
  if (confirm_relocate != "Y") {
    cat("❌ Cancelled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### NEW LOCATION ####
  ################################################################################
  
  cat("\n--- NEW LOCATION ---\n\n")
  
  ## New latitude
  repeat {
    cat("Enter NEW latitude (decimal degrees, e.g., 18.3456):\n")
    lat_input <- trimws(readline())
    new_lat <- suppressWarnings(as.numeric(lat_input))
    
    if (!is.na(new_lat) && new_lat >= -90 && new_lat <= 90) {
      cat("✓ New latitude:", new_lat, "\n")
      break
    } else {
      cat("⚠️  Invalid latitude. Must be between -90 and 90.\n")
    }
  }
  
  ## New longitude
  repeat {
    cat("Enter NEW longitude (decimal degrees, e.g., -64.7890):\n")
    lon_input <- trimws(readline())
    new_lon <- suppressWarnings(as.numeric(lon_input))
    
    if (!is.na(new_lon) && new_lon >= -180 && new_lon <= 180) {
      cat("✓ New longitude:", new_lon, "\n")
      break
    } else {
      cat("⚠️  Invalid longitude. Must be between -180 and 180.\n")
    }
  }
  
  ## New elevation (optional)
  cat("\nEnter NEW elevation in meters (or press Enter to skip):\n")
  elev_input <- trimws(readline())
  if (elev_input == "") {
    new_elev <- NA
    cat("✓ No elevation recorded\n")
  } else {
    new_elev <- suppressWarnings(as.numeric(elev_input))
    if (!is.na(new_elev)) {
      cat("✓ New elevation:", new_elev, "m\n")
    } else {
      cat("⚠️  Invalid number, skipping elevation\n")
      new_elev <- NA
    }
  }
  
  ################################################################################
  #### DEPLOYMENT AT NEW LOCATION ####
  ################################################################################
  
  cat("\n--- DEPLOYMENT AT NEW LOCATION ---\n\n")
  
  ## Deploy datetime at new location
  deploy_datetime <- ui_prompt_datetime(
    "When was station deployed at new location?",
    allow_now = TRUE,
    timezone = current_device$timezone
  )
  
  if (is.null(deploy_datetime)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Deploy datetime:", format(deploy_datetime), "\n")
  
  ## Status at new location
  cat("\n")
  existing_statuses <- get_metadata_unique_values("status")
  new_status <- ui_select_or_specify("Select status at new location:", existing_statuses)
  if (is.null(new_status)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Status:", new_status, "\n")
  
  ## Download approval
  download_approved_response <- ui_yes_no("\nApprove station for download at new location?", 
                                          allow_quit = FALSE)
  download_approved <- (download_approved_response == "Y")
  cat("✓ Download approved:", download_approved, "\n")
  
  ################################################################################
  #### CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Station Relocation Summary:\n")
  cat("============================================\n")
  cat("Station:", station_id, "(", current_device$site_full, ")\n")
  cat("\nOLD LOCATION:\n")
  cat("  Device:", current_device$device_serial, "\n")
  cat("  Location:", current_device$lat, ",", current_device$lon, sep = " ")
  if (!is.na(current_device$elev)) {
    cat(" (", current_device$elev, "m)", sep = "")
  }
  cat("\n  Status: → 'relocated'\n")
  cat("\nNEW LOCATION:\n")
  cat("  Device:", current_device$device_serial, "(new metadata row)\n")
  cat("  Location:", new_lat, ",", new_lon, sep = " ")
  if (!is.na(new_elev)) {
    cat(" (", new_elev, "m)", sep = "")
  }
  cat("\n  Deploy:", format(deploy_datetime), "\n")
  cat("  Status:", new_status, "\n")
  cat("  Download approved:", download_approved, "\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm relocation?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - station not relocated\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- relocate_station(
    station_id = station_id,
    new_lat = new_lat,
    new_lon = new_lon,
    new_elev = new_elev,
    deploy_datetime = deploy_datetime,
    new_status = new_status,
    download_approved = download_approved
  )
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Station relocation complete!\n")
  cat("  Old device marked as 'relocated'\n")
  cat("  New metadata row created at new location\n")
  
  return(TRUE)
}

#' Interactive station decommissioning
#' Shuts down a station permanently - marks device as "decommissioned"
#' Can be reactivated later if needed
#' @return TRUE if successful, NULL if quit
ui_decommission_station <- function() {
  cat("\n============================================\n")
  cat("  Station Decommissioning\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO DECOMMISSION ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  
  # Get current device
  current_device <- station_devices[1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", current_device$site_full, "\n")
  cat("  Device:", current_device$device_serial, "\n")
  cat("  Current status:", current_device$status, "\n")
  cat("  Location:", current_device$lat, ",", current_device$lon, "\n\n")
  
  ################################################################################
  #### CONFIRM DECOMMISSIONING ####
  ################################################################################
  
  cat("⚠️  DECOMMISSIONING STATION\n")
  cat("This will:\n")
  cat("  - Mark the station as 'decommissioned'\n")
  cat("  - Stop monitoring at this location\n")
  cat("  - Can be reactivated later if needed\n\n")
  
  confirm_decommission <- ui_yes_no(
    paste0("Decommission station '", station_id, "'?"),
    allow_quit = FALSE
  )
  
  if (confirm_decommission != "Y") {
    cat("❌ Cancelled - station not decommissioned\n")
    return(NULL)
  }
  
  # Double-check
  cat("\n⚠️  This is a significant action.\n")
  final_confirm <- ui_yes_no("Are you sure you want to decommission this station?", 
                             allow_quit = FALSE)
  
  if (final_confirm != "Y") {
    cat("❌ Cancelled - station not decommissioned\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- update_station_status(station_id, "decommissioned")
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Station decommissioned successfully\n")
  cat("  Station:", station_id, "\n")
  cat("  Status: → 'decommissioned'\n")
  cat("\n  Note: This station can be reactivated later if needed.\n")
  
  return(TRUE)
}

#' Interactive station reactivation
#' Reactivates a decommissioned station by adding a new device
#' Can use same location or new location
#' @return List with device_serial, or NULL if quit
ui_reactivate_station <- function() {
  cat("\n============================================\n")
  cat("  Reactivate Decommissioned Station\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT DECOMMISSIONED STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO REACTIVATE ---\n\n")
  
  # Get all devices and filter to decommissioned only
  metadata <- load_zentra_metadata()
  decommissioned <- metadata[metadata$status == "decommissioned", ]
  
  if (nrow(decommissioned) == 0) {
    cat("❌ No decommissioned stations found\n")
    return(NULL)
  }
  
  # Get unique stations from decommissioned devices
  decommissioned_stations <- unique(decommissioned$station_id)
  
  # Build station options
  station_options <- sapply(decommissioned_stations, function(sid) {
    device_row <- decommissioned[decommissioned$station_id == sid, ][1, ]
    paste0(sid, " (", device_row$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select decommissioned station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  old_device <- decommissioned[decommissioned$station_id == station_id, ][1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", old_device$site_full, "\n")
  cat("  Last device:", old_device$device_serial, "\n")
  cat("  Last location:", old_device$lat, ",", old_device$lon, "\n")
  cat("  Decommissioned status:", old_device$status, "\n\n")
  
  ################################################################################
  #### SAME OR NEW LOCATION? ####
  ################################################################################
  
  cat("--- REACTIVATION TYPE ---\n\n")
  cat("Reactivate at:\n")
  cat("  1. Same location (", old_device$lat, ", ", old_device$lon, ")\n", sep = "")
  cat("  2. New location (different coordinates)\n")
  cat("  q. Cancel\n")
  cat("\nEnter selection: ")
  
  location_choice <- trimws(readline())
  
  if (tolower(location_choice) == "q") {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  same_location <- (location_choice == "1")
  
  if (same_location) {
    cat("✓ Reactivating at same location\n\n")
  } else if (location_choice == "2") {
    cat("✓ Reactivating at new location\n\n")
  } else {
    cat("❌ Invalid selection\n")
    return(NULL)
  }
  
  ################################################################################
  #### ADD DEVICE AT REACTIVATED STATION ####
  ################################################################################
  
  if (same_location) {
    # Use ui_add_device with preset station
    cat("--- ADD DEVICE FOR REACTIVATION ---\n")
    cat("Station: ", station_id, " (", old_device$site_full, ")\n\n", sep = "")
    
    add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id)
    
    if (is.null(add_result)) {
      cat("❌ Reactivation cancelled\n")
      return(NULL)
    }
    
    new_device_serial <- add_result$device_serial
    
    # Update location to match old station (using helper function)
    result <- update_device_location(new_device_serial, 
                                     old_device$lat, 
                                     old_device$lon, 
                                     old_device$elev)
    
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update location:", result, "\n")
    } else {
      cat("\n✓ Location set to match old station coordinates\n")
    }
    
  } else {
    # New location - use relocate_station logic
    cat("--- NEW LOCATION FOR REACTIVATION ---\n\n")
    
    ## New latitude
    repeat {
      cat("Enter NEW latitude (decimal degrees, e.g., 18.3456):\n")
      lat_input <- trimws(readline())
      new_lat <- suppressWarnings(as.numeric(lat_input))
      
      if (!is.na(new_lat) && new_lat >= -90 && new_lat <= 90) {
        cat("✓ New latitude:", new_lat, "\n")
        break
      } else {
        cat("⚠️  Invalid latitude. Must be between -90 and 90.\n")
      }
    }
    
    ## New longitude
    repeat {
      cat("Enter NEW longitude (decimal degrees, e.g., -64.7890):\n")
      lon_input <- trimws(readline())
      new_lon <- suppressWarnings(as.numeric(lon_input))
      
      if (!is.na(new_lon) && new_lon >= -180 && new_lon <= 180) {
        cat("✓ New longitude:", new_lon, "\n")
        break
      } else {
        cat("⚠️  Invalid longitude. Must be between -180 and 180.\n")
      }
    }
    
    ## New elevation (optional)
    cat("\nEnter NEW elevation in meters (or press Enter to skip):\n")
    elev_input <- trimws(readline())
    if (elev_input == "") {
      new_elev <- NA
      cat("✓ No elevation recorded\n")
    } else {
      new_elev <- suppressWarnings(as.numeric(elev_input))
      if (!is.na(new_elev)) {
        cat("✓ New elevation:", new_elev, "m\n")
      } else {
        cat("⚠️  Invalid number, skipping elevation\n")
        new_elev <- NA
      }
    }
    
    ## Deploy datetime
    deploy_datetime <- ui_prompt_datetime(
      "When was station reactivated?",
      allow_now = TRUE,
      timezone = old_device$timezone
    )
    
    if (is.null(deploy_datetime)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Deploy datetime:", format(deploy_datetime), "\n")
    
    ## Status
    cat("\n")
    existing_statuses <- get_metadata_unique_values("status")
    new_status <- ui_select_or_specify("Select status:", existing_statuses)
    if (is.null(new_status)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Status:", new_status, "\n")
    
    ## Download approval
    download_approved_response <- ui_yes_no("\nApprove station for download?", 
                                            allow_quit = FALSE)
    download_approved <- (download_approved_response == "Y")
    cat("✓ Download approved:", download_approved, "\n")
    
    # Call relocate_station (which handles creating new row at new location)
    result <- relocate_station(
      station_id = station_id,
      new_lat = new_lat,
      new_lon = new_lon,
      new_elev = new_elev,
      deploy_datetime = deploy_datetime,
      new_status = new_status,
      download_approved = download_approved
    )
    
    if (!isTRUE(result)) {
      cat("❌ Error:", result, "\n")
      return(NULL)
    }
    
    # Get the newly created device serial
    metadata <- load_zentra_metadata()
    station_devices <- metadata[metadata$station_id == station_id, ]
    active_devices <- station_devices[is.na(station_devices$valid_to) | 
                                        station_devices$status %in% c("online", "local"), ]
    new_device_serial <- active_devices$device_serial[nrow(active_devices)]
  }
  
  cat("\n✓ Station reactivated successfully!\n")
  cat("  Station:", station_id, "\n")
  cat("  New device:", new_device_serial, "\n")
  
  # Return device_serial for potential port initialization
  return(list(device_serial = new_device_serial))
}

# --- PORT CONFIGURATION ---
#' Interactive port configuration initialization
#' Sets up initial port configuration for a new Zentra ZL6 device
#' ONLY for Zentra devices - HOBO devices don't have ports
#' @param device_serial Character. Device to configure (must start with 'z')
#' @return TRUE if successful, NULL if quit or error
ui_initialize_ports <- function(device_serial) {
  cat("\n============================================\n")
  cat("  Initialize Port Configuration\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### VALIDATION ####
  ################################################################################
  
  # Check if device is Zentra (starts with 'z')
  if (!grepl("^z", device_serial, ignore.case = TRUE)) {
    cat("❌ Error: Port configuration is only for Zentra ZL6 devices\n")
    cat("   Device '", device_serial, "' does not appear to be a ZL6 logger\n", sep = "")
    cat("   (ZL6 serials start with 'z')\n")
    return(NULL)
  }
  
  # Check if device exists
  valid <- validate_device_exists(device_serial)
  if (!isTRUE(valid)) {
    cat("❌ Error:", valid, "\n")
    return(NULL)
  }
  
  cat("Configuring ports for device:", device_serial, "\n\n")
  
  # Get existing sensor types for menu
  existing_sensors <- get_unique_sensor_types()
  
  ################################################################################
  #### PORT-BY-PORT CONFIGURATION ####
  ################################################################################
  
  # Initialize port config data frame
  port_config <- data.frame(
    port = 1:6,
    type = character(6),
    sensor = character(6),
    depth_cm = numeric(6),
    status = character(6),
    stringsAsFactors = FALSE
  )
  
  for (port_num in 1:6) {
    cat("\n--- PORT ", port_num, " ---\n", sep = "")
    
    # Ask if port is occupied
    occupied <- ui_yes_no(paste0("Is port ", port_num, " occupied?"), allow_quit = FALSE)
    
    if (occupied == "N") {
      # Empty port
      port_config$type[port_num] <- "none"
      port_config$sensor[port_num] <- "none"
      port_config$depth_cm[port_num] <- NA
      port_config$status[port_num] <- NA
      cat("✓ Port ", port_num, ": Empty\n", sep = "")
      next
    }
    
    # Port is occupied - get sensor details
    
    ## Sensor type
    sensor_type <- ui_select_or_specify(
      paste0("Select sensor for port ", port_num, ":"),
      existing_sensors,
      allow_quit = FALSE
    )
    port_config$sensor[port_num] <- sensor_type
    
    ## Auto-determine type (vwc/weather)
    sensor_category <- determine_sensor_type(sensor_type)
    port_config$type[port_num] <- sensor_category
    cat("✓ Sensor type detected:", sensor_category, "\n")
    
    ## Depth (only for VWC sensors typically)
    has_depth <- ui_yes_no("Does this sensor measure at a specific depth?", 
                           allow_quit = FALSE)
    
    if (has_depth == "Y") {
      repeat {
        cat("Enter depth in cm (e.g., 10, 30, 50): ")
        depth_input <- trimws(readline())
        depth <- suppressWarnings(as.numeric(depth_input))
        
        if (!is.na(depth) && depth >= 0) {
          port_config$depth_cm[port_num] <- depth
          cat("✓ Depth:", depth, "cm\n")
          break
        } else {
          cat("⚠️  Invalid depth. Must be a positive number.\n")
        }
      }
    } else {
      port_config$depth_cm[port_num] <- NA
      cat("✓ No depth measurement\n")
    }
    
    ## Defunct status
    is_defunct <- ui_yes_no("Is this sensor defunct (seemingly broken but still plugged in)?", 
                            allow_quit = FALSE)
    
    if (is_defunct == "Y") {
      port_config$status[port_num] <- "defunct"
      cat("⚠️  Port ", port_num, " marked as defunct\n", sep = "")
    } else {
      port_config$status[port_num] <- NA
      cat("✓ Sensor is functional\n")
    }
    
    cat("✓ Port ", port_num, ": ", sensor_type, 
        if (!is.na(port_config$depth_cm[port_num])) paste0(" @ ", port_config$depth_cm[port_num], "cm") else "",
        "\n", sep = "")
  }
  
  ################################################################################
  #### VALIDATION ####
  ################################################################################
  
  # Check for duplicate ports (shouldn't happen with this UI, but safety check)
  occupied_ports <- port_config[port_config$sensor != "none", ]
  if (nrow(occupied_ports) > 0) {
    valid <- validate_no_duplicate_ports(occupied_ports)
    if (!isTRUE(valid)) {
      cat("❌ Error:", valid, "\n")
      return(NULL)
    }
  }
  
  ################################################################################
  #### SUMMARY & CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Port Configuration Summary:\n")
  cat("============================================\n")
  for (i in 1:6) {
    if (port_config$sensor[i] == "none") {
      cat("  Port ", i, ": Empty\n", sep = "")
    } else {
      cat("  Port ", i, ": ", port_config$sensor[i], 
          " (", port_config$type[i], ")",
          sep = "")
      if (!is.na(port_config$depth_cm[i])) {
        cat(" @ ", port_config$depth_cm[i], "cm", sep = "")
      }
      if (!is.na(port_config$status[i]) && port_config$status[i] == "defunct") {
        cat(" [DEFUNCT]", sep = "")
      }
      cat("\n")
    }
  }
  cat("============================================\n\n")
  
  # Warn if all ports are empty
  if (all(port_config$sensor == "none")) {
    cat("⚠️  WARNING: All ports are empty. Is this correct?\n")
  }
  
  confirm <- ui_yes_no("Save this configuration?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - configuration not saved\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- initialize_ports(device_serial, port_config)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Port configuration saved successfully!\n")
  
  return(TRUE)
}

#' Interactive port configuration update
#' Updates port configuration for an existing Zentra ZL6 device
#' Shows current config and prompts for changes
#' @return TRUE if successful, NULL if quit or error
ui_update_ports <- function() {
  cat("\n============================================\n")
  cat("  Update Port Configuration\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### DEVICE SELECTION ####
  ################################################################################
  
  # Get all devices and filter to Zentra only
  metadata <- load_zentra_metadata()
  zentra_devices <- metadata[grepl("^z", metadata$device_serial, ignore.case = TRUE), ]
  
  if (nrow(zentra_devices) == 0) {
    cat("❌ No Zentra devices found in metadata\n")
    return(NULL)
  }
  
  # Build device options
  device_options <- paste0(zentra_devices$device_serial, 
                           " (", zentra_devices$station_id, " - ", 
                           zentra_devices$site_full, ")")
  
  selected <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract device_serial
  device_serial <- sub(" \\(.*\\)$", "", selected)
  cat("✓ Device:", device_serial, "\n\n")
  
  ################################################################################
  #### GET CURRENT CONFIGURATION ####
  ################################################################################
  
  current_config <- get_current_port_config(device_serial)
  
  cat("--- CURRENT PORT CONFIGURATION ---\n")
  for (i in 1:6) {
    if (current_config$sensor[i] == "none") {
      cat("  Port ", i, ": Empty\n", sep = "")
    } else {
      cat("  Port ", i, ": ", current_config$sensor[i], 
          " (", current_config$type[i], ")",
          sep = "")
      if (!is.na(current_config$depth_cm[i])) {
        cat(" @ ", current_config$depth_cm[i], "cm", sep = "")
      }
      if (!is.na(current_config$status[i]) && current_config$status[i] == "defunct") {
        cat(" [DEFUNCT]", sep = "")
      }
      cat("\n")
    }
  }
  cat("\n")
  
  ################################################################################
  #### CHANGE DATETIME ####
  ################################################################################
  
  # Get device timezone for datetime prompt
  device_row <- metadata[metadata$device_serial == device_serial, ][1, ]
  device_timezone <- device_row$timezone
  
  cat("When did this port configuration change occur?\n")
  cat("(This should be date AND time, as exact as possible)\n\n")
  
  change_datetime <- ui_prompt_datetime(
    "Enter change datetime",
    allow_now = TRUE,
    timezone = device_timezone
  )
  
  if (is.null(change_datetime)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  cat("✓ Change datetime:", format(change_datetime), "\n")
  
  ################################################################################
  #### PORT-BY-PORT UPDATE ####
  ################################################################################
  
  # Get existing sensor types for menu
  existing_sensors <- get_unique_sensor_types()
  
  # Initialize new config (will update as we go)
  new_config <- current_config
  changes_made <- character(6)  # Track what changed per port
  
  for (port_num in 1:6) {
    cat("\n--- PORT ", port_num, " ---\n", sep = "")
    
    # Show current state
    if (current_config$sensor[port_num] == "none") {
      cat("Current: Empty\n")
    } else {
      cat("Current: ", current_config$sensor[port_num], sep = "")
      if (!is.na(current_config$depth_cm[port_num])) {
        cat(" @ ", current_config$depth_cm[port_num], "cm", sep = "")
      }
      if (!is.na(current_config$status[port_num]) && 
          current_config$status[port_num] == "defunct") {
        cat(" [DEFUNCT]", sep = "")
      }
      cat("\n")
    }
    
    # Ask if changing this port
    change_port <- ui_yes_no(paste0("Change port ", port_num, "?"), allow_quit = FALSE)
    
    if (change_port == "N") {
      changes_made[port_num] <- "no change"
      next
    }
    
    # User wants to change this port
    
    ## Ask if removing sensor or reconfiguring
    occupied <- ui_yes_no(paste0("Will port ", port_num, " have a sensor in this configuration?"), 
                          allow_quit = FALSE)
    
    if (occupied == "N") {
      # Port being emptied
      if (current_config$sensor[port_num] == "none") {
        cat("⚠️  Port was already empty - no change\n")
        changes_made[port_num] <- "no change"
      } else {
        new_config$type[port_num] <- "none"
        new_config$sensor[port_num] <- "none"
        new_config$depth_cm[port_num] <- NA
        new_config$status[port_num] <- NA
        changes_made[port_num] <- "REMOVED"
        cat("✓ Port ", port_num, " will be emptied\n", sep = "")
      }
      next
    }
    
    # Port is occupied - get new sensor details
    
    ## Sensor type
    sensor_type <- ui_select_or_specify(
      paste0("Select sensor for port ", port_num, ":"),
      existing_sensors,
      allow_quit = FALSE
    )
    
    ## Auto-determine type (vwc/weather)
    sensor_category <- determine_sensor_type(sensor_type)
    cat("✓ Sensor type detected:", sensor_category, "\n")
    
    ## Depth
    has_depth <- ui_yes_no("Does this sensor measure at a specific depth?", 
                           allow_quit = FALSE)
    
    new_depth <- NA
    if (has_depth == "Y") {
      repeat {
        cat("Enter depth in cm (e.g., 10, 30, 50): ")
        depth_input <- trimws(readline())
        depth <- suppressWarnings(as.numeric(depth_input))
        
        if (!is.na(depth) && depth >= 0) {
          new_depth <- depth
          cat("✓ Depth:", depth, "cm\n")
          break
        } else {
          cat("⚠️  Invalid depth. Must be a positive number.\n")
        }
      }
    } else {
      cat("✓ No depth measurement\n")
    }
    
    ## Defunct status
    is_working <- ui_yes_no("Is this sensor in good working order? (Considered 'defunct' - broken but still plugged in - if you say no)", 
                            allow_quit = FALSE)
    
    # Then below:
    new_status <- NA
    if (is_working == "N") {  # REVERSED
      new_status <- "defunct"
      cat("⚠️  Sensor marked as defunct\n")
    } else {
      cat("✓ Sensor is functional\n")
    }
    
    # Update config
    new_config$type[port_num] <- sensor_category
    new_config$sensor[port_num] <- sensor_type
    new_config$depth_cm[port_num] <- new_depth
    new_config$status[port_num] <- new_status
    
    # Determine what changed
    if (current_config$sensor[port_num] == "none") {
      changes_made[port_num] <- "ADDED"
    } else {
      changes_made[port_num] <- "CHANGED"
    }
    
    cat("✓ Port ", port_num, " updated\n", sep = "")
  }
  
  ################################################################################
  #### VALIDATION ####
  ################################################################################
  
  # Check for duplicate ports
  occupied_ports <- new_config[new_config$sensor != "none", ]
  if (nrow(occupied_ports) > 0) {
    valid <- validate_no_duplicate_ports(occupied_ports)
    if (!isTRUE(valid)) {
      cat("❌ Error:", valid, "\n")
      return(NULL)
    }
  }
  
  ################################################################################
  #### SUMMARY & CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Port Configuration Changes:\n")
  cat("============================================\n")
  cat("Change datetime: ", format(change_datetime), "\n\n", sep = "")
  
  any_changes <- FALSE
  for (i in 1:6) {
    if (changes_made[i] != "no change" && changes_made[i] != "") {
      any_changes <- TRUE
      cat("  Port ", i, " [", changes_made[i], "]: ", sep = "")
      
      if (new_config$sensor[i] == "none") {
        cat("Empty\n")
      } else {
        cat(new_config$sensor[i], " (", new_config$type[i], ")", sep = "")
        if (!is.na(new_config$depth_cm[i])) {
          cat(" @ ", new_config$depth_cm[i], "cm", sep = "")
        }
        if (!is.na(new_config$status[i]) && new_config$status[i] == "defunct") {
          cat(" [DEFUNCT]", sep = "")
        }
        cat("\n")
      }
    }
  }
  
  if (!any_changes) {
    cat("  No changes made\n")
  }
  cat("============================================\n\n")
  
  if (!any_changes) {
    cat("⚠️  No ports were changed. Configuration not updated.\n")
    return(NULL)
  }
  
  confirm <- ui_yes_no("Save these changes?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - configuration not updated\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- update_ports(device_serial, new_config, change_datetime)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Port configuration updated successfully!\n")
  
  return(TRUE)
}

# --- VIEW FUNCTIONS ---
#' View device metadata
#' Displays device metadata in readable format with filtering options
#' @return NULL (display only)
ui_view_metadata <- function() {
  cat("\n============================================\n")
  cat("  View Device Metadata\n")
  cat("============================================\n\n")
  
  metadata <- load_zentra_metadata()
  
  if (nrow(metadata) == 0) {
    cat("❌ No devices found in metadata\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. All devices\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by status\n")
  cat("  4. Filter by manufacturer\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_metadata <- metadata
  filter_description <- "All devices"
  
  if (view_choice == "2") {
    # Filter by station
    stations <- sort(unique(metadata$station_id))
    station_options <- stations
    
    selected_station <- ui_select_from_menu("Select station:", station_options)
    if (is.null(selected_station)) {
      return(NULL)
    }
    
    filtered_metadata <- metadata[metadata$station_id == selected_station, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by status
    statuses <- sort(unique(metadata$status))
    selected_status <- ui_select_from_menu("Select status:", statuses)
    if (is.null(selected_status)) {
      return(NULL)
    }
    
    filtered_metadata <- metadata[metadata$status == selected_status, ]
    filter_description <- paste0("Status: ", selected_status)
    
  } else if (view_choice == "4") {
    # Filter by manufacturer
    mfgers <- sort(unique(metadata$mfger))
    selected_mfger <- ui_select_from_menu("Select manufacturer:", mfgers)
    if (is.null(selected_mfger)) {
      return(NULL)
    }
    
    filtered_metadata <- metadata[metadata$mfger == selected_mfger, ]
    filter_description <- paste0("Manufacturer: ", selected_mfger)
  }
  
  ################################################################################
  #### DISPLAY METADATA ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Device Metadata - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_metadata), " device(s)\n\n", sep = "")
  
  if (nrow(filtered_metadata) == 0) {
    cat("No devices match this filter\n")
    return(NULL)
  }
  
  for (i in 1:nrow(filtered_metadata)) {
    device <- filtered_metadata[i, ]
    
    cat("--- DEVICE ", i, " ---\n", sep = "")
    cat("Unique ID:    ", device$unique_id, "\n", sep = "")
    cat("Serial:       ", device$device_serial, "\n", sep = "")
    cat("Station:      ", device$station_id, " (", device$site_full, ")\n", sep = "")
    cat("Manufacturer: ", device$mfger, "\n", sep = "")
    cat("Role:         ", device$device_role, "\n", sep = "")
    cat("Status:       ", device$status, "\n", sep = "")
    cat("Location:     ", device$lat, ", ", device$lon, sep = "")
    if (!is.na(device$elev)) {
      cat(" (", device$elev, "m)", sep = "")
    }
    cat("\n")
    cat("Interval:     ", device$interval, " minutes\n", sep = "")
    cat("Timezone:     ", device$timezone, "\n", sep = "")
    cat("Deployed:     ", format(device$deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    if (!is.na(device$last_visit)) {
      cat("Last visit:   ", format(device$last_visit, "%Y-%m-%d"), "\n", sep = "")
    }
    if (!is.na(device$last_download_date)) {
      cat("Last download:", format(device$last_download_date, "%Y-%m-%d"), "\n", sep = "")
    }
    cat("Download appr:", device$download_approved, "\n", sep = "")
    cat("\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' View port configurations
#' Displays port configurations for devices
#' @return NULL (display only)
ui_view_ports <- function() {
  cat("\n============================================\n")
  cat("  View Port Configurations\n")
  cat("============================================\n\n")
  
  ports <- load_zentra_ports_data()
  
  if (nrow(ports) == 0) {
    cat("❌ No port configurations found\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. All devices (active configs only)\n")
  cat("  2. Specific device (all configs including history)\n")
  cat("  3. Specific device (active configs only)\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  if (view_choice == "1") {
    # All devices - active configs only
    devices <- sort(unique(ports$sn))
    
    cat("\n============================================\n")
    cat("Active Port Configurations - All Devices\n")
    cat("============================================\n")
    cat("Found ", length(devices), " device(s) with active configs\n\n", sep = "")
    
    for (device in devices) {
      # Get active ports for this device
      device_active <- ports[ports$sn == device & is.na(ports$valid_to), ]
      
      # Take last 6 rows (most recent sextuplet)
      if (nrow(device_active) > 6) {
        device_active <- tail(device_active, 6)
      }
      
      # Sort by port number
      device_active <- device_active[order(device_active$port), ]
      
      cat("--- DEVICE: ", device, " ---\n", sep = "")
      for (i in 1:nrow(device_active)) {
        port_row <- device_active[i, ]
        if (port_row$sensor == "none") {
          cat("  Port ", port_row$port, ": Empty\n", sep = "")
        } else {
          cat("  Port ", port_row$port, ": ", port_row$sensor, 
              " (", port_row$type, ")", sep = "")
          if (!is.na(port_row$depth_cm)) {
            cat(" @ ", port_row$depth_cm, "cm", sep = "")
          }
          if (!is.na(port_row$status) && port_row$status == "defunct") {
            cat(" [DEFUNCT]", sep = "")
          }
          cat("\n")
        }
      }
      cat("\n")
    }
    
  } else if (view_choice %in% c("2", "3")) {
    # Specific device
    devices <- sort(unique(ports$sn))
    selected_device <- ui_select_from_menu("Select device:", devices)
    if (is.null(selected_device)) {
      return(NULL)
    }
    
    device_ports <- ports[ports$sn == selected_device, ]
    
    if (view_choice == "3") {
      # Active only - get last 6 rows with valid_to = NA
      device_active <- device_ports[is.na(device_ports$valid_to), ]
      
      # Take last 6 rows (most recent sextuplet)
      if (nrow(device_active) > 6) {
        device_active <- tail(device_active, 6)
      }
      
      device_ports <- device_active
      title <- paste0("Active Port Configuration - ", selected_device)
    } else {
      # All including history
      title <- paste0("Port Configuration History - ", selected_device)
    }
    
    cat("\n============================================\n")
    cat(title, "\n")
    cat("============================================\n\n")
    
    if (nrow(device_ports) == 0) {
      cat("No configurations found\n")
      return(NULL)
    }
    
    # Group by port number
    for (port_num in 1:6) {
      port_configs <- device_ports[device_ports$port == port_num, ]
      
      if (nrow(port_configs) == 0) next
      
      cat("--- PORT ", port_num, " ---\n", sep = "")
      
      for (i in 1:nrow(port_configs)) {
        config <- port_configs[i, ]
        
        if (config$sensor == "none") {
          cat("  Empty", sep = "")
        } else {
          cat("  ", config$sensor, " (", config$type, ")", sep = "")
          if (!is.na(config$depth_cm)) {
            cat(" @ ", config$depth_cm, "cm", sep = "")
          }
          if (!is.na(config$status) && config$status == "defunct") {
            cat(" [DEFUNCT]", sep = "")
          }
        }
        
        # Show validity period if viewing history
        if (view_choice == "2") {
          cat("\n    Valid: ", format(config$valid_from, "%Y-%m-%d %H:%M:%S"), " to ", 
              ifelse(is.na(config$valid_to), "present", format(config$valid_to, "%Y-%m-%d %H:%M:%S")),
              sep = "")
        }
        cat("\n")
      }
      cat("\n")
    }
    
  } else {
    cat("❌ Invalid selection\n")
    return(NULL)
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' View maintenance log
#' Displays maintenance log entries with filtering options
#' @return NULL (display only)
ui_view_maintenance_log <- function() {
  cat("\n============================================\n")
  cat("  View Maintenance Log\n")
  cat("============================================\n\n")
  
  maint_log <- load_maintenance_log()
  
  if (is.null(maint_log) || nrow(maint_log) == 0) {
    cat("❌ No maintenance log entries found\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. Recent entries (last 20)\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by action type\n")
  cat("  4. Filter by date range\n")
  cat("  5. All entries\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_log <- maint_log
  filter_description <- "All entries"
  
  if (view_choice == "1") {
    # Recent entries
    n_entries <- min(20, nrow(maint_log))
    filtered_log <- maint_log[(nrow(maint_log) - n_entries + 1):nrow(maint_log), ]
    filter_description <- paste0("Last ", n_entries, " entries")
    
  } else if (view_choice == "2") {
    # Filter by station
    stations <- sort(unique(maint_log$station_id))
    selected_station <- ui_select_from_menu("Select station:", stations)
    if (is.null(selected_station)) {
      return(NULL)
    }
    
    filtered_log <- maint_log[maint_log$station_id == selected_station, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by action type
    action_types <- sort(unique(maint_log$action_type))
    selected_action <- ui_select_from_menu("Select action type:", action_types)
    if (is.null(selected_action)) {
      return(NULL)
    }
    
    filtered_log <- maint_log[maint_log$action_type == selected_action, ]
    filter_description <- paste0("Action: ", selected_action)
    
  } else if (view_choice == "4") {
    # Filter by date range
    start_date <- ui_prompt_date("Enter start date", allow_today = FALSE, allow_quit = TRUE)
    if (is.null(start_date)) {
      return(NULL)
    }
    
    end_date <- ui_prompt_date("Enter end date", allow_today = TRUE, allow_quit = TRUE)
    if (is.null(end_date)) {
      return(NULL)
    }
    
    filtered_log <- maint_log[
      as.Date(maint_log$field_visit_date) >= as.Date(start_date) &
        as.Date(maint_log$field_visit_date) <= as.Date(end_date), 
    ]
    filter_description <- paste0("Date range: ", start_date, " to ", end_date)
  }
  
  ################################################################################
  #### DISPLAY LOG ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Maintenance Log - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_log), " entr", 
      ifelse(nrow(filtered_log) == 1, "y", "ies"), "\n\n", sep = "")
  
  if (nrow(filtered_log) == 0) {
    cat("No entries match this filter\n")
    return(NULL)
  }
  
  for (i in 1:nrow(filtered_log)) {
    entry <- filtered_log[i, ]
    
    cat("--- ENTRY ", i, " ---\n", sep = "")
    cat("Date:         ", format(as.Date(entry$field_visit_date), "%Y-%m-%d"), "\n", sep = "")
    cat("Station:      ", entry$station_id, " (", entry$station_type, ")\n", sep = "")
    cat("Device:       ", entry$device_serial, "\n", sep = "")
    cat("Action:       ", entry$action_type, "\n", sep = "")
    cat("Details:      ", entry$details, "\n", sep = "")
    cat("Ports updated:", entry$ports_updated, "\n", sep = "")
    cat("Logged by:    ", entry$logged_by, "\n", sep = "")
    if (!is.na(entry$timestamp)) {
      cat("Logged:       ", format(entry$timestamp, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    }
    cat("\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' View download log
#' Displays download log entries with filtering options
#' @return NULL (display only)
ui_view_download_log <- function() {
  cat("\n============================================\n")
  cat("  View Download Log\n")
  cat("============================================\n\n")
  
  download_log <- load_download_log()
  
  if (is.null(download_log) || nrow(download_log) == 0) {
    cat("❌ No download log entries found\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. Recent downloads (last 20)\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by date range\n")
  cat("  4. All downloads\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_log <- download_log
  filter_description <- "All downloads"
  
  if (view_choice == "1") {
    # Recent entries
    n_entries <- min(20, nrow(download_log))
    filtered_log <- download_log[(nrow(download_log) - n_entries + 1):nrow(download_log), ]
    filter_description <- paste0("Last ", n_entries, " downloads")
    
  } else if (view_choice == "2") {
    # Filter by station
    stations <- sort(unique(download_log$station))
    selected_station <- ui_select_from_menu("Select station:", stations)
    if (is.null(selected_station)) {
      return(NULL)
    }
    
    filtered_log <- download_log[download_log$station == selected_station, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by date range
    start_date <- ui_prompt_date("Enter start date", allow_today = FALSE, allow_quit = TRUE)
    if (is.null(start_date)) {
      return(NULL)
    }
    
    end_date <- ui_prompt_date("Enter end date", allow_today = TRUE, allow_quit = TRUE)
    if (is.null(end_date)) {
      return(NULL)
    }
    
    # Determine which date column exists in download_log
    if ("download_datetime" %in% names(download_log)) {
      filtered_log <- download_log[
        as.Date(download_log$download_datetime) >= as.Date(start_date) &
          as.Date(download_log$download_datetime) <= as.Date(end_date), 
      ]
    } else if ("timestamp" %in% names(download_log)) {
      filtered_log <- download_log[
        as.Date(download_log$timestamp) >= as.Date(start_date) &
          as.Date(download_log$timestamp) <= as.Date(end_date), 
      ]
    }
    filter_description <- paste0("Date range: ", start_date, " to ", end_date)
  }
  
  ################################################################################
  #### DISPLAY LOG ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Download Log - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_log), " download", 
      ifelse(nrow(filtered_log) == 1, "", "s"), "\n\n", sep = "")
  
  if (nrow(filtered_log) == 0) {
    cat("No downloads match this filter\n")
    return(NULL)
  }
  
  # Display based on actual column names in download_log
  for (i in 1:nrow(filtered_log)) {
    entry <- filtered_log[i, ]
    
    cat("--- DOWNLOAD ", i, " ---\n", sep = "")
    
    # Display columns with proper formatting for dates/datetimes
    for (col_name in names(entry)) {
      value <- entry[[col_name]]
      
      if (!is.na(value)) {
        # Format based on column type
        if (inherits(value, "POSIXct") || inherits(value, "POSIXlt")) {
          # Datetime column
          cat(col_name, ": ", format(value, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
        } else if (inherits(value, "Date")) {
          # Date column
          cat(col_name, ": ", format(value, "%Y-%m-%d"), "\n", sep = "")
        } else {
          # Other columns
          cat(col_name, ": ", value, "\n", sep = "")
        }
      }
    }
    cat("\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

################################################################################
#### METADATA MANAGER MASTER FUNCTION ####
################################################################################

#' Main metadata manager - orchestrates all metadata workflows
#' Interactive decision tree that routes to appropriate UI functions
metadata_manager <- function() {
  
  repeat {  # Main loop - allows multiple operations
    
    cat("\n============================================\n")
    cat("  VI-FLO Engine - Metadata Manager\n")
    cat("============================================\n\n")
    
    #### TOP LEVEL - What happened?
    cat("What happened?\n")
    cat("  1. Worked on existing station/device\n")
    cat("  2. Established new station/device or reactivated old station\n")
    cat("  3. View/check metadata\n")
    cat("  q. Quit\n")
    cat("\nEnter selection: ")
    
    top_choice <- trimws(readline())
    
    if (tolower(top_choice) == "q") {
      cat("\n✓ Exiting Metadata Manager\n")
      return(invisible(TRUE))
    }
    
    ################################################################################
    #### BRANCH 1: WORKED ON EXISTING STATION ####
    ################################################################################
    
    if (top_choice == "1") {
      
      repeat {  # Sub-loop for multiple actions at same station
        
        cat("\n--- EXISTING STATION WORK ---\n")
        cat("What type of work?\n")
        cat("  1. Routine maintenance ONLY (cleaning, battery, inspection, notes)\n")
        cat("  2. Downloaded data manually (HOBO or local Zentra)\n")
        cat("  3. Port configuration change (sensor swap, depth change)\n")
        cat("  4. Device replacement (old device out, new device in)\n")
        cat("  5. Station relocated (moved to new location)\n")
        cat("  6. Station decommissioned (shut down monitoring)\n")
        cat("  q. Back to main menu\n")
        cat("\nEnter selection: ")
        
        work_choice <- trimws(readline())
        
        if (tolower(work_choice) == "q") {
          break  # Back to main menu
        }
        
        ### Option 1: Routine maintenance
        if (work_choice == "1") {
          result <- ui_log_maintenance()
          
          if (!is.null(result)) {
            # Ask if they also did more significant work
            cat("\nDid you also do port changes, device replacement, relocation, or decommissioning? (Y/N)\n")
            cat("Response: ")
            major_work <- toupper(trimws(readline()))
            
            if (major_work == "Y" || major_work == "1") {
              # Offer to undo routine maintenance log
              cat("\n⚠️  You should select that workflow instead of routine maintenance.\n")
              cat("Cancel the routine maintenance entry you just logged? (Y/N)\n")
              cat("Response: ")
              cancel <- toupper(trimws(readline()))
              
              if (cancel == "Y" || cancel == "1") {
                # Delete the last maintenance log entry
                delete_result <- delete_last_maintenance_entry(result$device_serial)
                if (isTRUE(delete_result)) {
                  cat("✓ Routine maintenance entry cancelled\n")
                  cat("✓ Please select the appropriate workflow from the menu\n")
                } else {
                  cat("⚠️  Could not cancel entry - please manually edit maintenance_log.csv\n")
                }
              } else {
                cat("✓ Routine maintenance entry kept\n")
                cat("✓ You can now select additional workflows if needed\n")
              }
              # Loop continues - user can select another workflow
              next
            } else {
              # Just routine work - done with this workflow
              break  # Back to main menu, user can select another action if needed
            }
          } else {
            # User quit - back to work type menu
            next
          }
        }
        
        ### Option 2: Downloaded data
        else if (work_choice == "2") {
          result <- ui_log_download()
          
          if (!is.null(result)) {
            cat("\nDid you do anything else at this station? (Y/N)\n")
            cat("  If you also replaced/relocated/decommissioned, select that workflow next.\n")
            cat("Response: ")
            more_work <- toupper(trimws(readline()))
            if (more_work != "Y" && more_work != "1") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 3: Port configuration change
        else if (work_choice == "3") {
          result <- ui_update_ports()
          
          if (!is.null(result)) {
            cat("\nDid you do anything else at this station? (Y/N)\n")
            cat("  If you also replaced/relocated/decommissioned, select that workflow next.\n")
            cat("  Response: ")
            more_work <- toupper(trimws(readline()))
            if (more_work != "Y" && more_work != "1") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 4: Device replaced
        else if (work_choice == "4") {
          result <- ui_replace_device()
          
          if (!is.null(result)) {
            # ui_replace_device() handles both:
            # 1. Marking old device as "replaced"
            # 2. Adding new replacement device
            # Returns: list(old_device_serial, new_device_serial)
            
            # Check if new device is HOBO (no ports needed)
            metadata <- load_zentra_metadata()
            new_device_row <- metadata[metadata$device_serial == result$new_device_serial, ][1, ]
            
            if (tolower(new_device_row$mfger) %in% c("onset", "hobo")) {
              cat("✓ HOBO device - no port configuration needed\n")
            } else {
              # Zentra device - ask about ports
              cat("\nInitialize port configuration for new device? (Y/N): ")
              init_ports <- toupper(trimws(readline()))
              if (init_ports == "Y" || init_ports == "1") {
                ui_initialize_ports(result$new_device_serial)
              }
            }
            
            cat("\nDid you do anything else at this station? (Y/N)\n")
            cat("  Note: Device is replaced - further work would be on the NEW device.\n")
            cat("  Response: ")
            more_work <- toupper(trimws(readline()))
            if (more_work != "Y" && more_work != "1") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 5: Station relocated
        else if (work_choice == "5") {
          result <- ui_relocate_station()
          
          if (!is.null(result)) {
            # Relocation is terminal - no more work at this location
            cat("\n✓ Station relocation complete\n")
            break
          } else {
            next
          }
        }
        
        ### Option 6: Station decommissioned
        else if (work_choice == "6") {
          result <- ui_decommission_station()
          
          if (!is.null(result)) {
            # Decommissioning is terminal - station shut down
            cat("\n✓ Station decommissioned\n")
            break
          } else {
            next
          }
        }
        
        else {
          cat("⚠️  Invalid selection\n")
        }
        
      }  # End sub-loop (work on existing station)
      
    }
    
    ################################################################################
    #### BRANCH 2: ESTABLISHED NEW STATION OR REACTIVATED ####
    ################################################################################
    
    else if (top_choice == "2") {
      
      cat("\n--- NEW/REACTIVATED STATION SETUP ---\n")
      cat("Station setup type:\n")
      cat("  1. Establishing brand new station\n")
      cat("  2. New device at existing active station\n")
      cat("  3. Reactivate decommissioned station\n")
      cat("  q. Back to main menu\n")
      cat("\nEnter selection: ")
      
      new_choice <- trimws(readline())
      
      if (tolower(new_choice) == "q") {
        next  # Back to main menu
      }
      
      ### Options 1 & 2: Add new device
      if (new_choice %in% c("1", "2")) {
        is_new_station <- (new_choice == "1")
        
        # Add device (function handles new vs existing station internally)
        result <- ui_add_device(is_new_station = is_new_station)
        
        if (!is.null(result)) {
          # Check if device is HOBO (no ports needed)
          metadata <- load_zentra_metadata()
          device_row <- metadata[metadata$device_serial == result$device_serial, ][1, ]
          
          if (tolower(device_row$mfger) %in% c("onset", "hobo")) {
            cat("✓ HOBO device added - no port configuration needed\n")
          } else {
            # Zentra device - ask about ports
            cat("\nInitialize port configuration now? (Y/N): ")
            init_ports <- toupper(trimws(readline()))
            
            if (init_ports == "Y" || init_ports == "1") {
              ui_initialize_ports(result$device_serial)
            } else {
              cat("⚠️  Remember to initialize ports later!\n")
            }
          }
        }
      }
      
      ### Option 3: Reactivate decommissioned station
      else if (new_choice == "3") {
        result <- ui_reactivate_station()
        
        if (!is.null(result)) {
          # ui_reactivate_station() adds the new device
          # Check if device is HOBO (no ports needed)
          metadata <- load_zentra_metadata()
          device_row <- metadata[metadata$device_serial == result$device_serial, ][1, ]
          
          if (tolower(device_row$mfger) %in% c("onset", "hobo")) {
            cat("✓ HOBO device - no port configuration needed\n")
          } else {
            # Zentra device - ask about ports
            cat("\nInitialize port configuration now? (Y/N): ")
            init_ports <- toupper(trimws(readline()))
            
            if (init_ports == "Y" || init_ports == "1") {
              ui_initialize_ports(result$device_serial)
            } else {
              cat("⚠️  Remember to initialize ports later!\n")
            }
          }
        }
      }
      
      else {
        cat("⚠️  Invalid selection\n")
      }
      
    }
    
    ################################################################################
    #### BRANCH 3: VIEW METADATA ####
    ################################################################################
    
    else if (top_choice == "3") {
      
      cat("\n--- VIEW METADATA ---\n")
      cat("What would you like to view?\n")
      cat("  1. Device metadata\n")
      cat("  2. Port configurations\n")
      cat("  3. Maintenance log\n")
      cat("  4. Download log\n")
      cat("  q. Back to main menu\n")
      cat("\nEnter selection: ")
      
      view_choice <- trimws(readline())
      
      if (tolower(view_choice) == "q") {
        next
      }
      
      if (view_choice == "1") {
        ui_view_metadata()
      } else if (view_choice == "2") {
        ui_view_ports()
      } else if (view_choice == "3") {
        ui_view_maintenance_log()
      } else if (view_choice == "4") {
        ui_view_download_log()
      } else {
        cat("⚠️  Invalid selection\n")
      }
      
    }
    
    else {
      cat("⚠️  Invalid selection\n")
    }
    
    # After completing any branch, ask if user wants to do more
    cat("\nDo something else? This would return you to main menu. (Y/N): ")
    continue_response <- toupper(trimws(readline()))
    if (continue_response != "Y" && continue_response != "1") {
      cat("\n✓ Exiting Metadata Manager\n")
      return(invisible(TRUE))
    }
    
  }  # End main loop
  
}