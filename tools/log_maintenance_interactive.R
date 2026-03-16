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
    
    #### 9 - Update status if needed
    # Show current status and offer to change it
    current_status <- station_data$status[1]  # Get current status
    
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
      cat("Suggested new status based on action: ", suggested_status, "\n", sep = "")
    }
    cat("Does this status need to change? (Y/N): ")
    change_status <- toupper(trimws(readline()))
    if (change_status == "1") change_status <- "Y"
    if (change_status == "2") change_status <- "N"
    
    new_status <- current_status  # Default to keeping same status
    
    if (change_status == "Y") {
      # If there's a suggested status, offer to use it
      if (!is.null(suggested_status)) {
        cat("\nUse suggested status '", suggested_status, "'? (Y/N): ", sep = "")
        use_suggested <- toupper(trimws(readline()))
        if (use_suggested == "1") use_suggested <- "Y"
        if (use_suggested == "2") use_suggested <- "N"
        
        if (use_suggested == "Y") {
          new_status <- suggested_status
          cat("✓ New status:", new_status, "\n")
        } else {
          # Show full menu
          repeat {
            existing_statuses <- sort(unique(metadata$status))
            
            cat("\nSelect new status:\n")
            for (i in seq_along(existing_statuses)) {
              cat("  ", i, ". ", existing_statuses[i], "\n", sep = "")
            }
            cat("  ", length(existing_statuses) + 1, ". other (specify)\n", sep = "")
            
            cat("\nEnter selection: ")
            status_input <- trimws(readline())
            
            if (grepl("^[0-9]+$", status_input)) {
              status_num <- as.numeric(status_input)
              if (status_num >= 1 && status_num <= length(existing_statuses)) {
                new_status <- existing_statuses[status_num]
                break
              } else if (status_num == length(existing_statuses) + 1) {
                # Custom status
                cat("Enter custom status: ")
                custom_status <- trimws(readline())
                if (custom_status != "") {
                  new_status <- custom_status
                  break
                } else {
                  cat("⚠️  Status cannot be empty\n")
                }
              } else {
                cat("⚠️  Invalid number\n")
              }
            } else {
              cat("⚠️  Please enter a number\n")
            }
          }
          cat("✓ New status:", new_status, "\n")
        }
      } else {
        # No suggestion, show full menu
        repeat {
          existing_statuses <- sort(unique(metadata$status))
          
          cat("\nSelect new status:\n")
          for (i in seq_along(existing_statuses)) {
            cat("  ", i, ". ", existing_statuses[i], "\n", sep = "")
          }
          cat("  ", length(existing_statuses) + 1, ". other (specify)\n", sep = "")
          
          cat("\nEnter selection: ")
          status_input <- trimws(readline())
          
          if (grepl("^[0-9]+$", status_input)) {
            status_num <- as.numeric(status_input)
            if (status_num >= 1 && status_num <= length(existing_statuses)) {
              new_status <- existing_statuses[status_num]
              break
            } else if (status_num == length(existing_statuses) + 1) {
              # Custom status
              cat("Enter custom status: ")
              custom_status <- trimws(readline())
              if (custom_status != "") {
                new_status <- custom_status
                break
              } else {
                cat("⚠️  Status cannot be empty\n")
              }
            } else {
              cat("⚠️  Invalid number\n")
            }
          } else {
            cat("⚠️  Please enter a number\n")
          }
        }
        cat("✓ New status:", new_status, "\n")
      }
    } else {
      cat("✓ Status unchanged:", current_status, "\n")
    }
    
    #### 10 - Confirm before writing
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
    
    #### 11 - Write the entry
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
    
    #### 12 - Ask about approving download
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
    
    #### 13 - Update last_visit date and status in metadata
    # Reload metadata to get fresh copy
    metadata <- load_zentra_metadata()
    station_devices <- metadata[metadata$station_id == station_id, ]
    
    # Find active devices (exclude decommissioned and relocated)
    active_mask <- !(station_devices$status %in% c("decommissioned", "relocated"))
    active_unique_ids <- station_devices$unique_id[active_mask]
    
    if (length(active_unique_ids) > 0) {
      # Update last_visit for all active devices at this station
      metadata$last_visit[metadata$unique_id %in% active_unique_ids] <- as.Date(field_visit_date)
      
      # Also update status if it changed
      if (new_status != current_status) {
        metadata$status[metadata$unique_id %in% active_unique_ids] <- new_status
      }
      
      # Save metadata
      setwd(wds("meta_internal"))
      metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
      metadata$last_update <- format_datetime_safe(metadata$last_update)
      metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
      metadata$last_visit <- as.character(metadata$last_visit)
      
      write.csv(metadata, "device_metadata.csv", row.names = FALSE)
      
      message("✓ Updated last_visit date for ", length(active_unique_ids), " active device(s) at ", station_id)
      if (new_status != current_status) {
        message("✓ Updated status to: ", new_status)
      }
    }
    
    #### 13.5 - Handle relocation if needed
    if (action_type == "relocation" || new_status == "relocated") {
      cat("\n============================================\n")
      cat("RELOCATION DETECTED\n")
      cat("Creating new deployment entry for relocated device...\n")
      cat("============================================\n\n")
      
      # Get new location info
      cat("New latitude: ")
      new_lat <- as.numeric(trimws(readline()))
      
      cat("New longitude: ")
      new_lon <- as.numeric(trimws(readline()))
      
      cat("Deployment datetime at new location (YYYY-MM-DD HH:MM:SS)\n")
      cat("Or press Enter for now: ")
      new_deploy <- trimws(readline())
      if (new_deploy == "") {
        new_deploy <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      }
      
      # Ask about status at new location
      repeat {
        cat("\nIs device online at new location? (Y/N): ")
        online_response <- toupper(trimws(readline()))
        if (online_response == "1") online_response <- "Y"
        if (online_response == "2") online_response <- "N"
        
        if (online_response %in% c("Y", "N")) {
          if (online_response == "Y") {
            new_location_status <- "online"
            break
          } else {
            # Not online - ask what status it is
            repeat {
              existing_statuses <- sort(unique(metadata$status))
              cat("\nSelect status for new location:\n")
              for (i in seq_along(existing_statuses)) {
                cat("  ", i, ". ", existing_statuses[i], "\n", sep = "")
              }
              cat("  ", length(existing_statuses) + 1, ". other (specify)\n", sep = "")
              
              cat("\nEnter selection: ")
              status_input <- trimws(readline())
              
              if (grepl("^[0-9]+$", status_input)) {
                status_num <- as.numeric(status_input)
                if (status_num >= 1 && status_num <= length(existing_statuses)) {
                  new_location_status <- existing_statuses[status_num]
                  break
                } else if (status_num == length(existing_statuses) + 1) {
                  # Custom status
                  cat("Enter custom status: ")
                  custom_status <- trimws(readline())
                  if (custom_status != "") {
                    new_location_status <- custom_status
                    break
                  } else {
                    cat("⚠️  Status cannot be empty\n")
                  }
                } else {
                  cat("⚠️  Invalid number\n")
                }
              } else {
                cat("⚠️  Please enter a number\n")
              }
            }
            break
          }
        } else {
          cat("⚠️  Please enter Y or N\n")
        }
      }
      
      # Ask about download approval
      repeat {
        cat("\nApprove new deployment for download? (Y/N): ")
        approve_new <- toupper(trimws(readline()))
        if (approve_new == "1") approve_new <- "Y"
        if (approve_new == "2") approve_new <- "N"
        
        if (approve_new %in% c("Y", "N")) {
          new_download_approved <- (approve_new == "Y")
          break
        } else {
          cat("⚠️  Please enter Y or N\n")
        }
      }
      
      # Create new unique_id
      # Get the next available number
      all_unique_ids <- metadata$unique_id
      existing_numbers <- as.numeric(sub("^[a-z]-", "", all_unique_ids))
      next_number <- max(existing_numbers, na.rm = TRUE) + 1
      new_unique_id <- sprintf("z-%04d", next_number)
      
      # Get the old device row to copy most fields
      old_device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
      
      # Create new row
      new_row <- old_device_row
      new_row$unique_id <- new_unique_id
      new_row$lat <- new_lat
      new_row$lon <- new_lon
      new_row$deploy_datetime <- as.POSIXct(new_deploy, format = "%Y-%m-%d %H:%M:%S", tz = old_device_row$timezone)
      new_row$status <- new_location_status
      new_row$last_update <- old_device_row$last_update  # Copy from old location
      new_row$last_visit <- as.Date(field_visit_date)
      new_row$download_approved <- new_download_approved
      
      # Add new row to metadata
      
      # Reload metadata fresh to get clean copy after Section 13's save
      metadata <- load_zentra_metadata()
      
      # Add new row to metadata
      metadata <- rbind(metadata, new_row)
      
      # Save metadata
      setwd(wds("meta_internal"))
      metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
      metadata$last_update <- format_datetime_safe(metadata$last_update)
      metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
      metadata$last_visit <- as.character(metadata$last_visit)
      
      write.csv(metadata, "device_metadata.csv", row.names = FALSE)
      
      cat("\n✓ Created new deployment entry:", new_unique_id, "\n")
      cat("⚠️  REMINDER: Update zentra_ports.csv if sensor configuration changed!\n")
    }
    
    #### 14 - Ask if they want to log another entry
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

# Add new device to devices_metadata.csv
add_device <- function() {
  
  cat("\n============================================\n")
  cat("  VI-FLO Engine - Add Device\n")
  cat("============================================\n\n")
  
  # Load metadata to check existing stations
  metadata <- load_zentra_metadata()
  
  #### 1 - New or existing station?
  repeat {
    cat("Is this a new station or existing station?\n")
    cat("  1. New station (create station metadata)\n")
    cat("  2. Existing station (add device to existing station)\n")
    cat("\nEnter selection (or 'q' to quit): ")
    station_choice <- trimws(readline())
    
    if (tolower(station_choice) == "q") {
      cat("❌ Cancelled\n")
      return(invisible(FALSE))
    }
    
    if (station_choice %in% c("1", "2")) {
      is_new_station <- (station_choice == "1")
      break
    } else {
      cat("⚠️  Please enter 1 or 2\n")
    }
  }
  
  #### 2 - Get station information
  if (is_new_station) {
    # New station - prompt for station metadata
    cat("\n--- NEW STATION INFORMATION ---\n")
    
    # Watershed - show existing options
    repeat {
      existing_watersheds <- sort(unique(metadata$watershed[!is.na(metadata$watershed)]))
      cat("\nSelect watershed:\n")
      for (i in seq_along(existing_watersheds)) {
        cat("  ", i, ". ", existing_watersheds[i], "\n", sep = "")
      }
      cat("  ", length(existing_watersheds) + 1, ". other (specify)\n", sep = "")
      
      cat("\nEnter selection: ")
      watershed_input <- trimws(readline())
      
      if (grepl("^[0-9]+$", watershed_input)) {
        watershed_num <- as.numeric(watershed_input)
        if (watershed_num >= 1 && watershed_num <= length(existing_watersheds)) {
          watershed <- existing_watersheds[watershed_num]
          break
        } else if (watershed_num == length(existing_watersheds) + 1) {
          cat("Enter watershed name: ")
          custom_watershed <- trimws(readline())
          if (custom_watershed != "") {
            watershed <- custom_watershed
            break
          } else {
            cat("⚠️  Watershed cannot be empty\n")
          }
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        cat("⚠️  Please enter a number\n")
      }
    }
    
    # Area - show existing options
    repeat {
      existing_areas <- sort(unique(metadata$area[!is.na(metadata$area)]))
      cat("\nSelect area:\n")
      for (i in seq_along(existing_areas)) {
        cat("  ", i, ". ", existing_areas[i], "\n", sep = "")
      }
      cat("  ", length(existing_areas) + 1, ". other (specify)\n", sep = "")
      cat("  ", length(existing_areas) + 2, ". NA (no area)\n", sep = "")
      
      cat("\nEnter selection: ")
      area_input <- trimws(readline())
      
      if (grepl("^[0-9]+$", area_input)) {
        area_num <- as.numeric(area_input)
        if (area_num >= 1 && area_num <= length(existing_areas)) {
          area <- existing_areas[area_num]
          break
        } else if (area_num == length(existing_areas) + 1) {
          cat("Enter area name: ")
          custom_area <- trimws(readline())
          if (custom_area != "") {
            area <- custom_area
            break
          } else {
            cat("⚠️  Area cannot be empty\n")
          }
        } else if (area_num == length(existing_areas) + 2) {
          area <- NA
          break
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        cat("⚠️  Please enter a number\n")
      }
    }
    
    cat("\nFull site name: ")
    site_full <- trimws(readline())
    
    cat("Site code (short): ")
    site <- trimws(readline())
    
    # Station type - show existing options
    repeat {
      existing_types <- sort(unique(metadata$station_type))
      cat("\nSelect station type:\n")
      for (i in seq_along(existing_types)) {
        cat("  ", i, ". ", existing_types[i], "\n", sep = "")
      }
      cat("  ", length(existing_types) + 1, ". other (specify)\n", sep = "")
      
      cat("\nEnter selection: ")
      type_input <- trimws(readline())
      
      if (grepl("^[0-9]+$", type_input)) {
        type_num <- as.numeric(type_input)
        if (type_num >= 1 && type_num <= length(existing_types)) {
          station_type <- existing_types[type_num]
          break
        } else if (type_num == length(existing_types) + 1) {
          cat("Enter station type: ")
          custom_type <- trimws(readline())
          if (custom_type != "") {
            station_type <- custom_type
            break
          } else {
            cat("⚠️  Station type cannot be empty\n")
          }
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        cat("⚠️  Please enter a number\n")
      }
    }
    
    cat("Station ID (e.g., sr3_vwc1): ")
    station_id <- trimws(readline())
    
  } else {
    # Existing station - show list and inherit
    repeat {
      cat("\n--- EXISTING STATIONS ---\n")
      existing_stations <- unique(metadata[, c("station_id", "site_full", "station_type")])
      existing_stations <- existing_stations[order(existing_stations$station_id), ]
      
      for (i in 1:nrow(existing_stations)) {
        cat("  ", i, ". ", existing_stations$station_id[i], " (", 
            existing_stations$site_full[i], " - ", existing_stations$station_type[i], ")\n", sep = "")
      }
      
      cat("\nEnter station number or ID (or 'q' to quit): ")
      station_input <- trimws(readline())
      
      if (tolower(station_input) == "q") {
        cat("❌ Cancelled\n")
        return(invisible(FALSE))
      }
      
      # Parse input
      if (grepl("^[0-9]+$", station_input)) {
        station_num <- as.numeric(station_input)
        if (station_num >= 1 && station_num <= nrow(existing_stations)) {
          selected_station_id <- existing_stations$station_id[station_num]
          break
        } else {
          cat("⚠️  Invalid number\n")
        }
      } else {
        # Try to match station ID
        if (station_input %in% existing_stations$station_id) {
          selected_station_id <- station_input
          break
        } else {
          cat("⚠️  Station not found\n")
        }
      }
    }
    
    # Get one row from this station to inherit from
    station_template <- metadata[metadata$station_id == selected_station_id, ][1, ]
    
    # Inherit station info
    watershed <- station_template$watershed
    area <- station_template$area
    site_full <- station_template$site_full
    site <- station_template$site
    station_type <- station_template$station_type
    station_id <- selected_station_id
    
    cat("✓ Inherited station info from:", station_id, "\n")
  }
  
  #### 3 - Device details
  cat("\n--- DEVICE DETAILS ---\n")
  
  cat("Device serial number (e.g., z6-12345 or h21-98765): ")
  device_serial <- trimws(readline())
  
  # Device role - show existing options
  repeat {
    existing_roles <- sort(unique(metadata$device_role[!is.na(metadata$device_role)]))
    cat("\nSelect device role:\n")
    for (i in seq_along(existing_roles)) {
      cat("  ", i, ". ", existing_roles[i], "\n", sep = "")
    }
    cat("  ", length(existing_roles) + 1, ". other (specify)\n", sep = "")
    
    cat("\nEnter selection: ")
    role_input <- trimws(readline())
    
    if (grepl("^[0-9]+$", role_input)) {
      role_num <- as.numeric(role_input)
      if (role_num >= 1 && role_num <= length(existing_roles)) {
        device_role <- existing_roles[role_num]
        break
      } else if (role_num == length(existing_roles) + 1) {
        cat("Enter device role: ")
        custom_role <- trimws(readline())
        if (custom_role != "") {
          device_role <- custom_role
          break
        } else {
          cat("⚠️  Device role cannot be empty\n")
        }
      } else {
        cat("⚠️  Invalid number\n")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
  
  cat("Device name (descriptive): ")
  device_name <- trimws(readline())
  
  # Manufacturer - show existing options
  repeat {
    existing_mfgers <- sort(unique(metadata$mfger[!is.na(metadata$mfger)]))
    cat("\nSelect manufacturer:\n")
    for (i in seq_along(existing_mfgers)) {
      cat("  ", i, ". ", existing_mfgers[i], "\n", sep = "")
    }
    cat("  ", length(existing_mfgers) + 1, ". other (specify)\n", sep = "")
    
    cat("\nEnter selection: ")
    mfger_input <- trimws(readline())
    
    if (grepl("^[0-9]+$", mfger_input)) {
      mfger_num <- as.numeric(mfger_input)
      if (mfger_num >= 1 && mfger_num <= length(existing_mfgers)) {
        mfger <- existing_mfgers[mfger_num]
        break
      } else if (mfger_num == length(existing_mfgers) + 1) {
        cat("Enter manufacturer: ")
        custom_mfger <- trimws(readline())
        if (custom_mfger != "") {
          mfger <- custom_mfger
          break
        } else {
          cat("⚠️  Manufacturer cannot be empty\n")
        }
      } else {
        cat("⚠️  Invalid number\n")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
  
  #### 4 - Location
  cat("\n--- LOCATION ---\n")
  
  cat("Latitude (or press Enter for NA): ")
  lat_input <- trimws(readline())
  lat <- ifelse(lat_input == "", NA, as.numeric(lat_input))
  
  cat("Longitude (or press Enter for NA): ")
  lon_input <- trimws(readline())
  lon <- ifelse(lon_input == "", NA, as.numeric(lon_input))
  
  cat("Elevation (or press Enter for NA): ")
  elev_input <- trimws(readline())
  elev <- ifelse(elev_input == "", NA, as.numeric(elev_input))
  
  #### 5 - Timing
  cat("\n--- TIMING ---\n")
  
  cat("Data interval in minutes (default 15): ")
  interval_input <- trimws(readline())
  interval_min <- ifelse(interval_input == "", 15, as.numeric(interval_input))
  
  cat("Timezone (default America/Puerto_Rico): ")
  tz_input <- trimws(readline())
  timezone <- ifelse(tz_input == "", "America/Puerto_Rico", tz_input)
  
  cat("Deployment datetime (YYYY-MM-DD HH:MM:SS)\n")
  cat("Or press Enter for now: ")
  deploy_input <- trimws(readline())
  if (deploy_input == "") {
    deploy_datetime <- as.POSIXct(Sys.time(), tz = timezone)
  } else {
    deploy_datetime <- as.POSIXct(deploy_input, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
  }
  
  #### 6 - Status
  cat("\n--- STATUS ---\n")
  
  repeat {
    existing_statuses <- sort(unique(metadata$status))
    cat("Select device status:\n")
    for (i in seq_along(existing_statuses)) {
      cat("  ", i, ". ", existing_statuses[i], "\n", sep = "")
    }
    cat("  ", length(existing_statuses) + 1, ". other (specify)\n", sep = "")
    
    cat("\nEnter selection: ")
    status_input <- trimws(readline())
    
    if (grepl("^[0-9]+$", status_input)) {
      status_num <- as.numeric(status_input)
      if (status_num >= 1 && status_num <= length(existing_statuses)) {
        status <- existing_statuses[status_num]
        break
      } else if (status_num == length(existing_statuses) + 1) {
        cat("Enter custom status: ")
        custom_status <- trimws(readline())
        if (custom_status != "") {
          status <- custom_status
          break
        } else {
          cat("⚠️  Status cannot be empty\n")
        }
      } else {
        cat("⚠️  Invalid number\n")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
  
  repeat {
    cat("Approve for download? (Y/N): ")
    approve_response <- toupper(trimws(readline()))
    if (approve_response == "1") approve_response <- "Y"
    if (approve_response == "2") approve_response <- "N"
    
    if (approve_response %in% c("Y", "N")) {
      download_approved <- (approve_response == "Y")
      break
    } else {
      cat("⚠️  Please enter Y or N\n")
    }
  }
  
  cat("Expiry/warranty date (YYYY-MM-DD, or press Enter for NA): ")
  expiry_input <- trimws(readline())
  expiry_date <- ifelse(expiry_input == "", NA, as.Date(expiry_input))
  
  #### 7 - Generate unique_id
  # Determine prefix based on manufacturer
  if (tolower(mfger) == "meter") {
    prefix <- "z"
  } else if (tolower(mfger) %in% c("onset", "hobo")) {
    prefix <- "h"
  } else {
    cat("Manufacturer '", mfger, "' not recognized. Use 'z' or 'h' for unique_id prefix? ", sep = "")
    prefix <- tolower(trimws(readline()))
  }
  
  # Get next available number
  all_unique_ids <- metadata$unique_id
  matching_prefix <- all_unique_ids[grepl(paste0("^", prefix, "-"), all_unique_ids)]
  existing_numbers <- as.numeric(sub(paste0("^", prefix, "-"), "", matching_prefix))
  next_number <- ifelse(length(existing_numbers) == 0, 1, max(existing_numbers, na.rm = TRUE) + 1)
  unique_id <- sprintf("%s-%04d", prefix, next_number)
  
  #### 8 - Confirmation
  cat("\n============================================\n")
  cat("Ready to add this device:\n")
  cat("  Unique ID:", unique_id, "\n")
  cat("  Site:", site, "(", site_full, ")\n", sep = "")
  cat("  Station:", station_id, "(", station_type, ")\n", sep = "")
  cat("  Device:", device_serial, "\n")
  cat("  Role:", device_role, "\n")
  cat("  Location:", lat, ",", lon, "\n")
  cat("  Status:", status, "\n")
  cat("  Download approved:", download_approved, "\n")
  cat("============================================\n\n")
  cat("Confirm? (Y/N): ")
  confirm <- toupper(trimws(readline()))
  if (confirm == "1") confirm <- "Y"
  if (confirm == "2") confirm <- "N"
  
  if (confirm != "Y") {
    cat("❌ Cancelled - device not added\n")
    return(invisible(FALSE))
  }
  
  #### 9 - Create new row
  new_row <- data.frame(
    unique_id = unique_id,
    watershed = watershed,
    area = area,
    site_full = site_full,
    site = site,
    station_type = station_type,
    station_id = station_id,
    device_serial = device_serial,
    device_role = device_role,
    device_name = device_name,
    mfger = mfger,
    lat = lat,
    lon = lon,
    elev = elev,
    interval_min = interval_min,
    timezone = timezone,
    deploy_datetime = deploy_datetime,
    status = status,
    last_update = NA,
    battery = NA,
    last_visit = NA,
    expiry_date = expiry_date,
    last_download_date = NA,
    last_record_date = NA,
    download_approved = download_approved,
    stringsAsFactors = FALSE
  )
  
  #### 10 - Add to metadata and save
  metadata <- rbind(metadata, new_row)
  
  setwd(wds("meta_internal"))
  metadata$deploy_datetime <- format_datetime_safe(metadata$deploy_datetime)
  metadata$last_update <- format_datetime_safe(metadata$last_update)
  metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
  metadata$last_visit <- as.character(metadata$last_visit)
  metadata$expiry_date <- as.character(metadata$expiry_date)
  
  write.csv(metadata, "device_metadata.csv", row.names = FALSE)
  
  cat("\n✓ Device added:", unique_id, "\n")
  cat("⚠️  REMINDER: Create port configurations in zentra_ports.csv if needed!\n")
  
  invisible(TRUE)
}

# Run the interactive function
log_maintenance_interactive()

# Or run the add device function
add_device()

