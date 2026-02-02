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
  setwd(wds("meta_internal"))
  metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
  metadata$last_update <- format_datetime_safe(metadata$last_update)
  metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
  
  write.csv(metadata, "device_metadata.csv", row.names = FALSE)
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