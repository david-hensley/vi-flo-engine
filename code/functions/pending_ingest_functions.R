################################################################################
#                        PENDING INGEST FUNCTIONS                              #
#                                                                              #
# Tracks data offloads that have been started but not finished.                #
#                                                                              #
# The point of VI-FLO is that the system remembers, not the person. When a     #
# field download workflow cannot be completed in one sitting - the data is     #
# still on the shuttle, the CSV has not been exported yet - abandoning it      #
# quietly would put the burden of remembering back on a human. That is the     #
# exact failure this system exists to prevent.                                 #
#                                                                              #
# So instead of abandoning, we persist the intent. Nothing is written to the   #
# download log or to last_record_date until the data is genuinely archived,    #
# but a row here records where the workflow stopped, and check_pending()       #
# raises it every time the metadata manager is opened.                         #
#                                                                              #
# This is deliberately NOT a transaction with rollback. Nothing is ever        #
# un-written; writes are simply deferred until they are true.                  #
#                                                                              #
# Requires: wds() from setup_functions.R, load_zentra_metadata() from          #
#           metadata_functions.R                                               #
################################################################################

#### Stage definitions ####
# Ordered. Each represents a point where the human has to go and do something
# before the workflow can continue.
PENDING_STAGES <- c(
  "awaiting_offload",       # data still on the shuttle
  "awaiting_shuttle_drop",  # offloaded, not yet placed in shuttle_readouts
  "awaiting_temp_csv",      # readout in place, CSV not yet exported
  "awaiting_rename",        # temp CSV made, not yet archived
  "awaiting_cloud_upload"   # local Zentra offloaded on site, not yet uploaded
                            # to ZentraCloud - until it is, the data exists
                            # only on the field device
)

PENDING_STAGE_LABELS <- c(
  awaiting_offload      = "data not yet offloaded to computer",
  awaiting_shuttle_drop = "readout folder not yet filed",
  awaiting_temp_csv     = "CSV not yet exported",
  awaiting_rename       = "file not yet archived",
  awaiting_cloud_upload = "not yet uploaded to ZentraCloud"
)

PENDING_COLUMNS <- c(
  "created", "updated", "station_id", "device_serial",
  "field_visit_date", "logged_by", "stage", "notes"
)


#' Loads pending_ingest.csv from metadata/internal
#'
#' Creates an empty file with the correct header if none exists, so callers
#' never have to handle the missing-file case.
#'
#' @return Data.frame. Pending ingests, zero rows if none
load_pending_ingest <- function() {

  pending_file <- file.path(wds("meta_internal"), "pending_ingest.csv")

  if (!file.exists(pending_file)) {
    empty <- as.data.frame(
      matrix(character(0), ncol = length(PENDING_COLUMNS),
             dimnames = list(NULL, PENDING_COLUMNS)),
      stringsAsFactors = FALSE
    )
    write.csv(empty, pending_file, row.names = FALSE)
    return(empty)
  }

  pending <- read.csv(pending_file, stringsAsFactors = FALSE,
                      colClasses = "character")

  # Drop any fully blank rows - these creep in when a CSV is opened and
  # saved in Excel.
  if (nrow(pending) > 0) {
    blank <- apply(pending, 1, function(r) all(is.na(r) | trimws(r) == ""))
    pending <- pending[!blank, , drop = FALSE]
  }

  return(pending)
}


#' Writes the pending ingest table back to disk
#'
#' @param pending Data.frame. Full table to write
#' @return Invisible TRUE
write_pending_ingest <- function(pending) {

  pending_file <- file.path(wds("meta_internal"), "pending_ingest.csv")

  missing <- setdiff(PENDING_COLUMNS, names(pending))
  if (length(missing) > 0) {
    stop("Pending ingest table is missing columns: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  write.csv(pending[, PENDING_COLUMNS, drop = FALSE], pending_file,
            row.names = FALSE)
  invisible(TRUE)
}


#' Records a data offload that has been started but not completed
#'
#' If a pending row already exists for this station and device, it is updated
#' rather than duplicated - a station can only have one offload in flight.
#'
#' @param station_id Character. Station ID
#' @param device_serial Character. Device serial number
#' @param field_visit_date Date or character. Date of the field visit
#' @param logged_by Character. Initials of the person logging
#' @param stage Character. One of PENDING_STAGES
#' @param notes Character. Optional free text
#' @return Invisible TRUE
add_pending_ingest <- function(station_id, device_serial, field_visit_date,
                               logged_by, stage, notes = "") {

  if (!stage %in% PENDING_STAGES) {
    stop("Unknown stage '", stage, "'. Must be one of: ",
         paste(PENDING_STAGES, collapse = ", "), call. = FALSE)
  }

  pending <- load_pending_ingest()
  now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  new_row <- data.frame(
    created          = now,
    updated          = now,
    station_id       = as.character(station_id),
    device_serial    = as.character(device_serial),
    field_visit_date = format(as.Date(field_visit_date), "%Y-%m-%d"),
    logged_by        = as.character(logged_by),
    stage            = stage,
    notes            = as.character(notes),
    stringsAsFactors = FALSE
  )

  # One in-flight offload per station+device
  existing <- which(pending$station_id == station_id &
                    pending$device_serial == device_serial)

  if (length(existing) > 0) {
    new_row$created <- pending$created[existing[1]]   # keep original start
    pending <- pending[-existing, , drop = FALSE]
  }

  pending <- rbind(pending, new_row)
  write_pending_ingest(pending)

  invisible(TRUE)
}


#' Moves a pending ingest to a later stage
#'
#' @param station_id Character. Station ID
#' @param device_serial Character. Device serial number
#' @param stage Character. New stage, one of PENDING_STAGES
#' @param notes Character. Optional replacement notes
#' @return Invisible TRUE if a row was updated, FALSE if none matched
update_pending_stage <- function(station_id, device_serial, stage, notes = NULL) {

  if (!stage %in% PENDING_STAGES) {
    stop("Unknown stage '", stage, "'. Must be one of: ",
         paste(PENDING_STAGES, collapse = ", "), call. = FALSE)
  }

  pending <- load_pending_ingest()
  idx <- which(pending$station_id == station_id &
               pending$device_serial == device_serial)

  if (length(idx) == 0) return(invisible(FALSE))

  pending$stage[idx]   <- stage
  pending$updated[idx] <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  if (!is.null(notes)) pending$notes[idx] <- notes

  write_pending_ingest(pending)
  invisible(TRUE)
}


#' Removes a pending ingest, on successful completion or abandonment
#'
#' @param station_id Character. Station ID
#' @param device_serial Character. Device serial number
#' @return Invisible TRUE if a row was removed, FALSE if none matched
clear_pending_ingest <- function(station_id, device_serial) {

  pending <- load_pending_ingest()
  idx <- which(pending$station_id == station_id &
               pending$device_serial == device_serial)

  if (length(idx) == 0) return(invisible(FALSE))

  pending <- pending[-idx, , drop = FALSE]
  write_pending_ingest(pending)
  invisible(TRUE)
}


#' Displays outstanding data offloads
#'
#' Intended to run at the top of the metadata manager menu, every time. The
#' whole value is that it is unmissable and requires no one to remember to ask.
#'
#' Items are flagged by age: anything over `stale_days` old is called out
#' louder, because an offload left for a month is data at risk.
#'
#' @param stale_days Numeric. Age in days past which an item is flagged (14)
#' @param verbose Logical. Print the summary (default TRUE)
#' @return Invisible data frame of pending items, zero rows if none
check_pending <- function(stale_days = 14, verbose = TRUE) {

  pending <- load_pending_ingest()

  if (nrow(pending) == 0) return(invisible(pending))

  visit <- as.Date(pending$field_visit_date)
  age   <- as.numeric(Sys.Date() - visit)

  if (verbose) {
    cat("\n")
    cat("!! ", nrow(pending), " unfinished data task",
        ifelse(nrow(pending) == 1, "", "s"), ":\n", sep = "")

    for (i in seq_len(nrow(pending))) {
      label <- PENDING_STAGE_LABELS[pending$stage[i]]
      if (is.na(label)) label <- pending$stage[i]

      flag <- if (!is.na(age[i]) && age[i] > stale_days) "  <-- STALE" else ""

      cat("   ", format(pending$station_id[i], width = 14),
          " visited ", pending$field_visit_date[i],
          " (", age[i], " days ago)",
          " - ", label, flag, "\n", sep = "")
    }

    if (any(!is.na(age) & age > stale_days)) {
      cat("\n   Data that has not reached the archive - still on a logger, a\n")
      cat("   shuttle, a field device, or an unexported file - is data at\n")
      cat("   risk of being lost, overwritten, or filled by a redeployment.\n")
    }
    cat("\n")
  }

  invisible(pending)
}
