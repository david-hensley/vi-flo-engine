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

#' Get active devices at a station (excludes terminal statuses)
#' @param station_id Character. Station to query
#' @return Data frame of active devices (excludes removed, replaced, decommissioned)
get_active_station_devices <- function(station_id) {
  all_devices <- get_station_devices(station_id)
  terminal_statuses <- c("removed", "replaced", "decommissioned", "relocated")
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
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_visit: ", e$message))
  })
}

#' Update status for a specific device
#' @param device_serial Character. Device to update
#' @param new_status Character. New status value
#' @return TRUE if successful, error message if failed
update_device_status <- function(device_serial, new_status) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Check device exists
    if (!device_serial %in% metadata$device_serial) {
      return(paste0("Device '", device_serial, "' not found"))
    }
    
    # Update status
    metadata$status[metadata$device_serial == device_serial] <- new_status
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
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
update_station_status <- function(station_id, new_status,
                                 close_port_serials = NULL) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    if (new_status == "decommissioned") {
      # Get devices at this station
      station_devices <- metadata[metadata$station_id == station_id, ]
      
      # Check if any active devices exist
      active_statuses <- c("online", "local", "manual", "nonresponsive", "defunct")
      active_devices <- station_devices[station_devices$status %in% active_statuses, ]
      
      if (nrow(active_devices) > 0) {
        # Normal case: mark all active devices as decommissioned
        metadata$status[metadata$station_id == station_id & 
                          metadata$status %in% active_statuses] <- new_status
        
        # A decommissioned station's sensors are no longer deployed, so their
        # port configurations stop being true and must be closed.
        #
        # close_port_serials is what the caller established actually came out
        # of the field. A ZL6 still running another station keeps its ports,
        # because they are keyed by serial and still describe reality. Given
        # no list, fall back to closing every serial with nothing active left.
        decom_serials <- if (!is.null(close_port_serials)) {
          close_port_serials
        } else {
          s_all <- unique(active_devices$device_serial)
          s_all[!vapply(s_all, function(s) {
            any(metadata$device_serial == s & metadata$status %in% active_statuses)
          }, logical(1))]
        }
        
        for (s in decom_serials) close_device_ports(s, Sys.time())
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
      
    } else if (new_status == "relocated") {
      # For relocation, update all devices
      metadata$status[metadata$station_id == station_id] <- new_status
      
    } else {
      # Default: update all
      metadata$status[metadata$station_id == station_id] <- new_status
    }
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update station status: ", e$message))
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
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
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
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    # Only format expiry_date if it exists
    if ("expiry_date" %in% names(metadata)) {
      metadata$expiry_date <- as.character(metadata$expiry_date)
    }
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_download_date: ", e$message))
  })
}

#' Update elevation with a surveyed elevation for a single device
#' @param device_serial Character. Device to update
#' @param elevation Numeric. Surveyed elevation in meters
#' @return TRUE if successful, error message if failed
survey_device_elevation <- function(device_serial, elevation) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Update device elevation
    metadata$elev[metadata$device_serial == device_serial] <- elevation
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update elevation: ", e$message))
  })
}

#' Survey stream gauge elevations for primary/secondary logger setup
#' @param station_id Character. Station being surveyed
#' @param primary_serial Character. Primary logger device serial
#' @param secondary_serial Character. Secondary logger device serial
#' @param primary_elev Numeric. Surveyed elevation of primary logger (meters)
#' @param elevation_diff Numeric. Elevation difference: secondary - primary (meters)
#' @return TRUE if successful, error message if failed
survey_dual_logger_elevations <- function(station_id, primary_serial, secondary_serial,
                                          primary_elev, elevation_diff) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Calculate secondary elevation
    secondary_elev <- primary_elev + elevation_diff
    
    # Update primary device elevation
    metadata$elev[metadata$device_serial == primary_serial] <- primary_elev
    
    # Update secondary device elevation
    metadata$elev[metadata$device_serial == secondary_serial] <- secondary_elev
    
    # Save
    setwd(wds("meta_internal"))
    metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    metadata$expiry_date <- as.character(metadata$expiry_date)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update elevations: ", e$message))
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
    
    # Check if device_serial already exists and is still active
    existing <- metadata[metadata$device_serial == device_data$device_serial, ]
    
    if (nrow(existing) > 0) {
      terminal_statuses <- c("removed", "decommissioned", "replaced", "relocated")
      
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
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
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
    metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit <- as.character(metadata$last_visit)
    
    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    
    return(list(success = TRUE, new_unique_ids = new_unique_ids))
  }, error = function(e) {
    return(list(success = FALSE, error = paste0("Failed to relocate station: ", e$message)))
  })
}

#' Remove a device from service
#' @param device_serial Character. Device to remove
#' @param removal_datetime POSIXct. When device was removed
#' @return TRUE if successful, error message if failed
remove_device <- function(device_serial, removal_datetime) {
  tryCatch({
    metadata <- load_zentra_metadata()
    device_row <- metadata[metadata$device_serial == device_serial, ][1, ]
    
    if (is.na(device_row$device_serial)) {
      return(paste0("Device '", device_serial, "' not found"))
    }
    
    # 1. Update status to removed
    result <- update_device_status(device_serial, "removed")
    if (!isTRUE(result)) return(result)
    
    # 2. Disable downloads
    result <- update_download_approval(device_row$station_id, FALSE)
    if (!isTRUE(result)) {
      # Non-fatal - continue
    }
    
    # 3. Close port configs if Zentra
    if (grepl("^z", device_serial, ignore.case = TRUE)) {
      ports <- load_zentra_ports_data()
      ports$valid_to[ports$sn == device_serial & is.na(ports$valid_to)] <- removal_datetime
      
      setwd(wds("meta_internal"))
      ports$valid_from <- format_datetime_safe(ports$valid_from)
      ports$valid_to <- format_datetime_safe(ports$valid_to)
      write.csv(ports, "zentra_ports.csv", row.names = FALSE)
    }
    
    # 4. Update last_visit
    result <- update_last_visit(device_row$station_id, as.Date(removal_datetime))
    if (!isTRUE(result)) {
      # Non-fatal - continue
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

  # Station lists run to nearly thirty entries and every station at a site
  # shares a prefix, so they read as one undifferentiated block. Grouping them
  # by site makes the list scannable.
  #
  # Detected from the shape of the options rather than switched on by each of
  # the nine callers that build these lists: a station option looks like
  # "sr1_hydro (Salt River 1)". A device option - "21652379 (Adventure)" -
  # starts with digits and has no underscore, so it is left alone.
  is_station_list <- length(options) > 3 &&
    all(grepl("^[a-z][a-z0-9]*_[a-z0-9]+ \\(.+\\)$", options))

  groups <- if (is_station_list) sub("^.*\\((.+)\\)$", "\\1", options) else NULL

  repeat {
    cat(prompt, "\n", sep = "")
    for (i in seq_along(options)) {
      if (!is.null(groups) && i > 1 && groups[i] != groups[i - 1]) cat("\n")
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
    cat(prompt, "\n", sep = "")
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
ui_prompt_status_change <- function(current_status, allow_quit = TRUE, restrict_to_device_level = FALSE) {
  cat("\nCurrent status: ", current_status, "\n", sep = "")
  cat("\nStatus options:\n")
  cat("  online           = working, reports to the cloud over a cellular\n")
  cat("                     connection\n")
  cat("  local            = working, but out of cellular service - data\n")
  cat("                     reaches the cloud only when offloaded on site\n")
  cat("                     (e.g. Bluetooth) and uploaded\n")
  cat("  manual           = working, no cloud at all - data comes off by\n")
  cat("                     shuttle or cable and is archived by hand\n")
  cat("  defunct          = broken but still deployed\n")
  cat("  nonresponsive    = should be communicating with the cloud but is\n")
  cat("                     not, for an unknown reason\n")
  
  if (!restrict_to_device_level) {
    # Show all statuses
    cat("  replaced         = swapped for new device\n")
    cat("  relocated        = station moved\n")
    cat("  decommissioned   = station shut down\n")
  } else {
    cat("\n  Note: For replacement/relocation/decommissioning, use those workflows\n")
  }
  
  cat("\n")
  
  change_response <- ui_yes_no("Change status?", allow_quit = allow_quit)
  
  if (is.null(change_response) || change_response == "Q") {
    return(NULL)
  }
  
  if (change_response == "N") {
    return(current_status)
  }
  
  # Build allowed status list
  if (restrict_to_device_level) {
    allowed_statuses <- c("online", "local", "manual", "defunct", "nonresponsive")
  } else {
    allowed_statuses <- get_metadata_unique_values("status")
  }
  
  new_status <- ui_select_or_specify("Select new status:", allowed_statuses, 
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
ui_log_maintenance <- function(prefill_station = NULL, prefill_device = NULL,
                               prefill_visit_date = NULL,
                               prefill_logged_by = NULL) {
  cat("\n============================================\n")
  cat("  Routine Maintenance Logger\n")
  cat("============================================\n\n")
  
  #### Prefilled from a download on the same visit? ####
  # Called straight after logging a download, the station, device, date and
  # initials are all already known. Re-asking for them is three menus of
  # keystrokes to arrive at the same answer, and every one is a chance to pick
  # the wrong logger.
  prefilled <- !is.null(prefill_station) && !is.null(prefill_device)

  if (prefilled) {
    field_visit_date <- prefill_visit_date
    station_id       <- prefill_station
    device_serial    <- prefill_device

    station_devices <- get_active_devices_or_notify(station_id, "maintenance logging")
    if (is.null(station_devices)) return(NULL)
    station_devices <- order_devices_by_role(station_devices)
    station_type <- station_devices$station_type[1]

    this_row <- station_devices[station_devices$device_serial == device_serial, ]

    cat("Carried over from the download you just logged:\n\n")
    cat("  Date:    ", format(as.Date(field_visit_date)), "\n", sep = "")
    cat("  Station: ", station_id, "\n", sep = "")
    cat("  Device:  ",
        if (nrow(this_row) > 0) device_label(this_row[1, ], with_role = TRUE)
        else device_serial, "\n\n", sep = "")

  } else {

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
  station_devices <- get_active_devices_or_notify(station_id, "maintenance logging")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  # Labelled with the HOBOware name where there is one - a serial alone means
  # nothing to someone deciding which of two loggers they worked on.
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  device_serial <- station_devices$device_serial[match(selected_device, device_options)]
  cat("✓ Device:", device_serial, "\n")

  }  # end of the non-prefilled path
  
  #### 4 - Action type (ROUTINE MAINTENANCE ONLY)
  # Declared, not discovered. The previous version listed four standard actions
  # and then appended every action_type ever seen in the log, minus an
  # exclusion list. That list could never keep up: the moment a workflow wrote
  # a new type - station_established, device_added - it appeared here as
  # something a human could hand-log, which only a workflow should ever write.
  #
  # Listing what a person MAY choose inverts that. A new workflow-generated
  # type cannot leak in by accident, because nothing is discovered at all.
  action_options <- c(
    "inspection only"     = "inspection",
    "cleaning"            = "cleaning",
    "maintenance"         = "maintenance",
    "battery replacement" = "battery"
  )
  
  # Relaunching is a HOBO concept - a Zentra is not launched and relaunched -
  # so it is not offered where it cannot apply, rather than labelled and left
  # for the user to filter.
  device_meta <- load_zentra_metadata()
  this_device <- device_meta[device_meta$device_serial == device_serial, ]
  
  if (nrow(this_device) > 0 && is_hobo_device(this_device$mfger[1])) {
    action_options <- c(action_options, "relaunch" = "logger_relaunch")
  }
  
  action_type <- ui_select_or_specify("What action was performed?",
                                      names(action_options))
  if (is.null(action_type)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Map the label back to the stored value; a custom entry is stored as typed
  if (action_type %in% names(action_options)) {
    action_type <- unname(action_options[action_type])
  }
  cat("✓ Action:", action_type, "\n")
  
  #### 5 - Details
  # "inspection" with nothing else said means the station was as it should be.
  # Offered on Enter, shown explicitly so it is a stated finding rather than
  # an empty field.
  default_note <- if (action_type == "inspection") "In good order" else NULL

  cat("\nEnter details (one line):\n")
  if (!is.null(default_note)) {
    cat("  Press Enter for: ", default_note, "\n", sep = "")
  }
  details <- trimws(readline())
  if (details == "" && !is.null(default_note)) details <- default_note
  cat("✓ Details: ", details, "\n", sep = "")
  
  #### 6 - Who logged this?
  if (prefilled && !is.null(prefill_logged_by)) {
    logged_by <- prefill_logged_by
    cat("\n✓ Logged by:", logged_by, "(carried over)\n")
    logged_by_input <- NA
  } else {
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
  }  # end of the non-prefilled logged_by path
  
  #### 7 - Status update (uses helper function for consistency)
  current_status <- station_devices$status[1]
  new_status <- ui_prompt_status_change(current_status, allow_quit = TRUE, restrict_to_device_level = TRUE)
  
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
    result <- update_device_status(device_serial, new_status)
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update status:", result, "\n")
    } else {
      cat("✓ Updated status to:", new_status, "\n")
    }
  }
  
  #### 11b - A relaunch is where a logger's settings change
  # Relaunching is the only moment a HOBO's name and interval can change, and
  # both live in metadata that nothing else updates. Asking here, while the
  # visit is being logged, is the difference between a record that stays true
  # and one that quietly drifts from the device on the riverbed.
  if (action_type == "logger_relaunch") {
    
    meta_now <- load_zentra_metadata()
    d_idx <- which(meta_now$device_serial == device_serial &
                   meta_now$station_id == station_id &
                   !meta_now$status %in% c("removed", "replaced", "relocated",
                                           "decommissioned"))
    
    if (length(d_idx) > 0) {
      d_idx <- d_idx[1]
      changed <- FALSE
      
      #### Was it renamed? ####
      old_name <- meta_now$device_name[d_idx]
      cat("\n--- LOGGER SETTINGS ---\n\n")
      cat("Current name in HOBOware: ", blank_or_value(old_name), "\n", sep = "")
      
      if (ui_yes_no("Did you rename the logger?", allow_quit = FALSE) == "Y") {
        cat("Enter the new name exactly as set in HOBOware: ")
        new_name <- trimws(readline())
        
        if (nzchar(new_name) && new_name != old_name) {
          meta_now$device_name[d_idx] <- new_name
          changed <- TRUE
          cat("\u2713 Name: ", blank_or_value(old_name), " -> ", new_name, "\n", sep = "")
          
          # A rename is its own event - it explains why an older shuttle
          # readout's filenames no longer match the names in metadata.
          rename_log <- create_maintenance_entry(
            field_visit_date = field_visit_date,
            station_id       = station_id,
            station_type     = station_type,
            device_serial    = device_serial,
            action_type      = "device_renamed",
            details          = paste0("Renamed from '", blank_or_value(old_name),
                                      "' to '", new_name, "' at relaunch"),
            ports_updated    = FALSE,
            logged_by        = logged_by
          )
          if (isTRUE(rename_log)) cat("\u2713 Rename logged\n")
        }
      }
      
      #### Was the interval changed? ####
      old_interval <- meta_now$interval_min[d_idx]
      cat("\nCurrent logging interval: ", blank_or_value(old_interval),
          " minutes\n", sep = "")
      
      if (ui_yes_no("Did you change the logging interval?", allow_quit = FALSE) == "Y") {
        repeat {
          cat("Enter the new interval in minutes: ")
          new_interval <- suppressWarnings(as.numeric(trimws(readline())))
          if (!is.na(new_interval) && new_interval > 0) break
          cat("\u26a0\ufe0f  Must be a positive number\n")
        }
        
        if (new_interval != old_interval) {
          meta_now$interval_min[d_idx] <- new_interval
          changed <- TRUE
          cat("\u2713 Interval: ", old_interval, " -> ", new_interval,
              " minutes\n", sep = "")
        }
      }
      
      if (changed) {
        meta_now$deploy_datetime    <- format_datetime_safe(meta_now$deploy_datetime)
        meta_now$last_update        <- format_datetime_safe(meta_now$last_update)
        meta_now$last_download_date <- format_datetime_safe(meta_now$last_download_date)
        meta_now$last_record_date   <- format_datetime_safe(meta_now$last_record_date)
        meta_now$last_visit         <- as.character(meta_now$last_visit)
        if ("expiry_date" %in% names(meta_now)) {
          meta_now$expiry_date <- as.character(meta_now$expiry_date)
        }
        write.csv(meta_now, file.path(wds("meta_internal"), "device_metadata.csv"),
                  row.names = FALSE)
        cat("\u2713 Metadata updated\n")
      }
    }
  }
  
  #### 12 - Download approval
  # Get device info to check status
  device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
  
  if (tolower(device_row$status) == "manual") {
    # Manual stations have no cloud pathway at all - approval is meaningless
    cat("\n✓ Status is 'manual' - skipping download approval (data is offloaded by hand)\n")
  } else {
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
  station_devices <- get_active_devices_or_notify(station_id, "download logging")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  # Labelled with the HOBOware name where there is one - a serial alone means
  # nothing to someone deciding which of two loggers they worked on.
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  device_serial <- station_devices$device_serial[match(selected_device, device_options)]
  cat("✓ Device:", device_serial, "\n")
  
  #### 4 - Download details
  # A default offered on Enter, shown explicitly so it cannot be given by
  # accident without having been read. Only for HOBO devices - a shuttle is
  # not how a Zentra's data comes off.
  this_dev <- station_devices[station_devices$device_serial == device_serial, ]
  default_details <- if (nrow(this_dev) > 0 && is_hobo_device(this_dev$mfger[1])) {
    "shuttle download"
  } else {
    NULL
  }

  cat("\nEnter download details (one line):\n")
  cat("  Describe the DOWNLOAD only - how the data came off, and anything\n")
  cat("  that bears on reading the record.\n")
  cat("  Maintenance you did on the same visit gets its own entry - you will\n")
  cat("  be asked about it next.\n")
  if (!is.null(default_details)) {
    cat("  Press Enter for: ", default_details, "\n", sep = "")
  } else {
    cat("  (e.g. 'Bluetooth to phone, uploaded same day')\n")
  }
  details <- trimws(readline())
  if (details == "") {
    details <- if (!is.null(default_details)) default_details else "Manual download"
  }
  cat("✓ Details: ", details, "\n", sep = "")
  
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
  
  #### 10 - Download approval / cloud upload
  # Get device info to check status
  device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
  device_status <- tolower(device_row$status)
  
  if (device_status == "manual") {
    # Manual stations have no cloud pathway at all - approval is meaningless.
    # The data is archived directly in step 11 below.
    cat("\n✓ Status is 'manual' - skipping download approval (data is offloaded by hand)\n")
    
  } else if (device_status == "local") {
    # Local stations reach ZentraCloud, but only because someone offloads on
    # site and uploads afterwards. Until that upload happens the data exists
    # nowhere but the field device, and there is no point approving a download
    # of data the cloud does not have yet.
    cat("\n--- CLOUD UPLOAD ---\n\n")
    cat("This station is out of cellular service, so its data reaches\n")
    cat("ZentraCloud only when you upload what you offloaded on site.\n\n")
    
    uploaded <- ui_yes_no("Have you uploaded this data to ZentraCloud?",
                          allow_quit = FALSE)
    
    if (uploaded == "Y") {
      result <- update_download_approval(station_id, TRUE)
      if (!isTRUE(result)) {
        cat("⚠️  Warning: Could not update download approval:", result, "\n")
      } else {
        cat("✓ Station approved for download - new data is available in the cloud\n")
      }
    } else {
      cat("\nUntil the upload happens, this data exists only on the field\n")
      cat("device. Upload it as soon as you can.\n\n")
      
      add_pending_ingest(station_id, device_serial, field_visit_date,
                         logged_by, "awaiting_cloud_upload",
                         notes = "Offloaded on site, not yet uploaded to ZentraCloud")
      
      cat("✓ Recorded as unfinished - you will be reminded every time you\n")
      cat("  open the metadata manager.\n")
    }
    
  } else {
    approve_response <- ui_yes_no("\nApprove this station for future downloads?")
    if (approve_response == "Y") {
      result <- update_download_approval(station_id, TRUE)
      if (!isTRUE(result)) {
        cat("⚠️  Warning: Could not update download approval:", result, "\n")
      } else {
        cat("✓ Station approved for download\n")
      }
    }
  }
  
  #### 11 - Archive the data (manual stations only)
  # The field record is now written and stays true regardless of what happens
  # next. Archiving is a separate matter, and if it cannot be completed the
  # ingest workflow records a pending row rather than abandoning quietly.
  if (device_status == "manual") {
    ui_ingest_local_data(
      station_id       = station_id,
      device_serial    = device_serial,
      station_type     = station_type,
      mfger            = device_row$mfger,
      field_visit_date = field_visit_date,
      logged_by        = logged_by
    )
  }
  
  cat("\n✓ All done!\n")
  
  # Return enough for a maintenance entry on the same visit to be prefilled
  return(list(
    device_serial    = device_serial,
    station_id       = station_id,
    field_visit_date = field_visit_date,
    logged_by        = logged_by
  ))
}

#' Interactive elevation survey workflow
#' Handles both single-device and dual-logger elevation surveys
#' @return TRUE if successful, NULL if quit
ui_survey_elevations <- function() {
  cat("\n============================================\n")
  cat("  Field Elevation Survey\n")
  cat("============================================\n\n")
  cat("Use this workflow to record surveyed elevations\n")
  cat("from field measurements (GNSS, laser levels, etc.)\n\n")
  
  ################################################################################
  #### SELECT SURVEY TYPE ####
  ################################################################################
  
  cat("--- SURVEY TYPE ---\n\n")
  cat("What type of elevation survey?\n")
  cat("  1. Dual-logger stream gauge (primary/secondary with elevation difference)\n")
  cat("  2. Single device (direct elevation entry)\n")
  cat("  q. Cancel\n\n")
  cat("Enter selection: ")
  
  survey_type <- trimws(readline())
  
  if (tolower(survey_type) == "q") {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  ################################################################################
  #### OPTION 1: DUAL-LOGGER STREAM GAUGE ####
  ################################################################################
  
  if (survey_type == "1") {
    cat("\n--- DUAL-LOGGER STREAM GAUGE SURVEY ---\n\n")
    
    # Get all stations and filter to those with 2+ HOBO devices
    metadata <- load_zentra_metadata()
    hobo_devices <- metadata[is_hobo_device(metadata$mfger), ]
    
    if (nrow(hobo_devices) == 0) {
      cat("❌ No HOBO devices found in metadata\n")
      return(NULL)
    }
    
    # Find stations with multiple HOBO devices
    station_counts <- table(hobo_devices$station_id)
    multi_hobo_stations <- names(station_counts[station_counts >= 2])
    
    if (length(multi_hobo_stations) == 0) {
      cat("❌ No stations found with 2+ HOBO devices\n")
      cat("   This option is for dual-logger stream gauges\n")
      return(NULL)
    }
    
    # Build station options
    station_options <- sapply(multi_hobo_stations, function(sid) {
      station_devices <- metadata[metadata$station_id == sid, ]
      station_devices <- station_devices[order(as.POSIXct(station_devices$deploy_datetime), 
                                               decreasing = TRUE), ]
      device_row <- station_devices[1, ]
      hobo_count <- sum(hobo_devices$station_id == sid)
      paste0(sid, " (", device_row$site_full, " - ", hobo_count, " HOBO devices)")
    })
    
    selected <- ui_select_from_menu("Select station:", station_options)
    if (is.null(selected)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    
    # Extract station_id
    station_id <- sub(" \\(.*\\)$", "", selected)
    cat("✓ Station:", station_id, "\n\n")
    
    #### Identify primary and secondary ####
    station_hobos <- hobo_devices[hobo_devices$station_id == station_id, ]
    
    # Look for devices with role = "primary" and role = "secondary"
    primary_device <- station_hobos[!is.na(station_hobos$device_role) & 
                                      tolower(station_hobos$device_role) == "primary", ]
    secondary_device <- station_hobos[!is.na(station_hobos$device_role) & 
                                        tolower(station_hobos$device_role) == "secondary", ]
    
    #### Roles not yet assigned - the survey itself determines them ####
    # Requiring roles before surveying is backwards: you have to guess a role
    # to obtain the measurement that tells you the role. Primary is the
    # downstream logger, downstream is lower, and the survey measures exactly
    # that. So measure first, then assign.
    if (nrow(primary_device) == 0 || nrow(secondary_device) == 0) {
      
      if (nrow(station_hobos) != 2) {
        cat("❌ Device roles are not set at this station, and it has ",
            nrow(station_hobos), " logger(s) rather than 2.\n", sep = "")
        cat("   Roles can only be assigned by survey for a paired gauge.\n")
        return(NULL)
      }
      
      cat("--- ASSIGN ROLES BY SURVEY ---\n\n")
      cat("Neither logger has a role yet. Primary means the DOWNSTREAM logger,\n")
      cat("which is the lower of the two - so the survey decides this rather\n")
      cat("than you having to know it in advance.\n\n")
      
      dev_a <- station_hobos[1, ]
      dev_b <- station_hobos[2, ]
      
      cat("Loggers at this station:\n")
      cat("  A. ", device_label(dev_a), "\n", sep = "")
      cat("  B. ", device_label(dev_b), "\n\n", sep = "")
      
      repeat {
        cat("Enter elevation of logger A - ", device_label(dev_a), " - in metres: ", sep = "")
        elev_a <- suppressWarnings(as.numeric(trimws(readline())))
        if (!is.na(elev_a)) break
        cat("⚠️  Invalid number.\n")
      }
      
      repeat {
        cat("\nEnter elevation difference (B - A) in metres:\n")
        cat("  Positive = B is HIGHER than A\n")
        cat("  Negative = B is LOWER than A\n")
        cat("Difference: ")
        diff_ba <- suppressWarnings(as.numeric(trimws(readline())))
        if (!is.na(diff_ba)) break
        cat("⚠️  Invalid number.\n")
      }
      
      elev_b <- elev_a + diff_ba
      
      if (diff_ba == 0) {
        cat("\n❌ The two loggers are at the same elevation, so neither is\n")
        cat("   downstream of the other and no slope can be derived.\n")
        cat("   Re-survey before assigning roles.\n")
        return(NULL)
      }
      
      # Lower = downstream = primary
      if (elev_a < elev_b) {
        primary_device   <- dev_a
        secondary_device <- dev_b
        primary_elev     <- elev_a
        elevation_diff   <- diff_ba
      } else {
        primary_device   <- dev_b
        secondary_device <- dev_a
        primary_elev     <- elev_b
        elevation_diff   <- -diff_ba
      }
      
      cat("\n--- ROLES DETERMINED BY SURVEY ---\n\n")
      cat("  Primary   (downstream, lower): ", device_label(primary_device),
          "  ", primary_elev, " m\n", sep = "")
      cat("  Secondary (upstream, higher):  ", device_label(secondary_device),
          "  ", primary_elev + elevation_diff, " m\n", sep = "")
      cat("  Difference: ", sprintf("%+.2f", elevation_diff), " m\n\n", sep = "")
      
      if (ui_yes_no("Assign these roles and save the elevations?",
                    allow_quit = FALSE) != "Y") {
        cat("❌ Cancelled - nothing saved\n")
        return(NULL)
      }
      
      #### Write the roles before the elevations ####
      backup_metadata()
      metadata <- load_zentra_metadata()
      
      p_idx <- which(metadata$device_serial == primary_device$device_serial &
                     metadata$station_id == station_id &
                     !metadata$status %in% c("removed", "replaced", "relocated",
                                             "decommissioned"))
      s_idx <- which(metadata$device_serial == secondary_device$device_serial &
                     metadata$station_id == station_id &
                     !metadata$status %in% c("removed", "replaced", "relocated",
                                             "decommissioned"))
      
      metadata$device_role[p_idx[1]] <- "primary"
      metadata$device_role[s_idx[1]] <- "secondary"
      
      metadata$deploy_datetime    <- format_datetime_safe(metadata$deploy_datetime)
      metadata$last_update        <- format_datetime_safe(metadata$last_update)
      metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
      metadata$last_record_date   <- format_datetime_safe(metadata$last_record_date)
      metadata$last_visit         <- as.character(metadata$last_visit)
      if ("expiry_date" %in% names(metadata)) {
        metadata$expiry_date <- as.character(metadata$expiry_date)
      }
      write.csv(metadata, file.path(wds("meta_internal"), "device_metadata.csv"),
                row.names = FALSE)
      cat("✓ Roles assigned\n")
      
      #### Then the elevations, through the existing logic function ####
      result <- survey_dual_logger_elevations(
        station_id       = station_id,
        primary_serial   = primary_device$device_serial,
        secondary_serial = secondary_device$device_serial,
        primary_elev     = primary_elev,
        elevation_diff   = elevation_diff
      )
      
      if (!isTRUE(result)) {
        cat("❌ Error:", result, "\n")
        return(NULL)
      }
      cat("✓ Elevations saved successfully\n")
      
      return(TRUE)
    }
    
    # Use first match if multiple (shouldn't happen but be safe)
    primary_device <- primary_device[1, ]
    secondary_device <- secondary_device[1, ]
    
    cat("Primary logger:   ", device_label(primary_device), "\n", sep = "")
    cat("Secondary logger: ", device_label(secondary_device), "\n\n", sep = "")
    
    #### Primary elevation ####
    cat("--- PRIMARY LOGGER ELEVATION ---\n\n")
    
    if (!is.na(primary_device$elev)) {
      # Primary already has elevation
      cat("Current elevation: ", primary_device$elev, " m\n", sep = "")
      update_primary <- ui_yes_no("Update this elevation?", allow_quit = FALSE)
      
      if (update_primary == "Y") {
        repeat {
          cat("Enter new elevation for primary logger (meters): ")
          elev_input <- trimws(readline())
          primary_elev <- suppressWarnings(as.numeric(elev_input))
          
          if (!is.na(primary_elev)) {
            cat("✓ New primary elevation: ", primary_elev, " m\n", sep = "")
            break
          } else {
            cat("⚠️  Invalid number. Please enter elevation in meters.\n")
          }
        }
      } else {
        primary_elev <- primary_device$elev
        cat("✓ Keeping existing elevation: ", primary_elev, " m\n", sep = "")
      }
    } else {
      # Primary has no elevation - must enter
      cat("No elevation recorded for primary logger.\n")
      repeat {
        cat("Enter elevation for primary logger (meters): ")
        elev_input <- trimws(readline())
        primary_elev <- suppressWarnings(as.numeric(elev_input))
        
        if (!is.na(primary_elev)) {
          cat("✓ Primary elevation: ", primary_elev, " m\n", sep = "")
          break
        } else {
          cat("⚠️  Invalid number. Please enter elevation in meters.\n")
        }
      }
    }
    
    #### Secondary elevation (via difference) ####
    cat("\n--- SECONDARY LOGGER ELEVATION ---\n\n")
    cat("Primary logger elevation: ", primary_elev, " m\n\n", sep = "")
    
    repeat {
      cat("Enter elevation difference (secondary - primary) in meters:\n")
      cat("  Positive = secondary is HIGHER (upslope - normally secondary is supposed to be upstream!)\n")
      cat("  Negative = secondary is LOWER (downslope)\n")
      cat("Difference: ")
      diff_input <- trimws(readline())
      elevation_diff <- suppressWarnings(as.numeric(diff_input))
      
      if (!is.na(elevation_diff)) {
        secondary_elev <- primary_elev + elevation_diff
        cat("\n✓ Calculated elevations:\n")
        cat("  Primary:   ", primary_elev, " m\n", sep = "")
        cat("  Secondary: ", secondary_elev, " m\n", sep = "")
        cat("  Difference: ", sprintf("%+.2f", elevation_diff), " m\n\n", sep = "")
        break
      } else {
        cat("⚠️  Invalid number. Please enter elevation difference in meters.\n\n")
      }
    }
    
    #### Does the measurement contradict the recorded roles? ####
    # Primary is the downstream logger and downstream is lower, so a negative
    # difference means the roles on record are the wrong way round. The
    # measurement is the evidence, so offer to correct the roles from it
    # rather than sending the user elsewhere to fix it by hand.
    if (elevation_diff < 0) {
      p_name <- device_label(primary_device)
      s_name <- device_label(secondary_device)

      cat("\n--- ROLES LOOK INVERTED ---\n\n")
      cat("You have measured ", s_name, "\n", sep = "")
      cat("as ", sprintf("%.2f", abs(elevation_diff)), " m LOWER than ", p_name, ".\n\n", sep = "")
      cat("Primary means the DOWNSTREAM logger, which is the lower of the two.\n")
      cat("So this measurement says the roles on record are the wrong way round.\n\n")
      cat("Switch them?\n")
      cat("  ", s_name, " would become PRIMARY   (downstream, lower)\n", sep = "")
      cat("  ", p_name, " would become SECONDARY (upstream, higher)\n\n", sep = "")

      switch_roles <- ui_yes_no("Switch the roles and save?", allow_quit = FALSE)

      if (switch_roles == "Y") {
        backup_metadata()
        metadata <- load_zentra_metadata()

        active <- !metadata$status %in% c("removed", "replaced", "relocated",
                                          "decommissioned")
        p_idx <- which(metadata$device_serial == primary_device$device_serial &
                       metadata$station_id == station_id & active)
        s_idx <- which(metadata$device_serial == secondary_device$device_serial &
                       metadata$station_id == station_id & active)

        metadata$device_role[p_idx[1]] <- "secondary"
        metadata$device_role[s_idx[1]] <- "primary"

        metadata$deploy_datetime    <- format_datetime_safe(metadata$deploy_datetime)
        metadata$last_update        <- format_datetime_safe(metadata$last_update)
        metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
        metadata$last_record_date   <- format_datetime_safe(metadata$last_record_date)
        metadata$last_visit         <- as.character(metadata$last_visit)
        if ("expiry_date" %in% names(metadata)) {
          metadata$expiry_date <- as.character(metadata$expiry_date)
        }
        write.csv(metadata, file.path(wds("meta_internal"), "device_metadata.csv"),
                  row.names = FALSE)
        cat("\n✓ Roles switched\n")

        # Swap locally so the save below writes the right elevations to the
        # right devices, and flip the sign so the difference is positive again
        tmp              <- primary_device
        primary_device   <- secondary_device
        secondary_device <- tmp
        primary_elev     <- primary_elev + elevation_diff
        elevation_diff   <- -elevation_diff
        # secondary_elev was computed before the swap - recompute it, or the
        # confirmation below displays a stale figure
        secondary_elev   <- primary_elev + elevation_diff

      } else {
        cat("\nRoles left as they are. Note the hydraulic slope will come out\n")
        cat("with the wrong sign unless the measurement is re-checked.\n\n")

        if (ui_yes_no("Save these elevations anyway?", allow_quit = FALSE) != "Y") {
          cat("❌ Cancelled - elevations not saved\n")
          return(NULL)
        }
      }
    }
    
    #### Confirmation ####
    cat("============================================\n")
    cat("Ready to save elevations:\n")
    cat("  Station: ", station_id, "\n", sep = "")
    cat("  Primary   ", device_label(primary_device), ": ", primary_elev, " m\n", sep = "")
    cat("  Secondary ", device_label(secondary_device), ": ", secondary_elev, " m\n", sep = "")
    cat("  Difference: ", sprintf("%+.2f", elevation_diff), " m\n", sep = "")
    cat("============================================\n\n")
    
    confirm <- ui_yes_no("Confirm and save?", allow_quit = FALSE)
    if (confirm != "Y") {
      cat("❌ Cancelled - elevations not saved\n")
      return(NULL)
    }
    
    #### Call logic function ####
    result <- survey_dual_logger_elevations(
      station_id = station_id,
      primary_serial = primary_device$device_serial,
      secondary_serial = secondary_device$device_serial,
      primary_elev = primary_elev,
      elevation_diff = elevation_diff
    )
    
    if (!isTRUE(result)) {
      cat("❌ Error:", result, "\n")
      return(NULL)
    }
    
    cat("✓ Elevations saved successfully\n")
    
    #### Log to maintenance ####
    survey_date <- ui_prompt_date("When was this survey performed?", allow_today = TRUE)
    if (is.null(survey_date)) {
      cat("⚠️  Warning: Elevations saved but not logged to maintenance\n")
      return(TRUE)
    }
    
    # Get who logged
    cat("\nWho is logging this survey?\n")
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
    
    # Log for primary device
    details <- paste0("Elevation survey: Primary=", primary_elev, "m, Secondary=", 
                      secondary_elev, "m (diff=", sprintf("%+.2f", elevation_diff), "m)")
    
    log_result <- create_maintenance_entry(
      field_visit_date = survey_date,
      station_id = station_id,
      station_type = primary_device$station_type,
      device_serial = primary_device$device_serial,
      action_type = "elevation_survey",
      details = details,
      ports_updated = FALSE,
      logged_by = logged_by
    )
    
    if (!isTRUE(log_result)) {
      cat("⚠️  Warning: Elevations saved but maintenance log entry failed\n")
    } else {
      cat("✓ Survey logged to maintenance\n")
    }
    
    # Update last_visit
    update_last_visit(station_id, survey_date)
    
    cat("\n✓ Dual-logger elevation survey complete!\n")
    
    return(TRUE)
  }
  
  ################################################################################
  #### OPTION 2: SINGLE DEVICE ####
  ################################################################################
  
  else if (survey_type == "2") {
    cat("\n--- SINGLE DEVICE ELEVATION SURVEY ---\n\n")
    
    metadata <- load_zentra_metadata()
    
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
    cat("✓ Station:", station_id, "\n\n")
    
    # Get devices at station
    station_devices <- get_station_devices(station_id)
    
    # Show device options
    device_options <- paste0(station_devices$device_serial, 
                             " (", station_devices$mfger, 
                             " - ", station_devices$status, ")")
    
    selected_device <- ui_select_from_menu("Select device:", device_options)
    if (is.null(selected_device)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    
    # Extract device_serial
    device_serial <- sub(" \\(.*\\)$", "", selected_device)
    device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
    
    cat("✓ Device:", device_serial, "\n")
    cat("  Manufacturer:", device_row$mfger, "\n")
    cat("  Status:", device_row$status, "\n\n")
    
    #### Get elevation ####
    cat("--- ELEVATION ---\n\n")
    
    if (!is.na(device_row$elev)) {
      cat("Current elevation: ", device_row$elev, " m\n\n", sep = "")
    } else {
      cat("No elevation currently recorded\n\n")
    }
    
    repeat {
      cat("Enter surveyed elevation (meters): ")
      elev_input <- trimws(readline())
      
      if (tolower(elev_input) == "q") {
        cat("❌ Cancelled\n")
        return(NULL)
      }
      
      new_elevation <- suppressWarnings(as.numeric(elev_input))
      
      if (!is.na(new_elevation)) {
        cat("✓ New elevation: ", new_elevation, " m\n\n", sep = "")
        break
      } else {
        cat("⚠️  Invalid number. Please enter elevation in meters.\n\n")
      }
    }
    
    #### Confirmation ####
    cat("============================================\n")
    cat("Ready to save elevation:\n")
    cat("  Station: ", station_id, "\n", sep = "")
    cat("  Device: ", device_serial, "\n", sep = "")
    cat("  New elevation: ", new_elevation, " m\n", sep = "")
    cat("============================================\n\n")
    
    confirm <- ui_yes_no("Confirm and save?", allow_quit = FALSE)
    if (confirm != "Y") {
      cat("❌ Cancelled - elevation not saved\n")
      return(NULL)
    }
    
    #### Call logic function ####
    result <- survey_device_elevation(device_serial, new_elevation)
    
    if (!isTRUE(result)) {
      cat("❌ Error:", result, "\n")
      return(NULL)
    }
    
    cat("✓ Elevation saved successfully\n")
    
    #### Log to maintenance ####
    survey_date <- ui_prompt_date("When was this survey performed?", allow_today = TRUE)
    if (is.null(survey_date)) {
      cat("⚠️  Warning: Elevation saved but not logged to maintenance\n")
      return(TRUE)
    }
    
    # Get who logged
    cat("\nWho is logging this survey?\n")
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
    
    # Log
    details <- paste0("Elevation survey: ", new_elevation, "m")
    
    log_result <- create_maintenance_entry(
      field_visit_date = survey_date,
      station_id = station_id,
      station_type = device_row$station_type,
      device_serial = device_serial,
      action_type = "elevation_survey",
      details = details,
      ports_updated = FALSE,
      logged_by = logged_by
    )
    
    if (!isTRUE(log_result)) {
      cat("⚠️  Warning: Elevation saved but maintenance log entry failed\n")
    } else {
      cat("✓ Survey logged to maintenance\n")
    }
    
    # Update last_visit
    update_last_visit(station_id, survey_date)
    
    cat("\n✓ Single device elevation survey complete!\n")
    
    return(TRUE)
  }
  
  ################################################################################
  #### INVALID SELECTION ####
  ################################################################################
  
  else {
    cat("⚠️  Invalid selection\n")
    return(NULL)
  }
}

# --- DEVICE & STATION MANAGEMENT ---
#' Interactive device addition
#' Adds a new device to metadata - either at new station or existing station
#' @param is_new_station Logical. TRUE for brand new station, FALSE for existing
#' @param preset_station_id Character. Optional. If provided, skips station selection
#' @return List with device_serial, or NULL if quit
ui_add_device <- function(is_new_station = TRUE, preset_station_id = NULL, suppress_logging = FALSE) {
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
    
    ## Area (optional)
    specify_area <- ui_yes_no("Specify an area? (This is usually a subcatchment)", allow_quit = FALSE)
    if (specify_area == "N") {
      area <- NA
      cat("✓ No area recorded\n")
    } else {
      existing_areas <- get_metadata_unique_values("area")
      area <- ui_select_or_specify("Select area:", existing_areas)
      if (is.null(area)) {
        cat("❌ Cancelled\n")
        return(NULL)
      }
      cat("✓ Area:", area, "\n")
    }
    
    ## Site full name
    # Offered as a list, not free text. A new station at an existing site is
    # the common case, and a typo here ("Salt River 1 " vs "Salt River 1")
    # silently fragments a site into two across the metadata.
    # Only sites in the watershed just chosen. A site belongs to exactly one
    # watershed, so offering all of them makes the list long and invites
    # picking one from the wrong catchment.
    all_meta <- load_zentra_metadata()
    existing_sites <- unique(all_meta$site_full[all_meta$watershed == watershed])
    existing_sites <- sort(existing_sites[!is.na(existing_sites)])

    cat("\nSite name - lower numbers are further upstream.\n")

    if (length(existing_sites) == 0) {
      # New watershed, so nothing to choose from
      cat("No sites recorded in ", watershed, " yet.\n", sep = "")
      cat("Enter site full name (e.g. 'Salt River 1'): ")
      site_full <- trimws(readline())
      if (site_full == "") {
        cat("❌ Site name cannot be empty\n")
        return(NULL)
      }
    } else {
      site_full <- ui_select_or_specify(
        paste0("Select site in ", watershed, ":"), existing_sites)
      if (is.null(site_full)) {
        cat("❌ Cancelled\n")
        return(NULL)
      }
    }
    cat("✓ Site:", site_full, "\n")
    
    ## Site abbreviation
    # site_full and site are a pair. If the site already exists, its
    # abbreviation is already established - deriving it removes any chance of
    # the two disagreeing.
    metadata_all <- all_meta
    matching <- metadata_all$site[metadata_all$site_full == site_full]
    matching <- unique(matching[!is.na(matching)])
    
    if (length(matching) == 1) {
      site <- matching
      cat("✓ Site abbrev:", site, "(existing)\n")
      
    } else if (length(matching) > 1) {
      # Already fragmented - make the user resolve it rather than guessing
      cat("\n⚠️  Site '", site_full, "' has more than one abbreviation in use: ",
          paste(matching, collapse = ", "), "\n", sep = "")
      cat("   This should not happen. Choose the correct one.\n")
      site <- ui_select_or_specify("Select site abbreviation:", matching)
      if (is.null(site)) {
        cat("❌ Cancelled\n")
        return(NULL)
      }
      cat("✓ Site abbrev:", site, "\n")
      
    } else {
      cat("\nEnter site abbreviation (e.g., 'sr1' for Salt River 1):\n")
      cat("  Two or three letters for the watershed, plus one for the area if\n")
      cat("  needed, followed by the site number.\n")
      site <- trimws(readline())
      if (site == "") {
        cat("❌ Site abbreviation cannot be empty\n")
        return(NULL)
      }
      site <- tolower(site)
      
      if (site %in% get_metadata_unique_values("site")) {
        existing_full <- unique(metadata_all$site_full[metadata_all$site == site])
        cat("\n⚠️  Abbreviation '", site, "' is already used by: ",
            paste(existing_full, collapse = ", "), "\n", sep = "")
        confirm <- ui_yes_no("Use it anyway?", allow_quit = FALSE)
        if (confirm == "N") {
          cat("❌ Cancelled\n")
          return(NULL)
        }
      }
      cat("✓ Site abbrev:", site, "\n")
    }
    
    ## Station type
    existing_types <- get_metadata_unique_values("station_type")
    station_type <- ui_select_or_specify("Select station type:", existing_types)
    if (is.null(station_type)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Station type:", station_type, "\n")
    
    ## Station ID
    # Is this actually a new station at all? A second logger at a paired
    # stream gauge is a second DEVICE at one station, not a second station -
    # and arriving here with the bare ID already taken almost always means the
    # wrong branch was chosen four prompts ago. Say so now rather than
    # suggesting a counter that quietly creates a station nobody wanted.
    base_id <- paste0(tolower(site), "_", tolower(station_type))
    
    if (isTRUE(validate_station_exists(base_id))) {
      cat("\n⚠️  Station '", base_id, "' already exists at this site.\n\n", sep = "")
      
      if (tolower(station_type) == "hydro") {
        cat("   A stream gauge often has TWO loggers - a primary downstream and\n")
        cat("   a secondary upstream - but they are two devices at ONE station,\n")
        cat("   sharing the station ID. That is not a second station.\n\n")
      }
      
      cat("   To add another logger to '", base_id, "', cancel and choose\n", sep = "")
      cat("   'New device at existing active station' from the previous menu.\n\n")
      cat("   Continue here ONLY if this is a genuinely separate station that\n")
      cat("   happens to share the site and type - it will be numbered.\n\n")
      
      if (ui_yes_no("Is this a separate new station?", allow_quit = FALSE) == "N") {
        cat("\n❌ Cancelled - use 'New device at existing active station' instead\n")
        return(NULL)
      }
    }
    
    # station_id is derivable from site + station_type, so typing it is pure
    # error surface - a typo creates a station that matches nothing. Suggest
    # it and let the user ratify.
    suggested <- suggest_station_id(site, station_type)
    
    cat("\nStation ID\n")
    cat("  Suggested: ", suggested, "\n", sep = "")
    cat("  Press Enter to accept, or type a different ID:\n")
    
    station_id <- trimws(readline())
    if (station_id == "") station_id <- suggested
    station_id <- tolower(station_id)
    
    # Check if station already exists
    existing_check <- validate_station_exists(station_id)
    if (isTRUE(existing_check)) {
      cat("⚠️  Warning: Station '", station_id, "' already exists!\n", sep = "")
      cat("If you intended to have more than one station in the same site (e.g. sr1) of the same type,\n") 
      cat("(like two VWC stations), number these (e.g., sr1_vwc1 and sr1_vwc2), with higher numbers further downslope.\n\n")
      cat("OR if you meant to add two devices to the SAME STATION (this would be rare), use 'New device at existing station' instead.\n")
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
    }
    cat("✓ Inherited from: ", site_full, " ", station_type, " (", station_id, ")\n", sep = "")
  }
  
  ################################################################################
  #### SECTION B-F: DEVICE INFORMATION WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
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
    
    # Set when this serial is already active at another station type, so the
    # device details below can be inherited instead of re-entered
    shared_row <- NULL

    # Check if serial already exists and is still active
    metadata <- load_zentra_metadata()
    existing <- metadata[metadata$device_serial == device_serial, ]
    
    if (nrow(existing) > 0) {
      # Device exists - check if it's in a terminal status
      terminal_statuses <- c("removed", "decommissioned", "replaced", "relocated")
      
      if (all(existing$status %in% terminal_statuses)) {
        # All entries are terminal - allow reuse
        cat("ℹ️  Note: Serial '", device_serial, "' previously used (status: ", 
            existing$status[1], ")\n", sep = "")
        cat("   Reusing serial for new deployment\n\n")
      } else {
        # At least one entry is still active.
        #
        # That is not automatically wrong. One ZL6 commonly serves two
        # stations - an ATMOS on one port for weather, TEROS sensors on the
        # others for soil moisture - registered as two stations sharing a
        # serial. validate_metadata() permits exactly this: one active row per
        # serial PER STATION TYPE. So reject only a genuine duplicate, which
        # is the same serial at the same station type.
        active <- existing[!existing$status %in% terminal_statuses, , drop = FALSE]
        same_type <- active[tolower(active$station_type) == tolower(station_type), ,
                            drop = FALSE]

        if (nrow(same_type) > 0) {
          cat("❌ Device serial '", device_serial, "' is already active as a ",
              station_type, " device\n", sep = "")
          cat("   Station: ", same_type$station_id[1],
              "   Status: ", same_type$status[1], "\n", sep = "")
          cat("\n   A device can serve two stations only if they are different\n")
          cat("   station types, e.g. one ZL6 running both weather and vwc.\n")
          return(NULL)
        }

        cat("\n\u2139\ufe0f  Serial '", device_serial, "' is already in use at:\n", sep = "")
        for (i in seq_len(nrow(active))) {
          cat("     ", active$station_id[i], " (", active$station_type[i], ")\n",
              sep = "")
        }
        cat("\n   One logger can serve several stations - a ZL6 with an ATMOS\n")
        cat("   and TEROS sensors is a weather station and a vwc station at\n")
        cat("   once. Its ports are configured once, on the device.\n\n")

        if (ui_yes_no("Add this device to a new station as well?",
                      allow_quit = FALSE) == "N") {
          cat("\u274c Cancelled\n")
          return(NULL)
        }

        # It is the same physical box, so everything that describes the DEVICE
        # rather than the station is already on record. Re-typing it is not
        # just tedious - it is how one logger ends up with two spellings of
        # its name and coordinates a few metres apart.
        shared_row <- active[1, ]
      }
    }
    cat("✓ Device serial:", device_serial, "\n")
    
    ## Everything below describes the DEVICE, not the station. When the serial
    ## is already on record, take it from there rather than asking again.
    if (!is.null(shared_row)) {

      mfger           <- shared_row$mfger
      model           <- shared_row$model
      device_name     <- shared_row$device_name
      lat             <- shared_row$lat
      lon             <- shared_row$lon
      elev            <- shared_row$elev
      interval        <- shared_row$interval_min
      timezone        <- shared_row$timezone
      deploy_datetime <- shared_row$deploy_datetime
      status          <- shared_row$status
      expiry_date     <- shared_row$expiry_date

      cat("\n--- DEVICE DETAILS (inherited) ---\n\n")
      cat("  Manufacturer: ", mfger, "\n", sep = "")
      cat("  Model:        ", blank_or_value(model), "\n", sep = "")
      cat("  Name:         ", blank_or_value(device_name), "\n", sep = "")
      cat("  Location:     ", lat, ", ", lon, "\n", sep = "")
      cat("  Interval:     ", interval, " minutes\n", sep = "")
      cat("  Deployed:     ", blank_or_value(deploy_datetime), "\n", sep = "")
      cat("  Status:       ", status, "\n\n", sep = "")
      cat("  Taken from ", shared_row$station_id,
          " - it is the same physical logger.\n", sep = "")
      cat("  Correct any of it later with 'Correct device details'.\n")

      ## Device role is the one thing that is per-station, not per-device
      specify_role <- ui_yes_no("\nSpecify a device role (recommended)?",
                                allow_quit = FALSE)
      if (specify_role == "N") {
        device_role <- NA
        cat("\u2713 No device role recorded\n")
      } else {
        existing_roles <- get_metadata_unique_values("device_role")
        device_role <- ui_select_or_specify("Select device role:", existing_roles)
        if (is.null(device_role)) {
          cat("\u274c Cancelled\n")
          return(NULL)
        }
        cat("\u2713 Device role:", device_role, "\n")
      }

      ## Download approval is per-station, so it is still asked
      if (tolower(status) == "manual") {
        download_approved <- FALSE
        cat("\n\u2713 Status is 'manual' - automatic download disabled\n")
      } else {
        approve <- ui_yes_no("\nApprove this device for automatic download?",
                             allow_quit = FALSE)
        download_approved <- (approve == "Y")
        cat("\u2713 Download approved:", download_approved, "\n")
      }

    } else {

    ## Manufacturer
    existing_mfgers <- get_metadata_unique_values("mfger")
    mfger <- ui_select_or_specify("Select manufacturer:", existing_mfgers)
    if (is.null(mfger)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Manufacturer:", mfger, "\n")
    
    ## Model
    # The model determines what the numbers mean. A HOBO U20-001-01 is the 9 m
    # range version and the -04 is 4 m - without this, you cannot tell whether a
    # pressure reading is in spec or off the end of the sensor.
    existing_models <- get_metadata_unique_values("model")
    if (length(existing_models) > 0) {
      model <- ui_select_or_specify("Select model:", existing_models)
      if (is.null(model)) {
        cat("❌ Cancelled\n")
        return(NULL)
      }
    } else {
      cat("\nEnter device model (e.g. 'U20-001-01', 'ZL6'):\n")
      model <- trimws(readline())
      if (model == "") {
        model <- NA
        cat("✓ No model recorded\n")
      }
    }
    if (!is.na(model)) cat("✓ Model:", model, "\n")
    
    ## Device role (optional)
    specify_role <- ui_yes_no("Specify a device role (recommended)?", allow_quit = FALSE)
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
    cat("\nEnter device name (optional, press Enter to skip) - this is how the device was named in its own software:\n")
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
    
    if (is_new_station) {
      # New station - prompt for location
      
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
      
      ## Elevation (will be derived from DEM or entered via survey workflow)
      elev <- NA
      
    } else {
      # Existing station - inherit location from station
      station_devices <- get_station_devices(station_id)
      lat <- station_devices$lat[1]
      lon <- station_devices$lon[1]
      elev <- station_devices$elev[1]
      
      cat("✓ Location inherited from station:\n")
      cat("  Latitude:", lat, "\n")
      cat("  Longitude:", lon, "\n")
      if (!is.na(elev)) {
        cat("  Elevation:", elev, "m\n")
      } else {
        cat("  Elevation: Not recorded\n")
      }
    }
    
    ################################################################################
    #### SECTION D: TIMING ####
    ################################################################################
    
    cat("\n--- TIMING ---\n\n")
    
    ## Logging interval
    repeat {
      cat("Enter logging interval in minutes (e.g., 15, 30, 60)\n")
      cat("Or press Enter for default (15 minutes):\n")
      interval_input <- trimws(readline())
      
      # Allow empty input for default
      if (interval_input == "") {
        interval <- 15
        cat("✓ Interval: 15 minutes (default)\n")
        break
      }
      
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
    cat("\nSelect timezone:\n")
    for (i in seq_along(existing_timezones)) {
      cat("  ", i, ". ", existing_timezones[i], "\n", sep = "")
    }
    cat("  ", length(existing_timezones) + 1, ". other (specify)\n", sep = "")
    cat("\nEnter selection (or press Enter for America/Puerto_Rico): ")
    tz_input <- trimws(readline())
    
    if (tz_input == "") {
      timezone <- "America/Puerto_Rico"
      cat("✓ Timezone: America/Puerto_Rico (default)\n")
    } else if (tz_input == "q") {
      cat("❌ Cancelled\n")
      return(NULL)
    } else {
      tz_num <- suppressWarnings(as.numeric(tz_input))
      if (!is.na(tz_num) && tz_num >= 1 && tz_num <= length(existing_timezones)) {
        timezone <- existing_timezones[tz_num]
        cat("✓ Timezone:", timezone, "\n")
      } else if (!is.na(tz_num) && tz_num == length(existing_timezones) + 1) {
        cat("Enter timezone: ")
        timezone <- trimws(readline())
        cat("✓ Timezone:", timezone, "\n")
      } else {
        cat("❌ Invalid selection\n")
        return(NULL)
      }
    }
    
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
    status <- ui_prompt_device_status()
    if (is.null(status)) {
      cat("❌ Cancelled\n")
      return(NULL)
    }
    cat("✓ Status:", status, "\n")
    
    ## Download approval
    if (tolower(status) == "manual") {
      # Manual stations have no cloud pathway - automatic download impossible
      download_approved <- FALSE
      cat("\n✓ Status is 'manual' - automatic download disabled\n")
    } else {
      cat("\nApprove this device for automatic download?\n")
      cat("(If there is still something needing to be updated in metadata about this device, select NO)\n")
      download_approved_response <- ui_yes_no("Approve for download?", allow_quit = FALSE)
      download_approved <- (download_approved_response == "Y")
      cat("✓ Download approved:", download_approved, "\n")
    }
    
    ## Expiry date (optional)
    if (tolower(status) == "manual") {
      # Manual stations have no cloud subscription. Note that 'local' stations
      # DO - their data reaches ZentraCloud, just not over the air.
      expiry_date <- NA
      cat("✓ No cloud subscription (manual station)\n")
    } else {
      cat("\nEnter cloud subscription expiry date if applicable (YYYY-MM-DD) or press Enter to skip:\n")
      expiry_input <- trimws(readline())
      if (expiry_input == "") {
        expiry_date <- NA
        cat("✓ No expiry date\n")
      } else {
        expiry_date <- tryCatch({
          as.Date(expiry_input)
        }, error = function(e) {
          NA
        })
        
        if (!is.na(expiry_date)) {
          cat("✓ Data expiry:", as.character(expiry_date), "\n")
        } else {
          cat("⚠️  Invalid date format, skipping\n")
          expiry_date <- NA
        }
      }
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
      # User said no - offer to restart or cancel
      restart <- ui_yes_no("Start over and re-enter device information?", allow_quit = FALSE)
      
      if (restart != "Y") {
        cat("❌ Cancelled - device not added\n")
        return(NULL)
      }
      
      cat("\n--- RESTARTING DEVICE ENTRY ---\n")
      # Loop continues, restarts from beginning of device info
    } else {
      break  # Exit repeat loop, proceed to save
    }
    
  }  # End repeat loop
  
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
    model = model,
    lat = lat,
    lon = lon,
    elev = elev,
    interval_min = interval,
    timezone = timezone,
    deploy_datetime = deploy_datetime,
    status = status,
    download_approved = download_approved,
    expiry_date = expiry_date
  )
  
  # Call logic function
  result <- add_new_device(device_data)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Device added successfully!\n")
  
  # Log to maintenance (unless suppressed by parent workflow)
  if (!suppress_logging) {
    if (is_new_station) {
      log_result <- create_maintenance_entry(
        field_visit_date = as.Date(deploy_datetime),
        station_id = station_id,
        station_type = station_type,
        device_serial = device_serial,
        action_type = "station_established",
        details = paste0("New station established: ", site_full),
        ports_updated = FALSE,
        logged_by = ui_ask_whois_logging()
      )
      
      if (isTRUE(log_result)) {
        cat("✓ Station establishment logged to maintenance\n")
      }
    } else {
      # Adding to existing station
      log_result <- create_maintenance_entry(
        field_visit_date = as.Date(deploy_datetime),
        station_id = station_id,
        station_type = station_type,
        device_serial = device_serial,
        action_type = "device_added",
        details = paste0("Device added to existing station"),
        ports_updated = FALSE,
        logged_by = ui_ask_whois_logging()
      )
      
      if (isTRUE(log_result)) {
        cat("✓ Device addition logged to maintenance\n")
      }
    }
  }
  
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
  station_devices <- get_active_station_devices(station_id)
  cat("✓ Station:", station_id, "\n\n")
  
  # Show devices at this station
  cat("Devices at this station:\n")
  for (i in 1:nrow(station_devices)) {
    cat("  ", i, ". ", station_devices$device_serial[i], 
        " (", station_devices$mfger[i], " - ", 
        station_devices$status[i], ")\n", sep = "")
  }
  
  # Select device to replace
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("\nSelect device to replace:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  old_device_serial <- station_devices$device_serial[match(selected_device, device_options)]
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
  #### ADD NEW DEVICE (using ui_add_device with preset station) ####
  ################################################################################
  
  cat("\n--- ADD REPLACEMENT DEVICE ---\n")
  cat("Station: ", station_id, " (", old_device_row$site_full, ")\n\n", sep = "")
  
  # Call ui_add_device with preset station
  add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id, suppress_logging = TRUE)
  
  if (is.null(add_result)) {
    cat("❌ New device not added - replacement cancelled\n")
    cat("   Old device status unchanged\n")
    return(NULL)
  }
  
  new_device_serial <- add_result$device_serial
  
  ################################################################################
  #### MARK OLD DEVICE AS REPLACED (only after new device successfully added) ####
  ################################################################################
  
  result <- update_device_status(old_device_serial, "replaced")
  
  # The replaced device's sensors are no longer on it. Closing them at the new
  # device's deployment is the honest boundary: that is the moment the old
  # configuration stopped describing reality.
  closed <- close_device_ports(old_device_serial, Sys.time())
  if (is.numeric(closed) && closed > 0) {
    cat("\u2713 Closed ", closed, " port configuration(s) on ",
        old_device_serial, "\n", sep = "")
  }
  if (!isTRUE(result)) {
    cat("⚠️  Warning: New device added but could not mark old device as replaced\n")
    cat("   Error:", result, "\n")
    cat("   You may need to manually update old device status\n")
    # Still return success since new device was added
  } else {
    cat("✓ Old device marked as 'replaced'\n")
  }
  
  cat("\n✓ Device replacement complete!\n")
  cat("  Old:", old_device_serial, "(replaced)\n")
  cat("  New:", new_device_serial, "\n")
  
  #### Surveyed elevation is now suspect ####
  # A replacement logger is rarely at exactly the height of the one it
  # replaced - and at a dual-logger stream gauge, the elevation difference IS
  # the hydraulic slope. A stale elevation carried forward silently produces a
  # wrong slope, and a wrong slope produces wrong flow. Missing is safer than
  # wrong: at least a gap announces itself.
  old_elev <- old_device_row$elev
  
  if (tolower(old_device_row$station_type) == "hydro" &&
      !is.na(old_elev)) {
    
    cat("\n--- SURVEYED ELEVATION ---\n\n")
    cat("The device you replaced had a surveyed elevation of ", old_elev, " m.\n",
        sep = "")
    cat("The replacement is unlikely to sit at exactly that height, and at a\n")
    cat("dual-logger gauge the elevation difference IS the hydraulic slope.\n")
    cat("Carrying the old figure forward would silently produce wrong flow.\n\n")
    
    surveyed <- ui_yes_no("Have you surveyed the new device's elevation?",
                          allow_quit = FALSE)
    
    # The new row inherited the old elevation from the station, so clearing it
    # takes an explicit write - it does not start blank.
    metadata <- load_zentra_metadata()
    new_idx <- which(metadata$device_serial == new_device_serial &
                     metadata$station_id == station_id &
                     !metadata$status %in% c("removed", "replaced", "relocated",
                                             "decommissioned"))

    if (length(new_idx) > 0 && !is.na(metadata$elev[new_idx[1]])) {
      metadata$elev[new_idx[1]] <- NA

      metadata$deploy_datetime    <- format_datetime_safe(metadata$deploy_datetime)
      metadata$last_update        <- format_datetime_safe(metadata$last_update)
      metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
      metadata$last_record_date   <- format_datetime_safe(metadata$last_record_date)
      metadata$last_visit         <- as.character(metadata$last_visit)
      if ("expiry_date" %in% names(metadata)) {
        metadata$expiry_date <- as.character(metadata$expiry_date)
      }

      write.csv(metadata,
                file.path(wds("meta_internal"), "device_metadata.csv"),
                row.names = FALSE)
      cat("\n✓ Cleared the inherited elevation on the new device\n")
    }

    if (surveyed == "Y") {
      ui_survey_elevations()
    } else {
      cat("\nThe elevation is blank until it is surveyed. A missing elevation\n")
      cat("is safer than a stale one - it announces itself, and the survey\n")
      cat("workflow will prompt for it.\n")
    }
  }
  
  # Log to maintenance
  log_result <- create_maintenance_entry(
    field_visit_date = Sys.Date(),
    station_id = station_id,
    station_type = old_device_row$station_type,
    device_serial = new_device_serial,
    action_type = "device_replacement",
    details = paste0("Replaced device ", old_device_serial, " with ", new_device_serial),
    ports_updated = FALSE,
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Replacement logged to maintenance\n")
  }
  
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
  station_devices <- get_active_devices_or_notify(station_id, "station relocation")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  
  # Get most recent active device
  station_devices_sorted <- station_devices[order(as.POSIXct(station_devices$deploy_datetime), 
                                                  decreasing = TRUE), ]
  current_device <- station_devices_sorted[1, ]
  
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
  # Filter out workflow-specific statuses (relocated is set automatically)
  excluded_statuses <- c("replaced", "relocated", "decommissioned")
  allowed_statuses <- setdiff(existing_statuses, excluded_statuses)
  new_status <- ui_select_or_specify("Select status at new location:", allowed_statuses)
  if (is.null(new_status)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  cat("✓ Status:", new_status, "\n")
  
  ## Download approval
  if (tolower(new_status) == "manual") {
    # Manual stations have no cloud pathway - automatic download impossible
    download_approved <- FALSE
    cat("\n✓ Status is 'manual' - automatic download disabled\n")
  } else {
    download_approved_response <- ui_yes_no("\nApprove station for download at new location?", 
                                            allow_quit = FALSE)
    download_approved <- (download_approved_response == "Y")
    cat("✓ Download approved:", download_approved, "\n")
  }
  
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
    deploy_datetime = deploy_datetime,
    new_status = new_status,
    download_approved = download_approved
  )
  
  if (!result$success) {
    cat("❌ Error:", result$error, "\n")
    return(NULL)
  }
  
  cat("\n✓ Station relocation complete!\n")
  cat("  Old device marked as 'relocated'\n")
  cat("  New metadata row created at new location\n")
  
  # Log to maintenance
  log_result <- create_maintenance_entry(
    field_visit_date = as.Date(deploy_datetime),
    station_id = station_id,
    station_type = current_device$station_type,
    device_serial = current_device$device_serial,
    action_type = "station_relocation",
    details = paste0("Station relocated from (", current_device$lat, ", ", current_device$lon, 
                     ") to (", new_lat, ", ", new_lon, ")"),
    ports_updated = FALSE,
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Relocation logged to maintenance\n")
  }
  
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
  
  # Check if there's anything to decommission
  active_statuses <- c("online", "local", "manual", "nonresponsive", "defunct", "removed")
  decommissionable <- station_devices[station_devices$status %in% active_statuses, ]
  
  if (nrow(decommissionable) == 0) {
    cat("⚠️  This station is already fully decommissioned.\n")
    cat("   All devices have status = 'decommissioned', 'replaced', or 'relocated'.\n")
    cat("   Nothing to do.\n")
    return(NULL)
  }
  
  # Get most recent active device for logging
  decommissionable_sorted <- decommissionable[order(as.POSIXct(decommissionable$deploy_datetime), 
                                                    decreasing = TRUE), ]
  current_device <- decommissionable_sorted[1, ]
  
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
  #### WHICH DEVICES ACTUALLY CAME OUT? ####
  ################################################################################
  # Decommissioning a station retires its devices - but one ZL6 can serve two
  # stations, an ATMOS for weather and TEROS sensors for soil moisture. Ending
  # one of those stations does not necessarily mean the box left the ground.
  #
  # Ports are keyed by SERIAL, so closing them for a device still running the
  # other station would be wrong. Where that is possible, ask rather than
  # decide.
  all_meta <- load_zentra_metadata()
  active_statuses_chk <- c("online", "local", "manual", "nonresponsive", "defunct")
  
  shared_serials <- character(0)
  for (s in unique(decommissionable$device_serial)) {
    elsewhere <- all_meta[all_meta$device_serial == s &
                          all_meta$station_id != station_id &
                          all_meta$status %in% active_statuses_chk, ]
    if (nrow(elsewhere) > 0) shared_serials <- c(shared_serials, s)
  }
  
  removed_serials <- setdiff(unique(decommissionable$device_serial), shared_serials)
  
  if (length(shared_serials) > 0) {
    cat("\n--- SHARED DEVICES ---\n\n")
    cat("Some devices at this station also serve another station:\n\n")
    
    for (s in shared_serials) {
      others <- all_meta[all_meta$device_serial == s &
                         all_meta$station_id != station_id &
                         all_meta$status %in% active_statuses_chk, ]
      cat("  ", s, " - also ", paste(unique(others$station_id), collapse = ", "),
          "\n", sep = "")
    }
    
    cat("\nIts sensors stay in the ground if the device is still running the\n")
    cat("other station, so its port configuration stays open.\n\n")
    
    for (s in shared_serials) {
      if (ui_yes_no(paste0("Did ", s, " physically come out of the field?"),
                    allow_quit = FALSE) == "Y") {
        removed_serials <- c(removed_serials, s)
      }
    }
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- update_station_status(station_id, "decommissioned",
                                  close_port_serials = removed_serials)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Station decommissioned successfully\n")
  cat("  Station:", station_id, "\n")
  cat("  Status: → 'decommissioned'\n")
  cat("\n  Note: This station can be reactivated later if needed.\n")
  
  # Log to maintenance
  log_result <- create_maintenance_entry(
    field_visit_date = Sys.Date(),
    station_id = station_id,
    station_type = current_device$station_type,
    device_serial = current_device$device_serial,
    action_type = "station_decommissioned",
    details = "Station decommissioned - monitoring stopped",
    ports_updated = FALSE,
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Decommissioning logged to maintenance\n")
  }
  
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
  
  # Filter out stations that have been reactivated (have active devices)
  truly_decommissioned <- c()
  for (sid in decommissioned_stations) {
    station_devices <- metadata[metadata$station_id == sid, ]
    active_statuses <- c("online", "local", "manual", "nonresponsive", "defunct")
    has_active <- any(station_devices$status %in% active_statuses)
    
    if (!has_active) {
      # No active devices - truly decommissioned
      truly_decommissioned <- c(truly_decommissioned, sid)
    }
  }
  
  if (length(truly_decommissioned) == 0) {
    cat("❌ No fully decommissioned stations found\n")
    cat("   (All decommissioned stations have been reactivated)\n")
    return(NULL)
  }
  
  # Build station options from truly decommissioned stations
  station_options <- sapply(truly_decommissioned, function(sid) {
    station_decomm <- decommissioned[decommissioned$station_id == sid, ]
    station_decomm <- station_decomm[order(as.POSIXct(station_decomm$deploy_datetime), 
                                           decreasing = TRUE), ]
    device_row <- station_decomm[1, ]
    paste0(sid, " (", device_row$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select decommissioned station:", station_options)
  if (is.null(selected)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  # Get decommissioned devices for this station and find the most recent
  station_decommissioned <- decommissioned[decommissioned$station_id == station_id, ]
  # Sort by deploy_datetime descending and take the most recent
  station_decommissioned <- station_decommissioned[order(as.POSIXct(station_decommissioned$deploy_datetime), 
                                                         decreasing = TRUE), ]
  old_device <- station_decommissioned[1, ]
  
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
  cat("  1. Previous location (", old_device$lat, ", ", old_device$lon, ")\n", sep = "")
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
    # Same location - just add device and update location to match old
    cat("--- ADD DEVICE FOR REACTIVATION ---\n")
    cat("Station: ", station_id, " (", old_device$site_full, ")\n\n", sep = "")
    
    add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id, suppress_logging = TRUE)
    
    if (is.null(add_result)) {
      cat("❌ Reactivation cancelled\n")
      return(NULL)
    }
    
    new_device_serial <- add_result$device_serial
    
    # Update location to match old station coordinates
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
    # New location - get coordinates first, then add device, then update location
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
    
    # Add device (ui_add_device will handle deploy datetime, status, download approval)
    cat("\n--- ADD DEVICE FOR REACTIVATION ---\n")
    cat("Station:", station_id, "(", old_device$site_full, ")\n\n")
    
    add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id, suppress_logging = TRUE)
    
    if (is.null(add_result)) {
      cat("❌ Device not added - reactivation cancelled\n")
      return(NULL)
    }
    
    new_device_serial <- add_result$device_serial
    
    # Update location to new coordinates
    result <- update_device_location(new_device_serial, 
                                     new_lat, 
                                     new_lon, 
                                     NA)  # No elevation
    
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update location:", result, "\n")
    } else {
      cat("\n✓ Location set to new coordinates\n")
    }
  }
  
  cat("\n✓ Station reactivated successfully!\n")
  cat("  Station:", station_id, "\n")
  cat("  New device:", new_device_serial, "\n")
  
  # Log to maintenance
  log_result <- create_maintenance_entry(
    field_visit_date = Sys.Date(),
    station_id = station_id,
    station_type = old_device$station_type,
    device_serial = new_device_serial,
    action_type = "station_reactivated",
    details = "Station reactivated with new device",
    ports_updated = FALSE,
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Reactivation logged to maintenance\n")
  }
  
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

  #### Already configured? ####
  # Ports belong to the device, not the station. A ZL6 shared between a
  # weather station and a vwc station has ONE set of six ports, configured
  # once - reconfiguring from the second station would create a duplicate
  # active set.
  existing_ports <- get_active_ports(device_serial)

  if (nrow(existing_ports) > 0) {
    cat("\n============================================\n")
    cat("  Ports Already Configured\n")
    cat("============================================\n\n")
    cat("Device ", device_serial, " already has an active port configuration:\n\n",
        sep = "")

    for (i in order(existing_ports$port)) {
      depth <- if (!is.na(existing_ports$depth_cm[i])) {
        paste0(" @ ", existing_ports$depth_cm[i], "cm")
      } else ""
      cat("  Port ", existing_ports$port[i], ": ", existing_ports$sensor[i],
          " (", existing_ports$type[i], ")", depth, "\n", sep = "")
    }

    cat("\nPorts belong to the DEVICE, not the station. Where one ZL6 serves\n")
    cat("two stations - an ATMOS for weather and TEROS sensors for soil\n")
    cat("moisture - both stations share this one configuration.\n\n")
    cat("To change a sensor, use 'Port configuration change' under existing\n")
    cat("station work, which closes the old entry and opens a new one.\n\n")

    return(invisible(NULL))
  }

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
  
  ################################################################################
  #### PORT CONFIGURATION WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
    # Get existing sensor types for menu
    existing_sensors <- get_unique_sensor_types()
    
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
      is_working <- ui_yes_no("Is this sensor in good working order? (Considered 'defunct' - broken but still plugged in - if you say no)", 
                              allow_quit = FALSE)
      
      if (is_working == "N") {
        port_config$status[port_num] <- "defunct"
        cat("⚠️  Sensor marked as defunct\n")
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
    
    if (confirm == "Y") {
      break  # Exit repeat loop, proceed to save
    }
    
    # User said no - offer to restart or cancel
    restart <- ui_yes_no("Start over and reconfigure all ports?", allow_quit = FALSE)
    
    if (restart != "Y") {
      cat("❌ Cancelled - configuration not saved\n")
      return(NULL)
    }
    
    cat("\n--- RESTARTING PORT CONFIGURATION ---\n")
    # Loop continues, restarts from beginning
    
  }  # End repeat loop
  
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
  
  # Try to get current config - might not exist if never initialized
  current_config <- tryCatch({
    get_current_port_config(device_serial)
  }, error = function(e) {
    NULL
  })
  
  # Check if device has never been configured
  if (is.null(current_config)) {
    cat("⚠️  This device has no port configuration yet.\n")
    cat("   Use 'Initialize port configuration' instead.\n\n")
    
    init_now <- ui_yes_no("Initialize port configuration now?", allow_quit = FALSE)
    
    if (init_now == "Y") {
      # Call initialize function
      result <- ui_initialize_ports(device_serial)
      return(result)
    } else {
      cat("❌ Cancelled - ports not configured\n")
      return(NULL)
    }
  }
  
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
  #### PORT-BY-PORT UPDATE WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
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
      is_working <- ui_yes_no("Is this sensor in good working order? (If you say no, considered 'defunct' - broken but still plugged in)", 
                              allow_quit = FALSE)
      
      new_status <- NA
      if (is_working == "N") {
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
    
    if (confirm == "Y") {
      break  # Exit repeat loop, proceed to save
    }
    
    # User said no - offer to restart or cancel
    restart <- ui_yes_no("Start over and reconfigure ports again?", allow_quit = FALSE)
    
    if (restart != "Y") {
      cat("❌ Cancelled - configuration not updated\n")
      return(NULL)
    }
    
    cat("\n--- RESTARTING PORT UPDATE ---\n")
    cat("--- CURRENT PORT CONFIGURATION ---\n")
    for (i in 1:6) {
      if (current_config$sensor[i] == "none") {
        cat("  Port ", i, ": Empty\n", sep = "")
      } else {
        cat("  Port ", i, ": ", current_config$sensor[i], 
            " (", current_config$type[i], ")", sep = "")
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
    # Loop continues, restarts port configuration
    
  }  # End repeat loop
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- update_ports(device_serial, new_config, change_datetime)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("\n✓ Port configuration updated successfully\n")
  
  # Log to maintenance
  log_result <- create_maintenance_entry(
    field_visit_date = as.Date(change_datetime),
    station_id = device_row$station_id,
    station_type = device_row$station_type,
    device_serial = device_serial,
    action_type = "port_config_change",
    details = "Port configuration updated",
    ports_updated = TRUE,
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Port configuration change logged to maintenance\n")
  }
  
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

#' Interactive device removal
#' Removes a device from service - marks as removed, closes ports, disables downloads
#' @return TRUE if successful, NULL if quit
ui_remove_device <- function() {
  cat("\n============================================\n")
  cat("  Remove Device from Service\n")
  cat("============================================\n\n")
  cat("Use this workflow when:\n")
  cat("  - Taking a device out of the field\n")
  cat("  - Device being stored, scrapped, or redeployed elsewhere\n")
  cat("  - NOT for replacement (use replacement workflow instead)\n\n")
  
  ################################################################################
  #### SELECT STATION & DEVICE ####
  ################################################################################
  
  cat("--- SELECT DEVICE TO REMOVE ---\n\n")
  
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
  station_devices <- get_active_devices_or_notify(station_id, "device removal")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  cat("✓ Station:", station_id, "\n\n")
  
  # Show devices at this station
  cat("Devices at this station:\n")
  for (i in 1:nrow(station_devices)) {
    cat("  ", i, ". ", station_devices$device_serial[i], 
        " (", station_devices$mfger[i], " - ", 
        station_devices$status[i], ")\n", sep = "")
  }
  
  # Select device to remove
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("\nSelect device to remove:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  device_serial <- station_devices$device_serial[match(selected_device, device_options)]
  device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
  
  ################################################################################
  #### CHECK IF FINAL DEVICE - STRONG DECOMMISSION RECOMMENDATION ####
  ################################################################################
  
  # Check if this is the only active device at the station
  active_statuses <- c("online", "local", "manual", "nonresponsive")
  active_devices <- station_devices[station_devices$status %in% active_statuses, ]
  
  if (nrow(active_devices) == 1 && active_devices$device_serial[1] == device_serial) {
    cat("\n╔════════════════════════════════════════════════════════════╗\n")
    cat("║  ⚠️  RECOMMENDATION: USE DECOMMISSION WORKFLOW INSTEAD  ⚠️   ║\n")
    cat("╚════════════════════════════════════════════════════════════╝\n\n")
    cat("This is the ONLY active device at station '", station_id, "'\n", sep = "")
    cat("Removing it will leave the station with no active monitoring.\n\n")
    cat("RECOMMENDED ACTION:\n")
    cat("  1. Cancel this removal workflow\n")
    cat("  2. Use 'Station decommissioned' workflow instead\n")
    cat("  3. That workflow properly marks the entire station as shut down\n\n")
    cat("Why? 'Decommissioned' means the station has no active devices,\n")
    cat("which is exactly what will happen if you remove this device.\n\n")
    
    proceed <- ui_yes_no("Do you still want to proceed with device removal?", allow_quit = FALSE)
    if (proceed != "Y") {
      cat("\n✓ Good choice! Use 'Station decommissioned' workflow from main menu.\n")
      return(NULL)
    }
    cat("\n⚠️  Proceeding with device removal despite recommendation...\n\n")
  }
  
  cat("✓ Device:", device_serial, "\n")
  cat("  Manufacturer:", device_row$mfger, "\n")
  cat("  Current status:", device_row$status, "\n\n")
  
  ################################################################################
  #### REMOVAL DATETIME & DETAILS ####
  ################################################################################
  
  cat("--- REMOVAL INFORMATION ---\n\n")
  
  # When removed (datetime, not just date)
  cat("When was device removed?\n")
  cat("(This should be date AND time, as exact as possible)\n\n")
  
  removal_datetime <- ui_prompt_datetime(
    "Enter removal datetime",
    allow_now = TRUE,
    timezone = device_row$timezone
  )
  
  if (is.null(removal_datetime)) {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  cat("✓ Removal datetime:", format(removal_datetime), "\n\n")
  
  # Extract date for maintenance log
  removal_date <- as.Date(removal_datetime)
  
  # Details
  cat("Enter removal details (e.g., 'Device removed, stored in lab'):\n")
  details <- trimws(readline())
  if (details == "") {
    details <- "Device removed from service"
  }
  cat("✓ Details:", details, "\n\n")
  
  # Who is logging
  cat("Who is logging this removal?\n")
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
  
  ################################################################################
  #### CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Ready to remove device:\n")
  cat("  Device:", device_serial, "\n")
  cat("  Station:", station_id, "\n")
  cat("  Removal datetime:", format(removal_datetime), "\n")
  cat("  Details:", details, "\n\n")
  cat("This will:\n")
  cat("  - Mark device status as 'removed'\n")
  cat("  - Disable automatic downloads\n")
  cat("  - Close all active port configurations\n")
  cat("  - Log removal to maintenance\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm device removal?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Cancelled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- remove_device(device_serial, removal_datetime)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Device status set to 'removed'\n")
  cat("✓ Automatic downloads disabled\n")
  cat("✓ Port configurations closed\n")
  cat("✓ Last visit updated\n")
  
  ################################################################################
  #### LOG TO MAINTENANCE ####
  ################################################################################
  
  log_result <- create_maintenance_entry(
    field_visit_date = removal_date,
    station_id = device_row$station_id,
    station_type = device_row$station_type,
    device_serial = device_serial,
    action_type = "device_removal",
    details = details,
    ports_updated = TRUE,
    logged_by = logged_by
  )
  
  if (!isTRUE(log_result)) {
    cat("⚠️  Warning: Could not log to maintenance\n")
  } else {
    cat("✓ Removal logged to maintenance\n")
  }
  
  cat("\n✓ Device removal complete!\n")
  cat("  Device ", device_serial, " has been removed from service\n", sep = "")
  
  return(TRUE)
}

#' Delete a metadata row by unique_id (ADMIN FUNCTION)
#' Shows full record, confirms deletion, removes from metadata and ports
#' Logs deletion to maintenance log
#' @return TRUE if successful, NULL if cancelled
ui_delete_metadata_row <- function() {
  cat("\n============================================\n")
  cat("  DELETE METADATA ROW (ADMIN)\n")
  cat("============================================\n\n")
  cat("⚠️  WARNING: This permanently deletes a row from device metadata\n")
  cat("   Use only for entries added in error\n\n")
  
  ################################################################################
  #### GET UNIQUE_ID ####
  ################################################################################
  
  cat("Enter unique_id of row to delete (e.g., z-0045, h-0012):\n")
  cat("Or press 'q' to cancel: ")
  unique_id_input <- trimws(readline())
  
  if (tolower(unique_id_input) == "q" || unique_id_input == "") {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  unique_id <- unique_id_input
  
  ################################################################################
  #### LOAD AND VERIFY ####
  ################################################################################
  
  metadata <- load_zentra_metadata()
  
  # Check if unique_id exists
  if (!unique_id %in% metadata$unique_id) {
    cat("❌ Error: unique_id '", unique_id, "' not found in metadata\n", sep = "")
    return(NULL)
  }
  
  # Get the row
  row_to_delete <- metadata[metadata$unique_id == unique_id, ]
  
  ################################################################################
  #### SHOW FULL RECORD ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("DEVICE METADATA - CONFIRM DELETION\n")
  cat("============================================\n")
  cat("unique_id:           ", row_to_delete$unique_id, "\n", sep = "")
  cat("station_id:          ", row_to_delete$station_id, "\n", sep = "")
  cat("device_serial:       ", row_to_delete$device_serial, "\n", sep = "")
  cat("watershed:           ", row_to_delete$watershed, "\n", sep = "")
  cat("area:                ", row_to_delete$area, "\n", sep = "")
  cat("site_full:           ", row_to_delete$site_full, "\n", sep = "")
  cat("site:                ", row_to_delete$site, "\n", sep = "")
  cat("station_type:        ", row_to_delete$station_type, "\n", sep = "")
  cat("device_role:         ", row_to_delete$device_role, "\n", sep = "")
  cat("device_name:         ", row_to_delete$device_name, "\n", sep = "")
  cat("mfger:               ", row_to_delete$mfger, "\n", sep = "")
  cat("lat:                 ", row_to_delete$lat, "\n", sep = "")
  cat("lon:                 ", row_to_delete$lon, "\n", sep = "")
  cat("elev:                ", row_to_delete$elev, "\n", sep = "")
  cat("interval_min:        ", row_to_delete$interval_min, "\n", sep = "")
  cat("timezone:            ", row_to_delete$timezone, "\n", sep = "")
  cat("deploy_datetime:     ", format(row_to_delete$deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("status:              ", row_to_delete$status, "\n", sep = "")
  cat("download_approved:   ", row_to_delete$download_approved, "\n", sep = "")
  cat("============================================\n\n")
  
  ################################################################################
  #### CONFIRM DELETION ####
  ################################################################################
  
  confirm <- ui_yes_no("Permanently delete this row from metadata?", allow_quit = FALSE)
  
  if (confirm != "Y") {
    cat("❌ Cancelled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### DELETE FROM METADATA ####
  ################################################################################
  
  # Remove row
  metadata <- metadata[metadata$unique_id != unique_id, ]
  
  # Save
  setwd(wds("meta_internal"))
  metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
  metadata$last_update <- format_datetime_safe(metadata$last_update)
  metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
  metadata$last_record_date <- format_datetime_safe(metadata$last_record_date)
  metadata$last_visit <- as.character(metadata$last_visit)
  metadata$expiry_date <- as.character(metadata$expiry_date)
  
  write.csv(metadata, "device_metadata.csv", row.names = FALSE)
  
  cat("✓ Row deleted from device_metadata.csv\n")
  
  ################################################################################
  #### DELETE FROM ZENTRA PORTS (if applicable) ####
  ################################################################################
  
  # Check if device has port configs
  ports <- load_zentra_ports_data()
  device_ports <- ports[ports$sn == row_to_delete$device_serial, ]
  
  if (nrow(device_ports) > 0) {
    cat("\n⚠️  Found ", nrow(device_ports), " port configuration rows for this device\n", sep = "")
    cat("Delete these port rows too? (Y/N): ")
    delete_ports <- toupper(trimws(readline()))
    
    if (delete_ports == "Y" || delete_ports == "1") {
      # Remove port rows
      ports <- ports[ports$sn != row_to_delete$device_serial, ]
      
      # Save
      ports$valid_from <- format_datetime_safe(ports$valid_from)
      ports$valid_to <- format_datetime_safe(ports$valid_to)
      
      write.csv(ports, "zentra_ports.csv", row.names = FALSE)
      
      cat("✓ ", nrow(device_ports), " port rows deleted from zentra_ports.csv\n", sep = "")
    } else {
      cat("⚠️  Port rows NOT deleted - you may want to clean these up manually\n")
    }
  }
  
  ################################################################################
  #### LOG DELETION ####
  ################################################################################
  
  log_details <- paste0("METADATA DELETION - unique_id: ", unique_id, 
                        ", device_serial: ", row_to_delete$device_serial,
                        ", station: ", row_to_delete$station_id,
                        " (", row_to_delete$site_full, ")")
  
  log_result <- create_maintenance_entry(
    field_visit_date = Sys.Date(),
    station_id = row_to_delete$station_id,
    station_type = row_to_delete$station_type,
    device_serial = row_to_delete$device_serial,
    action_type = "metadata_deletion",
    details = log_details,
    ports_updated = FALSE,
    logged_by = "ADMIN"
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Deletion logged to maintenance_log.csv\n")
  } else {
    cat("⚠️  Warning: Could not log deletion to maintenance log\n")
  }
  
  cat("\n✓ Metadata row deletion complete\n")
  cat("  Deleted: ", unique_id, " (", row_to_delete$device_serial, ")\n", sep = "")
  
  return(TRUE)
}

################################################################################
#### METADATA MANAGER MASTER FUNCTION ####
################################################################################

#' Main metadata manager - orchestrates all metadata workflows
#' Interactive decision tree that routes to appropriate UI functions
metadata_manager <- function() {
  
  # Row count at the start, so the exit summary can report what this session
  # added rather than the whole log
  entries_at_start <- tryCatch(nrow(load_maintenance_log()),
                               error = function(e) NA_integer_)
  
  repeat {  # Main loop - allows multiple operations
    
    cat("\n============================================\n")
    cat("  VI-FLO Engine - Metadata Manager\n")
    cat("============================================\n")
    
    #### Unfinished business first
    # Data left on a logger, a shuttle, or a phone is data at risk. Raising it
    # here every single time is the point: the system remembers, not the person.
    n_pending <- 0
    if (exists("check_pending")) {
      pending_now <- check_pending()
      n_pending <- nrow(pending_now)
    }
    
    #### TOP LEVEL - What happened?
    cat("What happened?\n")
    cat("  1. Worked on existing station/device\n")
    cat("  2. Established new station/device or reactivated old station\n")
    cat("  3. View/check metadata\n")
    if (n_pending > 0) {
      cat("  r. Resume an unfinished data task\n")
    }
    cat("  q. Quit\n")
    cat("\nEnter selection: ")
    
    top_choice <- trimws(readline())
    
    if (tolower(top_choice) == "q") {
      return(ui_exit_metadata_manager(entries_at_start))
    }
    
    #### Resume an unfinished data task ####
    if (tolower(top_choice) == "r" && n_pending > 0) {
      ui_resume_pending_ingest()
      next
    }
    
    # Hidden admin function - delete metadata row
    if (tolower(top_choice) == "deletion") {
      ui_delete_metadata_row()
      next  # Return to main menu after deletion
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
        cat("  5. Device removal (taking device out of service)\n")
        cat("  6. Station relocated (moved to new location)\n")
        cat("  7. Station decommissioned (entire station shut down)\n")
        cat("  8. Field surveyed elevation of station or loggers\n")
        cat("  9. Correct device details (model, name, role, interval, coords)\n")
        cat("  q. Back to main menu\n")
        
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
            # Nobody visits a station, downloads it, and does nothing else -
            # at minimum they looked at it. So offer the maintenance entry
            # directly, carrying over the station, device and date rather than
            # making the user re-select all three from the top of the menu.
            cat("\nLog routine maintenance for this visit?\n")
            cat("  Inspection, cleaning, battery, relaunch - same station,\n")
            cat("  device and date, no need to re-select.\n")
            add_maint <- ui_yes_no("Log it now?", allow_quit = FALSE)
            
            if (add_maint == "Y") {
              ui_log_maintenance(
                prefill_station    = result$station_id,
                prefill_device     = result$device_serial,
                prefill_visit_date = result$field_visit_date,
                prefill_logged_by  = result$logged_by
              )
            }
            
            cat("\nAnything else at this station on this visit?\n")
            cat("  Sensor swap, device replaced, station moved -> its own workflow\n")
            cat("Response (Y/N): ")
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
            
            if (is_hobo_device(new_device_row$mfger)) {
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
        
        ### Option 5: Device removed
        else if (work_choice == "5") {
          result <- ui_remove_device()
          
          if (!is.null(result)) {
            cat("\nDid you do anything else at this station? (Y/N)\n")
            cat("  Response: ")
            more_work <- toupper(trimws(readline()))
            if (more_work != "Y" && more_work != "1") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 6: Station relocated
        else if (work_choice == "6") {
          result <- ui_relocate_station()
          
          if (!is.null(result)) {
            # Relocation is terminal - no more work at this location
            cat("\n✓ Station relocation complete\n")
            break
          } else {
            next
          }
        }
        
        ### Option 7: Station decommissioned
        else if (work_choice == "7") {
          result <- ui_decommission_station()
          
          if (!is.null(result)) {
            # Decommissioning is terminal - station shut down
            cat("\n✓ Station decommissioned\n")
            break
          } else {
            next
          }
        }
        
        ### Option 8: Surveyed elevation of station or logger
        else if (work_choice == "8") {
          result <- ui_survey_elevations()
          
          if (!is.null(result)) {
            cat("\n✓ Elevation survey complete\n")
          }
          # Continue to next iteration (allow more work)
          next
        }
        
        ### Option 9: Correct device details
        else if (work_choice == "9") {
          ui_correct_device_details()
          next
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
          
          if (is_hobo_device(device_row$mfger)) {
            cat("✓ HOBO device added - no port configuration needed\n")
            
            #### Surveyed elevation ####
            # Only once a station HAS a pair. A single water level logger is a
            # legitimate permanent arrangement - flow can come from a rating
            # curve built on flow-meter measurements instead of a hydraulic
            # slope - so a lone logger is not a half-finished gauge and should
            # not be nagged as one.
            #
            # A pair is different: the elevation difference between the two IS
            # the slope, and until it is surveyed the station produces water
            # levels that cannot become flow. The survey can only run once both
            # rows exist, which is exactly now.
            if (tolower(device_row$station_type) == "hydro") {
              
              station_devices <- get_active_station_devices(device_row$station_id)
              roles <- tolower(station_devices$device_role)
              has_pair <- sum(!is.na(roles) & roles %in% c("primary", "secondary")) >= 2
              unsurveyed <- any(is.na(station_devices$elev))
              
              if (has_pair && unsurveyed) {
                cat("\n--- SURVEYED ELEVATION ---\n\n")
                cat("This station now has a primary and a secondary logger. The\n")
                cat("elevation difference between them is the hydraulic slope,\n")
                cat("and until it is surveyed the water levels cannot become flow.\n\n")
                
                do_survey <- ui_yes_no("Do you have the elevation survey data to enter now?",
                                       allow_quit = FALSE)
                
                if (do_survey == "Y") {
                  ui_survey_elevations()
                } else {
                  cat("\nNo problem - record it later with 'Field surveyed\n")
                  cat("elevation' (option 8) under existing station work.\n")
                }
              }
            }
            
          } else {
            # Zentra device - ask about ports, unless this serial already has
            # them. A ZL6 shared between a weather and a vwc station is
            # configured once, by whichever station was set up first.
            if (nrow(get_active_ports(result$device_serial)) > 0) {
              cat("\n✓ Ports already configured on ", result$device_serial,
                  " - shared with its other station\n", sep = "")
            } else {
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
      }
      
      ### Option 3: Reactivate decommissioned station
      else if (new_choice == "3") {
        result <- ui_reactivate_station()
        
        if (!is.null(result)) {
          # ui_reactivate_station() adds the new device
          # Check if device is HOBO (no ports needed)
          metadata <- load_zentra_metadata()
          device_row <- metadata[metadata$device_serial == result$device_serial, ][1, ]
          
          if (is_hobo_device(device_row$mfger)) {
            cat("✓ HOBO device - no port configuration needed\n")
          } else {
            # Zentra device - ask about ports, unless this serial already has
            # them. A ZL6 shared between a weather and a vwc station is
            # configured once, by whichever station was set up first.
            if (nrow(get_active_ports(result$device_serial)) > 0) {
              cat("\n✓ Ports already configured on ", result$device_serial,
                  " - shared with its other station\n", sep = "")
            } else {
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
      return(ui_exit_metadata_manager(entries_at_start))
    }
    
  }  # End main loop
  
}


#' Corrects device details recorded wrongly or left blank
#'
#' For DESCRIPTIVE fields only - things that are properties of the device
#' rather than records of something happening. Correcting a typo in a model
#' number is a correction; a device being replaced or a station moving are
#' EVENTS and belong in their own workflows, where they leave a maintenance
#' log entry behind.
#'
#' Deliberately not a general row editor. A general editor would become the
#' easy path for changes that ought to be logged, and the log is the only
#' record of why anything changed.
#'
#' @return TRUE if a change was made, NULL if cancelled
ui_correct_device_details <- function() {

  cat("\n============================================\n")
  cat("  Correct Device Details\n")
  cat("============================================\n\n")
  cat("For fixing details recorded wrongly or left blank:\n")
  cat("  - model, device name, device role, logging interval\n")
  cat("  - deploy datetime, latitude, longitude\n\n")
  cat("NOT for things that happened in the field. A device swap or a station\n")
  cat("move belong in their own workflows, so that they leave a maintenance\n")
  cat("log entry behind.\n\n")
  cat("Devices already out of service are listed too - their rows are the\n")
  cat("historical record, and a wrong value on one still needs correcting.\n\n")

  #### Select station and device ####
  station_list <- get_station_list()
  if (length(station_list) == 0) {
    cat("No stations found in metadata.\n")
    return(invisible(NULL))
  }

  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$site_full, ")")
  })

  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("Cancelled\n")
    return(invisible(NULL))
  }
  # ui_select_from_menu returns the chosen STRING, not an index, so strip the
  # parenthesised site name back off it.
  station_id <- sub(" \\(.*\\)$", "", selected)

  # Terminal devices are included, not filtered out. Their rows are the
  # historical record, and a value recorded wrongly on one - a mis-entered
  # coordinate, or the wrong terminal status - has no other route to being
  # fixed. Listing only active devices made that unreachable.
  all_meta <- load_zentra_metadata()
  devices <- all_meta[all_meta$station_id == station_id, , drop = FALSE]
  devices <- order_devices_by_role(devices)

  if (nrow(devices) == 0) {
    cat("No devices at this station.\n")
    return(invisible(NULL))
  }

  terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")

  device_options <- vapply(seq_len(nrow(devices)), function(i) {
    label <- device_label(devices[i, ], with_role = TRUE)
    if (tolower(devices$status[i]) %in% terminal_statuses) {
      paste0(label, "  [", devices$status[i], "]")
    } else {
      label
    }
  }, character(1))

  if (nrow(devices) == 1) {
    row_i <- 1
    cat("\nDevice: ", device_options[1], "\n", sep = "")
  } else {
    dsel <- ui_select_from_menu("Select device:", device_options)
    if (is.null(dsel)) {
      cat("Cancelled\n")
      return(invisible(NULL))
    }
    row_i <- match(dsel, device_options)
  }

  device_serial <- devices$device_serial[row_i]
  device_status <- devices$status[row_i]

  #### Show current values ####
  metadata <- load_zentra_metadata()
  idx <- which(metadata$device_serial == device_serial &
               metadata$station_id == station_id &
               metadata$status == device_status)

  if (length(idx) == 0) {
    cat("Could not find that device row.\n")
    return(invisible(NULL))
  }
  idx <- idx[1]

  # Descriptive fields only. deploy_datetime, lat and lon are here because a
  # value recorded wrongly at creation has no other route to being fixed -
  # but note that lat/lon changing because the DEVICE MOVED is an event, and
  # belongs in the relocation or replacement workflow so it leaves a log entry.
  editable <- c("model", "device_name", "device_role", "interval_min",
                "deploy_datetime", "lat", "lon")
  editable <- editable[editable %in% names(metadata)]

  # A device already in a terminal state can have that state CORRECTED here -
  # but only where a workflow recorded the wrong one. Terminal statuses are
  # otherwise set by the workflows that log the event, and this must not
  # become the easy way to bypass them.
  is_terminal <- tolower(metadata$status[idx]) %in% terminal_statuses
  if (is_terminal) editable <- c(editable, "status")

  repeat {
    cat("\n--- CURRENT VALUES ---\n\n")
    for (i in seq_along(editable)) {
      value <- metadata[[editable[i]]][idx]
      display <- blank_or_value(value)
      cat("  ", i, ". ", format(editable[i], width = 14), " ", display, "\n", sep = "")
    }
    cat("  q. Done\n\n")
    cat("Which field to correct? ")

    choice <- trimws(readline())
    if (tolower(choice) == "q") break

    if (!grepl("^[0-9]+$", choice) ||
        as.numeric(choice) < 1 || as.numeric(choice) > length(editable)) {
      cat("Invalid selection\n")
      next
    }

    field <- editable[as.numeric(choice)]
    current <- metadata[[field]][idx]

    cat("\nCurrent ", field, ": ", blank_or_value(current), "\n", sep = "")

    #### Field-specific prompting ####
    if (field %in% c("model", "device_role")) {
      existing <- get_metadata_unique_values(field)
      if (length(existing) > 0) {
        new_value <- ui_select_or_specify(paste0("Select ", field, ":"), existing)
        if (is.null(new_value)) next
      } else {
        cat("Enter new ", field, " (or press Enter to leave blank): ", sep = "")
        new_value <- trimws(readline())
        if (new_value == "") new_value <- NA
      }

    } else if (field == "interval_min") {
      cat("Enter logging interval in minutes: ")
      input <- trimws(readline())
      new_value <- suppressWarnings(as.numeric(input))
      if (is.na(new_value) || new_value <= 0) {
        cat("Invalid interval - must be a positive number\n")
        next
      }

    } else if (field == "status") {
      # Only terminal-to-terminal. Bringing a device back into service is a
      # reactivation - a real event with its own workflow and its own log
      # entry - not a correction.
      cat("\nThis device is recorded as '", current, "'.\n", sep = "")
      cat("Correct it only if the wrong terminal status was recorded, e.g. a\n")
      cat("device swap logged as 'decommissioned' when it was 'replaced'.\n\n")
      cat("  removed         device taken out, station continues\n")
      cat("  replaced        swapped for another device at this station\n")
      cat("  relocated       the station moved - see the newer row\n")
      cat("  decommissioned  the station itself was shut down\n\n")
      cat("To bring a device back into service, use 'Reactivate\n")
      cat("decommissioned station' instead - that is an event, not a\n")
      cat("correction.\n\n")

      new_value <- ui_select_or_specify("Select the correct status:",
                                        terminal_statuses)
      if (is.null(new_value)) next

      if (!tolower(new_value) %in% terminal_statuses) {
        cat("\n\u274c '", new_value, "' is not a terminal status. This workflow\n",
            sep = "")
        cat("   corrects one terminal value for another; it cannot return a\n")
        cat("   device to service.\n")
        next
      }

    } else if (field == "deploy_datetime") {
      cat("Enter deploy datetime (YYYY-MM-DD HH:MM:SS): ")
      input <- trimws(readline())
      if (input == "") {
        cat("Not changed\n")
        next
      }
      parsed <- tryCatch(coerce_datetime_flexible(input, metadata$timezone[idx]),
                         error = function(e) NULL)
      if (is.null(parsed)) {
        cat("Could not read that as a date or datetime\n")
        next
      }
      new_value <- format(parsed, "%Y-%m-%d %H:%M:%S")

    } else if (field %in% c("lat", "lon")) {
      # Corrections only. A device that physically moved is an event - use the
      # relocation or replacement workflow so the move is logged.
      cat("\nOnly for correcting a coordinate recorded wrongly.\n")
      cat("If the device MOVED, cancel and use relocation or replacement\n")
      cat("instead, so the move is recorded in the maintenance log.\n\n")
      cat("Enter new ", field, " (decimal degrees): ", sep = "")
      input <- trimws(readline())
      new_value <- suppressWarnings(as.numeric(input))
      if (is.na(new_value)) {
        cat("Invalid - must be a number in decimal degrees\n")
        next
      }
      limit <- if (field == "lat") 90 else 180
      if (abs(new_value) > limit) {
        cat("Invalid - ", field, " must be between -", limit, " and ", limit,
            "\n", sep = "")
        next
      }
      # These stations are all in the Virgin Islands; a sign error puts a
      # coordinate in the Indian Ocean and nothing downstream would notice.
      if (field == "lat" && (new_value < 17 || new_value > 19)) {
        cat("\n⚠️  ", new_value, " is outside the Virgin Islands (17-19 N)\n", sep = "")
        if (ui_yes_no("Is that right?", allow_quit = FALSE) == "N") next
      }
      if (field == "lon" && (new_value > -64 || new_value < -66)) {
        cat("\n⚠️  ", new_value, " is outside the Virgin Islands (-64 to -66 W)\n", sep = "")
        if (ui_yes_no("Is that right?", allow_quit = FALSE) == "N") next
      }

    } else {
      cat("Enter new ", field, " (or press Enter to leave blank): ", sep = "")
      new_value <- trimws(readline())
      if (new_value == "") new_value <- NA
    }

    #### Confirm ####
    cat("\n  ", field, "\n", sep = "")
    cat("    from: ", blank_or_value(current), "\n", sep = "")
    cat("    to:   ", blank_or_value(new_value), "\n\n", sep = "")

    confirmed <- ui_yes_no("Apply this correction?", allow_quit = FALSE)
    if (confirmed == "N") {
      cat("Not applied\n")
      next
    }

    #### Write ####
    backup_metadata()

    metadata[[field]][idx] <- new_value

    setwd(wds("meta_internal"))
    metadata$deploy_datetime    <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update        <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date   <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit         <- as.character(metadata$last_visit)
    if ("expiry_date" %in% names(metadata)) {
      metadata$expiry_date <- as.character(metadata$expiry_date)
    }

    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    cat("Updated ", field, "\n", sep = "")

    #### A rename is an event, not just a correction ####
    # It explains why an old shuttle readout's filenames no longer match the
    # names in metadata. Without a log entry, someone looking at a folder of
    # files called "Backup.hobo" has nothing to tell them it is now "sr1".
    if (field == "status") {
      log_result <- create_maintenance_entry(
        field_visit_date = Sys.Date(),
        station_id       = station_id,
        station_type     = metadata$station_type[idx],
        device_serial    = device_serial,
        action_type      = "metadata_correction",
        details          = paste0("Terminal status corrected from '",
                                  blank_or_value(current), "' to '",
                                  blank_or_value(new_value), "'"),
        ports_updated    = FALSE,
        logged_by        = ui_ask_whois_logging()
      )
      if (isTRUE(log_result)) cat("Logged correction to maintenance\n")
    }

    if (field == "device_name") {
      log_result <- create_maintenance_entry(
        field_visit_date = Sys.Date(),
        station_id       = station_id,
        station_type     = metadata$station_type[idx],
        device_serial    = device_serial,
        action_type      = "device_renamed",
        details          = paste0("Device name changed from '",
                                  blank_or_value(current), "' to '",
                                  blank_or_value(new_value), "'"),
        ports_updated    = FALSE,
        logged_by        = ui_ask_whois_logging()
      )
      if (isTRUE(log_result)) cat("Logged rename to maintenance\n")
    }

    # Re-read so the display reflects what is actually on disk
    metadata <- load_zentra_metadata()
  }

  cat("\nDone.\n")
  invisible(TRUE)
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


#' Prompts for a device status, in a deliberate order, with meanings
#'
#' The generic picker sorted whatever statuses happened to exist in the
#' metadata alphabetically, which put "defunct" first and offered no clue what
#' any of them meant. Statuses are a fixed vocabulary, so they are listed here
#' explicitly rather than discovered - a new status should be a considered
#' addition, not something that appears because someone typed it once.
#'
#' Terminal statuses (replaced, relocated, decommissioned) are deliberately
#' absent: those are set by their own workflows, which log the event.
#'
#' @param allow_quit Logical. Allow 'q' to cancel (default TRUE)
#' @return Status string, or NULL if cancelled
ui_prompt_device_status <- function(allow_quit = TRUE) {

  statuses <- c("manual", "online", "local", "nonresponsive", "defunct")

  meanings <- c(
    manual        = "no cloud at all - data comes off by shuttle or cable",
    online        = "reports to the cloud over a cellular connection",
    local         = "out of cellular service - reaches the cloud when offloaded on site",
    nonresponsive = "should be communicating with the cloud but is not",
    defunct       = "broken or lost, but still deployed"
  )

  repeat {
    cat("\nSelect device status:\n")
    for (i in seq_along(statuses)) {
      cat("  ", i, ". ", format(statuses[i], width = 14), " ",
          meanings[statuses[i]], "\n", sep = "")
    }
    cat("  ", length(statuses) + 1, ". other (specify)\n", sep = "")

    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }

    choice <- trimws(readline())

    if (allow_quit && tolower(choice) == "q") return(NULL)

    if (grepl("^[0-9]+$", choice)) {
      n <- as.numeric(choice)

      if (n >= 1 && n <= length(statuses)) return(statuses[n])

      if (n == length(statuses) + 1) {
        cat("Enter status: ")
        custom <- tolower(trimws(readline()))
        if (custom == "") {
          cat("⚠️  Status cannot be empty\n")
          next
        }
        # A status outside the vocabulary will fail validate_metadata(), so
        # say that now rather than letting it surface later.
        cat("\n⚠️  '", custom, "' is not one of the known statuses. It will be\n",
            "   reported as a violation by validate_metadata() until it is\n",
            "   added to the valid list in validation_functions.R.\n", sep = "")
        if (ui_yes_no("Use it anyway?", allow_quit = FALSE) == "Y") return(custom)
        next
      }
    }

    cat("⚠️  Invalid selection\n")
  }
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


#' Names a device for display: its own name first, serial as the qualifier
#'
#' A HOBOware name means something to the person standing at the station; an
#' eight-digit serial does not. Fall back to the serial alone when unnamed.
#'
#' @param device_row One row of device metadata
#' @return Character
device_label <- function(device_row, with_role = FALSE) {
  nm <- device_row$device_name
  rl <- if (with_role) device_row$device_role else NA

  parts <- character(0)
  if (!is.null(nm) && length(nm) > 0 && !is.na(nm) && nzchar(trimws(nm))) {
    parts <- c(parts, trimws(nm))
  }
  if (!is.null(rl) && length(rl) > 0 && !is.na(rl) && nzchar(trimws(rl))) {
    parts <- c(parts, trimws(rl))
  }

  if (length(parts) == 0) return(as.character(device_row$device_serial))

  paste0(device_row$device_serial, " (", paste(parts, collapse = ", "), ")")
}


#' Resumes an unfinished data ingest
#'
#' check_pending() reports outstanding work; this acts on it. Without it the
#' only apparent route is to run the download workflow again, which would be
#' wrong - the field record was already written, so a second pass would
#' duplicate the maintenance entry and re-stamp last_visit. What is actually
#' outstanding is the archiving alone.
#'
#' @return TRUE if an ingest completed, FALSE if deferred again, NULL if cancelled
ui_resume_pending_ingest <- function() {

  pending <- load_pending_ingest()

  if (nrow(pending) == 0) {
    cat("\nNo unfinished data tasks.\n")
    return(invisible(NULL))
  }

  cat("\n============================================\n")
  cat("  Resume Unfinished Data Task\n")
  cat("============================================\n\n")

  options <- character(nrow(pending))
  for (i in seq_len(nrow(pending))) {
    label <- PENDING_STAGE_LABELS[pending$stage[i]]
    if (is.na(label)) label <- pending$stage[i]
    options[i] <- paste0(pending$station_id[i],
                         "  visited ", pending$field_visit_date[i],
                         "  - ", label)
  }

  selected <- ui_select_from_menu("Select task to resume:", options)
  if (is.null(selected)) {
    cat("Cancelled\n")
    return(invisible(NULL))
  }

  idx <- which(options == selected)[1]
  row <- pending[idx, ]

  #### Fill in what the pending row does not carry ####
  metadata <- load_zentra_metadata()
  dev <- metadata[metadata$device_serial == row$device_serial &
                  metadata$station_id == row$station_id, ]

  if (nrow(dev) == 0) {
    cat("\n❌ Device ", row$device_serial, " is no longer in metadata for ",
        row$station_id, ".\n", sep = "")
    cat("   The device may have been removed since this task was recorded.\n")
    return(invisible(NULL))
  }
  dev <- dev[1, ]

  #### A cloud upload is not an ingest - it just needs confirming ####
  if (row$stage == "awaiting_cloud_upload") {
    cat("This station was offloaded on site but the data has not yet been\n")
    cat("uploaded to ZentraCloud.\n\n")

    uploaded <- ui_yes_no("Has it been uploaded now?", allow_quit = FALSE)

    if (uploaded == "Y") {
      result <- update_download_approval(row$station_id, TRUE)
      if (!isTRUE(result)) {
        cat("⚠️  Warning: could not update download approval: ", result, "\n", sep = "")
      } else {
        cat("✓ Station approved for download - new data is available in the cloud\n")
      }
      clear_pending_ingest(row$station_id, row$device_serial)
      cat("✓ Task cleared\n\n")
      return(invisible(TRUE))
    }

    cat("\nLeft outstanding - you will be reminded again.\n\n")
    return(invisible(FALSE))
  }

  #### Otherwise hand back to the ingest workflow at the recorded stage ####
  ui_ingest_local_data(
    station_id       = row$station_id,
    device_serial    = row$device_serial,
    station_type     = dev$station_type,
    mfger            = dev$mfger,
    field_visit_date = as.Date(row$field_visit_date),
    logged_by        = row$logged_by,
    resume_stage     = row$stage
  )
}


#' Everything that should happen on the way out of the metadata manager
#'
#' There are two exits - 'q' from the main menu, and declining "do something
#' else" - and anything worth saying on the way out has to be said at both.
#' Putting it in one place is why the station photo reminder was missing from
#' one of them for a week.
#'
#' @param entries_at_start Integer. Maintenance log row count when the session
#'   began, used to report what this session wrote
#' @return Invisible TRUE
ui_exit_metadata_manager <- function(entries_at_start = NA) {

  #### What did this session actually write? ####
  # A last look before walking away. Everything here is already saved - this
  # is a chance to notice a wrong date or a misfiled station while it is still
  # fresh, not an opportunity to undo anything.
  if (!is.na(entries_at_start)) {
    mlog <- tryCatch(load_maintenance_log(), error = function(e) NULL)

    if (!is.null(mlog) && nrow(mlog) > entries_at_start) {
      new_rows <- mlog[(entries_at_start + 1):nrow(mlog), , drop = FALSE]

      cat("\n--- LOGGED THIS SESSION ---\n\n")
      for (i in seq_len(nrow(new_rows))) {
        cat("  ", format(as.character(new_rows$field_visit_date[i]), width = 12),
            format(new_rows$station_id[i], width = 14),
            format(new_rows$action_type[i], width = 20), "\n", sep = "")
        det <- new_rows$details[i]
        if (!is.na(det) && nzchar(trimws(det))) {
          cat("      ", det, "\n", sep = "")
        }
      }
      cat("\n  ", nrow(new_rows), " entr",
          ifelse(nrow(new_rows) == 1, "y", "ies"), " written.\n", sep = "")
    }
  }

  #### Station photos ####
  # Filed by hand, and nothing else in the system asks for them, so they are
  # quietly forgotten.
  photo_dir <- file.path(wds("meta_internal"), "station_photos")
  cat("\nIf you took station photos on this visit, file them here:\n\n")
  cat("     ", photo_dir, "\n\n", sep = "")
  cat("  Named station_id_YYYY-MM-DD, e.g. sr1_hydro_2026-03-02.jpeg\n")

  cat("\n\u2713 Exiting Metadata Manager\n")
  invisible(TRUE)
}


#' Orders devices at a station by role
#'
#' Two loggers at a gauge mean nothing in metadata order; primary then
#' secondary is how they are thought about in the field, so it is how they
#' should be listed. Anything with an unrecognised or missing role sorts last
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
get_active_ports <- function(device_serial) {
  ports <- tryCatch(load_zentra_ports_data(), error = function(e) NULL)

  empty <- data.frame()
  if (is.null(ports) || nrow(ports) == 0) return(empty)

  active <- ports[ports$sn == device_serial & is.na(ports$valid_to), , drop = FALSE]
  active <- active[!is.na(active$sensor) & active$sensor != "none", , drop = FALSE]

  active
}


#' Closes a device's active port configurations
#'
#' A port configuration says "this sensor is on this port from this time".
#' When a device leaves service that statement stops being true, so valid_to
#' has to be set - otherwise the record claims sensors are live on a device
#' that is in a drawer.
#'
#' NOT called on relocation: a relocated device keeps its serial and its
#' sensors, and ports are keyed by serial. Closing them there would be wrong.
#'
#' @param device_serial Character. Device leaving service
#' @param close_datetime POSIXct or Date. When it stopped being true
#' @return Number of port rows closed, or an error message string
close_device_ports <- function(device_serial, close_datetime) {
  tryCatch({
    if (is_hobo_device_serial(device_serial)) return(0)

    ports <- load_zentra_ports_data()

    open_rows <- which(ports$sn == device_serial & is.na(ports$valid_to) &
                       !is.na(ports$sensor) & ports$sensor != "none")

    if (length(open_rows) == 0) return(0)

    ports$valid_to[open_rows] <- as.POSIXct(close_datetime)

    ports$valid_from <- format_datetime_safe(ports$valid_from)
    ports$valid_to   <- format_datetime_safe(ports$valid_to)
    write.csv(ports, file.path(wds("meta_internal"), "zentra_ports.csv"),
              row.names = FALSE)

    return(length(open_rows))
  }, error = function(e) {
    return(paste0("Failed to close ports: ", e$message))
  })
}


#' Is this serial a HOBO logger? (serial-shaped test, for use without metadata)
#' @param device_serial Character
#' @return Logical
is_hobo_device_serial <- function(device_serial) {
  !grepl("^z", device_serial, ignore.case = TRUE)
}
