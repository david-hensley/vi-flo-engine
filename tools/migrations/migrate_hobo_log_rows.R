################################################################################
# migrate_hobo_log_rows.R
#
# APPLIED: not yet
#
# Repairs download_log.csv rows written by the HOBO ingest with seven fields
# instead of nine. The ingest built its row without run_id and device_serial -
# added to the log after it was written - and appended it by position, so
# every value after the station slid two columns left and filepath came out
# empty. The October 2026 offloads were therefore never seen as logged, and
# Product 2 skipped them. Fixed in the same release (append_log_row()).
#
# Each such row gets run_id NA, as a manual ingest has no run, and its
# device_serial, read from its own file name. A row is only touched if it has
# exactly seven fields, a manual download_type, and a filepath under
# device-data/hobo whose name begins with the serial; every other line of the
# file is left byte for byte.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_hobo_log_rows.R"))
#   migrate_hobo_log_rows()                 # dry run
#   migrate_hobo_log_rows(dry_run = FALSE)  # applies it
################################################################################

migrate_hobo_log_rows <- function(dry_run = TRUE) {

  f <- file.path(wds("meta_internal"), "download_log.csv")
  b <- readBin(f, "raw", file.info(f)$size)
  lines <- strsplit(rawToChar(b), "\n", fixed = TRUE)[[1]]
  final_newline <- length(b) > 0 && b[length(b)] == as.raw(10)

  # A field split that respects quotes; these rows hold no quoted commas, but
  # the header is read the same way
  split <- function(line) {
    line <- sub("\r$", "", line)
    scan(text = line, what = "character", sep = ",", quote = "\"", quiet = TRUE,
         na.strings = character(0))
  }
  header <- split(lines[1])
  if (!identical(header, c("timestamp_utc", "run_id", "station", "device_serial", "start_date",
                           "end_date", "n_records", "filepath", "download_type"))) {
    stop("download_log.csv's columns are not the expected nine - nothing written", call. = FALSE)
  }

  fixes <- list()
  for (i in seq_along(lines)[-1]) {
    if (!nzchar(sub("\r$", "", lines[i]))) next
    v <- split(lines[i])
    if (length(v) == 9) next
    serial <- sub("_.*$", "", basename(v[6]))
    ok <- length(v) == 7 && v[7] == "manual" && grepl("^internal/device-data/hobo/", v[6]) &&
          grepl("^[0-9]+_", basename(v[6]))
    if (!ok) {
      stop("Line ", i, " has ", length(v), " fields but is not a HOBO row this repairs:\n  ",
           sub("\r$", "", lines[i]), "\nNothing written.", call. = FALSE)
    }
    # Insert ,NA after the timestamp and ,"serial" after the station - the rest
    # of the line exactly as it was
    m <- regmatches(lines[i], regexec('^("[^"]*"),("[^"]*"),(.*)$', lines[i]))[[1]]
    if (length(m) != 4) stop("Line ", i, " is not in the expected form - nothing written", call. = FALSE)
    fixes[[length(fixes) + 1]] <- list(line = i, serial = serial, file = basename(v[6]),
                                       new = paste0(m[2], ",NA,", m[3], ",\"", serial, "\",", m[4]))
  }

  if (length(fixes) == 0) {
    message("\u2713 Already applied - every download_log row has its nine columns. Nothing to do.")
    return(invisible(TRUE))
  }

  cat("\n--- DOWNLOAD LOG ROWS MISSING run_id AND device_serial ---\n")
  for (x in fixes) cat(sprintf("  line %d  %s  %s\n", x$line, x$serial, x$file))

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(NULL))
  }

  backup_metadata()
  for (x in fixes) lines[x$line] <- x$new
  out <- paste(lines, collapse = "\n")
  if (final_newline) out <- paste0(out, "\n")
  writeBin(charToRaw(out), f)

  #### Verify ####
  log <- load_download_log()
  logged <- basename(log$filepath)
  files_ok <- all(vapply(fixes, function(x) x$file %in% logged, logical(1)))
  serial_ok <- all(vapply(fixes, function(x) {
    r <- log[basename(log$filepath) == x$file, ]
    nrow(r) == 1 && as.character(r$device_serial) == x$serial && r$download_type == "manual"
  }, logical(1)))
  raw <- utils::read.csv(f, stringsAsFactors = FALSE, colClasses = "character")
  width_ok <- all(vapply(strsplit(sub("\r$", "", readLines(f)[-1]), ","), length, integer(1)) >= 9)
  cat("\n--- VERIFICATION ---\n")
  cat(if (files_ok) "\u2713" else "\u274c", " ", length(fixes), " files now logged by their path\n", sep = "")
  cat(if (serial_ok) "\u2713" else "\u274c", " Each under its own serial, as a manual download\n", sep = "")
  cat(if (width_ok) "\u2713" else "\u274c", " Every row has the log's nine columns\n", sep = "")
  if (!(files_ok && serial_ok && width_ok)) stop("Verification failed - restore from metadata/internal/backups")
  cat("\n\u2713 Download log repaired. build_p2_stale() now finds these files new to their station-years.\n")
  invisible(TRUE)
}
