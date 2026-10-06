# VI-FLO: bring a second machine onto the products layout
#
# ONE-TIME SCRIPT, run on any machine that did NOT run
# migrate_products_layout.R.
#
# That migration moved device-data, created the products tree, retired the old
# folders both locally and on Box, and rewrote download_log. Box is therefore
# already correct, and the data has already been migrated - this machine needs
# none of that doing again.
#
# What it needs is the opposite: to stop holding what Box no longer has.
# `rclone copy` never deletes, so a pull brings the new structure down and
# leaves the old one sitting beside it - 650 MB duplicated, and folders that
# were deliberately retired back in place.
#
# So this deletes, and nothing else. No moves, no writes to Box, no metadata
# changes.
#
#
# BEFORE RUNNING
#
#   1. Pull from Box, so the new structure is here
#   2. Pull the engine repo, for the new default_datamap.csv
#   3. Run tools/datamapper.py and accept the default structure
#
# Then this.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/catchup_products_layout.R"))

catchup_products_layout <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Catch-up: the products layout\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  if (!nzchar(data_root) || !dir.exists(data_root)) {
    cat("X VI_FLO_DATA_ROOT is not set\n\n")
    return(invisible(FALSE))
  }

  #### Has the pull happened? ####
  # Deleting the old structure before the new one is here would be deleting the
  # only copy on this machine.
  new_device <- file.path(data_root, "internal/device-data")
  new_products <- file.path(data_root, "internal/products")

  if (!dir.exists(new_device)) {
    cat("X internal/device-data is not here yet.\n")
    cat("  Pull from Box first - otherwise this would delete the only copy\n")
    cat("  on this machine.\n\n")
    return(invisible(FALSE))
  }

  n_new <- length(list.files(new_device, recursive = TRUE))
  cat("internal/device-data is present: ", n_new, " file(s)\n", sep = "")

  if (n_new < 200) {
    cat("\nX That is fewer files than expected - the pull may be incomplete.\n")
    cat("  Nothing deleted. Let the sync finish and re-run.\n\n")
    return(invisible(FALSE))
  }

  if (!dir.exists(new_products)) {
    cat("! internal/products is not here. Not fatal - it is empty until\n")
    cat("  processing writes to it - but check the pull brought everything.\n")
  }
  cat("\n")

  #### What this machine is still holding ####
  stale <- c("internal/raw", "external/raw", "external/processed")
  present <- stale[dir.exists(file.path(data_root, stale))]

  if (length(present) == 0) {
    cat("+ Nothing stale here - this machine is already on the new layout.\n\n")
    return(invisible(TRUE))
  }

  cat("Stale, to be deleted from this machine:\n")
  total <- 0
  for (p in present) {
    n <- length(list.files(file.path(data_root, p), recursive = TRUE))
    total <- total + n
    size <- sum(file.size(list.files(file.path(data_root, p), recursive = TRUE,
                                     full.names = TRUE)), na.rm = TRUE)
    cat("  ", p, "  ", n, " file(s), ", round(size / 1024^2), " MB\n", sep = "")
  }
  cat("\n")

  #### Anything here that is NOT also in the new structure? ####
  # The old device-data should be duplicated under the new path. A file that is
  # not is one this machine holds alone, and deleting it would lose it.
  old_device <- file.path(data_root, "internal/raw/device-data")
  if (dir.exists(old_device)) {
    old_files <- list.files(old_device, recursive = TRUE)
    new_files <- list.files(new_device, recursive = TRUE)
    orphans <- setdiff(old_files, new_files)

    if (length(orphans) > 0) {
      cat("X ", length(orphans), " file(s) under internal/raw/device-data are\n",
          "  NOT present at the new path:\n", sep = "")
      for (f in head(orphans, 10)) cat("    ", f, "\n", sep = "")
      if (length(orphans) > 10) {
        cat("    ... and ", length(orphans) - 10, " more\n", sep = "")
      }
      cat("\n  Nothing deleted. Work out what these are first - deleting them\n")
      cat("  would lose the only copy.\n\n")
      return(invisible(FALSE))
    }
    cat("+ Every old device-data file is present at the new path\n\n")
  }

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to delete:\n")
    cat("  catchup_products_layout(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  for (p in present) unlink(file.path(data_root, p), recursive = TRUE)
  cat("+ Deleted ", total, " stale file(s)\n\n", sep = "")

  #### Verify ####
  left <- present[dir.exists(file.path(data_root, present))]
  if (length(left) > 0) {
    cat("! Still present: ", paste(left, collapse = ", "), "\n", sep = "")
    cat("  Something has a lock on them - close any open files and re-run.\n\n")
    return(invisible(FALSE))
  }

  cat("NEXT:\n")
  cat("  1. source start.R\n")
  cat("  2. validate_metadata()\n")
  cat("  3. Do NOT push to Box until both pass - a push from a machine in a\n")
  cat("     half-migrated state would put the old structure back\n\n")

  invisible(TRUE)
}

catchup_products_layout(dry_run = TRUE)
