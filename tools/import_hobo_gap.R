# VI-FLO: the stranded HOBO offloads
#
# ONE-TIME TOOL.
#
# Nine shuttle offloads were made and never ingested - four at St Croix on
# 2025-09-03, five at St Thomas and St John in November 2025. They sat in
# folders outside the data root while the archive recorded a five to six month
# hole at every one of those loggers.
#
# The loggers themselves never stopped. The gap was in the filing.
#
#
# NO FIELD VISITS ARE LOGGED
#
# These predate VI-FLO's maintenance log, and reconstructing who went and what
# else was done would be inventing it. They are ingested as data only:
# Product 1 files and download_log rows, nothing in the maintenance log. That
# the record keeping of this era was thinner is what record_confirmed.csv
# exists to say.
#
#
# STATION IS LEFT BLANK
#
# Product 1 is device-keyed and applies no attribution - which matters more
# than usual here, because at least one of these loggers has since moved site.
# 21652377 recorded at Reef Bay through November 2025 and now sits at
# sgm2_hydro, and metadata holds no row for its Reef Bay years. Writing a
# station into the log would assert something attribution would then
# contradict.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/import_hobo_gap.R"))
#   import_hobo_gap("C:/Users/david/Desktop/hobo_gap")

import_hobo_gap <- function(folder, dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Importing the stranded HOBO offloads\n")
  if (dry_run) cat("  DRY RUN - nothing will be written\n")
  cat("============================================\n\n")

  if (!dir.exists(folder)) {
    cat("X No folder at ", folder, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  files <- list.files(folder, pattern = "\\.csv$", full.names = TRUE,
                      ignore.case = TRUE)
  if (length(files) == 0) {
    cat("X No CSVs in ", folder, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  out_dir  <- wds("device_hobo")
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog     <- read.csv(log_file, stringsAsFactors = FALSE)
  existing <- basename(dlog$filepath)

  plan <- list()
  problems <- character(0)

  for (f in files) {
    # HOBOware writes a plot-title line above the header - "Plot Title:
    # Adventure" - which is one field where the rows below have four. read.csv
    # does not merely mis-parse that, it errors, so the header line is found
    # first and the read told where to start.
    head_lines <- tryCatch(readLines(f, n = 5, warn = FALSE),
                           error = function(e) character(0))

    hdr_at <- which(grepl("date\\s*time|timestamp", head_lines,
                          ignore.case = TRUE))[1]
    if (is.na(hdr_at)) {
      problems <- c(problems, paste(basename(f), "- no header line found"))
      next
    }

    raw <- tryCatch(read.csv(f, stringsAsFactors = FALSE, check.names = FALSE,
                             skip = hdr_at - 1),
                    error = function(e) NULL)

    if (is.null(raw) || nrow(raw) == 0) {
      problems <- c(problems, paste(basename(f), "- could not be read"))
      next
    }

    long <- tryCatch(hobo_to_long(raw), error = function(e) NULL)
    if (is.null(long)) {
      problems <- c(problems, paste(basename(f), "- no measurements found"))
      next
    }

    sn <- unique(long$device_serial)
    sn <- sn[!is.na(sn)]
    if (length(sn) != 1) {
      problems <- c(problems, paste(basename(f), "- serial unclear:",
                                    paste(sn, collapse = ", ")))
      next
    }

    when <- sort(unique(long$datetime))
    iv <- NA_real_
    if (length(when) > 2) {
      d <- as.numeric(diff(when), units = "mins"); d <- d[d > 0]
      if (length(d)) iv <- as.numeric(names(which.max(table(round(d, 3)))))
    }

    fname <- paste0(sn, "_", format(min(when), "%Y%m%d", tz = "UTC"), "_",
                    format(max(when), "%Y%m%d", tz = "UTC"), "_raw.rds")

    plan[[length(plan) + 1]] <- list(
      src = f, sn = sn, fname = fname, data = raw,
      first = min(when), last = max(when),
      n = length(when), interval = iv,
      already = fname %in% existing || file.exists(file.path(out_dir, fname)))
  }

  if (length(problems) > 0) {
    cat("Could not be read:\n")
    for (p in problems) cat("  ", p, "\n", sep = "")
    cat("\n")
  }

  if (length(plan) == 0) {
    cat("Nothing to import.\n\n")
    return(invisible(FALSE))
  }

  #### What this adds, and whether it meets what is held ####
  cat("To import:\n\n")
  cat(sprintf("  %-11s %-11s %-11s %7s %5s  %s\n",
              "serial", "first", "last", "readings", "min", "meets held data"))

  for (p in plan) {
    held <- list.files(out_dir, pattern = paste0("^", p$sn, "_"))
    seam <- "no other files"

    if (length(held) > 0) {
      starts <- as.Date(sub("^[^_]+_([0-9]{8})_.*$", "\\1", held), "%Y%m%d")
      after <- starts[starts >= as.Date(p$last) - 2]
      before <- held[starts < as.Date(p$first)]

      if (length(after) > 0) {
        d <- as.numeric(min(after) - as.Date(p$last))
        seam <- if (d <= 1) "joins the next file" else paste0(d, " day gap after")
      } else if (length(before) > 0) {
        seam <- "earlier files only"
      }
    }

    cat(sprintf("  %-11s %-11s %-11s %7d %5s  %s%s\n",
                p$sn, format(p$first, "%Y-%m-%d"), format(p$last, "%Y-%m-%d"),
                p$n, format(p$interval), seam,
                if (p$already) "   [ALREADY IMPORTED]" else ""))
  }

  todo <- Filter(function(p) !p$already, plan)
  cat("\n", length(todo), " of ", length(plan), " to write\n\n", sep = "")

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to import:\n")
    cat("  import_hobo_gap(\"", folder, "\", dry_run = FALSE)\n\n", sep = "")
    return(invisible(TRUE))
  }

  if (length(todo) == 0) {
    cat("+ Everything is already in Product 1.\n\n")
    return(invisible(TRUE))
  }

  #### Write ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  file.copy(log_file, file.path(backup_dir,
    paste0("download_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")))
  cat("+ download_log backed up\n")

  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")
  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  project_tz <- "America/Puerto_Rico"
  done <- 0

  for (p in todo) {
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
  cat("\n+ Imported ", done, " offload(s)\n", sep = "")

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))
  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in head(check$filepath[missing], 10)) cat("   ", f, "\n", sep = "")
    cat("\n  Restore from metadata/internal/backups/\n\n")
    return(invisible(FALSE))
  }
  cat("+ Verified: all ", nrow(check), " logged filepath(s) resolve\n\n",
      sep = "")

  cat("NEXT:\n")
  cat("  1. validate_metadata()\n")
  cat("  2. 21652377 recorded at Reef Bay until November 2025 and now sits at\n")
  cat("     sgm2_hydro. Metadata holds no Reef Bay row for it, so that data\n")
  cat("     would attribute to the wrong station - worth a metadata row\n")
  cat("     before Product 2 is built\n\n")

  invisible(TRUE)
}
