# Shared interactive prompts
#
# Small, reusable question-askers used by every workflow. Kept apart from the
# workflows themselves so that a prompt which already exists is easy to find -
# five near-identical download-approval prompts once existed because it was
# not.
#
# Requires: setup_functions.R, metadata_functions.R
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return "Y", "N", or "Q" (if allow_quit=TRUE and user quits)
ui_yes_no <- function(prompt, allow_quit = TRUE) {
  repeat {
    if (allow_quit) {
      cat(prompt, "(Y/N or 'q' to quit): ")
    } else {
      cat(prompt, "(Y/N): ")
    }
    
    response <- toupper(trimws(readline()))
    
    # Accept 1 for Y, 2 for N
    if (response == "1") response <- "Y"
    if (response == "2") response <- "N"
    
    if (allow_quit && tolower(response) == "q") {
      return("Q")
    }
    
    if (response %in% c("Y", "N")) {
      return(response)
    }
    
    cat("⚠️  Please enter Y or N\n")
  }
}

#' Prompt user to select from a numbered menu
#' @param prompt Character. Question to ask
#' @param options Character vector. Menu options
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Selected option string, or NULL if user quit
ui_select_from_menu <- function(prompt, options, allow_quit = TRUE) {

  # Station lists run to nearly thirty entries and every station at a site
  # shares a prefix, so they read as one undifferentiated block. Grouping them
  # by site makes the list scannable.
  #
  # Detected from the shape of the options rather than switched on by each of
  # the nine callers that build these lists: a station option looks like
  # "sr1_hydro (Salt River 1)". A device option - "21652379 (Adventure)" -
  # starts with digits and has no underscore, so it is left alone.
  is_station_list <- length(options) > 3 &&
    all(grepl("^[a-z][a-z0-9]*_[a-z0-9]+ \\(.+\\)$", options))

  groups <- if (is_station_list) sub("^.*\\((.+)\\)$", "\\1", options) else NULL

  repeat {
    cat(prompt, "\n", sep = "")
    for (i in seq_along(options)) {
      if (!is.null(groups) && i > 1 && groups[i] != groups[i - 1]) cat("\n")
      cat("  ", i, ". ", options[i], "\n", sep = "")
    }
    
    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }
    
    selection <- trimws(readline())
    
    if (allow_quit && tolower(selection) == "q") {
      return(NULL)
    }
    
    if (grepl("^[0-9]+$", selection)) {
      selection_num <- as.numeric(selection)
      if (selection_num >= 1 && selection_num <= length(options)) {
        return(options[selection_num])
      } else {
        cat("⚠️  Invalid number. Please enter 1-", length(options), "\n", sep = "")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
}

#' Prompt user to select from menu with "other (specify)" option
#' @param prompt Character. Question to ask
#' @param existing_options Character vector. Existing options to show
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Selected/entered value, or NULL if user quit
ui_select_or_specify <- function(prompt, existing_options, allow_quit = TRUE) {
  repeat {
    cat(prompt, "\n", sep = "")
    for (i in seq_along(existing_options)) {
      cat("  ", i, ". ", existing_options[i], "\n", sep = "")
    }
    cat("  ", length(existing_options) + 1, ". other (specify)\n", sep = "")
    
    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }
    
    selection <- trimws(readline())
    
    if (allow_quit && tolower(selection) == "q") {
      return(NULL)
    }
    
    if (grepl("^[0-9]+$", selection)) {
      selection_num <- as.numeric(selection)
      
      if (selection_num >= 1 && selection_num <= length(existing_options)) {
        return(existing_options[selection_num])
      } else if (selection_num == length(existing_options) + 1) {
        # Other - specify custom value
        cat("Enter value: ")
        custom_value <- trimws(readline())
        if (custom_value != "") {
          return(custom_value)
        } else {
          cat("⚠️  Value cannot be empty\n")
        }
      } else {
        cat("⚠️  Invalid number\n")
      }
    } else {
      cat("⚠️  Please enter a number\n")
    }
  }
}

#' Prompt user for a date
#' @param prompt Character. Question to ask
#' @param allow_today Logical. Allow pressing Enter for today (default TRUE)
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return Date string (YYYY-MM-DD) or NULL if quit
ui_prompt_date <- function(prompt, allow_today = TRUE, allow_quit = TRUE) {
  repeat {
    if (allow_today) {
      cat(prompt, " (YYYY-MM-DD)\n")
      cat("Or press Enter for today: ")
    } else {
      cat(prompt, " (YYYY-MM-DD): ")
    }
    
    date_input <- trimws(readline())
    
    if (allow_quit && tolower(date_input) == "q") {
      return(NULL)
    }
    
    if (allow_today && date_input == "") {
      return(as.character(Sys.Date()))
    }
    
    # Try to parse date
    parsed_date <- tryCatch({
      as.Date(date_input)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(parsed_date)) {
      return(as.character(parsed_date))
    }
    
    cat("⚠️  Invalid date format. Please use YYYY-MM-DD\n")
  }
}

#' Prompt user for a datetime
#' @param prompt Character. Question to ask
#' @param allow_now Logical. Allow pressing Enter for now (default TRUE)
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @param timezone Character. Timezone to use (default "America/Puerto_Rico")
#' @return POSIXct datetime or NULL if quit
ui_prompt_datetime <- function(prompt, allow_now = TRUE, allow_quit = TRUE, 
                               timezone = "America/Puerto_Rico") {
  repeat {
    if (allow_now) {
      cat(prompt, " (YYYY-MM-DD HH:MM:SS)\n")
      cat("Or press Enter for now: ")
    } else {
      cat(prompt, " (YYYY-MM-DD HH:MM:SS): ")
    }
    
    datetime_input <- trimws(readline())
    
    if (allow_quit && tolower(datetime_input) == "q") {
      return(NULL)
    }
    
    if (allow_now && datetime_input == "") {
      return(as.POSIXct(Sys.time(), tz = timezone))
    }
    
    # Try to parse datetime
    parsed_datetime <- tryCatch({
      as.POSIXct(datetime_input, format = "%Y-%m-%d %H:%M:%S", tz = timezone)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(parsed_datetime) && !is.na(parsed_datetime)) {
      return(parsed_datetime)
    }
    
    cat("⚠️  Invalid datetime format. Please use YYYY-MM-DD HH:MM:SS\n")
  }
}

#' Display status reference and prompt for status change
#' @param current_status Character. Current status value
#' @param allow_quit Logical. Allow 'q' to quit (default TRUE)
#' @return New status string, or NULL if user quit, or current_status if no change
ui_prompt_status_change <- function(current_status, allow_quit = TRUE, restrict_to_device_level = FALSE) {
  cat("\nCurrent status: ", current_status, "\n", sep = "")
  cat("\nStatus options:\n")
  cat("  online           = working, reports to the cloud over a cellular\n")
  cat("                     connection\n")
  cat("  local            = working, but out of cellular service - data\n")
  cat("                     reaches the cloud only when offloaded on site\n")
  cat("                     (e.g. Bluetooth) and uploaded\n")
  cat("  manual           = working, no cloud at all - data comes off by\n")
  cat("                     shuttle or cable and is archived by hand\n")
  cat("  defunct          = broken but still deployed\n")
  cat("  nonresponsive    = should be communicating with the cloud but is\n")
  cat("                     not, for an unknown reason\n")
  
  if (!restrict_to_device_level) {
    # Show all statuses
    cat("  replaced         = swapped for new device\n")
    cat("  relocated        = station moved\n")
    cat("  decommissioned   = station shut down\n")
  } else {
    cat("\n  Note: For replacement/relocation/decommissioning, use those workflows\n")
  }
  
  cat("\n")
  
  change_response <- ui_yes_no("Change status?", allow_quit = allow_quit)
  
  if (is.null(change_response) || change_response == "Q") {
    return(NULL)
  }
  
  if (change_response == "N") {
    return(current_status)
  }
  
  # Build allowed status list
  if (restrict_to_device_level) {
    allowed_statuses <- c("online", "local", "manual", "defunct", "nonresponsive")
  } else {
    allowed_statuses <- get_metadata_unique_values("status")
  }
  
  new_status <- ui_select_or_specify("Select new status:", allowed_statuses, 
                                     allow_quit = allow_quit)
  
  return(new_status)
}

################################################################################
#### CONSOLE UI MAIN FUNCTIONS ####
################################################################################
# These are the main interactive functions that users call
# Each handles a specific workflow

#' Prompts for a device status, in a deliberate order, with meanings
#'
#' The generic picker sorted whatever statuses happened to exist in the
#' metadata alphabetically, which put "defunct" first and offered no clue what
#' any of them meant. Statuses are a fixed vocabulary, so they are listed here
#' explicitly rather than discovered - a new status should be a considered
#' addition, not something that appears because someone typed it once.
#'
#' Terminal statuses (replaced, relocated, decommissioned) are deliberately
#' absent: those are set by their own workflows, which log the event.
#'
#' @param allow_quit Logical. Allow 'q' to cancel (default TRUE)
#' @return Status string, or NULL if cancelled
ui_prompt_device_status <- function(allow_quit = TRUE) {

  statuses <- c("manual", "online", "local", "nonresponsive", "defunct")

  meanings <- c(
    manual        = "no cloud at all - data comes off by shuttle or cable",
    online        = "reports to the cloud over a cellular connection",
    local         = "out of cellular service - reaches the cloud when offloaded on site",
    nonresponsive = "should be communicating with the cloud but is not",
    defunct       = "broken or lost, but still deployed"
  )

  repeat {
    cat("\nSelect device status:\n")
    for (i in seq_along(statuses)) {
      cat("  ", i, ". ", format(statuses[i], width = 14), " ",
          meanings[statuses[i]], "\n", sep = "")
    }
    cat("  ", length(statuses) + 1, ". other (specify)\n", sep = "")

    if (allow_quit) {
      cat("\nEnter selection (or 'q' to quit): ")
    } else {
      cat("\nEnter selection: ")
    }

    choice <- trimws(readline())

    if (allow_quit && tolower(choice) == "q") return(NULL)

    if (grepl("^[0-9]+$", choice)) {
      n <- as.numeric(choice)

      if (n >= 1 && n <= length(statuses)) return(statuses[n])

      if (n == length(statuses) + 1) {
        cat("Enter status: ")
        custom <- tolower(trimws(readline()))
        if (custom == "") {
          cat("⚠️  Status cannot be empty\n")
          next
        }
        # A status outside the vocabulary will fail validate_metadata(), so
        # say that now rather than letting it surface later.
        cat("\n⚠️  '", custom, "' is not one of the known statuses. It will be\n",
            "   reported as a violation by validate_metadata() until it is\n",
            "   added to the valid list in validation_functions.R.\n", sep = "")
        if (ui_yes_no("Use it anyway?", allow_quit = FALSE) == "Y") return(custom)
        next
      }
    }

    cat("⚠️  Invalid selection\n")
  }
}

#' Asks whether a station may be downloaded automatically
#'
#' download_approved is a safety interlock for the automated download job: it
#' sits FALSE, a human sets it TRUE to say "the metadata for this station is
#' current", and the job resets it after running.
#'
#' It means ONE thing - that the record is up to date. It does NOT mean "there
#' is new data worth fetching". Those coincide for a cell-connected station and
#' come apart for a local one, whose metadata can be perfectly current while
#' the cloud has nothing new because the upload is still on someone's phone.
#' Conflating them makes the question unanswerable.
#'
#' A redundant download is not harmful - it costs a duplicate file, which
#' check_raw_overlap() reports - so data availability is not worth gating on.
#'
#' Shared by every workflow that asks, because the same rule living in several
#' places is how one of them ends up out of date.
#'
#' @param station_id Character
#' @param device_row One row of device metadata, for the status check
#' @param apply Logical. Write the answer immediately (default TRUE). Pass
#'   FALSE where the row being approved does not exist yet - relocation
#'   collects values for a row it creates later, and writing here would set
#'   the flag on the row about to go terminal, before the user has even
#'   confirmed the move
#' @return TRUE if approved, FALSE otherwise
ui_prompt_download_approval <- function(station_id, device_row, apply = TRUE) {

  if (tolower(device_row$status) == "manual") {
    cat("\n\u2713 Status is 'manual' - skipping download approval",
        " (data is offloaded by hand)\n", sep = "")
    return(invisible(FALSE))
  }

  cat("\n--- DOWNLOAD APPROVAL ---\n\n")
  cat("Is everything you know about this station now recorded in metadata?\n")
  cat("Say no if a sensor swap, device change or port reconfiguration is\n")
  cat("still to be logged - an automated download would file data against\n")
  cat("a record that is wrong.\n\n")
  cat("Not about whether new data exists. The flag resets after each run.\n")

  response <- ui_yes_no("\nApprove for download?", allow_quit = FALSE)

  if (response != "Y") {
    cat("\u2713 Not approved - approve it once the record is complete\n")
    return(invisible(FALSE))
  }

  if (!apply) return(invisible(TRUE))

  result <- update_download_approval(station_id, TRUE)
  if (!isTRUE(result)) {
    cat("\u26a0\ufe0f  Warning: could not update download approval: ", result, "\n",
        sep = "")
    return(invisible(FALSE))
  }

  cat("\u2713 Station approved for download\n")
  invisible(TRUE)
}


################################################################################
