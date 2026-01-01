# Importing River Gut
# WEATHER NA         to NA
# HYDRO   2023-08-01 to 2024-08-21
# VWC     NA         to NA
# No weather station exists, we use UVI, and this gauge was destroyed in May 2024
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
sitename <- "river"
ranges <- dateranges(wd, sitename); run.started <- Sys.time() # Proceed with acknowledgement if prompted

################################################################################
#######                    WEATHER DATA IMPORTATION                     ########
################################################################################
# We simply create an river.weather.rda from UVI
type <- "weather"
setwd(wd.archive); load("uvi.weather.rda")
weather <- uvi.weather
################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# This has the effect of simply duplicating the uvi weather and calling it river!

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
gap.print(hydro, 15) # logger died in the flood of early May 2024
hydro <- hydro[hydro$date < "2024-05-12 21:30:00",]

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
# The logger hung on for awhile after being dislodged and produced erroneous values
plot(hydro$date[hydro$date >= "2024-05-03"], hydro$level[hydro$date >= "2024-05-03"])
# Appears to become dislodged at 2024-05-04 01:30:00
hydro <- hydro[hydro$date < "2024-05-04 01:30:00",]
plot(hydro$date, hydro$level) # looks okay
rownames(hydro) <- NULL

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gaps(hydro) # no gaps
plot(hydro$date, hydro$q) # Insane discharge peaks but until a rating curve exists...

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Success







