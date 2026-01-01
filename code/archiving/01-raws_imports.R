# This code is used for new downloads to the RAWS weather archive.
# Follow these instructions to download and add new data.
# Currently there are two operational USVI stations: Cotton Valley STX
# and St. John. It is recommended to download both to current date each time.
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr)
setwd(wd.raws)

# Begin with COTTON VALLEY:
# Go to https://wrcc.dri.edu/cgi-bin/rawMAIN.pl?txPCOT
site <- "cv"
# > Daily Summary Time Series (left toolbar) BE SURE IT SAYS TIME SERIES!
# > Set the starting date equal to the last ending date or earlier
files <- list.files(); files <- files[grepl(site, files)]; ends <- as.numeric(substr(files, nchar(files) - 11, nchar(files)-4))
end <- max(ends); start.cv <- end; end <- as.Date(as.character(end), format="%Y%m%d"); paste0("START DATE: ", as.character(format(end, "%B %d %Y")))
# > Set the ending date to today's date
paste0("END DATE: ", as.character(format(Sys.Date(), "%B %d %Y")))
# > Default "Elements marked with *" should be checked for variables to export
# > Output Units > Metric
# > Output format > Downloadable Ascii
# > Data Summarization requirements > Any data
# > Apply physical limits QC to data > Yes
# > Represent Missing data as > M
# > Include # of valid observations for each element > No
# > Submit info
# > Wait a moment for all data to load
# > CTRL+A to select
# > CTRL+C and CTRL+V in Notepad
# > Save with naming convention: RAWS_shortname_20200101-20240903.txt
# > Where the start string is the start date entered and the end string is today

# Now repeat this for CORAL BAY ST. JOHN:
# Go to https://wrcc.dri.edu/cgi-bin/rawMAIN.pl?txPSTJ
site <- "cb"
files <- list.files(); files <- files[grepl(site, files)]; ends <- as.numeric(substr(files, nchar(files) - 11, nchar(files)-4))
end <- max(ends); start.cb <- end; end <- as.Date(as.character(end), format="%Y%m%d"); paste0("START DATE: ", as.character(format(end, "%B %d %Y")))
paste0("END DATE: ", as.character(format(Sys.Date(), "%B %d %Y"))); end <- gsub("-", "", as.character(Sys.Date()))

## Change the start and end date to match that of the file, site by site
site <- "cv"
start <- as.character(start.cv)
end <- as.character(end)
# Perform the import of the raw .txt file you downloaded, and beware of warning messages
raws <- import.raws.raw(wd, site, start, end)
# If everything is acceptable with the import of all the sites, overwrite the archive
write.csv(raws, "raws.csv", row.names = FALSE)

## Change the start and end date to match that of the file, site by site
site <- "cb"
start <- as.character(start.cb)
end <- as.character(end)
# Perform the import of the raw .txt file you downloaded, and beware of warning messages
raws <- import.raws.raw(wd, site, start, end)
# If everything is acceptable with the import of all the sites, overwrite the archive
write.csv(raws, "raws.csv", row.names = FALSE)


