# metadata_manager_functions.R
# The metadata manager: every interactive workflow, and the menu that leads to
# them - metadata_manager() at the bottom of the file.
#
# The workflows ask and confirm; the saving is done by the functions in
# metadata_functions.R and survey_functions.R, which take values and never
# prompt, so a future interface could call them directly.

################################################################################

#  INTERACTIVE WORKFLOWS
################################################################################

# --- MAINTENANCE & LOGGING ---
#' Interactive maintenance logging - SIMPLIFIED for routine maintenance only
#' Logs a maintenance entry and updates metadata as needed
#' Relocation, device replacement, and port changes are separate workflows
#' @return List with device_serial, station_id, action_type, or NULL if quit
ui_log_maintenance <- function(prefill_station = NULL, prefill_device = NULL,
                               prefill_visit_date = NULL,
                               prefill_logged_by = NULL) {
  cat("\n============================================\n")
  cat("  Routine Maintenance Logger\n")
  cat("============================================\n\n")
  
  #### Prefilled from a download on the same visit? ####
  # Called straight after logging a download, the station, device, date and
  # initials are all already known. Re-asking for them is three menus of
  # keystrokes to arrive at the same answer, and every one is a chance to pick
  # the wrong logger.
  prefilled <- !is.null(prefill_station) && !is.null(prefill_device)

  if (prefilled) {
    field_visit_date <- prefill_visit_date
    station_id       <- prefill_station
    device_serial    <- prefill_device

    station_devices <- get_active_devices_or_notify(station_id, "maintenance logging")
    if (is.null(station_devices)) return(NULL)
    station_devices <- order_devices_by_role(station_devices)
    station_type <- station_devices$station_type[1]

    this_row <- station_devices[station_devices$device_serial == device_serial, ]

    cat("Carried over from the download you just logged:\n\n")
    cat("  Date:    ", format(as.Date(field_visit_date)), "\n", sep = "")
    cat("  Station: ", station_id, "\n", sep = "")
    cat("  Device:  ",
        if (nrow(this_row) > 0) device_label(this_row[1, ], with_role = TRUE)
        else device_serial, "\n\n", sep = "")

  } else {

  #### 1 - Field visit date
  field_visit_date <- ui_prompt_date("When did you visit the field?")
  if (is.null(field_visit_date)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  cat("✓ Field visit date:", field_visit_date, "\n\n")
  
  #### 2 - Station selection
  # Live stations by default, retired behind one key. Offloading a logger that
  # has just come out of a decommissioned station is ordinary work, but it is
  # rare - and a list of thirty-nine to reach one of two is a list nobody
  # reads. What matters is not whether the station is alive but whether the
  # readings fall inside its deployment, which the ingest checks later.
  live_list <- get_station_list()
  all_list  <- get_station_list(include_retired = TRUE)

  as_option <- function(s) paste0(s$station_id, " (", s$label, ")")
  station_options <- vapply(live_list, as_option, character(1), USE.NAMES = FALSE)
  retired_options <- vapply(
    all_list[setdiff(names(all_list), names(live_list))],
    as_option, character(1), USE.NAMES = FALSE)

  selected <- ui_select_from_menu(
    "Select station:", station_options,
    extra_key = "r", extra_label = "Show retired stations",
    extra_options = retired_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id from selection
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_active_devices_or_notify(station_id, "maintenance logging")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  # Labeled with the HOBOware name where there is one - a serial alone means
  # nothing to someone deciding which of two loggers they worked on.
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  device_serial <- station_devices$device_serial[match(selected_device, device_options)]
  cat("✓ Device:", device_label(device_serial), "\n")

  }  # end of the non-prefilled path
  
  #### 4 - Action type (ROUTINE MAINTENANCE ONLY)
  # Declared, not discovered. The previous version listed four standard actions
  # and then appended every action_type ever seen in the log, minus an
  # exclusion list. That list could never keep up: the moment a workflow wrote
  # a new type - station_established, device_added - it appeared here as
  # something a human could hand-log, which only a workflow should ever write.
  #
  # Listing what a person MAY choose inverts that. A new workflow-generated
  # type cannot leak in by accident, because nothing is discovered at all.
  action_options <- c(
    "inspection only"     = "inspection",
    "cleaning"            = "cleaning",
    "maintenance"         = "maintenance",
    "battery replacement" = "battery"
  )
  
  # Relaunching is a HOBO concept - a Zentra is not launched and relaunched -
  # so it is not offered where it cannot apply, rather than labeled and left
  # for the user to filter.
  device_meta <- load_zentra_metadata()
  this_device <- device_meta[device_meta$device_serial == device_serial, ]
  
  if (nrow(this_device) > 0 && is_hobo_device(this_device$mfger[1])) {
    action_options <- c(action_options, "relaunch" = "logger_relaunch")
  }
  
  # From the list only: an action typed in would be one MAINTENANCE_ACTIONS
  # does not know, and validation refuses it
  action_type <- ui_select_from_menu("What action was performed?",
                                     names(action_options))
  if (is.null(action_type)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  action_type <- unname(action_options[action_type])
  cat("✓ Action:", action_type, "\n")
  
  #### 5 - Details
  # "inspection" with nothing else said means the station was as it should be.
  # Offered on Enter, shown explicitly so it is a stated finding rather than
  # an empty field.
  default_note <- if (action_type == "inspection") "In good order" else NULL

  cat("\nEnter details (one line):\n")
  if (!is.null(default_note)) {
    cat("  Press Enter for: ", default_note, "\n", sep = "")
  }
  details <- trimws(readline())
  if (details == "" && !is.null(default_note)) details <- default_note
  cat("✓ Details: ", details, "\n", sep = "")
  
  #### 6 - Who logged this?
  if (prefilled && !is.null(prefill_logged_by)) {
    logged_by <- prefill_logged_by
    cat("\n✓ Logged by:", logged_by, "(carried over)\n")
  } else {
  logged_by <- ui_ask_whois_logging()
  cat("✓ Logged by:", logged_by, "\n")
  }  # end of the non-prefilled logged_by path
  
  #### 7 - Status update (uses helper function for consistency)
  # The chosen logger's own status - at a paired gauge the first row is the
  # primary, and the change applies to the logger picked
  current_status <- station_devices$status[station_devices$device_serial == device_serial][1]
  new_status <- ui_prompt_status_change(current_status, allow_quit = TRUE)
  
  if (is.null(new_status)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  if (new_status != current_status) {
    cat("✓ New status:", new_status, "\n")
  } else {
    cat("✓ Status unchanged:", current_status, "\n")
  }
  
  #### 8 - Logger settings, at a relaunch
  # Relaunching is the only moment a HOBO's name and interval can change, and
  # both live in metadata that nothing else updates. Asking here, while the
  # visit is being logged, is the difference between a record that stays true
  # and one that quietly drifts from the device on the riverbed. Asked before
  # the confirmation, so everything the entry will save is shown at once
  new_name <- NULL
  new_interval <- NULL
  old_name <- NA
  old_interval <- NA
  if (action_type == "logger_relaunch") {
    meta_now <- load_zentra_metadata()
    d_idx <- which(meta_now$device_serial == device_serial &
                   meta_now$station_id == station_id &
                   !meta_now$status %in% TERMINAL_STATUSES)
    if (length(d_idx) > 0) {
      d_idx <- d_idx[1]
      old_name <- meta_now$device_name[d_idx]
      cat("\n--- LOGGER SETTINGS ---\n\n")
      cat("Current name in HOBOware: ", blank_or_value(old_name), "\n", sep = "")
      if (ui_yes_no("Did you rename the logger?", allow_quit = FALSE) == "Y") {
        cat("Enter the new name exactly as set in HOBOware: ")
        typed <- trimws(readline())
        # A logger never named has NA for its old name, which compares as
        # neither equal nor different - identical() says which it is
        if (nzchar(typed) && !identical(typed, old_name)) new_name <- typed
      }

      old_interval <- meta_now$interval_min[d_idx]
      cat("\nCurrent logging interval: ", blank_or_value(old_interval),
          " minutes\n", sep = "")
      if (ui_yes_no("Did you change the logging interval?", allow_quit = FALSE) == "Y") {
        repeat {
          cat("Enter the new interval in minutes: ")
          typed <- suppressWarnings(as.numeric(trimws(readline())))
          if (!is.na(typed) && typed > 0) break
          cat("\u26a0\ufe0f  Must be a positive number\n")
        }
        if (!identical(as.numeric(typed), as.numeric(old_interval))) new_interval <- typed
      }
    }
  }

  #### 9 - Confirmation
  cat("\n============================================\n")
  cat("Ready to log this maintenance entry:\n")
  cat("  Date:", format(field_visit_date), "\n")
  cat("  Station:", station_id, "\n")
  cat("  Device:", device_label(device_serial), "\n")
  cat("  Action:", action_type, "\n")
  cat("  Details:", details, "\n")
  cat("  Logged by:", logged_by, "\n")
  if (new_status != current_status) {
    cat("  Status change: ", current_status, " \u2192 ", new_status, "\n", sep = "")
  } else {
    cat("  Status: ", current_status, " (unchanged)\n", sep = "")
  }
  if (!is.null(new_name)) {
    cat("  Name: ", blank_or_value(old_name), " \u2192 ", new_name, "\n", sep = "")
  }
  if (!is.null(new_interval)) {
    cat("  Interval: ", blank_or_value(old_interval), " \u2192 ", new_interval,
        " minutes\n", sep = "")
  }
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Canceled - no entry logged\n")
    return(NULL)
  }
  
  #### 10 - Write: the entry, the visit, any status and settings, as one change
  # A visit logged without its status change, or a rename saved without the
  # entry that explains it, is half an entry
  result <- tryCatch(with_metadata_change("logging maintenance", local({
    out <- create_maintenance_entry(
      field_visit_date = field_visit_date,
      station_id = station_id,
      device_serial = device_serial,
      action_type = action_type,
      details = details,
      logged_by = logged_by
    )
    if (!isTRUE(out)) return(out)
    out <- update_last_visit(station_id, field_visit_date)
    if (!isTRUE(out)) return(out)
    if (new_status != current_status) {
      out <- update_device_status(device_serial, new_status, station_id = station_id)
      if (!isTRUE(out)) return(out)
    }
    if (!is.null(new_name) || !is.null(new_interval)) {
      meta_now <- load_zentra_metadata()
      d_idx <- which(meta_now$device_serial == device_serial &
                     meta_now$station_id == station_id &
                     !meta_now$status %in% TERMINAL_STATUSES)[1]
      if (!is.null(new_name)) meta_now$device_name[d_idx] <- new_name
      if (!is.null(new_interval)) meta_now$interval_min[d_idx] <- new_interval
      save_device_metadata(meta_now)
      # A rename is its own event - it explains why an older shuttle
      # readout's filenames no longer match the names in metadata
      if (!is.null(new_name)) {
        out <- create_maintenance_entry(
          field_visit_date = field_visit_date,
          station_id       = station_id,
          device_serial    = device_serial,
          action_type      = "device_renamed",
          details          = paste0("Renamed from '", blank_or_value(old_name),
                                    "' to '", new_name, "' at relaunch"),
          logged_by        = logged_by
        )
        if (!isTRUE(out)) return(out)
      }
    }
    TRUE
  })), error = function(e) conditionMessage(e))

  if (!isTRUE(result)) {
    cat("❌ Not logged - ", result, "\n   Nothing was saved.\n", sep = "")
    return(NULL)
  }
  cat("✓ Maintenance entry logged\n")
  cat("✓ Updated last_visit\n")
  if (new_status != current_status) cat("✓ Updated status to:", new_status, "\n")
  if (!is.null(new_name)) cat("\u2713 Name: ", blank_or_value(old_name), " -> ", new_name,
                              " (rename logged)\n", sep = "")
  if (!is.null(new_interval)) cat("\u2713 Interval: ", blank_or_value(old_interval), " -> ",
                                  new_interval, " minutes\n", sep = "")
  
  #### 11 - Metadata review
  # Get device info to check status
  device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
  
  ui_prompt_metadata_approval(station_id)
  
  cat("\n✓ All done!\n")
  
  # Return info (removed ports_updated since always FALSE)
  return(list(
    device_serial = device_serial,
    station_id = station_id,
    action_type = action_type
  ))
}

#' Interactive download logging
#' Logs manual data download (for HOBO or local Zentra devices)
#' Simpler than routine maintenance - focused on download event
#' @return List with device_serial, station_id, or NULL if quit
ui_log_download <- function() {
  cat("\n============================================\n")
  cat("  Manual Download Logger\n")
  cat("============================================\n\n")
  
  #### 1 - Field visit date
  field_visit_date <- ui_prompt_date("When did you download data?")
  if (is.null(field_visit_date)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  cat("✓ Download date:", field_visit_date, "\n\n")
  
  #### 2 - Station selection
  # Live stations by default, retired behind one key. Offloading a logger that
  # has just come out of a decommissioned station is ordinary work, but it is
  # rare - and a list of thirty-nine to reach one of two is a list nobody
  # reads. What matters is not whether the station is alive but whether the
  # readings fall inside its deployment, which the ingest checks later.
  live_list <- get_station_list()
  all_list  <- get_station_list(include_retired = TRUE)

  as_option <- function(s) paste0(s$station_id, " (", s$label, ")")
  station_options <- vapply(live_list, as_option, character(1), USE.NAMES = FALSE)
  retired_options <- vapply(
    all_list[setdiff(names(all_list), names(live_list))],
    as_option, character(1), USE.NAMES = FALSE)

  selected <- ui_select_from_menu(
    "Select station:", station_options,
    extra_key = "r", extra_label = "Show retired stations",
    extra_options = retired_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id from selection
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_active_devices_or_notify(station_id, "download logging")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  station_type <- station_devices$station_type[1]
  cat("✓ Station:", station_id, "(", station_type, ")\n")
  
  #### 3 - Device selection
  # Labeled with the HOBOware name where there is one - a serial alone means
  # nothing to someone deciding which of two loggers they worked on.
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("Select device:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  device_serial <- station_devices$device_serial[match(selected_device, device_options)]
  cat("✓ Device:", device_label(device_serial), "\n")
  
  #### 4 - Download details
  # A default offered on Enter, shown explicitly so it cannot be given by
  # accident without having been read. Only for HOBO devices - a shuttle is
  # not how a Zentra's data comes off.
  this_dev <- station_devices[station_devices$device_serial == device_serial, ]
  default_details <- if (nrow(this_dev) > 0 && is_hobo_device(this_dev$mfger[1])) {
    "shuttle download"
  } else {
    NULL
  }

  cat("\nEnter download details (one line):\n")
  cat("  Describe the DOWNLOAD only - how the data came off, and anything\n")
  cat("  that bears on reading the record.\n")
  cat("  Maintenance you did on the same visit gets its own entry - you will\n")
  cat("  be asked about it next.\n")
  if (!is.null(default_details)) {
    cat("  Press Enter for: ", default_details, "\n", sep = "")
  } else {
    cat("  (e.g. 'Bluetooth to phone, uploaded same day')\n")
  }
  details <- trimws(readline())
  if (details == "") {
    details <- if (!is.null(default_details)) default_details else "Manual download"
  }
  cat("✓ Details: ", details, "\n", sep = "")
  
  #### 5 - Who logged this?
  logged_by <- ui_ask_whois_logging()
  cat("✓ Logged by:", logged_by, "\n")
  
  #### 6 - Confirmation
  cat("\n============================================\n")
  cat("Ready to log this download:\n")
  cat("  Date:", field_visit_date, "\n")
  cat("  Station:", station_id, "\n")
  cat("  Device:", device_label(device_serial), "\n")
  cat("  Details:", details, "\n")
  cat("  Logged by:", logged_by, "\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Canceled - no entry logged\n")
    return(NULL)
  }
  
  #### 7 - Write maintenance entry
  result <- create_maintenance_entry(
    field_visit_date = field_visit_date,
    station_id = station_id,
    device_serial = device_serial,
    action_type = "download",
    details = details,
    logged_by = logged_by
  )
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Download entry logged\n")
  
  #### 8 - Update last_visit
  result <- update_last_visit(station_id, field_visit_date)
  if (!isTRUE(result)) {
    cat("⚠️  Warning: Could not update last_visit:", result, "\n")
  } else {
    cat("✓ Updated last_visit\n")
  }
  
  # The download itself is recorded in download_log.csv when the file is
  # archived; the device table keeps no copy of when it happened

  #### 10 - Metadata review / cloud upload
  # Get device info to check status
  device_row <- station_devices[station_devices$device_serial == device_serial, ][1, ]
  device_status <- tolower(device_row$status)
  
  # 'manual' needs nothing here - its data is archived directly in step 11.
  # Note the metadata review below is NOT skipped for manual stations: it
  # asserts the record is accurate, which matters for attribution whatever
  # route the data took to get here.
  if (device_status == "local") {
    # Local stations reach ZentraCloud, but only because someone offloads on
    # site and uploads afterwards. Until that upload happens the data exists
    # nowhere but the field device, and there is no point approving a download
    # of data the cloud does not have yet.
    cat("\n--- CLOUD UPLOAD ---\n\n")
    cat("This station is out of cellular service, so its data reaches\n")
    cat("ZentraCloud only when you upload what you offloaded on site.\n\n")
    
    uploaded <- ui_yes_no("Have you uploaded this data to ZentraCloud?",
                          allow_quit = FALSE)
    
    if (uploaded == "N") {
      cat("\nUntil the upload happens, this data exists only on the field\n")
      cat("device. Upload it as soon as you can.\n\n")
      
      add_pending_ingest(station_id, device_serial, field_visit_date,
                         logged_by, "awaiting_cloud_upload",
                         notes = "Offloaded on site, not yet uploaded to ZentraCloud")
      
      cat("✓ Recorded as unfinished - you will be reminded every time you\n")
      cat("  open the metadata manager.\n")
    }
    
    # The upload question is about where the DATA is. The metadata review is
    # about whether the METADATA is current. They are separate questions and
    # this branch used to answer the second with the first, which made the
    # flag mean two things at once and neither reliably.
  }
  
  ui_prompt_metadata_approval(station_id)
  
  #### 11 - Archive the data (manual stations only)
  # The field record is now written and stays true regardless of what happens
  # next. Archiving is a separate matter, and if it cannot be completed the
  # ingest workflow records a pending row rather than abandoning quietly.
  if (device_status == "manual") {
    ui_ingest_local_data(
      station_id       = station_id,
      device_serial    = device_serial,
      station_type     = station_type,
      mfger            = device_row$mfger,
      field_visit_date = field_visit_date,
      logged_by        = logged_by
    )
  }
  
  cat("\n✓ All done!\n")
  
  # Return enough for a maintenance entry on the same visit to be prefilled
  return(list(
    device_serial    = device_serial,
    station_id       = station_id,
    field_visit_date = field_visit_date,
    logged_by        = logged_by
  ))
}

#' Interactive explanation of readings that belong to no station
#'
#' Two kinds of thing need explaining, and both are offered rather than typed:
#'
#'   - a logger VI-FLO has no row for - on the ZentraCloud account, or only in
#'     the archive - explained whole, with the choice of whether the download
#'     job keeps archiving it
#'   - an unexplained period the last builds found on a logger VI-FLO does
#'     know - its ports and dates filled in from the build
#'
#' Each becomes a row of known_unattributed.csv, a checked save. Whatever is
#' left unexplained stays on the to-do list and in the build's report, so the
#' file keeps up rather than drifting.
#'
#' @param devices ZentraCloud device list (zc_list_devices); fetched if NULL
#' @return TRUE if a row was added, NULL if canceled
ui_explain_unattributed <- function(devices = NULL) {
  cancel <- function(msg = "Canceled - nothing recorded") {
    cat("\n\u274c ", msg, "\n", sep = "")
    invisible(NULL)
  }

  cat("\n============================================\n")
  cat("  Explain Unattributed Readings\n")
  cat("============================================\n\n")
  cat("Readings that belong to no station, explained once so they stop being\n")
  cat("asked about. Recorded in known_unattributed.csv.\n\n")

  meta <- load_zentra_metadata()
  known <- load_known_unattributed()
  if (is.null(devices)) {
    devices <- tryCatch(zc_call("zc_list_devices", expand = "max_min_timestamp"),
                        error = function(e) NULL)
  }
  if (is.null(devices)) {
    cat("\u26a0\ufe0f  ZentraCloud could not be reached - only loggers in the archive are offered\n\n")
  }

  #### What needs explaining ####
  whole_known <- known_unattributed_loggers()
  on_cloud <- if (is.null(devices)) character(0) else
    setdiff(devices$device_id, c(meta$device_serial, whole_known))
  dl <- tryCatch(load_download_log(), error = function(e) NULL)
  archive_only <- if (is.null(dl)) character(0) else
    setdiff(unique(dl$device_serial[!is.na(dl$device_serial)]),
            c(meta$device_serial, whole_known, if (!is.null(devices)) devices$device_id))
  periods <- load_unexplained()

  opts <- character(0); what <- list()
  for (sn in on_cloud) {
    opts <- c(opts, paste0(device_label(sn, meta = meta[0, ], devices = devices), " - on ZentraCloud, no metadata row"))
    what[[length(what) + 1]] <- list(kind = "logger", serial = sn, name = device_display_name(sn, meta = meta[0, ], devices = devices))
  }
  for (sn in sort(archive_only)) {
    opts <- c(opts, paste0(sn, " - in the archive only, no metadata row"))
    what[[length(what) + 1]] <- list(kind = "logger", serial = sn, name = NA_character_)
  }
  d <- function(x) format(x, "%Y-%m-%d", tz = PROJECT_TZ)
  for (i in seq_len(nrow(periods))) {
    p <- periods[i, ]
    nm <- device_display_name(p$device_serial, meta)
    opts <- c(opts, sprintf("%s %s - %s to %s, %s moments", device_label(p$device_serial, meta = meta),
                            if (nzchar(p$ports)) paste("ports", p$ports) else "",
                            d(p$first), d(p$last), format(p$moments, big.mark = ",")))
    what[[length(what) + 1]] <- list(kind = "period", serial = p$device_serial, name = nm,
                                     first = p$first, last = p$last)
  }
  if (length(opts) == 0) {
    cat("\u2713 Nothing waiting to be explained.\n")
    return(invisible(NULL))
  }

  pick <- ui_select_from_menu("Which?", opts)
  if (is.null(pick)) return(cancel())
  w <- what[[match(pick, opts)]]

  cat("\nWhy do these readings belong to no station? One line, for whoever\n")
  cat("reads this next (e.g. 'not VI-FLO - a colleague's experiment'):\n")
  reason <- ""
  while (!nzchar(reason)) {
    reason <- trimws(readline())
    if (tolower(reason) == "q") return(cancel())
  }

  archive <- NA
  if (w$kind == "logger") {
    cat("\n")
    a <- ui_yes_no("Keep archiving its readings when the download job runs?", allow_quit = TRUE)
    if (a == "Q") return(cancel())
    archive <- a == "Y"
  }

  # A period covers exactly what the build found: its first reading to just
  # past its last, all ports - no wider, so nothing later hides inside it
  row <- data.frame(
    device_serial = w$serial, device_name = w$name, port = NA_integer_,
    from = if (w$kind == "period") as.POSIXct(w$first, tz = PROJECT_TZ)
           else as.POSIXct(NA, tz = PROJECT_TZ),
    to   = if (w$kind == "period") as.POSIXct(w$last, tz = PROJECT_TZ) + 60
           else as.POSIXct(NA, tz = PROJECT_TZ),
    reason = reason, archive = archive, stringsAsFactors = FALSE)

  cat("\n============================================\n")
  cat("  ", pick, "\n", sep = "")
  cat("  Reason: ", reason, "\n", sep = "")
  if (w$kind == "logger") {
    cat("  Archive it: ", if (archive) "yes" else if (w$serial %in% on_cloud)
      "no - the job stops downloading it" else "no", "\n", sep = "")
  }
  cat("============================================\n\n")
  if (ui_yes_no("Record this?", allow_quit = FALSE) != "Y") return(cancel())

  res <- tryCatch(write_table_or_stop("known_unattributed", rbind(known, row),
                                      intent = "explaining unattributed readings"),
                  error = function(e) conditionMessage(e))
  if (!isTRUE(res)) return(cancel(res))
  cat("\u2713 Recorded - it will no longer be asked about\n")
  invisible(TRUE)
}


#' Interactive field survey workflow
#'
#' Everything measured in the field with an instrument or a tape is recorded
#' in surveys.csv, as a distance between two named points. This menu leads to
#' the three ways of recording one, and to removing a row entered by mistake.
#'
#' @return TRUE if something was saved, NULL if canceled
ui_survey_elevations <- function() {
  cat("\n============================================\n")
  cat("  Field Survey\n")
  cat("============================================\n\n")
  cat("Measurements taken in the field. Each is recorded as how far one\n")
  cat("point sits above another - a sensor above the bed, one logger's\n")
  cat("rebar top above another's - so nothing assumes a reference.\n\n")

  cat("What was surveyed?\n")
  cat("  1. Paired stream gauge - fall and reach between two loggers\n")
  cat("  2. One logger - a height: sensor, rebar, overflow, or another point\n")
  cat("  3. One logger - ground elevation by GNSS\n")
  cat("  4. Remove a survey row entered by mistake\n")
  cat("  q. Cancel\n\n")
  cat("Enter selection: ")

  choice <- tolower(trimws(readline()))
  switch(choice,
         "1" = ui_survey_gut_pair(),
         "2" = ui_survey_measurement(),
         "3" = ui_survey_ground_elevation(),
         "4" = ui_remove_survey(),
         "q" = { cat("❌ Canceled\n"); invisible(NULL) },
         { cat("⚠️  Invalid selection\n"); invisible(NULL) })
}


#' Date and initials, asked the same way by every survey
#'
#' @return List: survey_date, logged_by; or NULL if canceled
survey_ask_when_who <- function() {
  survey_date <- ui_prompt_date("When was this survey performed?", allow_today = TRUE)
  if (is.null(survey_date)) return(NULL)
  cat("✓ Survey date: ", survey_date, "\n", sep = "")

  logged_by <- ui_ask_whois_logging()
  cat("✓ Logged by: ", logged_by, "\n\n", sep = "")
  list(survey_date = survey_date, logged_by = logged_by)
}


#' A current logger, chosen by station and then device
#'
#' @param metadata Data frame of device rows
#' @param types Character. Station types offered, or NULL for all
#' @return One device row, or NULL if canceled
survey_pick_logger <- function(metadata, types = NULL) {
  current <- metadata[!tolower(metadata$status) %in% TERMINAL_STATUSES, ]
  if (!is.null(types)) current <- current[tolower(current$station_type) %in% types, ]
  stations <- sort(unique(current$station_id))
  if (length(stations) == 0) { cat("❌ No current stations\n"); return(NULL) }

  station_options <- vapply(stations, function(sid) {
    n <- sum(current$station_id == sid)
    paste0(sid, " (", current$site_full[current$station_id == sid][1], " - ",
           n, " current device", if (n != 1) "s", ")")
  }, character(1), USE.NAMES = FALSE)
  pick <- ui_select_from_menu("Select station:", station_options)
  if (is.null(pick)) return(NULL)
  station_id <- sub(" \\(.*\\)$", "", pick)
  cat("✓ Station: ", station_id, "\n", sep = "")

  here <- order_devices_by_role(current[current$station_id == station_id, ])
  if (nrow(here) == 1) {
    dev <- here[1, ]
  } else {
    labels <- vapply(seq_len(nrow(here)), function(i)
      device_label(here[i, ], with_role = TRUE), character(1))
    d_pick <- ui_select_from_menu("Which device?", labels)
    if (is.null(d_pick)) return(NULL)
    dev <- here[which(labels == d_pick)[1], ]
  }
  cat("✓ Device: ", device_label(dev, with_role = TRUE), "\n\n", sep = "")
  dev
}


#' What a logger already has surveyed, printed
survey_show_current <- function(unique_id, metadata, surveys) {
  have <- latest_surveys(unique_id, surveys)
  if (nrow(have) == 0) {
    cat("Nothing surveyed on this logger yet.\n\n")
  } else {
    cat("Already surveyed on this logger (newest of each):\n")
    for (i in seq_len(nrow(have))) {
      cat("  ", describe_survey_row(have[i, ], metadata), "\n", sep = "")
    }
    cat("\n")
  }
}


# What each point is, for the menus
SURVEY_POINT_LABELS <- c(
  sensor   = "sensor   - the logger's measuring point",
  rebar    = "rebar    - the top of the logger's rebar",
  overflow = "overflow - where the pool spills (gauge of zero flow)",
  bed      = "bed      - the streambed or pond bed at the logger",
  ground   = "ground   - the ground at the station's coordinates"
)

# How it was measured, for the menus
SURVEY_METHOD_LABELS <- c(
  tape    = "tape    - tape measure or ruler",
  level   = "level   - builder's level and rod",
  laser   = "laser   - TruPulse or other rangefinder",
  nominal = "nominal - a standard value, not measured"
)

#' Asks how something was measured
#' @param offer Character. Methods to offer, in order
#' @return One of SURVEY_METHODS, or NULL if canceled
survey_ask_method <- function(offer = SURVEY_METHODS) {
  pick <- ui_select_from_menu("How was it measured?", unname(SURVEY_METHOD_LABELS[offer]))
  if (is.null(pick)) return(NULL)
  m <- offer[SURVEY_METHOD_LABELS[offer] == pick]
  cat("✓ Method: ", m, "\n", sep = "")
  m
}


#' Interactive survey of one logger: the height between two points
#'
#' Asked the way it is measured in the field: which two points, which of them
#' is higher, and by how much - always a positive number, so there is no
#' direction to get backwards. One point is on this logger; the other is on
#' this logger too, or on another logger at the same station. The sensor and
#' the bed are the commonest pair; the rebar top, the pool's overflow and the
#' ground can be measured the same way, against whatever the instrument was
#' actually set on.
#'
#' @return TRUE if saved, NULL if canceled
ui_survey_measurement <- function() {

  cancel <- function(msg = "Canceled - nothing saved") {
    cat("\n\u274c ", msg, "\n", sep = "")
    invisible(NULL)
  }

  cat("\n--- ONE LOGGER: A MEASURED HEIGHT ---\n\n")
  cat("The height between two points. Nothing is saved until the end, and\n")
  cat("'q' at any prompt cancels.\n\n")

  ww <- survey_ask_when_who()
  if (is.null(ww)) return(cancel())

  metadata <- load_zentra_metadata()
  surveys <- load_surveys()
  dev <- survey_pick_logger(metadata, types = c("hydro", "pond", "weather"))
  if (is.null(dev)) return(cancel())
  survey_show_current(dev$unique_id, metadata, surveys)

  #### The two points ####
  weather <- tolower(dev$station_type) == "weather"
  mine <- if (weather) c("sensor", "ground") else c("sensor", "bed", "rebar", "overflow", "ground")
  pick <- ui_select_from_menu("Which two points? The first, on this logger:",
                              unname(SURVEY_POINT_LABELS[mine]))
  if (is.null(pick)) return(cancel())
  p1 <- mine[SURVEY_POINT_LABELS[mine] == pick]
  cat("\u2713 First point: ", p1, "\n\n", sep = "")

  rest <- setdiff(mine, p1)
  rest_labels <- unname(SURVEY_POINT_LABELS[rest])
  others <- metadata[!tolower(metadata$status) %in% TERMINAL_STATUSES &
                       metadata$station_id == dev$station_id &
                       metadata$unique_id != dev$unique_id, ]
  if (nrow(others) > 0) rest_labels <- c(rest_labels, "a point on another logger at this station")
  pick2 <- ui_select_from_menu("And the second:", rest_labels)
  if (is.null(pick2)) return(cancel())
  id2 <- dev$unique_id
  if (pick2 == "a point on another logger at this station") {
    labels <- vapply(seq_len(nrow(others)), function(i)
      device_label(others[i, ], with_role = TRUE), character(1))
    o_pick <- ui_select_from_menu("Which logger?", labels)
    if (is.null(o_pick)) return(cancel())
    other <- others[which(labels == o_pick)[1], ]
    id2 <- other$unique_id
    p_pick <- ui_select_from_menu(paste0("Which point on ", device_label(other), "?"),
                                  unname(SURVEY_POINT_LABELS))
    if (is.null(p_pick)) return(cancel())
    p2 <- names(SURVEY_POINT_LABELS)[SURVEY_POINT_LABELS == p_pick]
  } else {
    p2 <- rest[match(pick2, rest_labels)]
  }

  # Each point named as a person would say it: "the sensor", or "bta2a's
  # sensor" when the two are on different loggers
  name <- function(uid, p) {
    if (id2 == dev$unique_id) return(paste0("the ", p))
    paste0(device_label(metadata[metadata$unique_id == uid, ][1, ]), "'s ", p)
  }
  n1 <- name(dev$unique_id, p1)
  n2 <- name(id2, p2)
  cat("\u2713 Second point: ", n2, "\n\n", sep = "")

  #### Which is higher, and by how much ####
  hi <- ui_select_from_menu("Which one is higher?",
                            c(n1, n2, "Neither - they are level"))
  if (is.null(hi)) return(cancel())
  level <- hi == "Neither - they are level"
  value <- 0
  if (!level) {
    repeat {
      cat("By how much, in centimeters? ")
      x <- trimws(readline())
      if (tolower(x) == "q") return(cancel())
      value <- suppressWarnings(as.numeric(x))
      if (!is.na(value) && value >= 0) break
      cat("\u26a0\ufe0f  A positive number of centimeters\n")
    }
  }

  # Recorded as the higher point above the lower, on the logger the higher
  # point belongs to
  first_higher <- level || hi == n1
  up   <- if (first_higher) list(uid = dev$unique_id, p = p1) else list(uid = id2, p = p2)
  down <- if (first_higher) list(uid = id2, p = p2) else list(uid = dev$unique_id, p = p1)

  method <- survey_ask_method()
  if (is.null(method)) return(cancel())
  cat("\nAnything worth recording as a note? (Enter to skip): ")
  note <- trimws(readline())
  if (tolower(note) == "q") return(cancel())

  row <- survey_row(dev$station_id, up$uid, ww$survey_date, "height_cm", up$p, value,
                    down$p, if (down$uid == up$uid) NA else down$uid, method, notes = note)
  problems <- survey_row_problems(row, metadata)
  if (!is.null(problems)) return(cancel(paste(problems, collapse = "; ")))

  cat("\n============================================\n")
  cat("  ", describe_survey_row(row, metadata, with_logger = TRUE), "\n", sep = "")
  if (nzchar(note)) cat("  Note: ", note, "\n", sep = "")
  cat("============================================\n\n")
  if (ui_yes_no("Save?", allow_quit = FALSE) != "Y") return(cancel())

  res <- add_survey_rows(row)
  if (!isTRUE(res)) return(cancel(paste0(res, " - nothing saved")))
  cat("\u2713 Survey recorded\n")

  log_result <- create_maintenance_entry(
    field_visit_date = ww$survey_date, station_id = dev$station_id,
    unique_id = up$uid, action_type = "survey",
    details = paste0("Survey: ", describe_survey_row(row, metadata),
                     if (nzchar(note)) paste0("; ", note) else ""),
    logged_by = ww$logged_by)
  if (!isTRUE(log_result)) {
    cat("\u26a0\ufe0f  Saved, but the maintenance log entry failed: ", log_result, "\n", sep = "")
  }
  visit <- update_last_visit(dev$station_id, ww$survey_date)
  if (!isTRUE(visit)) cat("\u26a0\ufe0f  Could not update last_visit: ", visit, "\n", sep = "")

  cat("\n\u2713 Survey complete\n")
  invisible(TRUE)
}


#' Interactive ground elevation by GNSS, for one logger
#'
#' `elev` is the GROUND at the device's coordinates, on every row whatever its
#' role. By one of two routes: typed as an orthometric height, or computed
#' here from an ellipsoidal height and the GEOID18 geoid height (H = h - N,
#' NAD83(2011) to VIVD09). A shot taken on the measuring point is brought back
#' to the ground by the logger's surveyed sensor height.
#'
#' @return TRUE if saved, NULL if canceled
ui_survey_ground_elevation <- function() {

  cancel <- function(msg = "Canceled - nothing saved") {
    cat("\n❌ ", msg, "\n", sep = "")
    invisible(NULL)
  }
  read_number <- function(prompt) {
    repeat {
      cat(prompt)
      x <- trimws(readline())
      if (tolower(x) == "q") return(NULL)
      v <- suppressWarnings(as.numeric(x))
      if (!is.na(v)) return(v)
      cat("⚠️  Not a number\n")
    }
  }
  show <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) == 0 || is.na(x)) "(blank)" else sprintf("%.3f m", x)
  }

  cat("\n--- ONE LOGGER: GROUND ELEVATION BY GNSS ---\n\n")
  cat("Nothing is saved until the end, and 'q' at any prompt cancels.\n\n")

  ww <- survey_ask_when_who()
  if (is.null(ww)) return(cancel())
  metadata <- load_zentra_metadata()
  dev <- survey_pick_logger(metadata)
  if (is.null(dev)) return(cancel())

  old_elev <- suppressWarnings(as.numeric(dev$elev))
  cat("Current elevation: ", show(old_elev),
      if (!is.na(dev$elev_source)) paste0("  (", dev$elev_source, ")") else "", "\n\n", sep = "")

  cat("  1. An orthometric height, meters above sea level (VIVD09)\n")
  cat("  2. An ellipsoidal height, converted here with GEOID18\n")
  route <- NULL
  repeat {
    cat("\nEnter selection: ")
    route <- tolower(trimws(readline()))
    if (route == "q") return(cancel())
    if (route %in% c("1", "2")) break
    cat("⚠️  Choose 1 or 2\n")
  }

  if (route == "1") {
    H <- read_number("Orthometric height, meters: ")
    if (is.null(H)) return(cancel())
    arithmetic <- sprintf("H %.3f m", H)
  } else {
    cat("\nThe NAD83(2011) ellipsoidal height, as the receiver or its\n")
    cat("post-processing reported it. It will look tens of meters too low.\n")
    h <- read_number("Ellipsoidal height h, meters: ")
    if (is.null(h)) return(cancel())
    cat("\nThe GEOID18 geoid height at this device - from NGS:\n\n")
    cat(sprintf("     https://geodesy.noaa.gov/api/geoid/ght?lat=%.6f&lon=%.6f&model=14\n\n",
                as.numeric(dev$lat), as.numeric(dev$lon)))
    N <- read_number("Geoid height N, meters (negative here): ")
    if (is.null(N)) return(cancel())
    H <- h - N
    cat(sprintf("\n  H = h - N = %.3f - (%.3f) = %.3f m\n", h, N, H))
    arithmetic <- sprintf("h %.3f m NAD83(2011) - GEOID18 N %.3f m = H %.3f m", h, N, H)
  }

  # In the Virgin Islands an ellipsoidal height is negative where the land is
  # well above sea level - the classic way a GNSS elevation goes wrong
  if (H < -5 || H > 900) {
    cat(sprintf("\n⚠️  %.3f m is outside the plausible range here.", H))
    if (route == "1" && H < -5) {
      cat(" That looks like an\n   ellipsoidal height - choose route 2 instead.")
    }
    cat("\n")
    if (ui_yes_no("Use it anyway?", allow_quit = FALSE) != "Y") return(cancel())
  }

  where <- ui_select_from_menu("Where was the shot taken?",
                               c("On the ground at the device",
                                 "On the device's measuring point"))
  if (is.null(where)) return(cancel())
  if (grepl("measuring point", where)) {
    # The sensor's surveyed height above the ground, or failing that the bed
    surveys <- load_surveys()
    up <- survey_height(dev$unique_id, "sensor", dev$unique_id, "ground", surveys)
    from <- "ground"
    if (is.na(up)) {
      up <- survey_height(dev$unique_id, "sensor", dev$unique_id, "bed", surveys)
      from <- "bed"
    }
    if (is.na(up)) {
      return(cancel(paste0("A shot on the measuring point needs the sensor's height above\n",
                           "   the ground or bed to get back down, and none is surveyed.\n",
                           "   Record it with option 2 first")))
    }
    new_elev <- round(H - up / 100, 3)
    cat(sprintf("✓ Ground = measuring point - sensor height above the %s = %.3f - %.2f = %.3f m\n",
                from, H, up / 100, new_elev))
    arithmetic <- paste0(arithmetic, sprintf(" at the measuring point, less %s cm above the %s = ground %.3f m",
                                             format(up), from, new_elev))
  } else {
    new_elev <- round(H, 3)
    arithmetic <- paste0(arithmetic, ", ground shot")
  }

  cat("\nAnything worth recording as a note? (Enter to skip): ")
  note <- trimws(readline())
  if (tolower(note) == "q") return(cancel())

  # A paired gauge carries one elevation, the primary's, on every logger
  shared <- elevation_shared_with(dev$unique_id, metadata)
  partners <- metadata[metadata$unique_id %in% setdiff(shared, dev$unique_id), , drop = FALSE]

  cat("\n============================================\n")
  cat("  Station:   ", dev$station_id, "  (", ww$survey_date, ")\n", sep = "")
  cat("  Device:    ", device_label(dev, with_role = TRUE), "\n", sep = "")
  cat("  Elevation: ", show(old_elev), " -> ", show(new_elev), "  (gnss)\n", sep = "")
  if (nrow(partners) > 0) {
    cat("             also on ", paste(vapply(seq_len(nrow(partners)), function(i)
      device_label(partners[i, ], with_role = TRUE), character(1)), collapse = ", "),
      " - a paired gauge carries one elevation\n", sep = "")
  }
  cat("             ", arithmetic, "\n", sep = "")
  if (nzchar(note)) cat("  Note:      ", note, "\n", sep = "")
  cat("============================================\n\n")
  if (ui_yes_no("Save?", allow_quit = FALSE) != "Y") return(cancel())

  result <- survey_device_elevation(shared, new_elev, "gnss")
  if (!isTRUE(result)) return(cancel(paste0(result, " - nothing saved")))
  cat("✓ Metadata saved\n")

  log_result <- create_maintenance_entry(
    field_visit_date = ww$survey_date, station_id = dev$station_id,
    unique_id = dev$unique_id, action_type = "survey",
    details = paste0("GNSS survey: elev ", show(old_elev), " -> ",
                     sprintf("%.3f m VIVD09 (%s)", new_elev, arithmetic),
                     if (nzchar(note)) paste0("; ", note) else ""),
    logged_by = ww$logged_by)
  if (!isTRUE(log_result)) {
    cat("⚠️  Saved, but the maintenance log entry failed: ", log_result, "\n", sep = "")
  }
  visit <- update_last_visit(dev$station_id, ww$survey_date)
  if (!isTRUE(visit)) cat("⚠️  Could not update last_visit: ", visit, "\n", sep = "")

  cat("\n✓ Survey complete\n")
  invisible(TRUE)
}


#' Interactive removal of a survey row entered by mistake
#'
#' Not for a measurement that has since been repeated - the newest of each
#' stands, and the older one is history worth keeping. For a row that should
#' never have been recorded: the wrong logger, a typo, a duplicate.
#'
#' @return TRUE if removed, NULL if canceled
ui_remove_survey <- function() {
  cancel <- function(msg = "Canceled - nothing removed") {
    cat("\n❌ ", msg, "\n", sep = "")
    invisible(NULL)
  }

  cat("\n--- REMOVE A SURVEY ROW ---\n\n")
  cat("For a row entered by mistake. A measurement that has simply been\n")
  cat("repeated needs no removing - the newest stands.\n\n")

  surveys <- load_surveys()
  if (nrow(surveys) == 0) return(cancel("No surveys recorded"))
  metadata <- load_zentra_metadata()

  stations <- sort(unique(surveys$station_id))
  pick <- ui_select_from_menu("Select station:", stations)
  if (is.null(pick)) return(cancel())
  here <- surveys[surveys$station_id == pick, , drop = FALSE]
  here <- here[order(here$measured_on, decreasing = TRUE), , drop = FALSE]

  labels <- vapply(seq_len(nrow(here)), function(i)
    describe_survey_row(here[i, ], metadata, with_logger = TRUE), character(1))
  r_pick <- ui_select_from_menu("Which row?", labels)
  if (is.null(r_pick)) return(cancel())
  row <- here[match(r_pick, labels), , drop = FALSE]

  cat("\n  ", r_pick, "\n", sep = "")
  if (!is.na(row$notes)) cat("  Notes: ", row$notes, "\n", sep = "")
  cat("\n")
  if (ui_yes_no("Remove this row?", allow_quit = FALSE) != "Y") return(cancel())

  cat("Why? (one line, for the maintenance log): ")
  why <- trimws(readline())

  res <- remove_survey_row(row)
  if (!isTRUE(res)) return(cancel(res))
  cat("✓ Row removed\n")

  log_result <- create_maintenance_entry(
    field_visit_date = Sys.Date(), station_id = row$station_id,
    unique_id = row$unique_id, action_type = "metadata_deletion",
    details = paste0("Survey row removed: ", r_pick,
                     if (nzchar(why)) paste0(" - ", why) else ""),
    logged_by = ui_ask_whois_logging())
  if (!isTRUE(log_result)) {
    cat("⚠️  Removed, but the maintenance log entry failed: ", log_result, "\n", sep = "")
  }
  invisible(TRUE)
}


#' Offers a replaced logger's surveys to its replacement, one by one
#'
#' A new logger in the same housing, with the rebar untouched, sits where the
#' old one sat: what was measured still holds. Only a person knows whether it
#' does, so each measurement is asked about separately - the rebar may have
#' stayed while the sensor sits differently in the new logger. A yes copies
#' the row to the new deployment, keeping its date and method, with
#' carried_from naming the old one. Measurements the new logger already has
#' are not offered.
#'
#' @param old_uid,new_uid Character unique_ids
#' @return Invisibly, the number of rows carried
ui_carry_surveys <- function(old_uid, new_uid) {
  surveys <- load_surveys()
  old <- latest_surveys(old_uid, surveys)
  if (nrow(old) == 0) return(invisible(0))
  kind <- function(d) paste(d$quantity, d$point, d$relative_to, d$relative_to_id)
  have <- latest_surveys(new_uid, surveys)
  old <- old[!kind(old) %in% kind(have), , drop = FALSE]
  if (nrow(old) == 0) return(invisible(0))

  metadata <- load_zentra_metadata()
  cat("\n--- SURVEYS THAT MAY STILL HOLD ---\n\n")
  cat("The old logger had these surveyed. If the new one went into the same\n")
  cat("housing and the rebar was not touched, they still hold, and carrying\n")
  cat("them over saves surveying again. Answer each separately.\n\n")

  carry <- old[0, ]
  for (i in seq_len(nrow(old))) {
    a <- ui_yes_no(paste0("  ", describe_survey_row(old[i, ], metadata), "\n  Still holds?"),
                   allow_quit = FALSE)
    if (a == "Y") carry <- rbind(carry, old[i, ])
  }
  if (nrow(carry) == 0) {
    cat("✓ Nothing carried - the new logger needs surveying\n")
    return(invisible(0))
  }
  carry$unique_id <- new_uid
  carry$carried_from <- old_uid
  # A failure stops the replacement it is part of, which puts everything back
  res <- add_survey_rows(carry)
  if (!isTRUE(res)) stop("the surveys could not be carried over: ", res)
  cat("✓ ", nrow(carry), " survey row", if (nrow(carry) != 1) "s", " carried over\n", sep = "")
  invisible(nrow(carry))
}


#' Interactive paired-gauge survey: fall and reach length
#'
#' One path from the field notebook to the metadata. The fall comes from rod
#' readings at independent level setups, or is typed in meters where it was
#' measured some other way; the reach comes from a TruPulse export, or is
#' typed. Either can be skipped, so a re-measured reach does not need a
#' re-leveled fall.
#'
#' ROLE IS NOT POSITION. Primary means the anchor - the logger whose elevation
#' is sourced externally, where flow is gauged, the position kept come what
#' may. Normally that is the downstream logger, but nothing here requires it.
#' Upstream and downstream come from the survey itself: the user names the
#' backsight end, and the sign of the fall confirms it.
#'
#' Nothing is written until the final confirmation. Then, in order: the
#' Product 0 files, any role assignment, the metadata, the maintenance log.
#' A Product 0 failure stops everything before the metadata is touched.
#'
#' @return TRUE if something was saved, NULL if canceled
ui_survey_gut_pair <- function() {

  cancel <- function(msg = "Canceled - nothing saved") {
    cat("\n\u274c ", msg, "\n", sep = "")
    invisible(NULL)
  }
  read_or_quit <- function(prompt) {
    cat(prompt)
    x <- trimws(readline())
    if (tolower(x) == "q") return(NULL)
    x
  }

  cat("\n--- PAIRED GAUGE SURVEY ---\n\n")
  cat("Fall between two loggers, and reach length between them along the\n")
  cat("channel. Either can be skipped. Nothing is saved until the end, and\n")
  cat("'q' at any prompt cancels.\n\n")

  ##############################################################################
  #### 1. When and who ####
  ##############################################################################

  survey_date <- ui_prompt_date("When was this survey performed?", allow_today = TRUE)
  if (is.null(survey_date)) return(cancel())
  cat("\u2713 Survey date: ", survey_date, "\n", sep = "")

  logged_by <- ui_ask_whois_logging()
  cat("\u2713 Logged by: ", logged_by, "\n\n", sep = "")

  ##############################################################################
  #### 2. Station and pair ####
  ##############################################################################

  # ACTIVE loggers only. Counting every HOBO ever installed listed stations by
  # loggers long since removed - Dorothea showed four.
  terminal <- TERMINAL_STATUSES
  metadata <- load_zentra_metadata()
  active <- metadata[is_hobo_device(metadata$mfger) &
                       !tolower(metadata$status) %in% terminal, ]

  counts <- table(active$station_id)
  stations <- sort(names(counts[counts >= 2]))
  if (length(stations) == 0) {
    cat("\u274c No station has two or more active HOBO loggers\n")
    return(invisible(NULL))
  }

  station_options <- vapply(stations, function(sid) {
    paste0(sid, " (", active$site_full[active$station_id == sid][1], " - ",
           counts[[sid]], " active HOBO loggers)")
  }, character(1), USE.NAMES = FALSE)

  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) return(cancel())
  station_id <- sub(" \\(.*\\)$", "", selected)
  cat("\u2713 Station: ", station_id, "\n\n", sep = "")

  loggers <- order_devices_by_role(active[active$station_id == station_id, ])
  roles <- tolower(trimws(as.character(loggers$device_role)))
  primary_rows <- which(!is.na(roles) & roles == "primary")

  roles_unset <- FALSE
  if (length(primary_rows) == 1) {
    primary <- loggers[primary_rows, ]
    others  <- loggers[-primary_rows, ]
    if (nrow(others) == 1) {
      other <- others[1, ]
    } else {
      # rb2 has a secondary and a tertiary. Each is surveyed against the
      # primary, one at a time, because each derives its elevation from it.
      pick <- ui_select_from_menu(
        "Which logger is being surveyed against the primary?",
        vapply(seq_len(nrow(others)), function(i)
          device_label(others[i, ], with_role = TRUE), character(1)))
      if (is.null(pick)) return(cancel())
      other <- others[vapply(seq_len(nrow(others)), function(i)
        device_label(others[i, ], with_role = TRUE), character(1)) == pick, ][1, ]
    }
  } else if (length(primary_rows) == 0 && nrow(loggers) == 2) {
    roles_unset <- TRUE
    primary <- NULL
    other   <- NULL
  } else {
    cat("\u274c This station has ", length(primary_rows), " primary loggers and ",
        nrow(loggers), " active loggers in all.\n", sep = "")
    cat("   A survey needs exactly one primary, or two loggers with no roles\n")
    cat("   yet. Fix the roles with 'Correct device details' first.\n")
    return(invisible(NULL))
  }

  pair <- if (roles_unset) loggers[1:2, ] else rbind(primary, other)

  cat("--- THE PAIR ---\n\n")
  if (roles_unset) {
    cat("Neither logger has a role yet. Roles are suggested once the fall is\n")
    cat("measured, so a fall is required this time.\n\n")
  } else {
    cat("Current roles:\n")
  }
  for (i in 1:2) cat("  ", device_label(pair[i, ], with_role = TRUE), "\n", sep = "")
  cat("\n")

  ##############################################################################
  #### 3. The fall ####
  ##############################################################################

  fall <- NULL   # list(value_m, upstream_serial, method, summary, p0)

  repeat {
    cat("--- FALL ---\n\n")
    cat("How was the fall between the loggers measured?\n")
    cat("  1. Builder's level and rod - enter the readings\n")
    cat("  2. Some other way - enter the fall in meters\n")
    if (!roles_unset) cat("  3. Not measured this time - skip\n")
    method <- read_or_quit("\nEnter selection: ")
    if (is.null(method)) return(cancel())
    if (method == "3" && !roles_unset) { cat("\u2713 Fall skipped\n\n"); break }
    if (!method %in% c("1", "2")) { cat("\u26a0\ufe0f  Choose 1, 2",
                                        if (!roles_unset) " or 3", "\n\n", sep = ""); next }

    #### Which end is upstream ####
    cat("\nWhich logger is UPSTREAM", if (method == "1") " - the backsight end" else "",
        "?\n", sep = "")
    cat("(Normally that is the secondary.)\n")
    # The readings cannot tell which LOGGER stood at the backsight end - a
    # mix-up here still gives a positive fall, and a wrong elevation. So the
    # unusual answer, the primary upstream, is confirmed rather than taken.
    # It is allowed - role is not position - but the first live survey named
    # the primary upstream by mistake, and nothing else would have caught it.
    labels <- vapply(1:2, function(i) device_label(pair[i, ], with_role = TRUE),
                     character(1))
    repeat {
      up_pick <- ui_select_from_menu("Upstream logger:", labels)
      if (is.null(up_pick)) return(cancel())
      up_i <- which(labels == up_pick)[1]
      up_role <- tolower(trimws(as.character(pair$device_role[up_i])))
      if (roles_unset || is.na(up_role) || up_role != "primary") break
      sure <- ui_yes_no(paste0("  The primary is normally downstream. Is ",
                               device_label(pair[up_i, ]), " really upstream?"))
      if (sure == "Q") return(cancel())
      if (sure == "Y") break
      cat("\n")
    }
    up_dev <- pair[up_i, ]
    dn_dev <- pair[3 - up_i, ]
    cat("\u2713 Upstream:   ", device_label(up_dev, with_role = TRUE), "\n", sep = "")
    cat("\u2713 Downstream: ", device_label(dn_dev, with_role = TRUE), "\n\n", sep = "")

    if (method == "2") {
      #### Manual fall ####
      v <- NA_real_
      repeat {
        x <- read_or_quit("Fall from upstream to downstream logger, in meters: ")
        if (is.null(x)) return(cancel())
        v <- suppressWarnings(as.numeric(x))
        if (!is.na(v)) break
        cat("\u26a0\ufe0f  Not a number\n")
      }
      # What the instrument stood on decides what the number means - so it
      # is recorded, never assumed
      pts <- ui_select_from_menu("Between which points was it measured?",
                                 c("The rebar tops", "The sensors (measuring points)",
                                   "Not recorded"))
      if (is.null(pts)) return(cancel())
      points <- switch(pts, "The rebar tops" = "rebar",
                       "The sensors (measuring points)" = "sensor", NA_character_)
      m <- survey_ask_method(c("laser", "level", "tape"))
      if (is.null(m)) return(cancel())
      note <- read_or_quit("Anything worth recording as a note? (Enter to skip): ")
      if (is.null(note)) return(cancel())
      candidate <- list(value_m = v, method = m, points = points, note = note,
                        summary = paste0(m, if (nzchar(note)) paste0(": ", note) else "",
                                         if (is.na(points)) ", points not recorded"
                                         else paste0(", between the ", points, " tops")),
                        p0 = NULL)
      if (!is.na(points) && points == "sensor") {
        candidate$summary <- sub("the sensor tops", "the sensors", candidate$summary)
      }

    } else {
      #### Rod survey ####
      rod_pick <- ui_select_from_menu("What units is the rod graduated in?",
                                      unname(ROD_UNITS))
      if (is.null(rod_pick)) return(cancel())
      rod_unit <- names(ROD_UNITS)[ROD_UNITS == rod_pick]
      unit_word <- switch(rod_unit, ft = "feet", m = "meters", cm = "centimeters")
      unit_eg   <- switch(rod_unit, ft = "4.37", m = "1.482", cm = "148.2")

      # One number per prompt, then the whole reading read back for a yes.
      # Three numbers on one line was too easy to get wrong without noticing,
      # and a misread here is a wrong slope later.
      read_number <- function(prompt) {
        repeat {
          x <- read_or_quit(prompt)
          if (is.null(x)) return(NULL)
          if (!is.na(suppressWarnings(as.numeric(x)))) return(x)
          cat("    \u26a0\ufe0f  Not a number\n")
        }
      }

      read_rod <- function(end) {
        cat("\n  Rod reading with the rod on the ", toupper(end),
            " rebar datum (top of the rebar stake)", sep = "")
        if (rod_unit == "ft_in_8") {
          cat(",\n  in feet, inches and eighths of an inch:\n")
        } else {
          cat(", in ", unit_word, ":\n", sep = "")
        }
        repeat {
          if (rod_unit == "ft_in_8") {
            ft <- read_number("    Feet: ");                                 if (is.null(ft)) return(NULL)
            inch <- read_number("    Inches: ");                             if (is.null(inch)) return(NULL)
            e8 <- read_number("    Eighths of an inch (decimals OK, e.g. 1.5): "); if (is.null(e8)) return(NULL)
            x <- paste(trimws(ft), trimws(inch), trimws(e8))
          } else {
            x <- read_number(paste0("    Reading (e.g. ", unit_eg, "): "))
            if (is.null(x)) return(NULL)
          }
          p <- parse_rod_reading(x, rod_unit)
          if (!p$ok) {
            cat("    \u26a0\ufe0f  ", p$message, " - enter it again\n", sep = "")
            next
          }
          ok <- ui_yes_no(paste0("    You entered ", format_rod_reading(x, rod_unit),
                                 " - correct?"))
          if (ok == "Q") return(NULL)
          if (ok == "Y") return(list(text = x, m = p$value_m))
          cat("    Enter it again:\n")
        }
      }

      bs_text <- character(0); fs_text <- character(0)
      bs_m <- numeric(0); fs_m <- numeric(0)
      repeat {
        k <- length(bs_text) + 1
        cat("\nSetup ", k, "\n", sep = "")
        cat("  Backsight")
        b <- read_rod("upstream")
        if (is.null(b)) return(cancel())
        cat("\n  Foresight")
        f <- read_rod("downstream")
        if (is.null(f)) return(cancel())
        bs_text <- c(bs_text, b$text); bs_m <- c(bs_m, b$m)
        fs_text <- c(fs_text, f$text); fs_m <- c(fs_m, f$m)
        another <- ui_yes_no("\nAdd another setup?")
        if (another == "Q") return(cancel())
        if (another == "N") break
      }

      #### Offsets ####
      cat("\n--- RE-BAR TO MEASURING POINT OFFSETS ---\n\n")
      cat("At each logger, the distance from the TOP of the rebar DOWN to the\n")
      cat("logger's measuring point. Positive when the measuring point is below\n")
      cat("the rebar top, which is the usual case.\n\n")
      off_pick <- ui_select_from_menu("What units were the offsets measured in?",
                                      unname(OFFSET_UNITS))
      if (is.null(off_pick)) return(cancel())
      off_unit <- names(OFFSET_UNITS)[OFFSET_UNITS == off_pick]

      read_offset <- function(dev) {
        repeat {
          x <- read_or_quit(paste0("  Offset at ", device_label(dev), " (", off_unit, "): "))
          if (is.null(x)) return(NULL)
          v <- suppressWarnings(as.numeric(x))
          if (!is.na(v)) return(list(text = x, m = to_meters(v, off_unit)))
          cat("  \u26a0\ufe0f  Not a number\n")
        }
      }
      d_up <- read_offset(up_dev);   if (is.null(d_up)) return(cancel())
      d_dn <- read_offset(dn_dev);   if (is.null(d_dn)) return(cancel())

      #### Reduce ####
      falls <- compute_falls(bs_m, fs_m, d_up$m, d_dn$m)

      cat("\n--- FALL BY SETUP ---\n\n")
      cat("  (FS + d_down) - (BS + d_up)\n\n")
      for (k in seq_along(falls)) {
        cat(sprintf("  Setup %d:  BS %-14s FS %-14s  fall %s\n", k,
                    format_rod_reading(bs_text[k], rod_unit),
                    format_rod_reading(fs_text[k], rod_unit), format_fall(falls[k])))
      }
      cat(sprintf("\n  Offsets: upstream %s %s, downstream %s %s\n\n",
                  d_up$text, off_unit, d_dn$text, off_unit))

      sel <- select_agreeing_pair(falls, tolerance_m = 0.010)

      p0 <- list(table = build_fall_rod_table(
        station_id, survey_date, up_dev$device_serial, dn_dev$device_serial,
        bs_text, fs_text, rod_unit, d_up$text, d_dn$text, off_unit))

      # A fall that is not positive is never accepted - asking first and then
      # refusing it would be asking a question whose answer does not matter.
      # It goes straight to the sign check below.
      ask_accept <- function(q) if (sel$fall_m <= 0) "Y" else ui_yes_no(q)

      accepted <- FALSE
      if (sel$single) {
        cat("One setup only - there is nothing to check it against, so it is\n")
        cat("recorded as UNCHECKED.\n\n")
        cat("  Fall: ", format_fall(sel$fall_m), "\n\n", sep = "")
        a <- ask_accept("Accept this fall?")
        if (a == "Q") return(cancel())
        accepted <- a == "Y"
        summ <- sprintf("rod: 1 setup, unchecked")
      } else if (isTRUE(sel$within)) {
        cat(sprintf("Setups %d and %d agree within %.1f mm (tolerance 10 mm).\n",
                    sel$i, sel$j, sel$diff_m * 1000))
        cat("  Mean fall: ", format_fall(sel$fall_m), "\n\n", sep = "")
        a <- ask_accept("Accept their mean as the fall?")
        if (a == "Q") return(cancel())
        accepted <- a == "Y"
        summ <- sprintf("rod: %d setups, accepted %d+%d, agreement %.1f mm",
                        sel$n, sel$i, sel$j, sel$diff_m * 1000)
      } else {
        cat(sprintf("No two setups agree within 10 mm - the closest, %d and %d, are\n",
                    sel$i, sel$j))
        cat(sprintf("%.1f mm apart. The fall will not be taken from these readings.\n\n",
                    sel$diff_m * 1000))
      }

      if (!accepted) {
        cat("What next?\n")
        cat("  1. Start the fall again - re-enter, or enter it in meters instead\n")
        if (!roles_unset) cat("  2. Skip the fall\n")
        x <- read_or_quit("\nEnter selection: ")
        if (is.null(x)) return(cancel())
        if (x == "2" && !roles_unset) { cat("\u2713 Fall skipped\n\n"); break }
        cat("\n"); next
      }

      p0$filename <- build_survey_filename(station_id, "fall", "rod", survey_date,
                                           "csv", dir = get_gut_survey_dir())
      # The rod stood on the rebar tops: what it measured is their
      # difference, and the offsets are each rebar top above its sensor.
      # The fall between the sensors follows from those three, and is what
      # the readings are checked by
      candidate <- list(value_m = sel$fall_m, method = "level", points = "rebar",
                        rebar_diff_m = sel$fall_m - d_dn$m + d_up$m,
                        d_up_m = d_up$m, d_dn_m = d_dn$m,
                        summary = paste0(summ, ", file ", p0$filename), p0 = p0)
    }

    #### The sign checks the upstream choice ####
    if (candidate$value_m <= 0) {
      cat("\n\u26a0\ufe0f  The fall came out ", format_fall(candidate$value_m),
          " - the end named upstream is not higher.\n", sep = "")
      cat("   Either the ends were mislabeled or a reading is wrong. Nothing\n")
      cat("   from this attempt will be saved.\n\n")
      cat("  1. Start the fall again\n")
      if (!roles_unset) cat("  2. Skip the fall\n")
      x <- read_or_quit("\nEnter selection: ")
      if (is.null(x)) return(cancel())
      if (x == "2" && !roles_unset) { cat("\u2713 Fall skipped\n\n"); break }
      cat("\n"); next
    }

    fall <- c(candidate, list(upstream_serial = up_dev$device_serial,
                              up_dev = up_dev, dn_dev = dn_dev))
    cat("\u2713 Fall: ", format_fall(fall$value_m), "\n\n", sep = "")
    break
  }

  ##############################################################################
  #### 4. Roles, if not yet set ####
  ##############################################################################

  if (roles_unset) {
    cat("--- ASSIGN ROLES ---\n\n")
    cat("Primary is the anchor: the logger whose elevation is sourced\n")
    cat("externally, where flow is gauged, the position kept long-term.\n")
    cat("Normally that is the downstream logger:\n\n")
    cat("  Suggested primary: ", device_label(fall$dn_dev), " (downstream)\n\n", sep = "")
    p_pick <- ui_select_from_menu("Which logger is PRIMARY?",
      c(paste0(device_label(fall$dn_dev), " (downstream) - suggested"),
        paste0(device_label(fall$up_dev), " (upstream)")))
    if (is.null(p_pick)) return(cancel())
    if (grepl("suggested$", p_pick)) {
      primary <- fall$dn_dev; other <- fall$up_dev
    } else {
      primary <- fall$up_dev; other <- fall$dn_dev
    }
    cat("\u2713 Primary:   ", device_label(primary), "\n", sep = "")
    cat("\u2713 Secondary: ", device_label(other), "\n\n", sep = "")
  }

  ##############################################################################
  #### 5. The reach ####
  ##############################################################################

  reach <- NULL   # list(value_m, method, summary, from, filename)

  repeat {
    cat("--- REACH LENGTH ---\n\n")
    cat("Along the channel, between the two loggers.\n")
    cat("  1. TruPulse export (.txt)\n")
    cat("  2. Some other way - enter the reach in meters\n")
    cat("  3. Not measured this time - skip\n")
    method <- read_or_quit("\nEnter selection: ")
    if (is.null(method)) return(cancel())
    if (method == "3") { cat("\u2713 Reach skipped\n\n"); break }
    if (!method %in% c("1", "2")) { cat("\u26a0\ufe0f  Choose 1, 2 or 3\n\n"); next }

    if (method == "2") {
      v <- NA_real_
      repeat {
        x <- read_or_quit("Reach length in meters: ")
        if (is.null(x)) return(cancel())
        v <- suppressWarnings(as.numeric(x))
        if (!is.na(v) && v > 0) break
        cat("\u26a0\ufe0f  Enter a positive number\n")
      }
      m <- survey_ask_method(c("tape", "laser"))
      if (is.null(m)) return(cancel())
      note <- read_or_quit("Anything worth recording as a note? (Enter to skip): ")
      if (is.null(note)) return(cancel())
      reach <- list(value_m = v, method = m, trupulse = FALSE,
                    summary = paste0(m, if (nzchar(note)) paste0(": ", note) else ""),
                    from = NULL, filename = NULL)
      cat(sprintf("\u2713 Reach: %.2f m\n\n", v))
      break
    }

    #### TruPulse ####
    survey_dir <- get_gut_survey_dir()
    cat("\nThe export belongs in:\n\n     ", survey_dir, "\n\n", sep = "")
    there <- ui_yes_no("Is it in that folder?")
    if (there == "Q") return(cancel())
    if (there == "N") {
      cat("\nCopy it there, then choose this option again.\n\n")
      next
    }

    # Unfiled exports, plus this station's already-filed ones in case of a rerun
    txts <- list.files(survey_dir, pattern = "\\.txt$", ignore.case = TRUE)
    txts <- txts[!is_standard_survey_filename(txts) |
                   startsWith(txts, paste0(station_id, "_reach_"))]
    if (length(txts) == 0) {
      cat("\n\u26a0\ufe0f  No .txt files there that are not already filed.\n\n")
      next
    }
    f_pick <- ui_select_from_menu("Which file is the export for this reach?", txts)
    if (is.null(f_pick)) return(cancel())
    from <- file.path(survey_dir, f_pick)

    parsed <- read_trupulse_export(from)
    if (!isTRUE(parsed$ok)) {
      cat("\n\u274c ", parsed$message, "\n\n", sep = "")
      next
    }

    cat("\n  ", length(parsed$legs), " leg", if (length(parsed$legs) != 1) "s",
        ", in ", parsed$unit, ":\n\n", sep = "")
    cat("  ", format_reach_arithmetic(parsed), "\n\n", sep = "")

    off_dates <- parsed$dates[!is.na(parsed$dates) &
                                parsed$dates != as.Date(survey_date)]
    if (length(off_dates) > 0) {
      cat("\u26a0\ufe0f  The export has shots dated ",
          paste(unique(format(off_dates)), collapse = ", "),
          ", not the survey date ", survey_date, ".\n", sep = "")
      cat("   Check this is the right file.\n\n")
    }

    a <- ui_yes_no(sprintf("Accept %.2f m as the reach length?", parsed$total_m))
    if (a == "Q") return(cancel())
    if (a == "N") { cat("\n"); next }

    filename <- if (is_standard_survey_filename(f_pick)) f_pick else
      build_survey_filename(station_id, "reach", "trupulse", survey_date,
                            "txt", dir = survey_dir)
    cat("\n  Will be filed as: ", filename, "\n\n", sep = "")

    reach <- list(value_m = parsed$total_m, method = "laser", trupulse = TRUE,
                  summary = sprintf("trupulse: %d legs, file %s",
                                    length(parsed$legs), filename),
                  from = from, filename = filename)
    cat(sprintf("\u2713 Reach: %.2f m\n\n", parsed$total_m))
    break
  }

  if (is.null(fall) && is.null(reach)) {
    return(cancel("Neither fall nor reach was measured - nothing to save"))
  }

  ##############################################################################
  #### 6. What would be recorded ####
  ##############################################################################

  # Every row belongs to the surveyed logger, measured against the primary,
  # except each logger's own offset. Upstream above downstream is positive,
  # so a surveyed logger downstream of its primary gets a negative height
  up_dev <- if (!is.null(fall)) fall$up_dev else NULL
  sign <- if (!is.null(fall) && fall$up_dev$device_serial == other$device_serial) 1 else -1
  cm <- function(m) round(m * 100, 2)
  fall_rows <- NULL
  if (!is.null(fall)) {
    if (!is.null(fall$rebar_diff_m)) {
      fall_rows <- rbind(
        survey_row(station_id, fall$up_dev$unique_id, survey_date, "height_cm", "rebar",
                   cm(fall$d_up_m), "sensor", method = "tape",
                   notes = "rebar top to measuring point, from the rod survey"),
        survey_row(station_id, fall$dn_dev$unique_id, survey_date, "height_cm", "rebar",
                   cm(fall$d_dn_m), "sensor", method = "tape",
                   notes = "rebar top to measuring point, from the rod survey"),
        survey_row(station_id, other$unique_id, survey_date, "height_cm", "rebar",
                   sign * cm(fall$rebar_diff_m), "rebar", primary$unique_id,
                   method = "level", notes = fall$summary))
    } else {
      fall_rows <- survey_row(station_id, other$unique_id, survey_date, "height_cm",
                              fall$points, sign * cm(fall$value_m), fall$points,
                              primary$unique_id, method = fall$method,
                              notes = if (nzchar(fall$note)) fall$note else NA)
    }
  }
  reach_rows <- if (!is.null(reach)) {
    survey_row(station_id, other$unique_id, survey_date, "reach_m", NA, reach$value_m, NA,
               primary$unique_id, method = reach$method, notes = reach$summary)
  } else NULL

  # Checked now, before anything is filed, so a row the table would refuse
  # never gets as far as a Product 0 file
  problems <- survey_row_problems(rbind(fall_rows, reach_rows), metadata)
  if (!is.null(problems)) return(cancel(paste(problems, collapse = "; ")))

  surveys <- load_surveys()
  before_cm <- survey_height(other$unique_id, "sensor", primary$unique_id, "sensor", surveys)
  after <- rbind(surveys, fall_rows, reach_rows)
  after_cm <- survey_height(other$unique_id, "sensor", primary$unique_id, "sensor", after)
  reach_m <- survey_reach(other$unique_id, primary$unique_id, after)
  slope <- if (!is.na(after_cm)) compute_slope(abs(after_cm) / 100, reach_m) else NA_real_

  cat("============================================\n")
  cat("  Station:  ", station_id, "  (", survey_date, ")\n", sep = "")
  cat("  Primary:  ", device_label(primary), "\n", sep = "")
  cat("  Surveyed: ", device_label(other, with_role = TRUE), "\n\n", sep = "")
  cat("  To be recorded:\n")
  for (r in list(fall_rows, reach_rows)) {
    for (i in seq_len(if (is.null(r)) 0 else nrow(r))) {
      cat("    ", describe_survey_row(r[i, ], metadata, with_logger = TRUE), "\n", sep = "")
    }
  }
  if (is.null(fall)) cat("    (no fall this time)\n")
  if (is.null(reach)) cat("    (no reach this time)\n")
  cat("\n")
  if (!is.na(after_cm)) {
    cat(sprintf("  Sensor to sensor: %s is %.1f cm %s %s\n", device_label(other),
                abs(after_cm), if (after_cm >= 0) "above" else "below", device_label(primary)))
  } else {
    cat("  Sensor to sensor: cannot be chained yet - ",
        if (!is.null(fall) && is.na(fall$points)) "the points measured were not recorded"
        else "a link is missing (the to-do list's SURVEYS OUTSTANDING says which)", "\n", sep = "")
  }
  if (!is.na(reach_m)) cat(sprintf("  Reach:            %.2f m\n", reach_m))
  if (!is.na(slope)) {
    cat("  Slope:            ", sprintf("%.5f", slope), "  (",
        sprintf("%.3f", slope * 100), "%)\n", sep = "")
  } else {
    cat("  Slope:            cannot be computed yet\n")
  }
  cat("============================================\n\n")

  # A survey that puts the surveyed logger on the other side of the primary
  # from the record is either a correction or a mix-up over which logger was
  # at the backsight. Both are worth seeing before anything is saved.
  if (!is.na(before_cm) && !is.na(after_cm) && (before_cm > 0) != (after_cm > 0)) {
    side <- function(above) if (above) "ABOVE" else "BELOW"
    cat("\u26a0\ufe0f  This survey puts ", device_label(other), " ",
        side(after_cm > 0), " the primary;\n", sep = "")
    cat("   the record had it ", side(before_cm > 0),
        ". If that is a correction, carry on. If not, check which\n", sep = "")
    cat("   logger was at the backsight end.\n\n")
  }

  # Outside roughly 0.0001-0.1 is most often a decimal slip in one half
  if (!is.na(slope) && (slope > 0.1 || slope < 0.0001)) {
    cat("\u26a0\ufe0f  That slope is unusual for a stream reach. Check both halves.\n\n")
  }

  ##############################################################################
  #### 7. Save what? ####
  ##############################################################################

  opts <- character(0)
  if (!is.null(fall) && !is.null(reach)) opts <- c(opts, "Save both")
  if (!is.null(fall))  opts <- c(opts, "Save the fall only")
  if (!is.null(reach) && !roles_unset) opts <- c(opts, "Save the reach only")
  choice <- ui_select_from_menu("Save?", opts)
  if (is.null(choice)) return(cancel())

  save_fall  <- choice %in% c("Save both", "Save the fall only")
  save_reach <- choice %in% c("Save both", "Save the reach only")

  ##############################################################################
  #### 8. Write ####
  ##############################################################################

  #### Product 0 first - the record of what was measured ####
  survey_dir <- get_gut_survey_dir()
  if (save_fall && !is.null(fall$p0)) {
    r <- write_fall_rod_file(fall$p0$table, file.path(survey_dir, fall$p0$filename))
    if (!isTRUE(r)) return(cancel(paste0("Could not write the rod readings: ", r,
                                         " - nothing saved")))
    cat("\u2713 Readings filed: ", fall$p0$filename, "\n", sep = "")
  }
  if (save_reach && isTRUE(reach$trupulse)) {
    r <- archive_trupulse_export(reach$from, file.path(survey_dir, reach$filename))
    if (!isTRUE(r)) return(cancel(paste0("Could not file the TruPulse export: ", r,
                                         " - nothing saved to metadata")))
    cat("\u2713 Export filed:   ", reach$filename, "\n", sep = "")
  }

  #### Roles and survey rows, as one change ####
  # Roles assigned with no survey behind them, or a survey against roles that
  # were never saved, is half an entry
  rows <- rbind(if (save_fall) fall_rows, if (save_reach) reach_rows)
  result <- with_metadata_change("recording a paired survey", {
    if (roles_unset) {
      metadata <- load_zentra_metadata()
      p_idx <- which(metadata$unique_id == primary$unique_id)
      o_idx <- which(metadata$unique_id == other$unique_id)
      metadata$device_role[p_idx[1]] <- "primary"
      metadata$device_role[o_idx[1]] <- "secondary"
      save_device_metadata(metadata)
    }
    add_survey_rows(rows)
  })
  if (!isTRUE(result)) {
    cat("\u274c ", result, " - nothing saved to metadata\n", sep = "")
    return(invisible(NULL))
  }
  if (roles_unset) cat("\u2713 Roles assigned\n")
  cat("\u2713 Survey recorded: ", nrow(rows), " row", if (nrow(rows) != 1) "s", "\n", sep = "")

  #### Maintenance log ####
  bits <- character(0)
  if (save_fall) {
    bits <- c(bits, sprintf("upstream %s, downstream %s; fall %.4f m [%s]",
                            device_label(fall$up_dev, with_role = TRUE),
                            device_label(fall$dn_dev, with_role = TRUE),
                            fall$value_m, fall$summary))
  }
  if (save_reach) {
    bits <- c(bits, sprintf("reach %.2f m [%s]", reach$value_m, reach$summary))
  }
  saved <- load_surveys()
  s_cm <- survey_height(other$unique_id, "sensor", primary$unique_id, "sensor", saved)
  s_reach <- survey_reach(other$unique_id, primary$unique_id, saved)
  slope_saved <- if (!is.na(s_cm)) compute_slope(abs(s_cm) / 100, s_reach) else NA_real_
  if (!is.na(slope_saved)) bits <- c(bits, sprintf("slope %.5f", slope_saved))

  log_result <- create_maintenance_entry(
    field_visit_date = survey_date,
    station_id       = station_id,
    unique_id        = other$unique_id,
    action_type      = "survey",
    details          = paste0("Gut survey: ", paste(bits, collapse = "; ")),
    logged_by        = logged_by
  )
  # create_maintenance_entry() announces its own success
  if (!isTRUE(log_result)) {
    cat("\u26a0\ufe0f  Saved, but the maintenance log entry failed: ", log_result, "\n", sep = "")
  }

  visit <- update_last_visit(station_id, survey_date)
  if (!isTRUE(visit)) cat("\u26a0\ufe0f  Could not update last_visit: ", visit, "\n", sep = "")

  cat("\n\u2713 Survey complete\n")
  invisible(TRUE)
}

#' A logger already serving another station: show its ports, and ask
#'
#' A new station on a logger that already has ports of its type usually means
#' sensors were just plugged in - or the ports were configured a step earlier,
#' on the other station's workflow. Either way the user is shown what the
#' logger has and asked, rather than told "already configured" and moved on.
#'
#' @param device_serial Character
#' @param station_type Character. The new station's type
#' @return Invisibly, TRUE if the ports were left as they are
review_shared_ports <- function(device_serial, station_type) {
  p <- get_active_ports(device_serial)
  p <- p[order(as.integer(p$port)), , drop = FALSE]
  cat("\n", device_label(device_serial), " already has ports configured - shared with its other station:\n",
      sep = "")
  for (i in seq_len(nrow(p))) {
    depth <- if ("depth_cm" %in% names(p) && !is.na(p$depth_cm[i]) && nzchar(p$depth_cm[i]))
               paste0(" @ ", p$depth_cm[i], "cm") else ""
    broken <- if ("status" %in% names(p) && tolower(p$status[i]) %in% "defunct") " [DEFUNCT]" else ""
    cat("  Port ", p$port[i], ": ", p$sensor[i], " (", p$type[i], ")", depth, broken, "\n", sep = "")
  }
  if (ui_yes_no(paste0("Do these include this ", station_type, " station's sensors, as they are now?"),
                allow_quit = FALSE) == "Y") {
    cat("\u2713 Ports unchanged\n")
    return(invisible(TRUE))
  }
  ui_update_ports(preset_device_serial = device_serial)
  invisible(FALSE)
}


# --- DEVICE & STATION MANAGEMENT ---
#' Interactive device addition
#' Adds a new device to metadata - either at new station or existing station
#' @param is_new_station Logical. TRUE for brand new station, FALSE for existing
#' @param preset_station_id Character. Optional. If provided, skips station selection
#' @return List with device_serial, or NULL if quit
ui_add_device <- function(is_new_station = TRUE, preset_station_id = NULL,
                          suppress_logging = FALSE, companion_of = NULL,
                          companion_type = NULL, replacing_uid = NULL) {
  cat("\n============================================\n")
  if (is_new_station) {
    cat("  Add Device - New Station\n")
  } else {
    cat("  Add Device - Existing Station\n")
  }
  cat("============================================\n\n")
  
  # Initialize variables
  station_id <- preset_station_id  # May be NULL
  site_full <- NULL
  site <- NULL
  watershed <- NULL
  area <- NULL
  station_type <- NULL
  
  ################################################################################
  #### SECTION A: STATION INFORMATION ####
  ################################################################################
  
  if (is_new_station) {
    cat("--- NEW STATION INFORMATION ---\n\n")
    
    ## Watershed
    # A companion station is the second station on a logger that has just been
    # set up: same site, same logger, only the sensor type differs. Asking for
    # the watershed again - having been told it a minute ago - is the kind of
    # thing that makes a correct workflow feel wrong.
    if (!is.null(companion_of)) {
      watershed <- companion_of$watershed
      area      <- companion_of$area
      site_full <- companion_of$site_full
      site      <- companion_of$site

      cat("\n--- SITE (inherited) ---\n\n")
      cat("  Watershed: ", watershed, "\n", sep = "")
      if (!is.na(area) && nzchar(trimws(as.character(area)))) {
        cat("  Area:      ", area, "\n", sep = "")
      }
      cat("  Site:      ", site_full, " (", site, ")\n\n", sep = "")
      cat("  Same site as ", companion_of$station_id,
          " - it is the same logger.\n", sep = "")
    } else {

    existing_watersheds <- get_metadata_unique_values("watershed")
    watershed <- ui_select_or_specify("Select watershed:", existing_watersheds)
    if (is.null(watershed)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    cat("✓ Watershed:", watershed, "\n")
    
    ## Area (optional)
    # Area groups stations that belong together within a site. For field
    # stations that is usually a subcatchment; for campus work it is the
    # experiment, which keeps station IDs a plain counter while the grouping
    # stays filterable.
    cat("\nArea groups stations within a site - a subcatchment in the field,\n")
    cat("or the name of the experiment for campus work.\n")
    specify_area <- ui_yes_no("Specify an area?", allow_quit = FALSE)
    if (specify_area == "N") {
      area <- NA
      cat("✓ No area recorded\n")
    } else {
      # Only this watershed's areas: an area belongs to one watershed, and
      # Mint offered under Salt River is a slip waiting to happen
      meta_areas <- load_zentra_metadata()
      existing_areas <- sort(unique(meta_areas$area[meta_areas$watershed %in% watershed &
                                                     !is.na(meta_areas$area) &
                                                     nzchar(trimws(meta_areas$area))]))
      area <- ui_select_or_specify(paste0("Select area in ", watershed, ":"), existing_areas)
      if (is.null(area)) {
        cat("❌ Canceled\n")
        return(NULL)
      }
      cat("✓ Area:", area, "\n")
    }
    
    ## Site full name
    # Offered as a list, not free text. A new station at an existing site is
    # the common case, and a typo here ("Salt River 1 " vs "Salt River 1")
    # silently fragments a site into two across the metadata.
    # Only sites in the watershed just chosen. A site belongs to exactly one
    # watershed, so offering all of them makes the list long and invites
    # picking one from the wrong catchment.
    all_meta <- load_zentra_metadata()
    has_area <- !is.na(area) && nzchar(trimws(area))
    in_area <- all_meta$watershed %in% watershed &
      (if (has_area) all_meta$area %in% area else is.na(all_meta$area) | !nzchar(trimws(all_meta$area)))
    existing_sites <- unique(all_meta$site_full[in_area])
    existing_sites <- sort(existing_sites[!is.na(existing_sites)])

    cat("\nSite name - lower numbers are further upstream.\n")

    # A new site is asked for by its number: the name follows from the
    # watershed and area, which is how every site is already named
    new_label <- "new site"
    site_number <- NA
    pick <- if (length(existing_sites) == 0) new_label else
      ui_select_from_menu(paste0("Select site in ", watershed,
                                 if (has_area) paste0(" ", area), ":"),
                          c(existing_sites, new_label))
    if (is.null(pick)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    if (pick != new_label) {
      site_full <- pick
    } else {
      repeat {
        cat("Site number: ")
        site_number <- suppressWarnings(as.integer(trimws(readline())))
        if (!is.na(site_number) && site_number > 0) break
        cat("⚠️  A whole number, e.g. 1\n")
      }
      suggested <- paste(c(watershed, if (has_area) area, site_number), collapse = " ")
      if (suggested %in% all_meta$site_full) {
        cat("⚠️  '", suggested, "' is already a site - choose it from the list\n", sep = "")
        cat("❌ Canceled\n")
        return(NULL)
      }
      cat("  Site name: ", suggested, "\n", sep = "")
      if (ui_yes_no("Use this name?", allow_quit = FALSE) == "Y") {
        site_full <- suggested
      } else {
        cat("Enter site full name: ")
        site_full <- trimws(readline())
        if (site_full == "") {
          cat("❌ Site name cannot be empty\n")
          return(NULL)
        }
      }
    }
    cat("✓ Site:", site_full, "\n")
    
    ## Site abbreviation
    # site_full and site are a pair. If the site already exists, its
    # abbreviation is already established - deriving it removes any chance of
    # the two disagreeing.
    metadata_all <- all_meta
    matching <- metadata_all$site[metadata_all$site_full == site_full]
    matching <- unique(matching[!is.na(matching)])
    
    if (length(matching) == 1) {
      site <- matching
      cat("✓ Site abbrev:", site, "(existing)\n")
      
    } else if (length(matching) > 1) {
      # Already fragmented - make the user resolve it rather than guessing
      cat("\n⚠️  Site '", site_full, "' has more than one abbreviation in use: ",
          paste(matching, collapse = ", "), "\n", sep = "")
      cat("   This should not happen. Choose the correct one.\n")
      site <- ui_select_or_specify("Select site abbreviation:", matching)
      if (is.null(site)) {
        cat("❌ Canceled\n")
        return(NULL)
      }
      cat("✓ Site abbrev:", site, "\n")
      
    } else {
      # Suggested from the sites already in this area - sgm2 makes the next
      # Mint site sgm-something - or, in an area not used before, from the
      # watershed's own letters plus the area's first
      prefix_of <- function(x) unique(sub("[0-9]+$", "", x[!is.na(x) & nzchar(x)]))
      number <- if (!is.na(site_number)) site_number else
        suppressWarnings(as.integer(sub(".*?([0-9]+)$", "\\1", site_full, perl = TRUE)))
      prefixes <- prefix_of(all_meta$site[in_area])
      if (length(prefixes) != 1 && has_area) {
        ws <- prefix_of(all_meta$site[all_meta$watershed %in% watershed &
                                        (is.na(all_meta$area) | !nzchar(trimws(all_meta$area)))])
        prefixes <- if (length(ws) == 1) paste0(ws, tolower(substr(area, 1, 1))) else character(0)
      }
      suggested <- if (length(prefixes) == 1 && !is.na(number)) paste0(prefixes, number) else NA

      cat("\nSite abbreviation - two or three letters for the watershed, plus one\n")
      cat("for the area if needed, followed by the site number.\n")
      if (!is.na(suggested)) {
        cat("  Suggested: ", suggested, "\n", sep = "")
        cat("  Press Enter to accept, or type a different one: ")
      } else {
        cat("  Enter abbreviation (e.g. 'sr1' for Salt River 1): ")
      }
      site <- tolower(trimws(readline()))
      if (site == "" && !is.na(suggested)) site <- suggested
      if (site == "") {
        cat("❌ Site abbreviation cannot be empty\n")
        return(NULL)
      }
      
      if (site %in% get_metadata_unique_values("site")) {
        existing_full <- unique(metadata_all$site_full[metadata_all$site == site])
        cat("\n⚠️  Abbreviation '", site, "' is already used by: ",
            paste(existing_full, collapse = ", "), "\n", sep = "")
        confirm <- ui_yes_no("Use it anyway?", allow_quit = FALSE)
        if (confirm == "N") {
          cat("❌ Canceled\n")
          return(NULL)
        }
      }
      cat("✓ Site abbrev:", site, "\n")
    }
    
    ## Station type
    }   # end of the non-companion site questions

    if (!is.null(companion_type)) {
      # Known: it is the type whose sensors are on the logger with no station
      station_type <- companion_type
      cat("\u2713 Station type: ", station_type,
          " (the sensors already configured)\n", sep = "")
    } else {
      existing_types <- get_metadata_unique_values("station_type")
      station_type <- ui_select_or_specify("Select station type:", existing_types)
      if (is.null(station_type)) {
        cat("❌ Canceled\n")
        return(NULL)
      }
      cat("✓ Station type:", station_type, "\n")
    }
    
    ## Station ID
    # Is this actually a new station at all? A second logger at a paired
    # stream gauge is a second DEVICE at one station, not a second station -
    # and arriving here with the bare ID already taken almost always means the
    # wrong branch was chosen four prompts ago. Say so now rather than
    # suggesting a counter that quietly creates a station nobody wanted.
    base_id <- paste0(tolower(site), "_", tolower(station_type))
    
    if (isTRUE(validate_station_exists(base_id))) {
      cat("\n⚠️  Station '", base_id, "' already exists at this site.\n\n", sep = "")
      
      if (tolower(station_type) == "hydro") {
        cat("   A stream gauge often has TWO loggers - a primary, normally\n")
        cat("   downstream, and a secondary - but they are two devices at ONE station,\n")
        cat("   sharing the station ID. That is not a second station.\n\n")
      }
      
      cat("   To add another logger to '", base_id, "', cancel and choose\n", sep = "")
      cat("   'New device at existing active station' from the previous menu.\n\n")
      cat("   Continue here ONLY if this is a genuinely separate station that\n")
      cat("   happens to share the site and type - it will be numbered.\n\n")
      
      if (ui_yes_no("Is this a separate new station?", allow_quit = FALSE) == "N") {
        cat("\n❌ Canceled - use 'New device at existing active station' instead\n")
        return(NULL)
      }
    }
    
    # station_id is derivable from site + station_type, so typing it is pure
    # error surface - a typo creates a station that matches nothing. Suggest
    # it and let the user ratify.
    suggested <- suggest_station_id(site, station_type)
    
    cat("\nStation ID\n")
    cat("  Suggested: ", suggested, "\n", sep = "")
    cat("  Press Enter to accept, or type a different ID:\n")
    
    station_id <- trimws(readline())
    if (station_id == "") station_id <- suggested
    station_id <- tolower(station_id)
    
    # Check if station already exists
    existing_check <- validate_station_exists(station_id)
    if (isTRUE(existing_check)) {
      cat("⚠️  Warning: Station '", station_id, "' already exists!\n", sep = "")
      cat("If you intended to have more than one station in the same site (e.g. sr1) of the same type,\n") 
      cat("(like two VWC stations), number these (e.g., sr1_vwc1 and sr1_vwc2), with higher numbers further downslope.\n\n")
      cat("OR if you meant to add two devices to the SAME STATION (this would be rare), use 'New device at existing station' instead.\n")
      return(NULL)
    }
    cat("✓ Station ID:", station_id, "\n")
    
  } else {
    # Existing station
    
    if (is.null(preset_station_id)) {
      # No preset - prompt user to select
      cat("--- SELECT EXISTING STATION ---\n\n")
      
      station_list <- get_station_list()
      station_options <- sapply(station_list, function(s) {
        paste0(s$station_id, " (", s$label, ")")
      })
      
      selected <- ui_select_from_menu("Select station:", station_options)
      if (is.null(selected)) {
        cat("❌ Canceled\n")
        return(NULL)
      }
      
      # Extract station_id
      station_id <- sub(" \\(.*\\)$", "", selected)
    } else {
      # Preset station provided (from replacement workflow)
      cat("--- ADDING TO EXISTING STATION ---\n\n")
      cat("Station:", preset_station_id, "\n\n")
    }
    
    # Get station devices and inherit metadata
    # The station's current row, not its first - see get_station_current_row()
    station_devices <- get_station_current_row(station_id)
    if (is.null(station_devices)) {
      cat("❌ No devices found at ", station_id, "\n", sep = "")
      return(NULL)
    }
    
    watershed <- station_devices$watershed[1]
    area <- station_devices$area[1]
    site_full <- station_devices$site_full[1]
    site <- station_devices$site[1]
    station_type <- station_devices$station_type[1]
    
    if (is.null(preset_station_id)) {
      cat("✓ Station:", station_id, "\n")
    }
    cat("✓ Inherited from: ", site_full, " ", station_type, " (", station_id, ")\n", sep = "")
  }
  
  ################################################################################
  #### SECTION B-F: DEVICE INFORMATION WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
    ################################################################################
    #### SECTION B: DEVICE INFORMATION ####
    ################################################################################
    
    cat("\n--- DEVICE INFORMATION ---\n\n")
    
    ## Device serial
    if (!is.null(companion_of)) {
      # The whole point of a companion station is that it is on the SAME
      # logger. Typing the serial again is a chance to mistype it.
      device_serial <- companion_of$device_serial
      cat("Device: ", device_label(device_serial), " (the logger just configured)\n", sep = "")
    } else {
      cat("Enter device serial number:\n")
      cat("  For Zentra ZL6: format 'z6-12345'\n")
      cat("  For HOBO: format '123456' or actual serial\n")
      cat("Serial: ")
      device_serial <- trimws(readline())
      if (device_serial == "") {
        cat("❌ Device serial cannot be empty\n")
        return(NULL)
      }
    }
    
    # Set when this serial is already active at another station type, so the
    # device details below can be inherited instead of re-entered
    shared_row <- NULL

    # Check if serial already exists and is still active
    metadata <- load_zentra_metadata()
    existing <- metadata[metadata$device_serial == device_serial, ]
    
    if (nrow(existing) > 0) {
      # Device exists - check if it's in a terminal status
      terminal_statuses <- TERMINAL_STATUSES
      
      if (all(existing$status %in% terminal_statuses)) {
        # All entries are terminal - allow reuse
        cat("ℹ️  Note: Serial '", device_serial, "' previously used (status: ", 
            existing$status[1], ")\n", sep = "")
        cat("   Reusing serial for new deployment\n\n")
      } else {
        # At least one entry is still active.
        #
        # That is not automatically wrong. One ZL6 commonly serves two
        # stations - an ATMOS on one port for weather, TEROS sensors on the
        # others for soil moisture - registered as two stations sharing a
        # serial. validate_metadata() permits exactly this: one active row per
        # serial PER STATION TYPE. So reject only a genuine duplicate, which
        # is the same serial at the same station type.
        active <- existing[!existing$status %in% terminal_statuses, , drop = FALSE]
        same_type <- active[tolower(active$station_type) == tolower(station_type), ,
                            drop = FALSE]

        if (nrow(same_type) > 0) {
          cat("❌ Device serial '", device_serial, "' is already active as a ",
              station_type, " device\n", sep = "")
          cat("   Station: ", same_type$station_id[1],
              "   Status: ", same_type$status[1], "\n", sep = "")
          cat("\n   A device can serve two stations only if they are different\n")
          cat("   station types, e.g. one ZL6 running both weather and vwc.\n")
          return(NULL)
        }

        # A companion was asked for by name a moment ago - asking again
        # whether the logger serves a second station is asking twice
        if (is.null(companion_of)) {
        cat("\n\u2139\ufe0f  Serial '", device_serial, "' is already in use at:\n", sep = "")
        for (i in seq_len(nrow(active))) {
          cat("     ", active$station_id[i], " (", active$station_type[i], ")\n",
              sep = "")
        }
        cat("\n   One logger can serve several stations - a ZL6 with an ATMOS\n")
        cat("   and TEROS sensors is a weather station and a vwc station at\n")
        cat("   once. Its ports are configured once, on the device.\n\n")
        }

        if (is.null(companion_of) &&
            ui_yes_no("Add this device to a new station as well?",
                      allow_quit = FALSE) == "N") {
          cat("\u274c Canceled\n")
          return(NULL)
        }

        # It is the same physical box, so everything that describes the DEVICE
        # rather than the station is already on record. Re-typing it is not
        # just tedious - it is how one logger ends up with two spellings of
        # its name and coordinates a few meters apart.
        shared_row <- active[1, ]
      }
    }
    cat("✓ Device serial:", device_serial, "\n")
    
    ## Everything below describes the DEVICE, not the station. When the serial
    ## is already on record, take it from there rather than asking again.
    if (!is.null(shared_row)) {

      mfger           <- shared_row$mfger
      model           <- shared_row$model
      device_name     <- shared_row$device_name
      lat             <- shared_row$lat
      lon             <- shared_row$lon
      elev            <- shared_row$elev
      # This branch predates elev_source; without it the confirmation summary
      # reaches an undefined variable and the whole workflow aborts
      elev_source     <- if ("elev_source" %in% names(shared_row)) {
        shared_row$elev_source
      } else NA_character_
      interval        <- shared_row$interval_min
      timezone        <- shared_row$timezone
      status          <- shared_row$status

      # deploy_datetime is NOT inherited. The logger's location, model and
      # elevation are genuinely shared - it is one box - but a station begins
      # when ITS sensors go in, which can be years later. sr1_vwc3 inherited
      # 2021 from the weather logger it shares when its TEROS went in on
      # 2026-09-04, which would have attributed five years of readings to a
      # station that did not exist.
      deploy_datetime <- NULL

      cat("\n--- DEVICE DETAILS (inherited) ---\n\n")
      cat("  Manufacturer: ", mfger, "\n", sep = "")
      cat("  Model:        ", blank_or_value(model), "\n", sep = "")
      cat("  Name:         ", blank_or_value(device_name), "\n", sep = "")
      cat("  Location:     ", lat, ", ", lon, "\n", sep = "")
      cat("  Elevation:    ", blank_or_value(elev), " m",
          if (!is.na(elev_source)) paste0(" (", elev_source, ")") else "",
          "\n", sep = "")
      cat("  Interval:     ", interval, " minutes\n", sep = "")
      cat("  Status:       ", status, "\n\n", sep = "")
      cat("  Taken from ", shared_row$station_id,
          " - it is the same physical logger.\n", sep = "")

      ## When did THIS station start?
      cat("\n--- WHEN THIS STATION STARTED ---\n\n")
      cat("The logger has been at this site since ",
          blank_or_value(shared_row$deploy_datetime), ", but this station\n",
          sep = "")
      cat("begins when its own sensors went in - which may be the same day or\n")
      cat("years later.\n\n")

      if (ui_yes_no("Did this station's sensors go in on the same day as the logger?",
                    allow_quit = FALSE) == "Y") {
        deploy_datetime <- shared_row$deploy_datetime
        cat("\u2713 Deployed: ", blank_or_value(deploy_datetime), "\n", sep = "")
      } else {
        deploy_datetime <- ui_prompt_datetime(
          "When did this station's sensors go in?")
        if (is.null(deploy_datetime)) {
          cat("\u274c Canceled\n")
          return(NULL)
        }
      }
      cat("  Correct any of it later with 'Correct device details'.\n")

      ## Sensor height: asked here too, as on the path below. Never inherited -
      ## it belongs to this station's sensors, not the logger - and not asked
      ## for vwc, whose depths are per port. Without it the confirmation below
      ## stopped on "object 'sensor_height_cm' not found" (dor1_vwc1, October
      ## 2026), before anything was written.
      sensor_height_cm <- ui_prompt_sensor_height(station_type)

      ## Device role is the one thing that is per-station, not per-device
      device_role <- ui_prompt_device_role(station_type, station_id, replacing_uid)
      if (identical(device_role, "cancel")) {
        cat("\u274c Canceled\n")
        return(NULL)
      }

      ## The metadata review happens after the row exists, like the branch
      ## below - the caller asks once ports and any survey are settled.
      metadata_approved <- FALSE

    } else {

    ## Manufacturer
    existing_mfgers <- get_metadata_unique_values("mfger")
    mfger <- ui_select_or_specify("Select manufacturer:", existing_mfgers)
    if (is.null(mfger)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    cat("✓ Manufacturer:", mfger, "\n")
    
    ## Model
    # The model determines what the numbers mean. A HOBO U20-001-01 is the 9 m
    # range version and the -04 is 4 m - without this, you cannot tell whether a
    # pressure reading is in spec or off the end of the sensor.
    # Only this manufacturer's models, each with its range where it has one
    meta_models <- load_zentra_metadata()
    existing_models <- sort(unique(meta_models$model[tolower(meta_models$mfger) == tolower(mfger) &
                                                      !is.na(meta_models$model)]))
    if (length(existing_models) > 0) {
      shown <- model_label(existing_models)
      model <- ui_select_or_specify("Select model:", shown)
      if (is.null(model)) {
        cat("❌ Canceled\n")
        return(NULL)
      }
      if (model %in% shown) model <- existing_models[match(model, shown)]
    } else {
      cat("\nEnter device model (e.g. 'U20-001-01', 'ZL6'):\n")
      model <- trimws(readline())
      if (model == "") {
        model <- NA
        cat("✓ No model recorded\n")
      }
    }
    if (!is.na(model)) cat("✓ Model:", model, "\n")
    
    ## Device role (optional)
    device_role <- ui_prompt_device_role(station_type, station_id, replacing_uid)
    if (identical(device_role, "cancel")) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    
    ## Device name (optional)
    device_name <- ui_ask_device_name(device_serial)
    
    ################################################################################
    #### SECTION C: LOCATION ####
    ################################################################################
    
    cat("\n--- LOCATION ---\n\n")
    
    if (is_new_station) {
      # New station - prompt for location
      
      coords <- ui_prompt_coordinates()
      lat <- coords[["lat"]]
      lon <- coords[["lon"]]
      
      ## Elevation
      # Looked up now, while the coordinates are on screen and correctable.
      elev_result <- ui_prompt_elevation(lat, lon, station_type, device_role)
      elev <- elev_result$elev
      elev_source <- elev_result$elev_source
      
    } else {
      # Existing station - inherit location from the station's CURRENT row,
      # not its first. A station that has been relocated still holds the old
      # row, and inheriting from it puts the new device at the old position.
      current_row <- get_station_current_row(station_id)
      if (is.null(current_row)) {
        cat("❌ No devices found at ", station_id, "\n", sep = "")
        return(NULL)
      }
      lat <- current_row$lat
      lon <- current_row$lon
      # Never looked up again: at a paired gauge every logger carries the
      # primary's elevation, and a fresh lookup could differ by DEM noise
      se <- station_elevation(station_id)
      elev <- se$elev
      elev_source <- se$elev_source
      
      cat("✓ Location inherited from station:\n")
      cat("  Latitude:", lat, "\n")
      cat("  Longitude:", lon, "\n")
      if (!is.na(elev)) {
        cat("  Elevation:", elev, "m",
            if (!is.na(elev_source)) paste0(" (", elev_source, ")") else "", "\n")
      } else {
        cat("  Elevation: Not recorded\n")
      }
    }

    ## Sensor height
    # Per device, not per station. A replacement in the same housing can have
    # its predecessor's surveys carried over afterwards instead.
    sensor_height_cm <- ui_prompt_sensor_height(station_type)
    
    ################################################################################
    #### SECTION D: TIMING ####
    ################################################################################
    
    cat("\n--- TIMING ---\n\n")
    
    ## Logging interval
    repeat {
      cat("Enter logging interval in minutes (e.g., 15, 30, 60)\n")
      cat("Or press Enter for default (15 minutes):\n")
      interval_input <- trimws(readline())
      
      # Allow empty input for default
      if (interval_input == "") {
        interval <- 15
        cat("✓ Interval: 15 minutes (default)\n")
        break
      }
      
      interval <- suppressWarnings(as.numeric(interval_input))
      
      if (!is.na(interval) && interval > 0) {
        cat("✓ Interval:", interval, "minutes\n")
        break
      } else {
        cat("⚠️  Invalid interval. Must be a positive number.\n")
      }
    }
    
    ## Timezone
    existing_timezones <- get_metadata_unique_values("timezone")
    cat("\nSelect timezone:\n")
    for (i in seq_along(existing_timezones)) {
      cat("  ", i, ". ", existing_timezones[i], "\n", sep = "")
    }
    cat("  ", length(existing_timezones) + 1, ". other (specify)\n", sep = "")
    # Asked again on a slip rather than abandoning the whole entry, and a
    # typed zone is checked against the zones R knows - a misspelled one
    # would be saved and only fail later, when a time is read with it
    timezone <- NULL
    while (is.null(timezone)) {
      cat("\nEnter selection (or press Enter for ", PROJECT_TZ, "): ", sep = "")
      tz_input <- trimws(readline())
      tz_num <- suppressWarnings(as.numeric(tz_input))
      if (tz_input == "") {
        timezone <- PROJECT_TZ
      } else if (tolower(tz_input) == "q") {
        cat("❌ Canceled\n")
        return(NULL)
      } else if (!is.na(tz_num) && tz_num >= 1 && tz_num <= length(existing_timezones)) {
        timezone <- existing_timezones[tz_num]
      } else if (!is.na(tz_num) && tz_num == length(existing_timezones) + 1) {
        cat("Enter timezone (e.g. America/Puerto_Rico): ")
        typed <- trimws(readline())
        if (typed %in% OlsonNames()) {
          timezone <- typed
        } else {
          cat("⚠️  '", typed, "' is not a time zone R recognizes - spelled as in\n",
              "   America/Puerto_Rico, with the capitals and underscore\n", sep = "")
        }
      } else {
        cat("⚠️  Invalid selection\n")
      }
    }
    cat("✓ Timezone: ", timezone, "\n", sep = "")
    
    ## Deploy datetime
    deploy_datetime <- ui_prompt_datetime("When was device deployed?", 
                                          allow_now = TRUE, 
                                          timezone = timezone)
    if (is.null(deploy_datetime)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    cat("✓ Deploy datetime:", format(deploy_datetime), "\n")
    
    ################################################################################
    #### SECTION E: STATUS & SETTINGS ####
    ################################################################################
    
    cat("\n--- STATUS & SETTINGS ---\n\n")
    
    ## Status
    status <- ui_prompt_device_status()
    if (is.null(status)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    cat("✓ Status:", status, "\n")
    
    ## Metadata review happens AFTER the device exists, not here.
    #
    # The review asks whether the record matches what is physically out there.
    # At this point it demonstrably does not: the ports are not configured yet,
    # and for a paired gauge the survey has not been entered. Asking now would
    # have someone confirm a record that is known to be incomplete.
    #
    # The row is created unapproved and the caller asks once everything has
    # been entered.
    metadata_approved <- FALSE
    
    
    }

    ################################################################################
    #### SECTION F: CONFIRMATION ####
    ################################################################################
    
    cat("\n============================================\n")
    cat("Ready to add this device:\n")
    cat("  Station:   ", station_id, " (", site_full, ")\n", sep = "")
    cat("  Device:    ", if (!is.na(device_name) && nzchar(device_name))
          paste0(device_name, " (", device_serial, ")") else device_serial, "\n", sep = "")
    cat("  Model:     ", mfger, " ", model_label(model), "\n", sep = "")
    if (!is.na(device_role)) cat("  Role:      ", device_role, "\n", sep = "")
    cat("  Location:  ", lat, ", ", lon, "\n", sep = "")
    if (!is.na(elev)) {
      cat("  Elevation: ", elev, " m",
          if (!is.na(elev_source)) paste0(" (", elev_source, ")") else "", "\n", sep = "")
    } else {
      cat("  Elevation: not set\n")
    }
    if (!is.na(sensor_height_cm)) {
      cat("  Sensor height: ", sensor_height_cm, " cm above the ",
          if (tolower(station_type) == "weather") "ground" else "bed", "\n", sep = "")
    }
    cat("  Interval:  ", interval, " minutes\n", sep = "")
    cat("  Deploy:    ", format(deploy_datetime, "%Y-%m-%d %H:%M"), " (", timezone, ")\n", sep = "")
    cat("  Status:    ", status, "\n", sep = "")
    # The metadata review is not shown here - it is asked after the ports and
    # any survey, once there is a complete record to confirm.
    cat("============================================\n\n")
    
    confirm <- ui_yes_no("Confirm?", allow_quit = FALSE)
    if (confirm != "Y") {
      # User said no - offer to restart or cancel
      restart <- ui_yes_no("Start over and re-enter device information?", allow_quit = FALSE)
      
      if (restart != "Y") {
        cat("❌ Canceled - device not added\n")
        return(NULL)
      }
      
      cat("\n--- RESTARTING DEVICE ENTRY ---\n")
      # Loop continues, restarts from beginning of device info
    } else {
      break  # Exit repeat loop, proceed to save
    }
    
  }  # End repeat loop
  
  ################################################################################
  #### SECTION G: CALL LOGIC FUNCTION ####
  ################################################################################
  
  # Build device data structure
  device_data <- list(
    device_serial = device_serial,
    station_id = station_id,
    watershed = watershed,
    area = area,
    site_full = site_full,
    site = site,
    station_type = station_type,
    device_role = device_role,
    device_name = device_name,
    mfger = mfger,
    model = model,
    lat = lat,
    lon = lon,
    elev = elev,
    elev_source = elev_source,
    sensor_height_cm = sensor_height_cm,
    interval_min = interval,
    timezone = timezone,
    deploy_datetime = deploy_datetime,
    status = status,
    metadata_approved = metadata_approved
  )
  
  # The note and who is logging are asked before anything is saved, so the
  # device and its log entry can be one change: a device recorded with no
  # entry saying when and why it arrived is half a record
  if (!suppress_logging) {
    cat("\nAnything worth noting about this installation? (Enter to skip): ")
    install_note <- trimws(readline())
    logged_by <- ui_ask_whois_logging()
    with_note <- function(text) {
      if (nzchar(install_note)) paste0(text, ". ", install_note) else text
    }
  }
  who <- if (!is.na(device_name) && nzchar(device_name)) {
    paste0(device_name, " (", device_serial, ")")
  } else device_serial

  result <- tryCatch(with_metadata_change(
    if (is_new_station) "establishing a station" else "adding a device", local({
      out <- add_new_device(device_data)
      if (!isTRUE(out) || suppress_logging) return(out)
      create_maintenance_entry(
        field_visit_date = local_date(deploy_datetime),
        station_id = station_id,
        device_serial = device_serial,
        action_type = if (is_new_station) "station_established" else "device_added",
        details = with_note(if (is_new_station) {
          paste0("New station established: ", site_full, ", with ", who)
        } else {
          paste0("Device added to existing station: ", who)
        }),
        logged_by = logged_by
      )
    })), error = function(e) conditionMessage(e))

  if (!isTRUE(result)) {
    cat("❌ Not added - ", result, "\n   Nothing was saved.\n", sep = "")
    return(NULL)
  }

  cat("\n✓ Device added successfully!\n")
  if (!suppress_logging) {
    cat(if (is_new_station) "✓ Station establishment logged to maintenance\n"
        else "✓ Device addition logged to maintenance\n")
  }
  
  # Return device_serial for potential port initialization
  # Station and type as well as the serial - callers need them to reason about
  # ports, which belong to the device but are meaningful per station type
  return(list(device_serial   = device_serial,
              station_id      = station_id,
              station_type    = station_type,
              deploy_datetime = deploy_datetime))
}

#' Interactive device replacement
#' Marks old device as "replaced" and adds new device at same station
#' @return List with old_device_serial and new_device_serial, or NULL if quit
ui_replace_device <- function() {
  cat("\n============================================\n")
  cat("  Device Replacement\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION & OLD DEVICE ####
  ################################################################################
  
  cat("--- SELECT DEVICE TO REPLACE ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$label, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_active_station_devices(station_id)
  cat("✓ Station:", station_id, "\n\n")
  
  # Show devices at this station
  cat("Devices at this station:\n")
  for (i in 1:nrow(station_devices)) {
    cat("  ", i, ". ", device_label(station_devices[i, ]),
        " - ", station_devices$mfger[i], ", ",
        station_devices$status[i], "\n", sep = "")
  }
  
  # Select device to replace
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("\nSelect device to replace:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # The row chosen, by its place in the menu - not found again by serial
  old_device_row <- station_devices[match(selected_device, device_options), ]
  old_device_serial <- old_device_row$device_serial
  
  cat("✓ Replacing device:", device_label(old_device_row), "\n")
  cat("  Manufacturer:", old_device_row$mfger, "\n")
  cat("  Current status:", old_device_row$status, "\n\n")
  
  # Confirm replacement
  confirm_replace <- ui_yes_no(
    paste0("Mark '", device_label(old_device_row), "' as replaced and add new device?"),
    allow_quit = FALSE
  )
  
  if (confirm_replace != "Y") {
    cat("❌ Canceled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### ADD NEW DEVICE (using ui_add_device with preset station) ####
  ################################################################################
  
  cat("\n--- ADD REPLACEMENT DEVICE ---\n")
  cat("Station: ", station_id, " (", old_device_row$site_full, ")\n\n", sep = "")
  
  # One change: the new logger in and the old one retired, kept together or
  # not at all. Done as two, a retirement that failed left both loggers
  # current at the station, under a message saying the replacement was done.
  # The old logger came out when the new one went in - that moment, not the
  # moment this is typed, is where its deployment ends and its ports close
  # One change: the new logger in, the old one retired, the surveys that
  # still hold, and the log entry - kept together or not at all. Done
  # separately, a retirement that failed left both loggers current at the
  # station, under a message saying the replacement was done. The old logger
  # came out when the new one went in - that moment, not the moment this is
  # typed, is where its deployment ends and its ports close
  add_result <- NULL
  carried <- 0
  also_at <- character(0)
  n_open <- nrow(get_active_ports(old_device_serial))
  result <- tryCatch(with_metadata_change("replacing a device", local({
    add_result <<- ui_add_device(is_new_station = FALSE, preset_station_id = station_id,
                                 suppress_logging = TRUE,
                                 replacing_uid = old_device_row$unique_id)
    if (is.null(add_result)) return("canceled")
    when <- add_result$deploy_datetime
    out <- retire_row(old_device_row$unique_id, when, status = "replaced")
    if (!isTRUE(out)) return(out)
    cat("\u2713 ", device_label(old_device_row), " to be retired at ",
        format(when, "%Y-%m-%d %H:%M"),
        if (n_open > 0) paste0(", its ", n_open, " port configuration(s) closed") else "",
        "\n", sep = "")

    # One ZL6 can serve a weather and a vwc station at once. The box that came
    # out served both, so the box that went in takes over at both: the other
    # station gets its own row on the new logger, inheriting everything but
    # the device, and its row on the old one ends at the same moment
    meta_now <- load_zentra_metadata()
    others <- meta_now[meta_now$device_serial %in% old_device_serial &
                         meta_now$unique_id != old_device_row$unique_id &
                         !tolower(meta_now$status) %in% TERMINAL_STATUSES, , drop = FALSE]
    new_row <- meta_now[meta_now$device_serial %in% add_result$device_serial &
                          meta_now$station_id %in% station_id &
                          !tolower(meta_now$status) %in% TERMINAL_STATUSES, , drop = FALSE][1, ]
    for (k in seq_len(nrow(others))) {
      o <- others[k, ]
      cat("\u2713 ", device_label(old_device_row), " also served ", o$station_id,
          " - the new logger takes over there too\n", sep = "")
      out <- add_new_device(list(
        device_serial = add_result$device_serial, station_id = o$station_id,
        watershed = o$watershed, area = o$area, site_full = o$site_full, site = o$site,
        station_type = o$station_type, device_role = o$device_role,
        device_name = new_row$device_name, mfger = new_row$mfger, model = new_row$model,
        lat = o$lat, lon = o$lon, elev = o$elev, elev_source = o$elev_source,
        sensor_height_cm = NA, interval_min = new_row$interval_min,
        timezone = new_row$timezone, deploy_datetime = when, status = new_row$status,
        metadata_approved = FALSE))
      if (!isTRUE(out)) return(out)
      out <- retire_row(o$unique_id, when, status = "replaced")
      if (!isTRUE(out)) return(out)
      also_at <<- c(also_at, o$station_id)
    }

    # Surveys belong to the deployment they were measured on, so the new
    # logger starts with none. Where it went into the same housing and the
    # rebar was not touched, what was measured still holds - only a person
    # knows which
    new_uid <- resolve_deployment(add_result$device_serial, station_id, when)
    if (!is.na(new_uid)) carried <<- ui_carry_surveys(old_device_row$unique_id, new_uid)
    logged_by <- ui_ask_whois_logging()

    for (st in also_at) {
      out <- create_maintenance_entry(
        field_visit_date = local_date(when), station_id = st,
        device_serial = add_result$device_serial, action_type = "device_replacement",
        details = paste0("Replaced ", device_label(old_device_row), " with ",
                         device_label(add_result$device_serial), " - the same logger as ",
                         station_id),
        logged_by = logged_by)
      if (!isTRUE(out)) return(out)
    }
    create_maintenance_entry(
      field_visit_date = local_date(when),
      station_id = station_id,
      device_serial = add_result$device_serial,
      action_type = "device_replacement",
      details = paste0("Replaced ", device_label(old_device_row), " with ",
                       device_label(add_result$device_serial),
                       if (carried > 0) paste0("; ", carried, " survey row",
                                               if (carried != 1) "s", " carried over")),
      logged_by = logged_by
    )
  })), error = function(e) conditionMessage(e))

  if (is.null(add_result) || identical(result, "canceled")) {
    cat("❌ New device not added - replacement canceled\n")
    cat("   Old device status unchanged\n")
    return(NULL)
  }
  if (!isTRUE(result)) {
    cat("❌ Replacement not made - ", result, "\n", sep = "")
    cat("   Nothing was kept: neither logger was changed.\n")
    return(NULL)
  }

  new_device_serial <- add_result$device_serial
  cat("\n✓ Device replacement complete, and logged to maintenance\n")
  cat("  Old:", device_label(old_device_row), "(replaced)\n")
  cat("  New:", device_label(new_device_serial), "\n")
  if (length(also_at) > 0) {
    cat("  At ", station_id, " and ", paste(also_at, collapse = ", "), " - one logger\n", sep = "")
  }

  # Return both device serials
  # station_id as well as the serials - callers need it to record the metadata
  # review, which is per-station
  return(list(
    old_device_serial = old_device_serial,
    new_device_serial = new_device_serial,
    station_id        = station_id
  ))
}

#' Interactive station relocation
#' Moves a station to a new location - marks old device as "relocated" and creates new entry
#' @return TRUE if successful, NULL if quit
ui_relocate_station <- function() {
  cat("\n============================================\n")
  cat("  Station Relocation\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO RELOCATE ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$label, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_active_devices_or_notify(station_id, "station relocation")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  
  # Get most recent active device
  station_devices_sorted <- station_devices[order(as.POSIXct(station_devices$deploy_datetime), 
                                                  decreasing = TRUE), ]
  current_device <- station_devices_sorted[1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", current_device$site_full, "\n")
  cat("  Current device:", device_label(current_device), "\n")
  cat("  Current location:", current_device$lat, ",", current_device$lon, sep = " ")
  if (!is.na(current_device$elev)) {
    cat(" (", current_device$elev, "m)", sep = "")
  }
  cat("\n\n")
  
  ################################################################################
  #### CONFIRM RELOCATION ####
  ################################################################################
  
  confirm_relocate <- ui_yes_no(
    paste0("Relocate station '", station_id, "' to a new location?"),
    allow_quit = FALSE
  )
  
  if (confirm_relocate != "Y") {
    cat("❌ Canceled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### OTHER STATIONS ON THE SAME LOGGER ####
  ################################################################################
  
  # What physically moves is a DEVICE. When one logger serves a weather and a
  # vwc station, relocating only the station that was named leaves the other
  # recorded at coordinates its own logger has left - one box in two places.
  #
  # Whether a companion moved is not derivable: the logger may have gone to the
  # new site while its soil sensors stayed in the ground, or came out entirely.
  # Only a person knows, so each is asked about.
  also_moving    <- character(0)
  staying_behind <- character(0)
  
  companions <- character(0)
  {
    all_meta <- load_zentra_metadata()
    terminal <- TERMINAL_STATUSES
    same_box <- all_meta$device_serial == current_device$device_serial &
                !tolower(all_meta$status) %in% terminal &
                all_meta$station_id != station_id
    companions <- unique(all_meta$station_id[same_box])
    companions <- companions[!is.na(companions)]
  }
  
  if (length(companions) > 0) {
    cat("\n--- OTHER STATIONS ON THIS LOGGER ---\n\n")
    cat(device_label(current_device), " also serves:\n\n", sep = "")
    for (cs in companions) cat("  ", cs, "\n", sep = "")
    cat("\nThe logger is one physical box, so it cannot be in two places.\n")
    cat("For each, say whether that station moved with it.\n")
    
    for (cs in companions) {
      cat("\n")
      if (ui_yes_no(paste0("Did ", cs, " move to the new location too?"),
                    allow_quit = FALSE) == "Y") {
        also_moving <- c(also_moving, cs)
        cat("\u2713 ", cs, " moves as well\n", sep = "")
      } else {
        staying_behind <- c(staying_behind, cs)
        cat("\u2713 ", cs, " did not move - its sensors came out, so it will\n",
            "  be recorded as 'removed'\n", sep = "")
      }
    }
  }
  
  ################################################################################
  #### SAME DEVICE, OR A DIFFERENT ONE? ####
  ################################################################################
  
  # A station often moves and gets a fresh logger in the same field operation.
  # Logged as relocate-then-replace that leaves a row asserting the OLD device
  # was deployed at the NEW position, which never happened. Asking here keeps
  # it to one event.
  cat("\n--- DEVICE AT THE NEW LOCATION ---\n\n")
  cat("Is the same logger going to the new position, or a different one?\n\n")
  cat("  1. The same logger moves with the station\n")
  cat("  2. A different logger goes in - the old one comes out\n")
  # Looped. Anything that was not 2 used to mean "same logger", so a stray
  # keystroke - a latitude typed a question early - silently chose it.
  repeat {
    cat("\nSelection: ")
    device_choice <- trimws(readline())
    if (device_choice %in% c("1", "2")) break
    cat("\u26a0\ufe0f  Enter 1 or 2.\n")
  }
  
  new_device <- NULL
  reconfigure_ports <- FALSE
  
  if (device_choice == "2") {
    cat("\n--- REPLACEMENT DEVICE ---\n\n")
    
    repeat {
      cat("Enter the new device serial number: ")
      nd_serial <- trimws(readline())
      if (nzchar(nd_serial)) break
      cat("\u26a0\ufe0f  A serial is required.\n")
    }
    
    existing_mfgers <- get_metadata_unique_values("mfger")
    nd_mfger <- ui_select_or_specify("Select manufacturer:", existing_mfgers)
    if (is.null(nd_mfger)) {
      cat("\u274c Canceled\n")
      return(NULL)
    }
    
    # Only this manufacturer's models, with their ranges, as when adding one
    meta_models <- load_zentra_metadata()
    existing_models <- sort(unique(meta_models$model[tolower(meta_models$mfger) == tolower(nd_mfger) &
                                                      !is.na(meta_models$model)]))
    shown <- model_label(existing_models)
    nd_model <- ui_select_or_specify("Select model:", shown)
    if (is.null(nd_model)) {
      cat("\u274c Canceled\n")
      return(NULL)
    }
    if (nd_model %in% shown) nd_model <- existing_models[match(nd_model, shown)]
    
    nd_name <- ui_ask_device_name(nd_serial)
    
    new_device <- list(device_serial = nd_serial,
                       mfger         = nd_mfger,
                       model         = nd_model,
                       device_name   = nd_name)
    
    cat("\n\u2713 ", device_label(new_device), " will be recorded at the new position.\n", sep = "")
    cat("  ", device_label(current_device), " comes out with the station.\n", sep = "")
  } else {
    cat("\n\u2713 The same logger moves with the station\n")
    
    # Not assumed. A logger can move while some of its sensors stay in the
    # ground - a weather station relocating while the soil profile it also
    # served is left behind - and the ports would then describe sensors that
    # are no longer on it.
    if (!is_hobo_device_serial(current_device$device_serial)) {
      existing_ports <- get_active_ports(current_device$device_serial)
      # The sensors of a station staying behind stay with it - that was
      # answered above, and they close with it at the move. Only the moving
      # stations' sensors are in question
      meta_p <- load_zentra_metadata()
      port_station <- meta_p$station_id[match(existing_ports$unique_id, meta_p$unique_id)]
      staying_ports <- existing_ports[port_station %in% staying_behind, , drop = FALSE]
      existing_ports <- existing_ports[!port_station %in% staying_behind, , drop = FALSE]
      port_line <- function(d, k) paste0("  Port ", d$port[k], ": ", d$sensor[k],
                                         if (!is.na(d$depth_cm[k])) paste0(" @ ", d$depth_cm[k], "cm"),
                                         "\n")
      if (nrow(staying_ports) > 0) {
        cat("\nStaying behind, closed at the move:\n\n")
        for (k in seq_len(nrow(staying_ports))) cat(port_line(staying_ports, k), sep = "")
      }
      if (nrow(existing_ports) > 0) {
        cat("\n", if (nrow(staying_ports) > 0) "Moving with the logger" else "Its ports are currently",
            ":\n\n", sep = "")
        for (k in seq_len(nrow(existing_ports))) cat(port_line(existing_ports, k), sep = "")
        cat("\n")
        ports_same <- ui_yes_no(if (nrow(staying_ports) > 0) "Did all of these move with it?"
                                else "Did every one of these sensors move with it?",
                                allow_quit = FALSE)
        if (ports_same != "Y") {
          cat("\u2713 Noted - you will be taken through the ports after the move\n")
          reconfigure_ports <- TRUE
        } else {
          cat("\u2713 Ports unchanged\n")
          reconfigure_ports <- FALSE
        }
      } else {
        reconfigure_ports <- FALSE
      }
    } else {
      reconfigure_ports <- FALSE
    }
  }
  
  
  ################################################################################
  #### NEW LOCATION ####
  ################################################################################
  
  cat("\n--- NEW LOCATION ---\n\n")
  
  coords <- ui_prompt_coordinates("NEW ")
  new_lat <- coords[["lat"]]
  new_lon <- coords[["lon"]]

  ## Elevation at the new location
  # The station has moved, so its old elevation describes a different place.
  station_type_now <- current_device$station_type
  role_now <- current_device$device_role
  reloc_elev <- ui_prompt_elevation(new_lat, new_lon, station_type_now, role_now)

  # A logger in a new spot sits at a new height above the bed: the old
  # height belongs to the old deployment, and is not carried
  reloc_height <- ui_prompt_sensor_height(station_type_now)
  
  ################################################################################
  #### DEPLOYMENT AT NEW LOCATION ####
  ################################################################################
  
  cat("\n--- DEPLOYMENT AT NEW LOCATION ---\n\n")
  
  ## Deploy datetime at new location
  # Not in the future, and not before the deployment it ends began
  deploy_datetime <- ui_prompt_event_time(
    "When was station deployed at new location?",
    current_device$timezone,
    as.POSIXct(current_device$deploy_datetime, tz = PROJECT_TZ)
  )
  
  if (is.null(deploy_datetime)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  cat("✓ Deploy datetime:", format(deploy_datetime), "\n")
  
  ## Status at new location
  # The declared list, not whatever statuses happen to exist in the data. The
  # discovered version could not offer 'local', so a station relocated into a
  # dead cell spot had no honest way to be recorded.
  cat("\nStatus at the new location:\n")
  new_status <- ui_prompt_device_status(allow_quit = TRUE)
  if (is.null(new_status)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  cat("✓ Status:", new_status, "\n")
  
  ## The metadata review is NOT asked here.
  #
  # It asks whether the record matches what is physically out there, and at
  # this point it demonstrably does not: the summary has not been shown, the
  # move has not been made, and where a logger's sensors did not all travel
  # the ports have not been corrected. The rows are created unapproved and the
  # caller asks once everything is recorded - as establishment does.
  metadata_approved <- FALSE
  
  ################################################################################
  #### CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Station Relocation Summary:\n")
  cat("============================================\n")
  cat("Station: ", station_id, " (", current_device$site_full, ")\n", sep = "")
  cat("\nOLD LOCATION:\n")
  cat("  Device:   ", device_label(current_device), "\n", sep = "")
  cat("  Location: ", current_device$lat, ", ", current_device$lon,
      if (!is.na(current_device$elev)) paste0(" (", current_device$elev, " m)"), "\n", sep = "")
  cat("  Status:   \u2192 relocated\n")
  cat("\nNEW LOCATION:\n")
  if (is.null(new_device)) {
    cat("  Device:   ", device_label(current_device), " (same logger, new row)\n", sep = "")
  } else {
    cat("  Device:   ", device_label(new_device), ", replacing ",
        device_label(current_device), "\n", sep = "")
  }
  cat("  Location: ", new_lat, ", ", new_lon,
      if (!is.na(reloc_elev$elev)) paste0(" (", reloc_elev$elev, " m, ", reloc_elev$elev_source, ")"),
      "\n", sep = "")
  if (!is.na(reloc_height)) {
    cat("  Sensor height: ", reloc_height, " cm above the ",
        if (tolower(station_type_now) == "weather") "ground" else "bed", "\n", sep = "")
  }
  cat("  Deploy:   ", format(deploy_datetime, "%Y-%m-%d %H:%M"), "\n", sep = "")
  cat("  Status:   ", new_status, "\n", sep = "")
  # Not shown - the review is asked after the move, once there is something
  # complete to confirm.

  # A HOBO has no ports to speak of
  if (grepl("^z", current_device$device_serial, ignore.case = TRUE) || !is.null(new_device)) {
    if (is.null(new_device) && !isTRUE(reconfigure_ports)) {
      cat("\n  Ports: unchanged - the same logger with the same sensors moved\n")
    } else if (is.null(new_device)) {
      cat("\n  Ports: some sensors did not move. You will be taken through\n")
      cat("         the port configuration after this.\n")
    } else if (grepl("^z", new_device$device_serial, ignore.case = TRUE)) {
      cat("\n  Ports: ", device_label(current_device),
          "'s ports will be closed. The new\n", sep = "")
      cat("         logger is configured after this.\n")
    }
  }
  
  if (length(also_moving) > 0) {
    cat("\n  Also moving: ", paste(also_moving, collapse = ", "), "\n", sep = "")
  }
  if (length(staying_behind) > 0) {
    cat("  Recorded as removed: ", paste(staying_behind, collapse = ", "),
        "\n", sep = "")
  }
  
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm relocation?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Canceled - station not relocated\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  # One change: the move itself, the old row's visit, and an entry at every
  # station that moved. Saved separately, a failed log left a move nothing
  # recorded, and a failed visit date left the old row looking unvisited
  logged_by <- ui_ask_whois_logging()
  relocation_date <- local_date(deploy_datetime)
  # The rows of the stations staying behind, named before the move ends them
  meta_before <- load_zentra_metadata()
  staying_uid <- vapply(staying_behind, function(st) {
    meta_before$unique_id[meta_before$station_id == st &
                            meta_before$device_serial == current_device$device_serial &
                            !tolower(meta_before$status) %in% TERMINAL_STATUSES][1]
  }, character(1))
  result <- tryCatch(with_metadata_change("relocating a station", local({
    res <- relocate_station(
      station_id = station_id,
      new_lat = new_lat,
      new_lon = new_lon,
      deploy_datetime = deploy_datetime,
      new_status = new_status,
      metadata_approved = metadata_approved,
      new_device = new_device,
      also_moving = also_moving,
      staying_behind = staying_behind,
      new_elev = reloc_elev$elev,
      new_elev_source = reloc_elev$elev_source
    )
    if (!isTRUE(res$success)) return(res$error)

    # The sensor height at the new spot, against the new deployment
    if (!is.na(reloc_height)) {
      meta_new <- load_zentra_metadata()
      new_uid <- meta_new$unique_id[meta_new$unique_id %in% res$new_unique_ids &
                                      meta_new$station_id == station_id][1]
      weather <- tolower(station_type_now) == "weather"
      method <- attr(reloc_height, "method")
      if (is.null(method)) method <- if (weather && reloc_height == 200) "nominal" else "tape"
      out <- add_survey_rows(survey_row(
        station_id = station_id, unique_id = new_uid, measured_on = relocation_date,
        quantity = "height_cm", point = "sensor", value = as.numeric(reloc_height),
        relative_to = if (weather) "ground" else "bed", method = method))
      if (!isTRUE(out)) return(out)
    }

    # Somebody stood at that station on the day it was moved.
    # update_last_visit() skips relocated rows - right for a routine visit,
    # since a relocated row is closed - but the relocation itself IS the visit
    # that closed it, so it is set here directly
    meta_after <- load_zentra_metadata()
    old_idx <- which(meta_after$unique_id == current_device$unique_id)
    if (length(old_idx) > 0) {
      lv <- format_datetime_safe(meta_after$last_visit)
      lv[old_idx[1]] <- format(relocation_date, "%Y-%m-%d")
      meta_after$last_visit <- lv
      save_device_metadata(meta_after)
    }

    # The entry names the device that went IN, since that is what the new row
    # describes - and says which came out, so the swap is not left to be
    # inferred from two serials in the metadata
    details <- paste0("Station relocated from (", current_device$lat, ", ",
                      current_device$lon, ") to (", new_lat, ", ", new_lon, ")")
    if (!is.null(new_device)) {
      details <- paste0(details, "; device changed from ", device_label(current_device),
                        " to ", device_label(new_device))
    }
    serial_in <- if (is.null(new_device)) current_device$device_serial else new_device$device_serial
    for (st in unique(c(station_id, also_moving))) {
      out <- create_maintenance_entry(
        field_visit_date = relocation_date,
        station_id = st,
        device_serial = serial_in,
        action_type = "station_relocation",
        details = if (st == station_id) details else
          paste0(details, " - moved with ", station_id, ", on the same logger"),
        logged_by = logged_by
      )
      if (!isTRUE(out)) return(out)
    }
    # A station left behind had its sensors taken out: that is a removal,
    # and it is logged at that station like any other
    for (k in seq_along(staying_behind)) {
      out <- create_maintenance_entry(
        field_visit_date = relocation_date,
        station_id = staying_behind[k],
        unique_id = staying_uid[k],
        action_type = "device_removal",
        details = paste0("Removed - its logger, ", device_label(current_device),
                         ", moved with ", station_id, " and its sensors came out"),
        logged_by = logged_by
      )
      if (!isTRUE(out)) return(out)
    }
    TRUE
  })), error = function(e) conditionMessage(e))

  if (!isTRUE(result)) {
    cat("❌ Not relocated - ", result, "\n   Nothing was changed.\n", sep = "")
    return(NULL)
  }

  cat("\n✓ Station relocation complete, and logged to maintenance\n")
  cat("  Old row ends at ", format(deploy_datetime, "%Y-%m-%d %H:%M"),
      ", visited that day; a new row starts at the new location\n", sep = "")
  if (length(also_moving) > 0) {
    cat("  ", paste(also_moving, collapse = ", "), " moved with it\n", sep = "")
  }
  if (!is.null(new_device)) {
    cat("  Device changed to ", device_label(new_device), "\n", sep = "")
    cat("  Ports on ", device_label(current_device), " closed\n", sep = "")
  }
  
  # The caller needs the serial to offer port configuration when the logger
  # changed - a new box arrives with nothing configured.
  return(list(station_id     = station_id,
              station_type   = current_device$station_type,
              old_device_serial = current_device$device_serial,
              device_serial  = if (is.null(new_device)) current_device$device_serial
                               else new_device$device_serial,
              device_changed = !is.null(new_device),
              ports_need_work = isTRUE(reconfigure_ports),
              # Every station that moved, not only the one that was named. A
              # companion's record changed too, so it needs its own review.
              moved_stations = unique(c(station_id, also_moving)),
              removed_stations = staying_behind))
}

#' Asks when an event happened: not in the future, not before a moment it
#' cannot precede
#'
#' Removal and decommissioning both end a deployment at a moment typed in the
#' field's terms - which may be long before it is entered, and is checked
#' against the two mistakes a typed time can make.
#'
#' @param prompt Character
#' @param timezone Character. The zone the time is typed in
#' @param not_before POSIXct, or NA. The moment it cannot precede
#' @param not_before_what Character. What that moment is, for the message
#' @return POSIXct, or NULL if canceled
ui_prompt_event_time <- function(prompt, timezone, not_before = NA,
                                 not_before_what = "its current deployment began") {
  repeat {
    when <- ui_prompt_datetime(prompt, allow_now = TRUE, timezone = timezone)
    if (is.null(when)) return(NULL)
    if (when > Sys.time() + 60) {
      cat("\u26a0\ufe0f  That is in the future - enter when it actually happened\n\n")
      next
    }
    if (!is.na(not_before) && when < not_before) {
      cat("\u26a0\ufe0f  That is before ", not_before_what, " (",
          format(not_before, "%Y-%m-%d %H:%M", tz = PROJECT_TZ), ")\n\n", sep = "")
      next
    }
    return(when)
  }
}

#' Interactive station decommissioning
#' Shuts down a station permanently - marks device as "decommissioned"
#' Ends monitoring with no intention of resuming; reactivation stays possible
#' @return TRUE if successful, NULL if quit
ui_decommission_station <- function() {
  cat("\n============================================\n")
  cat("  Station Decommissioning\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO DECOMMISSION ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$label, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_station_devices(station_id)
  
  # Check if there's anything to decommission
  active_statuses <- c(ACTIVE_STATUSES, "removed")
  decommissionable <- station_devices[station_devices$status %in% active_statuses, ]
  
  if (nrow(decommissionable) == 0) {
    cat("⚠️  This station is already fully decommissioned.\n")
    cat("   All devices have status = 'decommissioned', 'replaced', or 'relocated'.\n")
    cat("   Nothing to do.\n")
    return(NULL)
  }
  
  # Get most recent active device for logging
  decommissionable_sorted <- decommissionable[order(as.POSIXct(decommissionable$deploy_datetime), 
                                                    decreasing = TRUE), ]
  current_device <- decommissionable_sorted[1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", current_device$site_full, "\n")
  cat("  Device:", device_label(current_device), "\n")
  cat("  Current status:", current_device$status, "\n")
  cat("  Location:", current_device$lat, ",", current_device$lon, "\n\n")
  
  ################################################################################
  #### CONFIRM DECOMMISSIONING ####
  ################################################################################
  
  cat("\u26a0\ufe0f  DECOMMISSIONING STATION\n\n")
  cat("Monitoring at this site ends, with no intention of resuming.\n\n")
  cat("If you expect to put something back here - the position is\n")
  cat("waiting, the logger just came out - use 'Device removal'\n")
  cat("instead. The difference is intent, not permanence:\n")
  cat("reactivation is possible, because nobody knows the future.\n\n")
  
  #### WHEN ####
  # The moment monitoring actually stopped, which may be long before it is
  # entered here: the deployments end then, their ports close then, and the
  # log entry is dated then. Not before the newest deployment began - a
  # station cannot stop before it started - and not in the future
  ending_rows <- decommissionable[tolower(decommissionable$status) %in% ACTIVE_STATUSES, , drop = FALSE]
  earliest <- if (nrow(ending_rows) > 0) max(as.POSIXct(ending_rows$deploy_datetime, tz = PROJECT_TZ)) else NA
  cat("When was the station shut down?\n")
  cat("(The moment monitoring stopped - date AND time, as exact as possible)\n\n")
  when <- ui_prompt_event_time("Enter shutdown datetime", current_device$timezone, earliest)
  if (is.null(when)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  cat("✓ Shut down:", format(when, "%Y-%m-%d %H:%M"), "\n\n")

  confirm_decommission <- ui_yes_no(
    paste0("Decommission station '", station_id, "' as of ",
           format(when, "%Y-%m-%d %H:%M"), "?"),
    allow_quit = FALSE
  )
  
  if (confirm_decommission != "Y") {
    cat("❌ Canceled - station not decommissioned\n")
    return(NULL)
  }
  
  # Double-check
  cat("\n⚠️  This is a significant action.\n")
  final_confirm <- ui_yes_no("Are you sure you want to decommission this station?", 
                             allow_quit = FALSE)
  
  if (final_confirm != "Y") {
    cat("❌ Canceled - station not decommissioned\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################

  # The station's deployments end, and their own ports close with them. A
  # port row belongs to one deployment, so a ZL6 that stays on site running
  # another station keeps that station's ports - nothing needs asking
  ports_now <- load_zentra_ports_data()
  ending <- ending_rows$unique_id
  n_closing <- sum(ports_now$unique_id %in% ending & is.na(ports_now$valid_to))

  result <- update_station_status(station_id, "decommissioned", when = when)

  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  if (n_closing > 0) {
    cat("\u2713 Closed ", n_closing, " port configuration(s) of the retired station\n", sep = "")
  }

  cat("\n✓ Station decommissioned successfully\n")
  cat("  Station:", station_id, "\n")
  cat("  Status: → 'decommissioned'\n")
  cat("  As of:", format(when, "%Y-%m-%d %H:%M"), "\n")
  cat("\n  Reactivation remains possible if circumstances change.\n")
  
  # Log to maintenance, dated when it happened rather than when it was entered
  log_result <- create_maintenance_entry(
    field_visit_date = local_date(when),
    station_id = station_id,
    device_serial = current_device$device_serial,
    action_type = "station_decommissioned",
    details = "Station decommissioned - monitoring stopped",
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Decommissioning logged to maintenance\n")
  }
  
  return(TRUE)
}

#' Interactive station reactivation
#' Reactivates a decommissioned station by adding a new device
#' Can use same location or new location
#' @return List with device_serial, or NULL if quit
ui_reactivate_station <- function() {
  cat("\n============================================\n")
  cat("  Reactivate Decommissioned Station\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### SELECT DECOMMISSIONED STATION ####
  ################################################################################
  
  cat("--- SELECT STATION TO REACTIVATE ---\n\n")
  
  # Get all devices and filter to decommissioned only
  metadata <- load_zentra_metadata()
  decommissioned <- metadata[metadata$status == "decommissioned", ]
  
  if (nrow(decommissioned) == 0) {
    cat("❌ No decommissioned stations found\n")
    return(NULL)
  }
  
  # Get unique stations from decommissioned devices
  decommissioned_stations <- unique(decommissioned$station_id)
  
  # Filter out stations that have been reactivated (have active devices)
  truly_decommissioned <- c()
  for (sid in decommissioned_stations) {
    station_devices <- metadata[metadata$station_id == sid, ]
    active_statuses <- ACTIVE_STATUSES
    has_active <- any(station_devices$status %in% active_statuses)
    
    if (!has_active) {
      # No active devices - truly decommissioned
      truly_decommissioned <- c(truly_decommissioned, sid)
    }
  }
  
  if (length(truly_decommissioned) == 0) {
    cat("❌ No fully decommissioned stations found\n")
    cat("   (All decommissioned stations have been reactivated)\n")
    return(NULL)
  }
  
  # Build station options from truly decommissioned stations
  station_options <- sapply(truly_decommissioned, function(sid) {
    station_decomm <- decommissioned[decommissioned$station_id == sid, ]
    station_decomm <- station_decomm[order(as.POSIXct(station_decomm$deploy_datetime), 
                                           decreasing = TRUE), ]
    device_row <- station_decomm[1, ]
    paste0(sid, " (", device_row$site_full, ")")
  })
  
  selected <- ui_select_from_menu("Select decommissioned station:", station_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  # Get decommissioned devices for this station and find the most recent
  station_decommissioned <- decommissioned[decommissioned$station_id == station_id, ]
  # Sort by deploy_datetime descending and take the most recent
  station_decommissioned <- station_decommissioned[order(as.POSIXct(station_decommissioned$deploy_datetime), 
                                                         decreasing = TRUE), ]
  old_device <- station_decommissioned[1, ]
  
  cat("✓ Station:", station_id, "\n")
  cat("  Site:", old_device$site_full, "\n")
  cat("  Last device:", device_label(old_device), "\n")
  cat("  Last location:", old_device$lat, ",", old_device$lon, "\n")
  cat("  Decommissioned status:", old_device$status, "\n\n")
  
  ################################################################################
  #### SAME OR NEW LOCATION? ####
  ################################################################################
  
  cat("--- REACTIVATION TYPE ---\n\n")
  cat("Reactivate at:\n")
  cat("  1. Previous location (", old_device$lat, ", ", old_device$lon, ")\n", sep = "")
  cat("  2. New location (different coordinates)\n")
  cat("  q. Cancel\n")
  cat("\nEnter selection: ")
  
  location_choice <- trimws(readline())
  
  if (tolower(location_choice) == "q") {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  same_location <- (location_choice == "1")
  
  if (same_location) {
    cat("✓ Reactivating at same location\n\n")
  } else if (location_choice == "2") {
    cat("✓ Reactivating at new location\n\n")
  } else {
    cat("❌ Invalid selection\n")
    return(NULL)
  }
  
  ################################################################################
  #### ADD DEVICE AT REACTIVATED STATION ####
  ################################################################################
  
  if (same_location) {
    # Same location - just add device and update location to match old
    cat("--- ADD DEVICE FOR REACTIVATION ---\n")
    cat("Station: ", station_id, " (", old_device$site_full, ")\n\n", sep = "")
    
    # Same coordinates as before, so the old elevation still describes this
    # place - carry its source with it rather than leaving the value unlabeled.
    # The device and its position are one change: both, or neither
    old_source <- if ("elev_source" %in% names(old_device)) {
      old_device$elev_source
    } else NA_character_
    add_result <- NULL
    result <- with_metadata_change("reactivating a station", {
      add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id,
                                  suppress_logging = TRUE)
      if (is.null(add_result)) "canceled" else
        update_device_location(add_result$device_serial, old_device$lat, old_device$lon,
                               old_device$elev, elev_source = old_source,
                               station_id = station_id)
    })
    if (is.null(add_result) || identical(result, "canceled")) {
      cat("❌ Reactivation canceled\n")
      return(NULL)
    }
    if (!isTRUE(result)) {
      cat("❌ Not reactivated - ", result, "\n   Nothing was kept.\n", sep = "")
      return(NULL)
    }
    new_device_serial <- add_result$device_serial
    cat("\n✓ Location set to match old station coordinates\n")
    
  } else {
    # New location - get coordinates first, then add device, then update location
    cat("--- NEW LOCATION FOR REACTIVATION ---\n\n")
    
    ## New latitude
    repeat {
      cat("Enter NEW latitude (decimal degrees, e.g., 18.3456):\n")
      lat_input <- trimws(readline())
      new_lat <- suppressWarnings(as.numeric(lat_input))
      
      if (!is.na(new_lat) && new_lat >= -90 && new_lat <= 90) {
        cat("✓ New latitude:", new_lat, "\n")
        break
      } else {
        cat("⚠️  Invalid latitude. Must be between -90 and 90.\n")
      }
    }
    
    ## New longitude
    repeat {
      cat("Enter NEW longitude (decimal degrees, e.g., -64.7890):\n")
      lon_input <- trimws(readline())
      new_lon <- suppressWarnings(as.numeric(lon_input))
      
      if (!is.na(new_lon) && new_lon >= -180 && new_lon <= 180) {
        cat("✓ New longitude:", new_lon, "\n")
        break
      } else {
        cat("⚠️  Invalid longitude. Must be between -180 and 180.\n")
      }
    }
    
    # Add device (ui_add_device will handle deploy datetime, status, metadata review)
    cat("\n--- ADD DEVICE FOR REACTIVATION ---\n")
    cat("Station:", station_id, "(", old_device$site_full, ")\n\n")
    
    # A different place needs its own elevation - leaving it NA meant every
    # station reactivated at new coordinates started without one
    react_elev <- ui_prompt_elevation(new_lat, new_lon,
                                      old_device$station_type,
                                      old_device$device_role)

    # The device and its new position are one change: both, or neither
    add_result <- NULL
    result <- with_metadata_change("reactivating a station", {
      add_result <- ui_add_device(is_new_station = FALSE, preset_station_id = station_id,
                                  suppress_logging = TRUE)
      if (is.null(add_result)) "canceled" else
        update_device_location(add_result$device_serial, new_lat, new_lon,
                               react_elev$elev, elev_source = react_elev$elev_source,
                               station_id = station_id)
    })
    if (is.null(add_result) || identical(result, "canceled")) {
      cat("❌ Device not added - reactivation canceled\n")
      return(NULL)
    }
    if (!isTRUE(result)) {
      cat("❌ Not reactivated - ", result, "\n   Nothing was kept.\n", sep = "")
      return(NULL)
    }
    new_device_serial <- add_result$device_serial
    cat("\n✓ Location set to new coordinates\n")
  }
  
  cat("\n✓ Station reactivated successfully!\n")
  cat("  Station:", station_id, "\n")
  cat("  New device:", device_label(new_device_serial), "\n")
  
  # Log to maintenance, dated when the new device went in
  log_result <- create_maintenance_entry(
    field_visit_date = local_date(add_result$deploy_datetime),
    station_id = station_id,
    device_serial = new_device_serial,
    action_type = "station_reactivated",
    details = "Station reactivated with new device",
    logged_by = ui_ask_whois_logging()
  )
  
  if (isTRUE(log_result)) {
    cat("✓ Reactivation logged to maintenance\n")
  }
  
  # Station and type too - the caller needs them to decide about ports, which
  # belong to the device but only mean something per station type
  return(list(device_serial = new_device_serial,
              station_id    = station_id,
              station_type  = old_device$station_type))
}

# --- PORT CONFIGURATION ---
#' Interactive port configuration initialization
#' Sets up initial port configuration for a new Zentra ZL6 device
#' ONLY for Zentra devices - HOBO devices don't have ports
#' @param device_serial Character. Device to configure (must start with 'z')
#' @return TRUE if successful, NULL if quit or error
ui_initialize_ports <- function(device_serial) {

  #### Already configured? ####
  # Ports belong to the device, not the station. A ZL6 shared between a
  # weather station and a vwc station has ONE set of six ports, configured
  # once - reconfiguring from the second station would create a duplicate
  # active set.
  existing_ports <- get_active_ports(device_serial)

  if (nrow(existing_ports) > 0) {
    cat("\n============================================\n")
    cat("  Ports Already Configured\n")
    cat("============================================\n\n")
    cat("Device ", device_label(device_serial), " already has an active port configuration:\n\n",
        sep = "")

    for (i in order(existing_ports$port)) {
      depth <- if (!is.na(existing_ports$depth_cm[i])) {
        paste0(" @ ", existing_ports$depth_cm[i], "cm")
      } else ""
      cat("  Port ", existing_ports$port[i], ": ", existing_ports$sensor[i],
          " (", existing_ports$type[i], ")", depth, "\n", sep = "")
    }

    cat("\nPorts belong to the DEVICE, not the station. Where one ZL6 serves\n")
    cat("two stations - an ATMOS for weather and TEROS sensors for soil\n")
    cat("moisture - both stations share this one configuration.\n\n")
    cat("To change a sensor, use 'Port configuration change' under existing\n")
    cat("station work, which closes the old entry and opens a new one.\n\n")

    return(invisible(NULL))
  }

  cat("\n============================================\n")
  cat("  Initialize Port Configuration\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### VALIDATION ####
  ################################################################################
  
  # Check if device is Zentra (starts with 'z')
  if (!grepl("^z", device_serial, ignore.case = TRUE)) {
    cat("❌ Error: Port configuration is only for Zentra ZL6 devices\n")
    cat("   Device '", device_serial, "' does not appear to be a ZL6 logger\n", sep = "")
    cat("   (ZL6 serials start with 'z')\n")
    return(NULL)
  }
  
  # Check if device exists
  valid <- validate_device_exists(device_serial)
  if (!isTRUE(valid)) {
    cat("❌ Error:", valid, "\n")
    return(NULL)
  }
  
  cat("Configuring ports for device:", device_label(device_serial), "\n\n")

  # One ZL6 can serve a weather station and a vwc station at once, and this
  # workflow runs inside a question about ONE of them. Without saying so, a
  # user setting up a weather station reasonably wonders whether the TEROS
  # ports belong here.
  cat("Configure every occupied port on this ZL6, whether or not the\n")
  cat("sensor belongs to the station you are working on. Ports belong\n")
  cat("to the logger, not the station.\n\n")
  
  ################################################################################
  #### PORT CONFIGURATION WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
    # Get existing sensor types for menu
    existing_sensors <- get_unique_sensor_types()
    
    # Initialize port config data frame
    port_config <- data.frame(
      port = 1:6,
      type = character(6),
      sensor = character(6),
      depth_cm = numeric(6),
      status = character(6),
      stringsAsFactors = FALSE
    )
    
    for (port_num in 1:6) {
      cat("\n--- PORT ", port_num, " ---\n", sep = "")
      
      # Ask if port is occupied
      occupied <- ui_yes_no(paste0("Is port ", port_num, " occupied?"), allow_quit = FALSE)
      
      if (occupied == "N") {
        # Empty port
        port_config$type[port_num] <- "none"
        port_config$sensor[port_num] <- "none"
        port_config$depth_cm[port_num] <- NA
        port_config$status[port_num] <- NA
        cat("✓ Port ", port_num, ": Empty\n", sep = "")
        next
      }
      
      # Port is occupied - get sensor details
      
      ## Sensor type
      sensor_type <- ui_select_or_specify(
        paste0("Select sensor for port ", port_num, ":"),
        existing_sensors,
        allow_quit = FALSE
      )
      port_config$sensor[port_num] <- sensor_type
      
      ## Auto-determine type (vwc/weather)
      sensor_category <- determine_sensor_type(sensor_type)
      port_config$type[port_num] <- sensor_category
      cat("✓ Sensor type detected:", sensor_category, "\n")
      
      ## Depth (only for VWC sensors typically)
      has_depth <- ui_yes_no("Does this sensor measure at a specific depth?", 
                             allow_quit = FALSE)
      
      if (has_depth == "Y") {
        repeat {
          cat("Enter depth in cm (e.g., 10, 30, 50): ")
          depth_input <- trimws(readline())
          depth <- suppressWarnings(as.numeric(depth_input))
          
          if (!is.na(depth) && depth >= 0) {
            port_config$depth_cm[port_num] <- depth
            cat("✓ Depth:", depth, "cm\n")
            break
          } else {
            cat("⚠️  Invalid depth. Must be a positive number.\n")
          }
        }
      } else {
        port_config$depth_cm[port_num] <- NA
        cat("✓ No depth measurement\n")
      }
      
      ## Defunct status
      is_working <- ui_yes_no("Is this sensor in good working order? (Considered 'defunct' - broken but still plugged in - if you say no)", 
                              allow_quit = FALSE)
      
      if (is_working == "N") {
        port_config$status[port_num] <- "defunct"
        cat("⚠️  Sensor marked as defunct\n")
      } else {
        port_config$status[port_num] <- NA
        cat("✓ Sensor is functional\n")
      }
      
      cat("✓ Port ", port_num, ": ", sensor_type, 
          if (!is.na(port_config$depth_cm[port_num])) paste0(" @ ", port_config$depth_cm[port_num], "cm") else "",
          "\n", sep = "")
    }
    
    ################################################################################
    #### VALIDATION ####
    ################################################################################
    
    # Check for duplicate ports (shouldn't happen with this UI, but safety check)
    occupied_ports <- port_config[port_config$sensor != "none", ]
    if (nrow(occupied_ports) > 0) {
      valid <- validate_no_duplicate_ports(occupied_ports)
      if (!isTRUE(valid)) {
        cat("❌ Error:", valid, "\n")
        return(NULL)
      }
    }
    
    ################################################################################
    #### SUMMARY & CONFIRMATION ####
    ################################################################################
    
    cat("\n============================================\n")
    cat("Port Configuration Summary:\n")
    cat("============================================\n")
    for (i in 1:6) {
      if (port_config$sensor[i] == "none") {
        cat("  Port ", i, ": Empty\n", sep = "")
      } else {
        cat("  Port ", i, ": ", port_config$sensor[i], 
            " (", port_config$type[i], ")",
            sep = "")
        if (!is.na(port_config$depth_cm[i])) {
          cat(" @ ", port_config$depth_cm[i], "cm", sep = "")
        }
        if (!is.na(port_config$status[i]) && port_config$status[i] == "defunct") {
          cat(" [DEFUNCT]", sep = "")
        }
        cat("\n")
      }
    }
    cat("============================================\n\n")
    
    # Warn if all ports are empty
    if (all(port_config$sensor == "none")) {
      cat("⚠️  WARNING: All ports are empty. Is this correct?\n")
    }
    
    confirm <- ui_yes_no("Save this configuration?", allow_quit = FALSE)
    
    if (confirm == "Y") {
      break  # Exit repeat loop, proceed to save
    }
    
    # User said no - offer to restart or cancel
    restart <- ui_yes_no("Start over and reconfigure all ports?", allow_quit = FALSE)
    
    if (restart != "Y") {
      cat("❌ Canceled - configuration not saved\n")
      return(NULL)
    }
    
    cat("\n--- RESTARTING PORT CONFIGURATION ---\n")
    # Loop continues, restarts from beginning
    
  }  # End repeat loop
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  #### A station for every kind of sensor ####
  # Each port is recorded against the station its sensor serves. A new ZL6
  # with an ATMOS and four TEROS is a weather station and a vwc station - and
  # when only the first exists yet, the TEROS ports have nowhere to go. The
  # second station is offered here, before the save, rather than the save
  # failing for want of it
  meta_now <- load_zentra_metadata()
  mine <- meta_now[meta_now$device_serial %in% device_serial &
                     !tolower(meta_now$status) %in% TERMINAL_STATUSES, , drop = FALSE]
  served <- unique(tolower(mine$station_type))
  needed <- unique(tolower(port_config$type[port_config$sensor != "none"]))
  missing <- setdiff(needed, served)
  companions <- character(0)

  result <- tryCatch(with_metadata_change("setting up ports", {
    for (mt in missing) {
      at <- port_config$port[tolower(port_config$type) == mt & port_config$sensor != "none"]
      cat("\n--- ANOTHER STATION ON THIS LOGGER ---\n\n")
      cat("Port", if (length(at) > 1) "s", " ", paste(at, collapse = ", "), " hold ", mt,
          " sensors, but no ", mt, " station is\n", sep = "")
      cat("recorded on this logger. One logger serving a weather and a vwc\n")
      cat("station is two stations sharing a device.\n\n")
      made <- NULL
      if (ui_yes_no(paste0("Set up the ", mt, " station now?"), allow_quit = FALSE) == "Y") {
        # Everything except the sensor type is already known - same site,
        # same logger - so it is handed over rather than asked for again
        made <- ui_add_device(is_new_station = TRUE, companion_of = mine[1, ],
                              companion_type = mt)
      }
      if (is.null(made)) {
        cat("\u26a0\ufe0f  Port", if (length(at) > 1) "s", " ", paste(at, collapse = ", "),
            " not recorded - record ", if (length(at) > 1) "them" else "it",
            " with 'Port configuration change'\n", "   once the ", mt,
            " station exists.\n", sep = "")
        drop <- port_config$port %in% at
        port_config$sensor[drop] <- "none"
        port_config$type[drop] <- "none"
        port_config$depth_cm[drop] <- NA
        port_config$status[drop] <- NA
      } else {
        companions <- c(companions, made$station_id)
      }
    }
    initialize_ports(device_serial, port_config)
  }), error = function(e) conditionMessage(e))
  
  if (!isTRUE(result)) {
    cat("❌ Not saved - ", result, "\n   Nothing was kept.\n", sep = "")
    return(NULL)
  }
  
  cat("\n✓ Port configuration saved successfully!\n")
  # A station set up here is reviewed with the one that led here: that
  # review offers every other station on the same logger
  
  return(TRUE)
}

#' Interactive port configuration update
#' Updates port configuration for an existing Zentra ZL6 device
#' Shows current config and prompts for changes
#' @return TRUE if successful, NULL if quit or error
ui_update_ports <- function(preset_device_serial = NULL) {
  cat("\n============================================\n")
  cat("  Update Port Configuration\n")
  cat("============================================\n\n")
  
  ################################################################################
  #### DEVICE SELECTION ####
  ################################################################################
  
  # Loaded unconditionally - later steps in this function use it regardless of
  # how the device was chosen
  metadata <- load_zentra_metadata()
  
  # Called from a workflow that already knows the device? Don't ask again.
  if (!is.null(preset_device_serial)) {
    device_serial <- preset_device_serial
    cat("Device: ", device_label(device_serial), "\n\n", sep = "")
    
  } else {
    # Ports belong to the DEVICE, so the list is one entry per SERIAL - not one
    # per metadata row. A ZL6 serving two stations had three entries here: its
    # decommissioned row, its other station, and its reactivated row.
    #
    # Terminal rows are excluded: a device out of service has no ports to
    # reconfigure.
    terminal_statuses <- TERMINAL_STATUSES
    zentra_devices <- metadata[grepl("^z", metadata$device_serial, ignore.case = TRUE) &
                               !tolower(metadata$status) %in% terminal_statuses, ]
    
    if (nrow(zentra_devices) == 0) {
      cat("❌ No active Zentra devices found in metadata\n")
      return(NULL)
    }
    
    serials <- sort(unique(zentra_devices$device_serial))
    
    # Where a serial serves several stations, name them all
    device_options <- vapply(serials, function(s) {
      stations <- unique(zentra_devices$station_id[zentra_devices$device_serial == s])
      paste0(device_label(s, meta = metadata), " - ", paste(stations, collapse = ", "))
    }, character(1))
    
    selected <- ui_select_from_menu("Select device:", device_options)
    if (is.null(selected)) {
      cat("❌ Canceled\n")
      return(NULL)
    }
    
    device_serial <- serials[match(selected, device_options)]
    cat("✓ Device:", device_label(device_serial), "\n\n")
  }
  
  ################################################################################
  #### GET CURRENT CONFIGURATION ####
  ################################################################################
  
  # Try to get current config - might not exist if never initialized
  current_config <- tryCatch({
    get_current_port_config(device_serial)
  }, error = function(e) {
    NULL
  })
  
  # Check if device has never been configured
  if (is.null(current_config)) {
    cat("⚠️  This device has no port configuration yet.\n")
    cat("   Use 'Initialize port configuration' instead.\n\n")
    
    init_now <- ui_yes_no("Initialize port configuration now?", allow_quit = FALSE)
    
    if (init_now == "Y") {
      # Call initialize function
      result <- ui_initialize_ports(device_serial)
      return(result)
    } else {
      cat("❌ Canceled - ports not configured\n")
      return(NULL)
    }
  }
  
  cat("--- CURRENT PORT CONFIGURATION ---\n")
  for (i in 1:6) {
    if (current_config$sensor[i] == "none") {
      cat("  Port ", i, ": Empty\n", sep = "")
    } else {
      cat("  Port ", i, ": ", current_config$sensor[i], 
          " (", current_config$type[i], ")",
          sep = "")
      if (!is.na(current_config$depth_cm[i])) {
        cat(" @ ", current_config$depth_cm[i], "cm", sep = "")
      }
      if (!is.na(current_config$status[i]) && current_config$status[i] == "defunct") {
        cat(" [DEFUNCT]", sep = "")
      }
      cat("\n")
    }
  }
  cat("\n")
  
  ################################################################################
  #### CHANGE DATETIME ####
  ################################################################################
  
  # Get device timezone for datetime prompt
  device_row <- get_device_row(device_serial, metadata = metadata)
  if (is.null(device_row)) {
    cat("❌ Device '", device_serial, "' not found in metadata\n", sep = "")
    return(NULL)
  }
  device_timezone <- device_row$timezone
  
  cat("When did this port configuration change occur?\n")
  cat("(This should be date AND time, as exact as possible)\n\n")
  
  change_datetime <- ui_prompt_datetime(
    "Enter change datetime",
    allow_now = TRUE,
    timezone = device_timezone
  )
  
  if (is.null(change_datetime)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  cat("✓ Change datetime:", format(change_datetime), "\n")
  
  ################################################################################
  #### PORT-BY-PORT UPDATE WITH RESTART LOOP ####
  ################################################################################
  
  repeat {  # Allow restart if user wants to fix errors
    
    # Get existing sensor types for menu
    existing_sensors <- get_unique_sensor_types()
    
    # Initialize new config (will update as we go)
    new_config <- current_config
    changes_made <- character(6)  # Track what changed per port
    
    for (port_num in 1:6) {
      cat("\n--- PORT ", port_num, " ---\n", sep = "")
      
      # Show current state
      if (current_config$sensor[port_num] == "none") {
        cat("Current: Empty\n")
      } else {
        cat("Current: ", current_config$sensor[port_num], sep = "")
        if (!is.na(current_config$depth_cm[port_num])) {
          cat(" @ ", current_config$depth_cm[port_num], "cm", sep = "")
        }
        if (!is.na(current_config$status[port_num]) && 
            current_config$status[port_num] == "defunct") {
          cat(" [DEFUNCT]", sep = "")
        }
        cat("\n")
      }
      
      # Ask if changing this port
      change_port <- ui_yes_no(paste0("Change port ", port_num, "?"), allow_quit = FALSE)
      
      if (change_port == "N") {
        changes_made[port_num] <- "no change"
        next
      }
      
      # User wants to change this port
      
      ## Ask if removing sensor or reconfiguring
      occupied <- ui_yes_no(paste0("Will port ", port_num, " have a sensor in this configuration?"), 
                            allow_quit = FALSE)
      
      if (occupied == "N") {
        # Port being emptied
        if (current_config$sensor[port_num] == "none") {
          cat("⚠️  Port was already empty - no change\n")
          changes_made[port_num] <- "no change"
        } else {
          new_config$type[port_num] <- "none"
          new_config$sensor[port_num] <- "none"
          new_config$depth_cm[port_num] <- NA
          new_config$status[port_num] <- NA
          changes_made[port_num] <- "REMOVED"
          cat("✓ Port ", port_num, " will be emptied\n", sep = "")
        }
        next
      }
      
      # Port is occupied - get new sensor details
      
      ## Sensor type
      sensor_type <- ui_select_or_specify(
        paste0("Select sensor for port ", port_num, ":"),
        existing_sensors,
        allow_quit = FALSE
      )
      
      ## Auto-determine type (vwc/weather)
      sensor_category <- determine_sensor_type(sensor_type)
      cat("✓ Sensor type detected:", sensor_category, "\n")
      
      ## Depth
      has_depth <- ui_yes_no("Does this sensor measure at a specific depth?", 
                             allow_quit = FALSE)
      
      new_depth <- NA
      if (has_depth == "Y") {
        repeat {
          cat("Enter depth in cm (e.g., 10, 30, 50): ")
          depth_input <- trimws(readline())
          depth <- suppressWarnings(as.numeric(depth_input))
          
          if (!is.na(depth) && depth >= 0) {
            new_depth <- depth
            cat("✓ Depth:", depth, "cm\n")
            break
          } else {
            cat("⚠️  Invalid depth. Must be a positive number.\n")
          }
        }
      } else {
        cat("✓ No depth measurement\n")
      }
      
      ## Defunct status
      is_working <- ui_yes_no("Is this sensor in good working order? (If you say no, considered 'defunct' - broken but still plugged in)", 
                              allow_quit = FALSE)
      
      new_status <- NA
      if (is_working == "N") {
        new_status <- "defunct"
        cat("⚠️  Sensor marked as defunct\n")
      } else {
        cat("✓ Sensor is functional\n")
      }
      
      # Update config
      new_config$type[port_num] <- sensor_category
      new_config$sensor[port_num] <- sensor_type
      new_config$depth_cm[port_num] <- new_depth
      new_config$status[port_num] <- new_status
      
      # Determine what changed
      if (current_config$sensor[port_num] == "none") {
        changes_made[port_num] <- "ADDED"
      } else {
        changes_made[port_num] <- "CHANGED"
      }
      
      cat("✓ Port ", port_num, " updated\n", sep = "")
    }
    
    ################################################################################
    #### VALIDATION ####
    ################################################################################
    
    # Check for duplicate ports
    occupied_ports <- new_config[new_config$sensor != "none", ]
    if (nrow(occupied_ports) > 0) {
      valid <- validate_no_duplicate_ports(occupied_ports)
      if (!isTRUE(valid)) {
        cat("❌ Error:", valid, "\n")
        return(NULL)
      }
    }
    
    ################################################################################
    #### SUMMARY & CONFIRMATION ####
    ################################################################################
    
    # The whole configuration, not only the lines that changed. What is being
    # saved is the state of the device, and a list of three edits leaves the
    # reader to hold the other three ports in their head to check it.
    cat("\n============================================\n")
    cat("Port Configuration After These Changes:\n")
    cat("============================================\n")
    cat("Change datetime: ", format(change_datetime), "\n\n", sep = "")
    
    any_changes <- FALSE
    for (i in 1:6) {
      changed <- changes_made[i] != "no change" && changes_made[i] != ""
      if (changed) any_changes <- TRUE
      
      cat("  Port ", i, ": ", sep = "")
      
      if (new_config$sensor[i] == "none") {
        cat("Empty")
      } else {
        cat(new_config$sensor[i], " (", new_config$type[i], ")", sep = "")
        if (!is.na(new_config$depth_cm[i])) {
          cat(" @ ", new_config$depth_cm[i], "cm", sep = "")
        }
        if (!is.na(new_config$status[i]) && new_config$status[i] == "defunct") {
          cat(" [DEFUNCT]", sep = "")
        }
      }
      
      if (changed) cat("   <- ", changes_made[i], sep = "")
      cat("\n")
    }
    
    if (!any_changes) {
      cat("\n  Nothing changed\n")
    }
    cat("============================================\n\n")
    
    if (!any_changes) {
      cat("⚠️  No ports were changed. Configuration not updated.\n")
      return(NULL)
    }
    
    confirm <- ui_yes_no("Save these changes?", allow_quit = FALSE)
    
    if (confirm == "Y") {
      break  # Exit repeat loop, proceed to save
    }
    
    # User said no - offer to restart or cancel
    restart <- ui_yes_no("Start over and reconfigure ports again?", allow_quit = FALSE)
    
    if (restart != "Y") {
      cat("❌ Canceled - configuration not updated\n")
      return(NULL)
    }
    
    cat("\n--- RESTARTING PORT UPDATE ---\n")
    cat("--- CURRENT PORT CONFIGURATION ---\n")
    for (i in 1:6) {
      if (current_config$sensor[i] == "none") {
        cat("  Port ", i, ": Empty\n", sep = "")
      } else {
        cat("  Port ", i, ": ", current_config$sensor[i], 
            " (", current_config$type[i], ")", sep = "")
        if (!is.na(current_config$depth_cm[i])) {
          cat(" @ ", current_config$depth_cm[i], "cm", sep = "")
        }
        if (!is.na(current_config$status[i]) && current_config$status[i] == "defunct") {
          cat(" [DEFUNCT]", sep = "")
        }
        cat("\n")
      }
    }
    cat("\n")
    # Loop continues, restarts port configuration
    
  }  # End repeat loop
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  # The new configuration and its log entries are one change. A ZL6 serving
  # two stations gets an entry at each station whose sensors changed - and
  # only those - saying which ports changed and how
  describe_port <- function(cfg, n) vapply(n, function(k) {
    r <- cfg[cfg$port == k, , drop = FALSE]
    if (nrow(r) == 0 || is.na(r$sensor[1]) || r$sensor[1] == "none") return("empty")
    paste0(r$sensor[1], if (!is.na(r$depth_cm[1])) paste0(" @ ", r$depth_cm[1], "cm"),
           if (!is.na(r$status[1]) && r$status[1] == "defunct") " (defunct)")
  }, character(1))
  logged_by <- ui_ask_whois_logging()
  logged_at <- character(0)
  result <- tryCatch(with_metadata_change("recording a port configuration", local({
    res <- update_ports(device_serial, new_config, change_datetime)
    if (!isTRUE(res)) return(res)
    ports_now <- load_zentra_ports_data()
    at_change <- function(x) !is.na(x) & abs(as.numeric(x) - as.numeric(change_datetime)) < 1
    touched <- ports_now[ports_now$sn %in% device_serial &
                           (at_change(ports_now$valid_from) | at_change(ports_now$valid_to)), ,
                         drop = FALSE]
    for (uid in unique(touched$unique_id)) {
      pnums <- sort(unique(touched$port[touched$unique_id == uid]))
      stn <- metadata$station_id[match(uid, metadata$unique_id)]
      out <- create_maintenance_entry(
        field_visit_date = local_date(change_datetime),
        station_id = stn,
        unique_id = uid,
        action_type = "port_config_change",
        details = paste0("Port configuration updated - ",
                         paste0("port ", pnums, ": ", describe_port(current_config, pnums),
                                " \u2192 ", describe_port(new_config, pnums), collapse = "; ")),
        logged_by = logged_by
      )
      if (!isTRUE(out)) return(out)
      logged_at <<- c(logged_at, stn)
    }
    TRUE
  })), error = function(e) conditionMessage(e))
  
  if (!isTRUE(result)) {
    cat("❌ Not saved - ", result, "\n   Nothing was changed.\n", sep = "")
    return(NULL)
  }
  
  cat("\n✓ Port configuration updated successfully\n")
  if (length(logged_at) > 0) {
    cat("✓ Logged to maintenance at ", paste(unique(logged_at), collapse = " and "), "\n", sep = "")
  }
  
  return(TRUE)
}

# --- VIEW FUNCTIONS ---
#' View device metadata
#' Displays device metadata in readable format with filtering options
#' @return NULL (display only)
ui_view_metadata <- function() {
  cat("\n============================================\n")
  cat("  View Device Metadata\n")
  cat("============================================\n\n")
  
  metadata <- load_zentra_metadata()
  
  if (nrow(metadata) == 0) {
    cat("❌ No devices found in metadata\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. All devices\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by status\n")
  cat("  4. Filter by manufacturer\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_metadata <- metadata
  filter_description <- "All devices"
  
  if (view_choice == "2") {
    # Filter by station
    stations <- sort(unique(metadata$station_id))
    station_options <- label_station_options(stations)
    
    selected_station <- ui_select_from_menu("Select station:", station_options)
    if (is.null(selected_station)) {
      return(NULL)
    }
    # Back to the bare id - the label is for reading, not for matching
    selected_station <- sub(" \\(.*$", "", selected_station)
    
    filtered_metadata <- metadata[metadata$station_id == selected_station, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by status
    statuses <- sort(unique(metadata$status))
    selected_status <- ui_select_from_menu("Select status:", statuses)
    if (is.null(selected_status)) {
      return(NULL)
    }
    
    filtered_metadata <- metadata[metadata$status == selected_status, ]
    filter_description <- paste0("Status: ", selected_status)
    
  } else if (view_choice == "4") {
    # Filter by manufacturer
    mfgers <- sort(unique(metadata$mfger))
    selected_mfger <- ui_select_from_menu("Select manufacturer:", mfgers)
    if (is.null(selected_mfger)) {
      return(NULL)
    }
    
    filtered_metadata <- metadata[metadata$mfger == selected_mfger, ]
    filter_description <- paste0("Manufacturer: ", selected_mfger)
  }
  
  ################################################################################
  #### DISPLAY METADATA ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Device Metadata - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_metadata), " device(s)\n\n", sep = "")
  
  if (nrow(filtered_metadata) == 0) {
    cat("No devices match this filter\n")
    return(NULL)
  }
  
  for (i in 1:nrow(filtered_metadata)) {
    device <- filtered_metadata[i, ]
    
    cat("--- DEVICE ", i, " ---\n", sep = "")
    cat("Name:         ", blank_or_value(device$device_name), "\n", sep = "")
    cat("Unique ID:    ", device$unique_id, "\n", sep = "")
    cat("Serial:       ", device$device_serial, "\n", sep = "")
    cat("Station:      ", device$station_id, " (", device$site_full, ")\n", sep = "")
    cat("Manufacturer: ", device$mfger, "\n", sep = "")
    cat("Role:         ", device$device_role, "\n", sep = "")
    cat("Status:       ", device$status, "\n", sep = "")
    cat("Location:     ", device$lat, ", ", device$lon, sep = "")
    if (!is.na(device$elev)) {
      cat(" (", device$elev, "m)", sep = "")
    }
    cat("\n")
    cat("Interval:     ", blank_or_value(device$interval_min), " minutes\n", sep = "")
    cat("Timezone:     ", device$timezone, "\n", sep = "")
    cat("Deployed:     ", format(device$deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    if (!is.na(device$last_visit)) {
      cat("Last visit:   ", format(device$last_visit, "%Y-%m-%d"), "\n", sep = "")
    }
    act <- tryCatch(deployment_activity(device), error = function(e) NULL)
    if (!is.null(act) && !is.na(act$data_to)) {
      cat("Data to:      ", format(act$data_to, "%Y-%m-%d %H:%M"), "\n", sep = "")
    }
    # The flag with its age. "TRUE" alone says someone once confirmed the
    # record and nothing about whether that was this morning or in March.
    cat("Confirmed:    ", device$metadata_approved, sep = "")
    if (!("last_reviewed_utc" %in% names(device)) ||
        is.na(device$last_reviewed_utc) ||
        !nzchar(trimws(as.character(device$last_reviewed_utc)))) {
      # Blank is not the same as old. Saying so stops it reading as a
      # rendering failure.
      cat("  (never reviewed)", sep = "")
    } else {
      reviewed <- as.POSIXct(as.character(device$last_reviewed_utc), tz = "UTC")
      days <- as.numeric(difftime(Sys.time(), reviewed, units = "days"))
      cat("  (reviewed ",
          if (days < 1) "today"
          else if (days < 45) paste0(round(days), " days ago")
          else paste0(round(days / 30.4), " months ago"),
          ")", sep = "")
    }
    cat("\n\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' View port configurations
#' Displays port configurations for devices
#' @return NULL (display only)
ui_view_ports <- function() {
  cat("\n============================================\n")
  cat("  View Port Configurations\n")
  cat("============================================\n\n")
  
  ports <- load_zentra_ports_data()
  meta <- load_zentra_metadata()
  
  if (nrow(ports) == 0) {
    cat("❌ No port configurations found\n")
    return(NULL)
  }
  
  cat("View options:\n")
  cat("  1. All devices (active configs only)\n")
  cat("  2. Specific device (all configs including history)\n")
  cat("  3. Specific device (active configs only)\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  if (tolower(view_choice) == "q") return(NULL)
  if (!view_choice %in% c("1", "2", "3")) {
    cat("❌ Invalid selection\n")
    return(NULL)
  }

  # One line per port row. A sensor left blank is shown as unknown rather
  # than stopping the listing
  port_text <- function(r) {
    sensor <- if (is.na(r$sensor) || !nzchar(r$sensor)) "unknown sensor" else r$sensor
    if (sensor == "none") return("Empty")
    paste0(sensor, " (", r$type, ")",
           if (!is.na(r$depth_cm)) paste0(" @ ", r$depth_cm, "cm"),
           if (!is.na(r$status) && r$status == "defunct") " [DEFUNCT]")
  }
  # Heading for one deployment: the device by name, and its station
  deployment_heading <- function(uid) {
    row <- meta[meta$unique_id == uid, , drop = FALSE]
    if (nrow(row) == 0) return(paste0("--- unknown deployment ", uid, " ---"))
    paste0("--- ", device_label(row[1, ]), " at ", row$station_id[1],
           if (tolower(row$status[1]) %in% TERMINAL_STATUSES) paste0(" (", row$status[1], ")"),
           " ---")
  }
  stamp <- function(x) if (is.na(x)) "present" else format(x, "%Y-%m-%d %H:%M")

  if (view_choice == "1") {
    open <- ports[is.na(ports$valid_to), , drop = FALSE]
    uids <- unique(open$unique_id)
    uids <- uids[order(device_display_name(open$sn[match(uids, open$unique_id)], meta))]
    
    cat("\n============================================\n")
    cat("Active Port Configurations - All Devices\n")
    cat("============================================\n")
    cat("Found ", length(uids), " deployment(s) with active configs\n\n", sep = "")
    
    for (uid in uids) {
      rows <- open[open$unique_id == uid, , drop = FALSE]
      rows <- rows[order(rows$port), , drop = FALSE]
      cat(deployment_heading(uid), "\n", sep = "")
      for (i in seq_len(nrow(rows))) {
        cat("  Port ", rows$port[i], ": ", port_text(rows[i, ]), "\n", sep = "")
      }
      cat("\n")
    }
    cat("============================================\n")
    return(NULL)
  }

  # Specific device, chosen by name
  serials <- unique(ports$sn[!is.na(ports$sn)])
  labels <- vapply(serials, device_label, character(1), meta = meta)
  ord <- order(labels)
  pick <- ui_select_from_menu("Select device:", labels[ord])
  if (is.null(pick)) return(NULL)
  selected_device <- serials[ord][match(pick, labels[ord])]

  device_ports <- ports[ports$sn %in% selected_device, , drop = FALSE]
  if (view_choice == "3") device_ports <- device_ports[is.na(device_ports$valid_to), , drop = FALSE]
  title <- paste0(if (view_choice == "3") "Active Port Configuration - " else "Port Configuration History - ",
                  pick)

  cat("\n============================================\n")
  cat(title, "\n")
  cat("============================================\n\n")

  if (nrow(device_ports) == 0) {
    cat("No configurations found\n")
    return(NULL)
  }

  # A logger that served several stations, or served one more than once, has
  # one block per deployment
  device_ports <- device_ports[order(device_ports$valid_from, device_ports$port), , drop = FALSE]
  for (uid in unique(device_ports$unique_id)) {
    cat(deployment_heading(uid), "\n", sep = "")
    rows <- device_ports[device_ports$unique_id == uid, , drop = FALSE]
    for (port_num in sort(unique(rows$port))) {
      pr <- rows[rows$port == port_num, , drop = FALSE]
      for (i in seq_len(nrow(pr))) {
        cat("  Port ", port_num, ": ", port_text(pr[i, ]), sep = "")
        if (view_choice == "2") {
          cat("   [", stamp(pr$valid_from[i]), " to ", stamp(pr$valid_to[i]), "]", sep = "")
        }
        cat("\n")
      }
    }
    cat("\n")
  }
  cat("============================================\n")
  return(NULL)
}

#' View maintenance log
#' Displays maintenance log entries with filtering options
#' @return NULL (display only)
ui_view_maintenance_log <- function() {
  cat("\n============================================\n")
  cat("  View Maintenance Log\n")
  cat("============================================\n\n")
  
  maint_log <- load_maintenance_log()
  meta_for_log <- read_table("device_metadata", remember = FALSE)
  
  if (is.null(maint_log) || nrow(maint_log) == 0) {
    cat("❌ No maintenance log entries found\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. Recent entries (last 20)\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by action type\n")
  cat("  4. Filter by date range\n")
  cat("  5. All entries\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_log <- maint_log
  filter_description <- "All entries"
  
  if (view_choice == "1") {
    # Recent entries
    n_entries <- min(20, nrow(maint_log))
    filtered_log <- maint_log[(nrow(maint_log) - n_entries + 1):nrow(maint_log), ]
    filter_description <- paste0("Last ", n_entries, " entries")
    
  } else if (view_choice == "2") {
    # Filter by station
    stations <- label_station_options(sort(unique(maint_log$station_id)))
    selected_station <- ui_select_from_menu("Select station:", stations)
    if (is.null(selected_station)) {
      return(NULL)
    }
    selected_station <- sub(" \\(.*$", "", selected_station)
    
    filtered_log <- maint_log[maint_log$station_id == selected_station, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by action type
    action_types <- sort(unique(maint_log$action_type))
    selected_action <- ui_select_from_menu("Select action type:", action_types)
    if (is.null(selected_action)) {
      return(NULL)
    }
    
    filtered_log <- maint_log[maint_log$action_type == selected_action, ]
    filter_description <- paste0("Action: ", selected_action)
    
  } else if (view_choice == "4") {
    # Filter by date range
    start_date <- ui_prompt_date("Enter start date", allow_today = FALSE, allow_quit = TRUE)
    if (is.null(start_date)) {
      return(NULL)
    }
    
    end_date <- ui_prompt_date("Enter end date", allow_today = TRUE, allow_quit = TRUE)
    if (is.null(end_date)) {
      return(NULL)
    }
    
    filtered_log <- maint_log[
      as.Date(maint_log$field_visit_date) >= as.Date(start_date) &
        as.Date(maint_log$field_visit_date) <= as.Date(end_date), 
    ]
    filter_description <- paste0("Date range: ", start_date, " to ", end_date)
  }
  
  ################################################################################
  #### DISPLAY LOG ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Maintenance Log - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_log), " entr", 
      ifelse(nrow(filtered_log) == 1, "y", "ies"), "\n\n", sep = "")
  
  if (nrow(filtered_log) == 0) {
    cat("No entries match this filter\n")
    return(NULL)
  }
  
  for (i in 1:nrow(filtered_log)) {
    entry <- filtered_log[i, ]
    
    cat("--- ENTRY ", i, " ---\n", sep = "")
    cat("Date:         ", format(as.Date(entry$field_visit_date), "%Y-%m-%d"), "\n", sep = "")
    cat("Station:      ", entry$station_id, "\n", sep = "")
    dev <- meta_for_log[match(entry$unique_id, meta_for_log$unique_id), ]
    cat("Device:       ", if (nrow(dev) == 1 && !is.na(dev$device_serial)) device_label(dev)
                          else "(row no longer in metadata)",
        "  [", entry$unique_id, "]\n", sep = "")
    cat("Action:       ", entry$action_type, "\n", sep = "")
    cat("Details:      ", entry$details, "\n", sep = "")
    cat("Logged by:    ", entry$logged_by, "\n", sep = "")
    if (!is.na(entry$logged_utc)) {
      cat("Logged:       ", format(entry$logged_utc, "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ), "\n", sep = "")
    }
    cat("\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' View download log
#' Displays download log entries with filtering options
#' @return NULL (display only)
ui_view_download_log <- function() {
  cat("\n============================================\n")
  cat("  View Download Log\n")
  cat("============================================\n\n")
  
  download_log <- load_download_log()
  
  if (is.null(download_log) || nrow(download_log) == 0) {
    cat("❌ No download log entries found\n")
    return(NULL)
  }
  
  ################################################################################
  #### FILTER OPTIONS ####
  ################################################################################
  
  cat("View options:\n")
  cat("  1. Recent downloads (last 20)\n")
  cat("  2. Filter by station\n")
  cat("  3. Filter by date range\n")
  cat("  4. All downloads\n")
  cat("  q. Back to main menu\n")
  cat("\nEnter selection: ")
  
  view_choice <- trimws(readline())
  
  if (tolower(view_choice) == "q") {
    return(NULL)
  }
  
  filtered_log <- download_log
  filter_description <- "All downloads"
  
  if (view_choice == "1") {
    # Recent entries
    n_entries <- min(20, nrow(download_log))
    filtered_log <- download_log[(nrow(download_log) - n_entries + 1):nrow(download_log), ]
    filter_description <- paste0("Last ", n_entries, " downloads")
    
  } else if (view_choice == "2") {
    # Filter by station
    # The log is kept by logger, not station: a station's downloads are those
    # of the loggers that have served it
    meta_dl <- read_table("device_metadata", remember = FALSE)
    stations <- label_station_options(sort(unique(meta_dl$station_id)))
    selected_station <- ui_select_from_menu("Select station:", stations)
    if (is.null(selected_station)) {
      return(NULL)
    }
    selected_station <- sub(" \\(.*$", "", selected_station)
    
    its_loggers <- unique(meta_dl$device_serial[meta_dl$station_id == selected_station])
    filtered_log <- download_log[download_log$device_serial %in% its_loggers, ]
    filter_description <- paste0("Station: ", selected_station)
    
  } else if (view_choice == "3") {
    # Filter by date range
    start_date <- ui_prompt_date("Enter start date", allow_today = FALSE, allow_quit = TRUE)
    if (is.null(start_date)) {
      return(NULL)
    }
    
    end_date <- ui_prompt_date("Enter end date", allow_today = TRUE, allow_quit = TRUE)
    if (is.null(end_date)) {
      return(NULL)
    }
    
    # When the download ran, as a date in the project zone - a run late in
    # the evening is still that day here, though UTC has moved on
    run_day <- local_date(download_log$timestamp_utc)
    filtered_log <- download_log[!is.na(run_day) & run_day >= as.Date(start_date) &
                                   run_day <= as.Date(end_date), , drop = FALSE]
    filter_description <- paste0("Date range: ", start_date, " to ", end_date)
  }
  
  ################################################################################
  #### DISPLAY LOG ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Download Log - ", filter_description, "\n", sep = "")
  cat("============================================\n")
  cat("Found ", nrow(filtered_log), " download", 
      ifelse(nrow(filtered_log) == 1, "", "s"), "\n\n", sep = "")
  
  if (nrow(filtered_log) == 0) {
    cat("No downloads match this filter\n")
    return(NULL)
  }
  
  # Display based on actual column names in download_log
  for (i in 1:nrow(filtered_log)) {
    entry <- filtered_log[i, ]
    
    cat("--- DOWNLOAD ", i, " ---\n", sep = "")
    
    # Display columns with proper formatting for dates/datetimes
    for (col_name in names(entry)) {
      value <- entry[[col_name]]
      
      if (!is.na(value)) {
        # Format based on column type
        if (inherits(value, "POSIXct") || inherits(value, "POSIXlt")) {
          # Datetime column
          cat(col_name, ": ", format(value, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
        } else if (inherits(value, "Date")) {
          # Date column
          cat(col_name, ": ", format(value, "%Y-%m-%d"), "\n", sep = "")
        } else {
          # Other columns
          cat(col_name, ": ", value, "\n", sep = "")
        }
      }
    }
    cat("\n")
  }
  
  cat("============================================\n")
  
  return(NULL)
}

#' Interactive device removal
#' Removes a device from service - marks as removed, closes ports, disables downloads
#' @return TRUE if successful, NULL if quit
ui_remove_device <- function() {
  cat("\n============================================\n")
  cat("  Remove Device from Service\n")
  cat("============================================\n\n")
  cat("Use this workflow when:\n")
  cat("  - Taking a device out of the field\n")
  cat("  - Device being stored, scrapped, or redeployed elsewhere\n")
  cat("  - NOT for replacement (use replacement workflow instead)\n\n")
  
  ################################################################################
  #### SELECT STATION & DEVICE ####
  ################################################################################
  
  cat("--- SELECT DEVICE TO REMOVE ---\n\n")
  
  # Get all stations
  station_list <- get_station_list()
  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$label, ")")
  })
  
  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # Extract station_id
  station_id <- sub(" \\(.*\\)$", "", selected)
  station_devices <- get_active_devices_or_notify(station_id, "device removal")
  if (is.null(station_devices)) return(NULL)
  station_devices <- order_devices_by_role(station_devices)
  cat("✓ Station:", station_id, "\n\n")
  
  # Show devices at this station
  cat("Devices at this station:\n")
  for (i in 1:nrow(station_devices)) {
    cat("  ", i, ". ", device_label(station_devices[i, ]),
        " - ", station_devices$mfger[i], ", ",
        station_devices$status[i], "\n", sep = "")
  }
  
  # Select device to remove
  device_options <- vapply(seq_len(nrow(station_devices)),
                           function(i) device_label(station_devices[i, ],
                                                    with_role = TRUE),
                           character(1))
  selected_device <- ui_select_from_menu("\nSelect device to remove:", device_options)
  if (is.null(selected_device)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  # The row chosen, by its place in the menu - not found again by serial
  device_row <- station_devices[match(selected_device, device_options), ]
  device_serial <- device_row$device_serial

  # The box is coming out, so every station it serves ends with it
  served <- logger_current_rows(device_row$unique_id)
  also <- served$station_id[served$unique_id != device_row$unique_id]
  if (length(also) > 0) {
    cat("\n\u26a0\ufe0f  This logger also serves ", paste(also, collapse = ", "), ".\n", sep = "")
    cat("   Removing it ends that station's deployment too. If the logger stays\n")
    cat("   on site running ", paste(also, collapse = ", "), ", this is not a removal:\n", sep = "")
    cat("   decommission ", station_id, " instead, or change its ports if only the\n", sep = "")
    cat("   sensors came off.\n\n")
    if (ui_yes_no("Did the logger itself come out of the field?", allow_quit = FALSE) != "Y") {
      cat("\u274c Canceled - no changes made\n")
      return(NULL)
    }
  }
  
  ################################################################################
  #### CHECK IF FINAL DEVICE - STRONG DECOMMISSION RECOMMENDATION ####
  ################################################################################
  
  # Check if this is the only active device at the station
  active_statuses <- setdiff(ACTIVE_STATUSES, "defunct")
  active_devices <- station_devices[station_devices$status %in% active_statuses, ]
  
  if (nrow(active_devices) == 1 && active_devices$device_serial[1] == device_serial) {
    cat("\n╔════════════════════════════════════════════════════════════╗\n")
    cat("║  ⚠️  RECOMMENDATION: USE DECOMMISSION WORKFLOW INSTEAD  ⚠️   ║\n")
    cat("╚════════════════════════════════════════════════════════════╝\n\n")
    cat("This is the ONLY active device at station '", station_id, "'\n", sep = "")
    cat("Removing it will leave the station with no active monitoring.\n\n")
    cat("RECOMMENDED ACTION:\n")
    cat("  1. Cancel this removal workflow\n")
    cat("  2. Use 'Station decommissioned' workflow instead\n")
    cat("  3. That workflow properly marks the entire station as shut down\n\n")
    cat("Why? 'Decommissioned' means the station has no active devices,\n")
    cat("which is exactly what will happen if you remove this device.\n\n")
    
    proceed <- ui_yes_no("Do you still want to proceed with device removal?", allow_quit = FALSE)
    if (proceed != "Y") {
      cat("\n✓ Good choice! Use 'Station decommissioned' workflow from main menu.\n")
      return(NULL)
    }
    cat("\n⚠️  Proceeding with device removal despite recommendation...\n\n")
  }
  
  cat("✓ Device:", device_label(device_serial), "\n")
  cat("  Manufacturer:", device_row$mfger, "\n")
  cat("  Current status:", device_row$status, "\n\n")
  
  ################################################################################
  #### REMOVAL DATETIME & DETAILS ####
  ################################################################################
  
  cat("--- REMOVAL INFORMATION ---\n\n")
  
  # When removed (datetime, not just date)
  cat("When was device removed?\n")
  cat("(This should be date AND time, as exact as possible)\n\n")
  
  # Not before the latest of the deployments it ends - a logger cannot come
  # out of a station before it went in
  removal_datetime <- ui_prompt_event_time(
    "Enter removal datetime", device_row$timezone,
    max(as.POSIXct(served$deploy_datetime, tz = PROJECT_TZ)))
  
  if (is.null(removal_datetime)) {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  cat("✓ Removal datetime:", format(removal_datetime), "\n\n")
  
  # Extract date for maintenance log
  removal_date <- local_date(removal_datetime)
  
  # Details
  cat("Enter removal details (e.g., 'Device removed, stored in lab'):\n")
  details <- trimws(readline())
  if (details == "") {
    details <- "Device removed from service"
  }
  cat("✓ Details:", details, "\n\n")
  
  # Who is logging
  logged_by <- ui_ask_whois_logging()
  cat("✓ Logged by:", logged_by, "\n")
  
  ################################################################################
  #### CONFIRMATION ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("Ready to remove device:\n")
  cat("  Device:", device_label(device_serial), "\n")
  cat("  Station:", station_id, "\n")
  cat("  Removal datetime:", format(removal_datetime), "\n")
  cat("  Details:", details, "\n\n")
  cat("This will:\n")
  cat("  - Mark device status as 'removed'\n")
  cat("  - Mark the station's record for review\n")
  cat("  - Close all active port configurations\n")
  cat("  - Log removal to maintenance\n")
  cat("============================================\n\n")
  
  confirm <- ui_yes_no("Confirm device removal?", allow_quit = FALSE)
  if (confirm != "Y") {
    cat("❌ Canceled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### CALL LOGIC FUNCTION ####
  ################################################################################
  
  result <- remove_device(device_row$unique_id, removal_datetime)
  
  if (!isTRUE(result)) {
    cat("❌ Error:", result, "\n")
    return(NULL)
  }
  
  cat("✓ Device status set to 'removed'\n")
  cat("✓ Station record marked for review\n")
  cat("✓ Port configurations closed\n")
  cat("✓ Last visit updated\n")
  
  ################################################################################
  #### LOG TO MAINTENANCE ####
  ################################################################################
  
  log_result <- create_maintenance_entry(
    field_visit_date = removal_date,
    station_id = device_row$station_id,
    device_serial = device_serial,
    action_type = "device_removal",
    details = details,
    logged_by = logged_by
  )
  
  if (!isTRUE(log_result)) {
    cat("⚠️  Warning: Could not log to maintenance\n")
  } else {
    cat("✓ Removal logged to maintenance\n")
  }
  
  cat("\n✓ Device removal complete!\n")
  cat("  Device ", device_label(device_serial), " has been removed from service\n", sep = "")

  return(TRUE)
}

#' Delete a metadata row by unique_id (ADMIN FUNCTION)
#' Shows full record, confirms deletion, removes from metadata and ports
#' Logs deletion to maintenance log
#' @return TRUE if successful, NULL if canceled
ui_delete_metadata_row <- function() {
  cat("\n============================================\n")
  cat("  DELETE METADATA ROW (ADMIN)\n")
  cat("============================================\n\n")
  cat("⚠️  WARNING: This permanently deletes a row from device metadata\n")
  cat("   Use only for entries added in error\n\n")
  
  ################################################################################
  #### GET UNIQUE_ID ####
  ################################################################################
  
  cat("Enter unique_id of row to delete (e.g., z-0045, h-0012):\n")
  cat("Or press 'q' to cancel: ")
  unique_id_input <- trimws(readline())
  
  if (tolower(unique_id_input) == "q" || unique_id_input == "") {
    cat("❌ Canceled\n")
    return(NULL)
  }
  
  unique_id <- unique_id_input
  
  ################################################################################
  #### LOAD AND VERIFY ####
  ################################################################################
  
  metadata <- load_zentra_metadata()
  
  # Check if unique_id exists
  if (!unique_id %in% metadata$unique_id) {
    cat("❌ Error: unique_id '", unique_id, "' not found in metadata\n", sep = "")
    return(NULL)
  }
  
  # Get the row
  row_to_delete <- metadata[metadata$unique_id == unique_id, ]
  
  ################################################################################
  #### SHOW FULL RECORD ####
  ################################################################################
  
  cat("\n============================================\n")
  cat("DEVICE METADATA - CONFIRM DELETION\n")
  cat("============================================\n")
  cat("unique_id:           ", row_to_delete$unique_id, "\n", sep = "")
  cat("station_id:          ", row_to_delete$station_id, "\n", sep = "")
  cat("device_serial:       ", row_to_delete$device_serial, "\n", sep = "")
  cat("watershed:           ", row_to_delete$watershed, "\n", sep = "")
  cat("area:                ", row_to_delete$area, "\n", sep = "")
  cat("site_full:           ", row_to_delete$site_full, "\n", sep = "")
  cat("site:                ", row_to_delete$site, "\n", sep = "")
  cat("station_type:        ", row_to_delete$station_type, "\n", sep = "")
  cat("device_role:         ", row_to_delete$device_role, "\n", sep = "")
  cat("device_name:         ", row_to_delete$device_name, "\n", sep = "")
  cat("mfger:               ", row_to_delete$mfger, "\n", sep = "")
  cat("lat:                 ", row_to_delete$lat, "\n", sep = "")
  cat("lon:                 ", row_to_delete$lon, "\n", sep = "")
  cat("elev:                ", row_to_delete$elev, "\n", sep = "")
  cat("interval_min:        ", row_to_delete$interval_min, "\n", sep = "")
  cat("timezone:            ", row_to_delete$timezone, "\n", sep = "")
  cat("deploy_datetime:     ", format(row_to_delete$deploy_datetime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("status:              ", row_to_delete$status, "\n", sep = "")
  cat("metadata_approved:   ", row_to_delete$metadata_approved, "\n", sep = "")
  cat("============================================\n\n")
  
  ################################################################################
  #### CONFIRM DELETION ####
  ################################################################################
  
  confirm <- ui_yes_no("Permanently delete this row from metadata?", allow_quit = FALSE)
  
  if (confirm != "Y") {
    cat("❌ Canceled - no changes made\n")
    return(NULL)
  }
  
  ################################################################################
  #### DELETE: the row, everything that belongs to it, and the log entry ####
  ################################################################################

  # The row's own ports and surveys go with it - each names its deployment,
  # so another row of the same logger keeps its own - and the log records the
  # deletion. One change: checked once at the end, and put back whole if it
  # would leave anything pointing at nothing
  ports <- load_zentra_ports_data()
  surveys <- load_surveys()
  n_ports <- sum(ports$unique_id == unique_id)
  n_surveys <- sum(surveys$unique_id == unique_id | surveys$relative_to_id %in% unique_id |
                     surveys$carried_from %in% unique_id)
  if (n_ports + n_surveys > 0) {
    cat("\nGoing with it: ",
        paste(c(if (n_ports > 0) paste0(n_ports, " port row(s)"),
                if (n_surveys > 0) paste0(n_surveys, " survey row(s)")), collapse = " and "),
        " that belong to this row\n", sep = "")
  }

  result <- with_metadata_change(paste("deleting row", unique_id), tryCatch({
    metadata <- metadata[metadata$unique_id != unique_id, ]
    if (!isTRUE(save_device_metadata(metadata, intent = paste("deleting row", unique_id)))) {
      stop("device_metadata.csv was not saved")
    }
    if (n_ports > 0) {
      save_zentra_ports(ports[ports$unique_id != unique_id, ], intent = "deleting a row's ports")
    }
    if (n_surveys > 0) {
      keep <- !(surveys$unique_id == unique_id | surveys$relative_to_id %in% unique_id |
                  surveys$carried_from %in% unique_id)
      write_table_or_stop("surveys", surveys[keep, , drop = FALSE],
                          intent = "deleting a row's surveys")
    }
    log_result <- create_maintenance_entry(
      field_visit_date = Sys.Date(),
      station_id = row_to_delete$station_id,
      unique_id = unique_id,          # the row just deleted - nothing left to look it up by
      action_type = "metadata_deletion",
      details = paste0("METADATA DELETION - unique_id: ", unique_id,
                       ", device_serial: ", row_to_delete$device_serial,
                       ", station: ", row_to_delete$station_id,
                       " (", row_to_delete$site_full, ")"),
      logged_by = "ADMIN")
    if (!isTRUE(log_result)) stop("the deletion could not be logged")
    TRUE
  }, error = function(e) paste0("Deletion failed: ", conditionMessage(e))))

  if (!isTRUE(result)) {
    cat("\u274c Row NOT deleted - ", result, "\n", sep = "")
    return(invisible(FALSE))
  }
  cat("\u2713 Row deleted, with its ports and surveys, and the deletion logged\n")

  cat("\n✓ Metadata row deletion complete\n")
  cat("  Deleted: ", unique_id, " (", device_label(row_to_delete), ")\n", sep = "")
  
  return(TRUE)
}

################################################################################
#### METADATA MANAGER MASTER FUNCTION ####
################################################################################

#' Corrects device details recorded wrongly or left blank
#'
#' For DESCRIPTIVE fields only - things that are properties of the device
#' rather than records of something happening. Correcting a typo in a model
#' number is a correction; a device being replaced or a station moving are
#' EVENTS and belong in their own workflows, where they leave a maintenance
#' log entry behind.
#'
#' Deliberately not a general row editor. A general editor would become the
#' easy path for changes that ought to be logged, and the log is the only
#' record of why anything changed.
#'
#' @return TRUE if a change was made, NULL if canceled
ui_correct_device_details <- function() {

  cat("\n============================================\n")
  cat("  Correct Device Details\n")
  cat("============================================\n\n")
  cat("For fixing details recorded wrongly or left blank:\n")
  cat("  - model, device name, device role, logging interval\n")
  cat("  - deploy datetime, latitude, longitude, elevation\n")
  cat("  - end datetime and terminal status, for devices out of service\n\n")
  cat("NOT for things that happened in the field. A device swap or a station\n")
  cat("move belong in their own workflows, so that they leave a maintenance\n")
  cat("log entry behind.\n\n")
  cat("Devices already out of service are listed too - their rows are the\n")
  cat("historical record, and a wrong value on one still needs correcting.\n\n")

  #### Select station and device ####
  station_list <- get_station_list(include_retired = TRUE)
  if (length(station_list) == 0) {
    cat("No stations found in metadata.\n")
    return(invisible(NULL))
  }

  station_options <- sapply(station_list, function(s) {
    paste0(s$station_id, " (", s$label, ")")
  })

  selected <- ui_select_from_menu("Select station:", station_options)
  if (is.null(selected)) {
    cat("Canceled\n")
    return(invisible(NULL))
  }
  # ui_select_from_menu returns the chosen STRING, not an index, so strip the
  # parenthesised site name back off it.
  station_id <- sub(" \\(.*\\)$", "", selected)

  # Terminal devices are included, not filtered out. Their rows are the
  # historical record, and a value recorded wrongly on one - a mis-entered
  # coordinate, or the wrong terminal status - has no other route to being
  # fixed. Listing only active devices made that unreachable.
  all_meta <- load_zentra_metadata()
  devices <- all_meta[all_meta$station_id == station_id, , drop = FALSE]
  devices <- order_devices_by_role(devices)

  if (nrow(devices) == 0) {
    cat("No devices at this station.\n")
    return(invisible(NULL))
  }

  terminal_statuses <- TERMINAL_STATUSES

  device_options <- vapply(seq_len(nrow(devices)), function(i) {
    label <- device_label(devices[i, ], with_role = TRUE)
    if (tolower(devices$status[i]) %in% terminal_statuses) {
      paste0(label, "  [", devices$status[i], "]")
    } else {
      label
    }
  }, character(1))

  if (nrow(devices) == 1) {
    row_i <- 1
    cat("\nDevice: ", device_options[1], "\n", sep = "")
  } else {
    dsel <- ui_select_from_menu("Select device:", device_options)
    if (is.null(dsel)) {
      cat("Canceled\n")
      return(invisible(NULL))
    }
    row_i <- match(dsel, device_options)
  }

  device_serial <- devices$device_serial[row_i]
  device_status <- devices$status[row_i]

  #### Show current values ####
  metadata <- load_zentra_metadata()
  # The row chosen, by unique_id. Serial, station and status together are not
  # enough: a logger moved twice within a station leaves two 'relocated' rows
  idx <- which(metadata$unique_id == devices$unique_id[row_i])

  if (length(idx) == 0) {
    cat("Could not find that device row.\n")
    return(invisible(NULL))
  }
  idx <- idx[1]

  # Descriptive fields only. deploy_datetime, lat and lon are here because a
  # value recorded wrongly at creation has no other route to being fixed -
  # but note that lat/lon changing because the DEVICE MOVED is an event, and
  # belongs in the relocation or replacement workflow so it leaves a log entry.
  editable <- c("model", "device_name", "device_role", "interval_min",
                "deploy_datetime", "lat", "lon", "elev")
  editable <- editable[editable %in% names(metadata)]

  # A device already in a terminal state can have that state CORRECTED here -
  # but only where a workflow recorded the wrong one. Terminal statuses are
  # otherwise set by the workflows that log the event, and this must not
  # become the easy way to bypass them.
  is_terminal <- tolower(metadata$status[idx]) %in% terminal_statuses
  if (is_terminal) editable <- c(editable, "end_datetime", "status")

  # Datetimes shown in full, in the project zone; everything else as is
  show <- function(v) {
    if (inherits(v, "POSIXct") && length(v) == 1 && !is.na(v)) {
      return(format(v, "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ))
    }
    blank_or_value(v)
  }
  # Asked once, at the first correction that needs logging
  logged_by <- NULL

  repeat {
    cat("\n--- CURRENT VALUES ---\n\n")
    for (i in seq_along(editable)) {
      value <- metadata[[editable[i]]][idx]
      display <- show(value)
      cat("  ", i, ". ", format(editable[i], width = max(nchar(editable))), " ", display, "\n", sep = "")
    }
    cat("  q. Done\n\n")
    cat("Which field to correct? ")

    choice <- trimws(readline())
    if (tolower(choice) == "q") break

    if (!grepl("^[0-9]+$", choice) ||
        as.numeric(choice) < 1 || as.numeric(choice) > length(editable)) {
      cat("Invalid selection\n")
      next
    }

    field <- editable[as.numeric(choice)]
    current <- metadata[[field]][idx]

    cat("\nCurrent ", field, ": ", show(current), "\n", sep = "")

    #### Field-specific prompting ####
    if (field %in% c("model", "device_role")) {
      existing <- get_metadata_unique_values(field)
      if (length(existing) > 0) {
        new_value <- ui_select_or_specify(paste0("Select ", field, ":"), existing)
        if (is.null(new_value)) next
      } else {
        cat("Enter new ", field, " (or press Enter to leave blank): ", sep = "")
        new_value <- trimws(readline())
        if (new_value == "") new_value <- NA
      }

    } else if (field == "interval_min") {
      cat("Enter logging interval in minutes: ")
      input <- trimws(readline())
      new_value <- suppressWarnings(as.numeric(input))
      if (is.na(new_value) || new_value <= 0) {
        cat("Invalid interval - must be a positive number\n")
        next
      }

    } else if (field == "status") {
      # Only terminal-to-terminal. Bringing a device back into service is a
      # reactivation - a real event with its own workflow and its own log
      # entry - not a correction.
      cat("\nThis device is recorded as '", current, "'.\n", sep = "")
      cat("Correct it only if the wrong terminal status was recorded, e.g. a\n")
      cat("device swap logged as 'decommissioned' when it was 'replaced'.\n\n")
      for (st in TERMINAL_STATUSES) {
        cat("  ", format(st, width = 15), " ", STATUS_MEANINGS[[st]], "\n", sep = "")
      }
      cat("\n")
      cat("To bring a device back into service, use 'Reactivate\n")
      cat("decommissioned station' instead - that is an event, not a\n")
      cat("correction.\n\n")

      # From the list only: a typed status would be one nothing knows
      new_value <- ui_select_from_menu("Select the correct status:",
                                       setdiff(terminal_statuses, tolower(current)))
      if (is.null(new_value)) next

    } else if (field == "elev") {
      # Offer a lookup rather than only accepting a typed number - the
      # coordinates are right there, and a corrected elevation is usually a
      # corrected position.
      if (!exists("ui_prompt_elevation")) {
        suppressMessages(try(load_functions("ui_prompt"), silent = TRUE))
      }
      res <- ui_prompt_elevation(metadata$lat[idx], metadata$lon[idx],
                                 metadata$station_type[idx],
                                 metadata$device_role[idx])
      new_value <- res$elev
      new_source <- res$elev_source
      if (is.na(new_value)) {
        cat("\u2713 No elevation recorded\n")
      }

    } else if (field %in% c("deploy_datetime", "end_datetime")) {
      cat("Enter ", sub("_datetime", "", field), " datetime (YYYY-MM-DD HH:MM:SS): ", sep = "")
      input <- trimws(readline())
      if (input == "") {
        cat("Not changed\n")
        next
      }
      parsed <- tryCatch(coerce_datetime_flexible(input, metadata$timezone[idx]),
                         error = function(e) NULL)
      if (is.null(parsed) || length(parsed) != 1 || is.na(parsed)) {
        cat("Could not read that as a date or datetime\n")
        next
      }
      new_value <- as.POSIXct(format(parsed, "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ), tz = PROJECT_TZ)
      other_end <- if (field == "deploy_datetime") metadata$end_datetime[idx] else metadata$deploy_datetime[idx]
      if (!is.na(other_end) &&
          (if (field == "deploy_datetime") new_value > other_end else new_value < other_end)) {
        cat("\u274c That puts the deploy time after the end time (",
            show(other_end), ")\n", sep = "")
        next
      }

    } else if (field %in% c("lat", "lon")) {
      # Corrections only. A device that physically moved is an event - use the
      # relocation or replacement workflow so the move is logged.
      cat("\nOnly for correcting a coordinate recorded wrongly.\n")
      cat("If the device MOVED, cancel and use relocation or replacement\n")
      cat("instead, so the move is recorded in the maintenance log.\n\n")
      cat("Enter new ", field, " (decimal degrees, Enter to leave it): ", sep = "")
      input <- trimws(readline())
      if (input == "" || tolower(input) == "q") {
        cat("Not changed\n")
        next
      }
      new_value <- suppressWarnings(as.numeric(input))
      if (is.na(new_value)) {
        cat("Invalid - must be a number in decimal degrees\n")
        next
      }
      limit <- if (field == "lat") 90 else 180
      if (abs(new_value) > limit) {
        cat("Invalid - ", field, " must be between -", limit, " and ", limit,
            "\n", sep = "")
        next
      }
      # These stations are all in the Virgin Islands; a sign error puts a
      # coordinate in the Indian Ocean and nothing downstream would notice.
      if (field == "lat" && (new_value < 17 || new_value > 19)) {
        cat("\n⚠️  ", new_value, " is outside the Virgin Islands (17-19 N)\n", sep = "")
        if (ui_yes_no("Is that right?", allow_quit = FALSE) == "N") next
      }
      if (field == "lon" && (new_value > -64 || new_value < -66)) {
        cat("\n⚠️  ", new_value, " is outside the Virgin Islands (-64 to -66 W)\n", sep = "")
        if (ui_yes_no("Is that right?", allow_quit = FALSE) == "N") next
      }

    } else {
      cat("Enter new ", field, " (or press Enter to leave blank): ", sep = "")
      new_value <- trimws(readline())
      if (new_value == "") new_value <- NA
    }

    #### Confirm ####
    cat("\n  ", field, "\n", sep = "")
    cat("    from: ", show(current), "\n", sep = "")
    cat("    to:   ", show(new_value), "\n\n", sep = "")

    confirmed <- ui_yes_no("Apply this correction?", allow_quit = FALSE)
    if (confirmed == "N") {
      cat("Not applied\n")
      next
    }
    if (is.null(logged_by)) logged_by <- ui_ask_whois_logging()

    #### Which rows ####
    # Some of these describe the BOX, not the station it serves. One ZL6 can
    # carry a weather station and a vwc station at once, and its model, name,
    # logging interval and subscription are the same fact seen from two rows -
    # correcting one and leaving the other is how metadata ends up
    # contradicting itself.
    #
    # deploy_datetime, end_datetime, device_role, lat and lon stay on the
    # single row. A co-located station can begin years after its logger
    # arrives, and roles differ by station.
    #
    # elev goes the other way: a paired gauge carries one elevation, the
    # primary's, on every logger, so correcting it on one corrects it on all
    per_device <- c("model", "device_name", "interval_min")

    rows <- idx
    shares <- "share this logger"
    if (field %in% per_device) {
      companions <- which(metadata$device_serial == device_serial &
                          !tolower(metadata$status) %in% terminal_statuses)
      rows <- union(idx, companions)
    }
    if (field == "elev") {
      rows <- union(idx, which(metadata$unique_id %in%
                                 elevation_shared_with(metadata$unique_id[idx], metadata)))
      shares <- "are one paired gauge, which carries one elevation"
    }
    uid <- metadata$unique_id[idx]
    # Named as it was, before the correction - a rename's entry names the old
    who <- device_label(metadata[idx, ])

    #### Write: the value, the ports that follow it, and the log entry ####
    # One change, so a correction is never half-applied or left unlogged
    moved_ports <- 0L
    outcome <- tryCatch(with_metadata_change(paste0("correcting ", field), {
      metadata[[field]][rows] <- new_value
      if (field == "elev") metadata$elev_source[rows] <- new_source
      save_device_metadata(metadata)

      # A port configuration that began when the device went in, or ended
      # when it came out, moves with a corrected deploy or end time. Left
      # behind, the sensors would appear to start before the device existed
      if (field %in% c("deploy_datetime", "end_datetime") && !is.na(current)) {
        ports <- load_zentra_ports_data()
        col <- if (field == "deploy_datetime") "valid_from" else "valid_to"
        hit <- which(ports$unique_id == uid & !is.na(ports[[col]]) &
                       abs(as.numeric(ports[[col]]) - as.numeric(current)) < 1)
        if (length(hit) > 0) {
          ports[[col]][hit] <- new_value
          save_zentra_ports(ports, intent = paste0("correcting ", field))
          moved_ports <- length(hit)
        }
      }

      create_maintenance_entry(
        field_visit_date = local_date(Sys.time()),
        station_id       = station_id,
        unique_id        = uid,
        action_type      = if (field == "device_name") "device_renamed" else "metadata_correction",
        details          = paste0(field, " of ", who, ": ",
                                  show(current), " \u2192 ", show(new_value),
                                  if (length(rows) > 1) paste0(" (", length(rows), " rows)"),
                                  if (moved_ports > 0) paste0("; ", moved_ports, " port row",
                                                              if (moved_ports != 1) "s", " moved with it")),
        logged_by        = logged_by
      )
    }), error = function(e) conditionMessage(e))

    if (!isTRUE(outcome)) {
      cat("\u274c Not saved - ", if (is.character(outcome)) outcome else "the change was refused",
          "\n   Nothing was changed.\n", sep = "")
      metadata <- load_zentra_metadata()
      next
    }

    if (length(rows) > 1) {
      others <- setdiff(metadata$station_id[rows], station_id)
      cat("Updated ", field, " on ", length(rows), " rows - ",
          if (length(others) > 0) paste0(station_id, " and ", paste(others, collapse = ", "))
          else paste0("all at ", station_id), " ", shares, "\n", sep = "")
    } else {
      cat("Updated ", field, "\n", sep = "")
    }
    if (moved_ports > 0) {
      cat("Moved ", moved_ports, " port configuration row", if (moved_ports != 1) "s",
          " to the corrected time\n", sep = "")
    }
    cat("Logged to maintenance\n")

    # Coordinates changed means the elevation describes somewhere else - but
    # a paired gauge carries its primary's elevation on every logger, so a
    # secondary's corrected position changes nothing about it
    metadata <- load_zentra_metadata()
    paired_secondary <- length(elevation_shared_with(metadata$unique_id[idx], metadata)) > 1 &&
      !identical(tolower(metadata$device_role[idx]), "primary")
    if (field %in% c("lat", "lon") && paired_secondary) {
      cat("\nThis is a paired gauge, which carries its primary's elevation -\n")
      cat("correct the primary's position to look it up again.\n")
    }
    if (field %in% c("lat", "lon") && !paired_secondary) {
      cat("\nThe elevation on record was looked up for the old coordinates.\n")
      cat("If you still have the other coordinate to correct, say no and do\n")
      cat("the lookup once both are right.\n")
      if (ui_yes_no("Look up the elevation for the new position?",
                    allow_quit = FALSE) == "Y") {
        metadata <- load_zentra_metadata()
        res <- ui_prompt_elevation(metadata$lat[idx], metadata$lon[idx],
                                   metadata$station_type[idx],
                                   metadata$device_role[idx])
        # A paired gauge carries one elevation on every logger
        erows <- which(metadata$unique_id %in%
                         elevation_shared_with(metadata$unique_id[idx], metadata))
        old_elev <- metadata$elev[idx]
        e_out <- tryCatch(with_metadata_change("updating elevation", {
          metadata$elev[erows] <- res$elev
          metadata$elev_source[erows] <- res$elev_source
          save_device_metadata(metadata)
          create_maintenance_entry(
            field_visit_date = local_date(Sys.time()),
            station_id = station_id, unique_id = uid,
            action_type = "metadata_correction",
            details = paste0("elev of ", who, ": ",
                             show(old_elev), " \u2192 ", show(res$elev),
                             " after a coordinate correction"),
            logged_by = logged_by)
        }), error = function(e) conditionMessage(e))
        if (isTRUE(e_out)) {
          cat("\u2713 Elevation updated", if (length(erows) > 1)
            paste0(" on ", length(erows), " paired rows"), "\n", sep = "")
        } else {
          cat("\u274c Elevation not updated - ", e_out, "\n", sep = "")
        }
      }
    }

    # Re-read so the display reflects what is actually on disk
    metadata <- load_zentra_metadata()
  }

  cat("\nDone.\n")
  invisible(TRUE)
}

#' Asks for a device role, offering only the roles this station can use
#'
#' A role means one thing per station type: at a paired stream gauge, which
#' logger is the anchor and which the upstream one; at a vwc station, that it
#' shares the weather station's logger. Offering every role ever recorded put
#' rb2's tertiary - an arrangement not to be repeated - on every menu, and a
#' role already held at the station could be given out twice.
#'
#' @param station_type Character
#' @param station_id Character. The station, to leave out roles already held
#' @param replacing_uid Character. A row being replaced, whose role is free
#' @return The role, NA for none, or "cancel"
ui_prompt_device_role <- function(station_type, station_id = NULL, replacing_uid = NULL) {
  type <- tolower(station_type)
  allowed <- switch(type, hydro = c("primary", "secondary"),
                    vwc = "primary", weather = "primary", character(0))
  if (length(allowed) == 0) {
    cat("\n\u2713 No device role - a ", type, " station does not use one\n", sep = "")
    return(NA_character_)
  }

  cat("\nDevice role - most devices do not need one:\n\n")
  if (type == "hydro") {
    cat("  Paired stream gauges only. primary is the anchor - where flow is\n")
    cat("  gauged, normally the DOWNSTREAM logger; secondary is upstream.\n")
    cat("  A lone gauge has no role.\n\n")
  } else if (type == "vwc") {
    cat("  primary ONLY if this shares the weather station's logger.\n")
    cat("  Otherwise none.\n\n")
  } else {
    cat("  Almost always none.\n\n")
  }

  taken <- character(0)
  if (!is.null(station_id)) {
    meta <- load_zentra_metadata()
    # The logger being replaced is leaving: its role is the one to fill
    here <- meta[meta$station_id %in% station_id &
                   !tolower(meta$status) %in% TERMINAL_STATUSES &
                   !meta$unique_id %in% replacing_uid, , drop = FALSE]
    taken <- tolower(here$device_role[!is.na(here$device_role)])
  }
  available <- setdiff(allowed, taken)
  if (length(available) == 0) {
    cat("\u2713 No device role - ", station_id, " already has its ",
        paste(allowed, collapse = " and "), "\n", sep = "")
    return(NA_character_)
  }

  if (ui_yes_no("Specify a device role?", allow_quit = FALSE) == "N") {
    cat("\u2713 No device role recorded\n")
    return(NA_character_)
  }
  # Chosen even when only one is open: a role is a statement about the
  # station, and it should be made, not assumed
  role <- ui_select_from_menu("Select device role:", available)
  if (is.null(role)) return("cancel")
  cat("\u2713 Device role:", role, "\n")
  role
}

#' Asks for a latitude and longitude, checked against the Virgin Islands
#'
#' Every station is in the Virgin Islands, so a coordinate outside them is
#' far more likely a slip - a dropped minus sign, the two swapped - than a
#' place. It is shown and confirmed rather than refused.
#'
#' @param which Character. Put before the prompts - "NEW " for a relocation
#' @return Named numeric: lat, lon
ui_prompt_coordinates <- function(which = "") {
  ask <- function(what, eg, limit) {
    repeat {
      cat("Enter ", which, what, " (decimal degrees, e.g., ", eg, "):\n", sep = "")
      v <- suppressWarnings(as.numeric(trimws(readline())))
      if (!is.na(v) && abs(v) <= limit) return(v)
      cat("\u26a0\ufe0f  Invalid ", what, ". Must be between -", limit, " and ", limit, ".\n", sep = "")
    }
  }
  repeat {
    lat <- ask("latitude", "17.7456", 90)
    cat("\u2713 Latitude: ", lat, "\n", sep = "")
    lon <- ask("longitude", "-64.7890", 180)
    cat("\u2713 Longitude: ", lon, "\n", sep = "")
    if (lat >= 17 && lat <= 19 && lon >= -66 && lon <= -64) break
    cat("\n\u26a0\ufe0f  ", lat, ", ", lon, " is outside the Virgin Islands (17 to 19 N, 64 to 66 W)\n",
        sep = "")
    if (ui_yes_no("Is that right?", allow_quit = FALSE) == "Y") break
    cat("\n")
  }
  c(lat = lat, lon = lon)
}

#' A model with its depth range, for a menu or a summary
#'
#' The two U20 models look alike in a list, and which one went in decides
#' whether a pressure reading is in range
#'
#' @param model Character
#' @return Character, the model with its range in parentheses where known
model_label <- function(model) {
  ranges <- c("U20-001-01" = "30 ft", "U20-001-04" = "13 ft",
              "U20L-01" = "30 ft", "U20L-04" = "13 ft",
              "MX2001-01-SS-S" = "30 ft", "MX2001-04-SS-S" = "13 ft")
  out <- ifelse(is.na(model), "(model not recorded)", model)
  known <- !is.na(model) & model %in% names(ranges)
  out[known] <- paste0(model[known], " (", ranges[model[known]], ")")
  out
}

#' Ports for a ZL6 that replaced another
#'
#' The sensors usually move from the old box to the new one, port for port.
#' Offered as one answer rather than six ports retyped - and where they did
#' not, the ports are configured as for any new logger.
#'
#' @param old_serial,new_serial Character
#' @return Invisibly TRUE if ports were saved
ui_ports_after_replacement <- function(old_serial, new_serial) {
  ports <- load_zentra_ports_data()
  old <- ports[ports$sn %in% old_serial & !is.na(ports$valid_to), , drop = FALSE]
  if (nrow(old) > 0) old <- old[old$valid_to == max(old$valid_to), , drop = FALSE]
  if (nrow(old) == 0) {
    if (ui_yes_no("\nInitialize port configuration for new device?", allow_quit = FALSE) == "Y") {
      return(invisible(isTRUE(ui_initialize_ports(new_serial))))
    }
    return(invisible(FALSE))
  }

  old <- old[order(old$port), , drop = FALSE]
  cat("\nThe old logger's sensors when it came out:\n")
  for (i in seq_len(nrow(old))) {
    cat("  Port ", old$port[i], ": ", old$sensor[i],
        if (!is.na(old$depth_cm[i])) paste0(" @ ", old$depth_cm[i], "cm"),
        if (!is.na(old$status[i]) && old$status[i] == "defunct") " [DEFUNCT]",
        "\n", sep = "")
  }
  if (ui_yes_no("Did the same sensors go into the new logger, on the same ports?",
                allow_quit = FALSE) == "N") {
    return(invisible(isTRUE(ui_initialize_ports(new_serial))))
  }

  cfg <- data.frame(port = 1:6, type = "none", sensor = "none", depth_cm = NA_real_,
                    status = NA_character_, stringsAsFactors = FALSE)
  at <- match(old$port, cfg$port)
  cfg$type[at] <- old$type
  cfg$sensor[at] <- old$sensor
  cfg$depth_cm[at] <- old$depth_cm
  cfg$status[at] <- old$status
  res <- initialize_ports(new_serial, cfg)
  if (!isTRUE(res)) {
    cat("\u274c Not saved - ", res, "\n", sep = "")
    return(invisible(FALSE))
  }
  cat("\u2713 Ports recorded on ", device_label(new_serial), ", as on the old logger\n", sep = "")
  invisible(TRUE)
}

#' Port setup for a ZL6 just added or reactivated at a station
#'
#' Shared by the new-station and reactivation paths, which had drifted into
#' two copies of it.
#'
#' @param result List from ui_add_device() or ui_reactivate_station(), with
#'   device_serial, station_id and optionally station_type
#' @return Invisibly NULL
ui_setup_ports_after_add <- function(result) {
  # Zentra device - ask about ports, unless this serial already has
  # them. A ZL6 shared between a weather and a vwc station is
  # configured once, by whichever station was set up first.
  # A NULL here would silently disable the type filter, which is
  # exactly the bug this check exists to prevent - so fall back to
  # metadata rather than trusting the caller.
  device_station_type <- result$station_type
  if (is.null(device_station_type) || is.na(device_station_type)) {
    meta_lu <- load_zentra_metadata()
    # The station just worked on - a shared ZL6 serves two types
    hit <- meta_lu$station_type[meta_lu$device_serial == result$device_serial &
                                  meta_lu$station_id %in% result$station_id]
    device_station_type <- if (length(hit) > 0) hit[1] else NULL
  }
  
  if (nrow(get_active_ports(result$device_serial,
                            device_station_type)) > 0) {
    review_shared_ports(result$device_serial, device_station_type)
    
  } else if (nrow(get_active_ports(result$device_serial)) > 0) {
    # The logger has active ports, but none of this station's type -
    # its sensor was taken off when the station was last retired.
    cat("\n⚠️  ", device_label(result$device_serial), " has active ports, but none\n",
        sep = "")
    cat("   of type '", device_station_type, "'. Its sensor was\n", sep = "")
    cat("   removed when this station was last retired.\n\n")
    cat("   Full port initialization would overwrite the other\n")
    cat("   station's configuration, so the sensor is recorded one\n")
    cat("   port at a time instead.\n\n")
    
    # Offer it here rather than naming a menu item. A pointer to
    # somewhere else is a step someone has to remember to take.
    if (ui_yes_no(paste0("Set up the ", device_station_type,
                         " sensor for this station now?"),
                  allow_quit = FALSE) == "Y") {
      ui_update_ports(preset_device_serial = result$device_serial)
    } else {
      cat("\u2713 Record it later with 'Port configuration change'\n")
      cat("  (existing station work, option 3)\n")
    }
    
  } else {
    init_ports <- ui_yes_no("\nInitialize port configuration now?",
                            allow_quit = FALSE)
    
    if (init_ports == "Y") {
      ui_initialize_ports(result$device_serial)
    } else {
      cat("⚠️  Remember to initialize ports later!\n")
    }
  }
  invisible(NULL)
}

#' Resumes an unfinished data ingest
#'
#' check_pending() reports outstanding work; this acts on it. Without it the
#' only apparent route is to run the download workflow again, which would be
#' wrong - the field record was already written, so a second pass would
#' duplicate the maintenance entry and re-stamp last_visit. What is actually
#' outstanding is the archiving alone.
#'
#' @return TRUE if an ingest completed, FALSE if deferred again, NULL if canceled
ui_resume_pending_ingest <- function() {

  pending <- load_pending_ingest()

  if (nrow(pending) == 0) {
    cat("\nNo unfinished data tasks.\n")
    return(invisible(NULL))
  }

  cat("\n============================================\n")
  cat("  Resume Unfinished Data Task\n")
  cat("============================================\n\n")

  options <- character(nrow(pending))
  meta_names <- load_zentra_metadata()
  for (i in seq_len(nrow(pending))) {
    label <- PENDING_STAGE_LABELS[pending$stage[i]]
    if (is.na(label)) label <- pending$stage[i]
    at <- match(pending$unique_id[i], meta_names$unique_id)
    who <- if (!is.na(at)) paste0("  ", device_label(meta_names[at, ])) else ""
    options[i] <- paste0(pending$station_id[i], who,
                         "  visited ", pending$field_visit_date[i],
                         "  - ", label)
  }

  selected <- ui_select_from_menu("Select task to resume:", options)
  if (is.null(selected)) {
    cat("Canceled\n")
    return(invisible(NULL))
  }

  idx <- which(options == selected)[1]
  row <- pending[idx, ]

  #### Fill in what the pending row does not carry ####
  metadata <- load_zentra_metadata()
  dev <- metadata[metadata$unique_id == row$unique_id, ]

  if (nrow(dev) == 0) {
    cat("\n❌ Deployment ", row$unique_id, " is no longer in metadata for ",
        row$station_id, ".\n", sep = "")
    cat("   Its row may have been deleted since this task was recorded.\n")
    return(invisible(NULL))
  }
  dev <- dev[1, ]

  #### A cloud upload is not an ingest - it just needs confirming ####
  if (row$stage == "awaiting_cloud_upload") {
    cat("This station was offloaded on site but the data has not yet been\n")
    cat("uploaded to ZentraCloud.\n\n")

    uploaded <- ui_yes_no("Has it been uploaded now?", allow_quit = FALSE)

    if (uploaded == "Y") {
      # Only clears the pending task. The metadata review is a separate
      # question - whether the metadata is current - and is not implied by
      # data having reached the cloud.
      clear_pending_ingest(row$station_id, dev$device_serial)
      cat("✓ Task cleared\n\n")
      return(invisible(TRUE))
    }

    cat("\nLeft outstanding - you will be reminded again.\n\n")
    return(invisible(FALSE))
  }

  #### Otherwise hand back to the ingest workflow at the recorded stage ####
  ui_ingest_local_data(
    station_id       = row$station_id,
    device_serial    = dev$device_serial,
    station_type     = dev$station_type,
    mfger            = dev$mfger,
    field_visit_date = as.Date(row$field_visit_date),
    logged_by        = row$logged_by,
    resume_stage     = row$stage
  )
}

#' Everything that should happen on the way out of the metadata manager
#'
#' There are two exits - 'q' from the main menu, and declining "do something
#' else" - and anything worth saying on the way out has to be said at both.
#' Putting it in one place is why the station photo reminder was missing from
#' one of them for a week.
#'
#' @param entries_at_start Integer. Maintenance log row count when the session
#'   began, used to report what this session wrote
#' @return Invisible TRUE
ui_exit_metadata_manager <- function(entries_at_start = NA) {

  #### What did this session actually write? ####
  # A last look before walking away. Everything here is already saved - this
  # is a chance to notice a wrong date or a misfiled station while it is still
  # fresh, not an opportunity to undo anything.
  wrote <- FALSE
  if (!is.na(entries_at_start)) {
    mlog <- tryCatch(load_maintenance_log(), error = function(e) NULL)

    if (!is.null(mlog) && nrow(mlog) > entries_at_start) {
      wrote <- TRUE
      new_rows <- mlog[(entries_at_start + 1):nrow(mlog), , drop = FALSE]

      cat("\n--- LOGGED THIS SESSION ---\n\n")
      for (i in seq_len(nrow(new_rows))) {
        cat("  ", format(as.character(new_rows$field_visit_date[i]), width = 12),
            format(new_rows$station_id[i], width = 14),
            format(new_rows$action_type[i], width = 20), "\n", sep = "")
        det <- new_rows$details[i]
        if (!is.na(det) && nzchar(trimws(det))) {
          cat("      ", det, "\n", sep = "")
        }
      }
      cat("\n  ", nrow(new_rows), " entr",
          ifelse(nrow(new_rows) == 1, "y", "ies"), " written.\n", sep = "")
    }
  }

  #### Station photos ####
  # Filed by hand, and nothing else in the system asks for them, so they are
  # quietly forgotten. Asked only after a session that logged a visit - a
  # desk session has no photos to file
  if (wrote) {
    photo_dir <- file.path(wds("meta_internal"), "station_photos")
    cat("\nIf you took station photos on this visit, file them here:\n\n")
    cat("     ", photo_dir, "\n\n", sep = "")
    cat("  Named station_id_YYYY-MM-DD, e.g. sr1_hydro_2026-03-02.jpeg\n")
  }

  cat("\n\u2713 Exiting Metadata Manager\n")
  invisible(TRUE)
}


################################################################################
#  MENU
################################################################################

#' Main metadata manager - orchestrates all metadata workflows
#' Interactive decision tree that routes to appropriate UI functions
metadata_manager <- function() {
  
  # Row count at the start, so the exit summary can report what this session
  # added rather than the whole log
  entries_at_start <- tryCatch(nrow(load_maintenance_log()),
                               error = function(e) NA_integer_)

  # A workflow that fails - a refused save, a file that will not read - comes
  # back to the menu saying why, rather than ending the session. What it had
  # already saved stays saved; a change of several saves is put back whole
  repeat {
    done <- tryCatch({
      metadata_manager_menu(entries_at_start)
      TRUE
    }, error = function(e) {
      # Scripted answers that ran out (the tests) are not a workflow failing:
      # going back to the menu would ask again, forever
      if (inherits(e, "viflo_input_exhausted")) stop(e)
      cat("\n\u274c That stopped: ", conditionMessage(e), "\n", sep = "")
      cat("   Back to the menu.\n")
      FALSE
    })
    if (done) return(invisible(TRUE))
  }
}

#' The metadata manager's menu, until the person quits - see metadata_manager()
metadata_manager_menu <- function(entries_at_start) {
  
  repeat {  # Main loop - allows multiple operations
    
    cat("\n============================================\n")
    cat("  VI-FLO Engine - Metadata Manager\n")
    cat("============================================\n")
    
    #### Unfinished business first
    # Data left on a logger, a shuttle, or a phone is data at risk. Raising it
    # here every single time is the point: the system remembers, not the person.
    n_pending <- 0
    if (exists("check_pending")) {
      pending_now <- check_pending()
      n_pending <- nrow(pending_now)
    }
    
    #### TOP LEVEL - What happened?
    cat("What happened?\n")
    cat("  1. Worked on existing station/device\n")
    cat("  2. Established new station/device or reactivated old station\n")
    cat("  3. View metadata and network status\n")
    cat("  4. Explain unattributed readings\n")
    if (n_pending > 0) {
      cat("  r. Resume an unfinished data task\n")
    }
    cat("  q. Quit\n")
    cat("\nEnter selection: ")
    
    top_choice <- trimws(readline())
    
    if (tolower(top_choice) == "q") {
      return(ui_exit_metadata_manager(entries_at_start))
    }
    
    #### Resume an unfinished data task ####
    if (tolower(top_choice) == "r" && n_pending > 0) {
      ui_resume_pending_ingest()
      next
    }
    
    #### Explain readings that belong to no station ####
    if (top_choice == "4") {
      ui_explain_unattributed()
      next
    }

    # Hidden admin function - delete metadata row
    if (tolower(top_choice) == "deletion") {
      ui_delete_metadata_row()
      next  # Return to main menu after deletion
    }
    
    ################################################################################
    #### BRANCH 1: WORKED ON EXISTING STATION ####
    ################################################################################
    
    if (top_choice == "1") {
      
      repeat {  # Sub-loop for multiple actions at same station
        
        cat("\n--- EXISTING STATION WORK ---\n")
        cat("What type of work?\n")
        cat("  1. Routine maintenance ONLY (cleaning, battery, inspection, notes)\n")
        cat("  2. Downloaded data manually (HOBO or local Zentra)\n")
        cat("  3. Port configuration change (sensor swap, depth change)\n")
        cat("  4. Device replacement (old device out, new device in)\n")
        cat("  5. Device removal (taking device out of service)\n")
        cat("  6. Station relocated (moved to new location)\n")
        cat("  7. Station decommissioned (entire station shut down)\n")
        cat("  8. Field survey - sensor heights, falls, reach, GNSS elevation\n")
        cat("  9. Correct device details (model, name, role, interval, dates, coords)\n")
        cat("  q. Back to main menu\n")
        cat("\nEnter selection: ")
        
        work_choice <- trimws(readline())
        
        if (tolower(work_choice) == "q") {
          break  # Back to main menu
        }
        
        ### Option 1: Routine maintenance
        if (work_choice == "1") {
          result <- ui_log_maintenance()
          
          if (!is.null(result)) {
            # Ask if they also did more significant work
            # Two different situations, previously asked as one question and
            # answered as the other. Doing maintenance AND a port change on
            # one visit is normal - both happened, both belong in the log.
            # Picking the wrong workflow is a miscategorization, and only that
            # warrants removing the entry just written.
            cat("\nAnything else at this station on this visit?\n")
            cat("  1. Yes - I also did something else (port change, device\n")
            cat("     replacement, relocation, decommissioning)\n")
            cat("  2. No - that was the whole visit\n")
            cat("  3. I picked the wrong workflow - this was not routine\n")
            cat("     maintenance\n\n")
            cat("Response: ")
            major_work <- trimws(readline())
            
            if (major_work == "1") {
              cat("\n\u2713 Maintenance entry kept - select the next workflow\n")
              next
              
            } else if (major_work == "3") {
              cat("\nThe routine maintenance entry just logged will be removed,\n")
              cat("and you can select the workflow you meant.\n\n")
              
              if (ui_yes_no("Remove it?", allow_quit = FALSE) == "Y") {
                delete_result <- delete_last_maintenance_entry(result$device_serial,
                                                               result$station_id)
                if (isTRUE(delete_result)) {
                  cat("\u2713 Entry removed - select the correct workflow\n")
                } else {
                  cat("\u26a0\ufe0f  Could not remove the entry - edit maintenance_log.csv by hand\n")
                }
              } else {
                cat("\u2713 Entry kept\n")
              }
              next
              
            } else {
              break
            }
          } else {
            # User quit - back to work type menu
            next
          }
        }
        
        ### Option 2: Downloaded data
        else if (work_choice == "2") {
          result <- ui_log_download()
          
          if (!is.null(result)) {
            # Nobody visits a station, downloads it, and does nothing else -
            # at minimum they looked at it. So offer the maintenance entry
            # directly, carrying over the station, device and date rather than
            # making the user re-select all three from the top of the menu.
            cat("\nLog routine maintenance for this visit?\n")
            cat("  Inspection, cleaning, battery, relaunch - same station,\n")
            cat("  device and date, no need to re-select.\n")
            add_maint <- ui_yes_no("Log it now?", allow_quit = FALSE)
            
            if (add_maint == "Y") {
              ui_log_maintenance(
                prefill_station    = result$station_id,
                prefill_device     = result$device_serial,
                prefill_visit_date = result$field_visit_date,
                prefill_logged_by  = result$logged_by
              )
            }
            
            cat("\nSensor swap, device replaced, station moved -> its own workflow\n")
            more_work <- ui_yes_no("Anything else at this station on this visit?",
                                   allow_quit = FALSE)
            if (more_work != "Y") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 3: Port configuration change
        else if (work_choice == "3") {
          result <- ui_update_ports()
          
          if (!is.null(result)) {
            cat("\nIf you also replaced/relocated/decommissioned, select that\n")
            cat("workflow next.\n")
            more_work <- ui_yes_no("Did you do anything else at this station?",
                                   allow_quit = FALSE)
            if (more_work != "Y") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 4: Device replaced
        else if (work_choice == "4") {
          result <- ui_replace_device()
          
          if (!is.null(result)) {
            # ui_replace_device() handles both:
            # 1. Marking old device as "replaced"
            # 2. Adding new replacement device
            # Returns: list(old_device_serial, new_device_serial)
            
            # Check if new device is HOBO (no ports needed)
            metadata <- load_zentra_metadata()
            new_device_row <- get_device_row(result$new_device_serial,
                                             metadata = metadata)
            
            if (is_hobo_device(new_device_row$mfger)) {
              cat("✓ HOBO device - no port configuration needed\n")
              
            } else {
              # No "already configured" guard here, deliberately. A replacement
              # means a box was physically brought out and sensors plugged into
              # it, so its ports DO need configuring. The only serial that
              # would trip such a guard is one already active at another
              # station - which is not a replacement at all.
              ui_ports_after_replacement(result$old_device_serial,
                                         result$new_device_serial)
            }
            
            #### Metadata review, once the new device is fully recorded ####
            new_row <- get_device_row(result$new_device_serial,
                                      station_id = result$station_id)
            if (!is.null(new_row)) {
              ui_prompt_metadata_approval(new_row$station_id)
            }
            
            cat("\nNote: the device is replaced - further work would be on the\n")
            cat("NEW device.\n")
            more_work <- ui_yes_no("Did you do anything else at this station?",
                                   allow_quit = FALSE)
            if (more_work != "Y") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 5: Device removed
        else if (work_choice == "5") {
          result <- ui_remove_device()
          
          if (!is.null(result)) {
            more_work <- ui_yes_no("\nDid you do anything else at this station?",
                                   allow_quit = FALSE)
            if (more_work != "Y") {
              break
            }
          } else {
            next
          }
        }
        
        ### Option 6: Station relocated
        else if (work_choice == "6") {
          result <- ui_relocate_station()
          
          if (!is.null(result)) {
            #### A new logger arrives with nothing configured ####
            if (isTRUE(result$ports_need_work)) {
              cat("\nSome sensors did not move with the logger.\n")
              ui_update_ports(preset_device_serial = result$device_serial)
            }
            
            # A new logger brought in on the move: often the same sensors,
            # carried to the new spot and plugged in port for port
            if (isTRUE(result$device_changed) &&
                !is_hobo_device_serial(result$device_serial) &&
                nrow(get_active_ports(result$device_serial)) == 0) {
              ui_ports_after_replacement(result$old_device_serial, result$device_serial)
            }
            
            # A station left behind is recorded as removed. Said before the
            # reviews, since it is part of what just happened rather than
            # something to confirm - its row is terminal.
            if (length(result$removed_stations) > 0) {
              cat("\nRecorded as removed: ",
                  paste(result$removed_stations, collapse = ", "), "\n", sep = "")
            }
            
            #### Metadata review, last ####
            # A companion that traveled has a changed record of its own, and
            # only now - after the move and any port work - is there something
            # complete to confirm.
            # One review: it offers every other station on the same logger,
            # which is every station that moved with it
            ui_prompt_metadata_approval(result$station_id)
            
            # Relocation is terminal - no more work at this location
            break
          } else {
            next
          }
        }
        
        ### Option 7: Station decommissioned
        else if (work_choice == "7") {
          result <- ui_decommission_station()
          
          if (!is.null(result)) {
            # Decommissioning is terminal - station shut down
            cat("\n✓ Station decommissioned\n")
            break
          } else {
            next
          }
        }
        
        ### Option 8: Surveyed elevation of station or logger
        else if (work_choice == "8") {
          # The survey workflows announce their own completion
          result <- ui_survey_elevations()
          # Continue to next iteration (allow more work)
          next
        }
        
        ### Option 9: Correct device details
        else if (work_choice == "9") {
          ui_correct_device_details()
          next
        }
        
        else {
          cat("⚠️  Invalid selection\n")
        }
        
      }  # End sub-loop (work on existing station)
      
    }
    
    ################################################################################
    #### BRANCH 2: ESTABLISHED NEW STATION OR REACTIVATED ####
    ################################################################################
    
    else if (top_choice == "2") {
      
      cat("\n--- NEW/REACTIVATED STATION SETUP ---\n")
      cat("Station setup type:\n")
      cat("  1. Establishing brand new station\n")
      cat("  2. New device at existing active station\n")
      cat("  3. Reactivate decommissioned station\n")
      cat("  q. Back to main menu\n")
      cat("\nEnter selection: ")
      
      new_choice <- trimws(readline())
      
      if (tolower(new_choice) == "q") {
        next  # Back to main menu
      }
      
      ### Options 1 & 2: Add new device
      if (new_choice %in% c("1", "2")) {
        is_new_station <- (new_choice == "1")
        
        # Add device (function handles new vs existing station internally)
        result <- ui_add_device(is_new_station = is_new_station)
        
        if (!is.null(result)) {
          # Check if device is HOBO (no ports needed)
          metadata <- load_zentra_metadata()
          device_row <- get_device_row(result$device_serial,
                                       station_id = result$station_id,
                                       metadata = metadata)
          
          if (is_hobo_device(device_row$mfger)) {
            cat("✓ HOBO device added - no port configuration needed\n")
            
            #### Surveyed elevation ####
            # Only once a station HAS a pair. A single water level logger is a
            # legitimate permanent arrangement - flow can come from a rating
            # curve built on flow-meter measurements instead of a hydraulic
            # slope - so a lone logger is not a half-finished gauge and should
            # not be nagged as one.
            #
            # A pair is different: the elevation difference between the two IS
            # the slope, and until it is surveyed the station produces water
            # levels that cannot become flow. The survey can only run once both
            # rows exist, which is exactly now.
            if (tolower(device_row$station_type) == "hydro") {
              
              station_devices <- get_active_station_devices(device_row$station_id)
              roles <- tolower(station_devices$device_role)
              has_pair <- sum(!is.na(roles) & roles %in% c("primary", "secondary")) >= 2
              needs <- tryCatch(survey_needs(), error = function(e) NULL)
              unsurveyed <- !is.null(needs) &&
                any(needs$unique_id %in% station_devices$unique_id &
                      needs$need %in% c("fall to primary", "reach to primary"))
              
              if (has_pair && unsurveyed) {
                cat("\n--- GUT SURVEY ---\n\n")
                cat("This station now has a primary and a secondary logger. The\n")
                cat("fall and reach between them give the hydraulic slope, and\n")
                cat("until they are surveyed the water levels cannot become flow.\n\n")
                
                do_survey <- ui_yes_no("Do you have the survey data to enter now?",
                                       allow_quit = FALSE)
                
                if (do_survey == "Y") {
                  ui_survey_elevations()
                } else {
                  cat("\nNo problem - record it later with 'Field survey'\n")
                  cat("(option 8) under existing station work.\n")
                }
              }
            }
            
          } else {
            ui_setup_ports_after_add(result)
          }
          
          device_row <- get_device_row(result$device_serial,
                                       station_id = result$station_id)

          # A companion station - the vwc on a weather logger - is offered
          # while the ports are set up, where its sensors first appear

          #### Metadata review, last ####
          # Everything that makes up the record has now been entered - the
          # device, its ports, and any survey. Only now is there a complete
          # record to confirm.
          if (!is.null(device_row)) {
            ui_prompt_metadata_approval(device_row$station_id)
          }
        }
      }
      
      ### Option 3: Reactivate decommissioned station
      else if (new_choice == "3") {
        result <- ui_reactivate_station()
        
        if (!is.null(result)) {
          # ui_reactivate_station() adds the new device
          # Check if device is HOBO (no ports needed)
          metadata <- load_zentra_metadata()
          device_row <- get_device_row(result$device_serial,
                                       station_id = result$station_id,
                                       metadata = metadata)
          
          if (is_hobo_device(device_row$mfger)) {
            cat("✓ HOBO device - no port configuration needed\n")
          } else {
            ui_setup_ports_after_add(result)
          }
          
          #### Metadata review, once the reactivated station is recorded ####
          react_row <- get_device_row(result$device_serial,
                                      station_id = result$station_id)
          if (!is.null(react_row)) {
            ui_prompt_metadata_approval(react_row$station_id)
          }
        }
      }
      
      else {
        cat("⚠️  Invalid selection\n")
      }
      
    }
    
    ################################################################################
    #### BRANCH 3: VIEW METADATA ####
    ################################################################################
    
    else if (top_choice == "3") {
      
      cat("\n--- VIEW ---\n")
      cat("What would you like to see?\n")
      cat("  1. Device metadata\n")
      cat("  2. Port configurations\n")
      cat("  3. Maintenance log\n")
      cat("  4. Download log\n")
      cat("\n")
      cat("  5. Network status - every station and how it is doing\n")
      cat("  6. What needs attention - by kind of work\n")
      cat("  q. Back to main menu\n")
      cat("\nEnter selection: ")
      
      view_choice <- trimws(readline())
      
      if (tolower(view_choice) == "q") {
        next
      }
      
      if (view_choice == "1") {
        ui_view_metadata()
      } else if (view_choice == "2") {
        ui_view_ports()
      } else if (view_choice == "3") {
        ui_view_maintenance_log()
      } else if (view_choice == "4") {
        ui_view_download_log()

      # The two network views. Both ask ZentraCloud for the current state of
      # every device, so they take a few seconds - said in advance, because a
      # console that sits silent looks like it has hung.
      } else if (view_choice == "5") {
        cat("\n  Asking ZentraCloud (a few seconds)...\n")
        flush.console()
        if (exists("print_network_status")) {
          try(print_network_status(), silent = FALSE)
        } else {
          cat("\u26a0\ufe0f  network_status_functions.R is not loaded\n")
        }

      } else if (view_choice == "6") {
        cat("\n  Asking ZentraCloud (a few seconds)...\n")
        flush.console()
        if (exists("print_network_todo")) {
          try(print_network_todo(), silent = FALSE)
        } else {
          cat("\u26a0\ufe0f  network_status_functions.R is not loaded\n")
        }

      } else {
        cat("⚠️  Invalid selection\n")
      }
      
    }
    
    else {
      cat("⚠️  Invalid selection\n")
    }
    
    # After completing any branch, ask if user wants to do more
    # 'q' here means what it means everywhere else: done
    continue_response <- ui_yes_no("\nDo something else? This would return you to main menu.",
                                   allow_quit = TRUE)
    if (continue_response != "Y") {
      return(ui_exit_metadata_manager(entries_at_start))
    }
    
  }  # End main loop
  
}
