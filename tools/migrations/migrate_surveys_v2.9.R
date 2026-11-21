################################################################################
# migrate_surveys_v2.9.R
#
# APPLIED: 2026-11-21
#
# Creates surveys.csv - step 4.5a. Every row is a distance between two named
# points, as data/DATA_DICTIONARY.md describes.
#
#   sensor_height_cm   weather rows   ->  sensor above ground, nominal,
#                                         dated the deployment's start
#                      pond rows      ->  sensor above bed, by tape, dated
#                                         the deployment's start
#   the field surveys  FIELD_SURVEYS  ->  as measured: October 2026's four
#                                         pairs and RB C, bta2 on 14 Oct
#                                         2026, and SR2's gauge of zero flow
#
# Nothing is removed from device_metadata.csv: sensor_height_cm,
# reach_length_m and the secondaries' surveyed elevations stay, for the
# workflows that still write them, until step 4.5b moves those workflows onto
# this table.
#
# Each field survey names its loggers by station and serial; the deployment is
# the one the logger was serving on the survey's day. Afterwards every pair's
# sensor-to-sensor fall is chained from the new rows and checked against the
# fall the maintenance log recorded at the time.
#
# Surveys from before the October 2026 trip - fb2 and dor2 in February 2024,
# bta2's test run in September 2026 - are deliberately not carried forward:
# the dor2 loggers and their positions are gone, the fb2 reach was altered by
# that year's events, and the bta2 run was a trial of the method (DAH).
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_surveys_v2.9.R"))
#   migrate_surveys()                 # dry run: shows what would be written
#   migrate_surveys(dry_run = FALSE)  # writes it
################################################################################

#### The field surveys, as measured ####
# serial and ref_serial name the loggers; carried_serial the logger a row was
# carried from. Values in the quantity's unit.
FIELD_SURVEYS <- read.csv(text = '
station_id,serial,measured_on,quantity,point,value,relative_to,ref_serial,method,carried_serial,notes
dor2_hydro,22373554,2026-10-27,height_cm,rebar,26,bed,,tape,,
dor2_hydro,22373554,2026-10-27,height_cm,sensor,0,bed,,tape,,
dor2_hydro,22373551,2026-10-27,height_cm,rebar,25,bed,,tape,,
dor2_hydro,22373551,2026-10-27,height_cm,sensor,0,bed,,tape,,
dor2_hydro,22373554,2026-10-27,height_cm,rebar,237.5,rebar,22373551,laser,,"dor2_hydro_slope_survey_trupulse_2026-10-27.txt; mean of two setups, which differ by 1.0 cm"
dor2_hydro,22373554,2026-10-27,reach_m,,22.36,,22373551,laser,,"dor2_hydro_slope_survey_trupulse_2026-10-27.txt; straight line, mean of two setups"
tr1_hydro,21652374,2026-10-27,height_cm,rebar,30.48,bed,,tape,,"1 ft, as recorded in the survey file"
tr1_hydro,21652374,2026-10-27,height_cm,sensor,0,bed,,tape,,
tr1_hydro,21652376,2026-10-27,height_cm,rebar,12.7,bed,,tape,,"5 in, as recorded in the survey file"
tr1_hydro,21652376,2026-10-27,height_cm,sensor,0,bed,,tape,,
tr1_hydro,21652374,2026-10-27,height_cm,rebar,44,rebar,21652376,laser,,"tr1_hydro_slope_survey_trupulse_2026-10-27.txt; mean of two setups, which differ by 2.0 cm"
tr1_hydro,21652374,2026-10-27,reach_m,,34.39,,21652376,laser,,"tr1_hydro_slope_survey_trupulse_2026-10-27.txt; straight line, mean of two setups"
rb2_hydro,22373557,2026-10-28,height_cm,rebar,16,bed,,tape,,
rb2_hydro,22373557,2026-10-28,height_cm,sensor,0,bed,,tape,,
rb2_hydro,22373552,2026-10-28,height_cm,rebar,24,bed,,tape,,
rb2_hydro,22373552,2026-10-28,height_cm,sensor,0,bed,,tape,,
rb2_hydro,22373555,2026-10-28,height_cm,rebar,19,bed,,tape,,
rb2_hydro,22373555,2026-10-28,height_cm,sensor,0,bed,,tape,,
rb2_hydro,22373557,2026-10-28,height_cm,rebar,53.5,rebar,22373552,laser,,"rb2_hydro_slope_survey_trupulse_2026-10-28.txt; mean of two setups, which differ by 1.0 cm"
rb2_hydro,22373557,2026-10-28,reach_m,,25.74,,22373552,laser,,"rb2_hydro_slope_survey_trupulse_2026-10-28.txt; straight line, mean of two setups"
rb2_hydro,22373555,2026-10-28,height_cm,rebar,-127.5,rebar,22373552,laser,,"rb2_hydro_C_slope_survey_trupulse_2026-10-28.txt; traverse out and back by turning points, mean of the two; loop misclosure 11 cm vertical"
rb2_hydro,22373555,2026-10-28,reach_m,,72.26,,22373552,laser,,"rb2_hydro_C_slope_survey_trupulse_2026-10-28.txt; the path the shots followed, each leg judged straight, mean of out and back"
fb2_hydro,22373550,2026-10-28,height_cm,rebar,16,bed,,tape,,
fb2_hydro,22373550,2026-10-28,height_cm,sensor,0,bed,,tape,,
fb2_hydro,21179105,2026-10-28,height_cm,rebar,15,bed,,tape,,
fb2_hydro,21179105,2026-10-28,height_cm,sensor,0,bed,,tape,,
fb2_hydro,22373550,2026-10-28,height_cm,rebar,31,rebar,21179105,laser,,"fb2_hydro_slope_survey_trupulse_2026-10-28.txt; mean of two setups, which differ by 2.0 cm"
fb2_hydro,22373550,2026-10-28,reach_m,,50.36,,21179105,laser,,"fb2_hydro_slope_survey_trupulse_2026-10-28.txt; straight line, mean of two setups"
bta2_hydro,21652379,2026-10-14,height_cm,rebar,24.94,sensor,,tape,,"the offset in bta2_hydro_fall_rod_20261014.csv"
bta2_hydro,22357376,2026-10-14,height_cm,rebar,24.94,sensor,,tape,,"the offset in bta2_hydro_fall_rod_20261014.csv"
bta2_hydro,21652379,2026-10-14,height_cm,rebar,12.94,rebar,22357376,level,,"bta2_hydro_fall_rod_20261014.csv; setups 2 and 3, which agree within 7.9 mm; setup 1 rejected"
bta2_hydro,21652379,2026-10-14,reach_m,,24.16,,22357376,laser,,"bta2_hydro_reach_trupulse_20261014.txt; two legs following the channel"
sr2_hydro,21180079,2023-11-26,height_cm,overflow,27,sensor,,level,,"gauge of zero flow, builder\'s level and rod; from the prototype rating curves (qcurves6)"
sr2_hydro,21652378,2023-11-26,height_cm,overflow,27,sensor,,level,21180079,"same housing, so the same sensor height"
', colClasses = "character", na.strings = "", strip.white = TRUE)

# What the maintenance log recorded for each pair's fall at the time, in cm:
# the chained result must agree
LOGGED_FALLS <- read.csv(text = '
station_id,serial,ref_serial,fall_cm
dor2_hydro,22373554,22373551,236.5
tr1_hydro,21652374,21652376,26.2
rb2_hydro,22373557,22373552,61.5
rb2_hydro,22373552,22373555,122.5
fb2_hydro,22373550,21179105,30
bta2_hydro,21652379,22357376,12.94
', colClasses = c("character", "character", "character", "numeric"), strip.white = TRUE)


migrate_surveys <- function(dry_run = TRUE) {

  path <- table_path("surveys")
  if (file.exists(path)) {
    existing <- read_table("surveys", remember = FALSE)
    if (nrow(existing) > 0) {
      cat("✓ surveys.csv already exists, with ", nrow(existing),
          " rows - nothing to do\n", sep = "")
      return(invisible(TRUE))
    }
  }

  meta_raw <- utils::read.csv(table_path("device_metadata"), colClasses = "character",
                              na.strings = c("", "NA"), check.names = FALSE,
                              encoding = "UTF-8")
  meta <- read_table("device_metadata", remember = FALSE)
  name_of <- function(uid) {
    m <- meta[match(uid, meta$unique_id), ]
    paste0(m$device_name, " (", m$station_id, ", ", m$unique_id, ", ", m$status, ")")
  }
  cols <- names(TABLE_SCHEMA$surveys$columns)
  blank <- function(n) as.character(rep(NA, n))

  #### Sensor heights already in device_metadata ####
  h <- meta_raw[!is.na(meta_raw$sensor_height_cm), , drop = FALSE]
  type <- tolower(h$station_type)
  carried <- h[type %in% c("weather", "pond"), , drop = FALSE]
  skipped <- h[!type %in% c("weather", "pond"), , drop = FALSE]
  undated <- carried[is.na(carried$deploy_datetime), , drop = FALSE]
  if (nrow(undated) > 0) {
    stop("A sensor height on a deployment with no start, so no date to give it:\n  ",
         paste(name_of(undated$unique_id), collapse = "\n  "),
         "\nNothing written.", call. = FALSE)
  }
  weather <- tolower(carried$station_type) == "weather"
  from_column <- data.frame(
    station_id = carried$station_id, unique_id = carried$unique_id,
    measured_on = substr(carried$deploy_datetime, 1, 10), quantity = "height_cm",
    point = "sensor", value = carried$sensor_height_cm,
    relative_to = ifelse(weather, "ground", "bed"), relative_to_id = blank(nrow(carried)),
    method = ifelse(weather, "nominal", "tape"), carried_from = blank(nrow(carried)),
    notes = blank(nrow(carried)), stringsAsFactors = FALSE)

  #### The field surveys ####
  f <- FIELD_SURVEYS
  uid <- function(serial, station, when) {
    vapply(seq_along(serial), function(i) {
      if (is.na(serial[i])) return(NA_character_)
      resolve_deployment(serial[i], station[i], when[i], meta)
    }, character(1))
  }
  f$unique_id      <- uid(f$serial, f$station_id, f$measured_on)
  f$relative_to_id <- uid(f$ref_serial, f$station_id, f$measured_on)
  f$carried_from   <- uid(f$carried_serial, f$station_id, f$measured_on)
  lost <- (is.na(f$unique_id)) | (!is.na(f$ref_serial) & is.na(f$relative_to_id)) |
    (!is.na(f$carried_serial) & is.na(f$carried_from))
  if (any(lost)) {
    stop("No deployment found for:\n  ",
         paste(f$station_id[lost], f$serial[lost], f$measured_on[lost], collapse = "\n  "),
         "\nNothing written.", call. = FALSE)
  }
  from_field <- f[, cols]

  rows <- rbind(from_column, from_field)
  rows$measured_on <- as.Date(rows$measured_on)
  rows$value <- as.numeric(rows$value)
  rows <- rows[order(rows$station_id, rows$measured_on), cols]
  rownames(rows) <- NULL

  #### What would be written ####
  cat("\nsurveys.csv - ", nrow(rows), " rows\n", sep = "")
  cat("\n  From sensor_height_cm in device_metadata.csv: ", nrow(from_column), "\n", sep = "")
  for (i in seq_len(nrow(from_column))) {
    r <- from_column[i, ]
    cat(sprintf("    %-55s sensor %s cm above %s, %s, %s\n", name_of(r$unique_id),
                r$value, r$relative_to, r$method, r$measured_on))
  }
  if (nrow(skipped) > 0) {
    cat("\n  Not carried from the column - covered by the field surveys below:\n")
    for (i in seq_len(nrow(skipped))) {
      cat(sprintf("    %-55s %s cm\n", name_of(skipped$unique_id[i]),
                  skipped$sensor_height_cm[i]))
    }
  }
  cat("\n  Field surveys: ", nrow(from_field), "\n", sep = "")
  for (i in seq_len(nrow(from_field))) {
    r <- from_field[i, ]
    what <- if (r$quantity == "reach_m") {
      paste0("reach ", r$value, " m to ", name_of(r$relative_to_id))
    } else {
      paste0(r$point, " ", r$value, " cm above ",
             if (!is.na(r$relative_to_id)) paste0(name_of(r$relative_to_id), "'s ") else "",
             r$relative_to)
    }
    cat(sprintf("    %s  %-50s %s, %s%s\n", r$measured_on, name_of(r$unique_id), what, r$method,
                if (!is.na(r$carried_from)) paste0(", carried from ", name_of(r$carried_from)) else ""))
  }

  #### Each pair's fall, chained, against what the log recorded ####
  rows_typed <- rows
  cat("\n  Falls chained sensor to sensor, against the maintenance log:\n")
  ok <- TRUE
  for (i in seq_len(nrow(LOGGED_FALLS))) {
    l <- LOGGED_FALLS[i, ]
    day <- FIELD_SURVEYS$measured_on[FIELD_SURVEYS$station_id == l$station_id][1]
    a <- resolve_deployment(l$serial, l$station_id, day, meta)
    b <- resolve_deployment(l$ref_serial, l$station_id, day, meta)
    got <- survey_height(a, "sensor", b, "sensor", rows_typed)
    agree <- !is.na(got) && abs(got - l$fall_cm) < 0.1
    ok <- ok && agree
    cat(sprintf("    %s %-30s above %-30s %8.2f cm, logged %7.2f   %s\n",
                if (agree) "✓" else "✗", name_of(a), name_of(b), got, l$fall_cm,
                if (agree) "" else "DISAGREES"))
  }
  if (!ok) stop("A chained fall disagrees with the log. Nothing written.", call. = FALSE)

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_surveys(dry_run = FALSE) to write it.\n")
    return(invisible(rows))
  }

  write_table("surveys", rows, guard = FALSE)

  #### Verify ####
  back <- read_table("surveys", remember = FALSE)
  same <- nrow(back) == nrow(rows) &&
    isTRUE(all.equal(back$value, rows$value)) &&
    identical(back$unique_id, rows$unique_id)
  if (!same) stop("surveys.csv did not read back as written", call. = FALSE)
  cat("\n✓ surveys.csv written: ", nrow(back), " rows, read back identical\n", sep = "")
  res <- validate_metadata(verbose = FALSE)
  sv <- grep("^SURVEY_|^LOAD_SURVEYS", names(res$violations), value = TRUE)
  if (length(sv) > 0) {
    cat("✗ validation finds problems in the survey rows: ", paste(sv, collapse = ", "), "\n", sep = "")
  } else {
    cat("✓ validation passes the survey rows\n")
  }
  invisible(TRUE)
}
