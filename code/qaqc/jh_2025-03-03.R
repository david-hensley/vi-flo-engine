# Importing Jolly Hill
# WEATHER YYYY-MM-DD to YYYY-MM-DD
# HYDRO   2025-01-07 to 2025-03-03
# VWC     YYYY-MM-DD to YYYY-MM-DD
################################################################################
######               PACKAGES, FUNCTIONS AND WD INFORMATION               ######
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr); setwd(wd.archive)
sitename <- "jh"
ranges <- dateranges(wd, sitename); run.started <- Sys.time() # Proceed with acknowledgement if prompted

################################################################################
#######                    WEATHER DATA IMPORTATION                     ########
################################################################################
# We simply create an jh.weather.rda from r2r
type <- "weather"
setwd(wd.archive); load("r2r.weather.rda")
weather <- r2r.weather
################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# This has the effect of simply duplicating the r2r weather and calling it jh!

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
# Looks good

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # No gaps
plot(hydro$date, hydro$q) # Looks good

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Done







