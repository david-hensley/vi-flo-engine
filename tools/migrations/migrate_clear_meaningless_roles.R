# VI-FLO migration: clear device roles that carry no meaning
#
# ONE-TIME SCRIPT.
#
# `device_role` means one specific thing per station type, and neither is a
# general label:
#
#   hydro    a paired stream gauge. primary is the DOWNSTREAM logger,
#            secondary upstream. The pair's elevation difference over the
#            reach length is the hydraulic slope, so which is which decides
#            the sign of every discharge computed from it. A lone gauge has
#            no pair and therefore no role.
#
#   vwc      primary marks the soil moisture station sharing the weather
#            station's logger - one ZL6 with an ATMOS and TEROS sensors is
#            two stations, and this says which vwc station that is. A vwc
#            station on its own logger has nothing to be primary of.
#
#   weather  almost always none.
#
# Roles were nonetheless set on stations where they mean nothing, mostly by
# answering a prompt that called them "recommended" without saying what for.
# `ltt1_vwc1/2/3` ended up primary, tertiary and secondary as though three
# separate stations at Limetree were one hierarchy.
#
# A meaningless role is worse than a blank one: it invites a reader to look
# for a pairing that does not exist, and the hydro workflows treat secondary
# and tertiary as devices whose elevation must come from a survey.
#
#
# WHAT IS CLEARED
#
# Every vwc row whose device is NOT the one its site's weather station uses.
# Hydro roles are left alone - every hydro row carrying a role is genuinely
# paired, which this script verifies rather than assumes.
#
# Terminal rows are left alone. They record what was true at the time.
#
# Safe to run twice: it exits when nothing is left to clear.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_clear_meaningless_roles.R"))

migrate_clear_meaningless_roles <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: clear roles that carry no meaning\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  active <- !tolower(meta$status) %in% terminal

  blank <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")
  has_role <- !blank(meta$device_role)

  #### Which serial does each site's weather station use ####
  wx <- meta[active & tolower(meta$station_type) == "weather", ]
  weather_serial <- setNames(wx$device_serial, wx$site)

  #### vwc rows to clear ####
  is_vwc <- tolower(meta$station_type) == "vwc"
  colocated <- !is.na(weather_serial[meta$site]) &
               meta$device_serial == weather_serial[meta$site]
  colocated[is.na(colocated)] <- FALSE

  to_clear <- which(active & has_role & is_vwc & !colocated)

  #### Verify the hydro roles really are paired, rather than trusting them ####
  is_hydro <- tolower(meta$station_type) == "hydro"
  hydro_roled <- which(active & has_role & is_hydro)
  lone_hydro <- integer(0)

  for (i in hydro_roled) {
    at_station <- sum(active & meta$station_id == meta$station_id[i])
    if (at_station < 2) lone_hydro <- c(lone_hydro, i)
  }

  cat("Active rows carrying a role: ", sum(active & has_role), "\n\n", sep = "")

  cat("vwc rows to clear (not on the weather station's logger):\n\n")
  if (length(to_clear) == 0) {
    cat("  none\n")
  } else {
    for (i in to_clear) {
      cat("  ", format(meta$station_id[i], width = 13),
          format(meta$device_serial[i], width = 11),
          format(meta$device_role[i], width = 10),
          " -> (none)\n", sep = "")
    }
  }

  cat("\nvwc rows KEPT (sharing the weather station's logger):\n\n")
  kept <- which(active & has_role & is_vwc & colocated)
  if (length(kept) == 0) cat("  none\n")
  for (i in kept) {
    cat("  ", format(meta$station_id[i], width = 13),
        format(meta$device_serial[i], width = 11),
        meta$device_role[i], "\n", sep = "")
  }

  cat("\nhydro rows carrying a role: ", length(hydro_roled), "\n", sep = "")
  if (length(lone_hydro) > 0) {
    cat("\n! These hydro rows carry a role but their station has only one\n")
    cat("  active device, so there is no pair for primary to mean anything\n")
    cat("  against. NOT cleared automatically - a hydro role decides the sign\n")
    cat("  of a slope, and guessing at it is worse than leaving it:\n\n")
    for (i in lone_hydro) {
      cat("  ", format(meta$station_id[i], width = 13),
          format(meta$device_serial[i], width = 11),
          meta$device_role[i], "\n", sep = "")
    }
  } else {
    cat("  all are genuinely paired\n")
  }

  if (length(to_clear) == 0) {
    cat("\n+ Nothing to clear.\n\n")
    return(invisible(TRUE))
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_clear_meaningless_roles(dry_run = FALSE)\n\n")
    return(invisible(length(to_clear)))
  }

  backup_metadata()
  cat("\n+ Metadata backed up\n")

  meta$device_role[to_clear] <- NA
  save_device_metadata(meta)

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)
  still <- sum(!tolower(check$status) %in% terminal &
               !blank(check$device_role) &
               tolower(check$station_type) == "vwc" &
               !(!is.na(weather_serial[check$site]) &
                 check$device_serial == weather_serial[check$site]), na.rm = TRUE)

  if (still > 0) {
    cat("\nX ", still, " vwc role(s) remain - restore from backups/\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("+ Cleared ", length(to_clear), " role(s)\n", sep = "")
  cat("+ Verified: every remaining vwc role is on a shared logger\n\n")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_clear_meaningless_roles(dry_run = TRUE)
