#' =============================================================================
#' VI-FLO Engine - Metadata Validation Functions
#' =============================================================================
#' 
#' Functions to validate metadata integrity across all VI-FLO data files.
#' Run validate_metadata() after any operation to check for violations.
#'
#' Integrity rules enforced:
#'
#' DEVICE METADATA:
#'   1. unique_id must be unique (no duplicates)
#'   2. Only one active row per device_serial PER STATION_TYPE
#'      (Same device CAN serve multiple station types, e.g., weather + vwc)
#'   3. Required fields must be non-NA: station_id, device_serial, status, 
#'      deploy_datetime, lat, lon, timezone, mfger
#'   4. Coordinates must be valid: lat [-90, 90], lon [-180, 180]
#'   5. Status must be from known set
#'   6. download_approved must be FALSE for manual stations
#'   7. Every download log filepath resolves to a file that exists
#'
#' PORT CONFIGURATIONS:
#'   7. Only one active config per device+port (end_datetime = NA)
#'   8. Port numbers must be 1-6
#'   9. device_serial must exist in device_metadata
#'
#' MAINTENANCE LOG:
#'   10. station_id should exist in device_metadata
#'   11. Required fields: field_visit_date, station_id, device_serial, 
#'       action_type, logged_by
#'
#' CROSS-FILE:
#'   12. Terminal status rows (removed/replaced/relocated/decommissioned) 
#'       should not have active port configs
#'
#' =============================================================================


#' Validate all VI-FLO metadata
#' 
#' Runs comprehensive integrity checks on device_metadata, zentra_ports,
#' and maintenance_log. Returns a report of any violations found.
#'
#' @param verbose Logical. Print progress messages? Default TRUE.
#' @param stop_on_error Logical. Stop immediately on first violation? Default FALSE.
#' @return List with $valid (logical), $summary (character), $violations (list of data frames)
#' 
#' @examples
#' result <- validate_metadata()
#' if (!result$valid) print(result$summary)
#' 
validate_metadata <- function(verbose = TRUE, stop_on_error = FALSE) {
  
  # Initialize results
  violations <- list()
  checks_passed <- 0
  checks_failed <- 0
  
  # Helper to record violations
  record_violation <- function(check_name, description, data = NULL) {
    violations[[check_name]] <<- list(
      description = description,
      data = data
    )
    checks_failed <<- checks_failed + 1
    if (verbose) cat("  ✗", check_name, "-", description, "\n")
    if (stop_on_error) stop(paste("Validation failed:", check_name))
  }
  
  # Helper to record passed checks
  record_pass <- function(check_name) {
    checks_passed <<- checks_passed + 1
    if (verbose) cat("  ✓", check_name, "\n")
  }
  
  # ==========================================================================
  # LOAD DATA
  # ==========================================================================
  
  if (verbose) cat("\n=== VI-FLO Metadata Validation ===\n\n")
  if (verbose) cat("Loading data files...\n")
  
  # Try to load each file
  metadata <- tryCatch({
    load_zentra_metadata()
  }, error = function(e) {
    record_violation("LOAD_METADATA", paste("Failed to load device_metadata.csv:", e$message))
    return(NULL)
  })
  
  ports <- tryCatch({
    load_zentra_ports_data()
  }, error = function(e) {
    record_violation("LOAD_PORTS", paste("Failed to load zentra_ports.csv:", e$message))
    return(NULL)
  })
  
  maint <- tryCatch({
    load_maintenance_log()
  }, error = function(e) {
    record_violation("LOAD_MAINT", paste("Failed to load maintenance_log.csv:", e$message))
    return(NULL)
  })
  
  dlog <- tryCatch({
    load_download_log()
  }, error = function(e) {
    record_violation("LOAD_DOWNLOAD", paste("Failed to load download_log.csv:", e$message))
    return(NULL)
  })
  
  if (is.null(metadata)) {
    return(list(
      valid = FALSE,
      summary = "CRITICAL: Could not load device_metadata.csv",
      violations = violations
    ))
  }
  
  if (verbose) cat("  Loaded", nrow(metadata), "device records\n")
  if (!is.null(ports)) {
    if (verbose) cat("  Loaded", nrow(ports), "port configurations\n")
  }
  if (!is.null(maint)) {
    if (verbose) cat("  Loaded", nrow(maint), "maintenance entries\n")
  }
  
  if (!is.null(dlog)) {
    if (verbose) cat("  Loaded", nrow(dlog), "download records\n")
  }
  
  # ==========================================================================
  # DEVICE METADATA CHECKS
  # ==========================================================================
  
  if (verbose) cat("\nChecking device metadata...\n")
  
  # CHECK 1: Unique IDs must be unique
  if (any(duplicated(metadata$unique_id))) {
    dups <- metadata$unique_id[duplicated(metadata$unique_id)]
    dup_rows <- metadata[metadata$unique_id %in% dups, c("unique_id", "station_id", "device_serial")]
    record_violation(
      "UNIQUE_ID_DUPLICATES",
      paste(length(unique(dups)), "duplicate unique_id values found"),
      dup_rows
    )
  } else {
    record_pass("unique_id uniqueness")
  }
  
  # CHECK 2: Only one active row per device_serial PER STATION_TYPE
  # (Same physical device CAN serve multiple station types, e.g., weather + vwc)
  active_statuses <- c("online", "local", "nonresponsive", "defunct")
  active_devices <- metadata[metadata$status %in% active_statuses, ]
  
  if (nrow(active_devices) > 0) {
    # Create composite key: serial + station_type
    active_devices$serial_type <- paste(active_devices$device_serial, 
                                        active_devices$station_type, sep = "_")
    serial_type_counts <- table(active_devices$serial_type)
    multi_active <- names(serial_type_counts[serial_type_counts > 1])
    
    if (length(multi_active) > 0) {
      problem_rows <- active_devices[active_devices$serial_type %in% multi_active, 
                                     c("unique_id", "station_id", "device_serial", 
                                       "station_type", "status", "deploy_datetime")]
      record_violation(
        "MULTIPLE_ACTIVE_SERIAL_SAME_TYPE",
        paste(length(multi_active), "device serial + station_type combination(s) have multiple active rows"),
        problem_rows
      )
    } else {
      record_pass("one active row per device_serial per station_type")
    }
  } else {
    record_pass("one active row per device_serial per station_type (no active devices)")
  }
  
  # CHECK 3: Required fields non-NA
  required_fields <- c("station_id", "device_serial", "status", "deploy_datetime", 
                       "lat", "lon", "timezone", "mfger")
  
  for (field in required_fields) {
    if (field %in% names(metadata)) {
      # Handle different field types appropriately
      field_values <- metadata[[field]]
      
      # Check for NA
      is_na <- is.na(field_values)
      
      # Check for empty string (only for character fields)
      if (is.character(field_values)) {
        is_empty <- field_values == ""
      } else {
        is_empty <- rep(FALSE, length(field_values))
      }
      
      na_count <- sum(is_na | is_empty)
      
      if (na_count > 0) {
        problem_rows <- metadata[is_na | is_empty, 
                                 c("unique_id", "station_id", "device_serial")]
        record_violation(
          paste0("REQUIRED_FIELD_NA_", toupper(field)),
          paste(na_count, "rows have NA/empty", field),
          problem_rows
        )
      } else {
        record_pass(paste("required field:", field))
      }
    } else {
      record_violation(
        paste0("REQUIRED_FIELD_MISSING_", toupper(field)),
        paste("Column", field, "does not exist in metadata")
      )
    }
  }
  
  # CHECK 4: Valid coordinates
  if ("lat" %in% names(metadata) && "lon" %in% names(metadata)) {
    invalid_lat <- !is.na(metadata$lat) & (metadata$lat < -90 | metadata$lat > 90)
    invalid_lon <- !is.na(metadata$lon) & (metadata$lon < -180 | metadata$lon > 180)
    
    if (any(invalid_lat) || any(invalid_lon)) {
      problem_rows <- metadata[invalid_lat | invalid_lon, 
                               c("unique_id", "station_id", "lat", "lon")]
      record_violation(
        "INVALID_COORDINATES",
        paste(sum(invalid_lat | invalid_lon), "rows have out-of-range coordinates"),
        problem_rows
      )
    } else {
      record_pass("coordinate ranges")
    }
  }
  
  # CHECK 5: Valid status values
  valid_statuses <- c("online", "local", "manual", "nonresponsive", "defunct", 
                      "removed", "replaced", "relocated", "decommissioned")
  
  invalid_status <- !metadata$status %in% valid_statuses
  if (any(invalid_status)) {
    unknown_statuses <- unique(metadata$status[invalid_status])
    problem_rows <- metadata[invalid_status, c("unique_id", "station_id", "device_serial", "status")]
    record_violation(
      "INVALID_STATUS",
      paste("Unknown status values:", paste(unknown_statuses, collapse = ", ")),
      problem_rows
    )
  } else {
    record_pass("status values")
  }
  
  # CHECK 6: Manual stations should have download_approved = FALSE
  # Manual stations have no cloud pathway at all, so automatic download is
  # impossible and approval is meaningless. Note this does NOT apply to
  # 'local' stations - their data does reach ZentraCloud (offloaded on site
  # and uploaded), so they are legitimately API-downloadable and approvable.
  if ("download_approved" %in% names(metadata)) {
    manual_approved <- metadata$status == "manual" & 
                       !is.na(metadata$download_approved) & 
                       metadata$download_approved == TRUE
    
    if (any(manual_approved)) {
      problem_rows <- metadata[manual_approved, 
                               c("unique_id", "station_id", "device_serial", "status", "download_approved")]
      record_violation(
        "MANUAL_DOWNLOAD_APPROVED",
        paste(sum(manual_approved), "manual station(s) have download_approved = TRUE"),
        problem_rows
      )
    } else {
      record_pass("manual stations download_approved = FALSE")
    }
  }
  
  # ==========================================================================
  # PORT CONFIGURATION CHECKS
  # ==========================================================================
  
  if (!is.null(ports) && nrow(ports) > 0) {
    if (verbose) cat("\nChecking port configurations...\n")
    
    # CHECK 7: Only one active config per device+port
    # Active = end_datetime is NA
    active_ports <- ports[is.na(ports$end_datetime), ]
    
    if (nrow(active_ports) > 0) {
      active_ports$device_port <- paste(active_ports$device_serial, active_ports$port, sep = "_")
      port_counts <- table(active_ports$device_port)
      multi_active <- names(port_counts[port_counts > 1])
      
      if (length(multi_active) > 0) {
        problem_rows <- active_ports[active_ports$device_port %in% multi_active, 
                                     c("device_serial", "port", "sensor", "start_datetime")]
        record_violation(
          "MULTIPLE_ACTIVE_PORT_CONFIGS",
          paste(length(multi_active), "device+port combination(s) have multiple active configs"),
          problem_rows
        )
      } else {
        record_pass("one active config per device+port")
      }
    } else {
      record_pass("one active config per device+port (no active configs)")
    }
    
    # CHECK 8: Port numbers 1-6
    if ("port" %in% names(ports)) {
      invalid_ports <- !ports$port %in% 1:6
      if (any(invalid_ports)) {
        problem_rows <- ports[invalid_ports, c("device_serial", "port", "sensor")]
        record_violation(
          "INVALID_PORT_NUMBER",
          paste(sum(invalid_ports), "rows have port number outside 1-6"),
          problem_rows
        )
      } else {
        record_pass("port numbers 1-6")
      }
    }
    
    # CHECK 9: Port device_serial exists in metadata
    port_serials <- unique(ports$device_serial)
    meta_serials <- unique(metadata$device_serial)
    orphan_serials <- setdiff(port_serials, meta_serials)
    
    if (length(orphan_serials) > 0) {
      problem_rows <- ports[ports$device_serial %in% orphan_serials, 
                            c("device_serial", "port", "sensor")]
      record_violation(
        "ORPHAN_PORT_SERIAL",
        paste(length(orphan_serials), "device_serial(s) in ports not found in metadata"),
        problem_rows
      )
    } else {
      record_pass("port device_serials exist in metadata")
    }
    
    # CHECK 12: Terminal devices should not have active port configs
    terminal_statuses <- c("removed", "replaced", "relocated", "decommissioned")
    terminal_serials <- unique(metadata$device_serial[metadata$status %in% terminal_statuses])
    
    # Check for active configs on terminal devices
    active_ports <- ports[is.na(ports$end_datetime), ]
    terminal_with_active <- active_ports[active_ports$device_serial %in% terminal_serials, ]
    
    if (nrow(terminal_with_active) > 0) {
      # Get the status for context
      terminal_with_active$status <- sapply(terminal_with_active$device_serial, function(s) {
        paste(unique(metadata$status[metadata$device_serial == s & 
                                      metadata$status %in% terminal_statuses]), collapse = ",")
      })
      problem_rows <- terminal_with_active[, c("device_serial", "port", "sensor", "status")]
      record_violation(
        "TERMINAL_DEVICE_ACTIVE_PORTS",
        paste(nrow(terminal_with_active), "active port config(s) on terminal-status devices"),
        problem_rows
      )
    } else {
      record_pass("no active port configs on terminal devices")
    }
  }
  
  # ==========================================================================
  # MAINTENANCE LOG CHECKS
  # ==========================================================================
  
  if (!is.null(maint) && nrow(maint) > 0) {
    if (verbose) cat("\nChecking maintenance log...\n")
    
    # CHECK 10: station_id should exist in metadata
    maint_stations <- unique(maint$station_id[!is.na(maint$station_id)])
    meta_stations <- unique(metadata$station_id)
    orphan_stations <- setdiff(maint_stations, meta_stations)
    
    if (length(orphan_stations) > 0) {
      problem_rows <- maint[maint$station_id %in% orphan_stations, 
                            c("field_visit_date", "station_id", "device_serial", "action_type")]
      record_violation(
        "ORPHAN_MAINT_STATION",
        paste(length(orphan_stations), "station_id(s) in maintenance log not found in metadata"),
        problem_rows
      )
    } else {
      record_pass("maintenance station_ids exist in metadata")
    }
    
    # CHECK 11: Required fields in maintenance log
    maint_required <- c("field_visit_date", "station_id", "device_serial", "action_type", "logged_by")
    
    for (field in maint_required) {
      if (field %in% names(maint)) {
        field_values <- maint[[field]]
        is_na <- is.na(field_values)
        
        # Check for empty string (only for character fields)
        if (is.character(field_values)) {
          is_empty <- field_values == ""
        } else {
          is_empty <- rep(FALSE, length(field_values))
        }
        
        na_count <- sum(is_na | is_empty)
        
        if (na_count > 0) {
          # Only flag as violation if there are many (some NAs might be expected for old entries)
          if (na_count > nrow(maint) * 0.5) {
            record_violation(
              paste0("MAINT_FIELD_NA_", toupper(field)),
              paste(na_count, "of", nrow(maint), "maintenance entries have NA/empty", field)
            )
          } else if (verbose) {
            cat("  ⚠", field, "has", na_count, "NA values (may be legacy entries)\n")
          }
        } else {
          record_pass(paste("maintenance field:", field))
        }
      }
    }
    
    # Check action types are from known set
    known_actions <- c("cleaning", "maintenance", "inspection", "battery", "download",
                       "station_established", "device_added", "device_replacement", 
                       "device_removal", "station_relocation", "station_decommissioned",
                       "station_reactivated", "port_config_change", "elevation_survey",
                       "metadata_deletion", "logger_relaunch")
    
    if ("action_type" %in% names(maint)) {
      unknown_actions <- unique(maint$action_type[!maint$action_type %in% known_actions & 
                                                   !is.na(maint$action_type)])
      if (length(unknown_actions) > 0) {
        if (verbose) cat("  ⚠ Unknown action types (may be valid):", 
                         paste(unknown_actions, collapse = ", "), "\n")
      } else {
        record_pass("maintenance action_types known")
      }
    }
  }
  
  # ==========================================================================
  # DOWNLOAD LOG CHECKS
  # ==========================================================================
  
  if (!is.null(dlog) && nrow(dlog) > 0) {
    if (verbose) cat("\nChecking download log...\n")
    
    # CHECK: every logged filepath still resolves to a file on disk
    # The log is the record of what has been archived. If a file has been
    # moved, renamed, or deleted by hand, the log still claims it exists and
    # nothing else would ever notice - the reference simply dangles until
    # someone tries to use the data.
    data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
    
    if (nzchar(data_root) && "filepath" %in% names(dlog)) {
      full_paths <- file.path(data_root, dlog$filepath)
      missing <- !file.exists(full_paths)
      
      if (any(missing)) {
        problem_rows <- dlog[missing, c("timestamp", "station", "filepath")]
        record_violation(
          "MISSING_ARCHIVED_FILE",
          paste(sum(missing), "download log entr(ies) point at files that do not exist"),
          problem_rows
        )
      } else {
        record_pass("archived files exist")
      }
    }
    
    # CHECK: every station in the download log exists in metadata
    if (!is.null(metadata) && "station" %in% names(dlog)) {
      unknown <- !dlog$station %in% metadata$station_id
      
      if (any(unknown)) {
        problem_rows <- dlog[unknown, c("timestamp", "station", "filepath")]
        record_violation(
          "UNKNOWN_DOWNLOAD_STATION",
          paste("Download log references station(s) not in metadata:",
                paste(unique(dlog$station[unknown]), collapse = ", ")),
          problem_rows
        )
      } else {
        record_pass("download log station_ids exist")
      }
    }
  }
  
  # ==========================================================================
  # SUMMARY
  # ==========================================================================
  
  total_checks <- checks_passed + checks_failed
  is_valid <- checks_failed == 0
  
  if (verbose) {
    cat("\n=== Validation Summary ===\n")
    cat("Checks passed:", checks_passed, "/", total_checks, "\n")
    cat("Violations found:", checks_failed, "\n")
    
    if (is_valid) {
      cat("\n✓ All checks passed! Metadata is valid.\n\n")
    } else {
      cat("\n✗ Validation FAILED. Review violations above.\n\n")
    }
  }
  
  summary_text <- paste0(
    "Validation ", ifelse(is_valid, "PASSED", "FAILED"), ": ",
    checks_passed, "/", total_checks, " checks passed, ",
    checks_failed, " violation(s)"
  )
  
  return(list(
    valid = is_valid,
    summary = summary_text,
    checks_passed = checks_passed,
    checks_failed = checks_failed,
    violations = violations
  ))
}


#' Print violation details from validation result
#' 
#' @param result Result from validate_metadata()
#' @param violation_name Optional. Name of specific violation to print.
#'        If NULL, prints all violations.
#' 
print_violations <- function(result, violation_name = NULL) {
  if (result$valid) {
    cat("No violations to display - validation passed!\n")
    return(invisible(NULL))
  }
  
  violations <- result$violations
  
  if (!is.null(violation_name)) {
    if (violation_name %in% names(violations)) {
      violations <- violations[violation_name]
    } else {
      cat("Violation '", violation_name, "' not found.\n", sep = "")
      cat("Available violations:", paste(names(result$violations), collapse = ", "), "\n")
      return(invisible(NULL))
    }
  }
  
  for (name in names(violations)) {
    v <- violations[[name]]
    cat("\n===", name, "===\n")
    cat(v$description, "\n")
    if (!is.null(v$data) && nrow(v$data) > 0) {
      cat("\nAffected rows:\n")
      print(v$data, row.names = FALSE)
    }
  }
  
  return(invisible(NULL))
}


#' Quick validation check - returns TRUE/FALSE only
#' 
#' @return Logical. TRUE if all checks pass, FALSE otherwise.
#' 
is_metadata_valid <- function() {
  result <- validate_metadata(verbose = FALSE)
  return(result$valid)
}
