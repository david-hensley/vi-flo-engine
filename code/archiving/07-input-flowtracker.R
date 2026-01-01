# Adding new flow observations to record
# This is necessary after each FlowTracker observation
# And will help you decide whether to recalculate the rating curve
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr); setwd(wd.archive)



input.new.flowtracker <- function(wd){
  setwd(wd$paths[wd$wd=="sites"])
  site.ids <- read.csv("site-ids.csv")
  qfits <- read.csv("qfits.csv")
  sites <- unique(qfits$site)
  
  wd.flow <- paste0(sub("^(.*)/[^/]*$", "\\1", wd$paths[wd$wd=="sites"]), "/Raw-FlowTracker")
  setwd(wd.flow)
  files <- list.files()
  
  # We now check whether there are any files among the raw FlowTracker files that are newer than those in qfits.csv
  dates <- as.POSIXct(character(0), tz = "America/Puerto_Rico")
  for (i in 1:length(files)){
    file <- files[i]
    if (!grepl("_.*\\.", file)){
      next
    }
    datestring <- sub("^[^_]*_([^.]*)\\..*", "\\1", file)
    date <- as.POSIXct(datestring, format = "%Y%m%d-%H%M%S", tz = "America/Puerto_Rico")
    dates[i] <- date
  }
  dates <- dates[!is.na(dates)]
  dates <- unique(dates)
  qfits$date <- as.POSIXct(qfits$date, format = "%Y-%m-%d %H:%M:%S", tz = "America/Puerto_Rico")
  qfits.dates <- qfits$date[!is.na(qfits$date)]
  # get the file dates that exceed the most recent logged qfit + 30 minutes
  dates <- dates[dates > max(qfits.dates, na.rm = TRUE)+1800]
  # convert these back to string
  dates <- format(dates, "%Y%m%d-%H%M%S")
  # Now we get the relevant discharge data files
  files <- files[grepl(paste0(dates, collapse = "|"), files)]
  files <- files[grepl(".ft.dis", files)]
  
  for (i in 1:length(files)){
    file <- files[i]
    # Pull the site name from the file
    site <- sub("_.*", "", file)
    # Look up the corresponding universal sitename
    sitename <- true.sitename(site)
    df <- read.csv(file, row.names = NULL)
    # Pull the discharge figure
    discharge.row <- which(apply(df, 1, function(row) any(row == "Total_Discharge")))    
    q <- as.numeric(df[discharge.row, 3])
    # Pull the datetime
    datetime.row <- which(apply(df, 1, function(row) any(row == "Local_End_Time")))    
    datetime <- as.POSIXct(df[datetime.row, 3], format = "%Y-%m-%d %H:%M:%S", tz = "America/Puerto_Rico")
    # Round off to nearest 15 minutes to look up gauge
    rounded <- as.POSIXct(round(as.numeric(datetime) / (15 * 60)) * (15 * 60), origin = "1970-01-01", tz = attr(datetime, "tzone"))
  }
}


true.sitename <- function(site){
  # Look for this site name in site-ids
  site.found <- which(apply(site.ids, 1, function(row) any(row == site)))
  if (length(site.found) > 1){
    stop("ERROR: more than one row in site-ids.csv contains the supplied site name! Please check.")
  }
  sitename <- site.ids$sitename[site.found]
  return(sitename)
}
