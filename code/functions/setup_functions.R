# VI-FLO Engine set-up functions
# Functions for setting up working directory paths and initializing R scripts

######################          DATAMAP FUNCTIONS         ######################

#' Loads a group of functions by the file name, e.g. "api" for api_functions.R
#' @param func_name Character. This is the prefix of the requested _functions.R file
load_functions <- function(func_name) {
  prefix <- paste0(Sys.getenv("VI_FLO_ENGINE_ROOT"), "/code/functions/")
  suffix <- paste0(func_name, "_functions.R")
  filepath <- paste0(prefix, suffix)
  source(filepath)
  message("✓ Loaded ", func_name, "_functions.R")
  invisible(TRUE)
}

#' Loads every function file in code/functions/
#'
#' Discovers the files rather than listing them, so a new _functions.R file is
#' picked up automatically and there is no list to forget to update.
#'
#' setup_functions.R is skipped - if you are calling this, it is already loaded.
#'
#' @param quiet Logical. Say nothing at all, not even the count (default FALSE)
#' @param each Logical. List every file as it loads (default FALSE)
#' @return Invisible character vector of the prefixes loaded
load_all_functions <- function(quiet = FALSE, each = FALSE) {

  func_dir <- file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code", "functions")

  if (!dir.exists(func_dir)) {
    stop("Cannot find code/functions - is VI_FLO_ENGINE_ROOT set correctly?",
         call. = FALSE)
  }

  files <- list.files(func_dir, pattern = "_functions\\.R$")
  prefixes <- sub("_functions\\.R$", "", files)
  prefixes <- setdiff(prefixes, "setup")

  # One line for the lot, not one per file: twenty lines of ticks bury what
  # start.R goes on to say. A file that fails to load still stops with its
  # error. `each = TRUE` lists them, for when that is what is wanted
  for (p in prefixes) {
    if (quiet || !each) {
      suppressMessages(load_functions(p))
    } else {
      load_functions(p)
    }
  }

  if (!quiet) {
    message("\u2713 ", length(prefixes), " function files loaded")
  }

  # Here rather than in start.R, because start.R is not the only way in. The
  # metadata manager launcher calls load_all_functions() directly, and without
  # this the manager's network views failed with "no API key found" while the
  # same functions worked from the console.
  # Not passed `quiet`. A missing key is the one thing here a person can act
  # on, and the launcher - which loads quietly - is exactly where it was being
  # missed.
  connect_zentracloud()

  invisible(prefixes)
}


#' Hands the ZentraCloud key to zentraR
#'
#' Every function that reaches the API needs this done first, and doing it by
#' hand each session is a step that only ever gets forgotten - the call then
#' fails with an authentication error rather than saying what is missing.
#'
#' Silent on success. A missing token or package always says so, because those
#' are the two things a person can fix.
#'
#' @return Invisible TRUE if the key was set
connect_zentracloud <- function() {

  token <- Sys.getenv("ZENTRACLOUD_V5_TOKEN")

  if (!nzchar(token)) {
    cat("  ! ZENTRACLOUD_V5_TOKEN is not set - the API will not work\n")
    cat("    Check tools/api_tokens.csv, run set_api_tokens.py, then close\n")
    cat("    and reopen RStudio - a running session keeps the old value\n")
    return(invisible(FALSE))
  }

  if (!requireNamespace("zentraR", quietly = TRUE)) {
    cat("  ! the zentraR package is not installed\n")
    return(invisible(FALSE))
  }

  suppressPackageStartupMessages(library(zentraR))

  ok <- tryCatch({ zc_set_key(token); TRUE },
                 error = function(e) {
                   cat("  ! could not set the ZentraCloud key: ",
                       conditionMessage(e), "\n", sep = "")
                   FALSE
                 })

  invisible(ok)
}

#' Reads the datamap_engine.csv in the data root and lists the named_paths for the user
read_datamap <- function(){
  datamap <- read.csv(file.path(Sys.getenv("VI_FLO_DATA_ROOT"),
                                "datamap_engine.csv"))
  cat("Available named paths:\n")  
  cat(paste0("  - ", unique(datamap$named_path)), sep = "\n")
}

#' Takes a named path and returns the actual path for easy setwd() calls
#' Example usage: setwd(wds("meta_internal"))
#' @param name Character. Identical to the named_path in datamap.csv
#' @return Character. Absolute path to the named path, especially for use in setwd()
wds <- function(name){
  if (name == "data"){
    return(Sys.getenv("VI_FLO_DATA_ROOT"))
  }
  if (name == "engine"){
    return(Sys.getenv("VI_FLO_ENGINE_ROOT"))
  }
  # Read by full path rather than setwd()-ing there. wds() is called by almost
  # everything, so a working directory change here moved the session's
  # directory on every path lookup - which is how .Rhistory files ended up
  # being written into metadata/internal.
  datamap <- read.csv(file.path(Sys.getenv("VI_FLO_DATA_ROOT"),
                                "datamap_engine.csv"))
  result <- datamap$absolute_path[datamap$named_path == name][1]
  if (is.na(result)) {
    stop("Named path '", name, "' not found in datamap.\n",
         "Run read_datamap() to see available paths.", call. = FALSE)
  }
  return(result)
}

######################       GENERAL HELPER FUNCTIONS     ######################

#' Helper function to safely format datetime columns with NAs
#' Formats POSIXct to string, avoids dropping 00:00:00 
#' Also handles NAs within the column gracefully - use this to write to CSVs
#' @param dt_col POSIXct vector that can include NAs
#' @return Character vector representing YYYY-MM-DD HH:MM:SS
format_datetime_safe <- function(dt_col, tz = PROJECT_TZ) {
  result <- rep(NA_character_, length(dt_col))
  not_na <- !is.na(dt_col)

  if (!any(not_na)) return(result)

  # A column that is entirely NA comes back from read.csv typed as LOGICAL,
  # and one read without date parsing comes back as CHARACTER. format() on
  # either reads its second argument as `trim` and errors, so only reach for
  # the datetime format when the column actually holds datetimes. Anything
  # else is already a string, or should be treated as one.
  if (inherits(dt_col, "POSIXct") || inherits(dt_col, "POSIXlt") ||
      inherits(dt_col, "Date")) {
    # With an explicit zone, because format() on a POSIXct otherwise uses
    # whichever zone the object carries. Readings and the fields derived
    # from them are project local; a caller writing a machine event passes
    # tz = "UTC". Getting this wrong moves a 21:58 reading onto the
    # following day.
    result[not_na] <- format(dt_col[not_na], "%Y-%m-%d %H:%M:%S", tz = tz)
  } else {
    result[not_na] <- as.character(dt_col[not_na])
  }

  return(result)
}

#' Parse datetime strings (with time) from either Excel or ISO formats
#' Handles vectors of datetime strings, trying multiple common formats
#' @param datetime_vector Character vector. Datetime strings in either YYYY-MM-DD HH:MM:SS or M/D/YYYY format
#' @param tz Character. Timezone name e.g. "America/Puerto_Rico"
#' @return POSIXct vector. Datetime objects
parse_datetime_flexible <- function(datetime_vector, tz) {

  # Already a datetime? Nothing to parse. Callers reach this function with
  # values straight out of load_zentra_metadata(), which has parsed them
  # already - and the emptiness test below would then try to coerce "" into a
  # datetime to compare against, which errors with "character string is not in
  # a standard unambiguous format".
  if (inherits(datetime_vector, "POSIXct")) return(datetime_vector)
  if (inherits(datetime_vector, "POSIXlt")) return(as.POSIXct(datetime_vector))
  if (inherits(datetime_vector, "Date")) {
    return(as.POSIXct(format(datetime_vector), tz = tz))
  }

  # A column that is entirely NA comes back from read.csv typed as logical
  as_text <- as.character(datetime_vector)

  # Handle mixed formats: try each format on elements that haven't parsed yet
  result <- as.POSIXct(as_text, format = "%Y-%m-%d %H:%M:%S", tz = tz)

  # The same without seconds - what a person types. Missing this, a typed
  # "2023-11-06 10:45" fell through to the date-only parser and came back as
  # midnight, the time silently dropped
  still_na <- is.na(result) & !is.na(as_text) & nzchar(as_text)
  if (any(still_na)) {
    result[still_na] <- as.POSIXct(as_text[still_na], format = "%Y-%m-%d %H:%M", tz = tz)
  }

  # For any that failed, try Excel format with AM/PM (M/D/YYYY H:MM:SS AM/PM)
  still_na <- is.na(result) & !is.na(as_text) & nzchar(as_text)
  if (any(still_na)) {
    result[still_na] <- as.POSIXct(as_text[still_na], format = "%m/%d/%Y %I:%M %p", tz = tz)
  }

  # For any still failed, try Excel 24-hour format (M/D/YYYY HH:MM)
  still_na <- is.na(result) & !is.na(as_text) & nzchar(as_text)
  if (any(still_na)) {
    result[still_na] <- as.POSIXct(as_text[still_na], format = "%m/%d/%Y %H:%M", tz = tz)
  }

  return(result)
}

#' Parse date strings (no time) from either Excel or ISO formats
#' Handles vectors of date strings, trying multiple common formats
#' @param date_vector Character vector. Date strings in either YYYY-MM-DD or M/D/YYYY format
#' @return Date vector. Date objects
parse_date_flexible <- function(date_vector) {

  # Same guard as parse_datetime_flexible: an already-parsed value needs no
  # parsing, and the emptiness test below would otherwise try to coerce ""
  # into a date to compare against.
  if (inherits(date_vector, "Date")) return(date_vector)
  if (inherits(date_vector, "POSIXct") || inherits(date_vector, "POSIXlt")) {
    return(as.Date(date_vector))
  }

  as_text <- as.character(date_vector)

  # Handle mixed formats: try ISO first, then Excel for any that failed
  result <- as.Date(as_text, format = "%Y-%m-%d")

  # For any that failed (NA), try Excel's format (M/D/YYYY)
  still_na <- is.na(result) & !is.na(as_text) & nzchar(as_text)
  if (any(still_na)) {
    result[still_na] <- as.Date(as_text[still_na], format = "%m/%d/%Y")
  }

  return(result)
}


#' A path relative to a root folder
#'
#' Compared as text, not as a pattern: a folder whose name holds a character
#' a pattern would read specially - ( + . - cannot break it. Backslashes are
#' made forward slashes on both sides first, as Windows may give either.
#'
#' @param path Character vector of paths
#' @param root Character. The root; the data root by default
#' @return Character, relative to root - unchanged where a path is not under it
path_relative_to <- function(path, root = Sys.getenv("VI_FLO_DATA_ROOT")) {
  p <- gsub("\\\\", "/", path)
  r <- sub("/+$", "", gsub("\\\\", "/", root))
  under <- startsWith(p, paste0(r, "/"))
  p[under] <- substring(p[under], nchar(r) + 2)
  p
}

