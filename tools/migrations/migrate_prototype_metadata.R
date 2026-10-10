# VI-FLO: metadata for the prototype era
#
# ONE-TIME MIGRATION.
#
# Ten devices recorded data for VI-FLO stations and have no metadata row. Nine
# existing rows carry a deploy_datetime belonging to a different device. Eight
# maintenance entries name the device that is there now rather than the one
# that was there then. Until these are fixed, attribution assigns years of
# readings to the wrong logger, or to none.
#
# Every value comes from a dossier in docs/backfill/, and every dossier cites
# its evidence. Nothing here is invented.
#
#
# WHY THIS IS SAFE TO ADD NOW
#
# record_confirmed marks the date each station was born to VI-FLO. Every row
# here falls before that date for its station, so it reads as reconstruction
# rather than contemporaneous record. That is what makes writing it defensible.
#
#
# HOW HOBOLINK DEVICES ARE KEYED
#
# A HOBOlink station is two serials: an RX2104 base on the bank and an
# MX2001-04-SS-S pressure sensor in the water. They separate - SR1's sensor
# survived a base replacement in August 2023.
#
# device_serial holds the SENSOR. This differs from a ZL6, where device_serial
# is the logger and its sensors live in zentra_ports.csv. No equivalent table
# exists for HOBO devices: a U20's sensor is integral, and a HOBOlink's has
# nowhere else to go. Keying on the sensor keeps the measuring instrument
# identified and the water level record in one row. Base serials are recorded
# in the maintenance log and in the dossiers.
#
#
# WHY REMOVED AND NOT DEFUNCT
#
# defunct is an ACTIVE status: broken or assumed lost, but still the station's
# device. removed is terminal - out of the field, station stands, something may
# go back in. A gauge taken by a flood is the second. That no human took it out
# is a fact for the maintenance log, not a different status.
#
# The three soil moisture boxes moved the other way, from nonresponsive to
# defunct: they ARE still in the field, dead, and nothing has replaced them.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_prototype_metadata.R"))
#   migrate_prototype_metadata()                  # dry run, by site
#   migrate_prototype_metadata(dry_run = FALSE)

migrate_prototype_metadata <- function(dry_run = TRUE) {

  or_else <- function(a, b) if (is.null(a)) b else a
  TZ <- "America/Puerto_Rico"

  meta  <- load_zentra_metadata()
  maint <- load_maintenance_log()

  ##########################################################################
  #  THE PLAN, BY SITE
  #
  #  add    - a device that recorded here and has no row
  #  fix    - a field on an existing row that is wrong
  #  logfix - a maintenance entry naming the wrong device; drop = TRUE removes
  #  log    - a maintenance entry to add
  ##########################################################################

  plan <- list(

    "Fish Bay" = list(
      add = list(
        # 21179105 was here twice. Its existing row becomes the 2024
        # downstream deployment; this is its 2021 upstream one.
        list(serial="21179105", station="fb2_hydro", name="FishBay1",
             role="secondary", mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2021-10-21 11:11:00", status="removed",
             why="upstream of FishBay2; removed 2023-03-31")
      ),
      fix = list(
        list(serial="21179105", station="fb2_hydro", field="deploy_datetime",
             to="2024-02-05 12:05:00",
             why="its 2024 redeployment downstream, inverting the pair"),
        list(serial="21179105", station="fb2_hydro", field="reach_length_m",
             to=50.687, why="surveyed 2024"),
        list(serial="21179106", station="fb2_hydro", field="reach_length_m",
             to=50.687, why="surveyed 2024"),
        list(serial="21179106", station="fb2_hydro", field="elev",
             to=3.543, why="primary's 3.29 plus the surveyed fall of 0.253"),
        list(serial="21179106", station="fb2_hydro", field="elev_source",
             to="surveyed_relative", why="as the dictionary defines it")
      ),
      log = list(
        list(date="2023-03-31", station="fb2_hydro", type="hydro",
             serial="21179105", action="device_removal",
             details="FishBay1 removed from the upstream position"),
        list(date="2024-02-05", station="fb2_hydro", type="hydro",
             serial="21179105", action="device_added",
             details="redeployed 50.687 m downstream of FishBay2, inverting the pair"),
        list(date="2024-02-05", station="fb2_hydro", type="hydro",
             serial="21179105", action="elevation_survey",
             details="reach 50.687 m, fall 0.253 m, gradient 0.5 percent"),
        list(date="2024-02-06", station="fb1_weather", type="weather",
             serial="z6-13375", action="station_relocation",
             details="relocated 1.16 km from (18.32603, -64.76368) to (18.33096, -64.77339)")
      )
    ),

    "Reef Bay" = list(
      add = list(
        list(serial="21652380", station="rb2_hydro", name="Reef Bay", role=NA,
             mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2023-09-25 10:00:00", status="removed",
             why="last read 2024-10-24, lost thereafter"),
        list(serial="21652377", station="rb2_hydro", name="ReefBay_slope", role=NA,
             mfger="HOBO", model="U20-001-01", interval=15,
             deploy="2024-02-05 09:30:00", status="removed",
             why="recovered 2025-11-06, later deployed at sgm2")
      ),
      fix = list(
        list(serial="22373557", station="rb2_hydro", field="deploy_datetime",
             to="2025-11-06 12:00:00",
             why="was the 2023 establishment; this logger arrived in 2025"),
        list(serial="22373552", station="rb2_hydro", field="deploy_datetime",
             to="2025-11-06 12:00:00",
             why="was the 2023 establishment; this logger arrived in 2025")
      ),
      logfix = list(
        list(date="2023-09-25", station="rb2_hydro", action="station_established",
             from="22373557", to="21652380",
             why="the gauge deployed that day, not its 2025 successor"),
        list(date="2023-09-25", station="rb2_hydro", action="device_added",
             from="22373552", drop=TRUE,
             why="no second device existed at Reef Bay until February 2024")
      ),
      log = list(
        list(date="2024-02-05", station="rb2_hydro", type="hydro",
             serial="21652377", action="device_added",
             details="upstream slope partner; launched at a desk 2024-02-01 17:44"),
        list(date="2024-10-24", station="rb2_hydro", type="hydro",
             serial="21652377", action="logger_relaunch",
             details="relaunched at 15 minute interval from 10"),
        list(date="2024-11-11", station="rb2_hydro", type="hydro",
             serial="21652380", action="device_removal",
             details="lost; last read 2024-10-24, a 1.2 m flood followed on 11 November"),
        list(date="2025-11-06", station="rb2_hydro", type="hydro",
             serial="21652377", action="device_removal",
             details="recovered from the old site and taken back to St Croix")
      )
    ),

    "Dorothea" = list(
      add = list(
        list(serial="21652381", station="dor2_hydro", name="Dorothea", role=NA,
             mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2023-06-14 12:38:00", status="removed",
             why="last read 2024-10-22, lost in the November storm"),
        list(serial="21652372", station="dor2_hydro", name="Dorothea slope", role=NA,
             mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2024-02-04 14:05:00", status="removed",
             why="last offload 2024-06-04, lost with its partner")
      ),
      fix = list(
        list(serial="22373551", station="dor2_hydro", field="deploy_datetime",
             to="2025-11-05 12:00:00",
             why="was the 2023 establishment; this logger arrived in 2025"),
        list(serial="22373554", station="dor2_hydro", field="deploy_datetime",
             to="2025-11-05 12:00:00",
             why="was the 2023 establishment; this logger arrived in 2025")
      ),
      logfix = list(
        list(date="2023-06-14", station="dor2_hydro", action="station_established",
             from="22373551", to="21652381",
             why="the gauge deployed that day, not its 2025 successor"),
        list(date="2023-06-14", station="dor2_hydro", action="device_added",
             from="22373554", drop=TRUE,
             why="no second device existed at Dorothea until February 2024")
      ),
      log = list(
        list(date="2024-02-04", station="dor2_hydro", type="hydro",
             serial="21652372", action="device_added",
             details="slope partner upstream; launched at a desk 2024-02-01 17:49"),
        list(date="2024-02-04", station="dor2_hydro", type="hydro",
             serial="21652372", action="elevation_survey",
             details="reach 9.083 m upstream, fall 0.524 m, gradient 5.8 percent"),
        list(date="2024-11-11", station="dor2_hydro", type="hydro",
             serial="21652381", action="device_removal",
             details="lost; 78 mm of rain, 2.03 m at Turpentine Run the same day"),
        list(date="2024-11-11", station="dor2_hydro", type="hydro",
             serial="21652372", action="device_removal",
             details="lost with its partner; one logger crushed beneath a shifted boulder"),
        list(date="2025-11-05", station="dor2_hydro", type="hydro",
             serial="22373551", action="device_added",
             details="entirely new sensors after both were lost; positions not surveyed")
      )
    ),

    "Turpentine Run" = list(
      add = list(
        list(serial="21751136", station="tr1_hydro", name="TR1 HOBOlink", role=NA,
             mfger="HOBO", model="MX2001-04-SS-S", interval=5,
             deploy="2023-06-13 16:35:00", status="removed",
             why="destroyed in Hurricane Ernesto 2024-08-14; base 21769001"),
        # TR2 has no rows at all: decommissioned before the manager existed
        list(serial="21652376", station="tr2_hydro", name="TR2", role=NA,
             mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2023-06-14 14:20:00", status="decommissioned",
             watershed="Turpentine Run", area=NA, site="tr2",
             site_full="Turpentine Run 2", lat=18.3226, lon=-64.8786,
             why="concrete channel; logger moved to TR1 on 2024-10-22")
      ),
      fix = list(
        list(serial="21652376", station="tr1_hydro", field="deploy_datetime",
             to="2024-10-22 13:16:00",
             why="was TR1's HOBOlink deployment; this logger came from TR2 that afternoon"),
        list(serial="21652374", station="tr1_hydro", field="deploy_datetime",
             to="2024-10-22 13:20:00",
             why="was TR1's HOBOlink deployment; this logger went in that afternoon")
      ),
      logfix = list(
        list(date="2023-06-13", station="tr1_hydro", action="station_established",
             from="21652374", to="21751136",
             why="the HOBOlink established the station; this U20 arrived in 2024"),
        list(date="2023-06-13", station="tr1_hydro", action="device_added",
             from="21652376", drop=TRUE,
             why="this logger was at TR2 until October 2024")
      ),
      log = list(
        list(date="2023-06-14", station="tr2_hydro", type="hydro",
             serial="21652376", action="station_established",
             details="gauge deployed in the square concrete channel"),
        list(date="2024-08-14", station="tr1_hydro", type="hydro",
             serial="21751136", action="device_removal",
             details="HOBOlink destroyed in Hurricane Ernesto at 12:15"),
        list(date="2024-10-22", station="tr2_hydro", type="hydro",
             serial="21652376", action="station_decommissioned",
             details="housing compromised; logger offloaded 13:10 and moved to TR1"),
        list(date="2024-10-22", station="tr1_hydro", type="hydro",
             serial="21652376", action="device_added",
             details="relocated from TR2 the same afternoon, downstream position"),
        list(date="2024-10-22", station="tr1_hydro", type="hydro",
             serial="21652374", action="device_added",
             details="upstream position; the pair does not sit where the HOBOlink did")
      )
    ),

    "Salt River 1" = list(
      add = list(
        list(serial="21180078", station="sr1_hydro", name="SR1 HOBOlink", role=NA,
             mfger="HOBO", model="MX2001-04-SS-S", interval=5,
             deploy="2021-11-24 14:30:00", status="removed",
             why="bases 21171527 then 21748925; last read 2024-08-21"),
        list(serial="21352827", station="sr1_hydro", name="SR1_low", role=NA,
             mfger="HOBO", model="U20-001-01", interval=10,
             deploy="2023-09-19 15:48:00", status="removed",
             why="removed 2024-02-23; Backup was better placed")
      ),
      fix = list(
        list(serial="21352826", station="sr1_hydro", field="deploy_datetime",
             to="2023-10-28 08:22:00",
             why="was the HOBOlink's first reading, two years before this logger"),
        list(serial="z6-14635", station="sr1_weather", field="deploy_datetime",
             to="2022-09-13 13:00:00",
             why="was the stream gauge's timestamp; the station's own record starts here")
      ),
      logfix = list(
        list(date="2021-11-24", station="sr1_hydro", action="station_established",
             from="21352826", to="21180078",
             why="the HOBOlink established the station; this U20 arrived in 2023"),
        list(date="2021-11-24", station="sr1_vwc3", action="station_established",
             from="z6-14635", drop=TRUE,
             why="sr1_vwc3 was established 2026-09-04; this inherited the gauge's date")
      ),
      log = list(
        list(date="2023-08-02", station="sr1_hydro", type="hydro",
             serial="21180078", action="device_replacement",
             details="HOBOlink base replaced, 21171527 to 21748925; sensor retained"),
        list(date="2023-09-19", station="sr1_hydro", type="hydro",
             serial="21352827", action="device_added",
             details="SR1_low added alongside the HOBOlink"),
        list(date="2023-10-28", station="sr1_hydro", type="hydro",
             serial="21352826", action="device_added",
             details="Backup added; three loggers at the station for four months"),
        list(date="2024-02-23", station="sr1_hydro", type="hydro",
             serial="21352827", action="device_removal",
             details="removed deliberately; Backup sat in the better position"),
        list(date="2024-08-21", station="sr1_hydro", type="hydro",
             serial="21180078", action="device_removal",
             details="HOBOlink last reading; the U20 had run alongside it eleven months"),
        list(date="2025-08-01", station="sr1_hydro", type="hydro",
             serial="21352826", action="maintenance",
             details="memory filled at 21694 readings; a month lost before the 2025-09-03 offload"),
        list(date="2026-02-01", station="sr1_hydro", type="hydro",
             serial="21352826", action="maintenance",
             details="memory filled again at 21695 readings; a month lost before 2026-03-02"),
        list(date="2026-09-04", station="sr1_vwc3", type="vwc",
             serial="z6-14635", action="station_established",
             details="New station established: Salt River 1 VWC3, on the weather logger")
      )
    ),

    "Salt River 2" = list(
      add = list(
        list(serial="21180079", station="sr2_hydro", name="SR2 HOBOlink", role=NA,
             mfger="HOBO", model="MX2001-04-SS-S", interval=5,
             deploy="2021-11-22 17:55:00", status="removed",
             why="base 21171528 throughout; battery charging failure 2024-08-17")
      ),
      fix = list(
        list(serial="21652378", station="sr2_hydro", field="deploy_datetime",
             to="2024-08-15 11:43:00",
             why="was the HOBOlink's first reading, nearly three years earlier")
      ),
      logfix = list(
        list(date="2021-11-22", station="sr2_hydro", action="station_established",
             from="21652378", to="21180079",
             why="the HOBOlink established the station; this U20 arrived in 2024")
      ),
      log = list(
        list(date="2024-08-15", station="sr2_hydro", type="hydro",
             serial="21652378", action="device_added",
             details="SR2_backup added at 15 minutes, two days before the HOBOlink failed"),
        list(date="2024-08-17", station="sr2_hydro", type="hydro",
             serial="21180079", action="device_removal",
             details="HOBOlink battery charging failure at 05:15; sensor still submerged")
      )
    ),

    "La Grange" = list(
      log = list(
        list(date="2023-12-30", station="lg1_hydro", type="hydro",
             serial="21652375", action="maintenance",
             details="memory filled at 21693 readings; a month lost before the 2024-02-01 offload")
      )
    ),

    "Bethlehem Adventure" = list(
      fix = list(
        list(serial="z6-13391", station="bta2_vwc1", field="status", to="defunct",
             why="last reading 2024-11-05; confirmed dead in the field 2026-03-02"),
        list(serial="z6-14640", station="bta2_vwc2", field="status", to="defunct",
             why="last reading 2024-09-01; confirmed dead in the field 2026-03-02")
      )
    ),

    "UVI" = list(
      fix = list(
        list(serial="z6-13376", station="uvi_vwc3", field="status", to="defunct",
             why="last reading 2025-04-16; confirmed dead in the field 2026-03-02")
      )
    ),

    "Caledonia" = list(
      fix = list(
        list(serial="z6-14637", station="cal1_weather", field="elev", to=172.05,
             why="same position as its successor, which carries this value"),
        list(serial="z6-14637", station="cal1_weather", field="elev_source",
             to="usgs_3dep_1m", why="inherited with the value")
      )
    )
  )

  ##########################################################################
  #  REPORT, BY SITE
  ##########################################################################

  cat("\n############################################\n")
  cat("  Metadata for the prototype era\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n")

  n_add <- 0; n_fix <- 0; n_log <- 0; n_logfix <- 0
  mdate <- as.character(as.Date(maint$field_visit_date))

  for (site in names(plan)) {
    p <- plan[[site]]
    cat("\n============================================\n")
    cat("  ", site, "\n", sep = "")
    cat("============================================\n")

    if (length(or_else(p$add, list())) || length(or_else(p$fix, list())))
      cat("\n  device_metadata.csv\n")

    for (a in or_else(p$add, list())) {
      dup <- any(meta$device_serial == a$serial & meta$station_id == a$station &
                 as.character(meta$deploy_datetime) == a$deploy)
      cat(sprintf("    ADD  %-10s %-11s %-15s %-20s %s%s\n", a$serial,
                  a$station, a$name, a$deploy, a$status,
                  if (dup) "  [PRESENT]" else ""))
      cat("           ", a$why, "\n", sep = "")
      if (!dup) n_add <- n_add + 1
    }

    for (f in or_else(p$fix, list())) {
      idx <- which(meta$device_serial == f$serial & meta$station_id == f$station)
      if (length(idx) != 1) {
        cat(sprintf("    !    %-10s %-11s %-16s no single matching row\n",
                    f$serial, f$station, f$field)); next
      }
      was <- as.character(meta[[f$field]][idx])
      if (identical(was, as.character(f$to))) {
        cat(sprintf("    ok   %-10s %-11s %-16s already %s\n",
                    f$serial, f$station, f$field, f$to)); next
      }
      cat(sprintf("    FIX  %-10s %-11s %-16s %s -> %s\n",
                  f$serial, f$station, f$field, was, f$to))
      cat("           ", f$why, "\n", sep = "")
      n_fix <- n_fix + 1
    }

    if (length(or_else(p$log, list())) || length(or_else(p$logfix, list())))
      cat("\n  maintenance_log.csv\n")

    for (lf in or_else(p$logfix, list())) {
      idx <- which(mdate == lf$date & maint$station_id == lf$station &
                   maint$action_type == lf$action &
                   maint$device_serial == lf$from)
      if (length(idx) == 0) {
        cat(sprintf("    ok   %s %-11s %-22s nothing matching\n",
                    lf$date, lf$station, lf$action)); next
      }
      if (isTRUE(lf$drop)) {
        cat(sprintf("    DROP %s %-11s %-22s %s\n", lf$date, lf$station,
                    lf$action, lf$from))
      } else {
        cat(sprintf("    FIX  %s %-11s %-22s %s -> %s\n", lf$date, lf$station,
                    lf$action, lf$from, lf$to))
      }
      cat("           ", lf$why, "\n", sep = "")
      n_logfix <- n_logfix + 1
    }

    for (l in or_else(p$log, list())) {
      dup <- any(mdate == l$date & maint$station_id == l$station &
                 maint$action_type == l$action & maint$device_serial == l$serial)
      cat(sprintf("    ADD  %s %-11s %-22s %s%s\n", l$date, l$station,
                  l$action, l$serial, if (dup) "  [PRESENT]" else ""))
      cat("           ", substr(l$details, 1, 64), "\n", sep = "")
      if (!dup) n_log <- n_log + 1
    }
  }

  cat("\n############################################\n")
  cat("  device_metadata:  ", n_add, " added, ", n_fix, " corrected\n", sep = "")
  cat("  maintenance_log:  ", n_log, " added, ", n_logfix,
      " corrected or dropped\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_prototype_metadata(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  ##########################################################################
  #  APPLY
  ##########################################################################

  backup_metadata()
  cat("\n+ metadata backed up\n")
  now_utc <- format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")

  # Corrections before additions, so new rows append to a corrected table
  for (site in names(plan)) for (f in or_else(plan[[site]]$fix, list())) {
    idx <- which(meta$device_serial == f$serial & meta$station_id == f$station)
    if (length(idx) == 1) meta[[f$field]][idx] <- f$to
  }

  seq_h <- suppressWarnings(as.integer(sub("^h-", "",
             meta$unique_id[grepl("^h-", meta$unique_id)])))
  nxt <- max(c(0, seq_h), na.rm = TRUE)

  for (site in names(plan)) for (a in or_else(plan[[site]]$add, list())) {
    if (any(meta$device_serial == a$serial & meta$station_id == a$station &
            as.character(meta$deploy_datetime) == a$deploy)) next
    s <- meta[meta$station_id == a$station, , drop = FALSE]
    nxt <- nxt + 1

    row <- meta[0, , drop = FALSE]; row[1, ] <- NA
    row$unique_id       <- sprintf("h-%04d", nxt)
    row$watershed       <- if (nrow(s)) s$watershed[1] else a$watershed
    row$area            <- if (nrow(s)) s$area[1]      else a$area
    row$site_full       <- if (nrow(s)) s$site_full[1] else a$site_full
    row$site            <- if (nrow(s)) s$site[1]      else a$site
    row$station_type    <- "hydro"
    row$station_id      <- a$station
    row$device_serial   <- a$serial
    row$device_role     <- a$role
    row$device_name     <- a$name
    row$mfger           <- a$mfger
    row$model           <- a$model
    row$lat             <- if (nrow(s)) s$lat[1] else a$lat
    row$lon             <- if (nrow(s)) s$lon[1] else a$lon
    row$interval_min    <- a$interval
    row$timezone        <- TZ
    row$deploy_datetime <- a$deploy
    row$status          <- a$status

    # TRUE because the configuration IS now known - that is what the dossiers
    # established. metadata_approved gates attribution, so FALSE would mean
    # this backfill never attributes to a station, which is the opposite of
    # the point of recovering it.
    row$metadata_approved <- TRUE
    row$last_reviewed_utc <- now_utc

    meta <- rbind(meta, row)
    cat("  + ", row$unique_id, "  ", a$serial, "  ", a$station, "\n", sep = "")
  }

  save_device_metadata(meta)

  #### maintenance log: corrections need a whole-file write ####
  changed <- FALSE
  mdate <- as.character(as.Date(maint$field_visit_date))
  for (site in names(plan)) for (lf in or_else(plan[[site]]$logfix, list())) {
    idx <- which(mdate == lf$date & maint$station_id == lf$station &
                 maint$action_type == lf$action & maint$device_serial == lf$from)
    if (length(idx) == 0) next
    if (isTRUE(lf$drop)) {
      maint <- maint[-idx, , drop = FALSE]
      mdate <- mdate[-idx]
    } else {
      maint$device_serial[idx] <- lf$to
    }
    changed <- TRUE
  }
  if (changed) {
    write.csv(maint, file.path(wds("meta_internal"), "maintenance_log.csv"),
              row.names = FALSE)
    cat("+ maintenance log corrected\n")
  }

  #### additions use the normal appender ####
  for (site in names(plan)) for (l in or_else(plan[[site]]$log, list())) {
    if (any(as.character(as.Date(maint$field_visit_date)) == l$date &
            maint$station_id == l$station & maint$action_type == l$action &
            maint$device_serial == l$serial)) next
    suppressMessages(
      write_maintenance_entry(l$date, l$station, l$type, l$serial,
                              l$action, l$details, FALSE, "DAH"))
  }

  cat("\n+ ", n_add, " row(s) added, ", n_fix, " field(s) corrected\n", sep = "")
  cat("+ ", n_log, " log entr(ies) added, ", n_logfix,
      " corrected or dropped\n", sep = "")

  cat("\nNEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. the backfill import, which needs these rows to exist\n\n")

  invisible(TRUE)
}
