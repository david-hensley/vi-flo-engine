# All necessary functions for reimportation process (Summer 2024) are stored here
# And this will also be the source for all future importation and QA/QC functions
library(dplyr); library(zoo)

######################       SETUP AND ARCHIVING          ######################
# Setup and archive functions
setup.func <- function(dir, status){
  if (status == "online"){
    hier <- "C:/Users"
    suf <- "Box/Hensley, David/03-Hydro"
    setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))
  } else if (status == "offline"){
    hier <- "C:/Users"
    suf <- "Desktop/Offline_box/03-Hydro"
    setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))
  } else {
    cat("Unrecognized working status - use 'offline' or 'online'")
  }
  source("00-functions.R")
  wds(hier, dir, suf)
}
#wds <- function(hier, dir, suf){
#  wd.level <<- paste(hier, dir, suf, "Data/Raw-level", sep = "/")
#  wd.weather <<- paste(hier, dir, suf, "Data/Raw-weather", sep = "/")
#  wd.vwc <<- paste(hier, dir, suf, "Data/Raw-VWC", sep = "/")
#  wd.archive <<- paste(hier, dir, suf, "Data/Archive", sep = "/")
#  wd.code <<- paste(hier, dir, suf, "Code/Archiving", sep = "/")
#  wd.backup <<- paste(hier, dir, suf, "Data/Backup", sep = "/")
#  wd.sites <<- paste(hier, dir, suf, "Data/Site-info", sep = "/")
#  wd.nasa <<- paste(hier, dir, suf, "Data/NASA", sep = "/")
#  wd.daymet <<- paste(hier, dir, suf, "Data/Daymet", sep = "/")
#  wd.raws <<- paste(hier, dir, suf, "Data/Raw-RAWS", sep = "/")
#  wd.noaa <<- paste(hier, dir, suf, "Data/NOAA", sep = "/")
#  wd.krige <<- paste(hier, dir, suf, "Data/Kriging", sep = "/")
#  wd.splices <<- paste(hier, dir, suf, "Data/Splices", sep = "/")
#  wd.analysis <<- paste(hier, dir, suf, "Data/Analysis", sep = "/")
#  all.wds <- data.frame(wd = c("level", "weather", "vwc", "archive", "code", 
#                               "backup", "sites", "nasa", "daymet", "raws", "noaa", "krige", "splices", "analysis"),
#                        paths = c(wd.level, wd.weather, wd.vwc, wd.archive, wd.code, 
#                                  wd.backup, wd.sites, wd.nasa, wd.daymet, wd.raws, wd.noaa, wd.krige, wd.splices, wd.analysis))
#  print(all.wds)
#  return(all.wds)
#}

wds <- function(path){
  wd.level <<- paste(path, "Data/Raw-level", sep = "/")
  wd.weather <<- paste(path, "Data/Raw-weather", sep = "/")
  wd.vwc <<- paste(path, "Data/Raw-VWC", sep = "/")
  wd.archive <<- paste(path, "Data/Archive", sep = "/")
  wd.code <<- paste(path, "Code/Archiving", sep = "/")
  wd.backup <<- paste(path, "Data/Backup", sep = "/")
  wd.sites <<- paste(path, "Data/Site-info", sep = "/")
  wd.nasa <<- paste(path, "Data/NASA", sep = "/")
  wd.daymet <<- paste(path, "Data/Daymet", sep = "/")
  wd.raws <<- paste(path, "Data/Raw-RAWS", sep = "/")
  wd.noaa <<- paste(path, "Data/NOAA", sep = "/")
  wd.krige <<- paste(path, "Data/Kriging", sep = "/")
  wd.splices <<- paste(path, "Data/Splices", sep = "/")
  wd.analysis <<- paste(path, "Data/Analysis", sep = "/")
  all.wds <- data.frame(wd = c("level", "weather", "vwc", "archive", "code", 
                               "backup", "sites", "nasa", "daymet", "raws", "noaa", "krige", "splices", "analysis"),
                        paths = c(wd.level, wd.weather, wd.vwc, wd.archive, wd.code, 
                                  wd.backup, wd.sites, wd.nasa, wd.daymet, wd.raws, wd.noaa, wd.krige, wd.splices, wd.analysis))
  print(all.wds)
  return(all.wds)
}

getlat <- function(wd, sitename){
  setwd(wd$path[wd$wd=="sites"])
  sites <- read.csv("site-ids.csv")
  lat <- sites$lat[sites$sitename == sitename]
  return(lat)
}
getlon <- function(wd, sitename){
  setwd(wd$path[wd$wd=="sites"])
  sites <- read.csv("site-ids.csv")
  lon <- sites$lon[sites$sitename == sitename]
  return(lon)
}

get.site.info <- function(wd){
  df <- archived.date.ranges(wd)
  sites <- unique(df$site)
  sites2 <- paste(sites, collapse = " | ")

  repeat {
    cat(paste0("Enter a site-name from one of the possible codes: \n", 
               sites2, "\n"))
    response <- readline(); response <- tolower(trimws(response))
    if (response %in% sites) {
      # Prints site info
      site.information(wd, response)
      break  # Exit the repeat loop and continue the function
    }
    else {
      cat("Invalid input. Please enter one of the given site-names...\n")
    }
  }
  
}

# Provides a summary of import info for a site
site.information <- function(wd, sitename){
  setwd(wd$path[wd$wd=="archive"])
  corr <- read.csv("site.correspondence.csv")
  statuses <- read.csv("site.status.csv")
  statuses <- statuses[statuses$site == sitename,]
  coords <- read.csv("site.coords.csv")
  name <- coords$site[coords$sitename==sitename]
  status.weather <- statuses$status[statuses$type=="weather"]
  status.hydro <- statuses$status[statuses$type=="hydro"]
  status.vwc  <- statuses$status[statuses$type=="vwc"]
  # Pull down the latest dates and attach them to the message
  dates <- archived.date.ranges(wd)
  if (length(status.weather)>0){
    weather <- paste0("\nWeather station status...... ", status.weather)
    weather.date <- dates$last.reading[dates$site==sitename & dates$type=="weather"]
    weather.date <- paste0("\nWEATHER: ", weather.date)
  }
  if (length(status.hydro)>0){
    hydro <- paste0("\nStream gauge status......... ", status.hydro)
    hydro.date <- dates$last.reading[dates$site==sitename & dates$type=="hydro"]
    hydro.date <- paste0("\nHYDRO:   ", hydro.date)
  }
  if (length(status.vwc)>0){
    vwc <- paste0("\nVWC station(s) status....... ", status.vwc)
    vwc.date <- dates$last.reading[dates$site==sitename & dates$type=="vwc"]
    vwc.date <- paste0("\nVWC:     ", vwc.date)
  }
  if (!any(grepl(sitename, corr$hydro))){
    gauges <- corr$hydro[corr$weather==sitename]
    gauges <- paste(gauges, collapse = ", ")
    different.weather <- paste0("\nQueried station is a weather station ONLY. Corresponding gauges: ", gauges)
  } else{
    weather.name <- corr$weather[corr$hydro==sitename]
    if(sitename != weather.name){
      different.weather <- paste0("\nQueried station has a weather station under a different name: ", weather.name)
    }
  }
  safeget <- function(varname) {
    if (exists(varname, inherits = TRUE)) get(varname) else ""
  }
  
  readout <- paste0("Full site name.............. ", name, 
                    safeget("weather"), safeget("hydro"), safeget("vwc"), "\n",
                    safeget("different.weather"), "\nLAST DATA ENTERED ON:",
                    safeget("weather.date"), safeget("hydro.date"), safeget("vwc.date"), "\n")
  cat(readout)
}

# Used for summary of all datafiles
archived.date.ranges <- function(wd){
  wd.archive <- wd$path[wd$wd=="archive"]
  files <- list.files(wd.archive); files <- files[grepl("^.*?\\.[^.]*?(weather|hydro|vwc)", files)]
  sites <- sub("\\..*$", "", files); sites <- unique(sites)
  output <- data.frame(site = character(), type = character(), last.reading = character())
  for (i in 1:length(sites)){
    site <- sites[i]
    result <- latest.entries(wd, sites[i])
    currentrow <- nrow(output)
    addrow <- 0
    for (j in 1:nrow(result)){
      if (!is.na(result$start[j])){
        addrow <- addrow + 1
        output[currentrow + addrow,]$site <- site
        output[currentrow + addrow,]$type <- result$type[j]
        output[currentrow + addrow,]$last.reading <- result$startstring[j]
      }
    }
  }
  output$last.reading <- as.POSIXct(output$last.reading, format = "%Y%m%d")
  return(output)
}

# Pulls out the last date in the archive for each type at this site, 
# and returns the date and the stringdate for the previous day to use as start
# date for new download or import
latest.entries <- function(wd, sitename){
  setwd(wd$path[wd$wd=="archive"])
  result <- data.frame(type = c("weather","hydro","vwc"),
                       start = rep(NA,3),
                       startstring = rep(NA,3))
  result$start <- as.Date(result$start)
  for (i in 1:nrow(result)){
    type <- result$type[i]
    file.name <- paste0(sitename,".",type,".rda")
    # Not all sites will have all 3 types, so if it doesn't exist, skip it
    if (file.exists(file.name)){
      load(file.name)
      df.name <- paste0(sitename,".",type)
      df <- get(df.name)
      result$start[i] <- as.Date(df$date[nrow(df)], tz = "America/Port_of_Spain")
      result$startstring[i] <- format(result$start[i], "%Y%m%d")
    } else {
      result$start[i] <- NA
      result$startstring[i] <- NA
    }
  }
  return(result)
}
splice.backup <- function(wd){
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  setwd(wd$path[wd$wd=="splices"])
  current.time0 <- Sys.time()
  current.time <- substr(current.time0, 1, 19)
  current.time <- gsub(" ", "_", current.time)
  current.time <- gsub(":", "", current.time)
  filename <- paste0("splices_", current.time, ".csv")
  cat("Backing up splices record before further action, at: ", format(current.time0, "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain"), "\n")
  write.csv(splices, file = filename, row.names = FALSE)
}
restore.last.splice.backup <- function(wd){
  setwd(wd$path[wd$wd=="splices"])
  files <- list.files()
  datestrings <- substr(files, 9, (nchar(files)-4))
  datestrings <- gsub("_", "", datestrings)
  datestrings <- gsub("-", "", datestrings)
  datestrings <- as.numeric(datestrings)
  latest <- which(datestrings == max(datestrings, na.rm = TRUE))
  latest.file <- files[latest]
  restored.splices <- read.csv(latest.file)
  cat("Restoring splices from file:", latest.file, "\nMain splices file has been overwritten!\n")
  setwd(wd$path[wd$wd=="archive"])
  write.csv(restored.splices, "splices.csv", row.names = FALSE)
}
# This function produces start and end dates for each data type to be imported.
# Handles both the existing archive and new site names given with no archive.
dateranges <- function(wd, sitename){
  splice.backup(wd)
  ranges <- latest.entries(wd, sitename)
  # When there is no archived info for this site name:
  if (all(is.na(ranges$start)) & all(is.na(ranges$startstring))){
    setwd(wd$paths[wd$wd=="sites"]); sites <- read.csv("site-ids.csv"); sitenames <- paste(sites$sitename, collapse = ", ")
    # If this site has never been described with metadata and is not possibly just a slope or backup logger:
    backupnames <- paste0(sites$sitename, "backup")
    slopenames <- paste0(sites$sitename, "slope")
    all.sitenames <- c(sites$sitename, backupnames, slopenames)
    if (!(sitename %in% all.sitenames)){
      # Ask the user if they meant to create a new site, and collect and write new site info if so
      repeat {
        cat(paste0("Did you mean (Y/N) to start a new site with name: ", sitename, "?\nOr did you intend one of these existing sites:\n",sitenames, "?\n"))
        response <- readline(); response <- toupper(response)
        if (response == "Y") {
          cat(paste0("New site will be written under sitename: ", sitename, "\n"))
          # If the site is new, collect site info to write into site.ids.csv
          user.supplied.site.id(wd, sitename) # This also prints the new site-ids
          break  # Exit the repeat loop and continue the function
        } else if (response == "N") {
          cat("Please re-try with the site correctly written.\n")
          return() # Exits function to allow re-try
        } else {
          cat("Invalid input. Please enter Y or N.\n")
        }
      }
      # We have entered new site-ids info, but we still need to get valid start dates, so go to raw data
    } else {cat("Site has been described or is a secondary logger, but no archive exists, collecting raw file starts and ends...\n")}
    # Either the new site metadata has been written or already existed, but no archive exists
    # So here we will query the raw data and get the start and end date for this import run:
    ranges$end <- NA; ranges$endstring <- NA
    ranges <- get.raw.start.end(wd, sitename, ranges)
  } else if (all(!is.na(ranges$start)) & all(!is.na(ranges$startstring))) {
    # This is the case when archival dates exist for all data types
    cat("Site has archival data for all data types. Will use end of archive as start of this import...\n")
    ranges$end <- NA; ranges$endstring <- NA
    ranges <- get.raw.start.end(wd, sitename, ranges, TRUE)
  } else {
    # The else statement occurs when some but not all archived info did exist
    cat("Using archive end as start of this import if available, otherwise raw start to raw end:\n")
    ranges$end <- NA; ranges$endstring <- NA
    for (i in 1:nrow(ranges)){
      type <- ranges$type[i]
      bounds <- get.raw.start.end.type(wd, sitename, type)
      # Fix Inf values to NA
      bounds[is.infinite(as.numeric(bounds))] <- NA
      if (is.na(ranges$start[ranges$type == type])){
        cat(paste0("   --No archival data seems to exist in ", type, " data type.\n"))
        ranges$startstring[ranges$type==type] <- bounds[1]
        ranges$endstring[ranges$type==type] <- bounds[2]
      } else {
        cat(paste0("   --Archival data was found in ", type, " data type.\n"))
        ranges$endstring[ranges$type==type] <- bounds[2]
      }
    }
    ranges$start <- as.Date(ranges$startstring, format = "%Y%m%d")
    ranges$end <- as.Date(ranges$endstring, format = "%Y%m%d")
  }
  
  # First check if there is any new data at all - we assume this if the start and end dates are all the same
  if (all(ranges$start == ranges$end, na.rm = TRUE)){
    cat("WARNING: You appear to have no new raw data to archive - most likely you are re-running existing import code?\n  --You will need to manually alter your ranges to match what this import originally accomplished\n  --PLUS any previous code chunks to properly write the starts and ends for these data!\n")
    ranges[,] <- NA
    return(ranges)
  }
  
  # A few quality checks are used: 
  if (any(na.omit(ranges$start) > Sys.Date()) | any(na.omit(ranges$end) > Sys.Date())){
    stop("ERROR: At least one of the dates in the filnames appears to be in the future! Please check before retrying.\n")
  }
  if (any(na.omit(ranges$start) < "1980-01-01") | any(na.omit(ranges$end) < "1980-01-01")){
    stop("ERROR: At least one of the dates in the filenames may be wrongly formatted and was read as pre-1980! Please check before retrying.\n")
  }
  # if weather range does not encompass both of the others or is not found, an warning occurs (user could fix manually);
  if (is.na(ranges$start[ranges$type=="weather"])){
    cat("WARNING: No weather data was found. Most analyses will require some weather data!\n")
  } else if (ranges$start[ranges$type=="weather"] > min(ranges$start[ranges$type=="hydro"], ranges$start[ranges$type=="vwc"], na.rm = TRUE) | 
             ranges$end[ranges$type=="weather"] < max(ranges$end[ranges$type=="hydro"], ranges$end[ranges$type=="vwc"], na.rm = TRUE)){
    cat("WARNING: The given range of weather data does not fully one or both of the other (hydro/VWC) data types.\n")
  }
  # If the most recent raw data is either equal to or older than the most recent archive data, there is no new raw data
  # This only runs true when it is true for all of the raw data. It may sometimes be expected that a certain variable has no new raw
  # data, e.g. when we import new weather data alone without new data types downloaded from the field yet. 
  ranges0 <- latest.entries(wd, sitename)
  ranges1 <- get.raw.start.end(wd, sitename, ranges)
  if(all(!is.na(ranges1$end) & !is.na(ranges0$start) & (ranges1$end <= ranges0$start))){
    cat("WARNING: No new raw data appears to exist in one or more variables, compared to archive. Be sure you know which!\n")
  }
  repeat {
    cat("The date ranges have been collected for this run, you must now type these ranges as information in comments at the type of this code before proceeding!\n...\nBEFORE PROCEEDING, NOTATE THE DATES IN THE COMMENTS!\n")
    print(ranges)
    cat("\nYou must acknowledge you have entered these dates before proceeding! Press Y to confirm you are ready to proceed.\n")
    response <- readline(); response <- toupper(response)
    if (response == "Y") {
      cat(paste0("Dates acknowledged as manually recorded by user. Please proceed with running the import.\n"))
      break  # Exit the repeat loop and continue the function
    } else {
      cat("Invalid input. Please enter Y when you are ready to move on and have written the dates down!\n")
    }
  }
  return(ranges)
}
# Allows user to enter a new line in site-ids.csv from R console
user.supplied.site.id <- function(wd, sitename){
  cat("Please answer the following questions about the site (CASE SENSITIVE!):\n")
  # Ask the question, keep asking if input is invalid
  repeat {
    cat("What is the full proper site name? (Use correct capitalization, avoid abbreviation.) ")
    fullname <- readline()
    if (nchar(fullname) > 0) {  # Validate input is non-empty
      break
    } else {
      cat("Answer cannot be empty. Please enter a valid name.\n")
    }
  }
  repeat {
    cat("What is an alternate nickname for the site? (Often just, e.g., FB instead of fb.) ")
    nickname <- readline()
    if (nchar(nickname) > 0) {  # Validate input is non-empty
      break
    } else {
      cat("Answer cannot be empty. Please enter a valid name.\n")
    }
  }
  repeat {
    cat("What is the latitude of the site in decimal degrees? Provide at least 4 digits after decimal. ")
    lat <- readline()
    latnum <- as.numeric(lat)
    parts <- strsplit(lat, "\\.")[[1]]
    decimal.digits <- nchar(parts[2])
    if (is.na(latnum)){
      cat("Invalid input. Please provide a numeric string.\n")
    } else if (nchar(lat) == 0){
      cat("Answer cannot be empty. Please enter a latitude in decimal degrees.\n")
    } else if (length(parts) == 1) {
      cat("Answer must use a decimal point!\n")
    } else if (decimal.digits < 4){
      cat("Answer must use 4 or more digits after decimal for spatial precision.\n")
    } else if (latnum > 90 | latnum < -90){
      cat("Enter a valid latitude; between -90 and 90!\n")
    } else {
      break
    }
  }
  repeat {
    cat("What is the longitude of the site in decimal degrees? Provide at least 4 digits after decimal. ")
    lon <- readline()
    lonnum <- as.numeric(lon)
    parts <- strsplit(lon, "\\.")[[1]]
    decimal.digits <- nchar(parts[2])
    if (is.na(lonnum)){
      cat("Invalid input. Please provide a numeric string.\n")
    } else if (nchar(lon) == 0){
      cat("Answer cannot be empty. Please enter a longitude in decimal degrees.\n")
    } else if (length(parts) == 1) {
      cat("Answer must use a decimal point!\n")
    } else if (decimal.digits < 4){
      cat("Answer must use 4 or more digits after decimal for spatial precision.\n")
    } else if (lonnum > 180 | lonnum < -180){
      cat("Enter a valid longitude; between -180 and 180!\n")
    } else {
      break
    }
  }
  repeat {
    cat("What is the bankfull depth for the site (in meters), if known? Press enter with no entry if unknown or inapplicable.")
    overbank <- readline()
    overbank.num <- as.numeric(overbank)
    if (nchar(overbank) == 0){
      cat("User entered an empty value, so NA will be entered in site-ids.csv as the overbank value!")
      overbank <- NA
      break
    }
    if (!is.na(overbank.num)) {  # Validate input is a number
      break
    } else {
      cat("Invalid input. Please provide a numeric string.\n")
    }
  }
  repeat {
    cat("What is the roughness coefficient for the site (Manning's n), if known? Press enter with no entry if unknown or inapplicable.")
    roughness <- readline()
    roughness.num <- as.numeric(roughness)
    if (nchar(roughness) == 0){
      cat("User entered an empty value, so NA will be entered in site-ids.csv as the roughness value!")
      roughness <- NA
      break
    }
    if (!is.na(roughness.num)) {  # Validate input is a number
      break
    } else {
      cat("Invalid input. Please provide a numeric string.\n")
    }
  }
  # Store the responses
  responses <- c(fullname, nickname, lat, lon, overbank, roughness)
  # Ask the user to confirm the entries are correct
  repeat {
    cat(paste0("You have entered the following for: full site name, site nickname, latitude, longitude, overbank, and roughness:\n", paste(responses, collapse = ", "), "\nPlease check carefully and confirm Y/N:"))
    response <- readline(); response <- toupper(response)
    if (response == "Y") {
      cat(paste0("New site information will be written under in site-ids.csv! \n"))
      # Import site-ids, add line, and save
      responses <- c(sitename, responses)
      setwd(wd$paths[wd$wd=="sites"]); sites <- read.csv("site-ids.csv")
      sites[nrow(sites)+1,] <- responses; sites$lat <- as.numeric(sites$lat); sites$lon <- as.numeric(sites$lon)
      sites$overbank <- as.numeric(sites$overbank); sites$roughness <- as.numeric(sites$roughness)
      write.csv(sites, "site-ids.csv", row.names = FALSE)
      return(sites)
    } else if (response == "N") {
      cat("Please re-try and ensure the correct values are entered! Restarting function...\n")
      # Recursively restart the function
      return(user.supplied.site.id(wd, sitename))
    } else {
      cat("Invalid input. Please enter Y or N.\n")
    }
  }
}
# archive = TRUE avoids overwriting start dates that have already been pulled from archive
# but default FALSE overwrites entire date ranges from raw data in all cases
get.raw.start.end <- function(wd, sitename, ranges, archive = FALSE){
  # Get matching weather files and extract dates:
  bounds <- get.raw.start.end.type(wd, sitename, "weather")
  w.start <- bounds[1]; w.end <- bounds[2]
  # Get matching hydro files and extract dates:
  bounds <- get.raw.start.end.type(wd, sitename, "hydro")
  h.start <- bounds[1]; h.end <- bounds[2]
  # Get matching vwc files and extract dates:
  bounds <- get.raw.start.end.type(wd, sitename, "vwc")
  v.start <- bounds[1]; v.end <- bounds[2]
  # Write the end strings to ranges
  ranges$endstring[ranges$type == "weather"] <- w.end
  ranges$endstring[ranges$type == "hydro"] <- h.end
  ranges$endstring[ranges$type == "vwc"] <- v.end
  if (archive == FALSE){
    # Only write the start strings if there is no archive
    ranges$startstring[ranges$type == "weather"] <- w.start
    ranges$startstring[ranges$type == "hydro"] <- h.start
    ranges$startstring[ranges$type == "vwc"] <- v.start
  }
  # Deal with the inf values that arise when no data files of that type exist, especially occurs in VWC
  ranges$startstring[is.infinite(as.numeric(ranges$startstring))] <- NA
  ranges$endstring[is.infinite(as.numeric(ranges$endstring))] <- NA
  # Write the dates as date object 
  ranges$start <- as.Date(ranges$startstring, format = "%Y%m%d")
  ranges$end <- as.Date(ranges$endstring, format = "%Y%m%d")
  return(ranges)
}
get.raw.start.end.type <- function(wd, sitename, type){
  if (type == "hydro"){
    dir <- "level"
  } else {dir <- type}
  # Get matching files of this type and extract dates:
  setwd(wd$paths[wd$wd==dir]); filenames <- list.files()
  filenames <- filenames[grepl(sitename, filenames)]
  datestrings <- substr(filenames, (nchar(filenames)-20), (nchar(filenames)-4))
  starts <- substr(datestrings, 1, 8); ends <- substr(datestrings, 10, 17)
  start <-  suppressWarnings(as.character(min(as.numeric(starts))));   end <-  suppressWarnings(as.character(max(as.numeric(ends))))
  bounds <- c(start, end)
  return(bounds)
}
multi.import <- function(wd, sitename, type, start, end){
  if (type == "hydro"){
    dir <- "level"
  } else {dir <- type}
  # Get matching files of this type and deal with special cases slope and backup
  # by using e.g. "fbslope" or "sr1backup" as sitename which acts as the file's prefix.
  setwd(wd$paths[wd$wd==dir]); filenames <- list.files()
  filenames <- filenames[grepl(sitename, filenames)]
  prefix <- sub("_.*", "", filenames)
  filenames <- filenames[which(prefix==sitename)]
  # Extracting dates:
  files <- data.frame(filename = filenames, start = rep(NA, length(filenames)), end = rep(NA, length(filenames)))
  files$start <- substr(files$filename, (nchar(files$filename)-20), (nchar(files$filename)-13))
  files$end <- substr(files$filename, (nchar(files$filename)-11), (nchar(files$filename)-4))
  # Insert a fail check here to ensure each file name's end is the start of the next
  if (nrow(files) > 1){
    if (type != "vwc"){
      files$diff <- NA; files$diff[1] <- 0
      for (i in 2:nrow(files)){files$diff[i] <- as.numeric(files$end[i-1]) - as.numeric(files$start[i])}
    } else {
      vwctypes <- unique(sapply(strsplit(files$filename, "_"), `[`, 3))
      files0 <- files[0,]
      for (i in 1:length(vwctypes)){
        vwctype <- vwctypes[i]
        subset <- files[which(sapply(strsplit(files$filename, "_"), `[`, 3) == vwctype),]
        subset$diff <- NA; subset$diff[1] <- 0
        for (i in 2:nrow(subset)){subset$diff[i] <- as.numeric(subset$end[i-1]) - as.numeric(subset$start[i])}
        files0 <- rbind(files0, subset)
      }
      files <- files0; files0 <- NULL
    }
    if (any(is.na(files$diff)) | any(files$diff != 0, na.rm = TRUE)){
      cat("WARNING: Files in this import do not all match one another end to start of next file! Please check.\nPositive numbers are overlaps and this function should handle those successfully.\n")
      print(files)
    }
    files$diff <- NULL
  }
  # Clip this full files list to only include those encompassed by the start and end of this import call
  # Bearing in mind that both the input arguments and the entries in the df are strings 
  if (type != "vwc"){
    # Add one day of padding for Zentra files since they autmatically back up the start by 1 day
    files <- files[as.numeric(files$start) >= (as.numeric(start)-1),]
    files <- files[as.numeric(files$end) <= as.numeric(end),]
  } else {
    vwctypes <- unique(sapply(strsplit(files$filename, "_"), `[`, 3))
    files0 <- files[0,]
    for (i in 1:length(vwctypes)){
      vwctype <- vwctypes[i]
      subset <- files[which(sapply(strsplit(files$filename, "_"), `[`, 3) == vwctype),]
      subset <- subset[as.numeric(subset$start) >= as.numeric(start),]
      subset <- subset[as.numeric(subset$end) <= as.numeric(end),]
      files0 <- rbind(files0, subset)
    }
    files <- files0; files0 <- NULL
  }
  # The actual import follows: 
  if (type == "weather"){
    df <- read.csv(files$filename[1]); df <- zentra.hydro(df); df <- df[0,]
    for (i in 1:nrow(files)){
      df1 <- read.csv(files$filename[i]); df1 <- zentra.hydro(df1)
      # Removes any dates from df1 that already exist in df
      df1 <- df1 %>% anti_join(df, by = "date")
      df <- rbind(df, df1)
    }
  } else if (type == "hydro"){
    df <- read.csv(files$filename[1], header=FALSE); df <- hobo.import(df); df <- df[0,]
    for (i in 1:nrow(files)){
      df1 <- read.csv(files$filename[i], header=FALSE); df1 <- hobo.import(df1)
      # Removes any dates from df1 that already exist in df
      df1 <- df1 %>% anti_join(df, by = "date")
      df <- rbind(df, df1)
    }
    # Here we deal with secondary slope or backup loggers by seeing if these words appear in the sitename
    suffixes <- c("slope", "backup")  # Possible suffixes
    if (grepl(paste0("(", paste(suffixes, collapse = "|"), ")$"), sitename)){
      truesite <- sub(paste0("(", paste(suffixes, collapse = "|"), ")$"), "", sitename)
      df <- hoboware.import(wd, df, truesite)
    } else {
      df <- hoboware.import(wd, df, sitename)
    }
  } else if (type == "vwc"){
    vwctypes <- unique(sapply(strsplit(files$filename, "_"), `[`, 3))
    df <- read.csv(files$filename[1]); df <- vwc.import(df); df$type <- NA; df <- df[0,]; df.type <- df
    for (i in 1:length(vwctypes)){
      vwctype <- vwctypes[i]
      subset.files <- files[which(sapply(strsplit(files$filename, "_"), `[`, 3) == vwctype),]
      df1 <- df[0,]
      for (j in 1:nrow(subset.files)){
        df1 <- read.csv(subset.files$filename[j]); df1 <- vwc.import(df1)
        df1$type <- vwctype
        # Removes any dates from df1 that already exist in df
        df1 <- df1 %>% anti_join(df, by = "date")
        df <- rbind(df, df1)
      }
      df.type <- rbind(df.type, df); df <- df[0,]
    }
    df <- df.type
  } else {
    stop("ERROR: type not recognized, use weather, hydro, or vwc")
  }
  return(df)
}
# This function receives the recently processed new data df of weather, hydrograph,
# or of VWC record, which should have been QA/QC'd already, requests the sitename
# for file naming, receives the directory to work in, and the type
# Possible types are "weather", "hydro", and "vwc"
# OVERWRITE is a true/false variable that determines whether we overwrite the archive or defer
archive.data <- function (wd, df, sitename, type, overwrite){
  fix.midnight.splice.issue((wd))
  setwd(wd$path[wd$wd=="archive"])
  file.name <- paste0(sitename,".",type,".rda")
  # If an archive under this name does not already exist, just write it
  if (file.exists(file.name) == FALSE){
    cat(paste0("No archive file under the name: ", file.name, " exists. Writing new archive..."))
    df.name <- paste0(sitename, ".", type)
    assign(df.name, df)
    save(list = df.name, file = file.name, compress = "xz")
    return(df)
  } 
  # But if it does exist, load it in and we will check to make them fit
  else {
    # Load the archive under this filename and store its name
    archive.name <- load(file.name)
    # Rename for use in this function
    archive <- get(archive.name)
    # If we are not planning to overwrite the existing archive
    if (overwrite == FALSE){
      cat(paste0("Existing archive file under the name: ", file.name, " found. Updating archive WITHOUT overwrites..."))
      # Remove any dates from df that already exist in archive
      df <- df %>%
        anti_join(archive, by = "date")
      # If you attempt to re-run an archive.file() call which you have already archived
      # the remaining df will be empty, and the function should stop
      if (nrow(df) == 0){
        stop("ERROR: It appears you are adding nothing new to the archive!")
      }
    } else {
      repeat {
        cat(paste0("Existing archive file under the name: ", file.name, " found. Updating archive WITH OVERWRITE OF ARCHIVE!\nAre you sure you want to proceed to overwrite and save over the archive file? (Y/N)"))
        response <- readline(); response <- toupper(response)
        if (response == "Y") {
          cat(paste0("Proceeding with archive update and overwrite! \n"))
          # But if we ARE OVEWRITING THE ARCHIVE
          archive <- archive %>%
            anti_join(df, by = "date")
          break
        } else if (response == "N") {
          cat("Cancelling this function call...\n")
          # Exit the function
          return()
        } else {
          cat("Invalid input. Please enter Y or N.\n")
        }
      }
    }
    # Now check whether there is any gap between final in archive and first in df
    # By calculating gap in seconds between these
    gap <- df$timestamp[1] - archive$timestamp[nrow(archive)]
    print(gap)
    if (gap < 900){
      stop("ERROR: LESS THAN 15 MINUTE GAP BETWEEN START OF NEW DATA AND END OF OLD")
    } else {
      if (gap > 900){
        if (gap > 0.5*24*60*60){
          stop("WARNING: MORE THAN 12 HOUR GAP IN DATA")
        }
        # If gap is more than 15 min but less than 12 hours, interpolate between it
        gapsteps <- gap/900
        wholegaps <- floor(gapsteps)
        if (gapsteps != wholegaps){
          # If for some reason df is not on even 15 minute steps, print warning
          stop("ERROR: NEW DATA IS NOT ON EVEN 15-MINUTE INTERVAL AND MISMATCHES")
        } else {
          cat("WARNING: GAP EXISTS, BUT ON EVEN SPACING AND LESS THAN 12 HOURS")
          cat("SIMPLE INTERPOLATION USED EXCEPT RETURNS NAs FOR PRECIP AND VWC")
          # When gapsteps is 2, we need one new row, and so on:
          gapsteps <- gapsteps-1
          for (i in 1:gapsteps){
            # Create a new row to add to the site.archive
            new.row <- as.data.frame(matrix(NA, ncol = ncol(archive), nrow = 1))
            colnames(new.row) <- colnames(archive)
            archive <- rbind(archive, new.row)
            # For each additional row in site.archive, we increase the timestamp by 900 seconds
            # And do this for as many gaps as there are
            archive$timestamp[nrow(archive)] <- archive$timestamp[nrow(archive)-1] + 900
          }
          # Now overwrite $date 
          archive$date <- as.POSIXct(archive$timestamp, tz = "America/Port_of_Spain", origin = "1970-01-01")
          # Attach df to the site.archive subset
          df <- rbind(archive, df)
          if (type == "vwc"){
            cat("This is VWC data - data will be returned with NAs in the gap. Check for rainfall before interpolating")
          } 
          else {
            col.names <- colnames(df)
            if (any(col.names=="precip")){
              # If precip is involved, remove it for storage
              precip <- df$precip
              # Perform simple interpolation
              df <- fillgaps2(df, FALSE)
              # Add the original nonfilled precip back
              df$precip <- precip
              # Reorder columns to original order
              df <- df[,col.names]
            } else {
              df <- fillgaps2(df, FALSE)
            }
          }
          # Order by timestamp just in case, and relabel row indices
          df <- df[order(df$timestamp), ]
          rownames(df) <- NULL
        }
      } else {
        # This else occurs when gap is exactly 900 seconds - just as it should be
        # So simply attach the df to the end of the archive
        df <- rbind(archive, df)
        # Order by timestamp just in case, and relabel row indices
        df <- df[order(df$timestamp), ]
        rownames(df) <- NULL
      }
    }
    repeat {
      cat(paste0("Ready to save new archive file under the name: ", file.name, ". Proceed with file save? (Y/N)\n"))
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat(paste0("Proceeding with archive save! \n"))
        # But if we ARE OVEWRITING THE ARCHIVE
        df.name <- paste0(sitename, ".", type)
        assign(df.name, df)
        save(list = df.name, file = file.name, compress = "xz")
        return(df)
      } else if (response == "N") {
        cat("Cancelling the archive save but returning data to user...\n")
        # Just return the df without saving to directory
        return(df)
      } else {
        cat("Invalid input. Please enter Y or N.\n")
      }
    }
  }
}
fix.midnight.splice.issue <- function(wd){
  setwd(wd$paths[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  components <- strsplit(splices$key, "_")
  # Loop through the rows
  for (i in 1:nrow(splices)) {
    # Check if there is an NA in either col1 or col2 for the current row
    if (is.na(splices$start[i]) | is.na(splices$end[i])) {
      # Replace NAs with a default value as an example action
      splices$start[i] <- components[[i]][2]
      splices$end[i] <- components[[i]][3]
    }
  }
  write.csv(splices, "splices.csv", row.names = FALSE)
}
# One-time download of world coastline info for use in all future CoCoRaHs mapping
#(wd.sites)
#library(ggplot2); library(ggspatial); library(rnaturalearth); library(rnaturalearthdata); library(sf)
#coastline <- ne_download(scale = 10, type = "coastline", category = "physical", returnclass = "sf")
#save(coastline, file = "coastline.rda")

######################         WEATHER/HYDRO IMPORT       ######################
# Simple weather imports and pressure corrections
zentra.hydro <- function(zentra){
  zentra <- zentra[c(3:nrow(zentra)),]
  zentra$datetime <- zentra[,1]
  zentra$precip <- zentra[,3]; zentra$precip <- as.numeric(zentra$precip)
  zentra$rad <- zentra[,2]; zentra$rad <- as.numeric(zentra$rad)
  zentra$temp <- zentra[,9]; zentra$temp <- as.numeric(zentra$temp)
  zentra$rhtemp <- zentra[,15]; zentra$rhtemp <- as.numeric(zentra$rhtemp)
  zentra$v.pres <- zentra[,10]; zentra$v.pres <- as.numeric(zentra$v.pres)
  zentra$pres <- zentra[,11]; zentra$pres <- as.numeric(zentra$pres)
  zentra$wind <- zentra[,7]; zentra$wind <- as.numeric(zentra$wind)
  zentra <- zentra[,c("datetime","precip","rad","temp","rhtemp","v.pres","wind","pres")]
  zentra$datetime<-as.character(zentra$datetime)
  if (any(grepl("PM", zentra$datetime))){
    zentra$datetime <- as.POSIXct(zentra$datetime, format = "%m/%d/%Y %I:%M:%S %p", tz = "America/Port_of_Spain")
  } else {
    zentra$datetime <- as.POSIXct(zentra$datetime, format = "%m/%d/%Y %H:%M", tz = "America/Port_of_Spain")
  }
  # Calculate relative humidity
  zentra$sat.vapor <- 6.11*((7.5*zentra$rhtemp)/(237.3+zentra$rhtemp)) #in kPa
  zentra$rh <- (zentra$v.pres / zentra$sat.vapor)*100
  zentra$rhtemp <- NULL; zentra$v.pres <- NULL; zentra$sat.vapor <- NULL
  zentra <- zentra[,c("datetime","precip","rad","temp","rh","wind","pres")]
  rownames(zentra) <- NULL
  # rename datetime to date
  zentra$date <- zentra$datetime
  zentra <- zentra[,c("date","precip","rad","temp","rh","wind","pres")]
  # and make a timestamp column
  zentra$timestamp <- as.numeric(zentra$date)
  zentra <- zentra[,c("date","timestamp","precip","rad","temp","rh","wind","pres")]
  return(zentra)
}
hobo.import <- function(hobo){
  # Detect hobolink vs hoboware using key phrase
  hobolink <- any(grepl("Barometric Pressure", as.matrix(hobo)))
  if (hobolink){
    # Hobolink code
    # Begin by locating the proper columns with the key words 
    hobo$datetime <- hobo[,which(apply(hobo, 2, function(x) any(grepl("Date", x))))[1]]
    hobo$abs <- hobo[,which(apply(hobo, 2, function(x) any(grepl("Water Pressure", x))))[1]]
    hobo$pres <- hobo[,which(apply(hobo, 2, function(x) any(grepl("Barometric Pressure", x))))[1]]
    hobo$temp <- hobo[, which(apply(hobo, 2, function(x) any(grepl("Water Temperature", x))))[1]]
    if (!any(grepl("Date", hobo$datetime)) | !any(grepl("Water Pressure", hobo$abs)) | !any(grepl("Barometric Pressure", hobo$pres)) | !any(grepl("Water Temperature", hobo$temp))){
      stop("ERROR: Unexpected columns were selected for hobolink import, please check the raw file!\n")
    }
    hobo <- hobo[,c("datetime", "abs", "pres", "temp")]
    hobo <- hobo[c(2:nrow(hobo)),]
    if (any(grepl("PM", hobo$datetime))){
      # Attempt to parse with two digit year format with seconds for AM/PM
      parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %I:%M:%S %p")
      # If parsing with seconds fails, fallback to parsing without seconds
      if (any(is.na(parsed.datetime))){
        parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %I:%M %p")
        # If this still fails, attempt with four digit year
        if (any(is.na(parsed.datetime))){
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %I:%M %p")
        } else {
          # If it failed with 2-digit year with seconds, and 2-digit without seconds
          # AND it also failed with 4-digit year without seconds, this means 
          # we are sure it is a 4-digit year with seconds
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %I:%M:%S %p")
        }
      }
      # Convert to POSIXct and format to ensure seconds are included
      hobo$datetime <- as.POSIXct(parsed.datetime, format = "%m/%d/%y %H:%M:%S", tz = "America/Port_of_Spain")
      # Some security in case something still messed up:
      if (any(is.na(parsed.datetime))){
        stop("ERROR: SOMETHING IS WRONG WITH READING DATETIMES - INVESTIGATE BEFORE PROCEEDING!")
      }
      
    } else {
      # Attempt to parse with two digit year format with seconds for AM/PM
      parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %H:%M:%S")
      # If parsing with seconds fails, fallback to parsing without seconds
      if (any(is.na(parsed.datetime))){
        parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %H:%M")
        # If this still fails, attempt with four digit year
        if (any(is.na(parsed.datetime))){
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %H:%M")
        } else {
          # If it failed with 2-digit year with seconds, and 2-digit without seconds
          # AND it also failed with 4-digit year without seconds, this means 
          # we are sure it is a 4-digit year with seconds
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %H:%M:%S")
        }
      }
      # Convert to POSIXct and format to ensure seconds are included
      hobo$datetime <- as.POSIXct(parsed.datetime, format = "%m/%d/%y %H:%M:%S", tz = "America/Port_of_Spain")
      # Some security in case something still messed up:
      if (any(is.na(parsed.datetime))){
        stop("ERROR: SOMETHING IS WRONG WITH READING DATETIMES - INVESTIGATE BEFORE PROCEEDING!")
      }
    }
    hobo$date <- hobo$datetime
    hobo$abs <- as.numeric(hobo$abs)
    hobo$pres <- as.numeric(hobo$pres)
    hobo$temp <- as.numeric(hobo$temp)
    hobo <- hobo[,c("date", "abs", "pres", "temp")]
    hobo$level <- waterlevel(hobo$abs, hobo$pres, hobo$temp)
    rownames(hobo) <- NULL
    
  } else {
    # Hoboware code
    #more cleanup
    hobo$datetime <- hobo[,2]
    hobo$abs <- hobo[,3]
    hobo$temp <- hobo[,4]
    hobo <- hobo[,c("datetime","abs","temp")]
    # make sure df$timestamp is a character
    hobo$datetime<-as.character(hobo$datetime)
    hobo <- hobo[3:nrow(hobo),]
    
    if (any(grepl("PM", hobo$datetime))){
      # Attempt to parse with two digit year format with seconds for AM/PM
      parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %I:%M:%S %p")
      # If parsing with seconds fails, fallback to parsing without seconds
      if (any(is.na(parsed.datetime))){
        parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %I:%M %p")
        # If this still fails, attempt with four digit year
        if (any(is.na(parsed.datetime))){
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %I:%M %p")
        } else {
          # If it failed with 2-digit year with seconds, and 2-digit without seconds
          # AND it also failed with 4-digit year without seconds, this means 
          # we are sure it is a 4-digit year with seconds
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %I:%M:%S %p")
        }
      }
      # Convert to POSIXct and format to ensure seconds are included
      hobo$datetime <- as.POSIXct(parsed.datetime, format = "%m/%d/%y %H:%M:%S", tz = "America/Port_of_Spain")
      # Some security in case something still messed up:
      if (any(is.na(parsed.datetime))){
        stop("ERROR: SOMETHING IS WRONG WITH READING DATETIMES - INVESTIGATE BEFORE PROCEEDING!")
      }
      
    } else {
      # Attempt to parse with two digit year format with seconds for AM/PM
      parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %H:%M:%S")
      # If parsing with seconds fails, fallback to parsing without seconds
      if (any(is.na(parsed.datetime))){
        parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%y %H:%M")
        # If this still fails, attempt with four digit year
        if (any(is.na(parsed.datetime))){
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %H:%M")
        } else {
          # If it failed with 2-digit year with seconds, and 2-digit without seconds
          # AND it also failed with 4-digit year without seconds, this means 
          # we are sure it is a 4-digit year with seconds
          parsed.datetime <- strptime(hobo$datetime, format = "%m/%d/%Y %H:%M:%S")
        }
      }
      # Convert to POSIXct and format to ensure seconds are included
      hobo$datetime <- as.POSIXct(parsed.datetime, format = "%m/%d/%y %H:%M:%S", tz = "America/Port_of_Spain")
      # Some security in case something still messed up:
      if (any(is.na(parsed.datetime))){
        stop("ERROR: SOMETHING IS WRONG WITH READING DATETIMES - INVESTIGATE BEFORE PROCEEDING!")
      }
    }
    hobo$date <- hobo$datetime
    hobo <- hobo[,c("date","abs","temp")]
    hobo$abs <- as.numeric(hobo$abs)
    hobo$temp <- as.numeric(hobo$temp)
    rownames(hobo) <- NULL
  }
  return(hobo)
}
# Takes the hydro record with abs and temp, the archived weather already QA/QCd above
# and uses atmospheric pressure, to correct by elev at the sitename
weather.pres <- function(wd, weather, sitename){
  # Get the elevation difference between gage and weather station
  setwd(wd$path[wd$wd=="sites"])
  elevs <- read.csv("elevs.csv")
  elev <- elevs$elev[elevs$site == sitename]
  # elev is distance (up positive) in elevation from measurement point (weather station)
  # to desired location (stream gauge), m. Thus when weather station is above gauge, this
  # is a negative value in meters.
  # To calculate the correction we also need g and density of air 
  # at known temperature (which we assume is 30 C in the USVI)
  airdense30c <- 1.1644
  # acceleration of gravity
  g <- 9.8
  # product of these
  gpo <- g*airdense30c
  # measured pressure given in kPa
  p0 <- weather$pres
  # convert to Pa
  p0 <- p0*1000
  # single term for exponent
  gp0 <- gpo/p0
  # simplied formula with gp0 term
  weather$pres <- p0*exp(-gp0*elev)
  # convert back to kPa
  weather$pres <- weather$pres/1000
  return(weather)
}
# Similar to weather.pres but permits interpolating pressure given simply elev difference
# The elev difference in meters should be negative if the source pressure data is 
# higher than the target position
pres.correct <- function(wd, weather, elev){
  # To calculate the correction we also need g and density of air 
  # at known temperature (which we assume is 30 C in the USVI)
  airdense30c <- 1.1644
  # acceleration of gravity
  g <- 9.8
  # product of these
  gpo <- g*airdense30c
  # measured pressure given in kPa
  p0 <- weather$pres
  # convert to Pa
  p0 <- p0*1000
  # single term for exponent
  gp0 <- gpo/p0
  # simplied formula with gp0 term
  weather$pres <- p0*exp(-gp0*elev)
  # convert back to kPa
  weather$pres <- weather$pres/1000
  return(weather)
}
# Retrieves reference barometer and uses this instead if needed, usually SR1
get.backup.pres <- function(wd, csvname, weather){
  setwd(wd$path[wd$wd=="weather"]); w2 <- read.csv(csvname)
  w2$pres <- w2[,19]; w2 <- w2[c(3:nrow(w2)),]; w2$date <- w2[,1]; w2 <- w2[,c("date","pres")]
  w2$pres <- as.numeric(w2$pres); w2$date <- as.character(w2$date)
  if (any(grepl("PM", w2$date))){
    w2$date <- as.POSIXct(w2$date, format = "%m/%d/%Y %I:%M:%S %p", tz = "America/Port_of_Spain")
  } else {
    w2$date <- as.POSIXct(w2$date, format = "%m/%d/%Y %H:%M", tz = "America/Port_of_Spain")
  }
  if (nrow(w2) != nrow(weather)){
    stop("ERROR: Weather record length has been altered, use original import!")
  }
  weather$pres <- w2$pres
  return(weather)
}

######################           NON-PRECIP QA/QC         ######################
# Simple non-precip interpolations and QA/QC
diffcheck <- function(df){
  diffs <- diff(df$timestamp)
  diffs <- c(900, diffs)
  df$diffs <- diffs/3600
  # When diffs is zero, this is a duplicate entry. Simply delete those rows
  df <- df %>%
    filter(diffs != 0)
  df <- df[order(df$timestamp), ]
  rownames(df) <- NULL
  return(df)
}
uninterrupt <- function(df){
  df <- diffcheck(df)
  even.intervals <- all(diff(df$diffs) == diff(df$diffs)[1])
  if (even.intervals != TRUE) {
    cat("Warning: Observations are not at evenly spaced intervals. Filling gaps with NAs\n")
  }
  # vector of 15-minute timesteps
  min15 <- df$timestamp/900
  # collect start and end numbers
  start <- min15[1]
  end <- min15[length(min15)]
  # vector of the whole range of numbers
  range <- c(start:end)
  # convert back to seconds
  range <- range*900
  # convert to datetime
  dates <- as.POSIXct(range, tz = "America/Port_of_Spain", origin = "1970-01-01")
  # new df with uninterrupted gaps
  df2 <- data.frame(date = dates, timestamp = as.numeric(dates))
  # merge the original data onto this, leaving NAs 
  df <- merge(df2, df, by = "date", all.x = TRUE)
  # delete diffs column
  df$diffs <- NULL
  # timestamps were identical so an extra column was made. delete it
  df$timestamp.y <- NULL
  # and rename the timestamp.x column
  names(df)[names(df) == "timestamp.x"] <- "timestamp"
  # re-run diffcheck now
  df <- diffcheck(df)
  even.intervals <- all(diff(df$diffs) == diff(df$diffs)[1])
  if (even.intervals != TRUE) {
    stop("Error: Observations are not at evenly spaced intervals. Please check and retry\n")
  }
  df$diffs <- NULL
  rownames(df) <- NULL
  return(df)
}
gaps <- function (var){
  is.gap <- is.na(var)
  start.indices <- which(diff(c(0, is.gap)) == 1)
  stop.indices <- which(diff(c(is.gap, 0)) == -1)
  gap.lengths <- stop.indices - start.indices + 1
  gaps <- data.frame(start = start.indices, end = stop.indices, length = gap.lengths)
  return(gaps)
}
# Finds all gaps in a df columns, fills with linear interpolation if gap is <12 hours
# Also avoids gapfilling any precip and hydro.level entries longer than 1 hour
# All = TRUE when filling all gaps no matter the length with simple linear inerp
fillgaps <- function(wd, df, all, write.splice){
  # Bring in splices record to notate all filled gaps
  setwd(wd$path[wd$wd=="archive"]); splices0 <- read.csv("splices.csv")
  splices0$start <- as.POSIXct(splices0$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices0$end <- as.POSIXct(splices0$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  # Initialize storage information
  allgaps <- data.frame(start = numeric(0), end = numeric(0), length = numeric(0), varname = character(0))
  # Iterate through all columns and find gaps
  for (i in 2:ncol(df)){
    gap1 <- gaps(df[,i])
    gap1$varname <- rep(colnames(df)[i], nrow(gap1))
    allgaps <- rbind(allgaps, gap1)
  }
  if(nrow(allgaps) == 0){
    cat("Congratulations, there are no gaps to fill!")
    return(df)
  }
  # Create the splices table that we will fill and add to the master metadata of QA/QC operations
  splices <- data.frame(unique = rep(NA, nrow(allgaps)), site = rep(sitename, nrow(allgaps)), start = allgaps$start, end = allgaps$end,
                         var = allgaps$varname, type = rep("gap", nrow(allgaps)), method = rep(NA, nrow(allgaps)), 
                         check.num = c(1:nrow(allgaps)))
  for (i in 1:nrow(allgaps)){
    splices$start[i] <- df$date[allgaps$start[i]]
    splices$end[i] <- df$date[allgaps$end[i]]
  }
  splices$start <- as.POSIXct(splices$start, origin = "1970-01-01", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, origin = "1970-01-01", tz = "America/Port_of_Spain")
  
  # Now we will need to use this reference to check whether the length is less than
  # 12 hours, which in terms of 15-minute intervals is a gaplength of 48
  allgaps$approx <- rep(NA, nrow(allgaps))
  if (all == FALSE){
    for (i in 1:nrow(allgaps)){
      if (allgaps$varname[i] == "precip" | allgaps$varname[i] == "level"){
        if (allgaps$length[i] <= 4){
          allgaps$approx[i] <- TRUE
          splices$method[i] <- "interp.linear"
        } else {
          allgaps$approx[i] <- FALSE
        }
      } else{
        if (allgaps$length[i] <= 48){
          allgaps$approx[i] <- TRUE
          splices$method[i] <- "interp.linear"
        } else {
          allgaps$approx[i] <- FALSE
        }
      }
    }
  } else {
    allgaps$approx <- TRUE
    splices$method <- "interp.linear"
  }
  # For all TRUE gaps, we can just do linear interpolation, but we need to get 
  # the right positions filled
  for (i in 1:nrow(allgaps)){
    if (allgaps$approx[i] == TRUE){
      #build a vector from df of the values needed here
      start <- allgaps$start[i]-1
      end <- allgaps$end[i]+1
      needs.interp <- df[[allgaps$varname[i]]][start:end]
      interped <- na.approx(needs.interp, rule = 2)
      df[[allgaps$varname[i]]][start:end] <- interped
    }
  }
  # Annoyingly it is necessary to fix a midnight formatting issue here
  splices$key <- NA
  for (i in 1:nrow(splices)){
    if (format(splices$start[i], format = "%H:%M:%S") == "00:00:00" & format(splices$end[i], format = "%H:%M:%S") == "00:00:00"){
      # Midnight both start and end
      splices$key[i] <- paste(splices$site[i], paste0(splices$start[i], " 00:00:00"), paste0(splices$end[i], " 00:00:00"), splices$var[i], sep = "_")
    } else if (format(splices$end[i], format = "%H:%M:%S") == "00:00:00"){
      # Midnight end only 
      splices$key[i] <- paste(splices$site[i], splices$start[i], paste0(splices$end[i], " 00:00:00"), splices$var[i], sep = "_")
    } else if (format(splices$start[i], format = "%H:%M:%S") == "00:00:00") {
      # Midnight start only 
      splices$key[i] <- paste(splices$site[i], paste0(splices$start[i], " 00:00:00"), splices$end[i], splices$var[i], sep = "_")
    } else {
      splices$key[i] <- paste(splices$site[i], splices$start[i], splices$end[i], splices$var[i], sep = "_")
    }
  }

  # Filter this in case any splices have already been recorded to avoid duplication!
  splices <- splices[!(splices$key %in% splices0$key), ]
  if (nrow(splices) != 0){
    # If any unique splices remain, give them a unique number
    if (nrow(splices0) == 0){
      splices$unique <- c(1:nrow(splices))
    } else {
      splices$unique <- c((splices0$unique[nrow(splices0)]+1):(nrow(splices)+splices0$unique[nrow(splices0)]))
    }
  }
  splices0 <- rbind(splices0, splices)
  
  if (write.splice == TRUE){
    write.csv(splices0, "splices.csv", row.names = FALSE)
  } 
  return(df)
}
# Function for checking an entire df for gaps, requires interval in minutes
allgaps <- function(df, interval){
  # initialize output dataframe
  allgaps <- data.frame(start = as.POSIXct(character(0)), end = as.POSIXct(character(0)), length = numeric(0), varname = character(0))
  # Iterate through all columns and find gaps
  for (i in 3:ncol(df)){
    gap1 <- gaps(df[,i])
    gap1$varname <- rep(colnames(df)[i], nrow(gap1))
    # convert length to hours based on interval in minutes
    gap1$length <- (gap1$length * interval) / 60
    # convert start index to date
    gap1$start <- df$date[gap1$start]
    gap1$end <- df$date[gap1$end]
    allgaps <- rbind(allgaps, gap1)
  }
  print(allgaps)
  return(allgaps)
}
allgaps2 <- function(df, interval){
  # initialize output dataframe
  allgaps <- data.frame(start = as.POSIXct(character(0)), end = as.POSIXct(character(0)), length = numeric(0), varname = character(0))
  # Iterate through all columns and find gaps
  for (i in 3:ncol(df)){
    gap1 <- gaps(df[,i])
    gap1$varname <- rep(colnames(df)[i], nrow(gap1))
    # convert length to hours based on interval in minutes
    gap1$length <- (gap1$length * interval) / 60
    # convert start index to date
    gap1$start <- df$date[gap1$start]
    gap1$end <- df$date[gap1$end]
    allgaps <- rbind(allgaps, gap1)
  }
  return(allgaps)
}
# Exists soley to display gaps not to return them
gap.print <- function(df, interval){
  # initialize output dataframe
  allgaps <- data.frame(start = as.POSIXct(character(0)), end = as.POSIXct(character(0)), length = numeric(0), varname = character(0))
  # Iterate through all columns and find gaps
  for (i in 3:ncol(df)){
    gap1 <- gaps(df[,i])
    gap1$varname <- rep(colnames(df)[i], nrow(gap1))
    # convert length to hours based on interval in minutes
    gap1$length <- (gap1$length * interval) / 60
    # convert start index to date
    gap1$start <- df$date[gap1$start]
    gap1$end <- df$date[gap1$end]
    allgaps <- rbind(allgaps, gap1)
  }
  print(allgaps)
}
# This summarizes uninterrupt and fillgaps into one, and assumes only gaps of
# less than 12 hours are automatically filled. Produces a report of all remaining
# long gaps and their variable to use in manual steps following the initial procedure
auto.qaqc <- function(wd, df, write.splice = TRUE){
  # begin by checking that all dates are evenly spaced,
  # if they are not, print a warning but proceed to space them evenly and 
  # splice in NAs with uninterrupt(), assuming it worked as planned it will pass back
  df <- uninterrupt(df)
  df <- fillgaps(wd, df, FALSE, write.splice)
  return(df)
}
level.qaqc <- function(wd, hydro, sitename){
  # Coerce negative levels to zero, but not NAs
  hydro$level <- ifelse(is.na(hydro$level), NA, ifelse(hydro$level <= 0, 0, hydro$level))
  # Acquire overbank and produce warning statement if a flood occurred 
  setwd(wd$path[wd$wd=="sites"])
  site.info <- read.csv("site-ids.csv")
  overbank <- site.info$overbank[site.info$sitename == sitename]
  # Ordinarily gaps will have been filled before now, but it may sometimes occur that there is a gap
  # So the following if statment must ignore NAs:
  if (any(hydro$level[!is.na(hydro$level)] > overbank)){
    cat("WARNING: A FLOOD EVENT OCCURRED IN THIS HYDROGRAPH. INTERPRET TOTAL DISHCARGE FIGURES WITH CAUTION")
    # When this happens, we will simply assume max calculable discharge, but this is erroneous
    high.levels <- which(hydro$level>overbank)
    hydro$level[high.levels] <- overbank
  }
  # This will prevent NAs from occurring due to overbanking, meaning all other NAs
  # are because of zero water, so we will change the NAs to all zeroes 
  level.nas <- which(is.na(hydro$level))
  hydro$level[level.nas] <- 0
  # Any lingering zeroes should be raised slightly positive to permit clean discharge calculation
  hydro$level <- ifelse(hydro$level == 0, hydro$level + 0.00000001, hydro$level)
  rownames(hydro) <- NULL
  # Convenience plot to start manual QA/QC
  plot(hydro$date, hydro$level)
  return(hydro)
}
# THE TWO FUNCTIONS BELOW, daytime() and interp() are used to do interpolation across
# longer gaps in weather data, by averaging the values at that time of day in the future and past days from the gap
# which allows us to do a linear interpolation at each time of day. 
interp <- function(wd, df, varname, minutes){
  # Bring in splices record to notate all filled gaps
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  # Get the gaps data for this variable
  gap <- gaps(df[[varname]])
  for (i in 1:nrow(gap)){
    df <- daytime(gap$start[i], gap$end[i], gap$length[i], df, varname, minutes)
  }
  if (any(is.na(df[[varname]]))){
    for (i in nrow(gap):1){
      df <- daytime(gap$start[i], gap$end[i], gap$length[i], df, varname, minutes)
    }
    if (any(is.na(df[[varname]]))){
      df[[varname]] <- na.approx(df[[varname]], na.rm = FALSE)
    }
  }
  # Write in splice metadata
  for (i in 1:nrow(gap)){
    start <- gap$start[i]; end <- gap$end[i]; var <- varname
    splices$method[splices$var == var & splices$start == df$date[start] & splices$end == df$date[end]] <- "interp.daytime"
  }
  write.csv(splices, "splices.csv", row.names = FALSE)
  return(df)
}
# gap.start and gap.end are the indices of the start and end of the current gap and come 
# from the result of the gap function. gap.length is the length of the gap in rows, also from gap().
# varname is a string that corresponds to the column name.  The argument "minutes" 
# is the interval between weather data rows in minutes. Df must have a column, $datetime
# with POSIXct in 24h notation.
daytime <- function(gap.start, gap.end, gap.length, df, varname, minutes){
  # create a temp vector called var for easier manipulation
  var <- df[[varname]]
  # We use "minutes" that to find out the number of rows that equal 24 hours
  dayrows <- (24*60)/minutes
  for (i in 0:gap.length-1){
    # Need to only execute the following when the current value is NA
    # This prevents this code from re-running when we reach a future interpolated number
    # As a result in a multi-day gap, the true is.na() case should only run for 24 hours, after which
    # everything should have been interpolated and will result in else cases. 
    if (is.na(var[gap.start+i])){
      # This tells us how many days are left in the gap from here
      daysleft <- floor(((gap.end - (gap.start+i))/dayrows))
      # Find the value of our variable at this time yesterday and the previous 4 days averaged
      var1 <- var[(gap.start+i)-dayrows] 
      # Find the value of our variable at this time after the gap and the next 4 days averaged
      var2 <- var[(gap.start+i+((daysleft+1)*dayrows))]
      # This determines the interval of one day step
      step <- (var2-var1)/(daysleft+2)
      # Fills in with the value of that step
      var[gap.start+i] <- var1 + step
    } else {}
  }
  # Need at this point to overwrite var into df[[varname]]
  df[[varname]] <- var
  return(df)
}

######################             PRECIP QA/QC           ######################
# The master function deals with gaps (assumed cutoff of <3 mm for zeroing), 
# asks user for input in non-zeroed gaps for further zeroing, records splices,
# and performs a check of potentially important non-gap events compared to gauge data.
# Gaps and checks marked suspicious are interpolated with the upwind-downwind pluviograph simulation blend
rain.qaqc <- function(wd, sitename, weather){
  ### Begin by performing the gap zeroing
  # Cutoff is days where no rain less than cutoff (mm) permits auto-zeroing
  # Buffer is time in hours to display before and after gaps that still remain for user control
  gaplist00 <- allgaps(weather, 15)
  if (nrow(gaplist00) > 0){
    cutoff <- 3; buffer <- 24
    result <- precip.gap.zeroing(wd, sitename, weather, cutoff, buffer)
    if (identical(result, NA)) {
      return(NA)  # Shut down the entire function if result is exactly NA
    }
    weather <- result$weather; gaplist <- result$gaplist 
  } else{
    gaplist <- gaplist00
  }
  # Bring in splices for this part
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  # Acquire average wind direction from stations within 10 km
  # These are used throughout and take time to make, so make them once
  df <- quick.wind.compile(wd)
  atmos <- quick.atmos.compile(wd, TRUE)
  # If gaps were passed in from earlier steps, we deal with them first
  if (nrow(gaplist) > 0){
    for (i in 1:nrow(gaplist)){
      start <- gaplist$start[i]; end <- gaplist$end[i]
      cat(paste0("\nConstructing simulated pluviograph for gap #", gaplist$check.num[i], " from ", start, " to ", end, "...\n"))
      # A relative pluviograph for the gap to fill
      result <- rel.pluviograph(wd, df, atmos, sitename, start, end)
      rel.pluv <- result$rel.pluv; match <- result$match; type <- result$type
      # Pulling daily rainfall for each day of this gap
      start.date <- as.Date(start, tz = "America/Port_of_Spain"); end.date <- as.Date(end, tz = "America/Port_of_Spain")
      daylist <- seq(from = start.date, to = end.date, by = "day"); days <- data.frame(date = daylist, precip = rep(NA, length(daylist)))
      for (j in 1:nrow(days)){
        days$precip[j] <- neighbor.daily.model(wd, getlat(wd, sitename), getlon(wd, sitename), days$date[j])
      }
      # Adding the daily rainfall into the relative pluviograph to get the final pluviograph to splice
      pluv <- sim.pluviograph(rel.pluv, days$precip, match)
      # Splice this in
      weather$precip[weather$date >= gaplist$start[i] & weather$date <= gaplist$end[i]] <- pluv$precip
      #weather[weather$date >= gaplist$start[i] & weather$date <= gaplist$end[i],]
      splices$method[splices$key == gaplist$key[i]] <- type
    }
    gaplist00 <- allgaps(weather, 15)
    if (nrow(gaplist00) != 0){
      stop("ERROR: Not all gaps were dealt with, check the function. Printing remaining gaps\n")
      print(gaplist00)
    }
  }
  # Save splices
  setwd(wd$path[wd$wd=="archive"]); write.csv(splices, "splices.csv", row.names = FALSE)
  
  ###############################
  # Gaps have been handled, now we will run check.qaqc to mark any non-gaps that require splicing
  check <- check.qaqc(wd, weather, sitename)
  if (identical(check, NA)) {
    return(NA)  # Shut down the entire function if result is exactly NA, meaning user escaped function
  }
  if (nrow(check) > 0){
    check <- check[order(check$date), ]; rownames(check) <- NULL; check$type <- NA
    # Perform the pluviograph simulation, then proceed to write splice info if it succeeded
    for (i in 1:nrow(check)){
      start <- check$start[i]; end <- check$end[i]
      cat(paste0("\nConstructing simulated pluviograph for check #", check$check.num[i], " from ", start, " to ", end, "...\n"))
      # A relative pluviograph for the gap to fill
      result <- rel.pluviograph(wd, df, atmos, sitename, start, end)
      rel.pluv <- result$rel.pluv; match <- result$match; type <- result$type
      check$type[i] <- type
      # Pulling daily rainfall for each day of this gap
      start.date <- as.Date(start, tz = "America/Port_of_Spain"); end.date <- as.Date(end, tz = "America/Port_of_Spain")
      daylist <- seq(from = start.date, to = end.date, by = "day"); days <- data.frame(date = daylist, precip = rep(NA, length(daylist)))
      for (j in 1:nrow(days)){
        days$precip[j] <- neighbor.daily.model(wd, getlat(wd, sitename), getlon(wd, sitename), days$date[j])
      }
      # Adding the daily rainfall into the relative pluviograph to get the final pluviograph to splice
      pluv <- sim.pluviograph(rel.pluv, days$precip, match)
      # Splice this in
      weather$precip[weather$date >= check$start[i] & weather$date <= check$end[i]] <- pluv$precip
    }
    # Add the splice one by one with the function, which will alert the user of an overwrite. 
    # They should accept any overwrite in this instance since it would be a sim.pluv overwriting a gap interp, which should be better
    for (i in 1:nrow(check)){
      # Find out if we have two checks in a row being interpolated by seeing what the next one's start is
      # if so, alter the end information of this check to reflect the fact we will be writing over part of it
      
      if (i < nrow(check)){
        if (check$end[i] > check$start[i+1]){
          splice.meta.add(wd, sitename, check$start[i], (as.POSIXct(check$end[i], tz = "America/Port_of_Spain")-24*60*60), "precip", "check", check$type[i], check$check.num[i])
        } else {
          splice.meta.add(wd, sitename, check$start[i], check$end[i], "precip", "check", check$type[i], check$check.num[i])
        }
      } else {
        splice.meta.add(wd, sitename, check$start[i], check$end[i], "precip", "check", check$type[i], check$check.num[i])
      }
    }
  }
  # If anything is negative, zero it
  weather$precip[weather$precip < 0] <- 0
  cat("Precipitation QA/QC complete.\n")
  
  return(weather)
}
# Takes a minimum cutoff threshold in mm to simply zero out gaps in precip where less than 
# that was observed in the whole area in the days before and after the gap. With what remains,
# finds neighboring UVI ATMOS data, raw or archive, to compare the gap against the precip
# record there, +/- the buffer argument in hours, for the user to manually choose 
# if it is OK to zero out. Performs the zeroing of those gaps selected and 
# returns the updated weather data with an updated gaplist.
precip.gap.zeroing <- function(wd, sitename, weather, cutoff, buffer){
  # Find the gaps in the rain record in which insignificant rain i.e. <3 mm occurred
  precipfills <- coco.check(wd, weather, sitename, cutoff)
  gaplist <- allgaps(weather, 15)
  # Fill these insignificant gaps with observations of 0 rainfall
  if (nrow(precipfills) > 0){
    weather <- rainless.gaps(wd, sitename, precipfills, gaplist, weather)
  }
  gaplist <- allgaps(weather, 15) 
  # Find a qualifying neighborsite
  setwd(wd$path[wd$wd=="sites"]); sites <- read.csv("site-ids.csv")
  sites <- sites[sites$sitename != sitename,]; sites$dist <- haversine.distance(getlat(wd, sitename), getlon(wd, sitename), sites$lat, sites$lon)
  setwd(wd$path[wd$wd=="weather"])
  file.list <- list.files(wd$path[wd$wd=="weather"])
  file.list <- file.list[grep("weather", file.list)]
  weather.sitenames <- sub("_.*", "", file.list)
  weather.sitenames <- unique(weather.sitenames)
  sites <- sites[sites$sitename %in% weather.sitenames,]
  sites <- sites[order(sites$dist), ]; rownames(sites) <- NULL
  neighborsite <- sites$sitename[1]
  neighborsite2 <- sites$sitename[2]
  # Re-extract the files
  setwd(wd$path[wd$wd=="weather"])
  file.list <- list.files(wd$path[wd$wd=="weather"])
  site.files <- file.list[grep(neighborsite, file.list)]
  # Read the date ranges for all the files for this site to select the right one
  selection <- rep(NA, length(site.files))
  for (i in 1:length(site.files)){
    daterange <- gsub(".*weather_([0-9]+)-([0-9]+).*", "\\1-\\2", site.files[i])
    # Extract the first and second number as strings that read into dates
    filestart <- gsub("-.*", "", daterange); filestart <- as.Date(filestart, format = "%Y%m%d")
    fileend <- gsub(".*-(.*)", "\\1", daterange); fileend <- as.Date(fileend, format = "%Y%m%d")
    start <- as.Date(min(gaplist$start))
    end <- as.Date(max(gaplist$end))
    # ensure the file in question encompasses all our gaps
    if (filestart < start & fileend > end){
      selection[i] <- TRUE
    } else {
      selection[i] <- FALSE
    }
  }
  # Subset the filenames by those that do encompass our gaps
  selection <- which(selection)
  files <- site.files[selection]
  filename <- files[1]
  # If none met the criteria, we try archive, then try the entire thing again on the second closest site, and stop if nothing worked
  if (length(files) == 0){
    # Try the archive with the closest neighbor site now in case the raw data was chopped up
    setwd(wd$path[wd$wd=="archive"])
    filename <- paste0(neighborsite, ".weather.rda")
    start <- min(gaplist$start)
    end <- max(gaplist$end)
    # If we have an archive for the neighborsite, we can try this. Just check that it covers the gaplist
    if (file.exists(filename)){
      load(filename)
      df.name <- paste0(neighborsite, ".weather")
      weather2 <- get(df.name)
      if (start < weather2$date[1] | end > weather2$date[nrow(weather2)]){
        rm(weather2) # Remove weather2 if it failed so we can continue our attempts
      }
    } else {
      # The rest of this if statement operates knowing neighborsite1 was a failure, so we move to neighborsite2
      neighborsite <- neighborsite2
      # Re-run the code above to see if we can get a raw file
      setwd(wd$path[wd$wd=="weather"])
      file.list <- list.files(wd$path[wd$wd=="weather"])
      site.files <- file.list[grep(neighborsite, file.list)]
      # Read the date ranges for all the files for this site to select the right one
      selection <- rep(NA, length(site.files))
      for (i in 1:length(site.files)){
        daterange <- gsub(".*weather_([0-9]+)-([0-9]+).*", "\\1-\\2", site.files[i])
        # Extract the first and second number as strings that read into dates
        filestart <- gsub("-.*", "", daterange); filestart <- as.Date(filestart, format = "%Y%m%d")
        fileend <- gsub(".*-(.*)", "\\1", daterange); fileend <- as.Date(fileend, format = "%Y%m%d")
        start <- as.Date(min(gaplist$start))
        end <- as.Date(max(gaplist$end))
        # ensure the file in question encompasses all our gaps
        if (filestart < start & fileend > end){
          selection[i] <- TRUE
        } else {
          selection[i] <- FALSE
        }
      }
      # Subset the filenames by those that do encompass our gaps
      selection <- which(selection)
      files <- site.files[selection]
      filename <- files[1]
      if (length(files) == 0){
        # If this is true, the attempt to get a raw file failed, so we try the archive for the second closest neighbor
        setwd(wd$path[wd$wd=="archive"])
        filename <- paste0(neighborsite, ".weather.rda")
        start <- min(gaplist$start)
        end <- max(gaplist$end)
        # If we have an archive for the neighborsite, we can try this. Just check that it covers the gaplist
        if (file.exists(filename)){
          load(filename)
          df.name <- paste0(neighborsite, ".weather")
          weather2 <- get(df.name)
          if (start < weather2$date[1] | end > weather2$date[nrow(weather2)]){
            rm(weather2) # Remove weather2 if it failed so we can continue our attempts
          }
        }
      } else {
        weather2 <- read.csv(filename)
        # Process from raw
        weather2 <- zentra.hydro(weather2)
      }
    }
    # Perform a backstop check that the resulting alternative data actually covers the data period
    if (!exists("weather2") | start < weather2$date[1] | end > weather2$date[nrow(weather2)]){
      stop("ERROR: No files in this directory nor in archive at the given site encompass the period of interest. Import new data and re-try.")
    }
  } else {
    # Read in this data, raw -- this occurs when the closest neighorsite had good raw data, skipping the whole large if statement above
    weather2 <- read.csv(filename)
    # Process from raw
    weather2 <- zentra.hydro(weather2)
  }
  
  # Deal with splices
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  # Create the key identifier of these gaps
  gaplist$key <- paste(sitename, gaplist$start, gaplist$end, gaplist$varname, sep = "_")
  gaplist$check.num <- splices$check.num[which(splices$key %in% gaplist$key)]
  # Move through each gap needing examination by comparing with neighborsite
  gaplist$keep <- NA
  for (i in 1:nrow(gaplist)){
    offset <- buffer*60*60
    gaplength <- gaplist$end[i] - gaplist$start[i]
    neighbordist <- round(sites$dist[sites$sitename == neighborsite], 2)
    # Calculating display of concerning area based on assumed storm speed ofat least 10 km/h
    concern <- ((neighbordist / 10)*3600)
    start <- gaplist$start[i] - offset; end <- gaplist$end[i] + offset
    subset <- weather[weather$date >= start & weather$date <= end,]
    subset2 <- weather2[weather2$date >= start & weather2$date <= end,]
    maxrain <- max(c(subset$precip, subset2$precip), na.rm = TRUE)
    plot(subset2$date, subset2$precip, pch = 17, col = "red", 
         main = paste0("Gap number ", gaplist$check.num[i], 
                       "\n", as.Date(gaplist$start[i], tz = "America/Port_of_Spain"), " to ", as.Date(gaplist$end[i], tz = "America/Port_of_Spain"),
                       "\nGap length = ", gaplength,
                       "\nDistance to neighbor = ", neighbordist, " km"), 
         xlab = "Date", ylab = "Precipitation, mm", ylim = c(0,maxrain))
    points(subset$date, subset$precip, pch = 17, col = "blue")
    abline(v = gaplist$start[i], col = "red", lwd = 2)
    abline(v = gaplist$end[i], col = "red", lwd = 2)
    abline(v = (gaplist$start[i] - concern), col = "black", lty = 2)
    abline(v = (gaplist$end[i] + concern), col = "black", lty = 2)
    legend("topright", legend = c(paste0("Neighbor site = ", neighborsite), paste0("Original site = ", sitename)), pch = c(17, 17), col = c("red", "blue"))
    
    # User is prompted if the gap should not be zeroed
    iter <- 0
    repeat {
      cat(paste0("Is Gap #", gaplist$check.num[i], " concerning? i.e., should it NOT be zeroed?  (Y/N): "))
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat("Moving this event forward for splice-interpolation...\n")
        gaplist$keep[i] <- TRUE
        break  # Exit the repeat loop and continue the function if user says Yes
      } else if (response == "N") {
        cat("The existing data for this event will be accepted (not interpolated).\n")
        gaplist$keep[i] <- FALSE
        break
      } else {
        iter <- iter + 1
        if (iter > 3){
          repeat {
            cat("You have entered invalid input 3 times. Do you want to exit?\nYou will lose your progress! (Y/N)\n")
            response2 <- readline(); response2 <- toupper(response2)
            if (response2 == "Y") {
              cat("Quitting function...\n")
              return(NA)  # Exit the repeat loop and continue the function if user says Yes
            } else if (response2 == "N") {
              cat("Returning to the question at hand...\n")
              iter <- 0
              break
            } else {
              cat("Invalid input. Please enter Y or N.\n")
            }
          }
        } else {
          cat("Invalid input. Please enter Y or N.\n")
          cat(paste("Attempt number:", iter, ", option to exit after 3 attempts.\n"))  # Show current attempt number
        }
      }
    }
  }
  # User has flagged those gaps that cannot be zeroed
  zeroing <- gaplist[gaplist$keep == FALSE,]
  gaplist <- gaplist[gaplist$keep == TRUE,]
  # Update the splices record for those we zero out
  splices$method[splices$key %in% zeroing$key] <- "zeroed.manual"
  setwd(wd$path[wd$wd=="archive"]); write.csv(splices, "splices.csv", row.names = FALSE)
  # Perform the zeroing
  weather <- precip.gap.zeroing.inner(zeroing, weather)
  # For convenience the remaining gaps are returning with their check.nums and keys, 
  # and weather and weather2 are both returned for more processing
  result <- list(weather = weather, gaplist = gaplist)
  return(result)
}
# Used to check for gaps in the precip record against nearby GHCN gauges in which a simple zeroing 
# is probably not appropriate, based on some relatively low cutoff precip value
# of daily precip below which we consider that nothing significant occurred that day and 
# we can pass the list along to zero them. 
coco.check <- function(wd, df, sitename, cutoff){
  setwd(wd$path[wd$wd=="weather"]); load("precip.archive.rda")
  setwd(wd$path[wd$wd=="sites"]); lat <- getlat(wd, sitename); lon <- getlon(wd, sitename); sites <- read.csv("site-ids.csv")
  coco <- archive
  coco$dist <- haversine.distance(lat, lon, coco$lat, coco$lon)
  # summary table of all gaps in rain data
  gapslist <- allgaps2(df, 15)
  # Glean what check.num each of these should have from splices
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  gapslist$key <- paste(sitename, gapslist$start, gapslist$end, gapslist$varname, sep = "_")
  gapslist$check.num <- splices$check.num[which(splices$key %in% gapslist$key)]
  
  gapslist$start <- as.Date(gapslist$start)
  gapslist$end <- as.Date(gapslist$end)
  # storage column for the rain observed around the days of the gap
  gapslist$gaprain <- NA
  # records the average sum of precip seen from the four nearest cocorahs stations during the gap
  for (i in 1:nrow(gapslist)){
    # Subset the coco record to what is within the dates of this gap
    subset <- coco[coco$date >= gapslist$start[i] & coco$date <= gapslist$end[i],] 
    rownames(subset) <- NULL
    
    # Acquire the total mean daily precip from the nearest four stations during this gap
    start <- gapslist$start[i]; end <- gapslist$end[i]
    gapslist$gaprain[i] <- daily.near2(start, end, subset, lat, lon)
  }
  # NAs can be induced if you ran the data up to today's date
  # If the gap is less than 3 hours, just call the gaprain zero for this
  for (i in 1:nrow(gapslist)){
    if(is.na(gapslist$gaprain[i]) & gapslist$length[i] < 3){
      gapslist$gaprain[i] <- 0
    } else if (is.na(gapslist$gaprain[i])){
      gapslist$gaprain[i] <- 9999
    } 
  }
  gapslist <- gapslist[!is.na(gapslist$gaprain), ]
  gapslist <- gapslist[gapslist$gaprain <= cutoff,]
  gapslist$id <- rownames(gapslist)
  rownames(gapslist) <- NULL
  return(gapslist)
}
# Receives output of coco.check, with precipfills gap IDs that can be filled with 0
# And the gaps list with timestamp start and stop (inclusive), and fills these gaps
# with observations of zero rainfall. The rest cannot do this because rain occurred
rainless.gaps <- function(wd, sitename, precipfills, gaps, weather){
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  
  df <- precipfills
  for (i in 1:nrow(precipfills)){
    # Note the zeroing in splices
    key <- precipfills$key[i]
    check.num <- precipfills$check.num[i]
    if (!any(splices$key == key)){
      # This means there is no match between the current key and what is in the archive
      # Which should not occur with this function - we should only be dealing with already identified gaps
      stop("ERROR: At least one of the gaps to be zeroed does not appear in splices! Please check the input gaplist.\n")
    } else {
      # Mark that these gaps were zeroed out
      splices$method[splices$key == key] <- "zeroed.auto"
    }
    gap <- gaps[df$id[i],]
    start <- gap$start; end <- gap$end
    # Zero the gap
    weather$precip[weather$date >= start & weather$date <= end] <- 0
  }
  write.csv(splices, "splices.csv", row.names = FALSE)
  return(weather)
}
show.raingaps <- function(gaplist, weather, buffer){
  for (i in 1:nrow(gaplist)){
    offset <- buffer*60*60
    start <- gaplist$start[i] - offset; end <- gaplist$end[i] + offset
    subset <- weather[weather$date >= start & weather$date <= end,]
    plot(subset$date, subset$precip, main = paste0("Gap number ", i))
  }
}
precip.gap.zeroing.inner <- function(gaps, weather){
  for (i in 1:nrow(gaps)){
    weather$precip[weather$date >= gaps$start[i] & weather$date <= gaps$end[i]] <- 0
  }
  return(weather)
}
# Simply checks the rain record at a neighbor site and displays the gaps, uses buffer in hours
# This function can successfully query the correct raw weather file from the directory
rain.neighbor.check <- function(wd, weather, neighborsite, gaplist, buffer){
  setwd(wd$path[wd$wd=="weather"])
  file.list <- list.files(wd$path[wd$wd=="weather"])
  site.files <- file.list[grep(neighborsite, file.list)]
  # Read the date ranges for all the files for this site to select the right one
  selection <- rep(NA, length(site.files))
  for (i in 1:length(site.files)){
    daterange <- gsub(".*weather_([0-9]+)-([0-9]+).*", "\\1-\\2", site.files[i])
    # Extract the first and second number as strings that read into dates
    filestart <- gsub("-.*", "", daterange); filestart <- as.Date(filestart, format = "%Y%m%d")
    fileend <- gsub(".*-(.*)", "\\1", daterange); fileend <- as.Date(fileend, format = "%Y%m%d")
    start <- as.Date(min(gaplist$start))
    end <- as.Date(max(gaplist$end))
    # ensure the file in question encompasses all our gaps
    if (filestart < start & fileend > end){
      selection[i] <- TRUE
    } else {
      selection[i] <- FALSE
    }
  }
  # Subset the filenames by those that do encompass our gaps
  selection <- selection[selection == TRUE]
  files <- site.files[selection]
  filename <- files[1]
  # If none met the criteria, we stop now
  if (length(files) == 0){
    stop("ERROR: No files in this directory at the given site encompass the period of interest. Import new data and re-try.")
  }
  # Read in this data, raw
  weather2 <- read.csv(filename)
  # Process from raw
  weather2 <- zentra.hydro(weather2)
  
  for (i in 1:nrow(gaplist)){
    offset <- buffer*60*60
    start <- gaplist$start[i] - offset; end <- gaplist$end[i] + offset
    subset <- weather[weather$date >= start & weather$date <= end,]
    subset2 <- weather2[weather2$date >= start & weather2$date <= end,]
    maxrain <- max(c(subset$precip, subset2$precip), na.rm = TRUE)
    plot(subset2$date, subset2$precip, pch = 17, col = "red", main = paste0("Gap number ", i), ylim = c(0,maxrain))
    points(subset$date, subset$precip, pch = 17, col = "blue")
    legend("topright", legend = c("Neighbor site", "Original site"), pch = c(17, 17), col = c("red", "blue"))
  }
  return(weather2)
}
rain.neighbor.fill <- function(weather, weather2, gaplist){
  for (i in 1:nrow(gaplist)){
    weather$precip[weather$date >= gaplist$start[i] & weather$date <= gaplist$end[i]] <- weather2$precip[weather2$date >= gaplist$start[i] & weather2$date <= gaplist$end[i]]
  }
  return(weather)
}
# Almost the same as rain.neighbor.check but works with a list of cocorahs checks as dates instead of datetimes
rain.neighbor.splice.check <- function(wd, weather, neighborsite, checklist){
  setwd(wd$path[wd$wd=="weather"])
  file.list <- list.files(wd$path[wd$wd=="weather"])
  site.files <- file.list[grep(neighborsite, file.list)]
  # Read the date ranges for all the files for this site to select the right one
  selection <- rep(NA, length(site.files))
  for (i in 1:length(site.files)){
    daterange <- gsub(".*weather_([0-9]+)-([0-9]+).*", "\\1-\\2", site.files[i])
    # Extract the first and second number as strings that read into dates
    filestart <- gsub("-.*", "", daterange); filestart <- as.Date(filestart, format = "%Y%m%d")
    fileend <- gsub(".*-(.*)", "\\1", daterange); fileend <- as.Date(fileend, format = "%Y%m%d")
    start <- as.Date(min(checklist$date))
    end <- as.Date(max(checklist$date))
    # ensure the file in question encompasses all our gaps
    if (filestart < start & fileend > end){
      selection[i] <- TRUE
    } else {
      selection[i] <- FALSE
    }
  }
  # Subset the filenames by those that do encompass our gaps
  files <- site.files[selection]
  filename <- files[1]
  # If none met the criteria, we stop now
  if (length(files) == 0){
    stop("ERROR: No files in this directory at the given site encompass the period of interest. Import new data and re-try.")
  }
  # Read in this data, raw
  weather2 <- read.csv(filename)
  # Process from raw
  weather2 <- zentra.hydro(weather2)
  
  for (i in 1:nrow(checklist)){
    start <- checklist$date[i] - 1; end <- checklist$date[i] + 1
    weather$date2 <- as.Date(weather$date); weather2$date2 <- as.Date(weather2$date)
    subset <- weather[weather$date2 >= start & weather$date2 <= end,]
    subset2 <- weather2[weather2$date2 >= start & weather2$date2 <= end,]
    weather$date2 <- NULL; weather2$date2 <- NULL
    
    maxrain <- max(c(subset$precip, subset2$precip))
    plot(subset2$date, subset2$precip, pch = 17, col = "red", main = paste0("Check number ", i), ylim = c(0,maxrain))
    points(subset$date, subset$precip, pch = 17, col = "blue")
    legend("topright", legend = c("Neighbor site", "Original site"), pch = c(17, 17), col = c("red", "blue"))
  }
  return(weather2)
}
rain.neighbor.splice.fill <- function(weather, weather2, checklist){
  for (i in 1:nrow(checklist)){
    start <- checklist$date[i] - 1; end <- checklist$date[i] + 1
    weather$date2 <- as.Date(weather$date); weather2$date2 <- as.Date(weather2$date)
    weather$precip[weather$date2 >= start & weather$date2 <= end] <- weather2$precip[weather2$date2 >= start & weather2$date2 <= end]
    weather$date2 <- NULL; weather2$date2 <- NULL
  }
  return(weather)
}
# Quick function that interpolates between two given indices in a given colname in a df 
quick.index.interp <- function(wd, sitename, df, varname, index1, index2){
  df0 <- df
  # Bring in splices record to notate all filled gaps
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, origin = "1970-01-01", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, origin = "1970-01-01", tz = "America/Port_of_Spain")
  
  # The actual interpolation
  mean <- (df[[varname]][index1-1] + df[[varname]][index2+1]) / 2
  df[[varname]][index1:index2] <- c(rep(mean, ((index2-index1)+1)))
  
  # Filling in splice information
  start <- df$date[index1]; end <- df$date[index2]
  start <- as.POSIXct(start, origin = "1970-01-01", tz = "America/Port_of_Spain")
  end <- as.POSIXct(end, origin = "1970-01-01", tz = "America/Port_of_Spain")
  overwrite <- splice.meta.add(wd, sitename, start, end, varname, "splice", "interp.linear", NA, TRUE)
  # Ran splice.meta.add as nested=TRUE to return TRUE if user directed to overwrite
  # This means that when the user says YES overwrite with quick.index.interp(), 
  # the actual interpolation takes place and is returning, but when they say NO,
  # the original data before any action is returned instead
  if (overwrite == TRUE){
    return(df)
  } else {
    cat("Because this gap was already noted and you elected not to overwrite, data returned without any interpolation!")
    return(df0)
  }
}
# finds the four nearest reporting stations and during a given date interval
# calculates average daily precip and sums this, returning the sum
daily.near2 <- function(start, end, coco, lat, lon){
  # THIS CODE EXCLUDES ALL STATIONS THAT ARE NOT IN THE SAME ISLAND GROUP
  # Here we do this by excluding stations further than 50km away
  coco <- coco[coco$dist < 50,]
  # for each day in this coco subset of the gap, find the four nearest stations
  # and calculate an average precip, then sum all days
  precips <- rep(NA, length(unique(coco$date)))
  for (i in 1:length(unique(coco$date))){
    dates <- unique(coco$date)
    date <- dates[i]
    subset <- coco[coco$date == date,]
    subset <- subset[order(subset$dist), ]
    rownames(subset) <- NULL
    subset <- subset[c(1:4),]
    precip <- mean(subset$precip, na.rm = TRUE)
    precips[i] <- precip
  }
  gaprain <- sum(precips)
  return(gaprain)
}

# These functions will import combined daily precip archive (GHCN+), and provide
# user with maps and comparisons with neighboring gauges to decide whether to
# proceed with splicing-interpolation for each anomaly in the weather record at the site
check.qaqc <- function(wd, df, sitename){
  setwd(wd$path[wd$wd=="weather"]); load("precip.archive.rda")
  setwd(wd$path[wd$wd=="sites"]); lat <- getlat(wd, sitename); lon <- getlon(wd, sitename); sites <- read.csv("site-ids.csv")
  # Create a daily rainfall dataset from the weather record
  dailyrain <- aggregate(precip ~ as.Date(date, tz = "America/Port_of_Spain"), data = df, sum)
  # This creates a zero reading at the end that was not really observed
  dailyrain <- dailyrain[c(1:(nrow(dailyrain)-1)),]
  colnames(dailyrain) <- c("date", "precip")
  # Check if the precip archive has observations covering this weather data
  if (dailyrain$date[1] < min(archive$date) | dailyrain$date[nrow(dailyrain)] > max(archive$date)){
    stop("ERROR: THE PRECIP.ARCHIVE DOES NOT FULLY COVER THE WEATHER FILE. IMPORT NEW DATA.")
  }
  # At this point it will be beneficial to rename archive coco since most of this code was written for cocorahs
  coco <- archive
  # Now delete all the rows in coco that have dates before or after the weather record
  coco <- coco[coco$date >= dailyrain$date[1] & coco$date <= dailyrain$date[nrow(dailyrain)],]
  rownames(coco) <- NULL
  # Print the distance to each station
  coco$dist <- haversine.distance(lat, lon, coco$lat, coco$lon)
  # Acquire the mean daily precip of the nearest 4 stations every day, plus standard deviation
  dailyrain <- daily.near(dailyrain, coco)
  # Find the differences between our station and the cocorahs mean
  dailyrain$absdiff <- abs(dailyrain$precip - dailyrain$ghcn.precip)
  dailyrain$diff <- dailyrain$precip - dailyrain$ghcn.precip
  dailyrain$dev <- dailyrain$absdiff - dailyrain$sd
  dailyrain$devnorm <- dailyrain$dev / dailyrain$sd
  dailyrain0 <- dailyrain # Save before moving on to plot at the end
  # Replace all Inf and NaN with NAs and remove
  dailyrain <- as.data.frame(sapply(dailyrain, replace.inf.nan))
  # This coerced date to numeric, change it back
  dailyrain$date <- as.numeric(dailyrain$date, origin = "1970-01-01")
  dailyrain$date <- as.Date(dailyrain$date, origin = "1970-01-01")
  # Provide a start timestamp for the day
  time <- as.character(dailyrain$date)
  time <- paste0(time, " 00:00:00")
  dailyrain$datetime <- as.POSIXct(time, tz = "America/Port_of_Spain")
  dailyrain <- dailyrain[,c("datetime", "date", "precip", "ghcn.precip", "sd", "devnorm", "neighbor", "neighbor.type")]
  # select events with high coco deviation, or with any significant rain in any measurement
  # We have to use this notation so that if any of these is an NA, it does not make the whole row NA
  dailyrain$precip <- as.numeric(dailyrain$precip)
  dailyrain$ghcn.precip <- as.numeric(dailyrain$ghcn.precip)
  dailyrain$neighbor <- as.numeric(dailyrain$neighbor)
  dailyrain <- dailyrain[is.na(dailyrain$ghcn.precip) |
              #(!is.na(dailyrain$devnorm) & dailyrain$devnorm >= 2) |
              (!is.na(dailyrain$precip) & dailyrain$precip >= 6) |
              (!is.na(dailyrain$ghcn.precip) & dailyrain$ghcn.precip >= 6) |
              (!is.na(dailyrain$neighbor) & dailyrain$neighbor >= 6),]
  dailyrain <- dailyrain[order(dailyrain$date), ]
  rownames(dailyrain) <- NULL
  
  # Some overall plots to view before going through the checklist
  plot(dailyrain0$ghcn.precip, dailyrain0$precip, ylab = "Obs precip, mm", xlab = "GHCN nearby gauges (mean)", main = paste0("GHCN vs observed precip at ", sites$site[sites$sitename == sitename]))
  model <- lm(dailyrain0$precip ~ dailyrain0$ghcn.precip); abline(model, col = "blue", lwd = 2)
  plot(dailyrain0$neighbor, dailyrain0$precip, ylab = "Obs precip, mm", xlab = "Nearest gauge, mm", main = paste0("Nearest neighbor gauge \nvs observed precip at ", sites$site[sites$sitename == sitename]))
  model <- lm(dailyrain0$precip ~ dailyrain0$neighbor); abline(model, col = "blue", lwd = 2)
  # Go through all the checks using the coco.maps and plotted time series rain to decide which to keep
  dailyrain <- coco.map(wd, df, dailyrain, sitename)
  return(dailyrain)
}
# This function receives the output of check.qaqc() and produces a series of simple maps
# that mimics what is seen on the CoCoRaHs website. The internal principles are similar to coco.near()
coco.map <- function(wd, weather, df, sitename){
  setwd(wd$path[wd$wd=="weather"]); load("precip.archive.rda")
  setwd(wd$path[wd$wd=="sites"]); lat <- getlat(wd, sitename); lon <- getlon(wd, sitename); sites <- read.csv("site-ids.csv")
  # Rename coco as elsewhere, calculate distance, and exclude other island groups (>50km)
  coco <- archive; coco$dist <- haversine.distance(lat, lon, coco$lat, coco$lon); coco <- coco[coco$dist < 50,]
  df$keep <- NA
  df$start <- NA; df$end <- NA
  for (i in 1:nrow(df)){
    date <- df$date[i]
    precip.obs <- df$precip[i]
    precip.ghcn <- df$ghcn.precip[i]
    precip.neighbor <- df$neighbor[i]
    neighbor.type <- df$neighbor.type[i]
    coco.today <- coco[coco$date == date,]; neighbor.dist <- round(coco.today$dist[coco.today$dist == min(coco.today$dist)], 2)
    check.num <- i
    subset <- coco[coco$date == date,]
    load("coastline.rda")
    library(ggplot2); library(ggspatial); library(rnaturalearth); library(rnaturalearthdata); library(sf); library(grid)
    # CHECK MAP AND GRAPHS FOR EACH ONE
    weather$dateonly <- as.Date(weather$date, tz = "America/Port_of_Spain")
    start <- weather$date[weather$dateonly == date][1] - 12*60*60
    end <- weather$date[weather$dateonly == date][1] + 36*60*60
    df$start[i] <- start; df$end[i] <- end
    df.graph <- weather[weather$date >= start & weather$date <= end,]
    
    # Graph the map
    coco.map.plot(wd, subset, sitename, coastline, precip.obs, precip.ghcn, precip.neighbor, neighbor.type, check.num)
    # Show the rain record plus or minus 12 hours around the day - this will be the interpolation period!
    par(cex.main = 1)
    plot(df.graph$date, df.graph$precip,  type = "l", col = "blue", lwd = 2, 
         main = paste0("Check #", i, " on ", date, ", type is ", neighbor.type, "\nObs precip          = ", precip.obs,"\nNeighbor precip   = ", precip.neighbor, "\nNeighbor distance  = ", neighbor.dist, " km"), xlab = "Date", ylab = "Precip, mm")
    abline(v = (df.graph$date[1] + 12*60*60), col = "black", lty = 2) # Lines to bound the 24 hour observation period
    abline(v = (df.graph$date[1] + 36*60*60), col = "black", lty = 2)
    if (neighbor.type == "CoCoRaHs"){
      abline(v = (df.graph$date[1] + 20*60*60), col = "red", lty = 2) # Line at 8am the next day for CoCoRaHs, 32 hours from origin
      abline(v = (df.graph$date[1] + 44*60*60), col = "red", lty = 2) 
    }

    # Ask the user if they want to let the original data stand or mark this check for interpolation
    iter <- 0
    repeat {
      cat(paste0("Is Check #", i, " concerning? i.e., should it be interpolated?  (Y/N): ",
                 "\nIf you say yes, the entire period displayed on the graph will be interpolated!\n"))
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat("Moving this event forward for splice-interpolation...\n")
        df$keep[i] <- TRUE
        break  # Exit the repeat loop and continue the function if user says Yes
      } else if (response == "N") {
        cat("The existing data for this event will be accepted (not interpolated).\n")
        df$keep[i] <- FALSE
        break
      } else {
        iter <- iter + 1
        if (iter > 3){
          repeat {
            cat("You have entered invalid input 3 times. Do you want to exit?\nYou will lose your progress! (Y/N)\n")
            response2 <- readline(); response2 <- toupper(response2)
            if (response2 == "Y") {
              cat("Quitting function...\n")
              return(NA)  # Exit the repeat loop and continue the function if user says Yes
            } else if (response2 == "N") {
              cat("Returning to the question at hand...\n")
              iter <- 0
              break
            } else {
              cat("Invalid input. Please enter Y or N.\n")
            }
          }
        } else {
          cat("Invalid input. Please enter Y or N.\n")
          cat(paste("Attempt number:", iter, ", option to exit after 3 attempts.\n"))  # Show current attempt number
        }
      }
    }
  }
  # Remove the checks from the list that were not concerning as marked by user
  df <- df[df$keep == TRUE,]; df$keep <- NULL; df$check.num <- rownames(df); rownames(df) <- NULL
  df$start <- as.POSIXct(df$start, tz = "America/Port_of_Spain", origin = "1970-01-01")
  df$end <- as.POSIXct(df$end, tz = "America/Port_of_Spain", origin = "1970-01-01")
  #df <- df[,c("checknum", "datetime", "date", "precip", "ghcn.precip", "neighbor", "neighbor.type")]
  return(df)
}
coco.map.plot <- function(wd, subset, sitename, coastline, precip.obs, precip.ghcn, precip.neighbor, neighbor.type, check.num){
  setwd(wd$path[wd$wd=="sites"])
  # Distinguish whether we are in STT/STJ or STX
  if (getlat(wd, sitename) > 18.2){
    lon1 <- -65.1; lon2 <- -64.5
    lat1 <- 18.2; lat2 <- 18.5
    island <- "STT/STJ"
  } else {
    lon1 <- -65; lon2 <- -64.5
    lat1 <- 17.6; lat2 <- 17.85
    island <- "STX"
  }
  # Notate the site coordinates to plot this
  title <- paste0("Check #", check.num, " on ", subset$date[1], ", site marked by black box\n...\nObs precip          = ", 
                  precip.obs, "\nGHCN precip      = ", precip.ghcn, "\nNeighbor precip  = ", precip.neighbor, "  (type: ", neighbor.type, ")")
  site.coords <- data.frame(lat = getlat(wd, sitename), lon = getlon(wd, sitename))
  # Basic map with lat/lon tick marks and coastline and points added to map
  p <-   ggplot(data = coastline) +
    geom_sf(fill = "white", color = "black") +
    geom_point(data = subset, aes(x = lon, y = lat, color = precip), size = 3) +
    scale_color_gradientn(
      colors = c("blue", "green", "yellow", "orange", "red", "darkred")
    ) +    
    coord_sf(xlim = c(lon1, lon2), ylim = c(lat1, lat2), expand = FALSE) +
    theme_bw() +
    theme(
      panel.border = element_rect(color = "black", fill = NA),
      panel.grid.major = element_line(color = "gray", linetype = "dotted"),
      panel.background = element_blank(),
      axis.title = element_blank()
    ) +
    geom_point(data = site.coords, aes(x = lon, y = lat), 
               shape = 0, color = "black", size = 5, stroke = 1.5) + # Add black "X"
    annotation_north_arrow(location = "tl", which_north = "true", height = unit(1, "cm"), width = unit(1, "cm")) +
    annotation_scale(location = "bl", width_hint = 0.5) +
    labs(color = "GHCN precip, mm") + # Add title and legend
    ggtitle(title)
  print(p)
}
# goes through the df weather record each day, finds the four nearest reporting stations
# on that day, reports an average precip and a standard deviation
daily.near <- function(df, coco){
  # THIS CODE EXCLUDES ALL STATIONS THAT ARE NOT IN THE SAME ISLAND GROUP
  # Here we do this by excluding stations further than 50km away
  coco <- coco[coco$dist < 50,]
  df$ghcn.precip <- NA
  df$sd <- NA
  df$neighbor <- NA
  df$neighbor.type <- NA
  for (i in 1:nrow(df)){
    date <- as.Date(df$date[i], tz = "America/Port_of_Spain")
    coco.today <- coco[coco$date == date & !is.na(coco$precip),]
    stations.today <- coco.today[order(coco.today$dist),][1:4,]
    neighbor <- coco.today[order(coco.today$dist),][1,]
    mean <- mean(stations.today$precip)
    sd <- sd(stations.today$precip)
    df$ghcn.precip[i] <- mean
    df$sd[i] <- sd
    df$neighbor[i] <- neighbor$precip
    df$neighbor.type[i] <- neighbor$type
  }
  return(df)
}
leading.zeros <- function(string, length){
  stringlength <- length - nchar(string)
  conversion <- 10^stringlength
  conversion <- as.character(conversion)
  zeroes <- substr(conversion, 2, nchar(conversion))
  output <- paste0(zeroes, string)
  return(output)
}
# Function to replace Inf and NaN with NA
replace.inf.nan <- function(df) {
  if (is.numeric(df)) {
    df[!is.finite(df) | is.nan(df)] <- NA
  }
  return(df)
}
graph.checks <- function(weather, check){
  weather$dateonly <- as.Date(weather$date)
  if (nrow(check) == 0){
    cat("Congratulations, there are no major deviations with surrounding rain gauges - proceed")
  } else{
    for (i in 1:nrow(check)){
      subset <- weather[weather$dateonly == check$date[i] | weather$dateonly == check$date[i] + 1,]
      plot(subset$date, subset$precip,  type = "l", col = "blue", lwd = 2, main = check$date[i], xlab = "Date", ylab = "Precip, mm")
    }
  }
}
splice.meta.add <- function(wd, sitename, start, end, var, type, method, check.num, nested = FALSE){
  # Bring in splices record to notate all filled gaps
  setwd(wd$path[wd$wd=="archive"]); splices <- read.csv("splices.csv")
  splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  start <- as.POSIXct(start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  end <- as.POSIXct(end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  unique1 <- nrow(splices) + 1
  splices1 <- data.frame(unique = unique1, site = sitename, start = start, end = end, var = var, type = type, method = method, check.num = check.num, key = NA)
  splices1$key <- paste(splices1$site, splices1$start, splices1$end, splices1$var, sep = "_")
  splices <- rbind(splices, splices1)
  # If this splice is somehow already in the table, don't add it
  if(any(splices$key[nrow(splices)] %in% splices$key[c(1:(nrow(splices)-1))])){
    # Tell the user a splice with this same key already exists, and give them the previous type and method to decide to overwrite
    repeat {
      cat(paste0("This splice is already noted! Would you like to overwrite it? (Y/N)",
                 "\nEXISTING SPLICE INFORMATION FOUND:",
                 "\n --start    = ", splices$start[splices$key == splices1$key[1]][1],
                 "\n --end      = ", splices$end[splices$key == splices1$key[1]][1],
                 "\n --variable = ", splices$var[splices$key == splices1$key[1]][1],
                 "\n --type     = ", splices$type[splices$key == splices1$key[1]][1], 
                 "\n --method   = ", splices$method[splices$key == splices1$key[1]][1],
                 "\nIf this information is the same as what you are attempting to write, overwriting is okay.",
                 "\nIf it is different, be certain you want to overwrite this splice!"))
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat(paste0("Splice is overwritten at the same uniqueID# and key!\n"))
        # Delete the "extra" row because we are overwriting in place
        splices1$unique[1] <- splices$unique[splices$key == splices1$key[1]][1]
        splices <- splices[c(1:(nrow(splices)-1)),]
        splices[splices$key == splices1$key,] <- splices1[1,]
        if (nested == TRUE){
          # When overwriting the splice and inside a nested function, we overwrite it here and escape while returning TRUE overwrite
          write.csv(splices, "splices.csv", row.names = FALSE)
          return(TRUE)
        } else {
          break  # When function is not nested, we will not return a boolean about overwriting
        }
      } else if (response == "N") {
        cat("Splice will not be overwritten - do not edit the data if you are keeping the original splice!\n")
        if (nested == TRUE){
          # The function was called in nested form, so we should return overwrite == FALSE to prevent data from being altered
          return(FALSE)
        } else {
          return(invisible()) # If not nested, we can just exit function to prevent further action
        }
      } else {
        cat("Invalid input. Please enter Y or N.\n")
      }
    }
  } else {
    # In the case where nothing in the splice archive matches the current action
    # OVERWRITE should automatically be returned true if it is in a nested function
    if (nested == TRUE){
      write.csv(splices, "splices.csv", row.names = FALSE)
      return(TRUE)
    } else {
      write.csv(splices, "splices.csv", row.names = FALSE)
      return(invisible())  # When function is not nested, we will not return a boolean about overwriting
    }
  }
  write.csv(splices, "splices.csv", row.names = FALSE)
}

######################   HOBOWARE, MANNING, DISCHARGE     ######################
# Hoboware and Manning/discharge functions
# This function takes the raw hydro record after basic importation
# And does further processing steps: pulls weather archive from above,
# Applies pressure correction from elevations, maps hydro onto 15-minute data,
# calculates water level from pressures, and trimming
hoboware.import <- function(wd, hydro, sitename){
  # Include code here to deal with hobolink vs hoboware
  ##################################
  if ("level" %in% colnames(hydro)){
    # If the level column as already added, this is hobolink
    hydro$date <- as.POSIXct(hydro$date, tz = "America/Port_of_Spain")
    hydro$timestamp <- as.numeric(hydro$date)
    df <- hydro[,c("date", "timestamp", "level")]
  } else {
    # Else we have hoboware and need to calculate level
    # Get weather archive containing uncorrected pressure
    setwd(wd$path[wd$wd=="archive"])
    weather.file <- paste0(sitename, ".weather.rda")
    load(weather.file)
    df.name <- paste0(sitename, ".weather")
    weather <- get(df.name)
    # Perform pressure correction
    weather <- weather.pres(wd, weather, sitename)
    # drop column $temp from weather since it shares a name with the hoboware temp column
    tempcol <- which(colnames(weather) == "temp")
    weather <- weather[,c(1:tempcol-1,(tempcol+1):ncol(weather))]
    
    # Here we must check that weather overlaps hydro completely
    if (all(min(weather$date) <= min(hydro$date) & max(weather$date) >= max(hydro$date))) {
      # No action
    } else {
      # If it does not, print a warning statement.
      repeat {
        cat(paste0("ERROR: WEATHER DATA DOES NOT COVER WATER LEVEL RECORD PERIOD.\n",
                   "  --Weather start date  = ", min(weather$date), "\n",
                   "  --Hydro start date    = ", min(hydro$date), "\n",
                   "  --Weather end date    = ", max(weather$date), "\n",
                   "  --Hydro end date      = ", max(hydro$date), "\n",
                   "Would you like to trim the hydro record to fit the weather? (Y/N)\n"))
        response <- readline(); response <- toupper(response)
        if (response == "Y"){
          cat("Trimming hydro record to fit weather archive...\n")
          hydro <- hydro[hydro$date >= min(weather$date) & hydro$date <= max(weather$date),]
          break
        } else if (response == "N"){
          cat("Cannot proceed without weather data! Closing function.\n")
          return(NA)
        } else {
          cat("Invalid input. Please enter Y or N.\n")
        }
      }
    }
    hydro <- hydro[,c("date","abs","temp")]
    # Now map the values from the weather station onto the logger interval
    df <- hydro %>%
      left_join(weather, by = "date") %>%
      mutate(pres = if_else(is.na(pres),
                            approx(x = weather$date, y = weather$pres, xout = date)$y,
                            pres))
    # Calculate water level from pressure data
    levels <- waterlevel(df$abs, df$pres, df$temp)
    df$level <- levels
    # Create new columns for df to begin to match archive
    df$timestamp <- as.numeric(df$date)
    # Name them as df.h
    df <- df[,c("date","timestamp", "level")]
  }
  
  # Now we need to force the data into 15 minute timesteps
  # make an even 15-minute start and end time for the subset
  min15 <- df$timestamp/900
  start <- min15[1]
  start <- ceiling(start)
  end <- min15[length(min15)]
  end <- floor(end)
  range <- c(start:end)
  range <- range*900
  dates <- as.POSIXct(range, tz = "America/Port_of_Spain", origin = "1970-01-01")
  # This creates df2, which has evenly spaced timestamps
  df2 <- data.frame(date = dates, timestamp = as.numeric(dates), site = sitename)
  # Interpolate level into the 15 minute data
  level.interp <- approx(
    x = df$date,
    y = df$level,
    xout = df2$date,
    method = "linear"
  )
  level <- level.interp$y
  # add to df2, the new data
  df2$level <- level
  df <- df2
  return(df)
}
# The next several functions takes several slope measurements from the thalweg along the 
# reaches of each watershed site and generates an average slope for each site.
# We accomplish this with a function similar to streamplot() which takes the survey data
# and re-writes it as coordinates in units of meters. In this case we provide both $dist
# and $alt in units of meters to begin with as well.
slopeplot <- function (df){
  # first need to transform the data properly
  for (i in 1:nrow(df)){
    #first set upstream to negative x coords
    if (df$direction[i]=="Upstream"){
      df$dist[i] <- df$dist[i]*-1
    } }
  # next set the furthest upstream point to zero and name the x column
  df <- df %>%
    group_by(site) %>%
    mutate(x = dist - min(dist))
  df$dist <- NULL; #df$direction <- NULL
  # invert the alt readings
  df$alt <- df$alt * -1
  # next set lowest point as zero and name as y (really z but y for ease)
  df <- df %>%
    group_by(site) %>%
    mutate(y = alt - min(alt))
  df$alt <- NULL
  
  #order it so that the values come in order of x reading within site*reps
  #this is important because later functions assume left bank precedes right bank in order
  df <- df %>%
    arrange(site, x)
  return (df)
}
allslopes1 <- function(df){
  slopes <- c()
  mfunc <- function(x1, x2, y1, y2){
    m <- (y2-y1)/(x2-x1)
  }
  for (i in 1:nrow(df)-1){
    slope <- mfunc(df$x[1], df$x[1+i], df$y[1], df$y[1+i])
    slopes <- c(slopes,slope)
  }
  slopes <- c(slopes[2:length(slopes)])
  return(slopes)
}
allslopes2 <- function(df){
  slopes <- allslopes1(df)
  for (i in 1:nrow(df)-1){
    df2 <- df[(i+1):nrow(df),]
    #re-index
    rownames(df) <- NULL
    slopes <- c(slopes, allslopes1(df2))
  }
  slopes <- c(slopes[1:(length(slopes)-2)])
  return(slopes)
}
# This final function takes the raw slope information:
# df$site with site name, $direction with Upstream or Downstream, 
# $dist with distance in meters, $alt with altitude in meters, and provides
# a df with calculated slopes for each site, using nested functions. 
siteslopes <- function(df){
  # Use slopeplot() to reformat the input coordinates
  all <- slopeplot(df)
  # Extract unique site names
  sites <- unique(all$site)
  # Perform slope calculation on each site
  # First make an empty dataframe to store results
  slopes <- data.frame(site = sites, slope = NA)
  # An empty list to store the df subsets for each site
  subsets <- list()
  for (i in 1:length(sites)){
    subsets[[i]] <- subset(all, site == sites[i])
    slopes$slope[i] <- mean(allslopes2(subsets[[i]]))
  }
  slopes$slope <- abs(slopes$slope)
  return(slopes)
}
# alt is a vector of difference between water levels, positive altitude
# and level is a vector of ordered water levels corresponding to alt
# dist is the distance between the loggers in meters
# height is the height of the higher logger over the other in meters
create.slope.model <- function(wd, alt, level, dist, height, sitename){
  slope.model <- data.frame(alt = alt, level = level)
  slope.model$alt <- slope.model$alt + height
  slope.model$slope <- (slope.model$alt) / dist
  slope.model$site <- sitename
  slope.model <- slope.model[,c("site","level","alt","slope")]
  setwd(wd$path[wd$wd=="sites"])
  if (file.exists("slope_models.csv")){
    models <- read.csv("slope_models.csv")
    # Remove the site's old model if present
    models <- models[models$site != sitename,]
    models <- rbind(models, slope.model)
    models <- models[order(models$site, models$level),]
    rownames(models) <- NULL
    write.csv(models, "slope_models.csv", row.names = FALSE)
  } else{
    write.csv(slope.model, "slope_models.csv", row.names = FALSE)
  }
  return(slope.model)
}
#quick functions for water density and water level from diff pressure, units of kPa and C
waterdensity <- function(temp){
  ph2o <- 998.2071
  beta <- 0.00026
  stdtemp <- 20
  density <- ph2o / (1 + (beta * (temp - stdtemp)))
  return(density)
}
waterlevel <- function(abs, ref, temp){
  density <- waterdensity(temp)
  gauge <- abs - ref
  g <- 9.80665
  level <- 1000*(gauge / (density*g))
  return(level)
}
# The streamplot function takes the df with $site (reach), $rep (repeated cross section surveys), 
# $bank (left and right bank survey directions from central tripod in thalweg), 
# $dist (horizontal distance from tripod, meters), and $alt (reading on survey rod, feet)
# and returns a df with $site, $rep, $x (with leftbank zero origin, meters),
# and y (really z, with thalweg zero origin, meters)
streamplot <- function (df){
  # first need to transform the data properly
  for (i in 1:nrow(df)){
    #first set left bank to negative x coords
    if (df$bank[i]=="left"){
      df$dist[i] <- df$dist[i]*-1
    } }
  # next set the leftmost point to zero and name the x column
  df <- df %>%
    group_by(site,rep) %>%
    mutate(offset = min(dist),
           x = dist - min(dist))
  df$offset <- NULL; df$dist <- NULL; df$bank <- NULL
  # convert feet to meters in altitude and invert the alt readings
  df$alt <- df$alt * 0.3048 ; df$alt <- df$alt * -1
  # next set lowest point as zero and name as y (really z but y for ease)
  df <- df %>%
    group_by(site,rep) %>%
    mutate(offset = min(alt),
           y = alt - min(alt))
  df$offset <- NULL; df$alt <- NULL
  df$m <- NA
  df$b <- NA
  
  #briefly ensure that any flat surfaces in stream survey are made slightly different
  for (i in 1:(nrow(df)-1)){
    if (df$y[i] == df$y[i+1]){
      df$y[i] <- df$y[i] - 0.00000001
    }
  }
  
  # calculate a slope and intercept the current row and the next row, excluding
  # when this borders on the next rep or site or when it is the last row,
  # in which case the m and b are repeated from the row before, since these are endpoints and must share
  # their slope with their predecessor
  for (i in 1:nrow(df)){
    if (df$site[i+1] != df$site[i] | df$rep[i+1] != df$rep[i] | i == nrow(df)){
      df$m[i] <- df$m[i-1]
      df$b[i] <- df$b[i-1]
    } else {
      df$m[i] <- (df$y[i+1]-df$y[i]) / (df$x[i+1]-df$x[i])
      df$b[i] <- df$y[i] - (df$m[i]*df$x[i])
    }
  }
  #order it so that the values come in order of x reading within site*reps
  #this is important because later functions assume left bank precedes right bank in order
  df <- df %>%
    arrange(site, rep, x)
  return (df)
}
hyd.radius <- function (df, level){
  # create dummy column to mark line segments to be ignored for perimeter
  df$ignore <- 0
  
  # first make a new column which finds the endpoints
  df$is.endpoint <- 0
  for (i in 1:nrow(df)){
    if (i == 1 | i == nrow(df)){
      df$is.endpoint[i] <- 1
    }
  }
  for (i in 2:(nrow(df)-1)){
    if (df$rep[i+1] != df$rep[i] | df$rep[i-1] != df$rep[i]){
      df$is.endpoint[i] <- 1
    }
  }
  # now the end points of all transects are marked
  # next we check if the endpoints are out of water, and if so, whether the next innermost are also
  for (i in 1:(nrow(df)-1)){
    if (df$is.endpoint[i] == 1 & df$y[i] > level){
      if (df$y[i+1] > level){
        # if yes, mark as endpoint
        df$is.endpoint[i+1] <- 1
      }
    }
  }
  # the above only works for the left bank, now run the for loop backwards and mark the right bank
  for (i in nrow(df):2){
    if (df$is.endpoint[i] == 1 & df$y[i] > level){
      if (df$y[i-1] > level){
        # if yes, mark as endpoint
        df$is.endpoint[i-1] <- 1
      }
    }
  }
  # we must be re-write the dataframe with interpolated x/y points wherever the 
  # water level is less than the y values
  # we use an on the fly function called interp to do this
  interp <- function (df, level){
    for (i in 2:(nrow(df)-1)){
      # check if dealing with an endpoint
      if (df$is.endpoint[i] == 1){
        #check if the endpoint has a non-endpoint neighbor
        if (df$is.endpoint[i+1] == 0 | df$is.endpoint[i-1] == 0){
          # and point height is out of water
          # importantly the fact that it is not greater or equal to level
          # means that we can re-run this function on processed data
          # and it will simply ignore an endpoint that is measure as equal to level
          if (df$y[i] > level){
            # interpolate a new point using water level as the new y
            df$y[i] <- level
            
            #now interpolate x
            if (df$is.endpoint[i+1] == 0){
              #interpolate x using slope intercept
              df$x[i] <- (level-df$b[i])/df$m[i]
            } 
            # only use the slope of the current line if we were on the left bank of the water.
            # we use the slope of the previous line to interp x if we are on the right bank 
            # i.e., if we are on the leading edge of a segment of endpoint trues
            else {
              df$x[i] <- (level-df$b[i-1])/df$m[i-1]
            }
            
            # creates flat slope if we are on the right bank
            if (df$y[i+1] > level){
              df$m[i] <- 0
              df$b[i] <- level
              df$ignore[i] <- 1
            }
          } 
        } else{
          # when we're within a segment of endpoint trues
          df$y[i] <- level
          # keep x the same, simply drop the point to level
          # flatten the slope
          df$m[i] <- 0
          df$b[i] <- level
          df$ignore[i] <- 1
        }
      } else{
        # THIS MAIN LEVEL ELSE BLOCK IS FOR ALL NON ENDPOINT CASES
        if (df$y[i] <= level){
          #this is left blank so that when we re-run, nothing breaks at the "banks" of islands
        }
        else {
          # first deal with single points sticking out of the water
          if (df$y[i] > level & df$y[i+1] <= level & df$y[i-1] < level){
            # interpolate first new point (to the left) using water level as the new y
            df$y[i] <- level
            # and x interpolated using the slope-intercept
            # but need to use m and b from last row because it refers to the line "behind"
            # the current point exceeding the level
            df$x[i] <- (level-df$b[i-1])/df$m[i-1]
            # slope and intercept of i-1 will not have changed
            # also mark on this row that the "flat-top" line segment to the right of this point
            # must be ignored for perimeter calculation
            df$ignore[i] <- 1
            # and now also need a second new point using the m and b of the current row
            # but there is nowhere in the df to store 
            # so we create a quick temporary df to write the row for the point to our right
            # which interpolates x and is not ignored since "ignore" refers to the line to the right
            new.x <- (level-df$b[i])/(df$m[i])
            new.m <- df$m[i]
            new.b <- df$b[i]
            # now that the new row's slope-intercept is stored from the old one, we can write
            # the slope intercept for the flat-top line
            df$m[i] <- 0
            df$b[i] <- level
            
            # and finally we can make the new row and splice it in
            new.row <- data.frame(site = df$site[i], rep = df$rep[i], x = new.x,
                                  y = level, m = new.m, b = new.b, 
                                  s = df$s[i], n = df$n[i], ignore = 0, is.endpoint = 0)
            df <- rbind(df[1:i, ], new.row, df[(i+1):nrow(df), ])
          } else{
            # this else chunk is to deal with a series of points out of water
            # which means we need to send away any points that are fully underwater
            if (df$y[i] < level){
              # this is left empty, because we take no action on underwater points
            } 
            else{
              # first we need to deal with any points on the trailing end of the island, 
              # where it dips back into the water
              if(df$y[i]>level & df$y[i+1] <= level){
                # it is much the same as the endpoint code above for the left bank
                df$y[i] <- level
                df$x[i] <- (level-df$b[i])/df$m[i]
              } 
              else{
                #now need to write code for the "high and dry points"
                if (df$m[i-1] == 0){
                  #need to take care of points that are on islands but have dry neighbors on both sides
                  #they will be hard-coded to taking flat positions
                  #this is necessary since the slope of preceding lines is switched to zero below,
                  #which makes this special case necessary. These cases can be identified by
                  #the fact that the preceding neighbor has a slope zero
                  df$y[i] <- level
                  df$m[i] <- 0
                  df$b[i] <- level
                  df$ignore[i] <- 1
                } else{
                  #then deal with the banks of these "islands"
                  #interpolate the point where we the water level sits as before
                  df$y[i] <- level
                  df$x[i] <- (level-df$b[i-1])/df$m[i-1]
                  df$m[i] <- 0
                  df$b[i] <- level
                  df$ignore[i] <- 1
                }
              }
            } 
          }
        }
      }
    }
    return(df)
  }
  
  #before running interp the first time, ensure there is no case in which the water level is exactly
  #equal to any of the point altitudes. This would cause problems
  any.equals <- any(df$y == level)
  while (any.equals == TRUE){
    for (i in 1:nrow(df)){
      if (df$y[i] == level){
        df$y[i] <- df$y[i] + 0.00000001
      }
    }
  }
  
  df <- interp(df, level)
  # because of the fact that the dataframe length changes on the fly in this function,
  # the function stops iterating early if we added any points
  # so we need to run the function again on the new df
  df <- interp(df, level)
  # run it again for good measure
  df <- interp(df, level)
  
  # the indexing in the main for loop above had to exclude the very first and last row of df
  # so we need to coerce these two points to match water level if they exceed it, just as we
  # did for the other endpoint trues
  # first check if the first row neighbors a non-endpoint
  if (df$is.endpoint[2] == 0){
    # interpolate a new point using water level as the new y
    df$y[1] <- level
    # and x interpolated using the slope-intercept
    df$x[1] <- (level-df$b[1])/df$m[1]
    # creates flat slope if we are on the right bank
    if (df$y[2] > level){
      df$m[1] <- 0
      df$b[1] <- level
      df$ignore[1] <- 1
    } 
  } else {
    # if endpoint is part of a series of endpoint trues
    df$y[1] <- level
    df$m[1] <- 0
    df$b[1] <- level
    df$ignore[1] <- 1
  }
  
  # now do the same for the endpoint of df
  if (df$is.endpoint[(nrow(df)-1)] == 0){
    # interpolate a new point using water level as the new y
    df$y[nrow(df)] <- level
    # and x interpolated using the slope-intercept
    df$x[nrow(df)] <- (level-df$b[nrow(df)])/df$m[nrow(df)]
  } else {
    # if endpoint is part of a series of endpoint trues
    df$y[nrow(df)] <- level
    df$m[nrow(df)] <- 0
    df$b[nrow(df)] <- level
    df$ignore[nrow(df)] <- 1
  }
  # re-sort the df by x to get the indexes in order
  df <- df[order(df$rep, df$x), ]
  #  df$is.endpoint <- NULL
  
  # next take each horizontal named point and measure its width (base of rectangle)
  # take the minimum of the current point and the last point, use this to draw a rectangular segment
  # and take the segment area
  # but now also take the minimum of the two points, the maximum, and the min Z value at X position
  # and get the area of the right triangle they form, to add to the rectangular area
  # this together is the area of the segment
  # creating empty storage column for segment areas
  df$s.area <- NA
  
  for (i in 1:nrow(df)){
    # if statement to assign a zero value to s.area (segment area) if the next row is not
    # part of its rep subset or is the last row
    if (df$rep[i+1] != df$rep[i] | i == nrow(df)){
      df$s.area[i] = 0
    } else {
      # width is the distance between two horizontal points
      w <- df$x[i+1] - df$x[i]
      # rectangle height is the distance between zero and the minimum of the two y values
      rh <- min(df$y[i+1], df$y[i])
      #rectangle area calculation
      r.area <- w*rh
      #triangle height is the distance between the two y values
      th <- abs(df$y[i+1] - df$y[i])
      #triangle area calculation
      t.area <- (w*th)/2
      #total segment area stored
      df$s.area[i] <- r.area + t.area
    }
  }
  
  # by site, creates total rectangular area, subtracts total solid area, and provides
  # total stream cross sectional area, m^2
  df <- df %>%
    group_by(site, rep) %>%
    mutate(totalarea = (max(x) - min(x)) * max (y),
           totalsolid = sum(s.area),
           a = totalarea - totalsolid)
  df$totalarea <- NULL; df$totalsolid <- NULL
  
  # the final step is to calculate the wetted perimeter by summing the length of each 
  # line segment which is not marked "ignore"
  df$perim <- 0
  for (i in 1:nrow(df)){
    # assign zero value to rows marked ignore, or final rows in a subset
    if (df$rep[i+1] != df$rep[i] | i == nrow(df) | df$ignore[i] == 1){
      df$perim[i] = 0
    } else {
      #legs of right triangle, leg1 is horizontal width
      leg1 <- df$x[i+1] - df$x[i]
      #leg2 is same as triangle height
      leg2 <- abs(df$y[i+1] - df$y[i])
      df$perim[i] <- sqrt((leg1^2)+(leg2^2))
    }
  }
  
  return(df)
}
# Straightforward Manning equation designed for one site at a time
manning <- function(df, level){
  # Run hyd.radius on gutsurvey data and the stated level
  df <- hyd.radius(df, level)
  # This statement collapses the large dataset into site*rep summaries and calculates r
  df <- df %>%
    group_by(rep) %>%
    summarise(a = mean(a),
              r = mean(a)/sum(perim),
              s = mean(s),
              n = mean(n))
  # This statement averages across reps within site
  df <- df%>%
    summarise(a = mean(a),
              r = mean(r),
              s = mean(s),
              n = mean(n))
  # Manning equation
  a = df$a
  r = df$r
  s = df$s
  n = df$n
  q = (a*(r^(2/3))*(s^(1/2)))/n
  return(q)
}
# Use Kennedy when creating a new rating curve which includes a GZF
# Sitename will have to be altname, the alternative (capitalized) name
kennedy <- function(qfits, sitename, df){
  # read in the measured values for the rating curve but exclude GZF
  fit <- qfits[qfits$site == sitename & qfits$q !=0,]
  # extract gauge height of zero flow from qfits
  gzf <- qfits$level[qfits$site == sitename & qfits$q == 0]
  # make offset level
  fit$d2 <- fit$level - gzf
  # log transform adjusted level and q
  fit$ld2 <- log(fit$d2)
  fit$lq <- log(fit$q)
  # fit a linear equation to this, and solve for x
  linfit <- lm(fit$ld2 ~ fit$lq)
  # extract linear coefficients
  m <- linfit$coefficients[2]
  b <- linfit$coefficients[1]
  # write equation in log form
  # fit$d2 <- exp(b)*fit$q^m
  # solve for x
  # fit$q <- (fit$d2 / exp(b))^(1/m)
  # and write x and y for the qcurve
  # first get offset level
  df$ggzf <- df$level - gzf
  for (i in 1:nrow(df)){
    # Ensure that the value for this is never negative
    if (df$ggzf[i] < 0){
      df$ggzf[i] <- 0
    }
  }
  df$q <- (df$ggzf / exp(b))^(1/m)
  df$ggzf <- NULL
  return(df)
}
# Same as Kennedy but without a GZF, use to fit a standard rating curve
fit.qcurve <- function(qfits, sitename, qcurve){
  # read in the measured values for the rating curve
  fit <- qfits[qfits$site == sitename,]
  fit$ld <- log(fit$level)
  fit$lq <- log(fit$q)
  linfit <- lm(fit$ld ~ fit$lq)
  m <- linfit$coefficients[2]
  b <- linfit$coefficients[1]
  r2 <- summary(linfit)$r.squared
  plot(fit$lq, fit$ld, xlab = "Log-discharge", ylab = "Log-waterlevel", main = paste0("Log-transformed rating curve\nR-squared = ", round(r2, 2)))
  abline(linfit, col = "red", lwd = 2)
  if (r2 < 0.6){
    # When r2 is poor, consult the user
    repeat {
      cat(paste0("The rating curve fit may be poor (r-squared < 0.6), continue with this? (Y/N)\n"))
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat(paste0("Proceeding with this rating curve!\n"))
        break  # Exit the repeat loop and continue the function
      } else if (response == "N") {
        cat("Rejecting this rating curve fit -- recommend checking/altering qfits.\n")
        return() # Exits function to allow re-try
      } else {
        cat("Invalid input. Please enter Y or N.\n")
      }
    }
  }
  # Back-transform and solve for x, which is q in the qcurve
  qcurve$q <- (qcurve$level / exp(b))^(1/m)
  return(qcurve)
}
manning.qcurve <- function(wd, sitename, is.slopemodel){
  setwd(wd$path[wd$wd=="sites"])
  # Pull down gut survey info and process into standard form
  survey <- read.csv("gutsurveys.csv")
  survey <- streamplot(survey)
  if (is.slopemodel == TRUE){
    slope.model <- read.csv("slope_models.csv")
    slope.model <- slope.model[slope.model$site == sitename,]
    # Placeholder column with $s if we have a slope curve model
    survey$s <- NA
  } else {
    slopes <- read.csv("slopedata.csv")
    slopes <- siteslopes(slopes)
    # Merge slopes from other datasets by site and add to df
    slopemerge <- merge(survey, slopes, by = "site", all.x = TRUE)
    survey$s <- slopemerge$slope
  }
  # Pull down roughness coefficients, and add as column to df
  site.info <- read.csv("site-ids.csv")
  longsitename <- site.info$site.alt[site.info$sitename == sitename]
  survey <- survey[survey$site == longsitename,]
  survey$n <- site.info$roughness[site.info$sitename == sitename]
  # Above keeps the site column to keep hyd.radius from breaking
  # Max bank heights from each rep
  maxlist <- survey %>%
    group_by(rep) %>%
    summarize(max.h = max(y))
  # Minimum among these expressed in mm
  max <- floor(min(maxlist$max.h)*1000)
  # Create sequence of timestamps from 1 to max
  timestamp <- c(1:max)
  # Do the same for all levels
  level <- seq(0.001, (max/1000)+0.001, length.out = max)
  # Now bring this together as a df that will be fed into the discharge function
  df.h <- data.frame(timestamp = timestamp, level = level)
  # Interpolate a slope column into df.h from the slope model
  df.h$slope <- approx(x = slope.model$level, y = slope.model$slope, xout = df.h$level, rule = 2)$y
  # Initialize the column for discharge
  df.h$q <- NA
  #now cycle through each level and calculate discharge!!!
  if (is.slopemodel == TRUE){
    for (i in 1:(nrow(df.h))){
      survey$s <- df.h$slope[i]
      df.h$q[i] <- manning(survey, df.h$level[i])
    }
  } else {
    for (i in 1:(nrow(df.h))){
      df.h$q[i] <- manning(survey, df.h$level[i])
    }
  }
  df.h$site <- sitename
  df.h <- df.h[,c("site","timestamp","level","q")]
  return(df.h)
}
add.qcurve <- function(wd, new.qcurve, sitename, reason){
  # Confirm with the user that this is not being re-run
  repeat {
    cat("This function will alter qcurves.csv and qcurves_meta!\nIf you have already run this code and added this qcurve, do not proceed with this line!\nDid you mean to run this add.qcurve() call?\n")
    response <- readline(); response <- toupper(response)
    if (response == "Y") {
      cat(paste0("Proceeding with this run of add.qcurves()!.\n"))
      break  # Exit the repeat loop and continue the function
    } else {
      cat("User did not confirm intention to overwrite qcurves. Exiting function...\n")
      return()
    }
  }
  
  setwd(wd$path[wd$wd=="sites"])
  qcurves <- read.csv("qcurves.csv")
  # Remove the site's old qcurve
  qcurves <- qcurves[qcurves$site != sitename,]
  new.qcurve$site <- sitename
  new.qcurve <- new.qcurve[,c("site","timestamp","level","q")]
  qcurves <- rbind(qcurves, new.qcurve)
  qcurves <- qcurves[order(qcurves$site, qcurves$timestamp),]
  rownames(qcurves) <- NULL
  meta <- read.csv("qcurves_meta.csv")
  newnum <- max(meta$num) + 1
  qcurve.name <- paste0("qcurves", newnum)
  meta[newnum,] <- NA
  meta$num[newnum] <- newnum
  meta$name[newnum] <- qcurve.name
  meta$note[newnum] <- reason
  qcurve.csvname <- paste0("qcurves", newnum, ".csv")
  write.csv(qcurves, qcurve.csvname, row.names = FALSE)
  write.csv(qcurves, "qcurves.csv", row.names = FALSE)
  write.csv(meta, "qcurves_meta.csv", row.names = FALSE)
}
# the qflux function is be used to take the df of qcurves.csv, 
#$level from a df.h dataframe (consisting of $site, $timestamp, and $level)
qflux <- function(wd, df.h, sitename){
  site <- sitename
  setwd(wd$path[wd$wd=="sites"])
  df <- read.csv("qcurves.csv")
  df.h$q <- NA
  # subset by site given
  df <- df[df$site == site,]
  rownames(df) <- NULL
  for (i in 1:nrow(df.h)){
    df.h$q[i] <- approx(df$level, df$q, xout = df.h$level[i])$y
  }
  # Deal with zero levels, the above leaves it as NA
  for (i in 1:nrow(df.h)){
    if (df.h$level[i] < min(df$level)){
      df.h$q[i] <- 0
    }
  }
  return(df.h)
}

######################            VWC FUNTIONS            ######################
# VWC FUNCTIONS
vwc.import <- function(df){
  df <- df[c(3:nrow(df)),]
  colnames(df) <- c("date", "cm10", "cm30", "cm50", "cm100")
  df$date <-as.character(df$date)
  if (any(grepl("PM", df$date))){
    df$date <- as.POSIXct(df$date, format = "%m/%d/%Y %I:%M:%S %p", tz = "America/Port_of_Spain")
  } else {
    df$date <- as.POSIXct(df$date, format = "%m/%d/%Y %H:%M", tz = "America/Port_of_Spain")
  }
  df$timestamp <- as.numeric(df$date)
  df <- df[,c("date", "timestamp", "cm10", "cm30", "cm50", "cm100")]
  df$cm10 <- as.numeric(df$cm10)
  df$cm30 <- as.numeric(df$cm30)
  df$cm50 <- as.numeric(df$cm50)
  df$cm100 <- as.numeric(df$cm100)
  rownames(df) <- NULL
  return(df)
}
vwc.qaqc <- function(wd, vwc){
  # Auto-detect the presence of types and create subsets
  types <- unique(vwc$type)
  dfs <- NA
  result <- vwc[0,]
  for (i in 1:length(types)){
    # Provide the name of the df e.g. vwc.sb
    df.name <- paste0("vwc.",types[i])
    subset <- vwc[vwc$type == types[i],]
    # We will rename the variable columns for more descriptive storage in splices
    suffix <- paste0(".", types[i])
    renaming.cols <- c("cm10", "cm30", "cm50", "cm100")
    names(subset)[names(subset) %in% renaming.cols] <- paste0(renaming.cols, suffix)
    # Remove the type column before moving on
    subset$type <- NULL
    assign(df.name, subset)
    dfs[i] <- df.name
    print(paste0("NOW CHECKING: ", dfs[i]))
    new.df <- auto.qaqc(wd, get(dfs[i]))
    new.df$type <- types[i]
    # Now remove the vwctype from colnames
    # Identify columns that have the suffix
    renaming.cols <- names(new.df)[grepl(paste0(suffix, "$"), names(new.df))]
    # Remove the suffix from those columns
    names(new.df)[names(new.df) %in% renaming.cols] <- sub(paste0(suffix, "$"), "", renaming.cols)
    result <- rbind(result, new.df)
  }
  return(result)
}
# This function receives a vwc file, possibly of more than one type, and finds
# all its remaining gaps in the record - if rainfall above the threshold in mm
# was observed from the weather record during that gap, the gap is left, 
# but if not, simple interpolation occurs. 
vwc.rain.fill <- function(wd, vwc, sitename, threshold){
  # Auto-detect the presence of types and create subsets
  types <- unique(vwc$type)
  dfs <- NA
  result <- vwc[0,]
  for (i in 1:length(types)){
    df.name <- paste0("vwc.",types[i])
    subset <- vwc[vwc$type == types[i],]
    # Rename columns much as in vwc.qaqc
    suffix <- paste0(".", types[i])
    renaming.cols <- c("cm10", "cm30", "cm50", "cm100")
    names(subset)[names(subset) %in% renaming.cols] <- paste0(renaming.cols, suffix)
    # Fix up the columns and df.name
    subset$type <- NULL
    assign(df.name, subset)
    dfs[i] <- df.name
    print(paste0("NOW CHECKING: ", dfs[i]))
    
    new.df <- vwc.rain.fill.inner(wd, subset, sitename, threshold)
    new.df$type <- types[i]
    # Now remove the vwctype from colnames
    # Identify columns that have the suffix
    renaming.cols <- names(new.df)[grepl(paste0(suffix, "$"), names(new.df))]
    # Remove the suffix from those columns
    names(new.df)[names(new.df) %in% renaming.cols] <- sub(paste0(suffix, "$"), "", renaming.cols)
    result <- rbind(result, new.df)
  }
  return(result)
}
# Inside the larger wrapper function - very similar to fillgaps()
vwc.rain.fill.inner <- function(wd, df, sitename, threshold){
  allgaps <- allgaps2(df, 15)
  if(nrow(allgaps) == 0){
    stop("Congratulations, there are no gaps to fill!")
  }
  # Now we will need to use this reference to check whether the gap had rainfall
  allgaps$approx <- rep(NA, nrow(allgaps))
  setwd(wd$path[wd$wd=="archive"])
  filename <- paste0(sitename, ".weather.rda")
  load(filename)
  df.name <- paste0(sitename, ".weather")
  weather <- get(df.name)
  # Here we are seeing whether more than the threshold of rain fell in total during the gap
  for (i in 1:nrow(allgaps)){
    if (sum(weather$precip[weather$date >= allgaps$start[i] & weather$date <= allgaps$end[i]]) > threshold){
      allgaps$approx[i] <- FALSE
    } else{
      allgaps$approx[i] <- TRUE
    }
  }
  # Bring in splices record to notate all filled gaps
  setwd(wd$path[wd$wd=="archive"]); splices0 <- read.csv("splices.csv")
  splices0$start <- as.POSIXct(splices0$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  splices0$end <- as.POSIXct(splices0$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  # Create the splices table that we will fill and add to the master metadata of QA/QC operations
  splices <- data.frame(unique = rep(NA, nrow(allgaps)), site = rep(sitename, nrow(allgaps)), start = allgaps$start, end = allgaps$end,
                        var = allgaps$varname, type = rep("gap", nrow(allgaps)), method = rep(NA, nrow(allgaps)), 
                        check.num = rep(NA, nrow(allgaps)))
  splices$start <- as.POSIXct(splices$start, origin = "1970-01-01", tz = "America/Port_of_Spain")
  splices$end <- as.POSIXct(splices$end, origin = "1970-01-01", tz = "America/Port_of_Spain")
  splices$approx <- allgaps$approx
  # For all TRUE gaps, we can just do linear interpolation, but we need to get 
  # the right positions filled
  for (i in 1:nrow(allgaps)){
    if (allgaps$approx[i] == TRUE){
      #build a vector from df of the values needed here
      start <- which(df$date == allgaps$start[i]-900)
      end <- which(df$date == allgaps$end[i]+900)
      needs.interp <- df[[allgaps$varname[i]]][start:end]
      interped <- na.approx(needs.interp, rule = 2)
      df[[allgaps$varname[i]]][start:end] <- interped
      splices$method[i] <- "interp.linear"
    } else {
      # When gap filling is not happening, in VWC these will stay as gaps
      splices$method[i] <- "stays.gap"
    }
  }
  # Find gaps a second time, use allgaps2 function and assume 15 minute interval
  allgaps2(df, 15)
  
  splices$approx <- NULL
  splices$key <- NA
  # Annoyingly it is necessary to fix a midnight formatting issue here
  for (i in 1:nrow(splices)){
    if (format(splices$start[i], format = "%H:%M:%S") == "00:00:00" & format(splices$end[i], format = "%H:%M:%S") == "00:00:00"){
      splices$key[i] <- paste(splices$site[i], paste0(splices$start[i], " 00:00:00"), paste0(splices$end[i], " 00:00:00"), splices$var[i], sep = "_")
    } else if (format(splices$end[i], format = "%H:%M:%S") == "00:00:00"){
      splices$key[i] <- paste(splices$site[i], splices$start[i], paste0(splices$end[i], " 00:00:00"), splices$var[i], sep = "_")
    } else if (format(splices$start[i], format = "%H:%M:%S") == "00:00:00") {
      splices$key[i] <- paste(splices$site[i], paste0(splices$start[i], " 00:00:00"), paste0(splices$end[i], " 00:00:00"), splices$var[i], sep = "_")
    } else {
      splices$key[i] <- paste(splices$site[i], splices$start[i], splices$end[i], splices$var[i], sep = "_")
    }
  }
  # In this function, we expect that the gaps have already been identified and added to splices and are waiting 
  # to have their "method" filled in here, so we must locate those key matches in splices0 that have "NA" for method
  for (i in 1:nrow(splices)){
    if (splices$key[i] %in% splices0$key) {
      index <- which(splices0$key == splices$key[i])
      # Begin by checking that method was written as "NA"
      if (is.na(splices0$method[index])){
        # Now we can write into this method
        splices0$method[index] <- splices$method[i]
      } else {
        # If NA is not the method, this indicates an overwrite or something else being wrong
        stop(paste0("ERROR: The gap from ", splices$start[i], " to ", splices$end[i], " already has a gap-filling method listed.",
                    "\nThis should not occur, and indicates something has gone wrong between the call of vwc.qaqc() and this function call!"))
      }
    } else {
      # This should not happen, if it does, the gap was somehow introduced between the run of vwc.qaqc() and this
      stop(paste0("ERROR: The gap from ", splices$start[i], " to ", splices$end[i], " has no match in the existing Splices record",
                  "\nThis should not occur, and indicates something has gone wrong between the call of vwc.qaqc() and this function call!"))
    }
  }
  
  # Write new splices if everything went well
  write.csv(splices0, "splices.csv", row.names = FALSE)
  return(df)
}

######################          NASA GPM IMGERG           ######################
# Functions designed to query NASA GPM IMERG precip data estimates using Python
nasa.rain <- function(wd, lat, lon, start, end, user, pass, timezone){
  # Convert to UTC to match the NASA datasets
  start <- as.POSIXct(format(start, tz = "UTC", usetz = TRUE), tz = "UTC")
  end <- as.POSIXct(format(end, tz = "UTC", usetz = TRUE), tz = "UTC")
  # Round to nearest half hour
  start <- round.halfhour(start, "start")
  start.date <- start
  end <- round.halfhour(end, "end")
  duration <- as.numeric(end) - as.numeric(start) 
  # We now have the start and end times in string form, but it's entirely possible
  # we need a large number of images - we must work out how many we need now
  steps <- duration / (30*60)
  # A reference dataframe to use to query each file and store results
  df <- data.frame(step = c(1:steps), datestring = rep(NA, steps), startstring = rep(NA, steps), endstring = rep(NA, steps), minutestamp = rep(NA, steps), year = rep(NA, steps), julian = rep(NA, steps),
                   file.name = rep(NA, steps), file.name.late = rep(NA, steps), date = rep(NA, steps), precip.mmh = rep(NA, steps))
  # Now we must construct the filename and so on for each of the steps
  for (i in 1:steps){
    df$startstring[i] <- as.numeric(start) + ((i*1800)-1800) 
    df$endstring[i] <- df$startstring[i] + 1799
    df$datestring[i] <- format(as.Date(as.POSIXct(df$startstring[i], tz = "UTC", origin = "1970-01-01")), format = "%Y%m%d")
    df$minutestamp[i] <- (df$startstring[i] - as.numeric(as.Date(as.POSIXct(df$startstring[i], tz = "UTC", origin = "1970-01-01"))) * 24 * 60 * 60) / 60
    df$year[i] <- substr(df$datestring[i], start = 1, stop = 4)
    df$julian[i] <- format(as.Date(as.POSIXct(df$startstring[i], tz = "UTC", origin = "1970-01-01")), "%j")
    df$date[i] <- format(as.POSIXct((df$endstring[i]+1), origin = "1970-01-01", tz = timezone), format = "%Y-%m-%d %H:%M:%S")
  }
  df$startstring <- format(as.POSIXct(df$startstring, origin = "1970-01-01", tz = "UTC"), format = "%H%M%S")
  df$endstring <- format(as.POSIXct(df$endstring, origin = "1970-01-01", tz = "UTC"), format = "%H%M%S")
  df$minutestamp <- sprintf("%04d", df$minutestamp)
  df$julian <- sprintf("%03d", as.numeric(df$julian))
  # Construct file name from NASA convention
  imerg.final <- "3B-HHR.MS.MRG.3IMERG."; filesuffix.f <- ".V07B.HDF5"; imerg.late <- "3B-HHR-L.MS.MRG.3IMERG."; filesuffix.l <- ".V07B.HDF5"
  df$file.name <- paste0(imerg.final, df$datestring, "-S", df$startstring, "-E", df$endstring, ".", df$minutestamp, filesuffix.f)
  df$file.name.late <- paste0(imerg.late, df$datestring, "-S", df$startstring, "-E", df$endstring, ".", df$minutestamp, filesuffix.l)
  
  # Now we take this reference df and use it to do downloads and precip reads
  for (i in 1:nrow(df)){
    df$precip.mmh[i] <- gpm.query(wd, df$year[i], df$julian[i], df$file.name[i], df$file.name.late[i], user, pass, lat, lon, "final")
  }
  # If this entirely fails, i.e. no results returned, try with the late run data
  #if (all(is.na(df$precop.mmh))){
  #  for (i in 1:nrow(df)){
  #    df$precip.mmh[i] <- gpm.query(wd, df$year[i], df$julian[i], df$file.name[i], df$file.name.late[i], user, pass, lat, lon, "late")
  #  }
  #}
  df$precip <- df$precip.mmh / 2 # converts to mm accumulation for comparison with other data
  df <- df[,c("date", "precip")]
  return(df)
}
gpm.query <- function(wd, year, julian, file.name, file.name.late, user, pass, lat, lon, type){
  # Construct URL
  if (type == "final"){
    nasa.prefix <- "https://gpm1.gesdisc.eosdis.nasa.gov/data/GPM_L3/GPM_3IMERGHH.07/"
  } else if (type == "late"){
    nasa.prefix <- "https://gpm1.gesdisc.eosdis.nasa.gov/data/GPM_L3/GPM_3IMERGHHL.07/"
    file.name <- file.name.late
  } else {
    stop("ERROR: supply only type 'final' or 'late'")
  }
  url <- paste0(nasa.prefix, year, "/", julian, "/", file.name)
  file.path <- paste0(wd$path[wd$wd=="nasa"], "/", file.name)
  # Perform the download into our directory with all the information
  download.gpm.file(wd, url, file.path, user, pass)
  # And query at our coordinates for the precip at this timestep
  precip.mmh <- extract.point.precip(wd, file.path, lat, lon)
  # Delete the raw file for cleanliness
  file.remove(file.path)
  if (is.na(precip.mmh) || precip.mmh == 9999.99){
    precip.mmh <- NA
  }
  return(precip.mmh)
}
download.gpm.file <- function(wd, url, file.path, username, password) {
  # Ensure the Python executable path is correctly set
  python.executable <- "python"
  script.path <- paste0(wd$path[wd$wd=="nasa"], "/download_precip.py")
  # Construct the command to run the Python script with arguments
  command <- sprintf('"%s" "%s" "%s" "%s" "%s" "%s"', 
                     python.executable, 
                     script.path, 
                     url, 
                     file.path, 
                     username, 
                     password)
  # Execute the command
  system(command)
}
extract.point.precip <- function(wd, file.path, lat, lon) {
  # Define the path to the Python script
  script.path <- paste0(wd$path[wd$wd=="nasa"], "/extract_precip.py")
  # Construct the command to run the Python script
  cmd <- sprintf("python \"%s\" \"%s\" %.4f %.4f", script.path, file.path, lat, lon)
  # Run the Python script and capture the output
  output <- system(cmd, intern = TRUE)
  # Return the output as numeric or NA
  precip.value <- as.numeric(output)
  return(precip.value)
}
# Serves to round the start time down 15 minutes if on 15 or 45, and round up end
round.halfhour <- function(datetime, type){
  if ((as.numeric(datetime) / (60*60))*2 != floor(2*(as.numeric(datetime) / (60*60)))){
    if (type == "start"){
      new.date <- as.numeric(datetime) - 900
      new.date <- as.POSIXct(new.date, tz = "UTC", origin = "1970-01-01")
    } else if (type == "end"){
      new.date <- as.numeric(datetime) + 900
      new.date <- as.POSIXct(new.date, tz = "UTC", origin = "1970-01-01")
    } else {
      stop("ERROR: supply type either 'start' or 'end'")
    } 
    datetime <- new.date
  }
  return(datetime)
}

######################               DAYMET               ######################
# Below are the Daymet functions
# The first two simply redownload the entire archive at some given coordinates and variables
# This carries the temporary name of file1.csv
daymet.download <- function(wd, vars, lat, lon){
  setwd(wd$path[wd$wd=="daymet"])
  # Make the vars alphabetically if they didn't come in that way
  vars <- sort(vars)
  legit.vars <- c("dayl", "prcp", "srad", "swe", "tmax", "tmin", "vp")
  if (any(!vars %in% legit.vars)){
    stop("ERROR: One or more of your variables is not a valid variable: dayl, prcp, srad, swe, tmax, tmin, or vp")
  }
  # Run the download function
  df <- daymet.download.inner(wd, vars, lat, lon)
  # Subset to the years we need
  #df <- df[df$year >= start & df$year <= end,]
  # Better column names for the variables we got
  for (i in 1:length(vars)){
    var <- vars[i]
    df[[var]] <- df[ ,grep(var, names(df), value = TRUE)]
  }
  # Rename yday to julian day
  df$julian <- df$yday
  cols <- c("year", "julian", vars)
  df <- df[, cols]
  return(df)
}
daymet.download.inner <- function(wd, vars, lat, lon) {
  setwd(wd$path[wd$wd=="daymet"])
  # Define the path to the latlon.txt file
  file_path <- "latlon.txt"
  vars <- paste(vars, collapse = ", ")
  coords <- paste0("file1.csv, ", lat, ", ", lon)
  # Open the file for writing
  fileConn <- file(file_path, open = "w")
  # Write the variables and years to the file
  writeLines(sprintf("Variables: %s", vars), fileConn)
  writeLines("years: ", fileConn)
  writeLines(coords, fileConn)  # Write lat/lon
  # Close the file connection
  close(fileConn)
  # Prepare the command to run the Python script
  command <- "python daymet_multiple_extraction.py latlon.txt"
  # Run the Python script
  system(command, intern = TRUE)
  # Skip the first N rows and then read the data due to special characters
  df <- read.csv("file1.csv", skip = 6)
  return(df)
}
# The following is a wrapper function that ASSUMES PRECIPITATION ONLY is of interest
# It receives a start and end date with lat lon and returns a simple df of these from dayment
daymet.rain <- function(wd, start, end, lat, lon){
  setwd(wd$path[wd$wd=="daymet"])
  df <- daymet.download(wd, "prcp", lat, lon)
  df$date <- paste(df$year, df$julian)
  df$date <- as.Date(df$date, format = "%Y %j"); df$year <- NULL; df$julian <- NULL
  df <- df[df$date >= start & df$date <= end,]
  rownames(df) <- NULL
  return(df)
}

######################         RAWS WEATHER NETWORK       ######################
# RAWS functions
import.raws.raw <- function(wd, site, start, end){
  setwd(wd$path[wd$wd=="raws"])
  filename <- paste0("RAWS_", site, "_", start, "-", end, ".txt")
  filepath <- paste0(wd$path[wd$wd=="raws"], "/", filename)
  lines <- suppressWarnings(readLines(filepath))
  # First 6 and last 2 lines are header and footer 
  lines <- lines[7:length(lines)]
  lines <- lines[1:(length(lines)-2)]
  # Date is the first 12 chars, precip is the last 7
  dates <- substr(lines, 1, 12)
  precips <- substr(lines, nchar(lines)-7, nchar(lines))
  for (i in 1:length(lines)){
    dates[i] <- no.spaces(dates[i])
    precips[i] <- no.spaces(precips[i])
  }
  df <- data.frame(date = dates, precip = precips)
  df$date <- as.Date(df$date, format = "%m/%d/%Y")
  # Deal with missing precip, denoted by "M"
  df$precip[which(df$precip == "M" | df$precip == "m")] <- NA
  df$precip <- as.numeric(df$precip)
  df$site <- site
  df <- df[,c("site", "date", "precip")]
  # Deal with NAs and errors
  df$skip <- rep(0, nrow(df))
  for (i in 2:nrow(df)){
    df$skip[i] <- df$date[i] - df$date[i-1]
  }
  df$skip[1] <- 1
  if (any(df$skip > 3 | df$skip < 1)){
    stop(paste0("WARNING: a gap longer than 3 days exists in this data, or replication occurs at: ", which(df$skip > 3), ". Stop and investigate!"))
  }
  if (any(df$skip != 1)){
    cat("WARNING: gaps or unevenness occurs of 3 days or less, these will be filled by NA\n")
    start0 <- df$date[1]; end0 <- df$date[nrow(df)]
    complete.dates <- as.Date(c(start0:end0))
    df2 <- data.frame(date = complete.dates)
    df <- merge(df2, df, by = "date", all.x = TRUE)
    df$site <- NULL; df$site <- site; df <- df[,c("site", "date", "precip", "skip")]
  } else {
    cat("No apparent skips in the incoming dataset, congratulations!\n")
  }
  # Deal now with any disagreement between filename and actual record
  start.date <- as.Date(start, format = "%Y%m%d")
  end.date <- as.Date(end, format = "%Y%m%d")
  # This checks to make sure the filename start and end match the actual dataset
  if (df$date[nrow(df)] != end.date | df$date[1] != start.date){
    if (df$date[1] != start.date){
      cat("WARNING: filename start is not identical with first date in this data!\n")
      if (df$date[1] < start.date){
        cat("Data begins before filename start - data will be trimmed to filename start!\n")
        df <- df[df$date >= start.date,]
      } else {
        stop("Data begins after filename start - rename file or check data download!")
      }
    } else {
      cat("WARNING: filename end is not identical with final date in this data!\n")
      if (df$date[nrow(df)] < end.date){
        cat("WARNING: filename end is later than actual end of data, NAs will be added!\n")
        cat("STRONGLY RECOMMEND re-checking data download to ensure there is no data to present day\n")
        df0 <- df[0,]
        diff <- as.numeric(end.date - df$date[nrow(df)])
        df0[1:diff,] <- NA
        df0$site <- site
        df0$date <- as.Date(c((df$date[nrow(df)]+1):end.date))
        df <- rbind(df, df0)
      } else {
        cat("WARNING: end of data is later than filename end, data will be trimmed! Check filename.\n")
        df <- df[df$date <= end.date,]
      }
    }
  }
  df$skip <- NULL
  ########################
  # Bring in raws archive and paste this in - with preference to the new data
  raws <- read.csv("raws.csv")
  raws$date <- as.Date(raws$date)
  # By site
  subset <- raws[raws$site == site,]
  raws <- raws[raws$site != site,]
  # Remove those rows in df which have a match in the site subset
  length1 <- nrow(subset)
  subset <- subset[!(subset$date %in% df$date), ]
  length2 <- nrow(subset)
  if (length2 < length1){
    cat("WARNING: Some data has been trimmed from the archive because those dates were already present in new data!\n")
  }
  # That done, check to see if the final row of the archive is one day before the first row of the new data
  if (subset$date[nrow(subset)] != (df$date[1]-1)){
    cat("WARNING: end of archive and beginning of data do not match without gaps")
    if (subset$date[nrow(subset)] > df$date[1]){
      stop("ERROR: Final date in the archive is later than the first date in the data. Check the download and re-try.")
    } else if (subset$date[nrow(subset)] < df$date[1]){
      cat("WARNING: Adding NAs into the gap between archive and new data!\n")
      diff <- as.numeric(df$date[1] - subset$date[nrow(subset)]) - 1
      df0 <- df[0,]
      df0[1:diff,] <- NA
      df0$site <- site
      df0$date <- as.Date(c((subset$date[nrow(subset)]+1):(df$date[1]-1)))
      df <- rbind(subset, df0, df)
    }
  } else {
    cat("Final date of archive is now one day before first date of new data. Attaching for new archive!\n")
    df <- rbind(subset, df)
  }
  # Now re-attach the sites
  raws <- rbind(raws, df)
  # Order by site then date
  raws <- raws[order(raws$site, raws$date), ]
  rownames(raws) <- NULL
  return(raws)
}
# This function takes a string, reads it character by character, and passes it back
# with all spaces removed, and as a number rather than a string
no.spaces <- function(string){
  string1 <- ""
  for (i in 1:nchar(string)){
    if (substr(string, i, i) != " "){
      string1 <- paste0(string1, substr(string, i, i))
    } else {
      # no action, space is dropped from new string1
    }
  }
  return(string1)
}
raws.join <- function(wd, archive){
  setwd(wd$path[wd$wd=="raws"])
  raws <- read.csv("raws.csv")
  raws$station <- raws$site; raws$site <- NULL
  raws$date <- as.Date(raws$date)
  raws$name <- NA; raws$type <- "RAWS"; raws$lat <- NA; raws$lon <- NA; raws$elev <- NA; raws$qual <- NA
  raws <- raws[,c("date", "station", "name", "type", "lat", "lon", "elev", "precip", "qual")]
  meta <- read.csv("raws_meta.csv"); meta$station <- meta$raws.station
  for (i in 1:nrow(raws)){
    station <- raws$station[i]
    name <- meta$raws.station[which(meta$shortname == station)]
    raws$name[i] <- name
    lat <- meta$lat[which(meta$shortname == station)]
    lon <- meta$lon[which(meta$shortname == station)]
    raws$lat[i] <- lat; raws$lon[i] <- lon
    elev <- meta$elev[which(meta$shortname == station)]
    raws$elev[i] <- elev
  }
  # Check for skips and splice NAs in, mark skip as a qualflag
  stations <- unique(raws$station)
  for (i in 1:length(stations)){
    df <- raws[raws$station == stations[i],]
    raws <- raws[raws$station != stations[i],]
    # Make a new date series from start to finish 
    min.date <- min(df$date); max.date <- max(df$date)
    df.full <- data.frame(date = seq.Date(from = min.date, to = max.date, by = "day"))
    df$blank <- FALSE # And mark the original observations 
    # Join together to fill the gaps and proceed to write down all fillable info
    df <- merge(df.full, df, by = "date", all.x = TRUE)
    df$blank[is.na(df$blank)] <- TRUE
    df$station <- df$station[1]; df$name <- df$name[1]; df$type <- df$type[1]; df$lat <- df$lat[1]; df$lon <- df$lon[1]; df$elev <- df$elev[1]
    df$qual[df$blank == TRUE] <- "skip"; df$blank <- NULL; rownames(df) <- NULL
    raws <- rbind(df, raws)
    raws <- raws[order(raws$station, raws$date), ]
    rownames(raws) <- NULL
  }
  # Attach this to the archive
  archive <- rbind(raws, archive)
  # Re-sort by date*station
  archive <- archive[order(archive$station, archive$date), ]
  rownames(archive) <- NULL
  cat("Everything looks good to save this full VI rain gauge archive!")
  return(archive)
}

######################    GHCN DAILY RAIN GAUGE DATA      ######################
# GHCN importation and archiving functions
# Extracts metadata information of NOAA GHCN weather records for the Virgin Islands
download.extract.new.ghcn <- function(wd, meta.url, gz){
  setwd(wd$path[wd$wd=="noaa"])
  # Get the old number of stations in case there are new ones online
  if (file.exists("ghcn_meta.csv")){
    num <- read.csv("ghcn_meta.csv")
    num.stations <- as.numeric(nrow(num))
  } else{
    num.stations <- 0
  }
  # Download the full GHCN station metadata
  txt <- readLines(meta.url)
  vi.txt <- txt[grepl("^VQ", txt)] # Subset to VI stations only
  meta.path <- paste0(wd$path[wd$wd=="noaa"], "/GHCN_VI_stations.txt")
  writeLines(vi.txt, con = meta.path) # Save the result as a .txt
  stations <- substr(vi.txt, 1, 11) # Acquire list of station names
  # Write CSV metadata for future reference
  meta <- data.frame(station = rep(NA, length(stations)), name = rep(NA, length(stations)), lat = rep(NA, length(stations)), lon = rep(NA, length(stations)), elev = rep(NA, length(stations)), type = rep(NA, length(stations)), defunct = rep(NA, length(stations)))
  # Iterate through all stations and extract station metadata
  for (i in 1:length(stations)){
    station <- stations[i]
    csvname <- paste0(station, ".csv")
    df <- read.csv(csvname)
    df$station <- df$STATION; df$name <- df$NAME; df$lat <- df$LATITUDE; df$lon <- df$LONGITUDE; df$elev <- df$ELEVATION; df$date <- df$DATE; df$attr <- df$PRCP_ATTRIBUTES
    df <- df[,c("station", "name", "lat", "lon", "elev", "date", "attr")]
    meta$station[i] <- df$station[1]
    meta$name[i] <- df$name[1]
    meta$lat[i] <- df$lat[1]
    meta$lon[i] <- df$lon[1]
    meta$elev[i] <- df$elev[1]
    # Extract the type by using sapply() to pull out the third item after the second comma
    source.type <- sapply(strsplit(df$attr, ","), function(x) x[3])
    # Identify the most common source type
    common.type <- names(which.max(table(source.type)))
    type.freq <- max(table(source.type))
    type.percentage <- type.freq / nrow(df)
    if (type.percentage < 0.5){
      meta$type[i] <- "Mixed"
      cat(paste0("Station ", meta$name[i], " is mixed-source - normally government-classified\n"))
    } else {
      meta$type[i] <- common.type
    }
    # Identify whether the station is defunct by whether any data in the last ten years
    df$date <- as.Date(df$date)
    age <- as.numeric(Sys.Date()) - as.numeric(df$date[nrow(df)])
    if (age > (365*10)){
      meta$defunct[i] <- TRUE
    } else {
      meta$defunct[i] <- FALSE
    }
    # Provide the start and end of the record
    meta$start[i] <- df$date[1]; meta$end[i] <- df$date[nrow(df)]
    # Parse the type to something meaningful
    if (meta$type[i] == "0" | meta$type[i] == "6" | meta$type[i] == "7"){
      meta$type[i] <- "Govt"
    } else if (meta$type[i] == "N"){
      meta$type[i] <- "CoCoRaHs"
    } else if (meta$type[i] == "Mixed"){
      meta$type[i] <- "Govt"
    } else {
      meta$type[i] <- "Unrecognized"
    }
  }
  meta <- meta[,c("station", "name", "type", "lat", "lon", "elev", "start", "end", "defunct")]
  meta$station <- as.character(meta$station); meta$name <- as.character(meta$name); meta$type <- as.character(meta$type); meta$lat <- as.numeric(meta$lat); meta$lon <- as.numeric(meta$lon); meta$elev <- as.numeric(meta$elev); meta$start <- as.Date(meta$start); meta$end <- as.Date(meta$end); meta$defunct <- as.logical(meta$defunct)
  if (nrow(meta) > num.stations){
    cat("NOTICE: There appear to more available VI stations for download since the last update!\n")
  } else if (nrow(meta) < num.stations){
    stop("ERROR: Something may be wrong! There are fewer stations for download than last update. Stopping function to avoid ovewrite.")
  }
  write.csv(meta, "ghcn_meta.csv", row.names = FALSE)
  
  # Now download new archive and extract, if asked
  if (gz == TRUE){
    gz.url <- "https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/archive/daily-summaries-latest.tar.gz"
    download.file(gz.url, destfile = "daily-summaries-latest.tar.gz", method = "auto")
    # Untar the new tar.gz
    filenames <- paste0(stations, ".csv")
    tarpath <- paste0(wd$path[wd$wd=="noaa"], "/daily-summaries-latest.tar.gz")
    untar(tarpath, files = filenames, exdir = wd$path[wd$wd=="noaa"])
  } else {
    # Stop here
  }
}
# This takes a station ID and performs a basic import of the data
ghcn.import.simple <- function(wd, station){
  setwd(wd$path[wd$wd=="noaa"])
  csvname <- paste0(station, ".csv")
  df <- read.csv(csvname)
  df$station <- df$STATION; df$name <- df$NAME; df$lat <- df$LATITUDE; df$lon <- df$LONGITUDE; df$elev <- df$ELEVATION; df$date <- df$DATE; df$precip <- df$PRCP; df$attr <- df$PRCP_ATTRIBUTES
  meta <- read.csv("ghcn_meta.csv"); station <- df$station[1]; type <- meta$type[meta$station == station]; df$type <- type
  df <- df[,c("station", "name", "type", "lat", "lon", "elev", "date", "precip", "attr")]
  df$meas <- sapply(strsplit(df$attr, ","), function(x) x[1])
  df$qual <- sapply(strsplit(df$attr, ","), function(x) x[2])
  # Deal with any NAs in the flags
  df$qual[which(is.na(df$qual))] <- ""; df$meas[which(is.na(df$meas))] <- ""
  # Trace flags to zero, missing-presumed-zero to zero, "accumulation" to NA
  for (i in 1:nrow(df)){
    if (df$meas[i] == "T"){
      df$precip[i] <- 0
    }
    if (df$meas[i] == "P"){
      df$precip[i] <- 0
    }
    if (df$meas[i] == "A"){
      # If the measurement flag "A" is present, it represents accumulation
      # and for most of our purposes this is not good enough - so it will be missing
      if (is.na(df$precip[i-1])){
        df$precip[i] <- NA
      } else {
        # If for some reason the previus record is not actually NA, keep the "A" measurement anyway
      }
    }
  }
  # Report any quality flags for follow-up
  if (any(df$qual != "")){
    flags <- unique(df$qual)
    for (i in 1:length(flags)){
      if (flags[i] == ""){
        flags2 <- flags[-i]
      }
    }
    flags <- flags2
    df$quality.issues <- TRUE
    df$qual[df$qual == ""] <- NA
  } else {
    df$qual <- NA
    df$quality.issues <- FALSE
  }
  # Convert precip to mm
  df$precip <- df$precip / 10
  df$attr <- NULL; df$meas <- NULL
  df$date <- as.Date(df$date)
  df$qual <- as.character(df$qual)
  return(df)
}
# Use this for a non-QC'd full import of the entire archive extracted from the tar.gz
ghcn.import.all <- function(wd){
  setwd(wd$path[wd$wd=="noaa"])
  stations <- read.csv("ghcn_meta.csv")
  for (i in 1:nrow(stations)){
    station <- stations$station[i]
    df <- ghcn.import.simple(wd, station)
    # Make a new date series from start to finish 
    min.date <- min(df$date); max.date <- max(df$date)
    df.full <- data.frame(date = seq.Date(from = min.date, to = max.date, by = "day"))
    df$blank <- FALSE # And mark the original observations 
    # Join together to fill the gaps and proceed to write down all fillable info
    df <- merge(df.full, df, by = "date", all.x = TRUE)
    df$blank[is.na(df$blank)] <- TRUE
    df$station <- df$station[1]; df$name <- df$name[1]; df$type <- df$type[1]; df$lat <- df$lat[1]; df$lon <- df$lon[1]; df$elev <- df$elev[1]; df$quality.issues <- df$quality.issues[1]
    df$qual[df$blank == TRUE] <- "skip"; df$blank <- NULL; rownames(df) <- NULL
    if (i == 1){
      # If this is the first run, do not attach to anything, and just rename
      archive <- df
    } else{
      # But if we already have some data, rbind()
      archive <- rbind(archive, df); rownames(archive) <- NULL
    }
  }
  return(archive)
}
# This function deals with quality flags that appear. 
# Any new quality flags may need to be dealt with differently but for now it makes all these NA
ghcn.import.qualflag<- function(archive0){
  # Deal with each quality flag in turn: G, L, O, S, Z are all probably best handled as NA
  flags <- c("G", "L", "O", "S", "Z")
  for (i in 1:length(which(archive0$qual %in% flags))){
    archive0$precip[which(archive0$qual %in% flags)[i]] <- NA
  }
  archive <- archive0
  archive$quality.issues <- NULL
  rownames(archive) <- NULL
  return(archive)
}
# Uses Open-Elevation API to grab the elevation of a given lat/lon coordinate in meters
get.elev <- function(lat, lon){
  url <- sprintf("https://api.open-elevation.com/api/v1/lookup?locations=%f,%f", lat, lon)
  response <- readLines(url, warn=FALSE)
  # Parse the elevation from the raw text
  elevation_line <- grep("elevation", response, value = TRUE)
  # Extract the numeric elevation value using regular expressions
  elevation <- as.numeric(sub(".*\"elevation\":([0-9\\-]+).*", "\\1", elevation_line))
  return(elevation)
}
# Imports raw cocorahs csv and joins without gaps to archive, writes new CSV if passes error check
# Largely replaces the functionality of import.coco.raw() and raw.coco.check()
import.coco.raw.full <- function(wd){
  setwd(wd$path[wd$wd=="weather"])
  # Find the final entry date in the archive
  coco <- read.csv("cocorahs.csv"); start <- coco$ObservationDate[1]
  start <- as.Date(start) # Convert to date for start of new download
  end <- Sys.Date() # Today's date for end of new download
  # Convert these dates to strings for the URL
  start <- format(start, "%m/%d/%Y"); end <- format(end, "%m/%d/%Y")
  url <- paste0("https://data.cocorahs.org/export/exportreports.aspx?ReportType=Daily&dtf=1&Format=CSV&State=VI&ReportDateType=reportdate&StartDate=", start, "&EndDate=", end, "&TimesInGMT=False")
  start <- format(as.Date(start, format = "%m/%d/%Y"), "%Y%m%d")
  end <- format(as.Date(end, format = "%m/%d/%Y"), "%Y%m%d")
  csvname <- paste0("cocorahs_", start, "-", end, ".csv")
  # Download fresh data
  download.file(url, destfile = csvname, method = "auto")
  
  # Import the new cocorahs and the archived one
  df0 <- read.csv("cocorahs.csv")
  df1 <- read.csv(csvname)
  # Ensure the $ObservationDate is identical formatting in both by reading as.Date
  df0$ObservationDate <- as.Date(df0$ObservationDate, tryFormats = c("%Y-%m-%d", "%m/%d/%Y"))
  df1$ObservationDate <- as.Date(df1$ObservationDate, tryFormats = c("%Y-%m-%d", "%m/%d/%Y"))
  # Check if any of the resulting parsed dates in either df are outside of the modern era
  # Just in case the date parsing happened to fail. Everything should fall between
  # 1950 and 2100, or else something is seriously wrong
  modern0 <- any(df0$ObservationDate <= "1950-01-01" & df0$ObservationDate >= "2099-12-31")
  modern1 <- any(df1$ObservationDate <= "1950-01-01" & df1$ObservationDate >= "2099-12-31")
  if (modern0 == TRUE | modern1 == TRUE){
    stop("ERROR: PARSED DATES ARE OUTSIDE EXPECTED MODERN ERA - ASSUMED FORMATTING ISSUE")
  }
  # Find overlaps in the new coco and delete those rows
  # Do this by creating a unique_ID column of timestamp and station number
  df0$id <- paste0(df0$ObservationDate, "_", df0$StationNumber)
  df1$id <- paste0(df1$ObservationDate, "_", df1$StationNumber)
  # Iterate through each row in the new cocorahs to check it
  df1$del <- NA
  for (i in 1:nrow(df1)){
    if (any(df0$id == df1$id[i])){
      df1$del[i] <- TRUE
    } else {
      df1$del[i] <- FALSE
    }
  }
  # Now delete those rows marked for deletion
  df1 <- df1[df1$del == FALSE,]
  df1$del <- NULL
  # We can rbind this to the archive, but the new data is on top as per convention
  df0 <- rbind(df1, df0)
  df0$id <- NULL
  rownames(df0) <- NULL
  ###############################################################################
  # Perform a check of the new archive 
  coco <- df0
  # The raw download includes at least one station with no marked lat/lon, recorded as zero. This must be deleted.
  coco <- coco[coco$Latitude != 0 & coco$Longitude != 0,]
  coco$diff <- NA
  coco$diff[1] <- 0
  for (i in 2:nrow(coco)){
    coco$diff[i] <- coco$ObservationDate[i] - coco$ObservationDate[i-1]
  }
  if (any(coco$diff > 0 | coco$diff < -1)){
    print("ERROR: Apparent skips or gaps in CoCoRaHs record - possible import mistake!")
    write <- FALSE
  } else {
    print("No dates are more than one day apart, import was likely successful.")
    write <- TRUE
  }
  coco$diff <- NULL
  if (write == TRUE){
    print("Overwriting cocorahs.csv...")
    write.csv(coco, "cocorahs.csv", row.names = FALSE)
  } else {
    print("Not overwriting csv file - check for errors before overwriting!")
  }
  return(coco)
}
coco.process <- function(coco){
  coco$date <- coco$ObservationDate; coco$date <- as.Date(coco$date)
  coco$time <- coco$ObservationTime
  coco$station <- coco$StationNumber
  coco$name <- coco$StationName
  coco$lat <- coco$Latitude
  coco$lon <- coco$Longitude
  # coerce all "trace" T to zero precip
  for (i in 1:nrow(coco)){
    if (coco$TotalPrecipAmt[i] == " T"){
      coco$TotalPrecipAmt[i] <- "0"
    }
  }
  # Removes leading spaces if they occur
  coco$TotalPrecipAmt <- sub("^\\s+", "", coco$TotalPrecipAmt)
  coco$precip <- coco$TotalPrecipAmt
  coco$precip <- as.numeric(coco$precip)
  # remaining NAs dropped
  coco <- coco[!is.na(coco$precip), ]
  coco <- coco[,c("date","time","station","name","lat","lon","precip")]
  # convert inches to mm
  coco$precip <- coco$precip * 25.4
  # subtract one day from the dates because cocorahs really is reporting the previous day's rain
  coco$date <- coco$date - as.difftime(1, units = "days")
  # sort by date to match weather record
  coco <- coco[order(coco$date),]
  rownames(coco) <- NULL
  return(coco)
}
# Joins a complete cocorahs record to the full archive
coco.join <- function(coco, archive){
  # Fix the NOAA CoCoRaHs dates
  archive$date[archive$type == "CoCoRaHs"] <- archive$date[archive$type == "CoCoRaHs"] - 1
  # Drop VI-ST-7 from coco - it has a very short and suspicious record, besides sharing
  # a name awkwardly with VI-ST-1, which has a much better record
  coco <- coco[coco$station != "VI-ST-7",]
  # Now fix up the coco data to prepare to add it to the archive
  coco$name <- toupper(coco$name)
  coco$name <- gsub("['’]", " ", coco$name)
  coco$name <- substring(coco$name, 2)
  # And add the suffix here
  #########################
  # Make the coco station name compatible with NOAA
  # VQ1VISC0010
  coco$station <- paste0("VQ1VI", substr(coco$station, 5, 6), leading.zeros(substr(coco$station, 8, nchar(coco$station)), 4))
  # Add text to the name to make this match
  coco$name <- paste0(coco$name, ", VI VQ")
  coco$elev <- NA # Use an elev lookup to generate elevs later if needed!
  coco$qual <- NA # Iron out gaps just as you did for NOAA
  stations <- unique(coco$station)
  for (i in 1:length(stations)){
    df <- coco[coco$station == stations[i],]
    coco <- coco[coco$station != stations[i],]
    # Make a new date series from start to finish 
    min.date <- min(df$date); max.date <- max(df$date)
    df.full <- data.frame(date = seq.Date(from = min.date, to = max.date, by = "day"))
    df$blank <- FALSE # And mark the original observations 
    # Join together to fill the gaps and proceed to write down all fillable info
    df <- merge(df.full, df, by = "date", all.x = TRUE)
    df$blank[is.na(df$blank)] <- TRUE
    df$station <- df$station[1]; df$name <- df$name[1]; df$type <- df$type[1]; df$lat <- df$lat[1]; df$lon <- df$lon[1]; df$elev <- df$elev[1]
    df$qual[df$blank == TRUE] <- "skip"; df$blank <- NULL; rownames(df) <- NULL
    coco <- rbind(df, coco)
    coco <- coco[order(coco$station, coco$date), ]
    rownames(coco) <- NULL
  }
  coco$type <- "CoCoRaHs"
  coco <- coco[,c("date", "station", "name", "type", "lat", "lon", "elev", "precip", "qual")]
  # Now find those station*dates that are not already in this record
  coco$id <- paste0(coco$date, "_", coco$station)
  archive$id <- paste0(archive$date, "_", archive$station)
  # Now remove everything from the CoCoRaHs import that is already represented in the archive
  coco <- coco[!(coco$id %in% archive$id), ]
  archive <- rbind(coco, archive)
  archive <- archive[order(archive$station, archive$date), ]
  rownames(archive) <- NULL; archive$id <- NULL
  # Perform another gap check and fill with NAs
  for (i in 1:length(stations)){
    df <- archive[archive$station == stations[i],]
    archive <- archive[archive$station != stations[i],]
    # Make a new date series from start to finish 
    min.date <- min(df$date); max.date <- max(df$date)
    df.full <- data.frame(date = seq.Date(from = min.date, to = max.date, by = "day"))
    df$blank <- FALSE # And mark the original observations 
    # Join together to fill the gaps and proceed to write down all fillable info
    df <- merge(df.full, df, by = "date", all.x = TRUE)
    df$blank[is.na(df$blank)] <- TRUE
    df$station <- df$station[1]; df$name <- df$name[1]; df$type <- df$type[1]; df$lat <- df$lat[1]; df$lon <- df$lon[1]; df$elev <- df$elev[1]
    df$qual[df$blank == TRUE] <- "skip"; df$blank <- NULL; rownames(df) <- NULL
    archive <- rbind(df, archive)
    archive <- archive[order(archive$station, archive$date), ]
    rownames(archive) <- NULL
  }
  # Report name NA for those that came in with no CoCoRaHs name
  archive$name[which(archive$name == ", VI VQ")] <- NA
  # Re-sort by date*station
  archive <- archive[order(archive$station, archive$date), ]
  rownames(archive) <- NULL
  return(archive)
}

######################    PRECIP SPATIAL INTERPOLATION    ######################
# These are kriging functions
kriging.rain <- function(wd, aoi, resolution){
  library(sf)
  library(gstat)
  library(ggplot2)
  # First bring in whatever data may already exist
  setwd(wd$path[wd$wd=="krige"])
  # Check if any precip kriging file exists
  if (any(grepl("kriged-precip", list.files()))) {
    files <- list.files()
    files <- files[grepl("kriged-precip", files)]
    drop.dates <- substr(files, 15, 24); drop.dates <- as.Date(drop.dates)
  } 
  # Load the full rain gauge archive
  setwd(wd$path[wd$wd=="weather"])
  load("precip.archive.rda")
  df <- archive
  # Bring in the data and prepare it
  # Filter observations that may lie outside the AOI
  df <- df %>%
    filter(lat >= min(aoi$lat) & lat <= max(aoi$lat) &
             lon >= min(aoi$lon) & lon <= max(aoi$lon))
  # Remove rows where precipitation is NA
  df <- df %>%
    filter(!is.na(precip))
  # Remove the dates we have already run before
  setwd(wd$path[wd$wd=="krige"])
  if (any(grepl("kriged-precip", list.files()))){
    df <- df[!(df$date %in% drop.dates),]
  }
  setwd(wd$path[wd$wd=="weather"])
  # Define the grid resolution, the argument should come in in meters
  # Calculate number of grid points
  xseq <- seq(from = min(aoi$lon), to = max(aoi$lon), by = resolution / 111320) # Convert meters to degrees
  # Get longitude degrees from meters by using 111320 * cos(lat_radians)
  yseq <- seq(from = min(aoi$lat), to = max(aoi$lat), by = resolution / 111320*cos((((min(aoi$lat) + max(aoi$lat))/2)*pi)/180)) 
  # Create a grid of points and filter by min and max lons just in case
  grid.df <- expand.grid(lon = xseq, lat = yseq)
  grid.df <- grid.df %>%
    filter(lon >= min(aoi$lon) & lon <= max(aoi$lon) & lat >= min(aoi$lat) & lat <= max(aoi$lat))

  for (i in 1:length(unique(df$date))){
    # Subset data for the current date
    subset <- df[df$date == df$date[i],]
    # Convert df.date to sf object
    df.sf <- st_as_sf(subset, coords = c("lon", "lat"), crs = 4326)
    # Convert grid.df to sf object
    grid.sf <- st_as_sf(grid.df, coords = c("lon", "lat"), crs = 4326)
    # Create a gstat object for variogram modeling
    gstat.obj <- gstat(id = "precip", formula = precip ~ 1, data = df.sf)
    
    # Compute the variogram
    variogram.model <- variogram(gstat.obj)
    curves <- c("Sph","Exp","Gau","Mat","Lin","Cir", "Nug")
    # Use try-catch to prevent errors and default to IDW
    fit.model <- tryCatch({
      # Some risky calculation
      fit.variogram(variogram.model, vgm(curves), fit.kappa = TRUE)
    }, error = function(e) {
      # Return NA if an error occurs
      NULL
    })
    
    if (is.null(fit.model)){
      # If the variogram fit produced an error and completely failed, do nothing to gstat.obj and proceed with IDW
    } else if (any(fit.model$psill < 0) | any(fit.model$range < 0)){
      # Ditto fi the sill or range produced were negative - this will make predict() default to inverse distance weighting
    } else {
      gstat.obj <- gstat(id = "precip", formula = precip ~ 1, data = df.sf, model = fit.model)
    }
    
    # Perform kriging
    kriging.result <- predict(gstat.obj, newdata = grid.sf, model = fit.model)
    
    # Convert result to a data frame
    result.df <- as.data.frame(kriging.result)
    # Add coordinates to the result
    result.df$lon <- st_coordinates(grid.sf)[, 1]
    result.df$lat <- st_coordinates(grid.sf)[, 2]
    # Add the date column to the result
    result.df$date <- df$date[i]
    result.df$geometry <- NULL
    
    print.now <- (i %% 10 == 0)
    if (print.now == TRUE){
      print(paste0("Functioning still performing well as of ", Sys.time(), ", printing latest plot..."))
      p <- krig.rain.plot(wd, result.df, aoi, df$date[i])
      print(p)
    }
    
    result.df$precip <- result.df$precip.pred
    kriged.precip <- result.df[,c("date","lat","lon","precip")]
    
    # Save this file
    today <- as.character(result.df$date[1])
    filename <- paste0("kriged-precip_", today, ".rda")
    setwd(wd$path[wd$wd=="krige"]); save(kriged.precip, file=filename,compress="xz")
    cat(paste0("File saved as ", filename))
  }
}
krig.rain.plot <- function(wd, result.df, aoi, date){
  # Create the plot
  setwd(wd$path[wd$wd=="sites"])
  load("coastline.rda")
  
  p <- ggplot() + 
    # Plot the kriged result
    geom_raster(data = result.df, aes(x = lon, y = lat, fill = precip.pred)) + 
    scale_fill_viridis_c() + 
    # Add coastlines on top
    geom_sf(data = coastline, color = "black", fill = NA) + 
    # Use coord_sf() for proper spatial alignment
    coord_sf(xlim = c(min(aoi$lon), max(aoi$lon)), ylim = c(min(aoi$lat), max(aoi$lat)), expand = FALSE) +
    # Add labels and title
    labs(title = paste("Kriging Result for Date:", date),
         x = "Longitude", 
         y = "Latitude", 
         fill = "Precipitation") +
    theme_minimal()
  return(p)
}
predicted.precip <- function(lat, lon, kriged){
  df <- kriged
  nearest.lat <- which.min(abs(df$lat - lat))
  nearest.lon <- which.min(abs(df$lon - lon))
  idx <- (nearest.lat + nearest.lon) / 2
  precip <- df$precip[idx]
  return(precip)
}
get.kriged.precip <- function(wd, date, lat, lon){
  setwd(wd$path[wd$wd=="krige"])
  date <- as.character(date)
  filename <- paste0("kriged-precip_", date, ".rda")
  load(filename)
  precip <- predicted.precip(lat, lon, kriged.precip)
  return(precip)
}
# This will provide a predicted kriging precip value and the N stations on the island that day,
# difference, and a normalized difference by N (e.g. diff/N) as new columns in the df provided, 
# where df contains date, lat, lon, and is a daily sum of precip from ATMOS gauges maintained by UVI
krig.compare <- function(wd, df){
  # Collect the dates available in the kriged rain folder
  setwd(wd$path[wd$wd=="krige"])
  filenames <- list.files()
  dates <- substr(filenames, 15, 24); dates <- as.Date(dates)
  # Discover the N gauges total and for each island group for each kriged date
  setwd(wd$path[wd$wd=="weather"])
  load("precip.archive.rda")
  df0 <- archive
  df0 <- df0[(df0$date %in% dates),]
  # This summary table contains the information needed
  ns <- df0 %>% group_by(date) %>% summarize(n = n(), n.stt = sum(lat > 18), n.stx = sum(lat < 18))
  df$kriged.precip <- NA; df$n <- NA; df$diff <- NA; df$normal.diff <- NA
  for (i in 1:nrow(df)){
    if (!any(grepl(df$date[i], dates))){
      # There is no kriging map for this date, skip it
      next
    }
    df$kriged.precip[i] <- get.kriged.precip(wd, df$date[i], df$lat[i], df$lon[i])
    if (df$lat[i] < 18){
      df$n[i] <- ns$n.stx[ns$date == df$date[i]]
    } else {
      df$n[i] <- ns$n.stt[ns$date == df$date[i]]
    }
    df$diff[i] <- df$precip[i] - df$kriged.precip[i]
    df$normal.diff[i] <- df$diff[i] / df$n[i]
    cat(paste0("Finished ", i, " of ", nrow(df)))
  }
  return(df)
}
# Compiles, without major QA/QC, all available raw Zentra records into daily precip
# full = TRUE means high resolution timesteps, instead of daily values
quick.atmos.compile <- function(wd, full = FALSE){
  setwd(wd$path[wd$wd=="weather"])
  files <- list.files()
  # Get only the files that are raw Zentra
  files <- files[grepl("weather", files)]
  # Pull out the sites
  sites <- unique(sub(paste0("(.*)", "_weather_", ".*"), "\\1", files))
  full.zentra <- read.csv(files[grepl(sites[1], files)][1]); full.zentra <- zentra.hydro(full.zentra)
  full.zentra$site <- NA; full.zentra <- full.zentra[0,]
  for (i in 1:length(sites)){
    setwd(wd$path[wd$wd=="weather"])
    site <- sites[i]
    site.files <- files[grepl(site, files)]
    # Extract the first file to begin the iteration
    filename <- site.files[1]; df <- read.csv(filename); df <- zentra.hydro(df)
    if (length(site.files) > 1){
      # Gather up the rest of the site files and attach them together
      for (j in 2:length(site.files)){
        filename <- site.files[j]
        df2 <- read.csv(filename)
        df2 <- zentra.hydro(df2)
        df <- rbind(df, df2)
      }
    }
    # A simple QA/QC to get evenly spaced times and splice NAs instead of skips
    df <- auto.qaqc(wd, df, FALSE)
    df$site <- site
    full.zentra <- rbind(full.zentra, df)
  }
  full.zentra <- full.zentra[,c("site", "date", "precip")]
  if (full){
    # Here we just return the full timeseries when that was requested
    result <- full.zentra
  } else {
    full.zentra$del <- NA
    # Collapse ATMOS to daily values, but exclude those with more than 2 hours gap of precip in one day
    full.storage <- full.zentra[0,]
    for (i in 1:length(sites)){
      site <- sites[i]
      subset <- full.zentra[full.zentra$site == site,]
      subset$date <- as.Date(subset$date)
      dates <- unique(subset$date)
      storage <- subset[0,]
      for (j in 1:length(dates)){
        date <- dates[j]
        dayrecord <- subset[subset$date == date,]
        dayrecord$del <- FALSE
        if (nrow(dayrecord) < 96){
          dayrecord$del <- TRUE # This also gets rid of days that are not full 24 hours
        }
        na.count <- sum(is.na(dayrecord$precip))
        if (na.count >= 8){
          dayrecord$del <- TRUE
        }
        storage <- rbind(storage, dayrecord)
      }
      full.storage <- rbind(full.storage, storage)
    }
    full.zentra <- full.storage[full.storage$del == FALSE,]
    daily <- full.zentra %>%
      group_by(site, date) %>%
      summarize(precip = sum(precip, na.rm = TRUE))
    
    # Now add lat and lon
    setwd(wd$path[wd$wd=="sites"])
    info <- read.csv("site-ids.csv")
    daily$lat <- NA; daily$lon <- NA
    for (i in 1:nrow(daily)){
      daily$lat[i] <- info$lat[info$sitename == daily$site[i]]; daily$lon[i] <- info$lon[info$sitename == daily$site[i]]
    }
    result <- daily
  }
  return(result)
}
haversine.distance <- function(lat1, lon1, lat2, lon2) {
  R <- 6371  # Earth's radius in km
  lat1 <- lat1 * pi / 180
  lon1 <- lon1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon2 <- lon2 * pi / 180
  dlat <- lat2 - lat1
  dlon <- lon2 - lon1
  a <- sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  d <- R * c
  return(d)
}
# Here we will pull the nearest gauge neighbor to the site*day and read its precip as $neighbor
neighbordaily <- function(wd, atmos){
  setwd(wd$path[wd$wd=="weather"])
  load("precip.archive.rda")
  # Combine UVI data with the whole archive
  atmos$type <- "UVI"
  atmos$station <- atmos$site
  atmos$name <- atmos$site
  atmos$elev <- NA
  atmos$qual <- NA
  atmos <- atmos[,c("date", "station", "name", "type", "lat", "lon", "elev", "precip", "qual")]
  all <- rbind(atmos, archive)
  # Make a table of stations to find nearest neighbors
  stations <- unique(all$station)
  neighbors <- data.frame(station = rep(NA, length(stations)), lat = rep(NA, length(stations)), lon = rep(NA, length(stations)), type = rep(NA, length(stations)))
  for (i in 1:length(stations)){
    station <- stations[i]
    neighbors$station[i] <- station
    neighbors$lat[i] <- all$lat[all$station == station][1]
    neighbors$lon[i] <- all$lon[all$station == station][1]
    neighbors$type[i] <- all$type[all$station == station][1]
  }
  atmos$neighbor <- NA
  # Supply precip observation at nearest neighbor
  for (i in 1:nrow(atmos)){
    neighbors$precip <- NA
    date <- atmos$date[i]
    for (j in 1:nrow(neighbors)){
      precip <- all$precip[all$station == neighbors$station[j] & all$date == date]
      if (length(precip) == 0){
        precip <- NA
      }
      neighbors$precip[j] <- precip
    }
    # Remove the stations with nothing today
    today <- neighbors[!is.na(neighbors$precip),]
    # Find the nearest of these to our position
    today$dist <- NA
    for (j in 1:nrow(today)){
      today$dist[j] <- haversine.distance(atmos$lat[i], atmos$lon[i], today$lat[j], today$lon[j])
    }
    # One of these will be our own position, remove it
    today <- today[today$dist > 0.00001,]
    # Now find the smallest remaining distance
    atmos$neighbor[i] <- today$precip[today$dist == min(today$dist)]
    cat(paste0("Finished ", i, " of ", nrow(atmos)))
  }
  return(atmos)
}
siteplots <- function(atmos){
  atmos$kriged.precip[atmos$kriged.precip < 0] <- 0
  
  sites <- unique(atmos$site)
  results <- data.frame(site = sites, krig.r2 = NA, krig.slope = NA)
  for (i in 1:length(sites)){
    site <- sites[i]
    subset <- atmos[atmos$site == site,]
    
    model.krig <- lm(subset$precip ~ subset$kriged.precip)
    krig.r2 <- round(summary(model.krig)$r.squared, 2)
    plot(subset$kriged.precip, subset$precip, 
         xlab = "Kriged precip, mm", ylab = "Observed precip, mm", 
         main = paste0("Kriging vs. real precip at ", site),
         ylim = c(0, max(max(subset$precip, na.rm = TRUE), max(subset$kriged.precip, na.rm = TRUE))),
         xlim = c(0, max(max(subset$precip, na.rm = TRUE), max(subset$kriged.precip, na.rm = TRUE))))
    abline(model.krig, col = "red")
    krig.slope <- round(model.krig$coefficients[2], 2)
    printed <- paste0("R2 = ", krig.r2, "; slope = ", krig.slope)
    text(60, 60, printed)
    results$site[i] <- site; results$krig.r2[i] <- krig.r2; results$krig.slope[i] <- krig.slope
    print(i)
  }
  subset <- atmos
  results[(length(unique(sites))+1),] <- NA
  results$site[length(unique(sites))+1] <- "all"
  model <- lm(subset$precip ~ subset$kriged.precip)
  r2 <- round(summary(model)$r.squared, 2)
  plot(subset$kriged.precip, subset$precip, 
       xlab = "Kriged precip, mm", ylab = "Observed precip, mm", 
       main = paste0("Kriging vs. real precip at all"),
       ylim = c(0, max(max(subset$precip, na.rm = TRUE), max(subset$kriged.precip, na.rm = TRUE))),
       xlim = c(0, max(max(subset$precip, na.rm = TRUE), max(subset$kriged.precip, na.rm = TRUE))))
  abline(model, col = "red")
  slope <- round(model$coefficients[2], 2)
  printed <- paste0("R2 = ", r2, "; slope = ", slope)
  text(60, 60, printed)
  results$r2[length(unique(sites))+1] <- r2; results$slope[length(unique(sites))+1] <- slope
  return(results)
}
# Extracts the full metadata for a given precip archive
full.precip.meta <- function(wd){
  setwd(wd$paths[wd$wd=="weather"]); load("precip.archive.rda")
  df <- archive
  meta <- data.frame(station = unique(df$station), name = rep(NA, length(unique(df$station))), type = rep(NA, length(unique(df$station))), 
                     lat = rep(NA, length(unique(df$station))), lon = rep(NA, length(unique(df$station))), elev = rep(NA, length(unique(df$station))), 
                     start = rep(NA, length(unique(df$station))), end = rep(NA, length(unique(df$station))))
  for (i in 1:nrow(meta)){
    subset <- df[df$station == meta$station[i],]
    meta$name[i] <- subset$name[1]; meta$type[i] <- subset$type[1]
    meta$lat[i] <- subset$lat[1]; meta$lon[i] <- subset$lon[1]; meta$elev[i] <- subset$elev[1]
    meta$start[i] <- subset$date[1]; meta$end[i] <- subset$date[nrow(subset)]
  }
  return(meta)
}
# Pulls the nearest neighboring daily gauge reading for a given site*date
neighbor.daily.model <- function(wd, lat, lon, date){
  # Pull the full archive if we have it already, or just the non-UVI if not yet
  setwd(wd$paths[wd$wd=="archive"])
  if (file.exists("full.precip.archive.rda")){load("precip.archive.rda")} else {setwd(wd$paths[wd$wd=="weather"]); load("precip.archive.rda") }
  df <- archive; df <- df[df$date == date,]
  # Find the neighbor to these coordinates on this date
  df$dist <- haversine.distance(lat, lon, df$lat, df$lon)
  df <- df[df$dist != 0,]; df <- df[order(df$dist), ]
  for (i in 1:nrow(df)){
    precip <- df$precip[i]
    if (!is.na(precip)){
      break
    }
    if (i == nrow(df)){
      stop("ERROR: All daily gauges in this island group were NA on one of the days you needed to interpolate!")
    }
  }
  neighbor <- precip
  # Apply the formula
  m <- 0.637; b <- 1.045
  daily.precip <- (m * neighbor) + b
  return(daily.precip)
}

######################        PLUVIOGRAPH SIMULATION      ######################
# Pluviograph simulation based on wind direction
zentra.wind <- function(zentra){
  zentra <- zentra[c(3:nrow(zentra)),]; rownames(zentra) <- NULL
  zentra$datetime <- zentra[,1]
  zentra$dir <- zentra[,6]; zentra$dir <- as.numeric(zentra$dir)
  zentra$wind <- zentra[,7]; zentra$wind <- as.numeric(zentra$wind)
  zentra$timestamp <- NA
  zentra <- zentra[,c("datetime","timestamp", "wind","dir")]
  zentra$datetime<-as.character(zentra$datetime)
  if (any(grepl("PM", zentra$datetime))){
    zentra$datetime <- as.POSIXct(zentra$datetime, format = "%m/%d/%Y %I:%M:%S %p", tz = "America/Port_of_Spain")
  } else {
    zentra$datetime <- as.POSIXct(zentra$datetime, format = "%m/%d/%Y %H:%M", tz = "America/Port_of_Spain")
  }
  zentra$timestamp <- as.numeric(zentra$datetime)
  zentra$date <- zentra$datetime
  zentra <- zentra[,c("date","timestamp","wind","dir")]
  return(zentra)
}
auto.qaqc2 <- function(df){
  # begin by checking that all dates are evenly spaced,
  # if they are not, print a warning but proceed to space them evenly and 
  # splice in NAs with uninterrupt(), assuming it worked as planned it will pass back
  df <- uninterrupt(df)
  df <- fillgaps2(df, FALSE)
  return(df)
}
fillgaps2 <- function(df, all){
  # Initialize storage information
  allgaps <- data.frame(start = numeric(0), end = numeric(0), length = numeric(0), varname = character(0))
  # Iterate through all columns and find gaps
  gaps(df[,4])
  for (i in 2:ncol(df)){
    gap1 <- gaps(df[,i])
    gap1$varname <- rep(colnames(df)[i], nrow(gap1))
    allgaps <- rbind(allgaps, gap1)
  }
  if(nrow(allgaps) == 0){
    stop("Congratulations, there are no gaps to fill!")
  }
  # Now we will need to use this reference to check whether the length is less than
  # 12 hours, which in terms of 15-minute intervals is a gaplength of 48
  allgaps$approx <- rep(NA, nrow(allgaps))
  if (all == FALSE){
    for (i in 1:nrow(allgaps)){
      if (allgaps$varname[i] == "precip" | allgaps$varname[i] == "level"){
        if (allgaps$length[i] <= 4){
          allgaps$approx[i] <- TRUE
        } else {
          allgaps$approx[i] <- FALSE
        }
      } else{
        if (allgaps$length[i] <= 192){
          allgaps$approx[i] <- TRUE
        } else {
          allgaps$approx[i] <- FALSE
        }
      }
    }
  } else {
    allgaps$approx <- TRUE
  }
  # For all TRUE gaps, we can just do linear interpolation, but we need to get 
  # the right positions filled
  for (i in 1:nrow(allgaps)){
    if (allgaps$approx[i] == TRUE){
      #build a vector from df of the values needed here
      start <- allgaps$start[i]-1
      end <- allgaps$end[i]+1
      needs.interp <- df[[allgaps$varname[i]]][start:end]
      interped <- na.approx(needs.interp, rule = 2)
      df[[allgaps$varname[i]]][start:end] <- interped
    }
  }
  # Find gaps a second time, use allgaps function and assume 15 minute interval
  allgaps(df, 15)
  #allgaps2 <- data.frame(start = numeric(0), end = numeric(0), length = numeric(0), varname = character(0))
  ## Iterate through all columns and find gaps
  #for (i in 2:ncol(df)){
  #  gap1 <- gaps(df[,i])
  #  gap1$varname <- rep(colnames(df)[i], nrow(gap1))
  #  allgaps2 <- rbind(allgaps2, gap1)
  #}
  #print(allgaps2)
  return(df)
}
# Compiles, without major QA/QC, all available raw Zentra records into wind and wind direction
quick.wind.compile <- function(wd){
  setwd(wd$path[wd$wd=="weather"])
  files <- list.files()
  # Get only the files that are raw Zentra
  files <- files[grepl("weather", files)]
  # Pull out the sites
  sites <- unique(sub(paste0("(.*)", "_weather_", ".*"), "\\1", files))
  full.zentra <- read.csv(files[grepl(sites[1], files)][1]); full.zentra <- zentra.wind(full.zentra)
  full.zentra$site <- NA; full.zentra <- full.zentra[0,]
  for (i in 1:length(sites)){
    site <- sites[i]
    site.files <- files[grepl(site, files)]
    # Extract the first file to begin the iteration
    filename <- site.files[1]; df <- read.csv(filename); df <- zentra.wind(df)
    if (length(site.files) > 1){
      # Gather up the rest of the site files and attach them together
      for (j in 2:length(site.files)){
        filename <- site.files[j]
        df2 <- read.csv(filename)
        df2 <- zentra.wind(df2)
        df <- rbind(df, df2)
      }
    }
    # A simple QA/QC to get evenly spaced times and splice NAs instead of skips - and interp 48 hours or less
    print(site); df <- auto.qaqc2(df); df$site <- site
    full.zentra <- rbind(full.zentra, df)
  }
  full.zentra <- full.zentra[,c("site", "date", "wind", "dir")]
  
  full.zentra$date <- as.Date(full.zentra$date)
  daily <- full.zentra %>%
    group_by(site, date) %>%
    summarize(wind = mean(wind, na.rm = TRUE),
              dir = mean(dir, na.rm = TRUE))

  # Now add lat and lon
  setwd(wd$path[wd$wd=="sites"])
  info <- read.csv("site-ids.csv")
  daily$lat <- NA; daily$lon <- NA
  for (i in 1:nrow(daily)){
    daily$lat[i] <- info$lat[info$sitename == daily$site[i]]; daily$lon[i] <- info$lon[info$sitename == daily$site[i]]
  }
  daily <- daily[,c("site","lat","lon","date","wind","dir")]
  daily$wind[is.nan(daily$wind)] <- NA; daily$dir[is.nan(daily$dir)] <- NA
  return(daily)
}
bearing <- function(lat1, lon1, lat2, lon2) {
  # Convert degrees to radians
  lat1 <- lat1 * pi / 180
  lon1 <- lon1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon2 <- lon2 * pi / 180
  dLon <- lon2 - lon1
  x <- sin(dLon) * cos(lat2)
  y <- cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
  theta <- atan2(x, y)
  # Convert radians to degrees and normalize to 0-360
  bearing <- (theta * 180 / pi + 360) %% 360
  return(bearing)
}
bearing.to.slope <- function(bearing) {
  # Convert bearing to standard angle (counterclockwise from x-axis)
  angle <- 90 - bearing
  # Convert angle to radians
  angle_rad <- angle * pi / 180
  # Calculate slope
  slope <- tan(angle_rad)
  return(slope)
}
# Finds the intersection along a point slope given in radians and a lat/lon coordinate where the second
# coordinate pair would intersect that line at a right angle. This is the distance "off" the upwind/downwind line
find.intersection <- function(slope1, x2, y2, x1, y1) {
  # Slope of the perpendicular line
  slope2 <- -1 / slope1
  x <- (slope1 * x1 - slope2 * x2 + y2 - y1) / (slope1 - slope2)
  y <- slope1 * (x - x1) + y1
  return(c(x, y))
}
downwind <- function(df, site, date){
  result <- data.frame(direction = c("downwind", "upwind"), pair = rep(NA, 2),
                       dist.online = rep(NA,2), dist.offline = rep(NA, 2), weight = rep(NA,2))
  # Ensure you are on the right island at least
  # Be aware that only one other station is on the island, it will simply be copied, no blending occurs
  if (getlat(wd, site) < 18){df <- df[df$lat < 18,]} else {df <- df[df$lat > 18,]}
  # Find the nearest downwind station and the day's windspeed
  direction <- df$dir[df$date == date & df$site == site]
  if (is.na(direction)){
    # When no station recorded a valid wind direction
    sites <- unique(df$site)
    sites <- sites[sites != site]
    dists <- data.frame(site = sites, dist = rep(NA, length(sites)))
    sitelat <- df$lat[df$site == site][1]
    sitelon <- df$lon[df$site == site][1]
    for (i in 1:length(sites)){
      site0 <- sites[i]
      lat <- df$lat[df$site == site0][1]
      lon <- df$lon[df$site == site0][1]
      dists$dist[i] <- haversine.distance(sitelat, sitelon, lat, lon)
    }
    neighborsite <- dists$site[dists$dist == min(dists$dist)]
    blend <- data.frame(site = rep(site, 2),
                        date = rep(date, 2),
                        direction = c("downwind", "upwind"),
                        pair = rep(neighborsite, 2),
                        weight = c(0.5, 0.5),
                        err = c(0,0))
    return(blend)
  }
  speed <- df$wind[df$date == date & df$site == site]
  meanspeed <- mean(df$wind[df$site == site], na.rm = TRUE)
  df <- df[df$date == date,]; df <- df[df$site != site,]
  df$bearing <- bearing(getlat(wd, site), getlon(wd, site), df$lat, df$lon)
  # Ensure the angular difference is within [0, 180]
  df$angular.diff <- pmin(abs(direction - df$bearing), 360 - abs(direction - df$bearing))
  # Find the coordinate with the smallest angular difference
  # But ensure the NAs are symmetric so we don't select a busted station
  df$wind[is.na(df$dir)] <- NA; df$dir[is.na(df$wind)] <- NA; df$angular.diff[is.na(df$wind)] <- NA
  downwind.site <- df$site[!is.na(df$angular.diff) & df$angular.diff == min(df$angular.diff, na.rm = TRUE)]
  # If there are no available wind stations today, return NA
  if (length(downwind.site) == 0){downwind.site <- NA}
  result$pair[result$direction=="downwind"] <- downwind.site
  # And the same for th nearest upwind
  upwind <- abs(direction - 180)
  # Ensure the angular difference is within [0, 180]
  df$angular.diff <- pmin(abs(upwind - df$bearing), 360 - abs(upwind - df$bearing))
  # Find the coordinate with the smallest angular difference
  upwind.site <- df$site[!is.na(df$angular.diff) & df$angular.diff == min(df$angular.diff, na.rm = TRUE)]
  if (length(upwind.site) == 0){upwind.site <- NA}
  result$pair[result$direction=="upwind"] <- upwind.site
  # Starting point (lat1, lon1)
  lat1 <- getlat(wd, site)
  lon1 <- getlon(wd, site)
  # Downwind coordinate (lat2, lon2)
  lat2 <- df$lat[df$site == downwind.site]
  lon2 <- df$lon[df$site == downwind.site]
  # Upwind coordinate (lat2, lon2)
  lat3 <- df$lat[df$site == upwind.site]
  lon3 <- df$lon[df$site == upwind.site]
  # Find where the wind direction line intersects with the nearest sites at a right angle
  # This will give us straight line distance to the target plus an off-line distance for error
  downwind.intersect <- find.intersection(bearing.to.slope(bearing(lat1, lon1, lat2, lon2)), lat1, lon1, lat2, lon2)
  upwind.intersect <- find.intersection(bearing.to.slope(bearing(lat1, lon1, lat3, lon3)), lat1, lon1, lat3, lon3)
  result$dist.online[result$direction=="downwind"] <- haversine.distance(lat1, lon1, downwind.intersect[1], downwind.intersect[2])
  result$dist.online[result$direction=="upwind"] <- haversine.distance(lat1, lon1, upwind.intersect[1], upwind.intersect[2])
  result$dist.offline[result$direction=="downwind"] <- haversine.distance(lat2, lon2, downwind.intersect[1], downwind.intersect[2])
  result$dist.offline[result$direction=="upwind"] <- haversine.distance(lat3, lon3, upwind.intersect[1], upwind.intersect[2])
  # Calculate the weight factors for the blending
  # These are based on the distance from the station to the perpendicular intersection ("on the line") with wind direction
  ratio <- max(result$dist.online) / min(result$dist.online);pie <- ratio + 1
  result$weight[result$dist.online == max(result$dist.online)] <- 1 / pie
  result$weight[result$dist.online == min(result$dist.online)] <- ratio / pie
  # But, based on the speed of the wind this day, and the distance "off" the line for each station, the influence
  # of each station on the final blend must be further modulated rather than the simple distance-weight
  # The windspeed needs to scale relatively, so: 
  speed.err <- 1 / (1 + (speed/meanspeed))
  # The scaling of this error calculation is based on the ratio of how far off the line we are to how long the line is:
  # We multiply it also with the speed error factor
  ratio <- result$dist.offline/result$dist.online
  result$err.scale <- (ratio / (1 + ratio)) * speed.err
  
  # We average the two since one blend change affects the other
  err.scale <- mean(result$err.scale); low <- 1 - err.scale; high <- 1 + err.scale
  result$err <- err.scale; result$low.err <- low; result$high.err <- high
  result$site <- site
  result$date <- date
  result <- result[,c("site", "date", "direction", "pair", "weight", "err")]
  return(result)
}
# Identifies if a pluviograph contains plateaus
plateau <- function(rain){
  pluv0 <- data.frame(precip = rain, sig = rep(NA, length(rain)), diff = rep(NA, length(rain)))
  pluv0$sig[pluv0$precip > 0.03] <- TRUE; pluv0$sig[pluv0$precip <= 0.03] <- FALSE
  pluv0$diff[1] <- 0
  for (i in 2:length(rain)){pluv0$diff[i] <- abs(pluv0$precip[i] - pluv0$precip[i-1])}
  pluv0$prob[pluv0$diff < 0.001 & pluv0$precip > 0.1] <- TRUE;   pluv0$prob[pluv0$diff >= 0.001 | pluv0$precip <= 0.1] <- FALSE
  rle.values <- rle(pluv0$prob)
  runs <- data.frame(value = rle.values$values, length = rle.values$lengths)
  runs <- runs[runs$value == TRUE,]
  # If there were no TRUE runs of plateaud values at all, we can just stop, so check that first
  if (nrow(runs) > 0){
    if (max(runs$length) > 4){
      # This identifies a significant "plateau" occured
      result <- TRUE
    } else {
      result <- FALSE
    }
  } else {
    result <- FALSE
  }
  return(result)
}
# A shorthand function that sets up a pluviograph of upwind and downwind sites as given by the blend.table, 
# used in a for loop with the iteration i variable and the atmos record
pluv.setup <- function(timestart, timeend, blend, atmos, date, i = NULL){
  start <- as.Date(timestart, tz = "America/Port_of_Spain"); end <- as.Date(timeend, tz = "America/Port_of_Spain")
  seq <- seq.Date(from = start, to = end, by = "day")
  if (is.null(i)){
    # If i is NULL, we are already within a single date
    start.time <- timestart; end.time <- timeend
    # Make timestamps for the start and end of the day as well
    start.day <- as.POSIXct(paste0(as.character(as.Date(timestart, tz = "America/Port_of_Spain")), " 00:00:00"), format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
    end.day <- as.POSIXct(paste0(as.character(as.Date(timestart, tz = "America/Port_of_Spain")+1), " 00:00:00"), format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain") - 900
  } else {
    # If we are at the beginning of the sequence blend from start time to midnight, middle is midnight to midnight, end is midnight to end time
    if (i == 1){
      start.time <- timestart; end.time <- as.POSIXct(paste(date + 1, "00:00:00"), tz = "America/Port_of_Spain")
      start.day <- as.POSIXct(paste0(as.character(as.Date(timestart, tz = "America/Port_of_Spain")), " 00:00:00"), format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
      end.day <- end.time - 900
    } else if (i != 1 & i != length(seq)){
      start.time <- as.POSIXct(paste(date, "00:00:00"), tz = "America/Port_of_Spain"); end.time <- as.POSIXct(paste(date + 1, "00:00:00"), tz = "America/Port_of_Spain")
      start.day <- start.time; end.day <- end.time - 900
    } else {
      start.time <- as.POSIXct(paste(date, "00:00:00"), tz = "America/Port_of_Spain"); end.time <- timeend
      start.day <- start.time
      end.day <- as.POSIXct(paste0(as.character(as.Date(timeend, tz = "America/Port_of_Spain")+1), " 00:00:00"), format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain") - 900
    }
  }
  # Use start.time and end.time to correctly subset the needed pluviographs from each of the blend pair sites
  pluv1 <- atmos[atmos$site == blend$pair[1],]; pluv2 <- atmos[atmos$site == blend$pair[2],] 
  if (blend$pair[1] == blend$pair[2]){
    pluv <- pluv1
  } else {
    pluv <- rbind(pluv1, pluv2)
  }
  #pluv1 <- pluv[pluv$date >= start.time & pluv$date <= end.time & pluv$site == blend$pair[1] ,]
  #pluv2 <- pluv[pluv$date >= start.time & pluv$date <= end.time & pluv$site == blend$pair[2] ,]
  pluv1 <- pluv[pluv$date >= start.day & pluv$date <= end.day & pluv$site == blend$pair[1] ,]
  pluv2 <- pluv[pluv$date >= start.day & pluv$date <= end.day & pluv$site == blend$pair[2] ,]
  pluv1$precip.down <- pluv1$precip; pluv1$precip.up <- pluv2$precip; pluv1$precip <- NULL; pluv1$site <- NULL; pluv <- pluv1
  rownames(pluv) <- NULL
  return(pluv)
}
# Shorthand function that performs a check on the given pluv pair site pluviographs to see if they have plateaus, and 
# replace them with another station if they do. Interacts with user if no good subset exists on that island, permits
# user to see the graph if so and proceed anyway if desired or return NA if not
pluv.check <- function(df, timestart, timeend, blend, atmos, pluv, site, date, i = NULL){
  iter <- 1
  # We must alter the sites we use until such time as no plateaus occur in our pluviograph
  while(TRUE) {
    # Deal with the possibilty of NAs in the pluv
    if (any(is.na(pluv$precip.down)) & !(any(is.na(pluv$precip.up)))){
      pluv$precip.down <- pluv$precip.up
    } else if (any(is.na(pluv$precip.up)) & !(any(is.na(pluv$precip.down)))){
      pluv$precip.up <- pluv$precip.down
    } else if (any(is.na(pluv$precip.down)) & (any(is.na(pluv$precip.up)))){
      df.switch <- df[df$site != blend$pair[blend$direction=="upwind"] & 
                        df$site != blend$pair[blend$direction=="downwind"],]
      blend <- downwind(df.switch, site, date)
      pluv <- pluv.setup(timestart, timeend, blend, atmos, date, i)
    }
    # Stop this if the loop is unneeded
    if (plateau(pluv$precip.down) == FALSE & plateau(pluv$precip.up) == FALSE){fail <- FALSE; break}
    # If both pluviographs are bad
    if (plateau(pluv$precip.down) == TRUE & plateau(pluv$precip.up) == TRUE){
      bad.site.down <- blend$pair[blend$direction=="downwind"]; bad.site.up <- blend$pair[blend$direction=="upwind"]
      df2 <- df[df$site != bad.site.up & df$site !=bad.site.down,]; blend <- downwind(df2, site, date)
    } else if (plateau(pluv$precip.down) == TRUE) {
      # If only downwind is bad
      bad.site <- blend$pair[blend$direction=="downwind"]
      df2 <- df[df$site != bad.site,]; blend <- downwind(df2, site, date)
    } else if (plateau(pluv$precip.up) == TRUE){
      # If only upwind is bad
      bad.site <- blend$pair[blend$direction=="upwind"]
      df2 <- df[df$site != bad.site,]; blend <- downwind(df2, site, date)
    }
    cat("WARNING: One or more neighbor station pluviographs swapped due to failed QC check for plateaus, retrying new station(s)...\n")
    # Make a pluviograph again to retry this loop with 
    pluv <- pluv.setup(timestart, timeend, blend, atmos, date, i)
    # Escape the loop if we have tried so much that there was no success and no pluviographs
    # are available - mark fail as TRUE to record this fact
    iter <- iter + 1
    if (iter > 100){
      cat("WARNING: No subsets from nearby station pluviographs passed QC check...\n")
      fail <- TRUE
      break
    }
  }
  if (fail == TRUE){
    cat("WARNING: One or more pluviographs from neighbor stations appeared to contain odd plateaus\n")
    cat("Plotting these now for visual inspection...")
    blend <- downwind(df, site, date)
    pluv <- pluv.setup(timestart, timeend, blend, atmos, date, i)
    plot(pluv$date, pluv$precip.down, type = "l", main = paste0("Downwind station: ", blend$pair[blend$direction=="downwind"], " on ", date))
    plot(pluv$date, pluv$precip.up, type = "l", main = paste0("Upwind station: ", blend$pair[blend$direction=="upwind"], " on ", date))
    # Ask the user if they want to continue
    repeat {
      cat("Do you want to continue with both these pluviographs? (Y/N): \n")
      response <- readline(); response <- toupper(response)
      if (response == "Y") {
        cat("Continuing and returning these pluviographs...\n")
        break  # Exit the repeat loop and continue the function if user says Yes
      } else if (response == "N") {
        # If the pluviograph is unacceptable, but no others were available, stop the function and return NA as the simulated pluviograph
        cat("Exiting function.\n")
        return(NA)  # Exit the function and return the result if user says No
      } else {
        cat("Invalid input. Please enter Y or N.\n")
      }
    }
    # We proceed with the pluviograph if the user said yes
  } else {cat("Passed QA/QC! Paired pluviographs for blending passed check for plateau errors - returning\n")}
  results <- list(blend = blend, pluv = pluv)
  return(results)
}
weighted.avg <- function(value1, value2, weight1, weight2) {
  weighted.sum <- (value1 * weight1) + (value2 * weight2)
  total.weight <- weight1 + weight2
  weighted.avg <- weighted.sum / total.weight
  return(weighted.avg)
}
# This function takes the validated two neighboring pluviographs and the information on the error factor
# And generates a blended pluviograph of the two, simulated in that the error is randomly applied
# The result is a relativized pluviograph indicating fractions of daily rain that can be combined
# outside this function with some observed or interpolated daily rainfall to get a sim.pluv simulated pluviograph
pluv.blend <- function(pluv, blend){
  pluv$precip <- NA; pluv$weight.d <- NA; pluv$weight.u <- NA
  set.seed(113)
  for (j in 1:nrow(pluv)){
    # Get the random scale changes to apply to one of the stations 
    coeff <- runif(1, (1-blend$err[1]), (1+blend$err[1]))
    pluv$weight.d[j] <- blend$weight[blend$direction=="downwind"] * coeff
    pluv$weight.u[j] <- 1 - pluv$weight.d[j]
    # Now the error has been applied to the weights. Perform the weighted average
    pluv$precip[j] <- weighted.avg(pluv$precip.down[j], pluv$precip.up[j], pluv$weight.d[j], pluv$weight.u[j])
  }
  # Now calculate the relative precipitation
  pluv <- pluv[,c("date", "precip")]
  total <- sum(pluv$precip)
  if (total == 0){
    # Deal with undefined dividing by zero - total rain of zero means all rain is zero
    pluv$rel.precip <- 0
  } else {
    pluv$rel.precip <- pluv$precip / total
  }
  return(pluv)
}
# If the nearest daily neighbor that we are about to scale off of, was a UVI gauge, 
# simply use that data as-is, as in just take its pluviograph - but subject it to a QA/QC check first. 
# And indeed, the pluviographs of each of the neighbors must also be QA/QC checked before use, and discarded if they are suspicious
rel.pluviograph <- function(wd, df, atmos, site, start, end){
  # Take the start and end timestamps and convert to date
  timestart <- start; timeend <- end
  timestart <- as.POSIXct(timestart, tz = "America/Port_of_Spain")
  timeend <- as.POSIXct(timeend, tz = "America/Port_of_Spain")
  start <- as.Date(start, tz = "America/Port_of_Spain"); end <- as.Date(end, tz = "America/Port_of_Spain")
  # To begin, check if there are no other active ATMOS stations in the island group in this period
  # And alert the user with a graph if this happens - user can choose linear, zero, or retain data
  setwd(wd$paths[wd$wd == "sites"]); sitelist <- read.csv("site-ids.csv")
  if (getlat(wd, site) > 18){
    islandsites <- sitelist[sitelist$lat > 18,]
  } else {
    islandsites <- sitelist[sitelist$lat <= 18,]
  }
  islandsites <- islandsites[islandsites$sitename != site,]
  islandsites$match <- NA
  for (i in 1:nrow(islandsites)){
    site0 <- islandsites$sitename[i]
    subset <- atmos[atmos$site == site0,]
    if (nrow(subset) == 0) {
      islandsites$match[i] <- FALSE  # No rows in the dataframe, set match to FALSE
    } else if (timestart < min(subset$date)) {
      islandsites$match[i] <- FALSE
    } else {
      islandsites$match[i] <- TRUE
    }
  }
  if (all(islandsites$match == FALSE)){
    match <- FALSE
    # This occurs when this check event has no matching neighbor ATMOS sites active, 
    # likely meaning this was the first ATMOS station in this island group.
    this.atmos <- atmos[atmos$site == site,]
    subset <- this.atmos[this.atmos$date >= (timestart - 24*60*60) & this.atmos$date <= (timeend + 24*60*60),]
    subset$zero <- 0; subset$zero[subset$date < timestart | subset$date > timeend] <- NA
    p1 <- subset$precip[subset$date == (timestart - 900)]
    p2 <- subset$precip[subset$date == (timeend + 900)]
    subset$lin <- NA
    n <- ((as.numeric(timeend) - as.numeric(timestart)) + 900) / 900
    subset$lin[subset$date >= timestart & subset$date <= timeend] <- seq(from = p1, to = p2, length.out = n)
    
    # Pulling daily rainfall for each day of this gap
    daylist <- seq(from = start, to = end, by = "day"); days <- data.frame(date = daylist, precip = rep(NA, length(daylist)))
    for (j in 1:nrow(days)){
      days$precip[j] <- neighbor.daily.model(wd, getlat(wd, sitename), getlon(wd, sitename), days$date[j])
    }
    gaugedailies <- round(days$precip, 2)
    gaugedailies <- paste(gaugedailies, collapse = ", ")
    plot(subset$date, subset$zero, ylim = c(0, (max(subset$precip))+(0.1*max(subset$precip))), pch = 17, col = "red", ylab = "Precip, mm", xlab = "Date", 
         main = paste0("Choose method of QA/QC with no ATMOS neighbor",
          "\n", as.Date(timestart, tz = "America/Port_of_Spain"), " to ", as.Date(timeend, tz = "America/Port_of_Spain"),
         "\nNearest daily precip values [mm]: ", gaugedailies))
    points(subset$date, subset$lin, pch = 17, col = "green")
    points(subset$date, subset$precip, pch = 17, col = "blue")
    abline(v = timestart, col = "black", lty = 2)
    abline(v = timeend, col = "black", lty = 2)
    rel.pluv <- data.frame(date = subset$date[subset$date >= timestart & subset$date <= timeend], precip = rep(NA, n), rel.precip = rep(NA, n))
    subset <- subset[subset$date >= timestart & subset$date <= timeend,]
    # Add legend
    legend("topright", legend = c("Original data", "Zeroed", "Linear interp"), col = c("blue", "red", "green"), pch = 17, box.lwd = 0)                   
    iter <- 0
    repeat {
      cat(paste0("ERROR: This check, from ", timestart, " to ", timeend, "\nhas no matching ATMOS weather stations in its island group. Would you like to:",
                 "\n  --[K]eep the data as is,",
                 "\n  --[Z]ero the data (entire pictured period is assigned zero values),",
                 "\n  --[I]nterpolate with simple linear interpolation (not usually recommended),, or",
                 "\n  --[G]PM/IMERG NASA satellite data (this will take a long time to execute!)\n"))      
      response <- readline(); response <- toupper(response)
      if (response == "K") {
        # If this is an unfilled gap, leaving the data is not an option
        if (any(is.na(subset$precip))){
          cat("This appears to be a lingering gap with missing data, you cannot choose this option!\n")
          next
        }
        cat("Retaining the original data with no alteration...\n")
        rel.pluv$precip <- subset$precip
        total <- sum(rel.pluv$precip)
        if (total == 0){
          # Deal with undefined dividing by zero - total rain of zero means all rain is zero
          rel.pluv$rel.precip <- 0
        } else {
          rel.pluv$rel.precip <- rel.pluv$precip / total
        }
        type <- "no.change"
        result <- list(rel.pluv = rel.pluv, match = match, type = type)
        return(result)  # Exit the this function and return this rel.pluv with FALSE MATCH
      } else if (response == "Z") {
        # User decided to replace data with precip zeroes
        rel.pluv$precip <- 0; rel.pluv$rel.precip <- 0
        cat("Replacing precip data in this period with zeroes...\n")
        type <- "zeroed.manual"
        result <- list(rel.pluv = rel.pluv, match = match, type = type)
        return(result)  # Exit the this function and return this rel.pluv with FALSE MATCH
      } else if (response == "I") {
        # User decided to replace data with linear interpolation
        rel.pluv$precip <- subset$lin
        total <- sum(rel.pluv$precip)
        if (total == 0){
          # Deal with undefined dividing by zero - total rain of zero means all rain is zero
          rel.pluv$rel.precip <- 0
        } else {
          rel.pluv$rel.precip <- rel.pluv$precip / total
        }
        cat("Replacing precip data in this period with linear interpolation...\n")
        type <- "interp.linear"
        result <- list(rel.pluv = rel.pluv, match = match, type = type)
        return(result)  # Exit the this function and return this rel.pluv with FALSE MATCH
      } else if (response == "G") {
        # Here we will extract data from NASA GPM IMERG to fill the gap, really a last resort!
        # The function should start a half hour early
        nasa <- nasa.rain(wd, getlat(wd, site), getlon(wd, site), timestart-(30*60), timeend, "thucydides15", "S@lt_R1v3r_hydro", "America/Port_of_Spain")
        nasa$date <- as.POSIXct(nasa$date, tz = "America/Port_of_Spain")
        # Convert this to 15 minute data
        nasa <- data.frame(
          date = seq(min(nasa$date), max(nasa$date), by = "15 min"),
          precip = approx(nasa$date, nasa$precip, xout = seq(min(nasa$date), max(nasa$date), by = "15 min"))$y
        )
        nasa <- nasa[nasa$date >= timestart & nasa$date <= timeend,]
        if (nrow(nasa) != n){
          cat("ERROR: The NASA data does not have the correct number of rows. Inspect and retry.")
          next
        }
        rel.pluv$precip <- nasa$precip
        total <- sum(rel.pluv$precip)
        if (total == 0){
          # Deal with undefined dividing by zero - total rain of zero means all rain is zero
          rel.pluv$rel.precip <- 0
        } else {
          rel.pluv$rel.precip <- rel.pluv$precip / total
        }
        type <- "NASA.GPM"
        result <- list(rel.pluv = rel.pluv, match = match, type = type)
        return(result)  # Exit the this function and return this rel.pluv with FALSE MATCH
      } else {
        iter <- iter + 1
        if (iter > 3){
          repeat {
            cat("You have entered invalid input 3 times. Do you want to exit?\nYou will lose your progress! (Y/N)\n")
            response2 <- readline(); response2 <- toupper(response2)
            if (response2 == "Y") {
              cat("Quitting function...\n")
              return(NA)  # Exit the repeat loop and continue the function if user says Yes
            } else if (response2 == "N") {
              cat("Returning to the question at hand...\n")
              iter <- 0
              break
            } else {
              cat("Invalid input. Please enter Y or N.\n")
            }
          }
        } else {
          cat("Invalid input. Please enter L, Z, I, or G.\n")
          cat(paste("Attempt number:", iter, ", option to exit after 3 attempts.\n"))  # Show current attempt number
        }
      }
    }
  }
  if (end - start == 0){
    # The whole gap happens on one date, so we can use the downwind() function just once
    blend <- downwind(df, site, start)
    # Use the resulting stations to subset the real pluviographs
    pluv <- pluv.setup(timestart, timeend, blend, atmos, date)
    # We must alter the sites we use until such time as no plateaus occur in our pluviograph
    result <- pluv.check(df, timestart, timeend, blend, atmos, pluv, site, date); pluv <- result$pluv; blend <- result$blend
    cat("Constructing simulated relative pluviograph with single day...\n")
    rel.pluv <- pluv.blend(pluv, blend)
  } else {
    # In this instance we must work on separate days
    seq <- seq.Date(from = start, to = end, by = "day")
    rel.pluv <- data.frame(date = character(0), precip = numeric(0), rel.precip = numeric(0))
    cat("Constructing simulated relative pluviograph with multiple days...\n")
    for (i in 1:length(seq)){
      date <- seq[i]
      blend <- downwind(df, site, date)
      # Use the resulting stations to subset the real pluviographs
      pluv <- pluv.setup(timestart, timeend, blend, atmos, date, i)
      # We must alter the sites we use until such time as no plateaus occur in our pluviograph
      result <- pluv.check(df, timestart, timeend, blend, atmos, pluv, site, date, i); pluv <- result$pluv; blend <- result$blend
      rel.pluv0 <- pluv.blend(pluv, blend)
      rel.pluv <- rbind(rel.pluv, rel.pluv0)
    }
  }
  # relative precip for each full date was calculated, now trim the pluviograph to match the actual perio
  rel.pluv <- rel.pluv[rel.pluv$date >= timestart & rel.pluv$date <= timeend,]
  match <- TRUE
  type <- "sim.pluviograph"
  result <- list(rel.pluv = rel.pluv, match = match, type = type)
  return(result) # If we did the actual pluviograph import, return with TRUE MATCH
}
# This generates the actual simulated pluviograph for one or multiple days given as a vector
sim.pluviograph <- function(rel.pluv, dailies, match){
  rel.pluv$date <- as.POSIXct(rel.pluv$date, tz = "America/Port_of_Spain")
  # Only applies daily correction if this came from a neighbor ATMOS true match
  if (match == TRUE){
    if (length(dailies) == 1){
      # Simple multiplication
      cat("Constructing simulated pluviograph with single daily rainfall...\n")
      pluv <- rel.pluv; pluv$precip <- pluv$rel.precip*dailies; pluv$daily <- dailies
    } else {
      cat("Constructing simulated pluviograph with multiple daily rainfalls...\n")
      start <- as.Date(rel.pluv$date, tz = "America/Port_of_Spain")[1]
      end <- as.Date(rel.pluv$date, tz = "America/Port_of_Spain")[nrow(rel.pluv)]
      seq <- seq.Date(from = start, to = end, by = "day")
      rel.pluv$dateonly <- as.Date(rel.pluv$date, tz = "America/Port_of_Spain")
      pluv <- data.frame(date = character(0), precip = numeric(0), rel.precip = numeric(0), daily = numeric(0))
      for (i in 1:length(seq)){
        date <- seq[i]
        subset <- rel.pluv[rel.pluv$dateonly == date,]
        subset$precip <- subset$rel.precip * dailies[i]
        subset$daily <- dailies[i]; subset$dateonly <- NULL
        pluv <- rbind(pluv, subset)
      }
    }
  } else {
    pluv <- rel.pluv
  }
  return(pluv)
}
