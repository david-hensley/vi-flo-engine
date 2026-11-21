################################################################################
# migrate_ports_v2.9.R
#
# APPLIED: 2026-11-21
#
# Brings zentra_ports.csv to its v2.9 shape - step 4.3.
#
#   sn, type  ->  unique_id   each row names the deployment its sensor serves;
#                             the logger and the kind of station come from it
#   "none" rows   dropped     an empty port needs no row
#   ECRN-50 rain gauges       status "excluded": plugged in and recorded,
#                             never ingested. Attached to the vwc deployment
#                             each was plugged into; a start date that was
#                             never known stays blank
#
# Each row's deployment is the one Product 2 already reads it against: the
# logger's deployment of the port's type whose span the port's overlaps. A row
# that spans two such deployments - a logger moved within its station, sensors
# and all - is split where the second begins, one row for each. A row that
# overlaps none stops the migration with nothing written; it is never guessed.
#
# Product 2 builds the same files from the new table. The unattributed report
# no longer lists the rain gauge ports.
#
# Reads the table raw, since the engine's schema already describes the new
# shape; writes it through the data layer, which backs it up first.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_ports_v2.9.R"))
#   migrate_ports()                 # dry run: shows what would change
#   migrate_ports(dry_run = FALSE)  # applies it
################################################################################

migrate_ports <- function(dry_run = TRUE) {

  path <- table_path("zentra_ports")
  old_cols <- c("sn", "port", "type", "sensor", "depth_cm", "status", "valid_from", "valid_to")
  new_cols <- names(TABLE_SCHEMA$zentra_ports$columns)

  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8")
  if (identical(names(raw), new_cols)) {
    cat("✓ zentra_ports.csv is already in its v2.9 shape - nothing to do\n")
    return(invisible(TRUE))
  }
  if (!identical(names(raw), old_cols)) {
    stop("zentra_ports.csv has neither the old columns nor the new ones:\n  ",
         paste(names(raw), collapse = ", "), "\nNothing written.", call. = FALSE)
  }

  meta <- read_table("device_metadata", remember = FALSE)
  w <- deployment_windows(meta)
  name_of <- function(uid) {
    m <- meta[match(uid, meta$unique_id), ]
    paste0(m$device_name, " (", m$station_id, ")")
  }
  tm <- function(x) as.numeric(parse_datetime_flexible(x, PROJECT_TZ))

  #### Placeholders ####
  empty <- is.na(raw$sensor) | raw$sensor == "none"
  real <- raw[!empty, , drop = FALSE]

  #### Each row's deployment ####
  out <- list(); split_rows <- character(0); lost <- integer(0); excluded <- character(0)
  for (i in seq_len(nrow(real))) {
    r <- real[i, ]
    rain <- tolower(r$type) == "precip"
    type <- if (rain) "vwc" else tolower(r$type)
    s <- tm(r$valid_from); if (is.na(s)) s <- -Inf
    e <- tm(r$valid_to);   if (is.na(e)) e <- Inf
    d <- w[w$device_serial == r$sn & w$station_type == type, , drop = FALSE]
    ds <- as.numeric(d$starts)
    de <- ifelse(is.na(d$ends), Inf, as.numeric(d$ends))
    d <- d[ds < e & de > s, , drop = FALSE]
    d <- d[order(d$starts), , drop = FALSE]
    if (nrow(d) == 0) { lost <- c(lost, i); next }

    for (k in seq_len(nrow(d))) {
      piece <- data.frame(
        unique_id  = d$unique_id[k], port = r$port, sensor = r$sensor,
        depth_cm   = r$depth_cm,
        status     = if (rain) "excluded" else r$status,
        # Split only where one deployment hands over to the next; the row's
        # own first and last moments are kept as they were
        valid_from = if (k == 1) r$valid_from
                     else format(d$starts[k], "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ),
        valid_to   = if (k == nrow(d)) r$valid_to
                     else format(d$starts[k + 1], "%Y-%m-%d %H:%M:%S", tz = PROJECT_TZ),
        stringsAsFactors = FALSE)
      out[[length(out) + 1]] <- piece
    }
    if (nrow(d) > 1) {
      split_rows <- c(split_rows, paste0(
        name_of(d$unique_id[1]), " port ", r$port, " (", r$sensor, "), ",
        r$valid_from, " to ", ifelse(is.na(r$valid_to), "open", r$valid_to),
        "\n      split at ", format(d$starts[-1], "%Y-%m-%d %H:%M", tz = PROJECT_TZ),
        " into ", paste(d$unique_id, collapse = " and ")))
    }
    if (rain) excluded <- c(excluded, paste0(name_of(d$unique_id[1]), " port ", r$port,
                                            " (", r$sensor, ")"))
  }

  if (length(lost) > 0) {
    cat("These port rows overlap no deployment of their logger and type:\n\n")
    print(real[lost, ], row.names = FALSE)
    stop("\n", length(lost), " row(s) could not be given a deployment. Nothing written.",
         call. = FALSE)
  }
  new <- do.call(rbind, out)

  #### What would change ####
  cat("zentra_ports.csv: ", nrow(raw), " rows\n\n", sep = "")
  cat("  Placeholders dropped: ", sum(empty), " (empty ports, no dates)\n", sep = "")
  cat("  Port rows kept:       ", nrow(real), ", each naming its deployment\n", sep = "")
  cat("  Excluded:             ", length(excluded), " rain gauge(s)\n", sep = "")
  for (x in excluded) cat("      ", x, "\n", sep = "")
  cat("  Split:                ", length(split_rows), " row(s) spanning two deployments\n", sep = "")
  for (x in split_rows) cat("      ", x, "\n", sep = "")
  cat("  Result:               ", nrow(new), " rows\n", sep = "")

  unknown <- setdiff(unique(new$status[!is.na(new$status)]), PORT_STATUSES)
  if (length(unknown) > 0) {
    cat("\n  ! Statuses not in the list - kept as they are, for you to look at: ",
        paste(unknown, collapse = ", "), "\n", sep = "")
  }

  if (dry_run) {
    cat("\nDry run - nothing written. Run migrate_ports(dry_run = FALSE) to apply.\n")
    return(invisible(new))
  }

  #### Write, then check what landed ####
  if (!isTRUE(write_table("zentra_ports", new, guard = FALSE,
                          intent = "migrating the port table to v2.9"))) {
    stop("Not written.", call. = FALSE)
  }

  back <- load_zentra_ports_data()
  ok_rows <- nrow(back) == nrow(new)
  ok_ids  <- all(back$unique_id %in% meta$unique_id)
  # Every row's deployment is on the logger it was recorded against, and of
  # its type - or vwc, for a rain gauge
  was_type <- ifelse(tolower(real$type) == "precip", "vwc", tolower(real$type))
  key_was <- sort(unique(paste(real$sn, real$port, was_type)))
  key_now <- sort(unique(paste(back$sn, back$port, back$type)))
  ok_keys <- identical(key_was, key_now)
  if (!(ok_rows && ok_ids && ok_keys)) {
    stop("Verification failed - restore zentra_ports.csv from metadata/internal/backups",
         call. = FALSE)
  }
  cat("\n✓ zentra_ports.csv migrated: ", nrow(back), " rows, each naming a deployment of ",
      "its own logger and kind. Backup in metadata/internal/backups.\n", sep = "")
  invisible(TRUE)
}
