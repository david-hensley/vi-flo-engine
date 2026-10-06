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
#' @return Data frame: station, device, severity, issue, type
get_network_status <- function(devices = NULL) {

  found <- list()
  add <- function(station, device, severity, issue, type) {
    found[[length(found) + 1]] <<- data.frame(
      station = station, device = device, severity = severity,
      issue = issue, type = type, stringsAsFactors = FALSE)
  }

  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
  if (is.null(meta)) {
    return(data.frame(station = NA, device = NA, severity = "error",
                      issue = "could not read device_metadata.csv",
                      type = "error", stringsAsFactors = FALSE))
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
            paste0("no readings for ", round(hours / 24), " days"), "reporting")
      } else if (hours > 24) {
        add(station, sn, "medium",
            paste0("no readings for ", round(hours), " hours"), "reporting")
      }
    }

    #### 2. Reporting, but VI-FLO does not know about it ####
    unknown <- setdiff(devices$device_id, meta$device_serial)
    for (sn in unknown) {
      add("(none)", sn, "medium", "reporting to ZentraCloud but not in metadata",
          "not established")
    }
  }

  #### 3. Battery ####
  # Written by every download from port 7 of what it fetched, so this is as
  # fresh as the data. It used to come from whatever last happened to write it,
  # which meant a device could sit at a January value while this check tried to
  # warn about low batteries.
  if ("battery" %in% names(active)) {
    low <- which(!is.na(active$battery) & active$battery < 25)
    for (i in low) {
      add(active$station_id[i], active$device_serial[i],
          if (active$battery[i] < 15) "high" else "medium",
          paste0("battery ", active$battery[i], "%"), "battery")
    }
  }

  #### 4. HOBO memory ####
  # TO CONFIRM: 21,700 is a figure for the U20 family taken from memory, not
  # from the datasheet. At 15 minutes it works out to ~226 days, which matches
  # what the St. Thomas gauges actually do - but the number should be checked
  # against Onset's specification and corrected here, since every percentage
  # below rests on it.
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
          paste0("memory ~", round(pct * 100), "% full - offload soon"), "memory")
    } else if (pct > 0.75) {
      add(hobo$station_id[i], hobo$device_serial[i], "medium",
          paste0("memory ~", round(pct * 100), "% full"), "memory")
    }
  }

  #### 5. Subscriptions ####
  if ("expiry_date" %in% names(active)) {
    soon <- which(!is.na(active$expiry_date))
    for (i in soon) {
      days <- as.numeric(difftime(active$expiry_date[i], now, units = "days"))
      if (days < 0) {
        add(active$station_id[i], active$device_serial[i], "high",
            paste0("subscription expired ", round(-days), " days ago"),
            "subscription")
      } else if (days < 60) {
        add(active$station_id[i], active$device_serial[i], "medium",
            paste0("subscription expires in ", round(days), " days"),
            "subscription")
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
        add(row$station_id, sn, "high", "no ports configured", "ports")
      }
    }
  }

  #### 6b. Known broken, waiting on a visit ####
  # These do not appear under "not reporting" - the API only lists devices it
  # can reach, so a dead logger is invisible there. Without this they show up
  # only as a stale review, which reads as paperwork rather than as a station
  # that needs somebody to drive to it.
  broken <- active[tolower(active$status) %in% c("defunct", "nonresponsive"), ,
                   drop = FALSE]
  for (i in seq_len(nrow(broken))) {
    since <- if (!is.na(broken$last_visit[i])) {
      paste0(" - last seen ", format(as.Date(broken$last_visit[i]), "%d %b %Y"))
    } else ""
    add(broken$station_id[i], broken$device_serial[i], "medium",
        paste0(tolower(broken$status[i]), since), "known broken")
  }

  #### 7. Metadata never reviewed, or reviewed long ago ####
  # Only working stations. A review asks whether the record matches what is
  # physically out there, and for a logger known to be dead the answer is "yes,
  # still dead" until somebody visits. Nagging about it would age indefinitely
  # while meaning nothing.
  active <- active[!tolower(active$status) %in% c("defunct", "nonresponsive"), ,
                   drop = FALSE]

  if ("last_reviewed_utc" %in% names(active)) {
    for (i in seq_len(nrow(active))) {
      v <- active$last_reviewed_utc[i]
      if (is.na(v) || !nzchar(trimws(as.character(v)))) {
        add(active$station_id[i], active$device_serial[i], "low",
            "metadata never reviewed", "metadata review")
        next
      }
      days <- as.numeric(difftime(now, as.POSIXct(as.character(v), tz = "UTC"),
                                  units = "days"))
      if (days > 180) {
        add(active$station_id[i], active$device_serial[i], "low",
            paste0("metadata last reviewed ", round(days / 30.4), " months ago"),
            "metadata review")
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
          paste0("no survey - ", paste(missing, collapse = " or "), " missing"),
          "survey")
    }
  }

  if (length(found) == 0) {
    return(data.frame(station = character(0), device = character(0),
                      severity = character(0), issue = character(0),
                      type = character(0), stringsAsFactors = FALSE))
  }

  out <- do.call(rbind, found)
  out$severity <- factor(out$severity, levels = c("high", "medium", "low", "error"))

  # Grouped by TYPE, not by severity. These are different kinds of work -
  # ordering batteries, chasing a subscription, planning a field trip to
  # offload a logger - and a single list sorted by urgency buries one kind
  # under another. Severity orders within each group.
  out$type <- factor(out$type, levels = c(
    "reporting", "battery", "memory", "subscription", "ports",
    "not established", "survey", "metadata review", "known broken", "error"))

  out[order(out$type, out$severity, out$station), ]
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

  headings <- c(
    "reporting"       = "NOT REPORTING",
    "battery"         = "BATTERY",
    "memory"          = "LOGGER MEMORY",
    "subscription"    = "SUBSCRIPTIONS",
    "ports"           = "PORTS NOT CONFIGURED",
    "not established" = "REPORTING BUT NOT ESTABLISHED",
    "survey"          = "SURVEY OUTSTANDING",
    "metadata review" = "METADATA REVIEW",
    # Last, because nothing here changes until somebody drives to it. It is a
    # standing list rather than a to-do.
    "known broken"    = "KNOWN BROKEN - NEEDS A VISIT",
    "error"           = "ERRORS")

  cat("\n============================================\n")
  cat("  Network - ", nrow(status), " thing(s) worth a look\n", sep = "")
  cat("============================================\n")

  for (ty in levels(status$type)) {
    rows <- status[status$type == ty, , drop = FALSE]
    if (nrow(rows) == 0) next

    cat("\n", headings[[ty]], "\n", sep = "")
    for (i in seq_len(nrow(rows))) {
      # Severity marks the line rather than splitting the list - the work is
      # the same kind either way, and a split would hide half of it.
      mark <- switch(as.character(rows$severity[i]),
                     high = "!", medium = " ", low = " ", "?")
      cat(" ", mark, " ", format(rows$station[i], width = 14),
          format(rows$device[i], width = 11), rows$issue[i], "\n", sep = "")
    }
  }

  n_high <- sum(status$severity == "high")
  if (n_high > 0) cat("\n  ! marks the ", n_high, " most urgent\n", sep = "")
  cat("\n")

  invisible(TRUE)
}
