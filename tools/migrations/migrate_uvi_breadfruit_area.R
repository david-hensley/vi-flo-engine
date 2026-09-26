# VI-FLO migration: set area on the UVI breadfruit stations
#
# ONE-TIME SCRIPT.
#
# uvi_vwc2 and uvi_vwc3 belong to a breadfruit experiment on the UVI campus,
# roughly 230 m north of the weather station. Until now their `area` was blank,
# so nothing distinguished them from the campus monitoring pair.
#
# WHY IT MATTERS MORE THAN IT LOOKS
#
# The UVI site exists to hold campus work that is not part of the field
# monitoring network. Such experiments are many and short-lived, where field
# stations are few and long-lived - so numbering alone would give uvi_vwc27
# within a few years, with no way to tell which stations belonged to which
# study.
#
# `area` carries the grouping instead. Station IDs stay a plain counter, and
# the experiment is a field that can be filtered on.
#
# uvi_weather and uvi_vwc1 stay blank. They share one ZL6 at one position and
# are the campus monitoring pair, not an experiment.
#
# Safe to run twice: it exits when the area is already set.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_uvi_breadfruit_area.R"))

migrate_uvi_breadfruit_area <- function(dry_run = TRUE) {

  STATIONS <- c("uvi_vwc2", "uvi_vwc3")
  AREA     <- "Breadfruit"

  cat("\n============================================\n")
  cat("  Migration: area for the UVI breadfruit stations\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  blank <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")

  cat("UVI stations:\n\n")
  for (i in which(meta$site == "uvi")) {
    cat("  ", format(meta$station_id[i], width = 13),
        format(meta$device_serial[i], width = 11),
        "  area: ",
        if (blank(meta$area[i])) "(blank)" else meta$area[i], "\n", sep = "")
  }

  rows <- which(meta$station_id %in% STATIONS & blank(meta$area))

  if (length(rows) == 0) {
    cat("\n+ Area already set on those stations - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  cat("\nTo set:\n\n")
  for (i in rows) {
    cat("  ", format(meta$station_id[i], width = 13),
        "(blank) -> ", AREA, "\n", sep = "")
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_uvi_breadfruit_area(dry_run = FALSE)\n\n")
    return(invisible(length(rows)))
  }

  backup_metadata()
  cat("\n+ Metadata backed up\n")

  meta$area[rows] <- AREA
  save_device_metadata(meta)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)

  set_ok <- all(!blank(check$area[check$station_id %in% STATIONS]))
  pair_ok <- all(blank(check$area[check$station_id %in% c("uvi_weather", "uvi_vwc1")]))

  cat("+ Set area on ", length(rows), " row(s)\n\n", sep = "")
  cat("UVI stations now:\n\n")
  for (i in which(check$site == "uvi")) {
    cat("  ", format(check$station_id[i], width = 13),
        format(check$device_serial[i], width = 11),
        "  area: ",
        if (blank(check$area[i])) "(blank)" else check$area[i], "\n", sep = "")
  }

  if (!set_ok || !pair_ok) {
    cat("\nX Verification FAILED - restore from metadata/internal/backups/\n\n")
    return(invisible(FALSE))
  }

  cat("\n+ Verified: breadfruit stations grouped, monitoring pair left blank\n\n")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_uvi_breadfruit_area(dry_run = TRUE)
