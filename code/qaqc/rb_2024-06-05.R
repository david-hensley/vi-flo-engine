# Importing Reef Bay (weather station is at Fish Bay)
# WEATHER NA         to NA
# HYDRO   2023-09-25 to 2024-06-05
# VWC     NA         to NA
# Reef Bay has hydro data only
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
sitename <- "rb"
ranges <- dateranges(wd, sitename); run.started <- Sys.time() # Proceed with acknowledgement if prompted

################################################################################
#######                    WEATHER DATA IMPORTATION                     ########
################################################################################
# We simply create an rb.weather.rda from Fish Bay, so Fish Bay must always run first
type <- "weather"
setwd(wd.archive); load("fb.weather.rda")
weather <- fb.weather
################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# This has the effect of simply duplicating the fb weather and calling it rb!

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
type <- "hydro"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
hydro <- multi.import(wd, sitename, type, start, end)

################################################################################
#############                 HYDROGRAPH DATA QA/QC                #############
################################################################################
# Ensures evenly spaced time intervals, fills gaps of <1 hours for water level
# and produces a summary of remaining gaps
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # No gaps

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
# The max value read, 2023-11-02 19:15:00 to 19:45:00, is bogus
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-11-02 19:15:00"), which(hydro$date == "2023-11-02 19:45:00"))
plot(hydro$date, hydro$level) # Looks good
rownames(hydro) <- NULL

# Slope logger became active 2024-02-05 09:30:00
# There was no flow during the observed slope period, so we stop here. We
# will have to calculate discharge without knowing the slope.curve
# This uses an existing qcurve, so no new qcurve calculation

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gaps(hydro) # no gaps
plot(hydro$date, hydro$q) # Looks okay, though we need a hydraulic slope

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# New archive written




