#' Interactive function to initialize port configuration for a new device deployment
#' Creates initial rows in zentra_ports.csv
#' @param device_serial Character. Device serial number to initialize
initialize_port_config <- function(device_serial = NULL) {
  
  cat("\n============================================\n")
  cat("  VI-FLO Engine - Initialize Port Config\n")
  cat("============================================\n\n")
  
  # Load metadata and ports
  metadata <- load_zentra_metadata()
  ports <- load_zentra_ports_data()
  
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
    stop("Device '", device_serial, "' not found in metadata! Add device first using add_device().", call. = FALSE)
  }
  
  # Check if port config already exists
  existing_ports <- ports[ports$device_serial == device_serial, ]
  if (nrow(existing_ports) > 0) {
    cat("⚠️  WARNING: Port configuration already exists for", device_serial, "\n")
    cat("Existing configuration:\n")
    active_ports <- existing_ports[is.na(existing_ports$valid_to), ]
    if (nrow(active_ports) > 0) {
      for (i in 1:nrow(active_ports)) {
        depth_str <- ifelse(is.na(active_ports$depth_cm[i]), "no depth", paste0(active_ports$depth_cm[i], "cm"))
        cat("  Port", active_ports$port[i], ":", active_ports$sensor_type[i], "-", depth_str, "\n")
      }
    }
    cat("\nTo update existing configuration, use update_port_config() instead.\n")
    cat("Continue anyway and ADD to existing config? (Y/N): ")
    continue_response <- toupper(trimws(readline()))
    if (continue_response != "Y" && continue_response != "1") {
      cat("❌ Cancelled\n")
      return(invisible(FALSE))
    }
  }
  
  # Get device info from metadata
  device_row <- metadata[metadata$device_serial == device_serial, ][1, ]
  deploy_datetime <- parse_datetime_flexible(device_row$deploy_datetime, device_row$timezone)
  
  cat("Initializing port configuration for:", device_serial, "\n")
  cat("Deployment datetime:", format(deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Determine total ports
  cat("How many ports does this device have? (default 6): ")
  total_ports_input <- trimws(readline())
  total_ports <- ifelse(total_ports_input == "", 6, as.numeric(total_ports_input))
  
  #### 2 - Port-by-port configuration
  new_config <- data.frame(
    port = integer(),
    sensor_type = character(),
    depth_cm = numeric(),
    stringsAsFactors = FALSE
  )
  
  for (port_num in 1:total_ports) {
    cat("\n--- PORT", port_num, "---\n")
    
    # Ask if port is occupied
    repeat {
      cat("Is this port occupied? (Y/N): ")
      occupied_response <- toupper(trimws(readline()))
      if (occupied_response == "1") occupied_response <- "Y"
      if (occupied_response == "2") occupied_response <- "N"
      
      if (occupied_response %in% c("Y", "N")) {
        break
      } else {
        cat("⚠️  Please enter Y or N\n")
      }
    }
    
    if (occupied_response == "N") {
      cat("✓ Port", port_num, "empty\n")
      next  # Skip this port
    }
    
    # Get sensor type
    repeat {
      # Get existing sensor types from ports data for menu
      existing_sensors <- sort(unique(ports$sensor_type[!is.na(ports$sensor_type)]))
      
      cat("Select sensor type:\n")
      for (i in seq_along(existing_sensors)) {
        cat("  ", i, ". ", existing_sensors[i], "\n", sep = "")
      }
      cat("  ", length(existing_sensors) + 1, ". other (specify)\n", sep = "")
      
      cat("\nEnter selection: ")
      sensor_input <- trimws(readline())
      
      if (grepl("^[0-9]+$", sensor_input)) {
        sensor_num <- as.numeric(sensor_input)
        if (sensor_num >= 1 && sensor_num <= length(existing_sensors)) {
          sensor_type <- existing_sensors[sensor_num]
          break
        } else if (sensor_num == length(existing_sensors) + 1) {
          cat("Enter sensor type: ")
          custom_sensor <- trimws(readline())
          if (custom_sensor != "") {
            sensor_type <- custom_sensor
            break
          } else {
            cat("⚠️  Sensor type cannot be empty\n")
          }
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        cat("⚠️  Please enter a number\n")
      }
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
      depth_cm <- as.numeric(depth_input)
    } else {
      depth_cm <- NA
    }
    
    # Add to config
    new_config <- rbind(new_config, data.frame(
      port = port_num,
      sensor_type = sensor_type,
      depth_cm = depth_cm,
      stringsAsFactors = FALSE
    ))
    
    depth_str <- ifelse(is.na(depth_cm), "no depth", paste0(depth_cm, "cm"))
    cat("✓ Port", port_num, ":", sensor_type, "-", depth_str, "\n")
  }
  
  #### 3 - Validate configuration
  # Check for duplicate port assignments
  if (any(duplicated(new_config$port))) {
    dup_ports <- new_config$port[duplicated(new_config$port)]
    stop("ERROR: Port(s) ", paste(dup_ports, collapse = ", "), 
         " assigned multiple sensors! Each port can only have one sensor.", call. = FALSE)
  }
  
  # Warn if all ports empty
  if (nrow(new_config) == 0) {
    cat("\n⚠️  WARNING: All ports are empty. This device will have no sensor data.\n")
    cat("Continue anyway? (Y/N): ")
    continue_empty <- toupper(trimws(readline()))
    if (continue_empty != "Y" && continue_empty != "1") {
      cat("❌ Cancelled\n")
      return(invisible(FALSE))
    }
  }
  
  #### 4 - Show summary
  cat("\n============================================\n")
  cat("INITIAL PORT CONFIGURATION\n")
  cat("Device:", device_serial, "\n")
  cat("Valid from:", format(deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n")
  cat("============================================\n\n")
  
  if (nrow(new_config) > 0) {
    for (i in 1:nrow(new_config)) {
      depth_str <- ifelse(is.na(new_config$depth_cm[i]), "no depth", paste0(new_config$depth_cm[i], "cm"))
      cat("Port", new_config$port[i], ":", new_config$sensor_type[i], "-", depth_str, "\n")
    }
  } else {
    cat("(All ports empty)\n")
  }
  
  cat("\n============================================\n")
  cat("Confirm this configuration? (Y/N): ")
  confirm <- toupper(trimws(readline()))
  if (confirm == "1") confirm <- "Y"
  if (confirm == "2") confirm <- "N"
  
  if (confirm != "Y") {
    cat("❌ Cancelled - no configuration created\n")
    return(invisible(FALSE))
  }
  
  #### 5 - Add to zentra_ports.csv
  if (nrow(new_config) > 0) {
    for (i in 1:nrow(new_config)) {
      new_row <- data.frame(
        device_serial = device_serial,
        port = new_config$port[i],
        sensor_type = new_config$sensor_type[i],
        depth_cm = new_config$depth_cm[i],
        valid_from = deploy_datetime,
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
  
  cat("\n✓ Port configuration initialized for", device_serial, "\n")
  cat("✓ Created", nrow(new_config), "port configuration(s)\n")
  
  invisible(TRUE)
}