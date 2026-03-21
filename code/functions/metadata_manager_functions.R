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
  
  if (nrow(device_ports) == 0) {
    # No config exists - return empty 6-port template
    return(data.frame(
      port = 1:6,
      type = rep("none", 6),
      sensor = rep("none", 6),
      depth_cm = rep(NA, 6),
      status = rep(NA, 6),
      stringsAsFactors = FALSE
    ))
  }
  
  # Get active configurations (valid_to = NA)
  active_ports <- device_ports[is.na(device_ports$valid_to), ]
  
  if (nrow(active_ports) == 0) {
    # No active configs - return empty 6-port template
    return(data.frame(
      port = 1:6,
      type = rep("none", 6),
      sensor = rep("none", 6),
      depth_cm = rep(NA, 6),
      status = rep(NA, 6),
      stringsAsFactors = FALSE
    ))
  }
  
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
    
    # Compare new vs current to find what changed
    # Only update ports that actually changed
    for (i in 1:nrow(port_config)) {
      port_num <- port_config$port[i]
      new_port <- port_config[i, ]
      current_port <- current_config[current_config$port == port_num, ]
      
      # Determine if this port changed
      port_changed <- FALSE
      
      # Check if sensor changed (including none → sensor or sensor → none)
      if (current_port$sensor[1] != new_port$sensor) {
        port_changed <- TRUE
      }
      # Check if type changed
      else if (current_port$type[1] != new_port$type) {
        port_changed <- TRUE
      }
      # Check if depth changed (using identical to handle NAs properly)
      else if (!identical(current_port$depth_cm[1], new_port$depth_cm)) {
        port_changed <- TRUE
      }
      # Check if status changed
      else if (!identical(current_port$status[1], new_port$status)) {
        port_changed <- TRUE
      }
      
      if (port_changed) {
        # Close old config for THIS port only (if it exists and isn't already "none")
        if (current_port$sensor[1] != "none") {
          ports$valid_to[ports$sn == device_serial & 
                         ports$port == port_num & 
                         is.na(ports$valid_to)] <- change_datetime
        }
        
        # Add new row for THIS port
        # For ports becoming empty, set valid_from and valid_to to NA
        if (new_port$sensor == "none") {
          new_row <- data.frame(
            sn = device_serial,
            port = port_num,
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
            port = port_num,
            type = new_port$type,
            sensor = new_port$sensor,
            depth_cm = new_port$depth_cm,
            status = new_port$status,
            valid_from = change_datetime,
            valid_to = NA,
            stringsAsFactors = FALSE
          )
        }
        
        ports <- rbind(ports, new_row)
      }
      # If unchanged, do nothing - old row stays active
    }
    
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
#' @return List with success status and unique_id if successful, error if failed
add_new_device <- function(device_data) {
  tryCatch({
    metadata <- load_zentra_metadata()
    
    # Generate unique_id based on manufacturer
    if (tolower(device_data$mfger) == "meter") {
      prefix <- "z"
    } else if (tolower(device_data$mfger) %in% c("onset", "hobo")) {
      prefix <- "h"
    } else {
      return(list(success = FALSE, error = "Unknown manufacturer, cannot determine unique_id prefix"))
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
    
    return(list(success = TRUE, unique_id = unique_id))
  }, error = function(e) {
    return(list(success = FALSE, error = paste0("Failed to add device: ", e$message)))
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

################################################################################
#### CONSOLE UI MAIN FUNCTIONS ####
################################################################################
# These are the main interactive functions that users call
# Each handles a specific workflow

#' Interactive maintenance logging
#' Logs a maintenance entry and updates metadata as needed
#' @return List with device_serial, action_type, ports_updated, or NULL if quit
ui_log_maintenance <- function() {
  cat("\n============================================\n")
  cat("  Maintenance Logger\n")
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
  
  #### 4 - Action type
  standard_actions <- c("download", "sensor_swap", "depth_change", "cleaning", 
                       "battery", "relocation", "device_removed", "device_installed", 
                       "maintenance", "other")
  
  # Add custom actions from log history
  custom_actions <- get_unique_action_types()
  custom_actions <- setdiff(custom_actions, c(standard_actions, "other"))
  
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
  
  #### 6 - Ports updated?
  ports_updated_response <- ui_yes_no("\nDid you update port configuration?")
  if (ports_updated_response == "Q") {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  ports_updated <- (ports_updated_response == "Y")
  cat("✓ Ports updated:", ports_updated, "\n")
  
  #### 7 - Who logged this?
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
  
  #### 8 - Status update
  current_status <- station_devices$status[1]
  
  # Suggest status based on action
  suggested_status <- NULL
  if (action_type == "relocation") {
    suggested_status <- "relocated"
  } else if (action_type == "device_removed") {
    suggested_status <- "decommissioned"
  }
  
  cat("\n============================================\n")
  cat("Current status for ", station_id, ": ", current_status, "\n", sep = "")
  if (!is.null(suggested_status)) {
    cat("Suggested new status: ", suggested_status, "\n", sep = "")
  }
  
  change_status_response <- ui_yes_no("Does this status need to change?")
  if (change_status_response == "Q") {
    cat("❌ Cancelled\n")
    return(NULL)
  }
  
  new_status <- current_status  # Default to unchanged
  
  if (change_status_response == "Y") {
    # If there's a suggested status, offer to use it
    if (!is.null(suggested_status)) {
      use_suggested <- ui_yes_no(paste0("Use suggested status '", suggested_status, "'?"), 
                                 allow_quit = FALSE)
      if (use_suggested == "Y") {
        new_status <- suggested_status
      } else {
        # Show full status menu
        existing_statuses <- get_metadata_unique_values("status")
        new_status <- ui_select_or_specify("Select new status:", existing_statuses, 
                                          allow_quit = FALSE)
      }
    } else {
      # No suggestion, show full menu
      existing_statuses <- get_metadata_unique_values("status")
      new_status <- ui_select_or_specify("Select new status:", existing_statuses, 
                                        allow_quit = FALSE)
    }
    cat("✓ New status:", new_status, "\n")
  } else {
    cat("✓ Status unchanged:", current_status, "\n")
  }
  
  #### 9 - Confirmation
  cat("\n============================================\n")
  cat("Ready to log this maintenance entry:\n")
  cat("  Date:", field_visit_date, "\n")
  cat("  Station:", station_id, "\n")
  cat("  Device:", device_serial, "\n")
  cat("  Action:", action_type, "\n")
  cat("  Details:", details, "\n")
  cat("  Ports updated:", ports_updated, "\n")
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
  
  #### 10 - Write maintenance entry
  result <- create_maintenance_entry(
    field_visit_date = field_visit_date,
    station_id = station_id,
    station_type = station_type,
    device_serial = device_serial,
    action_type = action_type,
    details = details,
    ports_updated = ports_updated,
    logged_by = logged_by
  )
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Maintenance entry logged\n")
  
  #### 11 - Update last_visit
  result <- update_last_visit(station_id, field_visit_date)
  if (!isTRUE(result)) {
    cat("⚠️  Warning: Could not update last_visit:", result, "\n")
  } else {
    cat("✓ Updated last_visit\n")
  }
  
  #### 12 - Update status if changed
  if (new_status != current_status) {
    result <- update_station_status(station_id, new_status)
    if (!isTRUE(result)) {
      cat("⚠️  Warning: Could not update status:", result, "\n")
    } else {
      cat("✓ Updated status to:", new_status, "\n")
    }
  }
  
  #### 13 - Download approval
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
  
  # Return info for potential chaining
  return(list(
    device_serial = device_serial,
    station_id = station_id,
    action_type = action_type,
    ports_updated = ports_updated
  ))
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
    cat("  2. Established new station or reactivated old station\n")
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
        cat("  1. Routine maintenance (cleaning, battery, inspection)\n")
        cat("  2. Downloaded data (manual/HOBO devices)\n")
        cat("  3. Port configuration change (sensor swap, depth change)\n")
        cat("  4. Device replacement\n")
        cat("  5. Station relocated\n")
        cat("  6. Station decommissioned\n")
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
            # Success - ask if more work at this station
            cat("\nDid you do anything else at this station? (Y/N): ")
            more_work <- toupper(trimws(readline()))
            if (more_work != "Y" && more_work != "1") {
              break  # Done with this station
            }
            # Loop continues for more work
          } else {
            # User quit - back to work type menu
            next
          }
        }
        
        ### Option 2: Downloaded data
        else if (work_choice == "2") {
          result <- ui_log_download()
          
          if (!is.null(result)) {
            cat("\nDid you do anything else at this station? (Y/N): ")
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
            cat("\nDid you do anything else at this station? (Y/N): ")
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
            
            cat("\nDid you do anything else at this station? (Y/N): ")
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
            # Relocation is major - probably done with this station
            break
          } else {
            next
          }
        }
        
        ### Option 6: Station decommissioned
        else if (work_choice == "6") {
          result <- ui_decommission_station()
          
          if (!is.null(result)) {
            # Decommissioned - definitely done
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
      cat("  1. Brand new station (new site)\n")
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
    cat("\n\nDo something else? (Y/N): ")
    continue_response <- toupper(trimws(readline()))
    if (continue_response != "Y" && continue_response != "1") {
      cat("\n✓ Exiting Metadata Manager\n")
      return(invisible(TRUE))
    }
    
  }  # End main loop
  
}