################################################################################
# migrate_device_names_v2.9.R
#
# APPLIED: 2026-11-22 (4 rows named: dor1 and tr1 weather loggers; sr2_vwc2 left unnamed)
#
# Fills blank device names from ZentraCloud - item (c) before the v2.9 tag.
#
# A logger with no name in metadata is shown by its serial everywhere, and a
# serial means nothing to anyone. Most such loggers are ZL6s that do have a
# name - on ZentraCloud, where they were set up. This copies that name into
# every metadata row whose device_name is blank, and changes nothing else:
# a row that already has a name keeps it, even if ZentraCloud's differs.
#
# Rows it cannot fill - a HOBO, or a ZL6 the account does not name - are
# listed, to name by hand through the metadata manager's corrections.
#
# Needs ZentraCloud, so run it from a session with the API key, not a test.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_device_names_v2.9.R"))
#   migrate_device_names()                 # dry run
#   migrate_device_names(dry_run = FALSE)  # applies it
################################################################################

migrate_device_names <- function(dry_run = TRUE) {
  meta <- load_zentra_metadata()
  blank <- which(is.na(meta$device_name) | !nzchar(trimws(meta$device_name)))
  if (length(blank) == 0) {
    cat("✓ Every metadata row has a device name - nothing to do\n")
    return(invisible(TRUE))
  }

  devices <- tryCatch(zc_call("zc_list_devices"), error = function(e) {
    stop("ZentraCloud could not be reached, so no names can be looked up:\n  ",
         conditionMessage(e), "\nNothing written.", call. = FALSE)
  })

  found <- vapply(meta$device_serial[blank], function(sn) {
    n <- device_display_name(sn, meta = meta[0, ], devices = devices)
    if (identical(n, sn)) NA_character_ else n
  }, character(1), USE.NAMES = FALSE)
  fill <- blank[!is.na(found)]
  left <- blank[is.na(found)]

  cat("\nDevice metadata - ", length(blank), " row(s) with no device name\n", sep = "")
  cat("\n  Named from ZentraCloud (", length(fill), "):\n", sep = "")
  if (length(fill) == 0) cat("      (none)\n")
  for (i in seq_along(fill)) {
    r <- fill[i]
    cat(sprintf("      %-14s %-12s %-10s -> %s\n", meta$station_id[r], meta$device_serial[r],
                meta$status[r], found[!is.na(found)][i]))
  }
  cat("\n  No name to be found - name by hand in the metadata manager if wanted (",
      length(left), "):\n", sep = "")
  if (length(left) == 0) cat("      (none)\n")
  for (r in left) {
    cat(sprintf("      %-14s %-12s %s\n", meta$station_id[r], meta$device_serial[r], meta$status[r]))
  }

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_device_names(dry_run = FALSE) to apply it.\n")
    return(invisible(meta[fill, c("unique_id", "station_id", "device_serial")]))
  }
  if (length(fill) == 0) {
    cat("\n✓ Nothing to fill - nothing written\n")
    return(invisible(TRUE))
  }

  meta$device_name[fill] <- found[!is.na(found)]
  write_table("device_metadata", meta, guard = FALSE)
  back <- load_zentra_metadata()
  if (!identical(back$device_name[fill], meta$device_name[fill])) {
    stop("device_metadata.csv did not read back as written", call. = FALSE)
  }
  cat("\n✓ device_metadata.csv written: ", length(fill),
      " name(s) filled, every other value as it was\n", sep = "")
  invisible(TRUE)
}
