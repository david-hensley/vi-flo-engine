# VI-FLO migration: add elev_source and fill elevations from USGS 3DEP
#
# Adds the `elev_source` column, then looks up an elevation for every device
# that needs one, using the USGS Elevation Point Query Service.
#
# WHAT IS SKIPPED, and why:
#
#   Secondary and tertiary hydro loggers. Their elevation is not independent -
#   it is the primary's elevation plus a surveyed difference. A DEM value would
#   produce a difference from the primary that is meaningless, which is worse
#   than a blank. They stay NA until an optical level survey is done.
#
#   Anything that already has an elevation.
#
# Devices sharing a coordinate - a weather and a vwc station on one ZL6 - are
# looked up once and the result applied to both, so their elevations cannot
# disagree.
#
# Nothing is written until the whole table has been reviewed. A lookup that
# fails leaves the row blank and prints a URL for manual entry.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fill_elevations.R"))

migrate_fill_elevations <- function() {

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")

  cat("\n============================================\n")
  cat("  Migration: elevations and elev_source\n")
  cat("============================================\n\n")

  if (!exists("lookup_elevation")) load_functions("elevation")

  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  #### Add elev_source, positioned after elev ####
  added_column <- FALSE
  if (!"elev_source" %in% names(meta)) {
    meta$elev_source <- NA_character_
    cols <- names(meta)
    cols <- cols[cols != "elev_source"]
    meta <- meta[, append(cols, "elev_source", after = which(cols == "elev")),
                 drop = FALSE]
    added_column <- TRUE
    cat("+ elev_source column will be added after elev\n\n")
  }

  #### Who needs one ####
  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  blank <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")

  active  <- !tolower(meta$status) %in% terminal
  no_elev <- blank(meta$elev)
  derived <- tolower(meta$station_type) == "hydro" &
             tolower(as.character(meta$device_role)) %in% c("secondary", "tertiary")

  need    <- which(active & no_elev & !derived)
  skipped <- sum(active & no_elev & derived, na.rm = TRUE)

  cat("Devices needing an elevation: ", length(need), "\n", sep = "")
  cat("Secondary/tertiary hydro left blank for survey: ", skipped, "\n\n", sep = "")

  if (length(need) == 0) {
    if (added_column) {
      backup_metadata()
      write.csv(meta, meta_file, row.names = FALSE)
      cat("+ elev_source column added\n\n")
    }
    cat("No elevations to fill.\n\n")
    return(invisible(TRUE))
  }

  #### One lookup per unique coordinate ####
  key <- paste(meta$lat[need], meta$lon[need], sep = ",")
  groups <- split(need, key)

  cat("Unique coordinates: ", length(groups), "\n", sep = "")
  cat("Looking up from USGS 3DEP...\n\n")

  results <- vector("list", length(groups))

  for (g in seq_along(groups)) {
    idx <- groups[[g]]
    lat <- as.numeric(meta$lat[idx[1]])
    lon <- as.numeric(meta$lon[idx[1]])

    res <- lookup_elevation(lat, lon)
    results[[g]] <- list(idx = idx, lat = lat, lon = lon, res = res)

    stations <- paste(unique(meta$station_id[idx]), collapse = ", ")

    if (res$ok) {
      res_note <- if (!is.na(res$resolution)) {
        paste0("  [", res$resolution, " m DEM]")
      } else ""
      cat("  \u2713 ", format(stations, width = 28), " ",
          format(sprintf("%.2f m", res$elev), width = 10), res_note, "\n", sep = "")
    } else {
      cat("  \u2717 ", format(stations, width = 28), " ", res$message, "\n", sep = "")
    }

    Sys.sleep(0.3)  # civility toward a free public service
  }

  ok_groups   <- Filter(function(r) r$res$ok, results)
  fail_groups <- Filter(function(r) !r$res$ok, results)

  n_devices <- sum(vapply(ok_groups, function(r) length(r$idx), integer(1)))

  cat("\n--------------------------------------------\n")
  cat(length(ok_groups), " of ", length(groups), " coordinates resolved, ",
      "covering ", n_devices, " device(s)\n", sep = "")

  #### Anything that failed gets a URL to do by hand ####
  if (length(fail_groups) > 0) {
    cat("\nCould not resolve - look these up and enter them with\n")
    cat("'Correct device details' (existing station work, option 9):\n\n")
    for (r in fail_groups) {
      cat("  ", paste(unique(meta$station_id[r$idx]), collapse = ", "), "\n", sep = "")
      cat("    ", build_elevation_url(r$lat, r$lon), "\n", sep = "")
    }
    cat("\n")
  }

  if (length(ok_groups) == 0) {
    cat("Nothing to write.\n\n")
    return(invisible(FALSE))
  }

  #### Confirm before writing ####
  if (ui_yes_no("\nWrite these elevations?", allow_quit = FALSE) != "Y") {
    cat("\u274c Cancelled - nothing written\n\n")
    return(invisible(FALSE))
  }

  backup_metadata()
  cat("+ Metadata backed up\n")

  for (r in ok_groups) {
    meta$elev[r$idx] <- r$res$elev
    meta$elev_source[r$idx] <- elevation_source_label(r$res)
  }

  write.csv(meta, meta_file, row.names = FALSE)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)
  written <- sum(!blank(check$elev) & grepl("^usgs_3dep", check$elev_source),
                 na.rm = TRUE)

  sources <- table(check$elev_source[grepl("^usgs_3dep", check$elev_source)])
  cat("+ Wrote ", written, " elevation(s)\n", sep = "")
  for (s in names(sources)) {
    cat("    ", s, ": ", sources[[s]], "\n", sep = "")
  }
  cat("  ", skipped, " secondary/tertiary hydro awaiting survey\n\n", sep = "")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_fill_elevations()
