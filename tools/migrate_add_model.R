# VI-FLO migration: add model column to device_metadata.csv
#
# ONE-TIME SCRIPT. Adds a `model` column immediately after `mfger`, recording
# the device model (e.g. U20-001-01, ZL6). The model determines what the
# numbers mean - a HOBO U20-001-01 is the 9 m range version and the -04 is
# 4 m - so without it you cannot tell whether a pressure reading is in spec or
# off the end of the sensor.
#
# Existing rows are left blank rather than guessed. Fill them in through the
# metadata manager as you confirm each device.
#
# Safe to run twice - it detects the column and exits without changing anything.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrate_add_model.R"))

migrate_add_model <- function() {

  meta_file <- file.path(wds("meta_internal"), "device_metadata.csv")

  cat("\n============================================\n")
  cat("  Migration: add model column\n")
  cat("============================================\n\n")

  if (!file.exists(meta_file)) {
    cat("X device_metadata.csv not found at:\n  ", meta_file, "\n", sep = "")
    return(invisible(FALSE))
  }

  # Read without date parsing so datetime strings are written back unchanged
  meta <- read.csv(meta_file, stringsAsFactors = FALSE)

  cat("Found ", nrow(meta), " device rows\n", sep = "")

  if ("model" %in% names(meta)) {
    cat("+ model already present - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  if (!"mfger" %in% names(meta)) {
    cat("X No mfger column found - cannot position the new column.\n")
    return(invisible(FALSE))
  }

  #### Back up before touching anything ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)

  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("device_metadata_", stamp, ".csv"))
  file.copy(meta_file, backup_file)
  cat("+ Backed up to: ", basename(backup_file), "\n", sep = "")

  #### Insert model immediately after mfger ####
  # Left blank, not guessed. An invented model is worse than an absent one -
  # it looks authoritative and nobody questions it.
  meta$model <- NA_character_

  mfger_pos <- which(names(meta) == "mfger")
  all_cols <- names(meta)
  all_cols <- all_cols[all_cols != "model"]
  new_order <- append(all_cols, "model", after = mfger_pos)
  meta <- meta[, new_order, drop = FALSE]

  write.csv(meta, meta_file, row.names = FALSE)

  cat("+ Added model column after mfger (", nrow(meta), " rows, all blank)\n",
      sep = "")

  #### Verify ####
  check <- read.csv(meta_file, stringsAsFactors = FALSE)

  ok <- TRUE
  if (nrow(check) != nrow(meta)) {
    cat("X Row count changed: ", nrow(meta), " -> ", nrow(check), "\n", sep = "")
    ok <- FALSE
  }
  if (!"model" %in% names(check)) {
    cat("X model missing after write\n")
    ok <- FALSE
  }
  if (ok && which(names(check) == "model") != which(names(check) == "mfger") + 1) {
    cat("X model is not positioned immediately after mfger\n")
    ok <- FALSE
  }

  if (ok) {
    cat("+ Verified: ", nrow(check), " rows, model follows mfger\n\n", sep = "")
    cat("Columns now:\n  ", paste(names(check), collapse = ", "), "\n\n", sep = "")
    cat("Migration complete. Fill in models through the metadata manager as\n")
    cat("you confirm each device - they are deliberately left blank rather\n")
    cat("than guessed.\n\n")
  } else {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
  }

  invisible(ok)
}

migrate_add_model()
