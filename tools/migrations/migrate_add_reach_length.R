# VI-FLO migration: add reach_length_m column
#
# ONE-TIME SCRIPT.
#
# Adds `reach_length_m` after `elev_source`. It holds the distance from a
# secondary or tertiary hydro logger to its station's primary, measured ALONG
# THE CHANNEL - which on a sinuous reach is longer than the straight line.
#
# Hydraulic slope is then derivable from stored values alone:
#
#     (secondary_elev - primary_elev) / reach_length_m
#
# Every row starts blank. Nothing is guessed: the only reach length that could
# be inferred from existing data is the straight-line distance between two
# coordinates, and paired loggers share coordinates by design, so that distance
# is zero. It has to be measured in the field.
#
# Safe to run twice - it detects the column and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_add_reach_length.R"))

migrate_add_reach_length <- function() {

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")

  cat("\n============================================\n")
  cat("  Migration: add reach_length_m\n")
  cat("============================================\n\n")

  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  if ("reach_length_m" %in% names(meta)) {
    cat("+ reach_length_m already present - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  if (!"elev_source" %in% names(meta)) {
    cat("X No elev_source column - run migrate_fill_elevations.R first\n")
    return(invisible(FALSE))
  }

  #### Back up ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("device_metadata_", stamp, ".csv"))
  file.copy(meta_file, backup_file)
  cat("+ Backed up to: ", basename(backup_file), "\n", sep = "")

  #### Insert after elev_source ####
  meta$reach_length_m <- NA_real_
  cols <- names(meta)
  cols <- cols[cols != "reach_length_m"]
  meta <- meta[, append(cols, "reach_length_m",
                        after = which(cols == "elev_source")), drop = FALSE]

  write.csv(meta, meta_file, row.names = FALSE)
  cat("+ Added reach_length_m after elev_source (", nrow(meta),
      " rows, all blank)\n", sep = "")

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)

  ok <- TRUE
  if (nrow(check) != nrow(meta)) {
    cat("X Row count changed\n"); ok <- FALSE
  }
  if (!"reach_length_m" %in% names(check)) {
    cat("X Column missing after write\n"); ok <- FALSE
  }
  if (ok && which(names(check) == "reach_length_m") !=
            which(names(check) == "elev_source") + 1) {
    cat("X Column is not positioned after elev_source\n"); ok <- FALSE
  }

  if (!ok) {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  #### Who will need one ####
  terminal <- c("removed", "replaced", "relocated", "decommissioned")
  needs <- sum(!tolower(check$status) %in% terminal &
               tolower(check$station_type) == "hydro" &
               tolower(as.character(check$device_role)) %in%
                 c("secondary", "tertiary"), na.rm = TRUE)

  cat("+ Verified\n\n")
  cat("Columns now:\n  ", paste(names(check), collapse = ", "), "\n\n", sep = "")
  cat(needs, " paired logger(s) will need a reach length, recorded during the\n",
      "elevation survey (existing station work, option 8).\n\n", sep = "")

  invisible(TRUE)
}

migrate_add_reach_length()
