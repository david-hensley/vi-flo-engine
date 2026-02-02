# log_maintenance_interactive.R
# Interactive station/device maintenance logging for VI-FLO Engine
# Run with: Rscript log_maintenance_interactive.R
# Or double-click log_maintenance.bat

# Source required functions
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
load_functions("metadata")

# Main interactive function
log_maintenance_interactive <- function() {
  
  # Loop to allow multiple entries
  repeat {
    cat("\n============================================\n")
    cat("  VI-FLO Engine - Maintenance Logger\n")
    cat("============================================\n\n")
    # Load metadata to show available stations
    metadata <- load_zentra_metadata()
    
    #### 1 - Prompt for field visit date
    cat("When did you visit the field? (YYYY-MM-DD)\n")
    cat("Or simply press Enter for today: ")
    field_visit_date <- readline()
    if (field_visit_date == "") {
      field_visit_date <- as.character(Sys.Date())
    }
    cat("✓ Field visit date:", field_visit_date, "\n\n")
    
    #### 2 - Prompt for station
    repeat {
      cat("\nAvailable stations:\n")
      stations <- sort(unique(metadata$station_id))
      for (i in seq_along(stations)) {
        # Get full site name for this station
        site_full <- metadata$site_full[metadata$station_id == stations[i]][1]
        cat("  ", i, ". ", stations[i], " (", site_full, ")\n", sep = "")
      }
      cat("\nEnter station number or ID (or 'q' to quit): ")
      station_input <- trimws(readline())
      # Check for quit
      if (tolower(station_input) == "q") {
        cat("❌ Exiting maintenance logger\n")
        return(invisible(FALSE))
      }
      # Parse station input whether numbers or actual station name
      if (grepl("^[0-9]+$", station_input)) {
        station_num <- as.numeric(station_input)
        if (station_num >= 1 && station_num <= length(stations)) {
          station_id <- stations[station_num]
          break  # Valid selection, exit loop
        } else {
          cat("⚠️  Invalid number. Please enter 1-", length(stations), "\n", sep = "")
        }
      } else {
        if (station_input %in% metadata$station_id) {
          station_id <- station_input
          break  # Valid station ID, exit loop
        } else {
          cat("⚠️  Station '", station_input, "' not found. Try again.\n", sep = "")
        }
      }
    }
    
    #### 3 - Get station info
    station_data <- metadata[metadata$station_id == station_id, ]
    station_type <- station_data$station_type[1]
    cat("✓ Station:", station_id, "(", station_type, ")\n")
    
    #### 4 - Get device info
    repeat {
      cat("\nDevices at this station:\n")
      for (i in 1:nrow(station_data)) {
        cat("  ", i, ". ", station_data$device_serial[i], "\n", sep = "")
      }
      cat("\nEnter device number or serial (or 'q' to quit): ")
      device_input <- trimws(readline())
      
      # Check for quit
      if (tolower(device_input) == "q") {
        cat("❌ Exiting maintenance logger\n")
        return(invisible(FALSE))
      }
      # Parse device input
      if (grepl("^[0-9]+$", device_input)) {
        device_num <- as.numeric(device_input)
        if (device_num >= 1 && device_num <= nrow(station_data)) {
          device_serial <- station_data$device_serial[device_num]
          break  # Valid selection, exit loop
        } else {
          cat("⚠️  Invalid number. Please enter 1-", nrow(station_data), "\n", sep = "")
        }
      } else {
        if (device_input %in% station_data$device_serial) {
          device_serial <- device_input
          break  # Valid device serial, exit loop
        } else {
          cat("⚠️  Device '", device_input, "' not found at this station. Try again.\n", sep = "")
        }
      }
    }
    cat("✓ Device:", device_serial, "\n")
    
    #### 5 - Prompt for action type
    repeat {
      cat("\nWhat action was performed?\n")
      
      # Standard action types
      standard_actions <- c("download", "sensor_swap", "depth_change", "cleaning", "battery", 
                            "relocation", "device_removed", "device_installed", "maintenance")
      
      # Load maintenance log to find custom actions
      maint_log <- load_maintenance_log()
      custom_actions <- character()
      if (!is.null(maint_log) && nrow(maint_log) > 0) {
        all_actions <- unique(maint_log$action_type)
        custom_actions <- setdiff(all_actions, c(standard_actions, "other"))
      }
      
      # Build combined action list
      all_action_types <- c(standard_actions, custom_actions, "other")
      
      # Display options
      for (i in seq_along(all_action_types)) {
        cat("  ", i, ". ", all_action_types[i], "\n", sep = "")
      }
      
      cat("\nEnter number or type custom action (or 'q' to quit): ")
      action_input <- trimws(readline())
      # Check for quit
      if (tolower(action_input) == "q") {
        cat("❌ Exiting maintenance logger\n")
        return(invisible(FALSE))
      }
      
      # Parse input
      if (grepl("^[0-9]+$", action_input)) {
        action_num <- as.numeric(action_input)
        if (action_num >= 1 && action_num <= length(all_action_types)) {
          action_type <- all_action_types[action_num]
          break  # Valid selection
        } else {
          cat("⚠️  Invalid number. Please enter 1-", length(all_action_types), "\n", sep = "")
        }
      } else {
        # Custom action - confirm with user
        cat("Custom action: '", action_input, "'\n", sep = "")
        cat("Is this correct? (Y/N): ")
        confirm <- toupper(trimws(readline()))
        # Accept 1 for Y, 2 for N
        if (confirm == "1") confirm <- "Y"
        if (confirm == "2") confirm <- "N"
        
        if (confirm == "Y") {
          action_type <- action_input
          break  # User confirmed custom action
        } else {
          cat("Let's try again.\n")
        }
      }
    }
    cat("✓ Action:", action_type, "\n")
    
    #### 6 - Prompt for details
    cat("\nEnter details (one line):\n")
    details <- readline()
    cat("✓ Details recorded\n")
    
    #### 7 - Prompt for ports updated
    repeat {
      cat("\nDid you update zentra_ports.csv? (Y/N or 'q' to quit): ")
      ports_response <- toupper(trimws(readline()))
      # Accept 1 for Y, 2 for N
      if (ports_response == "1") ports_response <- "Y"
      if (ports_response == "2") ports_response <- "N"
      
      if (ports_response == "Q") {
        cat("❌ Exiting maintenance logger\n")
        return(invisible(FALSE))
      }
      if (ports_response %in% c("Y", "N")) {
        ports_updated <- ports_response == "Y"
        break
      } else {
        cat("⚠️  Please enter Y or N\n")
      }
    }
    if (ports_updated) {
      cat("\n⚠️  REMINDER: Make sure zentra_ports.csv is updated!\n")
      cat("Press Enter when ready to continue...")
      readline()
    }
    cat("✓ Ports updated:", ports_updated, "\n\n")
    
    #### 8 - Prompt for logged_by
    repeat {
      cat("\nWho is logging this entry?\n")
      cat("  1. DAH\n")
      cat("  2. Enter custom initials (3 letters)\n")
      cat("\nEnter selection: ")
      logged_by_input <- trimws(readline())
      
      if (logged_by_input == "1") {
        logged_by <- "DAH"
        break
      } else if (logged_by_input == "2") {
        cat("Enter 3-letter initials: ")
        custom_initials <- toupper(trimws(readline()))
        if (nchar(custom_initials) == 3) {
          logged_by <- custom_initials
          break
        } else {
          cat("⚠️  Please enter exactly 3 letters\n")
        }
      } else {
        cat("⚠️  Please enter 1 or 2\n")
      }
    }
    cat("✓ Logged by:", logged_by, "\n")
    
    #### 9 - Confirm before writing
    cat("\n============================================\n")
    cat("Ready to log this maintenance entry:\n")
    cat("  Date:", field_visit_date, "\n")
    cat("  Station:", station_id, "\n")
    cat("  Device:", device_serial, "\n")
    cat("  Action:", action_type, "\n")
    cat("  Details:", details, "\n")
    cat("  Ports updated:", ports_updated, "\n")
    cat("  Logged by:", logged_by, "\n")
    cat("============================================\n\n")
    cat("Confirm? (Y/N): ")
    confirm <- toupper(trimws(readline()))
    # Accept 1 for Y, 2 for N
    if (confirm == "1") confirm <- "Y"
    if (confirm == "2") confirm <- "N"
    
    if (confirm != "Y") {
      cat("❌ Cancelled - no entry logged\n")
      # Ask if they want to try again
      cat("\nTry again? (Y/N): ")
      retry <- toupper(trimws(readline()))
      if (retry == "1") retry <- "Y"
      if (retry == "2") retry <- "N"
      if (retry != "Y") {
        return(invisible(FALSE))
      }
      next  # Go back to start of loop
    }
    
    #### 10 - Write the entry
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
    
    #### 11 - Ask about approving download
    cat("\n============================================\n")
    cat("Approve this station for download? (Y/N): ")
    approve <- toupper(trimws(readline()))
    # Accept 1 for Y, 2 for N
    if (approve == "1") approve <- "Y"
    if (approve == "2") approve <- "N"
    
    if (approve == "Y") {
      set_download_approved(station_id = station_id, value = TRUE)
      cat("✓ Station approved for download\n")
    } else {
      cat("⚠️  Station NOT approved - remember to approve later!\n")
    }
    
    #### 12 - Update last_visit date in metadata
    # Update last_visit for active devices (not decommissioned/relocated) at this station
    metadata <- load_zentra_metadata()
    station_devices <- metadata[metadata$station_id == station_id, ]
    # Find active devices (exclude decommissioned and relocated)
    active_mask <- !(station_devices$status %in% c("decommissioned", "relocated"))
    active_unique_ids <- station_devices$unique_ID[active_mask]
    if (length(active_unique_ids) > 0) {
      # Update last_visit for all active devices at this station
      metadata$last_visit[metadata$unique_ID %in% active_unique_ids] <- field_visit_date
      # Save metadata
      setwd(wds("meta_internal"))
      metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
      metadata$last_update <- format_datetime_safe(metadata$last_update)
      metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
      write.csv(metadata, "device_metadata.csv", row.names = FALSE)
      message("✓ Updated last_visit date for ", length(active_unique_ids), " active device(s) at ", station_id)
    }
    
    #### 13 - Ask if they want to log another entry
    cat("\n============================================\n")
    cat("Log another maintenance entry? (Y/N): ")
    another <- toupper(trimws(readline()))
    if (another == "1") another <- "Y"
    if (another == "2") another <- "N"
    
    if (another != "Y") {
      cat("\n✓ All done!\n")
      return(invisible(TRUE))
    }
    
    # Loop continues for another entry
  }
}

# Run the interactive function
log_maintenance_interactive()
