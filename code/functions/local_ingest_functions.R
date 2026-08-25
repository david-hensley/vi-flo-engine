################################################################################
#                        LOCAL DATA INGEST FUNCTIONS                           #
#                                                                              #
# Brings manually-offloaded data into the archive: data pulled off a HOBO       #
# logger by shuttle, or off a local Zentra by hand, rather than through the    #
# ZentraCloud API.                                                             #
#                                                                              #
# The workflow is deliberately transactional at the end rather than the        #
# start. maintenance_log, last_visit and last_download_date record what        #
# happened in the FIELD and are written immediately - they stay true whether   #
# or not the file ever reaches the archive. download_log and last_record_date  #
# assert something about the ARCHIVE, and are written only once the data is    #
# genuinely in it.                                                             #
#                                                                              #
# If the user cannot finish, nothing is abandoned - a pending_ingest row       #
# records the stage reached and check_pending() raises it every time the       #
# metadata manager opens. The system remembers, not the person.                #
#                                                                              #
# Requires: setup_functions.R, metadata_functions.R, file_naming_functions.R,  #
#           pending_ingest_functions.R, metadata_manager_functions.R           #
################################################################################

################################################################################
#                                                                              #
#   >>>>>  USER-FACING INSTRUCTION TEXT - EDIT THE BLOCKS BELOW  <<<<<         #
#                                                                              #
#   Everything between the ===== EDIT ===== banners is text shown to the       #
#   person doing the work. Rewrite freely. Anything in {curly braces} is       #
#   substituted at runtime - keep those tokens intact.                         #
#                                                                              #
#   Available tokens:                                                          #
#     {shuttle_dir}   absolute path to the shuttle readout folder              #
#     {raw_dir}       absolute path to the raw data folder for this type       #
#     {temp_file}     temporary filename the export must be saved as           #
#     {station_id}    station being worked on, e.g. sr1_hydro                  #
#                                                                              #
################################################################################

##### ===== EDIT: HOBO EXPORT INSTRUCTIONS ===== #####
HOBO_EXPORT_INSTRUCTIONS <- "
To proceed, you must export raw .hobo files from the shuttle to CSV.
Follow these steps:

1. Navigate to the raw shuttle folder here:

     {shuttle_dir}

2. Open it and find the .hobo file corresponding to this download
3. Double click the correct .hobo file to open it in HOBOware
4. A pop-up called 'Plot Setup' appears. You must UNCHECK all the 'events'
   under 'Select internal logger events to plot'. Change nothing else.
5. When this is done, press 'Plot'
6. You will see a plot of the data on the screen. Now we export it:
   File > Export Table Data
7. A pop-up window appears, change nothing and press 'Export'
8. Navigate to:

     {raw_dir}

   and name the file:

     {temp_file}

   then press 'Save'
"
##### ===== END EDIT ===== #####


##### ===== EDIT: LOCAL ZENTRA EXPORT INSTRUCTIONS ===== #####
# PLACEHOLDER - written generically until a real local Zentra file is in hand.
ZENTRA_LOCAL_EXPORT_INSTRUCTIONS <- "
To proceed, you must transfer the data file off the device and save it as CSV.
Follow these steps:

1. Connect the download cable to the logger and transfer the data file to
   this computer
2. If the file is not already a CSV, open it and save or export it as CSV
3. Save the file here:

     {raw_dir}

   and name it:

     {temp_file}

   then press 'Save'
"
##### ===== END EDIT ===== #####


##### ===== EDIT: OFFLOAD GATE PROMPTS ===== #####
HOBO_OFFLOAD_GATE <- "
Before this download can be archived, the shuttle readout must be offloaded
from the shuttle onto this computer.

Has the data been offloaded from the shuttle to this computer?"

ZENTRA_OFFLOAD_GATE <- "
Before this download can be archived, the data must be off the logger and
onto this computer.

Has the data been transferred from the logger to this computer?"
##### ===== END EDIT ===== #####


##### ===== EDIT: OFFLOAD NOT DONE - WHERE IT GOES ===== #####
HOBO_OFFLOAD_DIRECTIONS <- "
Offload the shuttle readout to this computer, placing the readout folder
here:

     {shuttle_dir}

Then run this download again to continue.
"

ZENTRA_OFFLOAD_DIRECTIONS <- "
Connect the download cable and transfer the data file to this computer,
saving it here:

     {raw_dir}

Then run this download again to continue.
"
##### ===== END EDIT ===== #####


#' Substitutes {tokens} in an instruction block
#' @param template Character. Text containing {tokens}
#' @param ... Named values to substitute
#' @return Character. Text with tokens replaced
fill_instructions <- function(template, ...) {
  values <- list(...)
  out <- template
  for (nm in names(values)) {
    out <- gsub(paste0("\\{", nm, "\\}"), values[[nm]], out, fixed = FALSE)
  }
  out
}


#' Resolves the raw data directory for a station
#' @param station_type Character. e.g. "hydro", "vwc"
#' @return Character. Absolute path
get_raw_dir <- function(station_type) {
  wds(paste0("internal_raw_", station_type))
}


#' Resolves the shuttle readout folder
#'
#' A fixed subfolder of the hydro raw directory. Deliberately NOT a named path
#' in the datamap - it is dumb storage that only humans interact with, and a
#' fixed subfolder of an already-mapped location should be derived, not
#' configured.
#'
#' @return Character. Absolute path
get_shuttle_dir <- function() {
  file.path(wds("internal_raw_hydro"), "shuttle_readouts")
}


#' Finds the most recently modified file in the data root
#'
#' Used only when an expected export cannot be found, to help the user locate
#' whatever they actually saved.
#'
#' The `since` anchor is what makes this trustworthy. It is set when the export
#' instructions are displayed, and the workflow then blocks on user input, so
#' nothing machine-generated can land in the data root during the wait.
#' Anything newer than the anchor is therefore the user's doing. Without it,
#' the newest file would often be pending_ingest.csv or a metadata backup -
#' and pointing a user at those under a "you may want to delete this" heading
#' would be actively dangerous.
#'
#' @param since POSIXct. Only consider files modified after this moment
#' @param exclude Character vector. Filenames never reported as candidates
#' @return Data frame with path and mtime, zero rows if nothing qualifies
find_recent_file_in_data_root <- function(since,
                                          exclude = c("pending_ingest.csv")) {

  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (!nzchar(data_root) || !dir.exists(data_root)) {
    return(data.frame(path = character(0), mtime = character(0),
                      stringsAsFactors = FALSE))
  }

  all_files <- list.files(data_root, recursive = TRUE, full.names = TRUE,
                          all.files = FALSE, no.. = TRUE)

  if (length(all_files) == 0) {
    return(data.frame(path = character(0), mtime = character(0),
                      stringsAsFactors = FALSE))
  }

  # Files the workflow itself writes are never candidates
  keep <- !(basename(all_files) %in% exclude)
  # Metadata backups are machine-generated by definition
  keep <- keep & !grepl("[/\\\\]backups[/\\\\]", all_files)
  all_files <- all_files[keep]

  if (length(all_files) == 0) {
    return(data.frame(path = character(0), mtime = character(0),
                      stringsAsFactors = FALSE))
  }

  info <- file.info(all_files)
  recent <- info$mtime > since & !is.na(info$mtime)

  if (!any(recent)) {
    return(data.frame(path = character(0), mtime = character(0),
                      stringsAsFactors = FALSE))
  }

  hits <- all_files[recent]
  times <- info$mtime[recent]
  ord <- order(times, decreasing = TRUE)

  data.frame(
    path = hits[ord],
    mtime = format(times[ord], "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )
}


#' Reads an exported CSV and extracts its date range
#'
#' Column names are DETECTED, not assumed. Onset changed its export format
#' when it moved to the LI-COR platform - column names differ and the serial
#' number may be absent - and any file may have been opened in Excel on the
#' way here, which rewrites datetimes into the local format.
#'
#' @param filepath Character. Path to the CSV
#' @param tz Character. Timezone for parsing
#' @return List with data, start, end, n_records - or NULL with a message on
#'   failure
read_exported_csv <- function(filepath, tz = NULL) {

  if (is.null(tz)) {
    metadata <- load_zentra_metadata()
    tz <- metadata$timezone[1]
  }

  data <- tryCatch(
    read.csv(filepath, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) NULL
  )

  if (is.null(data) || nrow(data) == 0) {
    cat("\n  X Could not read the file, or it contains no rows.\n")
    return(NULL)
  }

  #### Find the datetime column ####
  # Try by name first, then fall back to whichever column parses as dates.
  datetime_col <- NULL
  name_patterns <- c("date.*time", "^date$", "^time$", "timestamp", "^#?\\s*$")

  for (pattern in name_patterns) {
    hits <- grep(pattern, names(data), ignore.case = TRUE)
    if (length(hits) > 0) {
      datetime_col <- hits[1]
      break
    }
  }

  if (is.null(datetime_col)) {
    # No recognisable name - try parsing each column and take the first that
    # yields dates for most rows.
    for (i in seq_along(data)) {
      attempt <- suppressWarnings(
        tryCatch(coerce_datetime_flexible(data[[i]][1:min(20, nrow(data))], tz),
                 error = function(e) NULL)
      )
      if (!is.null(attempt) && sum(!is.na(attempt)) > 15) {
        datetime_col <- i
        break
      }
    }
  }

  if (is.null(datetime_col)) {
    cat("\n  X Could not identify a date/time column in this file.\n")
    cat("    Columns found: ", paste(names(data), collapse = ", "), "\n", sep = "")
    return(NULL)
  }

  #### Parse it ####
  parsed <- tryCatch(
    coerce_datetime_flexible(data[[datetime_col]], tz),
    error = function(e) {
      cat("\n  X Could not parse the date column '",
          names(data)[datetime_col], "':\n    ", conditionMessage(e), "\n", sep = "")
      NULL
    }
  )

  if (is.null(parsed)) return(NULL)

  valid <- parsed[!is.na(parsed)]
  if (length(valid) == 0) {
    cat("\n  X The date column contained no readable dates.\n")
    return(NULL)
  }

  list(
    data = data,
    datetime_col = names(data)[datetime_col],
    start = min(valid),
    end = max(valid),
    n_records = nrow(data)
  )
}


#' Interactive local data ingest workflow
#'
#' Called at the end of ui_log_download() for devices whose data is offloaded
#' by hand. Can also be called directly to resume a pending ingest.
#'
#' @param station_id Character. Station being ingested
#' @param device_serial Character. Device serial number
#' @param station_type Character. e.g. "hydro", "vwc"
#' @param mfger Character. Manufacturer, decides which instructions to show
#' @param field_visit_date Date. Date of the field visit
#' @param logged_by Character. Initials
#' @param resume_stage Character. Stage to resume at, or NULL to start fresh
#' @return TRUE if data was archived, FALSE if deferred, NULL if quit
ui_ingest_local_data <- function(station_id, device_serial, station_type,
                                 mfger, field_visit_date, logged_by,
                                 resume_stage = NULL) {

  cat("\n============================================\n")
  cat("  Archive Downloaded Data\n")
  cat("============================================\n\n")
  cat("Station: ", station_id, "\n", sep = "")
  cat("Device:  ", device_serial, "\n\n", sep = "")

  #### Resolve paths ####
  raw_dir     <- get_raw_dir(station_type)
  shuttle_dir <- get_shuttle_dir()
  temp_file   <- paste0(station_id, "_raw_temp.csv")
  temp_path   <- file.path(raw_dir, temp_file)

  if (!dir.exists(raw_dir)) dir.create(raw_dir, recursive = TRUE)

  #### Which instruction set ####
  is_hobo <- tolower(mfger) %in% c("onset", "hobo")
  instructions <- if (is_hobo) HOBO_EXPORT_INSTRUCTIONS else
                                ZENTRA_LOCAL_EXPORT_INSTRUCTIONS

  #### Stage 1 - offload gate ####
  if (is.null(resume_stage) || resume_stage == "awaiting_offload") {

    gate <- if (is_hobo) HOBO_OFFLOAD_GATE else ZENTRA_OFFLOAD_GATE

    offloaded <- ui_yes_no(gate)
    if (offloaded == "Q") return(invisible(NULL))

    if (offloaded == "N") {
      directions <- if (is_hobo) HOBO_OFFLOAD_DIRECTIONS else
                                 ZENTRA_OFFLOAD_DIRECTIONS

      if (is_hobo && !dir.exists(shuttle_dir)) {
        dir.create(shuttle_dir, recursive = TRUE)
      }

      cat(fill_instructions(directions,
                            shuttle_dir = shuttle_dir,
                            raw_dir     = raw_dir))

      add_pending_ingest(station_id, device_serial, field_visit_date,
                         logged_by, "awaiting_offload",
                         notes = "Data not yet offloaded from logger")

      cat("This download has been recorded as unfinished. You will be\n")
      cat("reminded every time you open the metadata manager.\n\n")
      cat("Nothing has been written to the download log - that happens only\n")
      cat("once the data is genuinely archived.\n\n")
      return(invisible(FALSE))
    }

    #### Stage 2 - shuttle drop (HOBO only) ####
    if (is_hobo) {
      if (!dir.exists(shuttle_dir)) dir.create(shuttle_dir, recursive = TRUE)

      cat("\nThe shuttle readout folder belongs here:\n\n")
      cat("     ", shuttle_dir, "\n\n", sep = "")

      dropped <- ui_yes_no("Can you confirm the readout folder is there?")
      if (dropped == "Q") return(invisible(NULL))

      if (dropped == "N") {
        add_pending_ingest(station_id, device_serial, field_visit_date,
                           logged_by, "awaiting_shuttle_drop",
                           notes = "Readout folder not yet filed")
        cat("\nRecorded as unfinished. You will be reminded.\n\n")
        return(invisible(FALSE))
      }
    }
  }

  #### Stage 3 - export loop ####
  repeat {

    cat(fill_instructions(instructions,
                          shuttle_dir = shuttle_dir,
                          raw_dir     = raw_dir,
                          temp_file   = temp_file,
                          station_id  = station_id))
    cat("\n")

    # Anchor: nothing machine-generated lands in the data root while we wait
    # here, so anything newer than this is the user's own save.
    anchor <- Sys.time()

    cat("When you have saved the file, press ENTER.\n")
    readline()

    #### Scan for it ####
    if (file.exists(temp_path)) break

    #### Not found ####
    cat("\n--------------------------------------------\n")
    cat("Could not find the expected file:\n\n")
    cat("     ", temp_path, "\n\n", sep = "")

    candidates <- find_recent_file_in_data_root(anchor)

    if (nrow(candidates) == 0) {
      cat("No file appears to have been saved anywhere in the data root\n")
      cat("since these instructions were shown. It looks like the export\n")
      cat("did not complete.\n\n")
    } else {
      cat("The most recently modified file in the data root is:\n\n")
      cat("     ", candidates$path[1], "\n", sep = "")
      cat("     modified ", candidates$mtime[1], "\n\n", sep = "")
      cat("This MAY be the file you just exported - or it may be unrelated.\n")
      cat("Check the path and timestamp against what you actually saved.\n")
      cat("Do not delete it unless you are certain it is yours.\n\n")
      cat("Stray files in the data tree cause confusion later, and a\n")
      cat("half-named export can be mistaken for real archived data.\n\n")
    }

    cat("  1. Retry the scan (I'll deal with the file myself)\n")
    cat("  2. Stop here and finish later\n\n")

    choice <- trimws(readline("Choose (1-2): "))

    if (choice == "2") {
      add_pending_ingest(station_id, device_serial, field_visit_date,
                         logged_by, "awaiting_temp_csv",
                         notes = "Export not completed")
      cat("\nRecorded as unfinished. You will be reminded.\n\n")
      return(invisible(FALSE))
    }
  }

  #### Stage 4 - read and confirm ####
  repeat {

    parsed <- read_exported_csv(temp_path)

    if (is.null(parsed)) {
      cat("\n  1. Try the export again\n")
      cat("  2. Stop here and finish later\n\n")
      choice <- trimws(readline("Choose (1-2): "))
      if (choice == "2") {
        add_pending_ingest(station_id, device_serial, field_visit_date,
                           logged_by, "awaiting_temp_csv",
                           notes = "Exported file could not be read")
        return(invisible(FALSE))
      }
      file.remove(temp_path)
      return(invisible(ui_ingest_local_data(station_id, device_serial, station_type,
                                  mfger, field_visit_date, logged_by,
                                  resume_stage = "awaiting_temp_csv")))
    }

    final_name <- build_raw_filename(station_id, parsed$start, parsed$end,
                                     ext = "rds")

    cat("\n--------------------------------------------\n")
    cat("Read ", temp_file, "\n\n", sep = "")
    cat("  Station:       ", station_id, "\n", sep = "")
    cat("  Date column:   ", parsed$datetime_col, "\n", sep = "")
    cat("  First record:  ", format(parsed$start, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    cat("  Last record:   ", format(parsed$end,   "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    cat("  Records:       ", format(parsed$n_records, big.mark = ","), "\n\n", sep = "")

    check_raw_overlap(station_id, parsed$start, parsed$end, dir = raw_dir)

    cat("Proposed filename:\n")
    cat("     ", final_name, "\n\n", sep = "")

    confirmed <- ui_yes_no("Does this look correct?")
    if (confirmed == "Q") return(invisible(NULL))

    if (confirmed == "Y") break

    #### Not correct - most likely the wrong .hobo file was opened ####
    cat("\nIf the dates are wrong, the most likely cause is that a different\n")
    cat("logger's file was opened in HOBOware.\n\n")
    cat("  1. Delete this export and try again\n")
    cat("  2. Stop here and finish later\n\n")

    choice <- trimws(readline("Choose (1-2): "))

    if (choice == "2") {
      add_pending_ingest(station_id, device_serial, field_visit_date,
                         logged_by, "awaiting_temp_csv",
                         notes = "Export produced unexpected date range")
      cat("\nRecorded as unfinished. The temporary file has been left in\n")
      cat("place at:\n     ", temp_path, "\n\n", sep = "")
      return(invisible(FALSE))
    }

    file.remove(temp_path)
    return(invisible(ui_ingest_local_data(station_id, device_serial, station_type,
                                mfger, field_visit_date, logged_by,
                                resume_stage = "awaiting_temp_csv")))
  }

  #### Stage 5 - hand off to the non-interactive writer ####
  result <- archive_local_data(
    station_id    = station_id,
    device_serial = device_serial,
    csv_path      = temp_path,
    parsed        = parsed,
    final_name    = final_name,
    raw_dir       = raw_dir
  )

  if (!isTRUE(result$success)) {
    cat("\n  X ", result$message, "\n", sep = "")
    add_pending_ingest(station_id, device_serial, field_visit_date,
                       logged_by, "awaiting_rename",
                       notes = result$message)
    cat("\nRecorded as unfinished. You will be reminded.\n\n")
    return(invisible(FALSE))
  }

  for (line in result$messages) cat("+ ", line, "\n", sep = "")
  for (line in result$warnings) cat("!  ", line, "\n", sep = "")

  cat("\n+ Data archived.\n\n")
  return(invisible(TRUE))
}


#' Archives an exported data file - no prompting, no console dependency
#'
#' The writing half of the local ingest workflow, deliberately separated from
#' the interactive half so a future GUI can call it directly rather than
#' reimplementing it. Takes values, returns a result; never asks a question.
#'
#' Order matters here. The RDS is written first and confirmed on disk before
#' the CSV is deleted, so a failure never destroys the only copy. The
#' archive-asserting writes - download_log and last_record_date - come last,
#' once the file is genuinely in the archive and the claim is true.
#'
#' @param station_id Character. Station ID
#' @param device_serial Character. Device serial number
#' @param csv_path Character. Path to the exported CSV to archive
#' @param parsed List. Output of read_exported_csv()
#' @param final_name Character. Filename from build_raw_filename()
#' @param raw_dir Character. Directory to archive into
#' @return List with success (logical), message (character), messages and
#'   warnings (character vectors for the caller to display)
archive_local_data <- function(station_id, device_serial, csv_path, parsed,
                               final_name, raw_dir) {

  messages <- character(0)
  warnings <- character(0)

  final_path <- file.path(raw_dir, final_name)

  #### Write the RDS ####
  saved <- tryCatch({
    saveRDS(parsed$data, final_path)
    TRUE
  }, error = function(e) {
    conditionMessage(e)
  })

  if (!isTRUE(saved)) {
    return(list(success = FALSE,
                message = paste0("Could not save the RDS file: ", saved),
                messages = messages, warnings = warnings))
  }

  if (!file.exists(final_path)) {
    return(list(success = FALSE,
                message = "RDS file was not found on disk after writing",
                messages = messages, warnings = warnings))
  }

  messages <- c(messages, paste0("Saved: ", final_name))

  #### Only now is it safe to remove the CSV ####
  if (file.exists(csv_path)) {
    file.remove(csv_path)
    messages <- c(messages, "Removed temporary CSV")
  }

  #### Archive-asserting writes ####
  filepath_relative <- sub(paste0("^", Sys.getenv("VI_FLO_DATA_ROOT"), "/?"),
                           "", final_path)
  filepath_relative <- sub("^/", "", filepath_relative)

  log_entry <- data.frame(
    timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    station       = station_id,
    start_date    = format(parsed$start, "%Y-%m-%d %H:%M:%S"),
    end_date      = format(parsed$end,   "%Y-%m-%d %H:%M:%S"),
    n_records     = parsed$n_records,
    filepath      = filepath_relative,
    download_type = "manual",
    stringsAsFactors = FALSE
  )

  log_file <- file.path(wds("meta_internal"), "download_log.csv")

  logged <- tryCatch({
    if (file.exists(log_file)) {
      write.table(log_entry, log_file, sep = ",", append = TRUE,
                  col.names = FALSE, row.names = FALSE, qmethod = "double")
    } else {
      write.csv(log_entry, log_file, row.names = FALSE)
    }
    TRUE
  }, error = function(e) conditionMessage(e))

  if (isTRUE(logged)) {
    messages <- c(messages, "Logged to download_log.csv (manual)")
  } else {
    warnings <- c(warnings, paste0("Could not write download log: ", logged))
  }

  result <- update_last_record_date(device_serial, parsed$end)
  if (isTRUE(result)) {
    messages <- c(messages, "Updated last_record_date")
  } else {
    warnings <- c(warnings, paste0("Could not update last_record_date: ", result))
  }

  #### Clear the pending row - the workflow is complete ####
  clear_pending_ingest(station_id, device_serial)

  list(success = TRUE, message = "Data archived",
       messages = messages, warnings = warnings)
}


#' Updates last_record_date for a device
#'
#' last_record_date is the timestamp of the last actual observation now held in
#' the archive - distinct from last_download_date, which records when someone
#' went and pulled data, and from last_update, which records remote contact and
#' is NA for local devices by design.
#'
#' Comparing last_record_date against last_visit is how gap detection works for
#' local devices: a logger that died three weeks before the visit shows records
#' ending well before the visit date.
#'
#' Modelled on update_last_download_date() in metadata_manager_functions.R.
#'
#' @param device_serial Character. Device to update
#' @param record_datetime POSIXct. Timestamp of the last record archived
#' @return TRUE if successful, error message string if failed
update_last_record_date <- function(device_serial, record_datetime) {
  tryCatch({
    metadata <- load_zentra_metadata()
    device_index <- which(metadata$device_serial == device_serial)

    if (length(device_index) == 0) {
      return("Device not found in metadata")
    }

    if (!"last_record_date" %in% names(metadata)) {
      return("last_record_date column not present in device_metadata.csv")
    }

    metadata$last_record_date[device_index] <- record_datetime

    setwd(wds("meta_internal"))
    metadata$deploy_datetime    <- format_datetime_safe(metadata$deploy_datetime)
    metadata$last_update        <- format_datetime_safe(metadata$last_update)
    metadata$last_download_date <- format_datetime_safe(metadata$last_download_date)
    metadata$last_record_date   <- format_datetime_safe(metadata$last_record_date)
    metadata$last_visit         <- as.character(metadata$last_visit)
    if ("expiry_date" %in% names(metadata)) {
      metadata$expiry_date <- as.character(metadata$expiry_date)
    }

    write.csv(metadata, "device_metadata.csv", row.names = FALSE)
    return(TRUE)
  }, error = function(e) {
    return(paste0("Failed to update last_record_date: ", e$message))
  })
}
