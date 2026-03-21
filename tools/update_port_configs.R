#' Interactive function to update port configuration in zentra_ports.csv
#' Closes old configuration and creates new rows with changes
#' @param device_serial Character. Device serial number to update
update_port_config <- function(device_serial = NULL) {
  
  cat("\n============================================\n")
  cat("  VI-FLO Engine - Update Port Config\n")
  cat("============================================\n\n")
  
  # Load current ports and metadata
  ports <- load_zentra_ports_data()
  metadata <- load_zentra_metadata()
  
  #### 1 - Get device serial if not provided
  if (is.null(device_serial)) {
    cat("Enter device serial number (or 'q' to quit): ")
    device_serial <- trimws(readline())
    if (tolower(device_serial) == "q") {
      cat("❌ Cancelled\n")
      return(invisible(FALSE))
    }
  }
  
  # Verify device exists in metadata
  if (!device_serial %in% metadata$device_serial) {
    stop("Device '", device_serial, "' not found in metadata!", call. = FALSE)
  }
  
  #### 2 - Get current configuration (most recent for each port)
  device_ports <- ports[ports$device_serial == device_serial, ]
  
  if (nrow(device_ports) == 0) {
    cat("No existing port configuration found for", device_serial, "\n")
    cat("This appears to be a new device setup.\n\n")
    current_config <- data.frame(
      port = integer(),
      sensor_type = character(),
      depth_cm = numeric(),
      stringsAsFactors = FALSE
    )
  } else {
    # Get the most recent (currently active) configuration for each port
    # Active configs have valid_to = NA
    active_ports <- device_ports[is.na(device_ports$valid_to), ]
    
    if (nrow(active_ports) == 0) {
      cat("Warning: No active port configurations found (all have valid_to dates).\n")
      cat("Showing most recent configuration:\n\n")
      # Get most recent for each port
      current_config <- device_ports %>%
        group_by(port) %>%
        filter(valid_from == max(valid_from)) %>%
        ungroup() %>%
        select(port, sensor_type, depth_cm) %>%
        as.data.frame()
    } else {
      current_config <- active_ports[, c("port", "sensor_type", "depth_cm")]
    }
  }
  
  # Show current configuration
  if (nrow(current_config) > 0) {
    cat("Current active configuration for", device_serial, ":\n")
    for (i in 1:nrow(current_config)) {
      depth_str <- ifelse(is.na(current_config$depth_cm[i]), 
                          "no depth", 
                          paste0(current_config$depth_cm[i], "cm"))
      cat("  Port", current_config$port[i], ":", current_config$sensor_type[i], "-", depth_str, "\n")
    }
  }
  
  # Determine total ports (default 6 for Zentra)
  cat("\nHow many ports does this device have? (default 6): ")
  total_ports_input <- trimws(readline())
  total_ports <- ifelse(total_ports_input == "", 6, as.numeric(total_ports_input))
  
  #### 3 - Get change datetime
  cat("\n--- CONFIGURATION CHANGE TIMING ---\n")
  cat("When did this configuration change occur?\n")
  cat("(YYYY-MM-DD HH:MM:SS) or press Enter for now: ")
  change_datetime_input <- trimws(readline())
  
  if (change_datetime_input == "") {
    # Get timezone from metadata
    device_tz <- metadata$timezone[metadata$device_serial == device_serial][1]
    change_datetime <- as.POSIXct(Sys.time(), tz = device_tz)
  } else {
    device_tz <- metadata$timezone[metadata$device_serial == device_serial][1]
    change_datetime <- as.POSIXct(change_datetime_input, format = "%Y-%m-%d %H:%M:%S", tz = device_tz)
  }
  
  cat("✓ Configuration change datetime:", format(change_datetime, "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  #### 4 - Port-by-port configuration
  new_config <- data.frame(
    port = integer(),
    sensor_type = character(),
    depth_cm = numeric(),
    stringsAsFactors = FALSE
  )
  
  for (port_num in 1:total_ports) {
    cat("\n--- PORT", port_num, "---\n")
    
    # Get current setting for this port
    current_port <- current_config[current_config$port == port_num, ]
    has_current <- nrow(current_port) > 0
    
    if (has_current) {
      current_sensor <- current_port$sensor_type[1]
      current_depth <- current_port$depth_cm[1]
      depth_str <- ifelse(is.na(current_depth), "no depth", paste0(current_depth, "cm"))
      cat("Current:", current_sensor, "-", depth_str, "\n")
    } else {
      cat("Current: (empty)\n")
    }
    
    # Ask if changing
    repeat {
      cat("Change this port? (Y/N): ")
      change_response <- toupper(trimws(readline()))
      if (change_response == "1") change_response <- "Y"
      if (change_response == "2") change_response <- "N"
      
      if (change_response %in% c("Y", "N")) {
        break
      } else {
        cat("⚠️  Please enter Y or N\n")
      }
    }
    
    if (change_response == "N") {
      # Keep current config if it exists
      if (has_current) {
        new_config <- rbind(new_config, data.frame(
          port = port_num,
          sensor_type = current_sensor,
          depth_cm = current_depth,
          stringsAsFactors = FALSE
        ))
      }
      # If empty and no change, just skip (stays empty)
      next
    }
    
    # Changing this port - get new configuration
    cat("\nConfiguring port", port_num, ":\n")
    
    # Get sensor type
    repeat {
      existing_sensors <- sort(unique(ports$sensor_type[!is.na(ports$sensor_type)]))
      cat("Select sensor type:\n")
      for (i in seq_along(existing_sensors)) {
        cat("  ", i, ". ", existing_sensors[i], "\n", sep = "")
      }
      cat("  ", length(existing_sensors) + 1, ". other (specify)\n", sep = "")
      cat("  ", length(existing_sensors) + 2, ". empty (remove sensor)\n", sep = "")
      
      cat("\nEnter selection: ")
      sensor_input <- trimws(readline())
      
      if (grepl("^[0-9]+$", sensor_input)) {
        sensor_num <- as.numeric(sensor_input)
        if (sensor_num >= 1 && sensor_num <= length(existing_sensors)) {
          new_sensor <- existing_sensors[sensor_num]
          break
        } else if (sensor_num == length(existing_sensors) + 1) {
          cat("Enter sensor type: ")
          custom_sensor <- trimws(readline())
          if (custom_sensor != "") {
            new_sensor <- custom_sensor
            break
          } else {
            cat("⚠️  Sensor type cannot be empty\n")
          }
        } else if (sensor_num == length(existing_sensors) + 2) {
          new_sensor <- NULL  # Empty port
          break
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        cat("⚠️  Please enter a number\n")
      }
    }
    
    # If empty, skip depth question
    if (is.null(new_sensor)) {
      cat("✓ Port", port_num, "set to empty\n")
      next  # Don't add to new_config (empty port)
    }
    
    # Ask about depth
    repeat {
      cat("\nDoes this sensor have an installation depth? (Y/N): ")
      has_depth_response <- toupper(trimws(readline()))
      if (has_depth_response == "1") has_depth_response <- "Y"
      if (has_depth_response == "2") has_depth_response <- "N"
      
      if (has_depth_response %in% c("Y", "N")) {
        break
      } else {
        cat("⚠️  Please enter Y or N\n")
      }
    }
    
    if (has_depth_response == "Y") {
      cat("Enter depth (cm): ")
      depth_input <- trimws(readline())
      new_depth <- as.numeric(depth_input)
    } else {
      new_depth <- NA
    }
    
    # Add to new config
    new_config <- rbind(new_config, data.frame(
      port = port_num,
      sensor_type = new_sensor,
      depth_cm = new_depth,
      stringsAsFactors = FALSE
    ))
    
    depth_str <- ifelse(is.na(new_depth), "no depth", paste0(new_depth, "cm"))
    cat("✓ Port", port_num, ":", new_sensor, "-", depth_str, "\n")
  }
  
  #### 5 - Validate configuration
  # Check for duplicate port assignments
  if (any(duplicated(new_config$port))) {
    dup_ports <- new_config$port[duplicated(new_config$port)]
    stop("ERROR: Port(s) ", paste(dup_ports, collapse = ", "), 
         " assigned multiple sensors! Each port can only have one sensor.", call. = FALSE)
  }
  
  #### 6 - Show summary
  cat("\n============================================\n")
  cat("CONFIGURATION CHANGE SUMMARY\n")
  cat("Device:", device_serial, "\n")
  cat("Change datetime:", format(change_datetime, "%Y-%m-%d %H:%M:%S"), "\n")
  cat("============================================\n\n")
  
  # Show changes
  changes_made <- FALSE
  for (port_num in 1:total_ports) {
    old_port <- current_config[current_config$port == port_num, ]
    new_port <- new_config[new_config$port == port_num, ]
    
    has_old <- nrow(old_port) > 0
    has_new <- nrow(new_port) > 0
    
    if (!has_old && !has_new) {
      # Was empty, still empty
      cat("Port", port_num, ": (empty) - no change\n")
    } else if (has_old && !has_new) {
      # Sensor removed
      old_depth_str <- ifelse(is.na(old_port$depth_cm[1]), "no depth", paste0(old_port$depth_cm[1], "cm"))
      cat("Port", port_num, ":", old_port$sensor_type[1], old_depth_str, "→ (empty) - REMOVED\n")
      changes_made <- TRUE
    } else if (!has_old && has_new) {
      # Sensor added
      new_depth_str <- ifelse(is.na(new_port$depth_cm[1]), "no depth", paste0(new_port$depth_cm[1], "cm"))
      cat("Port", port_num, ": (empty) →", new_port$sensor_type[1], new_depth_str, "- ADDED\n")
      changes_made <- TRUE
    } else {
      # Both exist - check if changed
      old_depth_str <- ifelse(is.na(old_port$depth_cm[1]), "no depth", paste0(old_port$depth_cm[1], "cm"))
      new_depth_str <- ifelse(is.na(new_port$depth_cm[1]), "no depth", paste0(new_port$depth_cm[1], "cm"))
      
      if (old_port$sensor_type[1] != new_port$sensor_type[1] || 
          !identical(old_port$depth_cm[1], new_port$depth_cm[1])) {
        cat("Port", port_num, ":", old_port$sensor_type[1], old_depth_str, "→", 
            new_port$sensor_type[1], new_depth_str, "- CHANGED\n")
        changes_made <- TRUE
      } else {
        cat("Port", port_num, ":", new_port$sensor_type[1], new_depth_str, "- no change\n")
      }
    }
  }
  
  # Warning for all-empty configuration
  if (nrow(new_config) == 0) {
    cat("\n⚠️  WARNING: All ports are empty. This device will have no sensor data.\n")
  }
  
  if (!changes_made) {
    cat("\n⚠️  No changes detected. Configuration unchanged.\n")
    cat("Cancel operation? (Y/N): ")
    cancel <- toupper(trimws(readline()))
    if (cancel == "Y" || cancel == "1") {
      cat("❌ Cancelled\n")
      return(invisible(FALSE))
    }
  }
  
  cat("\n============================================\n")
  cat("Confirm these changes? (Y/N): ")
  confirm <- toupper(trimws(readline()))
  if (confirm == "1") confirm <- "Y"
  if (confirm == "2") confirm <- "N"
  
  if (confirm != "Y") {
    cat("❌ Cancelled - no changes made\n")
    return(invisible(FALSE))
  }
  
  #### 7 - Update zentra_ports.csv
  # Close all currently active configurations
  ports$valid_to[ports$device_serial == device_serial & is.na(ports$valid_to)] <- change_datetime
  
  # Add new configuration rows
  if (nrow(new_config) > 0) {
    for (i in 1:nrow(new_config)) {
      new_row <- data.frame(
        device_serial = device_serial,
        port = new_config$port[i],
        sensor_type = new_config$sensor_type[i],
        depth_cm = new_config$depth_cm[i],
        valid_from = change_datetime,
        valid_to = NA,
        stringsAsFactors = FALSE
      )
      ports <- rbind(ports, new_row)
    }
  }
  
  # Save updated ports
  setwd(wds("meta_internal"))
  ports$valid_from <- format_datetime_safe(ports$valid_from)
  ports$valid_to <- format_datetime_safe(ports$valid_to)
  
  write.csv(ports, "zentra_ports.csv", row.names = FALSE)
  
  cat("\n✓ Port configuration updated for", device_serial, "\n")
  cat("✓ Closed", sum(!is.na(ports$valid_to) & ports$device_serial == device_serial & 
                        ports$valid_to == format(change_datetime, "%Y-%m-%d %H:%M:%S")), "old configuration(s)\n")
  cat("✓ Created", nrow(new_config), "new configuration(s)\n")
  
  invisible(TRUE)
}