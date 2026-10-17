################################################################################
# migrate_u20_model_04.R
#
# APPLIED: 2026-10-17
#
# Every HOBO U20 stream gauge was recorded as U20-001-01, the 9 m (30 ft)
# range model. They are U20-001-04, the 4 m (13 ft) model. The distinction
# matters: the model says what range a pressure reading is valid over, and a
# 4 m logger read against a 9 m range would never be flagged as off the end
# of its sensor.
#
# Real U20-001-01 loggers are about to arrive for the pond sites, so the fix
# is by EXPLICIT unique_id, not "every U20-001-01": run after a pond logger
# is added, a blanket rule would quietly mislabel it. Any U20 row not on the
# list is reported and left alone.
#
# The file is edited line by line, replacing only the model value on the
# listed rows, so every other byte - quoting, number formats, NA, line
# endings - is written back exactly as it was.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_u20_model_04.R"))
#   migrate_u20_model_04()                 # dry run: shows what would change
#   migrate_u20_model_04(dry_run = FALSE)  # applies it
################################################################################

migrate_u20_model_04 <- function(dry_run = TRUE) {

  old_model <- "U20-001-01"
  new_model <- "U20-001-04"

  # The 27 U20 rows in device_metadata.csv as of 2026-10-14: every stream
  # gauge logger the network has had, active and retired.
  targets <- sprintf("h-%04d", c(1:25, 27, 29))

  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  if (!file.exists(path)) stop("Not found: ", path)

  #### Read: raw lines for writing, a parse for finding rows ####
  raw <- readBin(path, "raw", file.info(path)$size)
  crlf <- length(raw) > 1 && any(raw[-length(raw)] == as.raw(13) &
                                 raw[-1] == as.raw(10))
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  meta <- read.csv(text = lines, colClasses = "character",
                   stringsAsFactors = FALSE, check.names = FALSE)

  # One line per row, or the line-level edit is unsafe
  if (nrow(meta) != length(lines) - 1) {
    stop("Rows and lines do not match (", nrow(meta), " rows, ",
         length(lines) - 1, " data lines) - a field may contain a line break. ",
         "Nothing changed.")
  }

  is_u20 <- meta$mfger == "HOBO" & grepl("^U20", meta$model)

  #### Prior application ####
  listed <- meta$unique_id %in% targets
  if (all(meta$model[listed] == new_model) && any(listed)) {
    message("\u2713 Already applied: every listed row is ", new_model,
            ". Nothing to do.")
    return(invisible(TRUE))
  }

  #### What would change ####
  missing <- setdiff(targets, meta$unique_id)
  change  <- which(listed & meta$model == old_model)
  odd     <- which(listed & !meta$model %in% c(old_model, new_model))
  others  <- which(is_u20 & !listed)

  cat("\n--- U20 MODEL CORRECTION ---\n\n")
  cat(sprintf("Rows to change from %s to %s: %d\n\n", old_model, new_model,
              length(change)))
  for (i in change) {
    cat(sprintf("  %s  %-12s %-9s %-15s %s\n", meta$unique_id[i],
                meta$station_id[i], meta$device_serial[i],
                meta$device_name[i], meta$status[i]))
  }
  if (length(missing) > 0) {
    cat("\n\u26a0\ufe0f  Listed but not in the file: ",
        paste(missing, collapse = ", "), "\n", sep = "")
  }
  if (length(odd) > 0) {
    cat("\n\u26a0\ufe0f  Listed rows with an unexpected model, left alone:\n")
    for (i in odd) cat("  ", meta$unique_id[i], "  ", meta$model[i], "\n", sep = "")
  }
  if (length(others) > 0) {
    cat("\nU20 rows NOT on the list, left alone:\n")
    for (i in others) {
      cat(sprintf("  %s  %-12s %-9s %s\n", meta$unique_id[i],
                  meta$station_id[i], meta$device_serial[i], meta$model[i]))
    }
  }

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(meta[change, c("unique_id", "station_id",
                                    "device_serial", "model")]))
  }
  if (length(change) == 0) {
    message("Nothing to change.")
    return(invisible(TRUE))
  }

  #### Back up, then edit only the model value on each listed line ####
  backup_metadata()

  token_old <- paste0("\"", old_model, "\"")
  token_new <- paste0("\"", new_model, "\"")
  new_lines <- lines
  for (i in change) {
    ln <- i + 1   # line 1 is the header
    hits <- gregexpr(token_old, new_lines[ln], fixed = TRUE)[[1]]
    if (length(hits) != 1 || hits[1] == -1) {
      stop("Row ", meta$unique_id[i], " does not contain ", token_old,
           " exactly once on its line - nothing written.")
    }
    new_lines[ln] <- sub(token_old, token_new, new_lines[ln], fixed = TRUE)
  }

  con <- file(path, open = "wb")
  writeLines(new_lines, con, sep = if (crlf) "\r\n" else "\n", useBytes = TRUE)
  close(con)

  #### Verify ####
  after_lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  after <- read.csv(text = after_lines, colClasses = "character",
                    stringsAsFactors = FALSE, check.names = FALSE)

  changed_lines <- which(after_lines != lines)
  expected_lines <- change + 1
  ok_set   <- setequal(changed_lines, expected_lines)
  ok_model <- all(after$model[change] == new_model)
  ok_rest  <- identical(after[-change, ], meta[-change, ])
  ok_only  <- all(gsub(token_new, token_old, after_lines[expected_lines],
                       fixed = TRUE) == lines[expected_lines])

  cat("\n--- VERIFICATION ---\n")
  cat(if (ok_set) "\u2713" else "\u274c", " Only the listed rows' lines changed\n", sep = "")
  cat(if (ok_only) "\u2713" else "\u274c", " On those lines, only the model value changed\n", sep = "")
  cat(if (ok_model) "\u2713" else "\u274c", " Every listed row now reads ", new_model, "\n", sep = "")
  cat(if (ok_rest) "\u2713" else "\u274c", " Every other row is unchanged\n", sep = "")

  if (!(ok_set && ok_only && ok_model && ok_rest)) {
    stop("Verification failed. Restore from metadata/internal/backups.")
  }
  cat("\n\u2713 ", length(change), " rows corrected to ", new_model, "\n", sep = "")
  invisible(TRUE)
}
