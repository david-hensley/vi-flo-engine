################################################################################
# migrate_add_sensor_height.R
#
# APPLIED: 2026-10-17
#
# Adds `sensor_height_cm` to device_metadata.csv, after `elev_source`: the
# height of a device's measuring point above the ground at its coordinates.
#
# `elev` is the ground. For a stream gauge the sensor sits 1-2 cm above the
# bed and the difference has been ignored, but a pond logger's measuring
# point can sit 28 cm up, and a water level only becomes a water-surface
# elevation once that height is added.
#
# Weather rows get 200, the standard mounting height, which is known. Every
# other row is left blank. For hydro that means not yet measured - no gauge
# has had the distance taken, and a plausible guess would never be
# questioned. For vwc it means not applicable: soil sensor depths are per
# port in zentra_ports.csv. The two blanks are told apart by station type.
#
# The file is edited line by line - one empty field inserted after
# elev_source on each line - so every existing value is written back exactly
# as it was. Quoted fields containing commas are respected.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_add_sensor_height.R"))
#   migrate_add_sensor_height()                 # dry run
#   migrate_add_sensor_height(dry_run = FALSE)  # applies it
################################################################################

migrate_add_sensor_height <- function(dry_run = TRUE, path = NULL) {

  new_col <- "sensor_height_cm"
  after   <- "elev_source"

  if (is.null(path)) path <- file.path(wds("meta_internal"), "device_metadata.csv")
  if (!file.exists(path)) stop("Not found: ", path)

  # Splits one CSV line into its raw fields, quotes kept, commas inside
  # quotes respected
  split_fields <- function(line) {
    chars <- strsplit(line, "", fixed = TRUE)[[1]]
    fields <- character(0); cur <- character(0); inq <- FALSE
    for (ch in chars) {
      if (ch == "\"") inq <- !inq
      if (ch == "," && !inq) {
        fields <- c(fields, paste(cur, collapse = "")); cur <- character(0)
      } else {
        cur <- c(cur, ch)
      }
    }
    c(fields, paste(cur, collapse = ""))
  }

  raw <- readBin(path, "raw", file.info(path)$size)
  crlf <- length(raw) > 1 && any(raw[-length(raw)] == as.raw(13) &
                                 raw[-1] == as.raw(10))
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  meta  <- read.csv(text = lines, colClasses = "character",
                    stringsAsFactors = FALSE, check.names = FALSE)

  #### Prior application ####
  if (new_col %in% names(meta)) {
    message("\u2713 Already applied: ", new_col, " is present. Nothing to do.")
    return(invisible(TRUE))
  }
  if (!after %in% names(meta)) stop("No '", after, "' column to insert after")
  if (nrow(meta) != length(lines) - 1) {
    stop("Rows and lines do not match - a field may contain a line break. ",
         "Nothing changed.")
  }

  pos <- match(after, names(meta))
  header <- split_fields(lines[1])
  quoted_header <- grepl("^\"", header[pos])

  # Every line must split into exactly the right number of fields
  splits <- lapply(lines, split_fields)
  bad <- which(lengths(splits) != ncol(meta))
  if (length(bad) > 0) {
    stop("Line(s) ", paste(head(bad, 5), collapse = ", "),
         " do not split into ", ncol(meta), " fields. Nothing changed.")
  }

  cat("\n--- ADD ", new_col, " ---\n\n", sep = "")
  cat("File:    ", path, "\n", sep = "")
  cat("Rows:    ", nrow(meta), "\n", sep = "")
  cat("Insert:  after '", after, "' (column ", pos, " of ", ncol(meta), ")\n",
      sep = "")
  is_weather <- tolower(meta$station_type) == "weather"
  cat("Values:  200 on ", sum(is_weather), " weather rows, blank on the other ",
      sum(!is_weather), "\n", sep = "")
  tab <- table(meta$station_type[!is_weather])
  for (t in names(tab)) cat("           ", t, ": ", tab[[t]], " blank\n", sep = "")

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(NULL))
  }

  #### Back up, then insert ####
  if (exists("backup_metadata")) backup_metadata()

  header_value <- if (quoted_header) paste0("\"", new_col, "\"") else new_col
  new_lines <- vapply(seq_along(splits), function(k) {
    f <- splits[[k]]
    ins <- if (k == 1) header_value else if (is_weather[k - 1]) "200" else "NA"
    paste(c(f[seq_len(pos)], ins, f[-seq_len(pos)]), collapse = ",")
  }, character(1))

  con <- file(path, open = "wb")
  writeLines(new_lines, con, sep = if (crlf) "\r\n" else "\n", useBytes = TRUE)
  close(con)

  #### Verify ####
  after_lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  after_meta  <- read.csv(text = after_lines, colClasses = "character",
                          stringsAsFactors = FALSE, check.names = FALSE)

  ok_col   <- identical(names(after_meta),
                        append(names(meta), new_col, after = pos))
  ok_blank <- all(after_meta[[new_col]][is_weather] == "200") &&
              all(is.na(after_meta[[new_col]][!is_weather]))
  ok_rest  <- identical(after_meta[, names(meta)], meta)
  ok_lines <- all(vapply(seq_along(after_lines), function(k) {
    f <- split_fields(after_lines[k])
    identical(f[-(pos + 1)], splits[[k]])
  }, logical(1)))

  cat("\n--- VERIFICATION ---\n")
  cat(if (ok_col) "\u2713" else "\u274c", " Column added after ", after, "\n", sep = "")
  cat(if (ok_blank) "\u2713" else "\u274c", " 200 on weather rows, blank on all others\n", sep = "")
  cat(if (ok_rest) "\u2713" else "\u274c", " Every other value unchanged\n", sep = "")
  cat(if (ok_lines) "\u2713" else "\u274c", " Every other field byte-identical\n", sep = "")

  if (!(ok_col && ok_blank && ok_rest && ok_lines)) {
    stop("Verification failed. Restore from metadata/internal/backups.")
  }
  cat("\n\u2713 ", new_col, " added to ", nrow(meta), " rows\n", sep = "")
  invisible(TRUE)
}
