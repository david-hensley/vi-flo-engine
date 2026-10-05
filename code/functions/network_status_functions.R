################################################################################
#                            NETWORK STATUS                                    #
#                                                                              #
# What needs attention across the network, in one place. A logger that stopped #
# reporting three weeks ago, a battery at 12%, a HOBO about to fill, a station #
# whose ports were never configured - none of these announce themselves, and   #
# all of them are already answerable from metadata and the API.                #
#                                                                              #
# FIRST PASS. The thresholds are guesses and the checks are the obvious ones;  #
# expect to argue with both. Built as a function rather than an email so there #
# is something to argue WITH - the email can send the same list later without  #
# any of this changing.                                                        #
#                                                                              #
# Extreme or implausible readings are deliberately absent. That needs reading  #
# the data and a notion of plausible, which is quality control, and belongs    #
# with processing rather than here.                                            #
################################################################################


#' Everything worth a look across the network
#'
#' Gathers; does not print. print_network_status() renders, so a digest or a
#' dashboard can use the same findings without a console.
#'
#' @param devices Optional data frame from zc_list_devices(), to save a call
#' @return Data frame: station, device, severity, issue
get_network_status <- function(devices = NULL) {

  found <- list()
  add <- function(station, device, severity, issue) {
    found[[length(found) + 1]] <<- data.frame(
      station = station, device = device, severity = severity, issue = issue,
      stringsAsFactors = FALSE)
  }

  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
  if (is.null(meta)) {
    return(data.frame(station = NA, device = NA, severity = "error",
                      issue = "could not read device_metadata.csv",
                      stringsAsFactors = FALSE))
  }

  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  active <- meta[!tolower(meta$status) %in% terminal, , drop = FALSE]

  now <- Sys.time()

  #### 1. Cloud devices that have stopped reporting ####
  # Asked of the API rather than of last_update, which is only as current as
  # the last thing that happened to write it.
  if (is.null(devices)) {
    devices <- tryCatch(
      zentraR::zc_list_devices(expand = "max_min_timestamp"),
      error = function(e) NULL)
  }

  if (!is.null(devices) && nrow(devices) > 0) {
    for (i in seq_len(nrow(devices))) {
      sn   <- devices$device_id[i]
      last <- devices$last_measurement[i]
      if (is.na(last)) next

      hours <- as.numeric(difftime(now, last, units = "hours"))
      row <- active[active$device_serial == sn, ][1, ]
      station <- if (nrow(row) > 0 && !is.na(row$station_id)) row$station_id else "(not in metadata)"

      if (hours > 24 * 7) {
        add(station, sn, "high",
            paste0("no readings for ", round(hours / 24), " days"))
      } else if (hours > 24) {
        add(station, sn, "medium",
            paste0("no readings for ", round(hours), " hours"))
      }
    }

    #### 2. Reporting, but VI-FLO does not know about it ####
    unknown <- setdiff(devices$device_id, meta$device_serial)
    for (sn in unknown) {
      add("(none)", sn, "medium", "reporting to ZentraCloud but not in metadata")
    }
  }

  #### 3. Battery ####
  # From metadata, so only as fresh as the last thing that wrote it. A better
  # source is the readings themselves, which is a processing question.
  if ("battery" %in% names(active)) {
    low <- which(!is.na(active$battery) & active$battery < 25)
    for (i in low) {
      add(active$station_id[i], active$device_serial[i],
          if (active$battery[i] < 15) "high" else "medium",
          paste0("battery ", active$battery[i], "%"))
    }
  }

  #### 4. HOBO memory ####
  # A U20 holds about 21,700 readings. At a 15 minute interval that is ~226
  # days, after which it either stops or overwrites - and the gap is silent.
  hobo <- active[!grepl("^z6", active$device_serial), , drop = FALSE]
  HOBO_CAPACITY <- 21700

  for (i in seq_len(nrow(hobo))) {
    interval <- hobo$interval_min[i]
    since <- hobo$last_download_date[i]
    if (is.na(interval) || interval <= 0) next
    if (is.na(since)) since <- hobo$deploy_datetime[i]
    if (is.na(since)) next

    readings <- as.numeric(difftime(now, since, units = "mins")) / interval
    pct <- readings / HOBO_CAPACITY

    if (pct > 0.9) {
      add(hobo$station_id[i], hobo$device_serial[i], "high",
          paste0("memory ~", round(pct * 100), "% full - offload soon"))
    } else if (pct > 0.75) {
      add(hobo$station_id[i], hobo$device_serial[i], "medium",
          paste0("memory ~", round(pct * 100), "% full"))
    }
  }

  #### 5. Subscriptions ####
  if ("expiry_date" %in% names(active)) {
    soon <- which(!is.na(active$expiry_date))
    for (i in soon) {
      days <- as.numeric(difftime(active$expiry_date[i], now, units = "days"))
      if (days < 0) {
        add(active$station_id[i], active$device_serial[i], "high",
            paste0("subscription expired ", round(-days), " days ago"))
      } else if (days < 60) {
        add(active$station_id[i], active$device_serial[i], "medium",
            paste0("subscription expires in ", round(days), " days"))
      }
    }
  }

  #### 6. Zentra devices with no ports configured ####
  ports <- tryCatch(load_zentra_ports_data(), error = function(e) NULL)
  if (!is.null(ports)) {
    zentra <- active[grepl("^z6", active$device_serial), , drop = FALSE]
    for (sn in unique(zentra$device_serial)) {
      live <- ports[ports$sn == sn & is.na(ports$valid_to) &
                    !is.na(ports$sensor) & ports$sensor != "none", ]
      if (nrow(live) == 0) {
        row <- zentra[zentra$device_serial == sn, ][1, ]
        add(row$station_id, sn, "high", "no ports configured")
      }
    }
  }

  #### 7. Metadata never reviewed, or reviewed long ago ####
  if ("last_reviewed_utc" %in% names(active)) {
    for (i in seq_len(nrow(active))) {
      v <- active$last_reviewed_utc[i]
      if (is.na(v) || !nzchar(trimws(as.character(v)))) {
        add(active$station_id[i], active$device_serial[i], "low",
            "metadata never reviewed")
        next
      }
      days <- as.numeric(difftime(now, as.POSIXct(as.character(v), tz = "UTC"),
                                  units = "days"))
      if (days > 180) {
        add(active$station_id[i], active$device_serial[i], "low",
            paste0("metadata last reviewed ", round(days / 30.4), " months ago"))
      }
    }
  }

  #### 8. Paired gauges with no survey ####
  # Without both, no slope, and without slope no discharge - so the pair is
  # recording water level that cannot yet be used for the thing it was
  # installed to measure.
  paired <- active[tolower(as.character(active$device_role)) %in%
                     c("secondary", "tertiary") &
                   tolower(active$station_type) == "hydro", , drop = FALSE]
  for (i in seq_len(nrow(paired))) {
    missing <- character(0)
    if (is.na(paired$elev[i])) missing <- c(missing, "elevation")
    if (is.na(paired$reach_length_m[i])) missing <- c(missing, "reach length")
    if (length(missing) > 0) {
      add(paired$station_id[i], paired$device_serial[i], "low",
          paste0("no survey - ", paste(missing, collapse = " or "), " missing"))
    }
  }

  if (length(found) == 0) {
    return(data.frame(station = character(0), device = character(0),
                      severity = character(0), issue = character(0),
                      stringsAsFactors = FALSE))
  }

  out <- do.call(rbind, found)
  out$severity <- factor(out$severity, levels = c("high", "medium", "low", "error"))
  out[order(out$severity, out$station), ]
}


#' Renders the network status
#'
#' @param status Data frame from get_network_status()
#' @param quiet_if_clean Logical. Say nothing when there is nothing to say
#' @return Invisible TRUE
print_network_status <- function(status = NULL, quiet_if_clean = FALSE) {

  if (is.null(status)) status <- get_network_status()

  if (nrow(status) == 0) {
    if (!quiet_if_clean) cat("\n  Network: nothing needs attention\n\n")
    return(invisible(TRUE))
  }

  cat("\n============================================\n")
  cat("  Network - ", nrow(status), " thing(s) worth a look\n", sep = "")
  cat("============================================\n")

  for (sev in c("high", "medium", "low", "error")) {
    rows <- status[status$severity == sev, , drop = FALSE]
    if (nrow(rows) == 0) next

    cat("\n", toupper(sev), "\n", sep = "")
    for (i in seq_len(nrow(rows))) {
      cat("  ", format(rows$station[i], width = 14),
          format(rows$device[i], width = 11), rows$issue[i], "\n", sep = "")
    }
  }

  cat("\n")
  invisible(TRUE)
}
