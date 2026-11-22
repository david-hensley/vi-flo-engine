################################################################################
# migrate_known_unattributed_v2.9.R
#
# APPLIED: 2026-11-22 (14 rows, all periods - no whole-logger rows yet)
#
# Adds `archive` to known_unattributed.csv - item (a) before the v2.9 tag.
#
#   archive   for a row covering a whole logger (no port, no dates): whether
#             the download job keeps archiving it. Every existing whole-logger
#             row gets TRUE - the job archived them all until now, and that
#             stays so until someone decides otherwise. Blank on a period:
#             archiving is a question about a whole logger only
#
# Reads the table raw, since the engine's schema already describes the new
# shape; writes it through the data layer, which backs it up first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_known_unattributed_v2.9.R"))
#   migrate_known_unattributed()                 # dry run
#   migrate_known_unattributed(dry_run = FALSE)  # applies it
################################################################################

migrate_known_unattributed <- function(dry_run = TRUE) {
  path <- table_path("known_unattributed")
  new_cols <- names(TABLE_SCHEMA$known_unattributed$columns)
  old_cols <- setdiff(new_cols, "archive")

  if (!file.exists(path)) {
    cat("✓ No known_unattributed.csv yet - nothing to do\n")
    return(invisible(TRUE))
  }
  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8")
  if (identical(names(raw), new_cols)) {
    cat("✓ known_unattributed.csv already has its archive column - nothing to do\n")
    return(invisible(TRUE))
  }
  if (!identical(names(raw), old_cols)) {
    stop("known_unattributed.csv has neither the old columns nor the new:\n  ",
         paste(names(raw), collapse = ", "), "\nNothing written.", call. = FALSE)
  }

  whole <- is.na(raw$port) & is.na(raw$from) & is.na(raw$to)
  raw$archive <- ifelse(whole, "TRUE", NA)

  cat("\nknown_unattributed.csv - ", nrow(raw), " row(s)\n", sep = "")
  cat("  ", sum(whole), " covering a whole logger: archive TRUE, as the job has done until now\n", sep = "")
  for (i in which(whole)) cat("      ", raw$device_name[i], " (", raw$device_serial[i], ")\n", sep = "")
  cat("  ", sum(!whole), " period(s): archive left blank\n", sep = "")

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_known_unattributed(dry_run = FALSE) to apply it.\n")
    return(invisible(raw))
  }

  tmp <- tempfile(fileext = ".csv")
  utils::write.csv(raw[, new_cols], tmp, row.names = FALSE, na = "")
  write_table("known_unattributed", read_table("known_unattributed", path = tmp, remember = FALSE),
              guard = FALSE)
  back <- read_table("known_unattributed", remember = FALSE)
  if (nrow(back) != nrow(raw)) stop("known_unattributed.csv did not read back as written", call. = FALSE)
  cat("\n✓ known_unattributed.csv written: archive column added, every other value as it was\n")
  invisible(TRUE)
}
