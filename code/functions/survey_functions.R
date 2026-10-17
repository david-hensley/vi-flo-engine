################################################################################
#                           GUT SURVEY FUNCTIONS                               #
#                                                                              #
# Reduces a paired-gauge field survey to the two numbers the metadata needs:   #
# the FALL between the two loggers' measuring points, and the REACH LENGTH     #
# between them along the channel. Slope is fall over reach.                    #
#                                                                              #
# Everything here takes values and returns values. Nothing prompts, nothing    #
# reads the console - the interactive half lives in ui_survey_gut_pair() in    #
# metadata_manager_functions.R. Kept apart so the arithmetic can be tested     #
# on its own, and so a mistake in it is a mistake in one place.                #
#                                                                              #
# THE FALL                                                                     #
#   One instrument setup sees a rebar datum at each logger. The backsight is   #
#   the upstream rebar, the foresight the downstream. A bigger rod reading     #
#   means a LOWER point. Each logger's measuring point (MP) sits a measured    #
#   offset BELOW the top of its rebar. So for each setup:                      #
#                                                                              #
#       fall = (FS + d_down) - (BS + d_up)                                     #
#                                                                              #
#   positive when the upstream MP is higher, which it should be. Several       #
#   independent setups are taken; the two that agree most closely are         #
#   averaged, provided they agree within the tolerance.                        #
#                                                                              #
# THE REACH                                                                    #
#   Summed horizontal distances from a TruPulse export, one leg per shot,      #
#   following the channel.                                                     #
#                                                                              #
# Both raw records are Product 0: the readings exactly as typed, in the units  #
# they were read in, and the TruPulse export exactly as it came off the        #
# device. The numbers written to metadata can always be recomputed from them.  #
#                                                                              #
# Requires: setup_functions.R                                                  #
################################################################################


#### Units ####

# Rod units, offered up front because a rod is graduated one way and every
# reading off it is in that system. Feet-inches-eighths is the awkward one:
# it is three numbers, not a decimal.
ROD_UNITS <- c(
  ft_in_8 = "Feet, inches and eighths (architect's rod)",
  ft      = "Feet, decimal - tenths and hundredths (engineer's rod)",
  m       = "Meters",
  cm      = "Centimeters"
)

# Offsets are chosen independently of the rod. They are measured with a tape
# or a ruler, which may be in anything.
OFFSET_UNITS <- c(
  `in` = "Inches (decimal, e.g. 3.625)",
  cm   = "Centimeters",
  mm   = "Millimeters"
)

# Meters per unit
UNIT_TO_M <- c(m = 1, cm = 0.01, mm = 0.001, ft = 0.3048, `in` = 0.0254,
               yd = 0.9144)

#' Converts a length to meters
#' @param value Numeric
#' @param unit Character. One of names(UNIT_TO_M)
#' @return Numeric meters, NA if the unit is unknown
to_meters <- function(value, unit) {
  f <- UNIT_TO_M[unit]
  if (is.na(f)) return(NA_real_)
  unname(value * f)
}


#' Parses one rod reading as typed into meters
#'
#' Feet-inches-eighths is stored as three numbers - "4 7 3.5" is 4 ft 7 3.5/8
#' in. The workflow asks for each separately and joins them with spaces; this
#' also accepts commas, dashes or slashes between them. Feet and inches are
#' whole numbers, inches 0-11, because 12 inches is a foot. Eighths may carry
#' a decimal - a reading between two graduations is read as a half eighth -
#' but must be under 8.
#'
#' @param text Character. The reading as typed
#' @param unit Character. One of names(ROD_UNITS)
#' @return List with ok, value_m, and message (why it failed)
parse_rod_reading <- function(text, unit) {

  fail <- function(msg) list(ok = FALSE, value_m = NA_real_, message = msg)
  text <- trimws(as.character(text))
  if (!nzchar(text)) return(fail("Nothing entered"))

  if (unit == "ft_in_8") {
    parts <- strsplit(text, "[[:space:],/-]+")[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) != 3) {
      return(fail("Expected three numbers: feet, inches, eighths"))
    }
    n <- suppressWarnings(as.numeric(parts))
    if (any(is.na(n)) || any(n < 0)) {
      return(fail("Feet, inches and eighths must be numbers, zero or more"))
    }
    if (n[1] != round(n[1])) return(fail("Feet must be a whole number"))
    if (n[2] != round(n[2])) return(fail("Inches must be a whole number - put the fraction in eighths"))
    if (n[2] > 11)  return(fail("Inches must be 0-11"))
    if (n[3] >= 8)  return(fail("Eighths must be less than 8"))
    inches <- n[1] * 12 + n[2] + n[3] / 8
    return(list(ok = TRUE, value_m = inches * 0.0254, message = NULL))
  }

  v <- suppressWarnings(as.numeric(text))
  if (is.na(v)) return(fail("Not a number"))
  if (v < 0)    return(fail("A rod reading cannot be negative"))

  m <- to_meters(v, unit)
  if (is.na(m)) return(fail(paste0("Unknown rod unit '", unit, "'")))
  list(ok = TRUE, value_m = m, message = NULL)
}


#' Formats a rod reading for display in its own units
#'
#' Eighths are shown as entered, not reduced - "4' 3 2/8"" rather than
#' "4' 3 1/4"" - so the display matches the notebook.
#'
#' @param text Character. The reading as stored
#' @param unit Character. Rod unit
#' @return Character, e.g. "4' 7 3/8"" or "1.482 m"
format_rod_reading <- function(text, unit) {
  text <- trimws(as.character(text))
  if (unit == "ft_in_8") {
    n <- strsplit(text, "[[:space:],/-]+")[[1]]
    n <- n[nzchar(n)]
    frac <- if (as.numeric(n[3]) == 0) "" else paste0(" ", n[3], "/8")
    return(paste0(n[1], "' ", n[2], frac, "\""))
  }
  paste0(text, " ", unit)
}


#' Formats a fall for display
#'
#' No plus sign - a fall is positive by definition. A negative one is not a
#' fall at all, and says so.
#'
#' @param fall_m Numeric
#' @return Character
format_fall <- function(fall_m) {
  if (is.na(fall_m)) return("(none)")
  if (fall_m < 0) {
    return(sprintf("%.4f m (a climb, not a fall)", fall_m))
  }
  sprintf("%.4f m", fall_m)
}


#### The fall ####

#' Fall between the two measuring points, one value per setup
#'
#' fall = (FS + d_down) - (BS + d_up), everything in meters. The offsets are
#' measured DOWNWARD from the top of the rebar to the measuring point, so a
#' measuring point below its rebar has a positive offset.
#'
#' @param bs_m Numeric vector. Backsight (upstream rebar) readings
#' @param fs_m Numeric vector. Foresight (downstream rebar) readings
#' @param d_up_m Numeric. Offset at the upstream logger
#' @param d_down_m Numeric. Offset at the downstream logger
#' @return Numeric vector, positive when upstream is higher
compute_falls <- function(bs_m, fs_m, d_up_m, d_down_m) {
  (fs_m + d_down_m) - (bs_m + d_up_m)
}


#' Finds the two setups that agree most closely
#'
#' With one setup there is nothing to check it against, and it is returned
#' as such - the caller decides whether to accept an unchecked value. With
#' two or more, every pair is compared and the closest taken. Within
#' tolerance, their mean is the fall.
#'
#' @param falls Numeric vector, one per setup
#' @param tolerance_m Numeric. Agreement threshold (default 10 mm)
#' @return List: n, single (logical), i, j (setup numbers), diff_m, within
#'   (logical), fall_m (the mean, or the single value)
select_agreeing_pair <- function(falls, tolerance_m = 0.010) {

  n <- length(falls)
  if (n == 0) stop("No setups to select from")

  if (n == 1) {
    return(list(n = 1, single = TRUE, i = 1L, j = NA_integer_,
                diff_m = NA_real_, within = NA, fall_m = falls[1]))
  }

  best <- NULL
  for (a in 1:(n - 1)) {
    for (b in (a + 1):n) {
      d <- abs(falls[a] - falls[b])
      if (is.null(best) || d < best$d) best <- list(a = a, b = b, d = d)
    }
  }

  # Rounded before comparing: 10 mm exactly should pass, and floating point
  # turns 0.010 into 0.01000000000000001 often enough to matter
  within <- round(best$d, 6) <= tolerance_m

  list(n = n, single = FALSE, i = best$a, j = best$b, diff_m = best$d,
       within = within, fall_m = mean(falls[c(best$a, best$b)]))
}


#### The reach ####

#' Reads a TruPulse project export
#'
#' The export is a plain-text report: a header carrying "Units:", then one
#' block per measurement with "Horizontal Distance: 7.67 Meters". Only the
#' horizontal distances matter - the target height is arbitrary, so the
#' vertical figures say nothing about the fall.
#'
#' Refuses rather than guesses. Every leg must carry the header's unit, every
#' leg must have a number, and the count must match "Total Measurements" -
#' a leg that failed to parse would otherwise just make the reach shorter.
#'
#' @param path Character. Path to the .txt export
#' @return List: ok, message, unit (as written), unit_code, legs (native
#'   units), legs_m, total (native), total_m, dates (Date vector, one per leg)
read_trupulse_export <- function(path) {

  fail <- function(msg) list(ok = FALSE, message = msg)

  if (!file.exists(path)) return(fail("File not found"))
  lines <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"),
                    error = function(e) NULL)
  if (is.null(lines)) return(fail("Could not read the file"))
  lines <- trimws(lines)

  unit_word_to_code <- function(w) {
    w <- tolower(trimws(w))
    if (w %in% c("meters", "meter", "meters", "meter", "m"))  return("m")
    if (w %in% c("feet", "foot", "ft"))                      return("ft")
    if (w %in% c("yards", "yard", "yd"))                     return("yd")
    NA_character_
  }

  #### Header ####
  unit_line <- grep("^Units:", lines, value = TRUE)
  if (length(unit_line) == 0) {
    return(fail("No 'Units:' line - this does not look like a TruPulse export"))
  }
  unit_word <- trimws(sub("^Units:", "", unit_line[1]))
  unit_code <- unit_word_to_code(unit_word)
  if (is.na(unit_code)) {
    return(fail(paste0("Unrecognized unit '", unit_word, "'")))
  }

  declared <- NA_integer_
  total_line <- grep("^Total Measurements:", lines, value = TRUE)
  if (length(total_line) > 0) {
    declared <- suppressWarnings(as.integer(
      trimws(sub("^Total Measurements:", "", total_line[1]))))
  }

  #### Legs ####
  hd_lines <- grep("^Horizontal Distance:", lines, value = TRUE)
  if (length(hd_lines) == 0) {
    return(fail("No 'Horizontal Distance' lines found"))
  }

  body  <- trimws(sub("^Horizontal Distance:", "", hd_lines))
  value <- suppressWarnings(as.numeric(sub("^([-0-9.]+).*$", "\\1", body)))
  word  <- trimws(sub("^[-0-9.]+", "", body))

  if (any(is.na(value))) {
    bad <- which(is.na(value))
    return(fail(paste0("Leg(s) ", paste(bad, collapse = ", "),
                       " have no horizontal distance (", body[bad[1]], ")")))
  }
  if (any(value <= 0)) {
    return(fail("A horizontal distance of zero or less is not a leg"))
  }

  leg_codes <- vapply(word, unit_word_to_code, character(1), USE.NAMES = FALSE)
  if (any(is.na(leg_codes) | leg_codes != unit_code)) {
    return(fail(paste0("Legs are not all in the header's unit (", unit_word,
                       ") - refusing to mix units")))
  }

  if (!is.na(declared) && declared != length(value)) {
    return(fail(paste0("Header says ", declared, " measurements but ",
                       length(value), " horizontal distances were found")))
  }

  #### Dates, for a check against the survey date ####
  date_lines <- grep("^Date:", lines, value = TRUE)
  dates <- as.Date(trimws(sub("^Date:", "", date_lines)), format = "%m/%d/%Y")

  list(ok = TRUE, message = NULL,
       unit = unit_word, unit_code = unit_code,
       legs = value, legs_m = to_meters(value, unit_code),
       total = sum(value), total_m = to_meters(sum(value), unit_code),
       dates = dates)
}


#' Writes out the reach arithmetic for display
#' @param parsed List from read_trupulse_export()
#' @return Character, e.g. "7.67 + 16.49 = 24.16 m"
format_reach_arithmetic <- function(parsed) {
  u <- parsed$unit_code
  # sprintf, not format(): format() pads every leg to the widest one, which
  # put a stray space in front of a short first leg
  sum_line <- paste0(paste(sprintf("%.2f", parsed$legs), collapse = " + "),
                     " = ", sprintf("%.2f", parsed$total), " ", u)
  if (u != "m") {
    sum_line <- paste0(sum_line, " = ", sprintf("%.2f", parsed$total_m), " m")
  }
  sum_line
}


#### Slope ####

#' Hydraulic slope from fall and reach
#'
#' Higher minus lower over reach, so always positive. Which logger is primary
#' does not enter into it: role says which logger is the anchor, not which
#' way the water runs.
#'
#' @param fall_m Numeric. Upstream MP minus downstream MP
#' @param reach_m Numeric. Along-channel distance
#' @return Numeric, NA if either is missing
compute_slope <- function(fall_m, reach_m) {
  if (is.na(fall_m) || is.na(reach_m) || reach_m <= 0) return(NA_real_)
  abs(fall_m) / reach_m
}


#### Product 0: where the raw records live ####

#' The gut survey Product 0 folder
#'
#' Flat, not one folder per station - the filenames carry the station. Pond
#' surveys will get a sibling folder under surveys/.
#'
#' @param create Logical. Create it if missing
#' @return Character. Absolute path
get_gut_survey_dir <- function(create = TRUE) {
  d <- file.path(wds("discrete"), "surveys", "gut_surveys")
  if (create && !dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}


#' Builds a standard survey filename
#'
#' <station_id>_<quantity>_<method>_<YYYYMMDD>.<ext>. A second survey of the
#' same quantity by the same method on the same day gets _2, _3 rather than
#' overwriting the first - both are records of something that happened.
#'
#' @param station_id Character, e.g. "bta2_hydro"
#' @param quantity Character. "fall" or "reach"
#' @param method Character, e.g. "rod", "trupulse"
#' @param survey_date Character or Date
#' @param ext Character. Extension without the dot
#' @param dir Character. Folder to check for collisions, NULL to skip
#' @return Character. Filename only
build_survey_filename <- function(station_id, quantity, method, survey_date,
                                  ext, dir = NULL) {
  stem <- paste(station_id, quantity, method,
                format(as.Date(survey_date), "%Y%m%d"), sep = "_")
  name <- paste0(stem, ".", ext)
  if (is.null(dir)) return(name)

  k <- 1
  while (file.exists(file.path(dir, name))) {
    k <- k + 1
    name <- paste0(stem, "_", k, ".", ext)
  }
  name
}


#' Whether a filename already follows the survey naming standard
#' @param filename Character
#' @return Logical
is_standard_survey_filename <- function(filename) {
  grepl("^[a-z][a-z0-9]*_[a-z0-9]+_(fall|reach)_[a-z0-9]+_[0-9]{8}(_[0-9]+)?\\.[a-z]+$",
        filename)
}


#' Builds the rod-survey Product 0 table
#'
#' One row per number read in the field: each backsight and foresight, and
#' the two offsets. Readings are kept exactly as typed, beside their unit and
#' their value in meters, so the conversion itself can be checked later.
#' Which setups were accepted is a DECISION about the readings, not a reading,
#' and goes in the maintenance log rather than here.
#'
#' @param station_id Character
#' @param survey_date Character
#' @param upstream_serial,downstream_serial Character
#' @param bs_text,fs_text Character vectors. Readings as typed, one per setup
#' @param rod_unit Character
#' @param d_up_text,d_down_text Character. Offsets as typed
#' @param offset_unit Character
#' @return Data frame
build_fall_rod_table <- function(station_id, survey_date,
                                 upstream_serial, downstream_serial,
                                 bs_text, fs_text, rod_unit,
                                 d_up_text, d_down_text, offset_unit) {
  n <- length(bs_text)
  conv <- function(x) vapply(x, function(t) parse_rod_reading(t, rod_unit)$value_m,
                             numeric(1), USE.NAMES = FALSE)

  sights <- data.frame(
    station_id    = station_id,
    survey_date   = survey_date,
    setup         = rep(seq_len(n), each = 2),
    sight         = rep(c("BS", "FS"), n),
    end           = rep(c("upstream", "downstream"), n),
    device_serial = rep(c(upstream_serial, downstream_serial), n),
    entered       = as.vector(rbind(bs_text, fs_text)),
    unit          = rod_unit,
    value_m       = round(as.vector(rbind(conv(bs_text), conv(fs_text))), 5),
    stringsAsFactors = FALSE
  )

  offsets <- data.frame(
    station_id    = station_id,
    survey_date   = survey_date,
    setup         = NA_integer_,
    sight         = "offset",
    end           = c("upstream", "downstream"),
    device_serial = c(upstream_serial, downstream_serial),
    entered       = c(d_up_text, d_down_text),
    unit          = offset_unit,
    value_m       = round(c(to_meters(as.numeric(d_up_text), offset_unit),
                            to_meters(as.numeric(d_down_text), offset_unit)), 5),
    stringsAsFactors = FALSE
  )

  rbind(sights, offsets)
}


#' Writes the rod-survey Product 0 file
#' @param table Data frame from build_fall_rod_table()
#' @param path Character. Full destination path
#' @return TRUE, or an error message
write_fall_rod_file <- function(table, path) {
  tryCatch({
    if (file.exists(path)) stop("A file already exists at ", path)
    write.csv(table, path, row.names = FALSE)
    if (!file.exists(path)) stop("File was not found on disk after writing")
    TRUE
  }, error = function(e) conditionMessage(e))
}


#' Files a TruPulse export under its standard name
#'
#' A rename where possible. Where the source is on another volume, a copy
#' confirmed on disk before the original is removed, so a failure never loses
#' the only copy.
#'
#' @param from Character. Current path
#' @param to Character. Standard path
#' @return TRUE, or an error message
archive_trupulse_export <- function(from, to) {
  tryCatch({
    if (normalizePath(from, mustWork = FALSE) == normalizePath(to, mustWork = FALSE)) {
      return(TRUE)
    }
    if (file.exists(to)) stop("A file already exists at ", to)
    if (!file.rename(from, to)) {
      if (!file.copy(from, to)) stop("Could not copy the export")
      if (!file.exists(to)) stop("Copy was not found on disk")
      file.remove(from)
    }
    TRUE
  }, error = function(e) conditionMessage(e))
}
