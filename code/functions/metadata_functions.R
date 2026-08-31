# Local metadata management functions
# Load, validate, edit, local metadata files

######################          LOADING FUNCTIONS         ######################

#' Loads device_metadata.csv with formatting done
#' Requires: wds() and parse_date functions from setup_functions.R
#' Only intended for use WITHIN A SINGLE TIME ZONE!!
#' Handles both R and Excel date formats automatically
#' @return Data.frame. Zentra device metadata with formatted dates/timezone
load_zentra_metadata <- function(){
  setwd(wds("meta_internal"))
  metadata <- read.csv("device_metadata.csv", stringsAsFactors = FALSE)
  timezone <- metadata$timezone[1] # This assumes all the time zones are the same!
  # Parse datetime columns (handles both R and Excel formats)
  metadata$deploy_datetime <- parse_datetime_flexible(metadata$deploy_datetime, timezone)
  metadata$last_update <- parse_datetime_flexible(metadata$last_update, timezone)
  metadata$last_download_date <- parse_datetime_flexible(metadata$last_download_date, timezone)
  
  # Parse date columns (handles both R and Excel formats)
  metadata$expiry_date <- parse_date_flexible(metadata$expiry_date)
  metadata$last_visit <- parse_date_flexible(metadata$last_visit)
  # Convert logical column
  metadata$download_approved <- as.logical(metadata$download_approved)
  return(metadata)
}

#' Loads zentra_ports.csv with formatting done
#' Requires: wds() and parse_date functions from setup_functions.R
#' Only intended for use WITHIN A SINGLE TIME ZONE!!
#' Handles both R and Excel date formats automatically
#' @return Data.frame. Zentra port configuration history with formatted dates
load_zentra_ports_data <- function(){
  setwd(wds("meta_internal"))
  ports <- read.csv("zentra_ports.csv", stringsAsFactors = FALSE)
  # Get timezone from device metadata (assuming all same timezone)
  metadata <- load_zentra_metadata()
  timezone <- metadata$timezone[1] # Assumes the same time zone!
  # Parse datetime columns (handles both R and Excel formats)
  ports$valid_from <- parse_datetime_flexible(ports$valid_from, timezone)
  ports$valid_to <- parse_datetime_flexible(ports$valid_to, timezone)
  return(ports)
}

#' Loads download_log.csv from metadata/internal
#' #' Requires: wds() and parse_date functions from setup_functions.R
#' Only intended for use WITHIN A SINGLE TIME ZONE!!
#' Parses datetime columns appropriately
#' @return Data.frame. Download log with formatted dates
load_download_log <- function() {
  setwd(wds("meta_internal"))
  log <- read.csv("download_log.csv", stringsAsFactors = FALSE)
  # Get timezone from device metadata for consistency
  metadata <- load_zentra_metadata()
  timezone <- metadata$timezone[1]
  # Parse datetime columns (handles both R and Excel formats)
  log$timestamp <- parse_datetime_flexible(log$timestamp, timezone)
  log$start_date <- parse_datetime_flexible(log$start_date, timezone)
  log$end_date <- parse_datetime_flexible(log$end_date, timezone)
  return(log)
}

#' Loads maintenance_log.csv from metadata/internal
#' Requires: wds() and parse_date functions from setup_functions.R
#' Only intended for use WITHIN A SINGLE TIME ZONE!!
#' Parses datetime columns appropriately
#' @return Data.frame. Maintenance log with formatted dates
load_maintenance_log <- function() {
  setwd(wds("meta_internal"))
  log <- read.csv("maintenance_log.csv", stringsAsFactors = FALSE)
  # Get timezone from device metadata for consistency
  metadata <- load_zentra_metadata()
  timezone <- metadata$timezone[1]
  # Parse datetime columns (handles both R and Excel formats)
  log$timestamp <- parse_datetime_flexible(log$timestamp, timezone)
  log$field_visit_date <- parse_date_flexible(log$field_visit_date)
  # Convert logical
  log$ports_updated <- as.logical(log$ports_updated)
  return(log)
}

######################          BACK-UP FUNCTIONS         ######################

#' Backs up all CSV files in metadata/internal directory
#' Creates timestamped copies in backups subdirectory
#' Automatically cleans up backups older than 1 year
#' @return Invisible TRUE on success
backup_metadata <- function() {
  meta_dir <- wds("meta_internal")
  backup_dir <- file.path(meta_dir, "backups")
  
  # Create backup directory if needed
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE)
  }
  
  # Get all CSV files in metadata directory (but not in subdirectories)
  csv_files <- list.files(meta_dir, pattern = "\\.csv$", full.names = TRUE, recursive = FALSE)
  
  if (length(csv_files) == 0) {
    message("No CSV files found to backup")
    return(invisible(FALSE))
  }
  
  # Create timestamp for this backup batch
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "America/Puerto_Rico")
  
  # Backup each CSV file
  files_backed_up <- 0
  for (csv_file in csv_files) {
    # Skip download_log.csv - don't backup log files
    if (grepl("download_log", basename(csv_file))) {
      next
    }
    # Check if file is identical to most recent backup
    base_name <- tools::file_path_sans_ext(basename(csv_file))
    existing_backups <- list.files(backup_dir, 
                                   pattern = paste0("^", base_name, "_.*\\.csv$"), 
                                   full.names = TRUE)
    if (length(existing_backups) > 0) {
      # Get most recent backup
      most_recent <- existing_backups[which.max(file.info(existing_backups)$mtime)]
      
      # Compare file contents
      if (tools::md5sum(csv_file) == tools::md5sum(most_recent)) {
        # Files are identical - skip backup
        next
      }
    }
    # Generate backup filename
    backup_name <- paste0(base_name, "_", timestamp, ".csv")
    backup_path <- file.path(backup_dir, backup_name)
    # Copy file
    file.copy(csv_file, backup_path)
    files_backed_up <- files_backed_up + 1
  }
  message("✓ Backed up ", files_backed_up, " metadata file(s)")
  # Clean up old backups (older than 1 year)
  cleanup_old_backups(backup_dir, days = 365)
  invisible(TRUE)
}

#' Removes backup files older than specified number of days
#' @param backup_dir Character. Path to backups directory
#' @param days Numeric. Keep backups newer than this many days (default 365)
#' @return Invisible number of files deleted
cleanup_old_backups <- function(backup_dir, days = 365) {
  # Get all backup files
  all_backups <- list.files(backup_dir, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(all_backups) == 0) {
    return(invisible(0))
  }
  # Get file modification times
  file_ages <- difftime(Sys.time(), file.info(all_backups)$mtime, units = "days")
  # Find files older than threshold
  old_files <- all_backups[file_ages > days]
  if (length(old_files) > 0) {
    file.remove(old_files)
    message("Cleaned up ", length(old_files), " backup(s) older than ", days, " days")
    return(invisible(length(old_files)))
  }
  invisible(0)
}

######################          EDITING FUNCTIONS         ######################

#' Sets download_approved flag for device(s) in device_metadata.csv
#' Can approve single device, all devices at a station, or all devices
#' @param device_serial Character. Device serial number (optional if station_id provided)
#' @param station_id Character. Station ID - approves all devices at station (optional)
#' @param approve_all Logical. If TRUE, approves all devices (default FALSE)
#' @param value Logical. TRUE to approve, FALSE to un-approve (default TRUE)
#' @return Invisible TRUE on success
set_download_approved <- function(device_serial = NULL, station_id = NULL, approve_all = FALSE, value = TRUE) {
  # Load metadata
  metadata <- load_zentra_metadata()
  # Determine which rows to update
  if (approve_all) {
    # Approve all devices
    rows_to_update <- rep(TRUE, nrow(metadata))
    message("Setting download_approved = ", value, " for ALL devices")
  } else if (!is.null(station_id)) {
    # Approve all devices at this station
    rows_to_update <- metadata$station_id == station_id
    if (sum(rows_to_update) == 0) {
      stop("No devices found for station: ", station_id, call. = FALSE)
    }
    message("Setting download_approved = ", value, " for station: ", station_id, 
            " (", sum(rows_to_update), " device(s))")
  } else if (!is.null(device_serial)) {
    # Approve specific device
    rows_to_update <- metadata$device_serial == device_serial
    if (sum(rows_to_update) == 0) {
      stop("Device not found: ", device_serial, call. = FALSE)
    }
    message("Setting download_approved = ", value, " for device: ", device_serial)
  } else {
    stop("Must provide device_serial, station_id, or set approve_all = TRUE", call. = FALSE)
  }
  # Update the flag
  metadata$download_approved[rows_to_update] <- value
  # Save metadata back to CSV
  # This block previously formatted only three of the datetime columns - it
  # predates last_record_date, last_visit and expiry_date - and runs on every
  # approval. save_device_metadata() handles whatever columns are present.
  save_device_metadata(metadata)
  message("✓ Updated download approval(s) for device_metadata.csv")
  invisible(TRUE)
}

#' Writes a maintenance entry to maintenance_log.csv
#' Core function - can be called by interactive script or future GUI
#' Requires setup_functions.R
#' @param field_visit_date Character or Date. When you visited (YYYY-MM-DD)
#' @param station_id Character. Station ID
#' @param station_type Character. Station type (vwc, weather, streamflow, etc.)
#' @param device_serial Character. Device serial number
#' @param action_type Character. What was done
#' @param details Character. Free text description
#' @param ports_updated Logical. Did you update zentra_ports.csv?
#' @param logged_by Character. Your name/initials
#' @return Invisible TRUE on success
write_maintenance_entry <- function(field_visit_date, station_id, station_type, 
                                    device_serial, action_type, details, 
                                    ports_updated, logged_by) {
  # Get timezone from metadata for timestamp
  metadata <- load_zentra_metadata()
  timezone <- metadata$timezone[1]
  # Create new entry
  new_entry <- data.frame(
    timestamp = format_datetime_safe(as.POSIXct(Sys.time(), tz = timezone)),
    field_visit_date = as.character(field_visit_date),
    station_id = station_id,
    station_type = station_type,
    device_serial = device_serial,
    action_type = action_type,
    details = details,
    ports_updated = ports_updated,
    logged_by = logged_by,
    stringsAsFactors = FALSE
  )
  
  # Append to log
  log_file <- file.path(wds("meta_internal"), "maintenance_log.csv")
  
  if (file.exists(log_file)) {
    # Append without headers
    write.table(new_entry, log_file, sep = ",", append = TRUE, 
                row.names = FALSE, col.names = FALSE)
  } else {
    # Create new with headers
    write.csv(new_entry, log_file, row.names = FALSE)
  }
  
  message("✓ Maintenance entry logged for ", station_id, " (", device_serial, ")")
  invisible(TRUE)
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
    terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")
    
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
    
    # A device out of service cannot be downloaded, so approval stops meaning
    # anything. Clearing it here covers every terminal transition at once -
    # replacement, removal, relocation, decommissioning - rather than leaving
    # each workflow to remember.
    terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")
    if (tolower(new_status) %in% terminal_statuses &&
        "download_approved" %in% names(metadata)) {
      metadata$download_approved[rows] <- FALSE
    }
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
    
    # A station out of service cannot be downloaded. update_device_status()
    # clears this for device-level transitions; station-level ones come
    # through here and were being missed.
    station_terminal <- c("removed", "replaced", "relocated", "decommissioned")
    if (tolower(new_status) %in% station_terminal &&
        "download_approved" %in% names(metadata)) {
      metadata$download_approved[metadata$station_id == station_id &
                                 tolower(metadata$status) %in% station_terminal] <- FALSE
    }
    save_device_metadata(metadata)
    
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
    save_device_metadata(metadata)
    
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
    save_device_metadata(metadata)
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
    save_device_metadata(metadata)
    
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
    save_device_metadata(metadata)
    
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
    # deploy_datetime differs between a serial's rows, and it becomes the
    # valid_from on every port written below - an arbitrary row would stamp the
    # ports with the wrong deployment's start time.
    device_row <- get_device_row(device_serial, metadata = metadata)
    if (is.null(device_row)) {
      return(paste0("Device '", device_serial, "' not found in metadata"))
    }
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

      # An empty port that was never configured has no row to close
      has_old_row <- nrow(old_port) > 0

      is_empty_na_na <- has_old_row &&
                        old_port$sensor[1] == "none" &&
                        is.na(old_port$valid_from[1]) &&
                        is.na(old_port$valid_to[1]) &&
                        new_port$sensor == "none"

      if (has_old_row && !is_empty_na_na) {
        ports$valid_to[ports$sn == device_serial &
                         ports$port == port_num &
                         is.na(ports$valid_to)] <- change_datetime
      }

      if (is_empty_na_na) next  # nothing to record

      if (new_port$sensor == "none") {
        new_rows_list[[as.character(port_num)]] <- data.frame(
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
        new_rows_list[[as.character(port_num)]] <- data.frame(
          sn = as.character(device_serial),
          port = as.integer(port_num),
          type = as.character(new_port$type),
          sensor = as.character(new_port$sensor),
          depth_cm = as.integer(new_port$depth_cm),
          status = if (is.na(new_port$status)) NA_character_ else as.character(new_port$status),
          valid_from = change_datetime,
          valid_to = as.POSIXct(NA),
          stringsAsFactors = FALSE
        )
      }
    }

    if (length(new_rows_list) > 0) {
      ports <- rbind(ports, do.call(rbind, new_rows_list))
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
      # Establishing a station on a date means somebody stood at it on that
      # date. The deploy datetime IS a field visit, so recording it as one is
      # not an inference - it is the same fact stated in the field that asks
      # "when was this last visited?"
      last_visit = as.Date(device_data$deploy_datetime),
      expiry_date = device_data$expiry_date,
      last_download_date = NA,
      last_record_date = NA,
      download_approved = device_data$download_approved,
      stringsAsFactors = FALSE
    )
    
    # Add to metadata
    metadata <- rbind(metadata, new_row)
    save_device_metadata(metadata)
    
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
    save_device_metadata(metadata)
    
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
    # The FIRST row matching a serial may be a closed historical one. Take the
    # first ACTIVE row instead - that is the deployment being removed.
    terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")
    candidates <- metadata[metadata$device_serial == device_serial &
                           !tolower(metadata$status) %in% terminal_statuses, ]
    
    if (nrow(candidates) == 0) {
      return(paste0("No active deployment found for device '", device_serial, "'"))
    }
    device_row <- candidates[1, ]
    
    # 1. Update status to removed
    result <- update_device_status(device_serial, "removed",
                                   station_id = device_row$station_id)
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

#' Writes device_metadata.csv with every datetime column formatted
#'
#' Sixteen copies of this block existed, differing slightly: two omitted
#' expiry_date, and api_functions.R omitted last_record_date, last_visit and
#' expiry_date because it predates those columns. Every one was a place a new
#' column could be forgotten - which is exactly how last_record_date came to be
#' written as a Unix epoch.
#'
#' Columns are handled by NAME and only if present, so a caller working with a
#' subset, or a schema that gains a column, needs no change here.
#'
#' Takes a path rather than setwd()-ing, so it has no effect on the caller's
#' working directory.
#'
#' @param metadata Data.frame. Full device metadata to write
#' @param path Character. Destination (default: device_metadata.csv in meta_internal)
#' @return Invisible TRUE
save_device_metadata <- function(metadata, path = NULL) {

  if (is.null(path)) {
    path <- file.path(wds("meta_internal"), "device_metadata.csv")
  }

  # Datetimes: format_datetime_safe handles POSIXct, character and all-NA
  # logical columns alike
  datetime_cols <- c("deploy_datetime", "last_update",
                     "last_download_date", "last_record_date")
  for (col in intersect(datetime_cols, names(metadata))) {
    metadata[[col]] <- format_datetime_safe(metadata[[col]])
  }

  # Dates: written as-is, no time component
  date_cols <- c("last_visit", "expiry_date")
  for (col in intersect(date_cols, names(metadata))) {
    metadata[[col]] <- as.character(metadata[[col]])
  }

  write.csv(metadata, path, row.names = FALSE)
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

  terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")

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

  active <- ports[ports$sn == device_serial & is.na(ports$valid_to), , drop = FALSE]
  active <- active[!is.na(active$sensor) & active$sensor != "none", , drop = FALSE]

  # A shared logger has ports of more than one type. "Does this device have
  # active ports?" is the wrong question when a weather station is being set
  # up on a box whose vwc ports are open but whose ATMOS was taken off - the
  # answer is yes, and the weather station ends up with no sensor recorded.
  if (!is.null(station_type) && nrow(active) > 0) {
    active <- active[tolower(active$type) == tolower(station_type), , drop = FALSE]
  }

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

#' Closes specific port configurations
#'
#' Where close_device_ports() retires everything on a device, this retires
#' named ports - the case where a shared logger stays on site but the
#' sensors belonging to a retired station come off it.
#'
#' @param port_keys Character vector of "serial|port" entries
#' @param close_datetime POSIXct. When they stopped being deployed
#' @return Number of rows closed, or an error message string
close_specific_ports <- function(port_keys, close_datetime) {
  tryCatch({
    ports <- load_zentra_ports_data()
    n <- 0

    for (key in port_keys) {
      parts <- strsplit(key, "|", fixed = TRUE)[[1]]
      if (length(parts) != 2) next

      rows <- which(ports$sn == parts[1] &
                    as.character(ports$port) == parts[2] &
                    is.na(ports$valid_to))
      if (length(rows) == 0) next

      ports$valid_to[rows] <- as.POSIXct(close_datetime)
      n <- n + length(rows)
    }

    if (n == 0) return(0)

    ports$valid_from <- format_datetime_safe(ports$valid_from)
    ports$valid_to   <- format_datetime_safe(ports$valid_to)
    write.csv(ports, file.path(wds("meta_internal"), "zentra_ports.csv"),
              row.names = FALSE)

    return(n)
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


################################################################################
