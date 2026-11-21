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


#' What the archive says about each deployment
#'
#' Worked out from download_log.csv each time it is asked, never stored: how
#' far the archive reaches for the deployment, when its logger was last
#' downloaded, and its battery as that download found it. Each comes from the
#' files of the deployment's own logger that overlap the deployment - a logger
#' that served a station before is not credited with readings from then, which
#' is how sgm2_hydro's new logger once showed a last reading from its Reef Bay
#' years.
#'
#' @param rows Data frame of device_metadata rows
#' @param dl Data frame from load_download_log(), or NULL to read
#' @return Data frame, one row per input row: unique_id, data_to,
#'   last_download (UTC), battery, battery_as_of (UTC)
deployment_activity <- function(rows, dl = NULL) {
  n <- nrow(rows)
  out <- data.frame(unique_id = rows$unique_id,
                    data_to = as.POSIXct(rep(NA, n), tz = PROJECT_TZ),
                    last_download = as.POSIXct(rep(NA, n), tz = "UTC"),
                    battery = rep(NA_real_, n),
                    battery_as_of = as.POSIXct(rep(NA, n), tz = "UTC"),
                    stringsAsFactors = FALSE)
  if (n == 0) return(out)
  if (is.null(dl)) dl <- tryCatch(load_download_log(), error = function(e) NULL)
  if (is.null(dl) || nrow(dl) == 0) return(out)
  stamp <- as.POSIXct(dl$timestamp_utc, tz = "UTC")

  for (i in seq_len(n)) {
    from <- rows$deploy_datetime[i]
    to   <- if ("end_datetime" %in% names(rows)) rows$end_datetime[i] else NA
    mine <- which(dl$device_serial == rows$device_serial[i] & !is.na(dl$end_date) &
                    (is.na(from) | dl$end_date >= from) &
                    (is.na(to) | dl$start_date <= to))
    if (length(mine) == 0) next
    last <- max(dl$end_date[mine])
    if (!is.na(to) && last > to) last <- to
    out$data_to[i] <- last
    out$last_download[i] <- max(stamp[mine], na.rm = TRUE)
    b <- mine[!is.na(dl$battery[mine])]
    if (length(b) > 0) {
      newest <- b[which.max(dl$end_date[b])]
      out$battery[i] <- dl$battery[newest]
      out$battery_as_of[i] <- stamp[newest]
    }
  }
  out
}


#' What needs attention across the network
#'
#' Gathers; does not print. print_network_todo() renders, so a digest or a
#' dashboard can use the same findings without a console.
#'
#' @param devices Optional data frame from zc_list_devices(), to save a call
#' @return Data frame: station, device, severity, issue, type
get_network_todo <- function(devices = NULL) {

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

  active <- meta[!tolower(meta$status) %in% TERMINAL_STATUSES, , drop = FALSE]
  act <- deployment_activity(active)

  now <- Sys.time()

  #### 1. Cloud devices that have stopped reporting ####
  # Asked of the API rather than of last_update, which is only as current as
  # the last thing that happened to write it.
  api_error <- NA_character_
  if (is.null(devices)) {
    devices <- tryCatch(
      zentraR::zc_list_devices(expand = "max_min_timestamp"),
      error = function(e) { api_error <<- conditionMessage(e); NULL })
  }

  # A failed call used to return NULL and the checks below simply found
  # nothing - so a dead API key read as "every device is fine", which is the
  # worst way for a check to fail. It took six days of a station being down
  # before anyone noticed the silence was the tool and not the network.
  if (is.null(devices)) {
    add(NA_character_, NA_character_, "high",
        paste0("could not reach ZentraCloud - reporting and ",
               "unestablished devices were NOT checked",
               if (!is.na(api_error)) paste0(" (", substr(api_error, 1, 60), ")")
               else ""),
        "error")
  }

  if (!is.null(devices) && nrow(devices) > 0) {
    for (i in seq_len(nrow(devices))) {
      sn   <- devices$device_id[i]
      last <- devices$last_measurement[i]
      if (is.na(last)) next

      hours <- as.numeric(difftime(now, last, units = "hours"))
      row <- active[active$device_serial == sn, , drop = FALSE]
      station <- if (nrow(row) > 0 && !is.na(row$station_id[1])) {
        row$station_id[1]
      } else {
        # A retired logger still reporting - out of service, in a shed, waiting
        # to be collected - is named by the last station it served
        past <- meta[meta$device_serial == sn, , drop = FALSE]
        if (nrow(past) > 0) {
          paste0(past$station_id[which.max(as.numeric(past$deploy_datetime))], " (retired)")
        } else "(not in metadata)"
      }

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
  #
  # It is still only as fresh as the last DOWNLOAD, and cannot be otherwise:
  # zc_list_devices() returns identity and timestamps, not battery, so the
  # figure arrives with the readings. A battery changed this morning still
  # reads low here until the next download, which is confusing enough to be
  # worth saying rather than leaving the reader to work out.
  low <- which(!is.na(act$battery) & act$battery < 25)
  for (i in low) {
    age <- as.numeric(difftime(now, act$battery_as_of[i], units = "days"))
    note <- paste0("battery ", act$battery[i], "%")
    if (!is.na(age) && age >= 1) note <- paste0(note, " as of ", format(round(age)), "d ago")
    add(active$station_id[i], active$device_serial[i],
        if (act$battery[i] < 15) "high" else "medium", note, "battery")
  }

  #### 4. Hydro logger memory ####
  #
  # A U20 stops when its memory is full and says nothing about it. Three
  # loggers have been observed stopping at 21,693 to 21,695 readings, so 21,600
  # is used - a warning that fires a few days early costs nothing, one that
  # fires late costs the data.
  #
  # Reported as a DEADLINE rather than a percentage. "88% full" needs arithmetic
  # before it can be acted on; "fills 2026-12-15, 48 days" is a date to plan a
  # trip around.
  #
  # Two loggers filled TWICE before this existed: 21352826 and 21652375 were
  # launched at 10 minutes while metadata declared 15, so they filled in 150
  # days rather than 225. Which is why the interval comes from the DATA where
  # there is any - the declared value is what someone meant to set, the
  # timestamps are what the logger did, and it is the logger that fills the
  # memory.
  HOBO_CAPACITY <- 21600
  WARN_WITHIN_DAYS <- 60

  is_hobo <- !grepl("^z6", active$device_serial)
  hobo <- active[is_hobo, , drop = FALSE]
  hobo_reach <- act$data_to[is_hobo]

  for (i in seq_len(nrow(hobo))) {
    sn <- hobo$device_serial[i]

    interval <- NA_real_
    basis <- "declared"
    held <- tryCatch(
      list.files(wds("device_hobo"), pattern = paste0("^", sn, "_"),
                 full.names = TRUE),
      error = function(e) character(0))

    if (length(held) > 0) {
      # The newest file by its DATA, not by file.mtime(). Modification time
      # says when a file was written, which is not when its readings were
      # taken - importing the 2021-2025 archive in October 2026 gave a Fish
      # Bay file from 2021 the newest mtime on disk, and the check then
      # reported that logger as running at ten minutes because that is what
      # it did five years ago.
      #
      # The span is in the name: {serial}_{start}_{end}_raw.rds
      ends <- suppressWarnings(as.Date(
        sub("^.*_([0-9]{8})_([0-9]{8})(_[0-9T]+)?_raw\\.rds$", "\\2",
            basename(held)), format = "%Y%m%d"))
      newest <- if (all(is.na(ends))) held[which.max(file.mtime(held))]
                else held[which.max(ends)]
      obs <- tryCatch({
        l <- hobo_to_long(readRDS(newest), sn)
        u <- sort(unique(l$datetime))
        if (length(u) > 2) {
          g <- as.numeric(diff(u), units = "mins"); g <- g[g > 0]
          if (length(g)) as.numeric(names(which.max(table(round(g, 3)))))
          else NA_real_
        } else NA_real_
      }, error = function(e) NA_real_)
      if (!is.na(obs) && obs > 0) { interval <- obs; basis <- "observed" }
    }

    if (is.na(interval)) interval <- hobo$interval_min[i]
    if (is.na(interval) || interval <= 0) next

    # Memory fills from the launch - the last offload, or for a logger nobody
    # has read yet, the deployment
    # The logger is relaunched when it is offloaded, so its memory fills from
    # the end of the last file it gave
    since <- hobo_reach[i]
    from_deploy <- is.na(since)
    if (from_deploy) since <- hobo$deploy_datetime[i]
    if (is.na(since)) next

    full_at <- as.POSIXct(since) + HOBO_CAPACITY * interval * 60
    days_left <- as.numeric(difftime(full_at, now, units = "days"))

    if (days_left > WARN_WITHIN_DAYS) next

    when <- format(full_at, "%d %b %Y")

    note <- if (days_left < 0) {
      paste0("FULL since ", when, " - ", round(-days_left),
             " days of readings already lost")
    } else {
      paste0("fills ", when, " - ", round(days_left), " days")
    }

    # The thing that caused two losses already: a logger running faster than
    # metadata says
    if (basis == "observed" && !is.na(hobo$interval_min[i]) &&
        abs(interval - hobo$interval_min[i]) > 0.001) {
      note <- paste0(note, ", logging at ", interval, " min not ",
                     hobo$interval_min[i])
    } else if (from_deploy) {
      note <- paste0(note, ", never offloaded",
                     if (basis == "declared") " and interval unverified" else "")
    }

    add(hobo$station_id[i], sn,
        if (days_left <= 14) "high" else "medium", note, "memory")
  }

  #### 5. Subscriptions ####
  #
  # Not checked. The expiry date was typed in by hand and went stale, and the
  # API's own subscription status has proved unreliable - devices reporting
  # daily have shown as inactive. ZentraCloud's account page is the record.

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
  broken <- active[tolower(active$status) %in% "defunct", , drop = FALSE]
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
  active <- active[!tolower(active$status) %in% "defunct", , drop = FALSE]

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
  # Without a fall and a reach, no slope, and without slope no discharge - so
  # the pair is recording water level that cannot yet be used for the thing it
  # was installed to measure. Worked out from surveys.csv by survey_needs();
  # the other things it finds missing - a sensor height at a single gauge -
  # stop nothing working, and belong in the doctor report rather than here.
  # Asked of every current row, so a primary marked defunct - still in its
  # housing, still surveyed - is still found to survey against
  needs <- tryCatch(survey_needs(meta), error = function(e) {
    add("(all)", NA, "error", paste("surveys.csv could not be read:", conditionMessage(e)),
        "survey")
    NULL
  })
  if (!is.null(needs)) {
    needs <- needs[needs$need %in% c("fall to primary", "reach to primary", "no primary") &
                     needs$unique_id %in% active$unique_id, , drop = FALSE]
    for (uid in unique(needs$unique_id)) {
      n <- needs[needs$unique_id == uid, , drop = FALSE]
      add(n$station_id[1], active$device_serial[match(uid, active$unique_id)], "low",
          paste0("no survey - ", paste(n$detail, collapse = "; ")), "survey")
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
  # ordering batteries, planning a field trip to
  # offload a logger - and a single list sorted by urgency buries one kind
  # under another. Severity orders within each group.
  # Field first, desk after. The first five need somebody to drive somewhere;
  # the last three are answered from here.
  out$type <- factor(out$type, levels = c(
    "reporting", "battery", "memory", "survey", "known broken",
    "ports", "not established", "metadata review", "error"))

  out[order(out$type, out$severity, out$station), ]
}


#' Renders the to-do list
#'
#' @param status Data frame from get_network_todo()
#' @param quiet_if_clean Logical. Say nothing when there is nothing to say
#' @return Invisible TRUE
print_network_todo <- function(status = NULL, quiet_if_clean = FALSE) {

  if (is.null(status)) status <- get_network_todo()

  headings <- c(
    "reporting"       = "NOT REPORTING",
    "battery"         = "BATTERY  (as of the last download)",
    "memory"          = "HYDRO LOGGER MEMORY",
    "survey"          = "SURVEY OUTSTANDING",
    "known broken"    = "KNOWN BROKEN - NEEDS A VISIT",
    "ports"           = "PORTS NOT CONFIGURED",
    "not established" = "REPORTING BUT NOT ESTABLISHED",
    "metadata review" = "METADATA REVIEW")

  # Every section prints, empty or not. A heading that disappears when there is
  # nothing under it leaves the reader to notice an absence, which nobody does;
  # a heading saying "nothing here" is read in a second and believed.
  clear <- c(
    "reporting"       = "all reporting devices have been heard from",
    "battery"         = "no low batteries",
    "memory"          = "no logger fills within 60 days",
    "survey"          = "every paired gauge is surveyed",
    "known broken"    = "nothing known broken in the field",
    "ports"           = "every device has its ports configured",
    "not established" = "nothing reporting that is not in metadata",
    "metadata review" = "every record reviewed recently")

  if (nrow(status) == 0 && quiet_if_clean) return(invisible(TRUE))

  n <- nrow(status)
  cat("\n============================================\n")
  if (n == 0) {
    cat("  Network - nothing needs attention\n")
  } else {
    cat("  Network - ", n, " thing(s) worth a look\n", sep = "")
  }
  cat("============================================\n")

  for (ty in names(headings)) {
    rows <- if (n > 0) status[status$type == ty, , drop = FALSE] else status[0, ]

    cat("\n", headings[[ty]], "\n", sep = "")

    if (nrow(rows) == 0) {
      cat("   \u2713 ", clear[[ty]], "\n", sep = "")
      next
    }

    for (i in seq_len(nrow(rows))) {
      mark <- switch(as.character(rows$severity[i]),
                     high = "!", medium = " ", low = " ", "?")
      cat(" ", mark, " ", format(rows$station[i], width = 14),
          format(rows$device[i], width = 11), rows$issue[i], "\n", sep = "")
    }
  }

  if (n > 0) {
    errs <- status[status$type == "error", , drop = FALSE]
    if (nrow(errs) > 0) {
      cat("\nCOULD NOT CHECK\n")
      for (i in seq_len(nrow(errs))) cat(" ! ", errs$issue[i], "\n", sep = "")
    }
    n_high <- sum(status$severity == "high")
    if (n_high > 0) cat("\n  ! marks the ", n_high, " most urgent\n", sep = "")
  }
  cat("\n  print_network_status() for every station, not only these\n\n")

  invisible(TRUE)
}


################################################################################
#                            THE ROSTER                                        #
#                                                                              #
# Every station and how it is doing. No thresholds, no judgement - the facts   #
# you would want in front of you when deciding where to go.                    #
#                                                                              #
# print_network_todo() answers "what needs attention". This answers "what is   #
# out there", which is the question when planning rather than reacting.        #
################################################################################


#' Every active station, with its current state
#'
#' @param devices Optional data frame from zc_list_devices(), to save a call
#' @return Data frame: watershed, station_id, device_serial, station_type,
#'   status, battery, last_contact, data_to, last_visit, reports
get_station_roster <- function(devices = NULL) {

  meta <- load_zentra_metadata()
  active <- meta[!tolower(meta$status) %in% TERMINAL_STATUSES, , drop = FALSE]
  if (nrow(active) == 0) return(active)
  act <- deployment_activity(active)

  # Asked of the API rather than of metadata, which is only as current as the
  # last thing that wrote it
  reached <- TRUE
  if (is.null(devices)) {
    devices <- tryCatch(zentraR::zc_list_devices(expand = "max_min_timestamp"),
                        error = function(e) { reached <<- FALSE; NULL })
  }

  last_contact <- as.POSIXct(rep(NA, nrow(active)), tz = "UTC")
  if (!is.null(devices) && nrow(devices) > 0) {
    hit <- match(active$device_serial, devices$device_id)
    last_contact <- devices$last_measurement[hit]
  }

  # How far the archive reaches for each deployment - from the download log,
  # through the files of its own logger during its own deployment
  data_to <- act$data_to

  out <- data.frame(
    watershed    = active$watershed,
    station_id   = active$station_id,
    device_serial= active$device_serial,
    station_type = active$station_type,
    status       = active$status,
    battery      = act$battery,
    last_contact = last_contact,
    data_to      = data_to,
    last_visit   = active$last_visit,
    # A device that reaches the cloud, against one read by hand in the field.
    # They fail differently and are worth telling apart at a glance.
    reports      = tolower(active$status) %in% "online",
    stringsAsFactors = FALSE)

  # Carried on the result so the printer can distinguish "no contact recorded"
  # from "we could not ask". Blank cells look the same either way.
  attr(out, "api_reached") <- reached

  out[order(out$watershed, out$station_id), ]
}


#' Renders the roster
#'
#' @param roster Data frame from get_station_roster()
#' @return Invisible TRUE
print_station_roster <- function(roster = NULL) {

  if (is.null(roster)) roster <- get_station_roster()

  if (nrow(roster) == 0) {
    cat("\n  No active stations.\n\n")
    return(invisible(TRUE))
  }

  now <- Sys.time()
  ago <- function(x) {
    if (is.na(x)) return("-")
    h <- as.numeric(difftime(now, x, units = "hours"))
    if (h < 1)   return("just now")
    if (h < 48)  return(paste0(round(h), "h"))
    paste0(round(h / 24), "d")
  }

  cat("\n============================================\n")
  cat("  Network - ", nrow(roster), " active station(s)\n", sep = "")
  cat("============================================\n")

  cat("\n  ", format("station", width = 14), format("device", width = 11),
      format("status", width = 14), format("batt", width = 5),
      format("contact", width = 9), "data to\n", sep = "")

  ws <- NULL
  for (i in seq_len(nrow(roster))) {
    if (!identical(roster$watershed[i], ws)) {
      ws <- roster$watershed[i]
      cat("\n  === ", ws, " ", strrep("=", max(0, 30 - nchar(ws))), "\n", sep = "")
    }

    batt <- if (is.na(roster$battery[i])) "-" else paste0(roster$battery[i], "%")

    # A manual device never reaches the cloud, so a contact time would be
    # meaningless rather than missing
    contact <- if (!roster$reports[i]) "offload" else ago(roster$last_contact[i])

    cat("  ", format(roster$station_id[i], width = 14),
        format(roster$device_serial[i], width = 11),
        format(roster$status[i], width = 14),
        format(batt, width = 5),
        format(contact, width = 9),
        if (is.na(roster$data_to[i])) "-"
        else format(as.Date(roster$data_to[i]), "%Y-%m-%d"),
        "\n", sep = "")
  }

  if (identical(attr(roster, "api_reached"), FALSE)) {
    cat("\n  ! ZentraCloud could not be reached, so every contact time above is\n")
    cat("    unknown rather than absent. Check the API key.\n")
  }

  cat("\n  contact is the last reading ZentraCloud holds; data to is the last\n")
  cat("  reading in the archive\n")
  cat("\n  print_network_todo() for what needs attention\n\n")

  invisible(TRUE)
}


#' The roster, under its plainer name
#'
#' @param ... Passed to print_station_roster()
#' @return Invisible TRUE
print_network_status <- function(...) print_station_roster(...)
