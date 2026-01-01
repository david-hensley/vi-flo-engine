# Importing [write the full site name in English]
# WEATHER 2024-09-23 to 2025-01-08
# HYDRO   2024-09-13 to 2025-01-07
# VWC     2024-09-23 to 2025-01-08
# Current through 2024
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
sitename <- "sr2"
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
gaplist <- allgaps(weather, 15) # many short-ish gaps, most in precip

weather <- interp(wd, weather, "rad", 15)
weather <- interp(wd, weather, "temp", 15)
weather <- interp(wd, weather, "rh", 15)
weather <- interp(wd, weather, "wind", 15)
weather <- interp(wd, weather, "pres", 15)
gaplist0 <- allgaps(weather, 15) # Precip gaps remaining

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # An erroneous period exists mid November 2024
plot(weather$date, weather$temp)  # Same error here
plot(weather$date, weather$rh)    # Same error here
plot(weather$date, weather$wind)  # Same error here
plot(weather$date, weather$pres)  # Same error here
# If any manual QA/QC is needed, perform it here
# Use splice.meta.add() before performing any direct manual data editing
# and use quick.index.interp() for quick interpolation by index which will perform splice for you, e.g.
#weather <- quick.index.interp(wd, sitename, weather, "pres", which(weather$date == "2021-12-23 04:15:00"), which(weather$date == "2021-12-23 04:30:00"))

# The period between 2024-11-09 12:00:00 and 2024-11-18 18:00:00 is garbled in temp, rh, wind, and pres
# So we will acquire those values from UVI and use them
setwd(wd.archive); load("uvi.weather.rda")
splice.meta.add(wd, sitename, "2024-11-09 12:00:00", "2024-11-18 18:00:00", "pres", "gap", "neighbor.atmos", NA)
weather$pres[weather$date >= "2024-11-09 12:00:00" & weather$date <= "2024-11-18 18:00:00"] <- 
  uvi.weather$pres[uvi.weather$date >= "2024-11-09 12:00:00" & uvi.weather$date <= "2024-11-18 18:00:00"]
# Get the elev difference between the WEATHER STATIONS not the stream gauges! Coords pulled from Zentra cloud manually!
elev <- get.elev(17.7188825, -64.7967278) - get.elev(17.7536017, -64.7755428)
# Correct the pressure from UVI
weather <- pres.correct(wd, weather, elev)

# Supply rad, temp, rh, and wind from UVI
# With a universal correction coefficient
splice.meta.add(wd, sitename, "2024-11-09 12:00:00", "2024-11-18 18:00:00", "rad", "gap", "neighbor.atmos", NA)

weather$rad[weather$date >= "2024-11-09 12:00:00" & weather$date <= "2024-11-18 18:00:00"] <- 
  (uvi.weather$rad[uvi.weather$date >= "2024-11-09 12:00:00" & uvi.weather$date <= "2024-11-18 18:00:00"]) *
  (mean(weather$rad, na.rm = TRUE)/mean(uvi.weather$rad))
# Same with temp
splice.meta.add(wd, sitename, "2024-11-09 12:00:00", "2024-11-18 18:00:00", "temp", "gap", "neighbor.atmos", NA)

weather$temp[weather$date >= "2024-11-09 12:00:00" & weather$date <= "2024-11-18 18:00:00"] <- 
  (uvi.weather$temp[uvi.weather$date >= "2024-11-09 12:00:00" & uvi.weather$date <= "2024-11-18 18:00:00"]) *
  (mean(weather$temp, na.rm = TRUE)/mean(uvi.weather$temp))
# Same with rh
splice.meta.add(wd, sitename, "2024-11-09 12:00:00", "2024-11-18 18:00:00", "rh", "gap", "neighbor.atmos", NA)

weather$rh[weather$date >= "2024-11-09 12:00:00" & weather$date <= "2024-11-18 18:00:00"] <- 
  (uvi.weather$rh[uvi.weather$date >= "2024-11-09 12:00:00" & uvi.weather$date <= "2024-11-18 18:00:00"]) *
  (mean(weather$rh, na.rm = TRUE)/mean(uvi.weather$rh))
# Same with wind
splice.meta.add(wd, sitename, "2024-11-09 12:00:00", "2024-11-18 18:00:00", "wind", "gap", "neighbor.atmos", NA)

weather$wind[weather$date >= "2024-11-09 12:00:00" & weather$date <= "2024-11-18 18:00:00"] <- 
  (uvi.weather$wind[uvi.weather$date >= "2024-11-09 12:00:00" & uvi.weather$date <= "2024-11-18 18:00:00"]) *
  (mean(weather$wind, na.rm = TRUE)/mean(uvi.weather$wind))

# Plot again when needed to check for success
plot(weather$date, weather$rad)   # Fixed
plot(weather$date, weather$temp)  # Fixed
plot(weather$date, weather$rh)    # Fixed
plot(weather$date, weather$wind)  # Fixed
plot(weather$date, weather$pres)  # Fixed

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # No gaps
plot(weather$date, weather$precip) # Looks good

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# Saved

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
gap.print(hydro, 15) # [comment here]

################################################################################
# MANUAL QA/QC
# The backup is used henceforward at SR2
ranges2 <- dateranges(wd, "sr2backup")
start2 <- ranges2$startstring[ranges$type==type]
end2 <- ranges2$endstring[ranges$type==type]
hydro <- multi.import(wd,"sr2backup", type, start2, end2)

hydro <- level.qaqc(wd, hydro, sitename) # Has a few odd values near the start
# Same manual process as above, e.g.:
splice.meta.add(wd, sitename, "2024-08-15 11:45:00", "2024-08-15 16:00:00", "level", "splice", "copy.next.reading", NA)

hydro$level[hydro$date <= "2024-08-15 16:00:00"] <- hydro$level[hydro$date == "2024-08-15 16:15:00"]
splice.meta.add(wd, sitename, "2024-08-21 23:00:00", "2024-08-21 23:45:00", "level", "splice", "copy.next.reading", NA)

hydro$level[hydro$date >= "2024-08-21 23:00:00" & hydro$date <= "2024-08-21 23:45:00"] <- hydro$level[hydro$date == "2024-08-22 00:00:00"]
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-10-14 10:00:00"), which(hydro$date == "2024-10-14 12:00:00"))
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
archive <- archive.data(wd, hydro, sitename, type, overwrite) # Done
################################################################################
#############                    VWC IMPORTATION                   #############
################################################################################
type <- "vwc"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
vwc <- multi.import(wd, sitename, type, start, end)

################################################################################
#############                       VWC QA/QC                      #############
################################################################################
vwc <- vwc.qaqc(wd, vwc)
gaplist <- allgaps(vwc, 15) # No gaps

# setting a threshold of rainfall below which we allow auto gap filling, 6mm is normal
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # no gaps

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Check by type, begin with hs 
vwc.hs <- vwc[vwc$type == "hs",]
rownames(vwc.hs) <- NULL
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # Looks good
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # Looks good
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # Looks good
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # Looks good
# Perform manual QA/QC as necessary

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # Looks good
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # Looks good
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # Looks good
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # Looks good
# Perform manual QA/QC as necessary

# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc) <- NULL


################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# Saved



