# Importing Salt River 1
# WEATHER 2025-01-08 to 2025-06-30
# HYDRO   2025-01-07 to 2025-03-03
# VWC     2025-01-08 to 2025-06-30
# Pressure sensor is down, and SR2 weather is down - so UVI becomes the key station till replacements
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
gaplist <- allgaps(weather, 15) # pressure is missing - we pull from UVI

setwd(wd.archive); load("uvi.weather.rda")
splice.meta.add(wd, sitename, "2025-01-07 18:00:00", "2025-06-30 14:00:00", "pres", "gap", "neighbor.atmos", NA)
weather$pres <- uvi.weather$pres[uvi.weather$date >= "2025-01-07 18:00:00" & uvi.weather$date <= "2025-06-30 14:00:00"]
# Get the elev difference between the WEATHER STATIONS not the stream gauges! Coords pulled from site.coords.csv
coords <- read.csv("site.coords.csv")
sr1.lat <- coords$lat.weather[coords$sitename=="sr1"]
sr1.lon <- coords$lon.weather[coords$sitename=="sr1"]
uvi.lat <- coords$lat.weather[coords$sitename=="uvi"]
uvi.lon <- coords$lon.weather[coords$sitename=="uvi"]
elev <- get.elev(sr1.lat, sr1.lon) - get.elev(uvi.lat, uvi.lon)
# Correct the pressure from SR2
weather <- pres.correct(wd, weather, elev)
gaplist0 <- allgaps(weather, 15) # no gaps

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # looks good
plot(weather$date, weather$temp)  # looks good
plot(weather$date, weather$rh)    # looks good
plot(weather$date, weather$wind)  # looks good
plot(weather$date, weather$pres)  # looks good

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # no gaps
plot(weather$date, weather$precip) # ok

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# done

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
type <- "hydro"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
hydro <- multi.import(wd,"sr1backup", type, start, end)

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
plot(hydro$date, hydro$level) # no apparent issues
rownames(hydro) <- NULL

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # no gaps
plot(hydro$date, hydro$q) # looks fine

################################################################################
# Archive it
overwrite <- FALSE
#archive <- archive.data(wd, hydro, sitename, type, overwrite)
# This throws an error, unknown why
# But we will fix the 30 minute gap manually
splices <- read.csv("splices.csv")
unique(splices$method)
unique(splices$type)
splice.meta.add(wd, "sr1", "2025-01-07 14:00:00", "2025-01-07 14:00:00", "level", "gap", "copy.last.reading", NA)
splice.meta.add(wd, "sr1", "2025-01-07 14:00:00", "2025-01-07 14:00:00", "q", "gap", "copy.last.reading", NA)
setwd(wd.archive)
load("sr1.hydro.rda")
new <- data.frame(date = sr1.hydro$date[nrow(sr1.hydro)]+900,
                  timestamp = as.numeric(sr1.hydro$date[nrow(sr1.hydro)]+900),
                  site = "sr1",
                  level = 0.1112716,
                  q = 0.05552169)
sr1.hydro <- rbind(sr1.hydro, new)
save(sr1.hydro, file = "sr1.hydro.rda")
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Done

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
gaplist <- allgaps(vwc, 15) # no gaps

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
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # good
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # good
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # good
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # good

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # good
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # good
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # good
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # good

# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc) <- NULL

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# Done
