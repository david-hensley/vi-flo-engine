# VI-FLO: record where each station's history becomes trustworthy
#
# ONE-TIME TOOL. Run once across the stations with export data, then delete.
#
# The exports reach back to 2021, but device-level history of that era was not
# systematically recorded - which logger served which station, and when, is in
# places a reconstruction from notes. Attribution needs to know where that
# gives way to a contemporaneous log.
#
# It is a judgement, not a derivation. The obvious rule - that an entry written
# long after the visit it describes was reconstructed - fails, because some
# real entries were logged from field notes six months late.
#
# So this shows what is known about each station and asks. The answers go to
# metadata/internal/record_confirmed.csv, which attribution reads through
# record_confirmed_from().
#
# Stations without export data are not asked about: the default covers them.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/review_station_records.R"))
#   review_station_records()

#' Everything known about a station's record, for judging where it firms up
#'
#' @param station_id Character
#' @return Invisible list of the pieces, for a caller that wants them
show_station_record <- function(station_id) {

  meta <- load_zentra_metadata()
  rows <- meta[meta$station_id == station_id, , drop = FALSE]
  rows <- rows[order(rows$deploy_datetime), , drop = FALSE]

  cat("\n============================================\n")
  cat("  ", station_id, "\n", sep = "")
  if (nrow(rows) > 0) {
    cat("  ", rows$site_full[1], "   ", rows$watershed[1], " watershed\n",
        sep = "")
  }
  cat("============================================\n")

  #### Devices, in the order they served ####
  cat("\nDEVICES\n")
  for (i in seq_len(nrow(rows))) {
    cat("  ", format(rows$device_serial[i], width = 11),
        format(as.Date(rows$deploy_datetime[i]), "%Y-%m-%d"), "  ",
        format(rows$status[i], width = 14),
        if (!is.na(rows$device_role[i])) rows$device_role[i] else "",
        "\n", sep = "")
  }

  #### Maintenance, with the gap between doing and logging ####
  # The gap is the signal that an entry was reconstructed rather than logged at
  # the time - though not a reliable one on its own, since some real entries
  # were written from notes months later. It is shown so a person can weigh it.
  # Every entry for this station's DEVICES, not only those filed under this
  # station. One logger can serve two stations, and a visit gets logged under
  # whichever one the person had in mind - so a co-located station's own
  # history can look empty while its box was worked on repeatedly.
  ml <- tryCatch(load_maintenance_log(), error = function(e) NULL)
  entries <- if (is.null(ml)) NULL else {
    ml[ml$station_id == station_id | ml$device_serial %in% rows$device_serial, ,
       drop = FALSE]
  }

  #### What the ports say about when sensors went in ####
  # A co-located station shows almost nothing in its own maintenance history -
  # work on a shared logger tends to get logged under whichever station the
  # person was thinking about. The port dates are the harder evidence: a TEROS
  # with a valid_from of 2026-09-04 says when that station's sensors actually
  # went into the ground, whatever the logger's deployment date says.
  ports <- tryCatch(load_zentra_ports_data(), error = function(e) NULL)
  if (!is.null(ports)) {
    mine <- ports[ports$sn %in% rows$device_serial & is.na(ports$valid_to) &
                  !is.na(ports$sensor) & ports$sensor != "none", , drop = FALSE]
    if (nrow(mine) > 0) {
      cat("\nPORTS IN SERVICE\n")
      mine <- mine[order(mine$sn, mine$port), , drop = FALSE]
      for (i in seq_len(nrow(mine))) {
        cat("  ", format(mine$sn[i], width = 11), "port ", mine$port[i], "  ",
            format(mine$sensor[i], width = 12),
            if (!is.na(mine$depth_cm[i])) paste0(mine$depth_cm[i], " cm   ") else "       ",
            "since ",
            if (!is.na(mine$valid_from[i]))
              format(as.Date(mine$valid_from[i]), "%Y-%m-%d") else "?",
            "\n", sep = "")
      }
    }
  }

  cat("\nMAINTENANCE  (lag = days between the visit and it being logged)\n")
  if (is.null(entries) || nrow(entries) == 0) {
    cat("  none\n")
  } else {
    entries <- entries[order(entries$field_visit_date), , drop = FALSE]
    for (i in seq_len(nrow(entries))) {
      lag <- tryCatch(
        as.numeric(difftime(as.POSIXct(entries$timestamp[i]),
                            as.POSIXct(entries$field_visit_date[i]),
                            units = "days")),
        error = function(e) NA)

      elsewhere <- !identical(entries$station_id[i], station_id)
      cat("  ", format(as.Date(entries$field_visit_date[i]), "%Y-%m-%d"),
          "  lag ", format(if (is.na(lag)) "?" else round(lag), width = 5),
          "  ", format(entries$action_type[i], width = 20),
          substr(ifelse(is.na(entries$details[i]), "", entries$details[i]),
                 1, 40),
          if (elsewhere) paste0("   [under ", entries$station_id[i], "]") else "",
          "\n", sep = "")
    }
  }

  #### What data exists, and where it came from ####
  dl <- tryCatch(load_download_log(), error = function(e) NULL)
  serials <- unique(rows$device_serial)
  files <- if (is.null(dl)) NULL else dl[dl$device_serial %in% serials, ,
                                         drop = FALSE]

  cat("\nDATA HELD\n")
  if (is.null(files) || nrow(files) == 0) {
    cat("  none\n")
  } else {
    for (ty in c("export", "manual", "automatic")) {
      sub <- files[files$download_type == ty, , drop = FALSE]
      if (nrow(sub) == 0) next

      starts <- suppressWarnings(as.Date(sub$start_date))
      ends   <- suppressWarnings(as.Date(sub$end_date))

      cat("  ", format(ty, width = 10), format(nrow(sub), width = 4),
          " file(s)   ",
          format(min(starts, na.rm = TRUE), "%Y-%m-%d"), " to ",
          format(max(ends, na.rm = TRUE), "%Y-%m-%d"), "\n", sep = "")
    }

    # Where reconstruction gives way to a logged deployment. Export data
    # before the first contemporaneous maintenance entry is the era in
    # question.
    exports <- files[files$download_type == "export", , drop = FALSE]
    if (nrow(exports) > 0) {
      cat("\n  Export data begins ",
          format(min(as.Date(exports$start_date), na.rm = TRUE), "%Y-%m-%d"),
          " - before the API served anything\n", sep = "")
    }
  }

  #### What is recorded now ####
  rc <- load_record_confirmed()
  current <- rc[rc$station_id == station_id, , drop = FALSE]

  cat("\nCONFIRMED FROM\n")
  if (nrow(current) == 1) {
    cat("  ", current$confirmed_from[1], "   ", current$reason[1], "\n",
        sep = "")
  } else {
    cat("  (default) ", as.character(record_confirmed_from(station_id)),
        "\n", sep = "")
  }
  cat("\n")

  invisible(list(devices = rows, maintenance = entries, files = files))
}


#' Works through the stations, recording where each record firms up
#'
#' One at a time: what is known, then a date and a reason. Enter alone keeps
#' the default and moves on, so a station needing no exception costs one
#' keystroke.
#'
#' @param stations Character vector, or NULL for every station with export data
#' @return Invisible TRUE
review_station_records <- function(stations = NULL) {

  meta <- load_zentra_metadata()

  if (is.null(stations)) {
    # Stations with export data - the only ones where the question arises.
    # Everything else is covered by the default.
    dl <- load_download_log()
    export_serials <- unique(dl$device_serial[dl$download_type == "export"])
    stations <- sort(unique(meta$station_id[meta$device_serial %in% export_serials]))
  }

  if (length(stations) == 0) {
    cat("\n  No stations have export data - the default covers everything.\n\n")
    return(invisible(TRUE))
  }

  cat("\n============================================\n")
  cat("  Station records - ", length(stations), " to work through\n", sep = "")
  cat("============================================\n\n")
  cat("For each station: the date from which its record can be trusted.\n")
  cat("Before that date, which logger served it is a reconstruction.\n\n")
  cat("Press Enter alone to leave a station on the default (",
      RECORD_CONFIRMED_DEFAULT, ").\n", sep = "")
  cat("Type q at any point to stop - what you have answered is kept.\n")

  for (s in stations) {
    show_station_record(s)

    cat("Confirmed from (YYYY-MM-DD), Enter for the default, q to stop: ")
    answer <- trimws(readline())

    if (tolower(answer) == "q") {
      cat("\n\u2713 Stopped. Answers so far are saved.\n\n")
      return(invisible(TRUE))
    }

    if (!nzchar(answer)) {
      cat("\u2713 Left on the default\n")
      next
    }

    d <- suppressWarnings(as.Date(answer))
    if (is.na(d)) {
      cat("\u26a0\ufe0f  Not a date - left on the default\n")
      next
    }

    cat("Why that date? ")
    reason <- trimws(readline())
    if (!nzchar(reason)) reason <- "no reason given"

    set_record_confirmed(s, d, reason)
    cat("\u2713 ", s, " confirmed from ", format(d), "\n", sep = "")
  }

  cat("\n\u2713 Done. See metadata/internal/record_confirmed.csv\n\n")
  invisible(TRUE)
}
