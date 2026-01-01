# Importing Turpentine Run 1
# WEATHER 2024-08-20 to 2025-06-30
# HYDRO   2024-08-14 to 2025-06-03
# VWC     NA         to NA
# This import code produced an erroneous dataset because of a moved logger
# We will require a survey of new TR1 and TR1_slope logger to get new qcurve

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
sitename <- "tr1"
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
gaplist <- allgaps(weather, 15) # small wind gaps

weather <- interp(wd, weather, "wind", 15)
gaplist0 <- allgaps(weather, 15) # no gaps left

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # looks ok
plot(weather$date, weather$temp)  # looks ok
plot(weather$date, weather$rh)    # looks ok
plot(weather$date, weather$wind)  # greatly increased wind end of March 2025 could indicate vegetation clearing... area had become overgrown
plot(weather$date, weather$pres)  # looks ok

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # looks good
plot(weather$date, weather$precip) # looks good

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# [done

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
# A gap exists in the data files from 2024-08-14 to 2024-10-22
# As a result we will have to do a manual join with a long NA gap
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
gap.print(hydro, 15) # no gaps

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
plot(hydro$date, hydro$level) # interesting, but no red flags
rownames(hydro) <- NULL

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # no gaps
plot(hydro$date, hydro$q) # very interesting given the perennial flow

################################################################################
# Archive it
overwrite <- FALSE

#archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Instead of the normal process we will have to proceed manually
setwd(wd.archive)
load("tr1.hydro.rda")
missing.period <- seq(from = tr1.hydro$date[nrow(tr1.hydro)]+900, 
                      to = hydro$date[1]-900, by = "15 min")
na.splice <- data.frame(date = missing.period, timestamp = as.numeric(missing.period),
                        site = "tr1", level = rep(NA, length(missing.period)), q = rep(NA, length(missing.period)))
new <- rbind(tr1.hydro, na.splice, hydro)
# This looks good, but let's first record this splice manually in the record
splices <- read.csv("splices.csv")
unique(splices$method)
splice.meta.add(wd, "tr1", tr1.hydro$date[nrow(tr1.hydro)]+900, hydro$date[1]-900, 
                "level", "gap", "stays.gap", NA)
tr1.hydro <- new
save(tr1.hydro, file = "tr1.hydro.rda")
# Done