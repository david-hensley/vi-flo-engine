# Importing UVI St. Croix Campus weather station
# WEATHER 2021-10-08 to 2024-09-23
# HYDRO   NA         to NA
# VWC     NA         to NA
# UVI STX is a weather station only but is used for on-campus experiments
# ANd can also be the reference pressure for any gauges in the Bethlehem watershed
################################################################################
######               PACKAGES, FUNCTIONS AND WD INFORMATION               ######
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); setwd(wd.archive)
sitename <- "uvi"
ranges <- dateranges(wd, sitename); run.started <- Sys.time() # Proceed with acknowledgement if prompted

################################################################################
#######                    WEATHER DATA IMPORTATION                     ########
################################################################################
type <- "weather"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
weather <- multi.import(wd, sitename, type, start, end)

################################################################################
############                   WEATHER DATA QA/QC                  #############
################################################################################
# Ensures evenly spaced time intervals, fills gaps of <12 hours for weather
# variables and <1 hour for precip, produces summary of remaining gaps
weather <- auto.qaqc(wd, weather)
gaplist <- allgaps(weather, 15) # gaps remaining in wind, all short

weather <- interp(wd, weather, "wind", 15)
gaplist0 <- allgaps(weather, 15) # no more gaps

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # good
plot(weather$date, weather$temp)  # good
plot(weather$date, weather$rh)    # one ultra low value in early 2024
plot(weather$date, weather$wind)  # good
plot(weather$date, weather$pres)  # good
# If any manual QA/QC is needed, perform it here
# Use splice.meta.add() before performing any direct manual data editing
# and use quick.index.interp() for quick interpolation by index which will perform splice for you, e.g.
weather <- quick.index.interp(wd, sitename, weather, "rh", which(weather$date == "2024-01-17 09:45:00"), which(weather$date == "2024-01-17 09:45:00"))
plot(weather$date, weather$rh)    # fixed

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # no gaps
plot(weather$date, weather$precip) # very reasonable

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# Success







