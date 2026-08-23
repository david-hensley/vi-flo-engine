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

#' Reads the datamap_engine.csv in the data root and lists the named_paths for the user
read_datamap <- function(){
  setwd(Sys.getenv("VI_FLO_DATA_ROOT"))
  datamap <- read.csv("datamap_engine.csv")
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
  setwd(Sys.getenv("VI_FLO_DATA_ROOT"))
  datamap <- read.csv("datamap_engine.csv")
  result <- datamap$absolute_path[datamap$named_path == name][1]
  if (is.na(result)) {
    stop("Named path '", name, "' not found in datamap.\n",
         "Run read_datamap() to see available paths.", call. = FALSE)
  }
  return(result)
}

#' Takes a name for a specific path (i.e. a wd) and the local path.
#' Writes this into both default_datamap.csv (template) and datamap_engine.csv (actual)
#' Use this to add a new named path or overwrite an existing one
#' @param name Character. Identical to what will appear in $named_path in the CSV
#' @param path Character. Full absolute path (must be within VI_FLO_DATA_ROOT)
set_named_path <- function(name, path){
  # Do not permit "root" or "engine" as names, as these serve as the shorthand for data root and engine root
  if (name == "engine" | name == "data"){
    stop("Path must not be named 'engine' or 'data', these are fixed to root paths!")
  }
  # Check if path starts with data root prefix
  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (!grepl(paste0("^", data_root), path)) {
    stop("Path must be within VI_FLO_DATA_ROOT (", data_root, ")\n",
         "Provided path: ", path, call. = FALSE)
  }
  # Strip prefix to get relative path
  prefix_with_slash <- paste0(data_root, "/")
  relative_path <- sub(paste0("^", prefix_with_slash), "", path)
  
  # ========== UPDATE DEFAULT DATAMAP (TEMPLATE) ==========
  setwd(paste0(Sys.getenv("VI_FLO_ENGINE_ROOT"), "/data"))
  default_datamap <- read.csv("default_datamap.csv", stringsAsFactors = FALSE)
  if (name %in% default_datamap$named_path){
    # Record the existing path
    existing_path <- default_datamap$path[default_datamap$named_path == name][1]
    existing_path_full <- paste0(data_root, "/", existing_path)
    # Print warning with cat, then prompt on new line with readline
    cat("⚠️  WARNING: This will overwrite an existing named path:\n")
    cat("  Name:", name, "\n")
    cat("  Current path:", existing_path_full, "\n")
    response <- readline("Do you want to continue? (Y/N): ")
    if (toupper(trimws(response)) == "Y") {
      message("Overwriting...")
      default_datamap$path[default_datamap$named_path == name] <- relative_path
    } else if (toupper(trimws(response)) == "N") {
      stop("Operation cancelled by user", call. = FALSE)
    } else {
      stop("Invalid input. Please enter Y or N", call. = FALSE)
    }
  } else {
    # No existing path - add a new one to the default datamap
    message(paste0("Adding new named path: ", name))
    new_row <- data.frame(named_path = name, path = relative_path, stringsAsFactors = FALSE)
    default_datamap <- rbind(default_datamap, new_row)
  }
  # Write updated default datamap back to CSV
  default_datamap <- default_datamap[order(default_datamap$named_path), ]
  write.csv(default_datamap, "default_datamap.csv", row.names = FALSE)
  message("✓ Updated default_datamap.csv (template)")
  
  # ========== UPDATE ACTUAL DATAMAP (WORKING) ==========
  setwd(data_root)
  # Load actual datamap (or create empty if doesn't exist)
  datamap_file <- "datamap_engine.csv"
  if (file.exists(datamap_file)) {
    actual_datamap <- read.csv(datamap_file, stringsAsFactors = FALSE)
  } else {
    actual_datamap <- data.frame(
      named_path = character(),
      absolute_path = character(),
      date_set = character(),
      stringsAsFactors = FALSE
    )
  }
  
  # Update or add the path in actual datamap
  if (name %in% actual_datamap$named_path) {
    # Update existing
    actual_datamap$absolute_path[actual_datamap$named_path == name] <- path
    actual_datamap$date_set[actual_datamap$named_path == name] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6")
  } else {
    # Add new
    new_actual_row <- data.frame(
      named_path = name,
      absolute_path = path,
      date_set = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6"),
      stringsAsFactors = FALSE
    )
    actual_datamap <- rbind(actual_datamap, new_actual_row)
  }
  
  # Write updated actual datamap
  actual_datamap <- actual_datamap[order(actual_datamap$named_path), ]
  write.csv(actual_datamap, datamap_file, row.names = FALSE)
  message("✓ Updated datamap_engine.csv (actual)")
  message(paste0("✓ Path '", name, "' is now available for use with wds()"))
  invisible(TRUE)
}


######################       GENERAL HELPER FUNCTIONS     ######################

#' Helper function to safely format datetime columns with NAs
#' Formats POSIXct to string, avoids dropping 00:00:00 
#' Also handles NAs within the column gracefully - use this to write to CSVs
#' @param dt_col POSIXct vector that can include NAs
#' @return Character vector representing YYYY-MM-DD HH:MM:SS
format_datetime_safe <- function(dt_col) {
  result <- rep(NA_character_, length(dt_col))
  not_na <- !is.na(dt_col)
  result[not_na] <- format(dt_col[not_na], "%Y-%m-%d %H:%M:%S")
  return(result)
}

#' Parse datetime strings (with time) from either Excel or ISO formats
#' Handles vectors of datetime strings, trying multiple common formats
#' @param datetime_vector Character vector. Datetime strings in either YYYY-MM-DD HH:MM:SS or M/D/YYYY format
#' @param tz Character. Timezone name e.g. "America/Puerto_Rico"
#' @return POSIXct vector. Datetime objects
parse_datetime_flexible <- function(datetime_vector, tz) {
  # Handle mixed formats: try each format on elements that haven't parsed yet
  result <- as.POSIXct(datetime_vector, format = "%Y-%m-%d %H:%M:%S", tz = tz)
  
  # For any that failed, try Excel format with AM/PM (M/D/YYYY H:MM:SS AM/PM)
  still_na <- is.na(result) & !is.na(datetime_vector) & datetime_vector != ""
  if (any(still_na)) {
    result[still_na] <- as.POSIXct(datetime_vector[still_na], format = "%m/%d/%Y %I:%M %p", tz = tz)
  }
  
  # For any still failed, try Excel 24-hour format (M/D/YYYY HH:MM)
  still_na <- is.na(result) & !is.na(datetime_vector) & datetime_vector != ""
  if (any(still_na)) {
    result[still_na] <- as.POSIXct(datetime_vector[still_na], format = "%m/%d/%Y %H:%M", tz = tz)
  }
  
  return(result)
}

#' Parse date strings (no time) from either Excel or ISO formats
#' Handles vectors of date strings, trying multiple common formats
#' @param date_vector Character vector. Date strings in either YYYY-MM-DD or M/D/YYYY format
#' @return Date vector. Date objects
parse_date_flexible <- function(date_vector) {
  # Handle mixed formats: try ISO first, then Excel for any that failed
  result <- as.Date(date_vector, format = "%Y-%m-%d")
  
  # For any that failed (NA), try Excel's format (M/D/YYYY)
  still_na <- is.na(result) & !is.na(date_vector) & date_vector != ""
  if (any(still_na)) {
    result[still_na] <- as.Date(date_vector[still_na], format = "%m/%d/%Y")
  }
  
  return(result)
}