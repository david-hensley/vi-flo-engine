# VI-FLO: the prototype HOBO backfill
#
# ONE-TIME TOOL.
#
# Brings the prototype archive's U20 exports into Product 1. Each file is read,
# its serial taken from the column headers, and written under the Product 1
# naming convention with a download_log row.
#
#
# THE SERIAL COMES FROM THE HEADER, NEVER THE FILENAME
#
# Seven files are named RB-2021* and RB-2022* and contain serial 21179105 under
# the HOBOware plot title FishBay1. They are Fish Bay's upstream logger, not
# Reef Bay's. Reading the filename would file two years of one site's record
# under another, which is how the confusion arose in the first place.
#
#
# ONE FILE IS REFUSED
#
# sr1backup_hydro_20230919-20231128.csv declares serial 21352827 in its header
# and holds 2,023 readings from 21352826 in its lower half, where the line
# numbering restarts and the timestamp offset shifts. Device-keyed naming
# cannot catch that, because the header lies. Nothing is lost by refusing it:
# every reading it holds exists in sr1low_hydro_20230919-20231128.csv or
# sr1backup_hydro_20231028-20231128.csv.
#
#
# HOBOLINK FILES ARE SKIPPED
#
# Six level exports and seven weather exports come from HOBOlink telemetry
# stations: five minute interval, their own barometric pressure, and a computed
# water level alongside the raw. They need a different reader and a decision
# about which level to carry forward. Reported, not imported.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/import_hobo_backfill.R"))
#   import_hobo_backfill("C:/path/to/vi-flo-prototype")
#   import_hobo_backfill("C:/path/to/vi-flo-prototype", dry_run = FALSE)

REFUSED_FILES <- c("sr1backup_hydro_20230919-20231128.csv")

import_hobo_backfill <- function(folder, dry_run = TRUE) {

  cat("\n############################################\n")
  cat("  The prototype HOBO backfill\n")
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
  cat("Scanning ", length(files), " file(s)...\n\n", sep = "")

  out_dir    <- wds("device_hobo")
  project_tz <- "America/Puerto_Rico"
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog     <- read.csv(log_file, stringsAsFactors = FALSE)
  held     <- basename(dlog$filepath)

  plan <- list(); skipped <- list()

  for (f in files) {
    bn <- basename(f)

    if (bn %in% REFUSED_FILES) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "refused - mixed serials")
      next
    }

    # Latin-1, because of the degree symbol in "Temp, °C". Read as UTF-8 it
    # becomes an untranslatable string, grepl returns NA, the header is not
    # found and the file is silently set aside - which quietly dropped the
    # seven FishBay1 files this importer exists to handle.
    lines <- tryCatch(readLines(f, n = 4, warn = FALSE, encoding = "latin1"),
                      error = function(e) character(0))
    if (length(lines) < 2) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "unreadable"); next
    }

    # HOBOware writes a plot-title line above the header, which read.csv treats
    # as a one-field header over four-field rows and errors on. Find the real
    # header rather than assuming.
    hdr_at <- which(grepl("date\\s*time|timestamp", lines,
                          ignore.case = TRUE, useBytes = TRUE))[1]
    if (is.na(hdr_at)) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no header line"); next
    }

    head_txt <- paste(lines, collapse = " ")

    if (grepl("Water Pressure|Barometric Pressure", head_txt)) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "HOBOlink - needs its own reader")
      next
    }

    sns <- unique(regmatches(head_txt,
             gregexpr("(?<=LGR S/N: )\\d+", head_txt, perl = TRUE))[[1]])
    if (length(sns) == 0) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no serial in the header")
      next
    }
    sn <- sns[1]

    raw <- tryCatch(read.csv(f, stringsAsFactors = FALSE, check.names = FALSE,
                             skip = hdr_at - 1, fileEncoding = "latin1"),
                    error = function(e) NULL)
    if (is.null(raw) || nrow(raw) == 0) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "could not be read"); next
    }

    long <- tryCatch(hobo_to_long(raw, sn), error = function(e) NULL)
    if (is.null(long) || nrow(long) == 0) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no measurements found")
      next
    }

    when <- sort(unique(long$datetime))
    when <- when[!is.na(when)]
    if (length(when) == 0) {
      skipped[[length(skipped)+1]] <- list(f = bn, why = "no timestamps parsed")
      next
    }

    iv <- NA_real_
    if (length(when) > 2) {
      g <- as.numeric(diff(when), units = "mins"); g <- g[g > 0]
      if (length(g)) iv <- as.numeric(names(which.max(table(round(g, 3)))))
    }

    # PROJECT LOCAL, not UTC. A filename's span dates are reading times, and
    # the dictionary puts reading times in local - the same as start_date and
    # end_date in the log, which these must agree with. Only the fetch stamp
    # is UTC, because a run can be triggered from anywhere.
    fname <- paste0(sn, "_", format(min(when), "%Y%m%d", tz = project_tz), "_",
                    format(max(when), "%Y%m%d", tz = project_tz), "_raw.rds")

    plan[[length(plan)+1]] <- list(
      src = f, file = bn, sn = sn, fname = fname, data = raw,
      first = min(when), last = max(when), n = length(when), interval = iv,
      already = fname %in% held || file.exists(file.path(out_dir, fname)))
  }

  #### What was set aside ####
  if (length(skipped)) {
    cat("Set aside\n\n")
    by <- split(vapply(skipped, function(s) s$f, ""),
                vapply(skipped, function(s) s$why, ""))
    for (why in names(by)) {
      cat("  ", why, " (", length(by[[why]]), ")\n", sep = "")
      for (n in sort(by[[why]])) cat("      ", n, "\n", sep = "")
    }
    cat("\n")
  }

  if (length(plan) == 0) {
    cat("Nothing to import.\n\n"); return(invisible(FALSE))
  }

  #### Duplicates: the same readings under different names ####
  #
  # The prototype folder holds working copies alongside the archive - test.csv,
  # TR2_1.csv, RB_1.csv and others. A file is a duplicate when its serial,
  # span and reading count all match another's. The conventionally named one
  # is kept.
  conventional <- function(n) grepl("^[a-z0-9]+_hydro_\\d{8}-\\d{8}\\.csv$", n)

  # To the minute, because the same export exists at two precisions. The copies
  # in Old/Hobo downloads were saved as "10/21/2021 11:11" and those in
  # Raw-level as "10/21/21 11:11:59 AM" - identical readings, timestamps 59
  # seconds apart. Comparing to the second treats them as different files.
  to_min <- function(t) format(as.POSIXct(trunc(t, "mins")), "%Y-%m-%d %H:%M")

  key <- vapply(plan, function(p) paste(p$sn, to_min(p$first), to_min(p$last),
                                        p$n), "")
  dups <- list()
  keep <- rep(TRUE, length(plan))
  for (k in unique(key[duplicated(key)])) {
    grp <- which(key == k)
    # Prefer the copy that kept its seconds: it is the fuller record, and the
    # minute-precision copies lose information that cannot be recovered.
    has_secs <- vapply(plan[grp], function(p)
                       as.integer(format(p$first, "%S")) != 0, logical(1))
    best <- grp[order(!has_secs,
                      !conventional(vapply(plan[grp], function(p) p$file, "")),
                      nchar(vapply(plan[grp], function(p) p$file, "")))][1]
    for (i in setdiff(grp, best)) {
      keep[i] <- FALSE
      dups[[length(dups)+1]] <- list(drop = plan[[i]]$file,
                                     kept = plan[[best]]$file)
    }
  }

  if (length(dups)) {
    cat("Duplicates, same serial and span and reading count\n\n")
    for (d in dups)
      cat(sprintf("    %-42s is a copy of %s\n", substr(d$drop, 1, 42), d$kept))
    cat("\n  Where one copy keeps its seconds and the other does not, the\n")
    cat("  fuller one is kept.\n")
    cat("\n")
  }
  plan <- plan[keep]

  #### Overlaps: different files covering the same period ####
  #
  # Not duplicates - genuinely different reading counts over overlapping spans,
  # which usually means one file is a merge of several. Importing both would
  # double-count, so these are reported and nothing is written until resolved.
  overlaps <- list()
  for (sn in unique(vapply(plan, function(p) p$sn, ""))) {
    ii <- which(vapply(plan, function(p) p$sn, "") == sn)
    ii <- ii[order(vapply(plan[ii], function(p) as.numeric(p$first), 0))]
    if (length(ii) < 2) next
    for (a in seq_len(length(ii) - 1)) for (b in (a+1):length(ii)) {
      p <- plan[[ii[a]]]; q <- plan[[ii[b]]]
      if (q$first >= p$last - 60) next        # clean seam, nothing to say

      # Consecutive offloads often overlap by hours: a logger read in the
      # morning and relaunched that afternoon carries readings from both sides
      # of the visit. Those duplicate timestamps are dropped at regularisation
      # and need no intervention here.
      #
      # Containment is different. One file holding another's whole span means
      # a merged export sitting beside its parts, and importing both would
      # double-count readings that regularisation cannot tell apart.
      contained <- q$last <= p$last
      overlaps[[length(overlaps)+1]] <-
        list(sn = sn, a = p, b = q, blocking = contained)
    }
  }

  blocking <- Filter(function(o) isTRUE(o$blocking), overlaps)
  seams    <- Filter(function(o) !isTRUE(o$blocking), overlaps)

  if (length(seams)) {
    cat("Overlapping at the seam, which is normal\n\n")
    for (o in seams)
      cat(sprintf("    %-9s %-38s and %s overlap %.1f h\n", o$sn,
                  substr(o$a$file, 1, 38), substr(o$b$file, 1, 30),
                  as.numeric(difftime(o$a$last, o$b$first, units = "hours"))))
    cat("\n  A logger read in the morning and relaunched that afternoon\n")
    cat("  carries readings either side of the visit. The duplicates are\n")
    cat("  dropped at regularisation.\n\n")
  }

  if (length(blocking)) {
    cat("! One file contains another - these would double-count\n\n")
    for (o in blocking) {
      cat(sprintf("    %s\n", o$sn))
      cat(sprintf("      %-40s %s to %s  %d\n", substr(o$a$file, 1, 40),
                  format(o$a$first, "%Y-%m-%d %H:%M"),
                  format(o$a$last, "%Y-%m-%d %H:%M"), o$a$n))
      cat(sprintf("      %-40s %s to %s  %d\n", substr(o$b$file, 1, 40),
                  format(o$b$first, "%Y-%m-%d %H:%M"),
                  format(o$b$last, "%Y-%m-%d %H:%M"), o$b$n))
    }
    cat("\n  Nothing will be written until these are resolved.\n\n")
  }

  #### To import, by serial ####
  cat("To import, by device\n\n")
  order_by <- order(vapply(plan, function(p) p$sn, ""),
                    vapply(plan, function(p) as.numeric(p$first), 0))
  last_sn <- ""
  n_new <- 0
  for (i in order_by) {
    p <- plan[[i]]
    if (p$sn != last_sn) {
      m <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
      where <- if (!is.null(m)) paste(unique(m$station_id[m$device_serial == p$sn]),
                                      collapse = ", ") else ""
      cat("\n  ", p$sn, "   ", where, "\n", sep = "")
      last_sn <- p$sn
    }
    cat(sprintf("    %-42s %s to %s  %6d  %sm%s\n", substr(p$file, 1, 42),
                format(p$first, "%Y-%m-%d"), format(p$last, "%Y-%m-%d"),
                p$n, format(p$interval),
                if (p$already) "   [ALREADY HELD]" else ""))
    if (!p$already) n_new <- n_new + 1
  }

  cat("\n############################################\n")
  cat("  ", n_new, " of ", length(plan), " file(s) to write\n", sep = "")
  cat("############################################\n")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to import:\n")
    cat("  import_hobo_backfill(\"", folder, "\", dry_run = FALSE)\n\n", sep = "")
    return(invisible(TRUE))
  }

  if (length(blocking) > 0) {
    cat("\nX A file contains another's whole span. Resolve and re-run.\n\n")
    return(invisible(FALSE))
  }

  # Nothing to write does not mean nothing to do. The device facts are
  # computed from the readings, not from what this run imported, so they are
  # refreshed either way - which is what makes it safe to clear them in a
  # migration and let a second pass of this tool fill them again.
  if (n_new == 0) {
    cat("\n+ Everything is already in Product 1.\n")
    update_hobo_device_facts(unique(vapply(plan, function(p) p$sn, "")))
    cat("\n")
    return(invisible(TRUE))
  }

  #### Write ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  file.copy(log_file, file.path(backup_dir,
    paste0("download_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")))
  cat("\n+ download_log backed up\n")

  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")
  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  done <- 0

  for (i in order_by) {
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
      start_date    = format(p$first, "%Y-%m-%d %H:%M:%S", tz = project_tz),
      end_date      = format(p$last,  "%Y-%m-%d %H:%M:%S", tz = project_tz),
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

  #### Verify every logged path resolves ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))
  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in head(check$filepath[missing], 10)) cat("   ", f, "\n", sep = "")
    cat("\n  Restore from metadata/internal/backups/\n\n")
    return(invisible(FALSE))
  }
  cat("+ verified: all ", nrow(check), " logged filepath(s) resolve\n", sep = "")

  #### Facts the data knows and metadata does not ####
  #
  # interval_min and last_record_date were left empty by the migrations,
  # deliberately: they are measurable only from the readings. Now that the
  # readings are here, they are written from the timestamps rather than
  # asserted.
  update_hobo_device_facts(unique(vapply(plan, function(p) p$sn, "")))

  cat("\nNEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. the HOBOlink files, which need their own reader\n\n")

  invisible(TRUE)
}


#' Write the last record and download dates, per deployment
#'
#' A device can serve two stations over its life - 21652376 was at Turpentine
#' Run 2 and then Turpentine Run 1, six minutes apart on the same afternoon.
#' Each metadata row is one deployment, and reaches only as far as the readings
#' taken during it.
#'
#' A deployment ends at whichever comes FIRST: the day the device left that
#' station (last_visit, for a terminal row), or the moment the next deployment
#' began. Either alone is wrong. Closing at the next deployment charges a
#' recovered logger's desk readings to the station it came out of; closing at
#' last_visit alone charges a same-day handover's first evening to the station
#' it left.
#'
#' interval_min is deliberately NOT written. That field carries the DECLARED
#' interval - what the logger was set to at its last relaunch, recorded through
#' the metadata manager. The observed interval belongs to the data, and the
#' network memory check reads it there, because a declared fifteen against an
#' actual ten is what cost Salt River and La Grange a month each.
#'
#' @param serials Character vector of device serials
#' @return Invisible TRUE
update_hobo_device_facts <- function(serials) {

  TZ <- "America/Puerto_Rico"
  TERMINAL <- c("removed", "replaced", "relocated", "decommissioned")

  meta <- load_zentra_metadata()
  dl   <- tryCatch(load_download_log(), error = function(e) NULL)

  # Readings are UTC; metadata times are local. Comparing them is correct -
  # POSIXct is an absolute instant - but R warns when the tzone attributes
  # differ. Normalising everything to UTC keeps the same instants and silences
  # a warning that would otherwise hide a real one.
  as_utc <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "UTC"; x }

  parse_local <- function(x) as_utc(suppressWarnings(as.POSIXct(x, tz = TZ)))

  cat("\n  Facts from the data, per deployment\n\n")
  changed <- 0

  for (sn in serials) {

    f <- list.files(wds("device_hobo"), pattern = paste0("^", sn, "_"),
                    full.names = TRUE)
    when <- as_utc(character(0))
    if (length(f)) {
      when <- sort(unique(do.call(c, lapply(f, function(p) {
        l <- tryCatch(hobo_to_long(readRDS(p), sn), error = function(e) NULL)
        if (is.null(l)) return(as.POSIXct(character(0))) else as_utc(l$datetime)
      }))))
      when <- when[!is.na(when)]
    }

    # When the download RAN, from the log's UTC timestamp - not the last
    # reading in the file. The dictionary defines last_download_date as the
    # datetime of the last successful download, and for a hand offload those
    # differ by however long the walk back took.
    #
    # Each download is kept with the span it covers, so a download can be
    # placed in the right deployment window by its data rather than by when
    # someone got round to running it.
    runs <- data.frame(at = as_utc(character(0)),
                       covers = as_utc(character(0)))
    if (!is.null(dl) && nrow(dl) > 0) {
      mine <- dl$device_serial == sn
      if (any(mine)) {
        at     <- as_utc(suppressWarnings(as.POSIXct(dl$timestamp_utc[mine],
                                                     tz = "UTC")))
        covers <- parse_local(dl$end_date[mine])
        keep   <- !is.na(at) & !is.na(covers)
        runs   <- data.frame(at = at[keep], covers = covers[keep])
      }
    }

    idx <- which(meta$device_serial == sn)
    if (length(idx) == 0) next
    starts <- parse_local(meta$deploy_datetime[idx])
    idx    <- idx[order(starts)]
    starts <- sort(starts)

    for (k in seq_along(idx)) {
      i <- idx[k]
      from <- starts[k]
      if (is.na(from)) next

      # Whichever boundary comes first
      bounds <- as_utc(character(0))
      if (k < length(idx)) bounds <- c(bounds, starts[k + 1])
      if (tolower(meta$status[i]) %in% TERMINAL &&
          !is.na(meta$last_visit[i]) &&
          nzchar(as.character(meta$last_visit[i])))
        bounds <- c(bounds, parse_local(paste(as.character(meta$last_visit[i]),
                                              "23:59:59")))
      to <- if (length(bounds)) min(bounds) else as_utc(Sys.time())

      note <- character(0)

      mine <- when[when >= from & when < to]
      if (length(mine)) {
        lr <- format(mine[length(mine)], "%Y-%m-%d %H:%M:%S", tz = TZ)
        if (!identical(as.character(meta$last_record_date[i]), lr)) {
          meta$last_record_date[i] <- lr
          note <- c(note, paste0("record ", substr(lr, 1, 10)))
          changed <- changed + 1
        }
      }

      in_win <- runs$covers >= from & runs$covers < to
      if (any(in_win)) {
        ld <- format(max(runs$at[in_win]), "%Y-%m-%d %H:%M:%S", tz = TZ)
        if (!identical(as.character(meta$last_download_date[i]), ld)) {
          meta$last_download_date[i] <- ld
          note <- c(note, paste0("download ", ld))
          changed <- changed + 1
        }
      }

      cat(sprintf("    %-10s %-12s %s to %s   %5d readings   %s\n",
                  sn, meta$station_id[i], format(from, "%Y-%m-%d", tz = TZ),
                  format(to, "%Y-%m-%d", tz = TZ), length(mine),
                  if (length(note)) paste(note, collapse = ", ") else "unchanged"))
    }
  }

  if (changed > 0) {
    save_device_metadata(meta)
    cat("\n  + ", changed, " value(s) written\n", sep = "")
  } else {
    cat("\n  nothing to change\n")
  }

  invisible(TRUE)
}
