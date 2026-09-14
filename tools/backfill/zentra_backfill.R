# VI-FLO: ZentraCloud backfill
#
# Downloads everything available for every device in the ZentraCloud account,
# naively, without reference to VI-FLO metadata. Attribution to stations is a
# separate, later step - a device may have served several stations over five
# years, and the API knows nothing about that.
#
# Files land in internal/raw/zentra-backfill/ named by SERIAL and YEAR:
#
#     z6-13366_2021_raw.rds
#
# Each holds exactly what getReadings() returned - a list of six tibbles, one
# per port, with every value, error_flag and error_description column intact.
# Nothing is flattened, dropped or interpreted.
#
#
# WHY IT ROTATES BETWEEN DEVICES
#
# ZentraCloud allows 60 calls per minute per account, but only ONE PER MINUTE
# PER DEVICE. Downloading a device's whole history before moving to the next
# means waiting a minute between every page:
#
#     sequential:  ~225 hours
#     rotated:     ~8-19 hours
#
# So the queue is ordered by window, not by device: one window for each device
# in turn, then the next window for each. Cycling 37 devices takes longer than
# a minute on its own, so the per-device limit is never reached and no throttle
# wait ever happens.
#
# Windows are sized to fit in a single API page (~500 records), so each call
# returns promptly rather than paginating internally and blocking the rotation.
#
#
# RESUMING
#
# A device-year already on disk is skipped. Interrupt it, re-run it, and it
# picks up where it stopped, losing at most the year in progress. The package's
# own cache absorbs some of even that.
#
# Every call is recorded in zentra_backfill_log.csv - device, window, records,
# outcome - so a partial run can be audited rather than guessed at.
#
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   setup_zentracloud("ZENTRACLOUD_TOKEN")
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/backfill/zentra_backfill.R"))
#
#   zentra_backfill()                      # everything, all devices
#   zentra_backfill(devices = "z6-13366")  # one device
#   zentra_backfill(dry_run = TRUE)        # plan only, no calls


################################################################################
#  ===== EDIT: DEVICE LIST =====                                               #
#                                                                              #
#  Every device serial in the ZentraCloud account, transcribed from the        #
#  dashboard. The API is addressed by serial and cannot list an account's      #
#  devices, so this is the only enumeration there is.                          #
#                                                                              #
#  Add new serials here as loggers come online. Re-running picks them up.      #
################################################################################

ZENTRA_BACKFILL_DEVICES <- c(
  # --- in VI-FLO metadata ---
  "z6-12866",  # Glynn weather
  "z6-12874",  # Turpentine weather
  "z6-12885",  # Dorothea weather
  "z6-12893",  # sr1 streambank
  "z6-12898",  # sr2-hs v2
  "z6-13363",  # sr2 streambank
  "z6-13366",  # sr1 hillside
  "z6-13368",  # UVI campus weather
  "z6-13375",  # Fish Bay weather
  "z6-13376",  # vwc3
  "z6-13379",  # Fish Bay
  "z6-13388",  # sr2 hillside
  "z6-13391",  # reference pit
  "z6-14625",  # vwc2
  "z6-14635",  # Discovery Garden weather
  "z6-14637",  # R2R farm
  "z6-14640",  # r4 soil moisture
  "z6-34718",  # La Grange
  "z6-35061",  # ET1
  "z6-35227",  # ET3
  "z6-35228",  # ET2
  "z6-37439",  # Cal1 weather
  "z6-38174",  # sr1 sb vwc
  "z6-38175",  # sr2 sb vwc

  # --- in the cloud but not in VI-FLO metadata ---
  "z6-13365",  # near southeast
  "z6-14269",  # 30% aluminate
  "z6-13383",  # shadehouses
  "z6-21546",  # shadehouses
  "z6-21547",  # shadehouses
  "z6-30028",  # shadehouses
  "z6-30029",  # shadehouses
  "z6-30129",  # shadehouses
  "z6-30130",  # shadehouses
  "z6-30131",  # shadehouses
  "z6-30132",  # shadehouses
  "z6-30133",  # shadehouses
  "z6-30134"   # shadehouses
)

# Earliest deployment in the network. Nothing predates this.
ZENTRA_BACKFILL_START <- "2021-07-01"

# Days per request. Sized to return in one API page so the call comes back
# promptly and the rotation keeps moving. Larger windows paginate internally,
# which blocks the rotation and costs a minute per extra page.
ZENTRA_BACKFILL_WINDOW_DAYS <- 5

################################################################################
#  ===== END EDIT =====                                                        #
################################################################################


#' Directory the backfill writes to
zentra_backfill_dir <- function() {
  d <- file.path(wds("internal_raw_vwc"), "..", "zentra-backfill")
  d <- normalizePath(d, mustWork = FALSE)
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}


#' Path for one device-year
zentra_backfill_file <- function(device_sn, year) {
  file.path(zentra_backfill_dir(),
            paste0(device_sn, "_", year, "_raw.rds"))
}


#' Appends one line to the call log
zentra_backfill_log <- function(device_sn, start, end, n_records, outcome, note = "") {
  logfile <- file.path(zentra_backfill_dir(), "zentra_backfill_log.csv")

  row <- data.frame(
    timestamp  = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    device_sn  = device_sn,
    start_time = format(start, "%Y-%m-%d %H:%M:%S"),
    end_time   = format(end,   "%Y-%m-%d %H:%M:%S"),
    n_records  = n_records,
    outcome    = outcome,
    note       = note,
    stringsAsFactors = FALSE
  )

  write.table(row, logfile, sep = ",", row.names = FALSE,
              col.names = !file.exists(logfile),
              append = file.exists(logfile), qmethod = "double")
}


#' Builds the list of windows for one year
zentra_year_windows <- function(year, window_days, overall_start, overall_end) {
  y_start <- max(as.POSIXct(paste0(year, "-01-01 00:00:00"), tz = "UTC"),
                 overall_start)
  y_end   <- min(as.POSIXct(paste0(year, "-12-31 23:59:59"), tz = "UTC"),
                 overall_end)

  if (y_start >= y_end) return(list())

  starts <- seq(y_start, y_end, by = paste(window_days, "days"))
  lapply(starts, function(s) {
    list(start = s, end = min(s + window_days * 86400, y_end))
  })
}


#' Downloads everything available for every device
#'
#' @param devices Character vector of serials (default: all)
#' @param start_date Character. Earliest date to attempt
#' @param end_date Character. Latest date (default: now)
#' @param window_days Numeric. Days per request
#' @param dry_run Logical. Report the plan without calling the API
#' @return Invisible TRUE
zentra_backfill <- function(devices     = ZENTRA_BACKFILL_DEVICES,
                            start_date  = ZENTRA_BACKFILL_START,
                            end_date    = NULL,
                            window_days = ZENTRA_BACKFILL_WINDOW_DAYS,
                            dry_run     = FALSE) {

  if (!requireNamespace("zentracloud", quietly = TRUE)) {
    stop("zentracloud package not available - run setup_zentracloud() first",
         call. = FALSE)
  }

  overall_start <- as.POSIXct(paste(start_date, "00:00:00"), tz = "UTC")
  overall_end   <- if (is.null(end_date)) Sys.time() else
                     as.POSIXct(paste(end_date, "23:59:59"), tz = "UTC")

  years <- seq(as.integer(format(overall_start, "%Y")),
               as.integer(format(overall_end,   "%Y")))

  cat("\n============================================\n")
  cat("  ZentraCloud backfill\n")
  if (dry_run) cat("  DRY RUN - no API calls will be made\n")
  cat("============================================\n\n")
  cat("Devices:     ", length(devices), "\n", sep = "")
  cat("Period:      ", format(overall_start, "%Y-%m-%d"), " to ",
      format(overall_end, "%Y-%m-%d"), "\n", sep = "")
  cat("Window:      ", window_days, " days per request\n", sep = "")
  cat("Destination: ", zentra_backfill_dir(), "\n\n", sep = "")

  #### What is already done ####
  todo <- list()
  skipped <- 0

  for (y in years) {
    windows <- zentra_year_windows(y, window_days, overall_start, overall_end)
    if (length(windows) == 0) next

    for (dev in devices) {
      if (file.exists(zentra_backfill_file(dev, y))) {
        skipped <- skipped + 1
        next
      }
      todo[[length(todo) + 1]] <- list(year = y, device = dev, windows = windows)
    }
  }

  if (skipped > 0) {
    cat("Already on disk, skipping: ", skipped, " device-year(s)\n", sep = "")
  }

  if (length(todo) == 0) {
    cat("\nNothing left to download.\n\n")
    return(invisible(TRUE))
  }

  total_calls <- sum(vapply(todo, function(t) length(t$windows), integer(1)))
  cat("To download:               ", length(todo), " device-year(s)\n", sep = "")
  cat("API calls required:        ", format(total_calls, big.mark = ","), "\n\n",
      sep = "")

  cat("Estimated time at 3 s per call: ",
      sprintf("%.1f", total_calls * 3 / 3600), " hours\n\n", sep = "")

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to start.\n\n")
    return(invisible(TRUE))
  }

  cat("Rotating between devices so the per-device rate limit is never\n")
  cat("reached. Interrupt at any time - completed device-years are kept.\n\n")
  cat("--------------------------------------------\n\n")

  started <- Sys.time()
  calls_done <- 0

  #### One year at a time, rotating across devices within it ####
  for (y in years) {
    year_todo <- Filter(function(t) t$year == y, todo)
    if (length(year_todo) == 0) next

    windows <- year_todo[[1]]$windows
    devs <- vapply(year_todo, function(t) t$device, character(1))

    cat("=== ", y, " : ", length(devs), " device(s), ",
        length(windows), " windows each ===\n", sep = "")

    buffer <- setNames(vector("list", length(devs)), devs)
    empty  <- setNames(rep(TRUE, length(devs)), devs)

    for (w in seq_along(windows)) {
      win <- windows[[w]]

      for (dev in devs) {
        result <- tryCatch(
          zentracloud::getReadings(
            device_sn  = dev,
            start_time = format(win$start, "%Y-%m-%d %H:%M:%S"),
            end_time   = format(win$end,   "%Y-%m-%d %H:%M:%S")
          ),
          error = function(e) structure(list(), class = "zentra_error",
                                        message = conditionMessage(e))
        )

        calls_done <- calls_done + 1

        if (inherits(result, "zentra_error")) {
          zentra_backfill_log(dev, win$start, win$end, 0, "error",
                              attr(result, "message"))
          next
        }

        n <- if (length(result) > 0 && !is.null(result[[1]])) nrow(result[[1]]) else 0

        if (n > 0) {
          buffer[[dev]][[length(buffer[[dev]]) + 1]] <- result
          empty[[dev]] <- FALSE
          zentra_backfill_log(dev, win$start, win$end, n, "ok")
        } else {
          zentra_backfill_log(dev, win$start, win$end, 0, "no_data")
        }
      }

      #### Progress ####
      elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
      rate <- elapsed / calls_done
      remaining <- (total_calls - calls_done) * rate

      cat("\r  ", y, " window ", w, "/", length(windows),
          "   ", format(win$start, "%Y-%m-%d"),
          "   calls ", calls_done, "/", total_calls,
          "   ~", sprintf("%.1f", remaining / 3600), " h left     ", sep = "")
      flush.console()
    }

    cat("\n")

    #### Write the year out and free the memory ####
    for (dev in devs) {
      if (empty[[dev]]) {
        cat("  - ", dev, ": no data in ", y, "\n", sep = "")
        # An empty marker still counts as done, so a re-run does not retry it
        saveRDS(list(), zentra_backfill_file(dev, y))
        next
      }
      saveRDS(buffer[[dev]], zentra_backfill_file(dev, y))
      cat("  + ", dev, "_", y, "_raw.rds  (", length(buffer[[dev]]),
          " windows)\n", sep = "")
    }

    rm(buffer)
    gc(verbose = FALSE)
  }

  elapsed <- as.numeric(difftime(Sys.time(), started, units = "mins"))

  cat("\n--------------------------------------------\n")
  cat("Finished in ", sprintf("%.0f", elapsed), " minutes\n", sep = "")
  cat(calls_done, " API call(s) made\n", sep = "")
  cat("Files in: ", zentra_backfill_dir(), "\n\n", sep = "")
  cat("The call log is zentra_backfill_log.csv in that folder - every\n")
  cat("window, its record count, and whether it succeeded.\n\n")

  invisible(TRUE)
}
