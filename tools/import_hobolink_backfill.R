# VI-FLO: the HOBOlink telemetry backfill
#
# ONE-TIME TOOL. Delete once the prototype era is closed.
#
# Six exports from the three HOBOlink stations, holding 781,506 readings at a
# five minute interval. They are the whole of Salt River 1's and Salt River
# 2's 2021-2024 record and Turpentine Run 1's 2023-2024 record - not a
# remainder, but the larger part of what those stations ever produced.
#
#
# WHY THESE NEED THEIR OWN READER
#
# A U20 export is a plot title, a header and three columns. A HOBOlink export
# is a flat CSV of five measurements, and the differences matter:
#
#   - two serials per file, a base on the bank and a sensor in the water
#   - the column ORDER varies between files from the same station
#   - the sensor codes, not the positions, say what each column holds
#   - a barometric pressure and a computed water level the U20s never had
#   - five minute logging, not ten or fifteen
#
#
# HOW A FILE IS KEYED
#
# device_serial is the SENSOR, taken from the water pressure column's header:
#
#   "Water Pressure (M-WP04 21171527:21180078-1), kPa, Salt River 1"
#                            ^base    ^sensor
#
# Salt River 1's base was replaced on 2023-08-02 and the sensor stayed in the
# water. Keying on the base would split one continuous record in two; keying
# on the sensor keeps it whole and makes the base change a maintenance entry,
# which is what it was.
#
#
# WHAT IS KEPT, AND WHAT PRODUCT 2 WILL DO WITH IT
#
# Everything is kept, including the station's own barometric pressure and its
# computed water level. Product 1 records what the instrument returned.
#
# Product 2 will RECOMPUTE level from water pressure rather than carry the
# computed column, so that every station in the network is derived the same
# way and the barometric source follows VI-FLO's own rules rather than
# whatever happened to be wired to that base. The computed column stays in
# Product 1 as a check against that recomputation.
#
#
# THE RIVER FILE
#
# river_hydro_20230801-20240821.csv is a prototype site that does not carry
# forward. It is imported anyway, keyed by its sensor 21751137, and stays at
# Product 1 unattributed: there is no metadata row, no station, and no way to
# derive discharge from stage alone. Keeping it costs nothing and discarding
# it would be irreversible. Pass include_river = FALSE to leave it out.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/import_hobolink_backfill.R"))
#   import_hobolink_backfill("C:/path/to/vi-flo-prototype")
#   import_hobolink_backfill("C:/path/to/vi-flo-prototype", dry_run = FALSE)

import_hobolink_backfill <- function(folder, dry_run = TRUE,
                                     include_river = TRUE) {

  TZ <- "America/Puerto_Rico"

  cat("\n############################################\n")
  cat("  The HOBOlink telemetry backfill\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("############################################\n\n")

  if (!dir.exists(folder)) {
    cat("X No folder at ", folder, "\n\n", sep = ""); return(invisible(FALSE))
  }

  files <- list.files(folder, pattern = "\\.csv$", full.names = TRUE,
                      recursive = TRUE, ignore.case = TRUE)
  if (length(files) == 0) {
    cat("X No CSVs under ", folder, "\n\n", sep = ""); return(invisible(FALSE))
  }

  out_dir  <- wds("device_hobo")
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog     <- read.csv(log_file, stringsAsFactors = FALSE)
  held     <- basename(dlog$filepath)

  #### What each sensor code means ####
  #
  # Read from the header, never from the column position: the barometric
  # column is third in one Salt River 1 file and sixth in the other.
  CODES <- c("M-BP"   = "barometric_kpa",
             "M-WP"   = "water_pressure_kpa",
             "M-DP"   = "diff_pressure_kpa",
             "M-WT"   = "water_temp_c",
             "M-WL"   = "water_level_m")

  plan <- list(); skipped <- list()

  for (f in files) {
    bn <- basename(f)

    hdr <- tryCatch(readLines(f, n = 1, warn = FALSE, encoding = "latin1"),
                    error = function(e) character(0))
    if (length(hdr) == 0) next

    # A HOBOlink export announces itself: Line#, a Date, and M- sensor codes
    if (!grepl("^Line#", hdr) || !grepl("M-WP", hdr)) next

    if (!include_river && grepl("^river_", bn, ignore.case = TRUE)) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "river, excluded")
      next
    }

    raw <- tryCatch(read.csv(f, stringsAsFactors = FALSE, check.names = FALSE,
                             fileEncoding = "latin1"),
                    error = function(e) NULL)
    if (is.null(raw) || nrow(raw) == 0) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "could not be read")
      next
    }

    cols <- names(raw)

    #### A combined export covers several stations and is not usable here ####
    #
    # Seven files hold all four sensor pairs at once - SR1, SR2, TR1 and
    # River in one table. This reader keys a file by its single water
    # pressure column, so a combined file would be filed under whichever
    # station happened to come first.
    #
    # They are skipped rather than parsed because the per-station exports
    # already cover everything in them: the combined files stop by March 2024
    # at the latest, the per-station ones run to August.
    pairs <- unique(unlist(regmatches(cols,
               gregexpr("[0-9]{8}:[0-9]{8}", cols))))
    sensors <- unique(sub("^[0-9]{8}:", "", pairs))
    if (length(sensors) > 2) {
      skipped[[length(skipped)+1]] <- list(f = bn,
        why = paste0("combined export, ", length(sensors),
                     " stations - superseded by the per-station files"))
      next
    }

    #### The two serials, from the water pressure column ####
    wp <- grep("M-WP", cols, value = TRUE)[1]
    pair <- regmatches(wp, regexec("M-WP[0-9]*\\s+([0-9]+):([0-9]+)", wp))[[1]]
    if (length(pair) < 3) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no serial pair in the header")
      next
    }
    base_sn <- pair[2]; sensor_sn <- pair[3]

    #### Rename the measurement columns by their sensor code ####
    nice <- cols
    for (code in names(CODES)) {
      hit <- grep(paste0("\\(", code), cols)
      if (length(hit) == 1) nice[hit] <- CODES[[code]]
    }
    date_at <- grep("^Date$", cols)[1]
    if (is.na(date_at)) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no Date column"); next
    }
    nice[date_at] <- "datetime"
    line_at <- grep("^Line#$", cols)[1]
    if (!is.na(line_at)) nice[line_at] <- "line_no"
    names(raw) <- nice

    #### Timestamps ####
    #
    # "11/24/21 14:30:00" - project local, as every reading time is. HOBOlink
    # exports carry no zone marker, so this is asserted rather than read, and
    # it is asserted because the station was in the Virgin Islands.
    when <- suppressWarnings(as.POSIXct(raw$datetime, format = "%m/%d/%y %H:%M:%S",
                                        tz = TZ))
    for (fmt in c("%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M", "%m/%d/%y %H:%M")) {
      if (!all(is.na(when))) break
      when <- suppressWarnings(as.POSIXct(raw$datetime, format = fmt, tz = TZ))
    }
    good <- !is.na(when)
    if (!any(good)) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no timestamps parsed")
      next
    }
    raw$datetime <- when

    u  <- sort(unique(when[good]))
    iv <- NA_real_
    if (length(u) > 2) {
      g <- as.numeric(diff(u), units = "mins"); g <- g[g > 0]
      if (length(g)) iv <- as.numeric(names(which.max(table(round(g, 3)))))
    }

    fname <- paste0(sensor_sn, "_", format(min(u), "%Y%m%d", tz = TZ), "_",
                    format(max(u), "%Y%m%d", tz = TZ), "_raw.rds")

    plan[[length(plan)+1]] <- list(
      src = f, file = bn, sn = sensor_sn, base = base_sn, fname = fname,
      data = raw, first = min(u), last = max(u), n = length(u), interval = iv,
      vars = intersect(unname(CODES), names(raw)),
      already = fname %in% held || file.exists(file.path(out_dir, fname)))
  }

  if (length(skipped)) {
    cat("Set aside\n\n")
    for (s in skipped) cat(sprintf("    %-44s %s\n", substr(s$f, 1, 44), s$why))
    cat("\n")
  }

  if (length(plan) == 0) {
    cat("No HOBOlink exports found.\n\n"); return(invisible(FALSE))
  }

  #### Overlaps within a sensor ####
  #
  # A file whose whole span sits inside another's is an earlier, shorter
  # export of the same record - sr2_rawlevel.csv against the full Salt River 2
  # file - and is dropped. A partial overlap at the seam is normal and is
  # left alone; the duplicate timestamps go at regularisation.
  superseded <- list(); drop <- rep(FALSE, length(plan))

  for (sn in unique(vapply(plan, function(p) p$sn, ""))) {
    ii <- which(vapply(plan, function(p) p$sn, "") == sn)
    for (a in ii) for (b in ii) {
      if (a == b || drop[a] || drop[b]) next
      A <- plan[[a]]; B <- plan[[b]]
      if (B$first >= A$first && B$last <= A$last && B$n <= A$n) {
        drop[b] <- TRUE
        superseded[[length(superseded)+1]] <- list(drop = B$file, by = A$file)
      }
    }
  }

  if (length(superseded)) {
    cat("\nSuperseded - an earlier export of the same record\n\n")
    for (x in superseded)
      cat(sprintf("    %-40s is contained in %s\n", substr(x$drop, 1, 40), x$by))
  }
  plan <- plan[!drop]

  for (sn in unique(vapply(plan, function(p) p$sn, ""))) {
    ii <- which(vapply(plan, function(p) p$sn, "") == sn)
    ii <- ii[order(vapply(plan[ii], function(p) as.numeric(p$first), 0))]
    for (k in seq_len(max(0, length(ii) - 1))) {
      a <- plan[[ii[k]]]; b <- plan[[ii[k+1]]]
      if (b$first < a$last) {
        cat(sprintf("\n  seam: %s and %s overlap %.1f h\n", a$file, b$file,
                    as.numeric(difftime(a$last, b$first, units = "hours"))))
      }
    }
  }

  #### Report ####
  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
  ord <- order(vapply(plan, function(p) p$sn, ""),
               vapply(plan, function(p) as.numeric(p$first), 0))

  cat("To import\n\n")
  last_sn <- ""; n_new <- 0
  for (i in ord) {
    p <- plan[[i]]
    if (p$sn != last_sn) {
      where <- if (!is.null(meta))
        paste(unique(meta$station_id[meta$device_serial == p$sn]), collapse = ", ")
      else ""
      if (!nzchar(where)) where <- "(no metadata row - stays unattributed)"
      cat("\n  sensor ", p$sn, "   ", where, "\n", sep = "")
      last_sn <- p$sn
    }
    cat(sprintf("    %-40s %s to %s  %7d  %sm  base %s%s\n",
                substr(p$file, 1, 40), format(p$first, "%Y-%m-%d"),
                format(p$last, "%Y-%m-%d"), p$n, format(p$interval), p$base,
                if (p$already) "   [ALREADY HELD]" else ""))
    cat("        ", paste(p$vars, collapse = ", "), "\n", sep = "")
    if (!p$already) n_new <- n_new + 1
  }

  cat("\n############################################\n")
  cat("  ", n_new, " of ", length(plan), " file(s) to write   ",
      format(sum(vapply(plan, function(p) p$n, 0)), big.mark = ","),
      " readings\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to import:\n")
    cat("  import_hobolink_backfill(\"", folder, "\", dry_run = FALSE)\n\n",
        sep = "")
    return(invisible(TRUE))
  }

  if (n_new == 0) {
    cat("\n+ Everything is already in Product 1.\n\n"); return(invisible(TRUE))
  }

  #### Write ####
  bdir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(bdir)) dir.create(bdir, recursive = TRUE)
  file.copy(log_file, file.path(bdir, paste0("download_log_",
            format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")))
  cat("\n+ download_log backed up\n")

  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")
  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  done <- 0

  for (i in ord) {
    p <- plan[[i]]
    if (p$already) next

    saveRDS(p$data, file.path(out_dir, p$fname))
    rel <- sub(paste0("^", data_root, "/?"), "",
               gsub("\\\\", "/", file.path(out_dir, p$fname)))

    entry <- data.frame(
      timestamp_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      run_id        = stamp,
      station       = NA_character_,
      device_serial = p$sn,
      start_date    = format(p$first, "%Y-%m-%d %H:%M:%S", tz = TZ),
      end_date      = format(p$last,  "%Y-%m-%d %H:%M:%S", tz = TZ),
      n_records     = p$n,
      filepath      = rel,
      download_type = "manual",
      stringsAsFactors = FALSE)
    for (col in setdiff(names(dlog), names(entry))) entry[[col]] <- NA
    entry <- entry[, names(dlog), drop = FALSE]
    dlog <- rbind(dlog, entry)

    done <- done + 1
    cat("  + ", p$fname, "\n", sep = "")
  }

  write.csv(dlog, log_file, row.names = FALSE)
  cat("\n+ ", done, " file(s) imported\n", sep = "")

  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))
  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (x in head(check$filepath[missing], 10)) cat("   ", x, "\n", sep = "")
    return(invisible(FALSE))
  }
  cat("+ verified: all ", nrow(check), " logged filepath(s) resolve\n", sep = "")

  if (exists("update_hobo_device_facts"))
    update_hobo_device_facts(unique(vapply(plan, function(p) p$sn, "")))

  cat("\nNEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. delete this tool and import_hobo_backfill.R - the prototype era\n")
  cat("     is closed once these are in\n\n")

  invisible(TRUE)
}
