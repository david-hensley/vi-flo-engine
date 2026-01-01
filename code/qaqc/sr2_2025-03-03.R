# Importing Salt River 2
# WEATHER 2025-01-08 to 2025-06-30
# HYDRO   2025-01-07 to 2025-03-03
# VWC     2025-01-08 to 2025-06-30
# Weather station stopped working circa January 8th 2025 - interrupted data - UVI weather data instead
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
# We have to use SR1 data here until SR2 can be re-installed
type <- "weather"
setwd(wd.archive); load("sr1.weather.rda"); load("sr2.weather.rda")
weather <- sr1.weather
################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)

# This has the effect of writing sr1 weather data onto the SR2 weather archive for the missing period!
# We must therefore write a splice.meta.add()
splices <- read.csv("splices.csv")
unique(splices$method)
unique(splices$type)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "precip", "splice", "neighbor.atmos", NA)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "rad", "splice", "neighbor.atmos", NA)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "temp", "splice", "neighbor.atmos", NA)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "rh", "splice", "neighbor.atmos", NA)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "wind", "splice", "neighbor.atmos", NA)
splice.meta.add(wd, "sr1", "2025-01-08 22:45:00", "2025-06-30 14:00:00", "pres", "splice", "neighbor.atmos", NA)

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################

type <- "hydro"
# The backup is used henceforward at SR2
ranges2 <- dateranges(wd, "sr2backup")
start2 <- ranges2$startstring[ranges$type==type]
end2 <- ranges2$endstring[ranges$type==type]
hydro <- multi.import(wd,"sr2backup", type, start2, end2)

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
# a few values appear to be erroneously low
subset <- hydro[hydro$date < "2024-08-15 15:45:00",]
plot(subset$date, subset$level)
hydro$level[hydro$date < "2024-08-15 15:15:00"] <- hydro$level[hydro$date=="2024-08-15 15:15:00"]
plot(hydro$date, hydro$level) # Fixed, now add the splice record
splices <- read.csv("splices.csv")
unique(splices$type)
unique(splices$method)
splice.meta.add(wd, "sr2", "2024-08-15 11:45:00", "2024-08-15 15:00:00", "level", "splice", "copy.next.reading", NA)

subset <- hydro[hydro$date < "2024-08-22 03:00:00" & hydro$date > "2024-08-21 21:00:00",]
plot(subset$date, subset$level)
hydro$level[hydro$date >= "2024-08-21 23:00:00" & hydro$date < "2024-08-22 00:00:00"] <- hydro$level[hydro$date=="2024-08-22 00:00:00"]
plot(hydro$date, hydro$level) # Fixed, now add the splice record
splice.meta.add(wd, "sr2", "2024-08-21 23:00:00", "2024-08-21 23:45:00", "level", "splice", "copy.next.reading", NA)
rownames(hydro) <- NULL

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # no gaps
plot(hydro$date, hydro$q) # looks good

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# done

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
gaplist <- allgaps(vwc, 15) # one small hiccup - observations not evenly spaced, NA given

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
# Perform manual QA/QC as necessary

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") 
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") 
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") 
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") 
# failed within days of last import... SB interrupted

# Reform into a single df once finished
vwc <- vwc.hs
rownames(vwc) <- NULL

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# Done
