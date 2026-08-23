# API functions
# Functions for downloading data from various APIs
# Dependencies: zentracloud, remotes

######################                SETUP              ######################

#' Load zentracloud package or install if needed
#' @param token_name Character. Environment variable name from api_tokens.csv (e.g., "ZENTRACLOUD_TOKEN_DEFAULT")
setup_zentracloud <- function(token_name) {
  if (!require("zentracloud", quietly = TRUE)) {
    if (!require("remotes", quietly = TRUE)) {
      install.packages("remotes")
    }
    message("Installing zentracloud package from GitLab...")
    tryCatch({
      remotes::install_git("https://gitlab.com/meter-group-inc/pubpackages/zentracloud")
      library(zentracloud)
    }, error = function(e) {
      if (grepl("Git does not seem to be installed", e$message)) {
        stop("Git is not installed or not found in system PATH.\n",
             "Please install Git from https://git-scm.com/downloads\n",
             "After installing, restart R and try again.", call. = FALSE)
      } else {
        stop("Failed to install zentracloud: ", e$message, call. = FALSE)
      }
    })
  }
  
  # Get token from environment using exact name from CSV
  token <- Sys.getenv(token_name)
  if (token == "") {
    stop("Token not found: ", token_name, 
         "\nCheck api_tokens.csv and run set_api_tokens.py", call. = FALSE)
  }
  # Configure zentracloud
  setZentracloudOptions(token = token, domain = "default")
  invisible(TRUE)
}

######################       ZENTRA STATION DOWNLOAD      ######################

#' Safe wrapper for downloading Zentra station data with validation and storage
#' Downloads station data with automatic validation, date trimming, duplicate prevention,
#' and organized file storage. Use this instead of download_zentra_station() for production workflows.
#' Requires setup_functions.R
#' @param station Character. Station ID code from metadata e.g. "sr1_weather"
#' @param start Character. Start datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param end Character. End datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param all Logical. If TRUE, downloads entire station history (default FALSE)
#' @return Character. File path where data was saved
#' @details
#' This function performs the following steps:
#' 1. Validates metadata using validate_zentra_metadata()
#' 2. Checks whether download is approved for the station
#' 3. Trims requested dates to available range (unless strict_dates = TRUE)
#' 4. Backs up metadata and downloads data using download_zentra_station()
#' 5. Saves to organized directory structure: /raw/internal/{station}/
#' 6. Logs download to download_log.csv and alters device_metadata.csv
safe_download_zentra_station <- function(station, start = NULL, end = NULL, all = FALSE) {
  # Load in metadata functions required for this call
  load_functions("metadata")
  metadata <- load_zentra_metadata()
  ports <- load_zentra_ports_data()
  
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
      if (original_end < earliest_deploy){
        stop("Dates requested are not possible - end time is before station's first deployment!")
      }
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
  # type <- sub(".*_", "", station)
  type <- metadata$station_type[metadata$station_id==station][1]
  station_dir <- wds(paste0("internal_raw_", type))
  if (!dir.exists(station_dir)) {
    dir.create(station_dir, recursive = TRUE)
    message("Created directory: ", station_dir)
  }
  # Generate filename via the shared helper, so the automated and manual
  # ingest paths cannot drift apart. See file_naming_functions.R.
  if (!exists("build_raw_filename")) load_functions("file_naming")
  filename <- build_raw_filename(station, start, end, ext = "rds")
  filepath <- file.path(station_dir, filename)

  # Warn if this range overlaps data already archived for this station.
  # Deliberately non-blocking: boundary-day overlap is normal.
  check_raw_overlap(station, start, end, dir = station_dir)
  # Save
  saveRDS(data, filepath)
  message("✓ Saved to: ", filepath)
  
  # ========== STEP 6: LOG DOWNLOAD ==========
  # Create relative filepath for logging
  filepath_relative <- sub(paste0("^", Sys.getenv("VI_FLO_DATA_ROOT"), "/?"), "", filepath)
  filepath_relative <- sub("^/", "", filepath_relative)  # Remove leading slash if present
  
  log_entry <- data.frame(
    # Timezone for the timestamp is hard-coded AST since this is for VI-FLO - the Virgin Islands!
    timestamp = download_timestamp,
    station = station,
    start_date = format(start, "%Y-%m-%d %H:%M:%S"),
    end_date = format(end, "%Y-%m-%d %H:%M:%S"),
    n_records = nrow(data),
    filepath = filepath_relative,
    # "automatic" = pulled through the Zentra API by this function.
    # "manual" = offloaded by hand in the field; written by the local
    # ingest workflow. Column order must match download_log.csv, since
    # the append below uses col.names = FALSE.
    download_type = "automatic",
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
  # Update last_download_date for all devices whose deployment period overlaps download range
  # (Handles relocations, device swaps, and any scenario where multiple deployments exist)
  for (i in 1:nrow(station_devices)) {
    device <- station_devices[i, ]
    # Check if this device's active period overlaps with download period
    device_start <- device$deploy_datetime
    device_end <- device$last_update
    
    # Does this device's period overlap with [start, end]?
    if (device_start <= end && device_end >= start) {
      # Yes - we downloaded data from this device/deployment
      metadata$last_download_date[metadata$unique_id == device$unique_id] <- datetime_at_station
    }
  }
  # Save updated metadata
  setwd(wds("meta_internal"))
  # Format datetimes back to strings before saving (handles NAs properly)
  metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
  metadata$last_update <- format_datetime_safe(metadata$last_update)
  metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
  
  write.csv(metadata, "device_metadata.csv", row.names = FALSE)
  message("✓ Updated metadata with download timestamp")
  
  # ========== RETURN ==========
  
  message("\n=== Download Complete ===")
  return(filepath)
}

#' Validates Zentra metadata before attempting to download station data
#' Checks for technical issues that would cause download_zentra_station() to fail
#' @param station Character. Station ID code from metadata e.g. "sr1_weather"
#' @param metadata Data.frame. Output from load_zentra_metadata()
#' @param ports Data.frame. Output from load_zentra_ports_data()
#' @return Logical. TRUE if download can proceed, FALSE if critical issues found
validate_zentra_metadata <- function(station, metadata, ports){
  # ========== STATION-LEVEL CHECKS ==========
  # Check station exists
  if (!station %in% metadata$station_id) {
    message("ERROR: Station '", station, "' not found in metadata")
    return(FALSE)
  }
  # Get devices for this station
  station_devices <- metadata[metadata$station_id == station, ]
  # Check all devices have same station_type
  if (length(unique(station_devices$station_type)) > 1) {
    message("ERROR: Station '", station, "' has multiple station_types: ",
            paste(unique(station_devices$station_type), collapse = ", "))
    return(FALSE)
  }
  
  # ========== DEVICE-LEVEL CHECKS ==========
  for (i in 1:nrow(station_devices)) {
    device <- station_devices[i, ]
    sn <- device$device_serial
    # Check required fields present
    if (is.na(sn) || sn == "") {
      message("ERROR: Row ", i, " in metadata: missing device_serial")
      return(FALSE)
    }
    if (is.na(device$deploy_datetime)) {
      message("ERROR: Device ", sn, ": missing deploy_datetime")
      return(FALSE)
    }
    if (is.na(device$last_update)) {
      message("ERROR: Device ", sn, ": missing last_update")
      return(FALSE)
    }
    if (is.na(device$timezone) || device$timezone == "") {
      message("ERROR: Device ", sn, ": missing timezone")
      return(FALSE)
    }
    # Check date logic
    if (device$deploy_datetime >= device$last_update) {
      message("ERROR: Device ", sn, ": deploy_datetime (",
              format(device$deploy_datetime, "%Y-%m-%d %H:%M:%S"),
              ") must be before last_update (",
              format(device$last_update, "%Y-%m-%d %H:%M:%S"), ")")
      return(FALSE)
    }
    # Check device has port configurations
    device_ports <- ports[ports$sn == sn, ]
    if (nrow(device_ports) == 0) {
      message("ERROR: Device ", sn, " has no port configurations")
      return(FALSE)
    }
    
    # ========== PORT CONFIGURATION CHECKS FOR THIS DEVICE ==========
    port_nums <- unique(device_ports$port)
    for (port_num in port_nums) {
      port_configs <- device_ports[device_ports$port == port_num, ]
      # Remove never-used ports (both dates NA)
      valid_configs <- port_configs[!(is.na(port_configs$valid_from) & 
                                        is.na(port_configs$valid_to)), ]
      if (nrow(valid_configs) == 0) next  # Port was never used, skip
      # Check each config has required fields
      for (j in 1:nrow(valid_configs)) {
        config <- valid_configs[j, ]
        if (is.na(config$valid_from)) {
          message("ERROR: Device ", sn, " port ", port_num, ": missing valid_from")
          return(FALSE)
        }
        # Check date logic
        if (!is.na(config$valid_to) && config$valid_from >= config$valid_to) {
          message("ERROR: Device ", sn, " port ", port_num, 
                  ": valid_from (", format(config$valid_from, "%Y-%m-%d %H:%M:%S"),
                  ") must be before valid_to (", format(config$valid_to, "%Y-%m-%d %H:%M:%S"), ")")
          return(FALSE)
        }
      }
      # Check for overlapping configs (if multiple configs exist)
      if (nrow(valid_configs) > 1) {
        valid_configs <- valid_configs[order(valid_configs$valid_from), ]
        for (j in 1:(nrow(valid_configs) - 1)) {
          current <- valid_configs[j, ]
          next_config <- valid_configs[j + 1, ]
          # If current has no end date, it's still active - shouldn't have another config
          if (is.na(current$valid_to)) {
            message("ERROR: Device ", sn, " port ", port_num, 
                    ": current config has no end date but another config exists (overlap)")
            return(FALSE)
          }
          # Check if next config starts before current ends
          if (!is.na(next_config$valid_from) && next_config$valid_from < current$valid_to) {
            message("ERROR: Device ", sn, " port ", port_num, 
                    ": overlapping configurations - next starts at ",
                    format(next_config$valid_from, "%Y-%m-%d %H:%M:%S"),
                    " but current doesn't end until ",
                    format(current$valid_to, "%Y-%m-%d %H:%M:%S"))
            return(FALSE)
          }
        }
      }
    }
  }
  # All checks passed
  return(TRUE)
}

#' Downloads Zentra data by API based on station ID
#' Requires zentracloud package. Run setup_zentracloud() with API token first!
#' Helper functions: download_zentra_device()
#' @param station Character. Station ID code from metadata e.g. sr1_weather
#' @param metadata Data.frame. device_metadata.csv in data root. Use load_zentra_metadata() to get!
#'                 Must include: $station_id, $station_type, $deploy_datetime, $last_update, $device_serial, $timezone
#' @param ports Data.frame. zentra_ports.csv in data root. Use load_zentra_ports_data() to get!
#'              Must include: $sn, $port, $type, $sensor, $depth_cm, $valid_from, $valid_to
#' @param start Character. Start datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param end Character. End datetime string "YYYY-MM-DD HH:MM:SS" (ignored if all = TRUE)
#' @param all Logical. If TRUE, downloads entire station history (default FALSE)
#' @return Data.frame with collated data from one station over many devices
download_zentra_station <- function(station, metadata, ports, start = NULL, end = NULL, all = FALSE){
  # Look at the station ID alone
  df <- metadata[metadata$station_id == station,]
  # Conversion to POSIXct and set timezone
  timezone <- df$timezone[1]
  
  as.POSIXct(start, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
  
  start <- as.POSIXct(start, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
  end <- as.POSIXct(end, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
  # Double check this is a single type of data
  if (length(unique(df$station_type)) > 1) {
    stop("Station has multiple station_types - metadata issue")
  }
  type <- df$station_type[1]
  
  if (all) {
    # Set earliest/latest possible dates
    start <- min(df$deploy_datetime)
    end <- max(df$last_update)
  } else {
    # Check that start/end are provided
    if (is.null(start) | is.null(end)) {
      stop("Must provide start and end dates, or set all = TRUE")
    }
  }
  # Check if dates are in bounds by metadata
  if (start < min(df$deploy_datetime) | end > max(df$last_update)){
    stop("Provided dates are outside the deployment period for the station")
  }
  
  # Initialize list to hold processed device data
  device_dfs <- list()
  # Loop over each device in the station
  for (i in 1:nrow(df)) {
    # Set these for this unique ID - deals with relocation and device switches for later
    sn <- df$device_serial[i]
    lat <- df$lat[i]
    lon <- df$lon[i]
    # Determine device-specific start and end, clipped to requested period
    device_start <- max(df$deploy_datetime[i], start)
    device_end   <- min(df$last_update[i], end)
    # Skip device if its active period does not overlap requested window
    if (device_start > device_end) next
    # Download raw device data for this period
    raw_device <- download_zentra_device(sn, format(device_start, "%Y-%m-%d %H:%M:%S"), format(device_end, "%Y-%m-%d %H:%M:%S"))
    # Process raw device data into structured dataframe
    processed_device <- zentra_port_configure(sn, metadata, ports, raw_device)
    # IMPORTANT: Here we deal with RELOCATION and DEVICE REPLACEMENT by appending lat/lon and serial number
    processed_device$device_serial <- sn
    processed_device$lat <- lat
    processed_device$lon <- lon
    # Append the processed device dataframe to our list
    device_dfs[[length(device_dfs) + 1]] <- processed_device
  }
  # Combine all device outputs into a single dataframe
  if (length(device_dfs) == 0) {
    result <- data.frame()  # No devices contributed data
  } else {
    result <- do.call(rbind, device_dfs)
    # Ensure chronological order
    result <- result[order(result$datetime), ]
  }
  # Order columns logically
  front_cols <- c("datetime", "device_serial", "lat", "lon")
  result <- result[, c(front_cols, setdiff(names(result), front_cols))]
  
  return(result)
}

#' Downloads data from a Zentra logger
#' Requires zentracloud package. Run setup_zentracloud() with API token first!
#' Helper functions: extract_zentra_port()
#' @param sn Character. Device serial number e.g. "z6-13366"
#' @param start Character. Start datetime string "YYYY-MM-DD HH:MM:SS"
#' @param end Character. End datetime string "YYYY-MM-DD HH:MM:SS"
#' @return Data.frame with datetime and all port data
download_zentra_device <- function(sn, start, end){
  # Download full Zentra readout
  readout <- getReadings(device_sn = sn, start_time = start, end_time = end)
  # Gather the data from each port, initialize with port 1 first
  n_ports <- length(readout)
  combined_data <- extract_zentra_port(readout, 1)
  names(combined_data)[-1] <- paste0("port1.", names(combined_data)[-1])
  # Loop through remaining ports (only if > 1)
  if (n_ports > 1) {
    for (i in 2:n_ports) {
      port_data <- extract_zentra_port(readout, i)
      names(port_data)[-1] <- paste0("port", i, ".", names(port_data)[-1])
      # Merge on datetime
      combined_data <- merge(combined_data, port_data, by = "datetime", all = TRUE)
    }
  }
  return(combined_data)
}

#' Extracts all data from a single port in Zentra download
#' Applies error flags (sets value to NA where flag is TRUE)
#' @param readout List. Raw readout from Zentra download
#' @param port_num Numeric. Port number to extract, i.e. 1-6
#' @return Data.frame with $datetime and all variables for this port (wide format)
extract_zentra_port <- function(readout, port_num){
  # Get port data
  port_data <- readout[grep(paste0("_port", port_num, "$"), names(readout))][[1]]
  # Convert to datetime with correct timezone
  tz_hours <- unique(port_data$tz_offset)[1] / 3600
  tz_string <- sprintf("Etc/GMT%+d", -tz_hours)
  port_data$datetime <- as.POSIXct(port_data$timestamp_utc, 
                                   origin = "1970-01-01",
                                   tz = tz_string)
  # Find all .value columns
  value_cols <- grep("\\.value$", names(port_data), value = TRUE)
  # For each value column, apply flag logic
  for (val_col in value_cols) {
    # Corresponding flag column
    flag_col <- sub("\\.value$", ".error_flag", val_col)
    
    if (flag_col %in% names(port_data)) {
      # Set value to NA where flag is TRUE
      port_data[[val_col]][port_data[[flag_col]] == TRUE] <- NA
    }
  }
  # Keep datetime and all .value columns (drop flags, timestamps, etc.)
  keep_cols <- c("datetime", value_cols)
  port_data <- port_data[, keep_cols]
  return(port_data)
}

#' Configures raw Zentra download output based on port metadata
#' Translates port-based columns to meaningful variable names
#' @param sn Character. Device serial number e.g. "z6-13366"
#' @param metadata Data.frame. device_metadata.csv in data root. Must include: $timezone
#' @param ports Data.frame. Port configuration history (zentra_ports.csv)
#' @param raw_device Data.frame. Raw output from download_zentra_device()
#' @return Data.frame with meaningful column names (vwc_10cm, air_temp, etc.)
zentra_port_configure <- function(sn, metadata, ports, raw_device){
  # Glean timezone
  timezone <- metadata$timezone[metadata$device_serial==sn][1]
  # Format ports dates
  ports$valid_from <- as.POSIXct(ports$valid_from, tz = timezone)
  ports$valid_to <- as.POSIXct(ports$valid_to, tz = timezone)
  # Format inbound data datetime
  raw_device$datetime <- as.POSIXct(raw_device$datetime, tz = timezone)
  # Glean start and end datetimes
  start <- raw_device$datetime[1]
  end <- raw_device$datetime[nrow(raw_device)]
  # Filter to just this device's ports
  device_ports <- ports[ports$sn == sn, ]
  # Get all unique port numbers for this device
  port_nums <- unique(device_ports$port)
  # Will build up the final dataframe column by column
  result <- data.frame(datetime = raw_device$datetime)
  # Process each port
  for (port_num in port_nums) {
    # Get all configurations for this port
    port_configs <- device_ports[device_ports$port == port_num, ]
    # Drop port if never used (both valid_from and valid_to are NA for ALL configs)
    if (all(is.na(port_configs$valid_from)) & all(is.na(port_configs$valid_to))) {
      next  # Skip this port entirely
    }
    # Find which configs overlap with our download period
    # A config overlaps if: it started before our end AND (hasn't ended OR ended after our start)
    overlapping <- port_configs[
      !is.na(port_configs$valid_from) &  # Must have a start date
        port_configs$valid_from <= end & 
        (is.na(port_configs$valid_to) | port_configs$valid_to >= start),
    ]
    # Skip this port if no valid configurations during download period
    if (nrow(overlapping) == 0) {
      next
    }
    # Sort configs by time
    overlapping <- overlapping[order(overlapping$valid_from), ]
    # Process each configuration period for this port
    for (j in 1:nrow(overlapping)) {
      config <- overlapping[j, ]
      # Determine time bounds for this config
      config_start <- max(config$valid_from, start)
      config_end <- if (is.na(config$valid_to)) end else min(config$valid_to, end)
      # Find rows in the data that fall within this config period
      in_period <- raw_device$datetime >= config_start & raw_device$datetime <= config_end
      # Extract just the data for this time period
      period_data <- raw_device[in_period, ]
      # Route to sensor-specific helper function based on sensor name
      sensor_name <- config$sensor
      processed_cols <- NULL
      
      # ========== DEVICE-SPECIFIC HELPER FUNCTIONS ==========
      # Add new device types here as needed
      if (sensor_name == "TEROS 10") {
        processed_cols <- configure_teros(period_data, config)
      } else if (sensor_name == "ATMOS 41") {
        processed_cols <- configure_atmos(period_data, config)
      } else if (sensor_name == "ECRN-50") {
        stop("ECRN-50 data extraction tool still not developed.")
        # TO ADD NEW SENSOR TYPE:
        # Write a new function if needed for the sensor type
        # } else if (sensor_name == "NEW_DEVICE_NAME") {
        #   processed_cols <- configure_new_device(period_data, config)
      } else {
        # Unknown sensor - use generic fallback
        stop(paste("Unknown sensor type:", sensor_name, "- check for typos or configure new sensor style!"))
      }
      # ======================================================
      
      # Add processed columns to result
      if (!is.null(processed_cols)) {
        # Merge on datetime, filling in values only for this period
        for (col_name in names(processed_cols)) {
          if (!col_name %in% names(result)) {
            # Create new column filled with NAs
            result[[col_name]] <- NA
          }
          # Fill in values for this time period
          result[[col_name]][in_period] <- processed_cols[[col_name]]
        }
      }
    }
  }
  return(result)
}

#' Configure TEROS soil moisture sensor data
#' @param period_data Data.frame. Data for this time period only
#'                    Internal product of zentra_port_configure()
#' @param config Data.frame row. Single config record with device, depth_cm, etc.
#'               Effectively a one-row subset of zentra_ports.csv
#' @return Data.frame with VWC column(s)
configure_teros <- function(period_data, config) {
  # We can add logic if needed to deal with different TEROS sensor types
  
  port_num <- config$port[1]
  # Find the water content column name for this port for a TEROS 10
  raw_col <- grep(paste0("port", port_num, ".*water.*content.*value"), 
                  names(period_data), value = TRUE, ignore.case = TRUE)[1]
  # If we could not find the column in the data, move on
  if (is.na(raw_col) || !raw_col %in% names(period_data)) {
    return(NULL)
  }
  # Generate new column name
  col_name <- paste0("vwc_", config$depth_cm, "cm")
  # Return data.frame with single column
  result <- data.frame(period_data[[raw_col]])
  names(result) <- col_name
  return(result)
}

#' Configure ATMOS weather station data, renames columns
#' @param period_data Data.frame. Data for this time period only
#'                    Internal product of zentra_port_configure()
#' @param config Data.frame row. Single config record
#'               Effectively a one-row subset of zentra_ports.csv
#' @return Data.frame with multiple weather variable columns
configure_atmos <- function(period_data, config) {
  # We can add logic if needed to deal with different ATMOS sensor types
  port_num <- config$port[1]
  # Find all columns for this port
  raw_cols <- grep(paste0("^port", port_num, "\\..*\\.value$"), 
                   names(period_data), value = TRUE, ignore.case = TRUE)
  # Nothing to do here if we don't have any columns matching these names
  if (length(raw_cols) == 0) return(NULL)
  # Extract the middle part of the column name: strip "portX." and ".value"
  new_names <- sub(paste0("^port", port_num, "\\.(.*)\\.value$"), "\\1", raw_cols)
  # Select the columns and rename them
  result <- period_data[, raw_cols, drop = FALSE]
  names(result) <- new_names
  
  return(result)
}

######################           ZENTRA METADATA          ######################

#' Pulls current metadata for Zentra ZL6 logger
#' Requires zentracloud package. Run setup_zentracloud() with API token first!
#' Helper functions: consolidate_locss()
#' @param sn Character. Device serial number e.g. "z6-13366"
#' @return List containing: logging interval (minutes), subscription expiry date, location moves, and current device_name
get_zentra_metadata <- function(sn){
  meta <- queryDeviceSettings(sn)
  interval <- meta$device$measurement_settings[1,2] / 60 # Check the logging interval, minutes
  expiry <- as.Date(meta$device$subscription_expiry) # Get current subscription expiration date
  locs <- meta$device$locations
  locs <- consolidate_locs(locs, 0.001)
  history <- meta$device$installation_metadata
  results <- list(interval = interval, expiry = expiry, locs = locs, current_name = history$device_name[1])
  return(results)
}

#' Checks on the last time of update for a Zentra device
#' Requires zentracloud package. Run setup_zentracloud() with API token first!
#' @param sn Character. Device serial number e.g. "z6-13366"
#' @param metadata Data.frame. device_metadata.csv in data root. Must include $last_update, $device_serial
#' @return POSIXct object of the datetime of latest reading from the device
query_last_zentra_update <- function(sn, metadata){
  start <- as.character(metadata$last_update[metadata$device_serial == sn])
  latest <- getReadings(sn, start, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), 
                        force_api = TRUE, include_depth = TRUE)
  # Get latest timestamp from each port
  port_times <- sapply(latest, function(port_data) {
    if (nrow(port_data) > 0) {
      max(port_data$datetime)
    } else {
      as.POSIXct(NA)
    }
  })
  # Return the latest across all ports
  return(as.POSIXct(max(port_times, na.rm = TRUE)))
}

#' Function to detect real moves and consolidate locations
#' If device detects a move more than threshold in lat/lon degrees it logs the date
#' @param locs Data.frame. Expected input from get_zentra_metadata
#' @param threshold Numeric. Typically 0.001 in degrees of lat/lon 
#' @return Data.frame with $date_moved and average $latitude and $longitude of the new location
consolidate_locs <- function(locs, threshold = 0.001) {
  locs$valid_since <- as.Date(locs$valid_since)
  # Sort by time (oldest first)
  locs <- locs[order(locs$valid_since), ]
  locs <- locs[,c("valid_since", "latitude", "longitude")]
  # Initialize grouping
  locs$location_group <- 1
  current_group <- 1
  # Detect moves
  for (i in 2:nrow(locs)) {
    lat_diff <- abs(locs$latitude[i] - locs$latitude[i-1])
    lon_diff <- abs(locs$longitude[i] - locs$longitude[i-1])
    # If moved beyond threshold, start new group
    if (lat_diff > threshold | lon_diff > threshold) {
      current_group <- current_group + 1
    }
    locs$location_group[i] <- current_group
  }
  # Consolidate each group
  consolidated <- do.call(rbind, lapply(split(locs, locs$location_group), function(group) {
    data.frame(
      date_moved = min(group$valid_since),   # Earliest time
      latitude = mean(group$latitude),        # Average lat
      longitude = mean(group$longitude)       # Average lon
    )
  }))
  return(consolidated)
}



