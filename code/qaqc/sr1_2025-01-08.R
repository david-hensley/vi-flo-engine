# Importing Salt River 1
# WEATHER 2024-09-23 to 2025-01-08
# HYDRO   2024-09-13 to 2025-01-07
# VWC     2024-09-23 to 2025-01-08
# Complete through 2024
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
sitename <- "sr1"
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
gaplist <- allgaps(weather, 15) # Barometer failed - import pressure from SR2
setwd(wd.archive); load("sr2.weather.rda")
splice.meta.add(wd, sitename, "2024-09-22 19:00:00", "2025-01-08 22:15:00", "pres", "gap", "neighbor.atmos", NA)
weather$pres <- sr2.weather$pres[sr2.weather$date >= "2024-09-22 19:00:00" & sr2.weather$date <= "2025-01-08 22:15:00"]
# Get the elev difference between the WEATHER STATIONS not the stream gauges! Coords pulled from Zentra cloud manually!
elev <- get.elev(17.7606071, -64.8000398) - get.elev(17.7536017, -64.7755428)
# Correct the pressure from SR2
weather <- pres.correct(wd, weather, elev)

# If gaps remain in weather variables, you may interpolate all except precip
# when the gaps are not eregiously long, e.g.:
weather <- interp(wd, weather, "wind", 15)
gaplist0 <- allgaps(weather, 15) # no gaps remain

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # Normal
plot(weather$date, weather$temp)  # Normal
plot(weather$date, weather$rh)    # Normal
plot(weather$date, weather$wind)  # Normal
plot(weather$date, weather$pres)  # Normal

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # No gaps
plot(weather$date, weather$precip) # Looks OK

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# Done
################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
type <- "hydro"
# Use sr1backup as main site name but use original ranges
hydro <- multi.import(wd,"sr1backup", type, start, end)

################################################################################
#############                 HYDROGRAPH DATA QA/QC                #############
################################################################################
# Ensures evenly spaced time intervals, fills gaps of <1 hours for water level
# and produces a summary of remaining gaps
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # [comment here]

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
# A handful of extreme values in isolation
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-10-14 10:00:00"), which(hydro$date == "2024-10-14 12:00:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-11-04 03:00:00"), which(hydro$date == "2024-11-04 09:00:00"))

plot(hydro$date, hydro$level) # Fixed
rownames(hydro) <- NULL

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

################################################################################
#############                    VWC IMPORTATION                   #############
################################################################################
type <- "vwc"
end <- ranges$endstring[ranges$type==type]
start2 <- "20240910"
vwc <- multi.import(wd, sitename, type, start2, end)

################################################################################
#############                       VWC QA/QC                      #############
################################################################################
vwc <- vwc.qaqc(wd, vwc)
gaplist <- allgaps(vwc, 15) # No gaps

# setting a threshold of rainfall below which we allow auto gap filling, 6mm is normal
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # No gaps

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Check by type, begin with hs 
vwc.hs <- vwc[vwc$type == "hs",]
rownames(vwc.hs) <- NULL
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # Good
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # Good
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # Good
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # Good

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # Good
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # Good
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # Good
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # Good

# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc) <- NULL


################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# Done





