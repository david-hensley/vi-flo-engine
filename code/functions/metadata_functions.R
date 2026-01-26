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
  # Parse date columns (handles both R and Excel formats)
  metadata$expiry_date <- parse_date_flexible(metadata$expiry_date)
  metadata$last_visit <- parse_date_flexible(metadata$last_visit)
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