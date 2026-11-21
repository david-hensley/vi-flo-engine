################################################################################
# migrate_device_surveys_v2.9.R
#
# APPLIED: 2026-11-21
#
# Takes the survey values out of device_metadata.csv - step 4.5b. They have
# lived in surveys.csv since step 4.5a, and the workflows now read and write
# them there.
#
#   sensor_height_cm   dropped   every value is in surveys.csv - checked
#   reach_length_m     dropped   every current pair's reach is in surveys.csv -
#                                checked; the two on retired rows, from the
#                                February 2024 surveys, were deliberately not
#                                carried forward
#   elev on the rows   the       a secondary's elevation was the primary's
#   whose source is    primary's plus a surveyed fall. A paired gauge now
#   surveyed_relative            carries one ground elevation, the primary's,
#                                on every logger - copied, not looked up again,
#                                so DEM noise cannot creep in between them. The
#                                fall itself is in surveys.csv
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_device_surveys_v2.9.R"))
#   migrate_device_surveys()                 # dry run: shows what would change
#   migrate_device_surveys(dry_run = FALSE)  # applies it
################################################################################

migrate_device_surveys <- function(dry_run = TRUE) {

  path <- table_path("device_metadata")
  new_cols <- names(TABLE_SCHEMA$device_metadata$columns)
  raw <- utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                         check.names = FALSE, encoding = "UTF-8")
  if (identical(names(raw), new_cols)) {
    cat("✓ device_metadata.csv no longer has the survey columns - nothing to do\n")
    return(invisible(TRUE))
  }
  if (!identical(setdiff(names(raw), new_cols), c("sensor_height_cm", "reach_length_m")) ||
      !all(new_cols %in% names(raw))) {
    stop("device_metadata.csv is not in the shape this migration expects:\n  ",
         paste(names(raw), collapse = ", "), "\nNothing written.", call. = FALSE)
  }

  surveys <- read_table("surveys", remember = FALSE)
  if (nrow(surveys) == 0) {
    stop("surveys.csv is empty - run migrate_surveys_v2.9.R first. Nothing written.",
         call. = FALSE)
  }

  name_of <- function(i) paste0(raw$device_name[i], " (", raw$station_id[i], ", ",
                                raw$unique_id[i], ", ", raw$status[i], ")")
  terminal <- tolower(raw$status) %in% TERMINAL_STATUSES
  problems <- character(0)

  #### Every sensor height is in surveys.csv ####
  cat("\nSensor heights - each must be in surveys.csv:\n")
  for (i in which(!is.na(raw$sensor_height_cm))) {
    v <- as.numeric(raw$sensor_height_cm[i])
    ref <- if (tolower(raw$station_type[i]) == "weather") "ground" else "bed"
    got <- survey_height(raw$unique_id[i], "sensor", raw$unique_id[i], ref, surveys)
    ok <- !is.na(got) && abs(got - v) < 0.01
    if (!ok) problems <- c(problems, paste0("sensor height of ", name_of(i)))
    cat(sprintf("  %s %-58s %6s cm above %s, surveys.csv has %s\n", if (ok) "✓" else "✗",
                name_of(i), format(v), ref, if (is.na(got)) "nothing" else format(got)))
  }

  #### Every current reach is in surveys.csv ####
  cat("\nReach lengths - each current one must be in surveys.csv:\n")
  for (i in which(!is.na(raw$reach_length_m))) {
    v <- as.numeric(raw$reach_length_m[i])
    if (terminal[i]) {
      cat(sprintf("  - %-58s %7s m  not carried forward (a survey from before October 2026)\n",
                  name_of(i), format(v)))
      next
    }
    p <- which(raw$station_id == raw$station_id[i] & !terminal &
                 tolower(raw$device_role) %in% "primary")
    got <- if (length(p) == 1) survey_reach(raw$unique_id[i], raw$unique_id[p], surveys) else NA
    ok <- !is.na(got) && abs(got - v) < 0.005
    if (!ok) problems <- c(problems, paste0("reach of ", name_of(i)))
    cat(sprintf("  %s %-58s %7s m, surveys.csv has %s\n", if (ok) "✓" else "✗",
                name_of(i), format(v), if (is.na(got)) "nothing" else format(got)))
  }

  if (length(problems) > 0) {
    stop("Not in surveys.csv, so dropping the column would lose it:\n  ",
         paste(problems, collapse = "\n  "), "\nNothing written.", call. = FALSE)
  }

  #### Elevations derived from a fall: the primary's instead ####
  # A paired gauge carries one ground elevation, the primary's, on every
  # logger. Copied, never looked up again: a fresh lookup of the same place
  # could differ by DEM noise. A retired logger takes the primary it served
  # with - the one whose deployment overlapped its own
  cat("\nElevations that were a primary's plus a fall - the primary's elevation instead:\n")
  rel <- which(!is.na(raw$elev_source) & raw$elev_source == "surveyed_relative")
  tm <- function(x) as.numeric(parse_datetime_flexible(x, PROJECT_TZ))
  starts <- tm(raw$deploy_datetime)
  ends <- tm(raw$end_datetime); ends[is.na(ends)] <- Inf
  out <- raw
  orphans <- character(0)
  for (i in rel) {
    p <- which(raw$station_id == raw$station_id[i] &
                 tolower(raw$device_role) %in% "primary" & !is.na(raw$elev) &
                 !raw$elev_source %in% "surveyed_relative")
    s0 <- if (is.na(starts[i])) -Inf else starts[i]
    overlap <- p[(is.na(starts[p]) | starts[p] < ends[i]) & ends[p] > s0]
    pick <- if (!terminal[i]) p[!terminal[p]] else overlap
    if (length(pick) == 0) pick <- overlap
    if (length(pick) == 0) {
      orphans <- c(orphans, name_of(i))
      cat(sprintf("  \u2717 %-58s no primary to take an elevation from\n", name_of(i)))
      next
    }
    pick <- pick[which.max(starts[pick])]
    out$elev[i] <- raw$elev[pick]
    out$elev_source[i] <- raw$elev_source[pick]
    cat(sprintf("  \u2713 %-58s %9s m -> %8s m (%s, from %s)\n", name_of(i), raw$elev[i],
                out$elev[i], out$elev_source[i], raw$device_name[pick]))
  }
  if (length(orphans) > 0) {
    stop("No primary to take an elevation from for ", length(orphans), " row(s). ",
         "Nothing written.", call. = FALSE)
  }

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_device_surveys(dry_run = FALSE) to apply it.\n")
    return(invisible(out))
  }

  #### Write: through the layer, which types the columns from the schema ####
  out <- out[, new_cols]
  typed <- read_table("device_metadata", remember = FALSE, path = {
    tmp <- tempfile(fileext = ".csv")
    utils::write.csv(out, tmp, row.names = FALSE, na = "")
    tmp
  })
  write_table("device_metadata", typed, guard = FALSE)

  #### Verify ####
  back <- read_table("device_metadata", remember = FALSE)
  same <- identical(names(back), new_cols) && nrow(back) == nrow(raw) &&
    identical(back$unique_id, raw$unique_id)
  if (!same) stop("device_metadata.csv did not read back as expected", call. = FALSE)
  untouched <- setdiff(seq_len(nrow(raw)), rel)
  if (!isTRUE(all.equal(back$elev[untouched], suppressWarnings(as.numeric(raw$elev[untouched]))))) {
    stop("An elevation other than the copied ones changed", call. = FALSE)
  }
  cat("\n✓ device_metadata.csv written: survey columns gone, ", length(rel),
      " elevation(s) taken from their primary, every other value as it was\n", sep = "")
  res <- validate_metadata(verbose = FALSE)
  if (isTRUE(res$valid)) {
    cat("✓ validation passes\n")
  } else {
    cat("✗ validation finds: ", paste(names(res$violations), collapse = ", "), "\n", sep = "")
  }
  invisible(TRUE)
}
