# VI-FLO: prototype era metadata, second pass
#
# ONE-TIME MIGRATION. Run migrate_prototype_metadata.R first.
#
# The first pass established which devices existed and when. This fills the
# fields that were left empty on those rows, and corrects coordinates that were
# inherited from the wrong era.
#
#
# WHAT IS NOT HERE, AND WHY
#
# interval_min, last_record_date and last_download_date are derivable only from
# the data, and the prototype exports are not imported yet. Asserting them now
# would be guessing at values the importer can measure. The backfill importer
# writes them from the timestamps it reads, as zentra_update_device_facts()
# already does after a Zentra download.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_prototype_metadata_2.R"))
#   migrate_prototype_metadata_2()
#   migrate_prototype_metadata_2(dry_run = FALSE)

migrate_prototype_metadata_2 <- function(dry_run = TRUE, do_elevation = TRUE) {

  or_else <- function(a, b) if (is.null(a)) b else a
  meta  <- load_zentra_metadata()
  maint <- load_maintenance_log()

  ##########################################################################
  #
  #  REEF BAY MOVED 70 METRES
  #
  #  Three coordinate pairs were in circulation for this station and none of
  #  them was right. site.coords.csv had the old gauge 286 m out; the metadata
  #  rows carried a value 166 m out, sitting between the two positions.
  #
  #  The authoritative pair, measured since:
  #
  #    old   18.32810, -64.74196    the 2023-2025 gauge
  #    new   18.32864, -64.74230    from 2025-11-06
  #
  #  70 m apart, the same reach. Short enough that it is barely a reposition
  #  rather than a relocation - but lat and lon do not change without an event
  #  to explain them, so the relocation is logged. RB C keeps the OLD position
  #  deliberately: it was placed there to measure whether 70 m matters.
  #
  ##########################################################################

  RB_OLD <- c(lat = 18.32810, lon = -64.74196)
  RB_NEW <- c(lat = 18.32864, lon = -64.74230)

  coords <- list(
    list(serial = "21652380", station = "rb2_hydro", to = RB_OLD,
         why = "the 2023-2025 gauge position"),
    list(serial = "21652377", station = "rb2_hydro", to = RB_OLD,
         why = "the slope partner, at the old position throughout"),
    list(serial = "22373555", station = "rb2_hydro", to = RB_OLD,
         why = "RB C, placed at the old gauge position to bridge the two eras"),
    list(serial = "22373557", station = "rb2_hydro", to = RB_NEW,
         why = "the November 2025 position"),
    list(serial = "22373552", station = "rb2_hydro", to = RB_NEW,
         why = "the November 2025 position")
  )

  ##########################################################################
  #  ROLES ON THE PAIRED PROTOTYPE GAUGES
  #
  #  primary is the downstream logger. Reef Bay's partner went in upstream;
  #  Dorothea's did too, 9.083 m up and 0.524 m above.
  ##########################################################################

  fields <- list(
    list(serial = "21652380", station = "rb2_hydro", field = "device_role",
         to = "primary",   why = "the downstream gauge"),
    list(serial = "21652377", station = "rb2_hydro", field = "device_role",
         to = "secondary", why = "the upstream slope partner"),
    list(serial = "21652381", station = "dor2_hydro", field = "device_role",
         to = "primary",   why = "the downstream gauge"),
    list(serial = "21652372", station = "dor2_hydro", field = "device_role",
         to = "secondary", why = "9.083 m upstream, 0.524 m above"),

    # Dorothea's 2024 survey, which the first pass missed entirely
    list(serial = "21652372", station = "dor2_hydro", field = "reach_length_m",
         to = 9.083, why = "surveyed 2024, from dor2_hydro.md"),

    # Last visit on the terminal rows, from the visit chronology in the dossiers
    list(serial = "21179105", station = "fb2_hydro", field = "last_visit",
         to = "2023-03-31", why = "the visit it was removed on",
         match_deploy = "2021-10-21 11:11:00"),
    list(serial = "21180078", station = "sr1_hydro", field = "last_visit",
         to = "2024-08-21", why = "its last reading; the HOBOlink was not visited after"),
    list(serial = "21352827", station = "sr1_hydro", field = "last_visit",
         to = "2024-02-23", why = "the visit it was removed on"),
    list(serial = "21180079", station = "sr2_hydro", field = "last_visit",
         to = "2024-08-17", why = "its last reading"),
    list(serial = "21751136", station = "tr1_hydro", field = "last_visit",
         to = "2024-08-14", why = "destroyed in Ernesto; not visited after"),
    list(serial = "21652376", station = "tr2_hydro", field = "last_visit",
         to = "2024-10-22", why = "the visit the site was closed on"),
    list(serial = "21652380", station = "rb2_hydro", field = "last_visit",
         to = "2024-10-24", why = "its last offload; lost before the next visit"),
    list(serial = "21652377", station = "rb2_hydro", field = "last_visit",
         to = "2025-11-06", why = "the visit it was recovered on"),
    list(serial = "21652381", station = "dor2_hydro", field = "last_visit",
         to = "2024-10-22", why = "its last offload; lost before the next visit"),
    list(serial = "21652372", station = "dor2_hydro", field = "last_visit",
         to = "2024-06-04", why = "its last offload; lost before the next visit")
  )

  log_add <- list(
    list(date = "2025-11-06", station = "rb2_hydro", type = "hydro",
         serial = "22373557", action = "station_relocation",
         details = paste0("relocated 70 m upstream, (", RB_OLD["lat"], ", ",
                          RB_OLD["lon"], ") to (", RB_NEW["lat"], ", ",
                          RB_NEW["lon"], ")"))
  )

  ##########################################################################
  #  REPORT
  ##########################################################################

  cat("\n############################################\n")
  cat("  Prototype era metadata, second pass\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n")

  find_row <- function(x) {
    idx <- which(meta$device_serial == x$serial & meta$station_id == x$station)
    if (!is.null(x$match_deploy))
      idx <- idx[as.character(meta$deploy_datetime[idx]) == x$match_deploy]
    idx
  }

  cat("\n  Reef Bay coordinates\n")
  n_coord <- 0
  for (c in coords) {
    idx <- find_row(c)
    if (length(idx) != 1) {
      cat(sprintf("    !    %-10s no single matching row\n", c$serial)); next
    }
    was <- sprintf("%.5f, %.5f", meta$lat[idx], meta$lon[idx])
    to  <- sprintf("%.5f, %.5f", c$to["lat"], c$to["lon"])
    if (identical(was, to)) {
      cat(sprintf("    ok   %-10s already %s\n", c$serial, to)); next
    }
    cat(sprintf("    FIX  %-10s %-10s %s  ->  %s\n",
                c$serial, meta$device_name[idx], was, to))
    cat("           ", c$why, "\n", sep = "")
    n_coord <- n_coord + 1
  }

  cat("\n  Fields left empty by the first pass\n")
  n_field <- 0
  for (f in fields) {
    idx <- find_row(f)
    if (length(idx) != 1) {
      cat(sprintf("    !    %-10s %-12s %-15s no single matching row\n",
                  f$serial, f$station, f$field)); next
    }
    was <- as.character(meta[[f$field]][idx])
    if (identical(was, as.character(f$to))) {
      cat(sprintf("    ok   %-10s %-12s %-15s already %s\n",
                  f$serial, f$station, f$field, f$to)); next
    }
    cat(sprintf("    FIX  %-10s %-12s %-15s %s -> %s\n",
                f$serial, f$station, f$field, was, f$to))
    cat("           ", f$why, "\n", sep = "")
    n_field <- n_field + 1
  }

  cat("\n  maintenance_log.csv\n")
  n_log <- 0
  for (l in log_add) {
    dup <- any(as.character(as.Date(maint$field_visit_date)) == l$date &
               maint$station_id == l$station & maint$action_type == l$action)
    cat(sprintf("    ADD  %s %-11s %-22s %s%s\n", l$date, l$station,
                l$action, l$serial, if (dup) "  [PRESENT]" else ""))
    cat("           ", l$details, "\n", sep = "")
    if (!dup) n_log <- n_log + 1
  }

  #### Elevation, which nothing has ever run ####
  #
  # Computed against a table with the coordinate and role changes already
  # applied, because both affect the answer: three Reef Bay rows are about to
  # move 100 m, and four rows are about to become secondaries. Working from the
  # table as it stands would look up the wrong positions and include rows that
  # should be excluded.
  preview <- meta
  for (c in coords) {
    i <- which(preview$device_serial == c$serial & preview$station_id == c$station)
    if (length(i) == 1) { preview$lat[i] <- c$to["lat"]; preview$lon[i] <- c$to["lon"] }
  }
  for (f in fields) {
    i <- which(preview$device_serial == f$serial & preview$station_id == f$station)
    if (!is.null(f$match_deploy))
      i <- i[as.character(preview$deploy_datetime[i]) == f$match_deploy]
    if (length(i) == 1) preview[[f$field]][i] <- f$to
  }

  need_elev <- which(is.na(preview$elev) & !is.na(preview$lat) & !is.na(preview$lon))

  # A hydro secondary's elevation is NOT looked up: it is the primary's plus a
  # surveyed difference, so that the pair's difference is a measurement rather
  # than the gap between two DEM samples. Where no such survey exists - Reef
  # Bay's pair was never surveyed - the field stays empty, which is the honest
  # state rather than a DEM sample pretending to be a relative measurement.
  is_sec <- !is.na(preview$device_role) &
            preview$device_role %in% c("secondary", "tertiary")
  need_elev <- setdiff(need_elev, which(is_sec))

  cat("\n  Elevation lookup\n")
  if (!do_elevation) {
    cat("    skipped (do_elevation = FALSE)\n")
  } else if (length(need_elev) == 0) {
    cat("    nothing missing\n")
  } else {
    cat("    ", length(need_elev), " row(s) have no elev and are not hydro ",
        "secondaries:\n", sep = "")
    for (i in need_elev)
      cat(sprintf("      %-10s %-12s %-14s %.5f, %.5f\n", preview$device_serial[i],
                  preview$station_id[i], preview$station_type[i],
                  preview$lat[i], preview$lon[i]))
    cat("\n    Positions shown are the corrected ones, since the coordinate\n")
    cat("    fixes above are applied before any lookup runs.\n")
    cat("\n    Hydro secondaries are excluded: their elevation is the primary's\n")
    cat("    plus a surveyed difference, never an independent lookup. Reef Bay's\n")
    cat("    pair has no survey, so its secondary stays empty.\n")
  }

  cat("\n############################################\n")
  cat("  ", n_coord, " coordinate(s), ", n_field, " field(s), ", n_log,
      " log entr(y/ies)\n", sep = "")
  if (do_elevation) cat("  ", length(need_elev), " elevation lookup(s)\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_prototype_metadata_2(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  ##########################################################################
  #  APPLY
  ##########################################################################

  backup_metadata()
  cat("\n+ metadata backed up\n")

  for (c in coords) {
    idx <- find_row(c)
    if (length(idx) == 1) { meta$lat[idx] <- c$to["lat"]
                            meta$lon[idx] <- c$to["lon"] }
  }
  for (f in fields) {
    idx <- find_row(f)
    if (length(idx) == 1) meta[[f$field]][idx] <- f$to
  }

  # Recomputed against the table as it now is, not as it was at report time
  need_elev <- which(is.na(meta$elev) & !is.na(meta$lat) & !is.na(meta$lon))
  is_sec <- !is.na(meta$device_role) &
            meta$device_role %in% c("secondary", "tertiary")
  need_elev <- setdiff(need_elev, which(is_sec))

  if (do_elevation && length(need_elev) > 0) {
    cat("\n  Looking up ", length(need_elev), " elevation(s)...\n", sep = "")
    for (i in need_elev) {
      res <- tryCatch(lookup_elevation(meta$lat[i], meta$lon[i]),
                      error = function(e) NULL)
      if (!is.null(res) && isTRUE(res$ok)) {
        meta$elev[i] <- round(res$elev, 2)
        meta$elev_source[i] <- elevation_source_label(res)
        cat(sprintf("    + %-10s %-12s %8.2f m  %s\n", meta$device_serial[i],
                    meta$station_id[i], meta$elev[i], meta$elev_source[i]))
      } else {
        cat(sprintf("    ! %-10s %-12s lookup failed\n",
                    meta$device_serial[i], meta$station_id[i]))
      }
      Sys.sleep(0.5)   # the service is public; do not hammer it
    }
  }

  # Dorothea's secondary, once its primary has an elevation
  p <- which(meta$device_serial == "21652381" & meta$station_id == "dor2_hydro")
  s <- which(meta$device_serial == "21652372" & meta$station_id == "dor2_hydro")
  if (length(p) == 1 && length(s) == 1 && !is.na(meta$elev[p]) &&
      is.na(meta$elev[s])) {
    meta$elev[s] <- round(meta$elev[p] + 0.524, 3)
    meta$elev_source[s] <- "surveyed_relative"
    cat(sprintf("\n  + 21652372 elev %.3f m (primary plus the surveyed 0.524)\n",
                meta$elev[s]))
  }

  save_device_metadata(meta)

  for (l in log_add) {
    if (any(as.character(as.Date(maint$field_visit_date)) == l$date &
            maint$station_id == l$station & maint$action_type == l$action)) next
    suppressMessages(
      write_maintenance_entry(l$date, l$station, l$type, l$serial,
                              l$action, l$details, FALSE, "DAH"))
  }

  cat("\n+ second pass applied\n")
  cat("\nNEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. the backfill import, which fills interval_min and the record dates\n\n")

  invisible(TRUE)
}
