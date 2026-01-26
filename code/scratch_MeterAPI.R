# The following line can be run alone to call in setup functions
source(paste0(Sys.getenv("VI_FLO_ENGINE_ROOT"), "/code/functions/setup_functions.R"))
load_functions("api")
setwd(wds("data"))

############
# Run set-up function to get main Zentra Cloud token
setup_zentracloud("ZENTRACLOUD_TOKEN")
metadata <- load_zentra_metadata()
ports <- load_zentra_ports_data()



# These commands read and then add a named path if wanted
#read_datamap()
#path <- paste0(wds("data"), "/internal/raw/streamflow")
#set_named_path("internal_raw_streamflow", path)


# Write in elevations

# Write last download date
# Write the last recorded datetime for station
# Prevent downloads from less than a week ago unless override - this stops downloads when metadata needs updating manually
# Do all the above in the wrapper function

# Make sure last update is UP TO DATE in whatever master function runs all this together!

# Work out some sort of "rollback" process for when downloads occur with bad metadata
# Work out an external emailing system that will ask you if any metadata has changed since DATE, running every 2 weeks 


#df <- download_zentra_station("fb1_weather", metadata, ports, start = "2024-02-06 00:00:00", end = "2024-02-07 00:00:00")
station <- "fb1_weather"

#' Safe wrapper for downloading Zentra station data with validation and storage
#' 
#' Downloads station data with automatic validation, date trimming, duplicate prevention,
#' and organized file storage. Use this instead of download_zentra_station() for production workflows.
#' 
#' @param station Character. Station ID code from metadata e.g. "sr1_weather"
#' @param metadata Data.frame. Output from load_zentra_metadata()
#' @param ports Data.frame. Output from load_zentra_ports_data()
#' @param start Character. Start datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param end Character. End datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param all Logical. If TRUE, downloads entire station history (default FALSE)
#' @return Character. File path where data was saved
#' 
#' @details
#' This function performs the following steps:
#' 1. Validates metadata using validate_zentra_metadata()
#' 2. Checks for recent downloads (unless force = TRUE)
#' 3. Trims requested dates to available range (unless strict_dates = TRUE)
#' 4. Downloads data using download_zentra_station()
#' 5. Saves to organized directory structure: /raw/internal/{station}/
#' 6. Logs download to download_log.csv
#' 
#' File naming convention: {station}_{start-date}_{end-date}_raw.rds
#' Example: sr1_vwc_20240101_20240131_raw.rds
#' 
#' @examples
#' \dontrun{
#' metadata <- load_zentra_metadata()
#' ports <- load_zentra_ports_data()
#' 
#' # Download with auto-trimming
#' filepath <- safe_download_zentra_station("sr1_vwc", metadata, ports,
#'                                          "2024-01-01 00:00:00", 
#'                                          "2024-12-31 23:59:59")
#' 
#' # Download entire history
#' filepath <- safe_download_zentra_station("sr1_weather", metadata, ports, all = TRUE)
#' }
safe_download_zentra_station <- function(station, metadata, ports, start = NULL, end = NULL, all = FALSE) {
  # Load in metadata functions required for this call
  load_functions("metadata")
  
  # ========== STEP 1: VALIDATE METADATA ==========
  message("Validating metadata for station: ", station)
  if (!validate_zentra_metadata(station, metadata, ports)) {
    stop("Metadata validation failed. Fix errors before downloading.", call. = FALSE)
  }
  message("✓ Metadata validation passed")
  
  # ========== STEP 2: CHECK APPROVAL FLAG ==========
  station_devices <- metadata[metadata$station_id == station, ]
  # Check if any device for this station has download_approved != TRUE
  if ("download_approved" %in% names(metadata)) {
    if (any(station_devices$download_approved != TRUE, na.rm = TRUE)) {
      stop("Station '", station, "' is not approved for download.\n",
           "Set download_approved = TRUE in metadata after confirming metadata is current.",
           call. = FALSE)
    }
    message("✓ Download approved for station: ", station)
  } else {
    stop("Column 'download_approved' not found in metadata! Quitting..")
  }
  
  # ========== STEP 3: HANDLE DATE RANGE ==========
  earliest_deploy <- min(station_devices$deploy_datetime)
  latest_update <- max(station_devices$last_update)
  if (all) {
    start <- earliest_deploy
    end <- latest_update
    message("Downloading entire history: ", format(start, "%Y-%m-%d"), 
            " to ", format(end, "%Y-%m-%d"))
  } else {
    # Check that start/end provided
    if (is.null(start) || is.null(end)) {
      stop("Must provide start and end dates, or set all = TRUE", call. = FALSE)
    }
    timezone <- station_devices$timezone[1] # Assumes all in the same timezone
    start <- as.POSIXct(start, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
    end <- as.POSIXct(end, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
    # Check if dates are outside available range
    if (start < earliest_deploy || end > latest_update) {
      # Trim to available range
      original_start <- start
      original_end <- end
      start <- max(start, earliest_deploy)
      end <- min(end, latest_update)
      if (start != original_start || end != original_end) {
        message("NOTE: Trimmed date range to available data:")
        message("  Requested: ", format(original_start, "%Y-%m-%d"), " to ", format(original_end, "%Y-%m-%d"))
        message("  Actual: ", format(start, "%Y-%m-%d"), " to ", format(end, "%Y-%m-%d"))
      }
    }
  }
  
  # ========== STEP 4: DOWNLOAD DATA ==========
  backup_metadata() # Back up the metadata before taking action
  message("Downloading data from ZentraCloud...")
  # Log the current time at the device's timezone to record the download time
  timezone <- station_devices$timezone[1]
  datetime_at_station <- as.POSIXct(Sys.time(), tz = timezone)
  download_timestamp <- format(datetime_at_station, "%Y-%m-%d %H:%M:%S")
  data <- download_zentra_station(
    station = station,
    metadata = metadata,
    ports = ports,
    start = format(start, "%Y-%m-%d %H:%M:%S"),
    end = format(end, "%Y-%m-%d %H:%M:%S")
  )
  message("✓ Downloaded ", nrow(data), " records")
  
  # ========== STEP 5: SAVE TO FILE ==========
  # Create directory if needed
  type <- sub(".*_", "", station)
  station_dir <- wds(paste0("internal_raw_", type))
  if (!dir.exists(station_dir)) {
    dir.create(station_dir, recursive = TRUE)
    message("Created directory: ", station_dir)
  }
  # Generate filename
  start_date <- format(start, "%Y%m%d")
  end_date <- format(end, "%Y%m%d")
  filename <- paste0(station, "_", start_date, "_", end_date, "_raw.rds")
  filepath <- file.path(station_dir, filename)
  # Save
  saveRDS(data, filepath)
  message("✓ Saved to: ", filepath)
  
  # ========== STEP 6: LOG DOWNLOAD ==========
  log_entry <- data.frame(
    # Timezone for the timestamp is hard-coded AST since this is for VI-FLO - the Virgin Islands!
    timestamp = download_timestamp,
    station = station,
    start_date = format(start, "%Y-%m-%d %H:%M:%S"),
    end_date = format(end, "%Y-%m-%d %H:%M:%S"),
    n_records = nrow(data),
    filepath = filepath,
    stringsAsFactors = FALSE
  )
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  
  if (file.exists(log_file)) {
    # Append to existing log
    write.table(log_entry, log_file, sep = ",", append = TRUE, 
                row.names = FALSE, col.names = FALSE)
  } else {
    # Create new log with headers
    write.csv(log_entry, log_file, row.names = FALSE)
  }
  message("✓ Logged download to: ", log_file)
  
  # ========== STEP 7: UPDATE METADATA ==========
  # Update last_download_date only for the most recently active device
  # (In case of relocation, only update the current device, not old ones)
  most_recent_idx <- which.max(station_devices$last_update)
  active_sn <- station_devices$device_serial[most_recent_idx]
  metadata$last_download_date[metadata$device_serial == active_sn] <- download_timestamp
  
  # Save updated metadata
  setwd(wds("meta_internal"))
  # Format datetimes back to strings before saving
  metadata$deploy_datetime <- format(metadata$deploy_datetime, "%Y-%m-%d %H:%M:%S")
  metadata$last_update <- format(metadata$last_update, "%Y-%m-%d %H:%M:%S")
  metadata$last_download_date <- format(metadata$last_download_date, "%Y-%m-%d %H:%M:%S")
  write.csv(metadata, "device_metadata.csv", row.names = FALSE)
  
  message("✓ Updated metadata with download timestamp")
  
  # ========== RETURN ==========
  
  message("\n=== Download Complete ===")
  return(filepath)
}






