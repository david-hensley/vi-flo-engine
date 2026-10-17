################################################################################
# migrate_remove_windsor_note.R
#
# APPLIED: 2026-10-17
#
# Removes one maintenance entry: the Windsor Pond (srl1_pond) elevation note
# logged on 2026-10-17 as routine maintenance, because the single-device
# survey could not then record it properly. The same survey is re-entered
# through the rebuilt workflow, which logs it as an `elevation_survey` with
# the arithmetic, so keeping both would record one survey twice.
#
# Matches exactly one line - station srl1_pond, details beginning "Elevation
# survey: elev 31.266 m VIVD09", not the station_established entry - and
# refuses if it finds none or more than one. The line is deleted from the
# file as text, so every other entry is written back byte for byte.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_remove_windsor_note.R"))
#   migrate_remove_windsor_note()                 # dry run
#   migrate_remove_windsor_note(dry_run = FALSE)  # applies it
################################################################################

migrate_remove_windsor_note <- function(dry_run = TRUE) {

  path <- file.path(wds("meta_internal"), "maintenance_log.csv")
  if (!file.exists(path)) stop("Not found: ", path)

  raw <- readBin(path, "raw", file.info(path)$size)
  crlf <- length(raw) > 1 && any(raw[-length(raw)] == as.raw(13) &
                                 raw[-1] == as.raw(10))
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  log <- read.csv(text = lines, colClasses = "character",
                  stringsAsFactors = FALSE, check.names = FALSE)

  if (nrow(log) != length(lines) - 1) {
    stop("Rows and lines do not match - an entry may contain a line break. ",
         "Nothing changed.")
  }

  hit <- which(log$station_id == "srl1_pond" &
               log$action_type != "station_established" &
               startsWith(log$details, "Elevation survey: elev 31.266 m VIVD09"))

  cat("\n--- REMOVE WINDSOR NOTE ENTRY ---\n\n")
  if (length(hit) == 0) {
    # Either already removed, or the note was typed differently. Show what is
    # there rather than guessing which one is meant.
    others <- which(log$station_id == "srl1_pond" &
                    log$action_type != "station_established")
    if (length(others) == 0) {
      message("\u2713 No srl1_pond entry besides station_established - nothing to do.")
      return(invisible(TRUE))
    }
    cat("No entry begins \"Elevation survey: elev 31.266 m VIVD09\". The other\n")
    cat("srl1_pond entries are:\n\n")
    for (i in others) {
      cat(sprintf("  row %d  %s  %s  %s\n", i, log$field_visit_date[i],
                  log$action_type[i], substr(log$details[i], 1, 70)))
    }
    cat("\nNothing changed. Paste this, and the match can be adjusted.\n")
    return(invisible(NULL))
  }
  if (length(hit) > 1) {
    stop(length(hit), " entries match - expected one. Nothing changed.")
  }

  cat("Entry to remove (row ", hit, " of ", nrow(log), "):\n\n", sep = "")
  for (col in c("timestamp", "field_visit_date", "station_id", "action_type",
                "details", "logged_by")) {
    if (col %in% names(log)) cat(sprintf("  %-17s %s\n", col, log[[col]][hit]))
  }

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(NULL))
  }

  #### Back up, then drop the one line ####
  if (exists("backup_metadata")) backup_metadata()

  new_lines <- lines[-(hit + 1)]   # line 1 is the header
  con <- file(path, open = "wb")
  writeLines(new_lines, con, sep = if (crlf) "\r\n" else "\n", useBytes = TRUE)
  close(con)

  #### Verify ####
  after_lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  after <- read.csv(text = after_lines, colClasses = "character",
                    stringsAsFactors = FALSE, check.names = FALSE)

  ok_count <- nrow(after) == nrow(log) - 1
  ok_rest  <- identical(after_lines, lines[-(hit + 1)])
  ok_gone  <- !any(after$station_id == "srl1_pond" &
                   startsWith(after$details, "Elevation survey: elev 31.266 m VIVD09"))
  ok_kept  <- any(after$station_id == "srl1_pond" &
                  after$action_type == "station_established")

  cat("\n--- VERIFICATION ---\n")
  cat(if (ok_count) "\u2713" else "\u274c", " One entry fewer (", nrow(after), ")\n", sep = "")
  cat(if (ok_gone) "\u2713" else "\u274c", " The Windsor note entry is gone\n", sep = "")
  cat(if (ok_kept) "\u2713" else "\u274c", " The srl1_pond station_established entry remains\n", sep = "")
  cat(if (ok_rest) "\u2713" else "\u274c", " Every other line byte-identical\n", sep = "")

  if (!(ok_count && ok_gone && ok_kept && ok_rest)) {
    stop("Verification failed. Restore from metadata/internal/backups.")
  }
  cat("\n\u2713 Entry removed\n")
  invisible(TRUE)
}
