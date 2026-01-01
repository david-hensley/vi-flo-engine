# Importing Salt River 1, upstream site
# WEATHER 2021-10-13 to 2024-09-23
# HYDRO   2021-11-24 to 2024-09-13
# VWC     2022-05-26 to 2024-09-23
# But SR2 weather data used before 2022-09-13 13:00:00
# You must, as a result, run SR2 for the first before this for the first time.
################################################################################
######               PACKAGES, FUNCTIONS AND WD INFORMATION               ######
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly); setwd(wd.archive)
sitename <- "sr1"
ranges <- dateranges(wd, sitename); run.started <- Sys.time() # Proceed with acknowledgement if prompted
ranges[2,1] <- "hydro"
ranges[1,1] <- "weather"
ranges[3,1] <- "vwc"
ranges[2,2] <- "2021-11-24"
ranges[2,3] <- "20211124"
ranges[2,4] <- "2024-09-13"
ranges[2,5] <- "20240913"

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
# This station was deployed elsewhere (La Grange breadfruit orchard) till
# 2022-09-13 13:00:00, when it came online at SR1. Thus, subset this.
weather <- weather[weather$date >= "2022-09-13 13:00:00",]
# Ensures evenly spaced time intervals, fills gaps of <12 hours for weather
# variables and <1 hour for precip, produces summary of remaining gaps
weather <- auto.qaqc(wd, weather)
gaplist <- allgaps(weather, 15) # a number of gaps in non-precip, 
# includes a very long gap 2024-05-06 16:00 to 2025-07-10 12:30
# And a total lack of pressure information - pull pressure from SR2
setwd(wd.archive); load("sr2.weather.rda")
splice.meta.add(wd, sitename, "2022-09-13 13:00:00", "2024-09-23 19:00:00", "pres", "gap", "neighbor.atmos", NA)

weather$pres <- sr2.weather$pres[sr2.weather$date >= "2022-09-13 13:00:00" & sr2.weather$date <= "2024-09-23 19:00:00"]
# Get the elev difference between the WEATHER STATIONS not the stream gauges! Coords pulled from Zentra cloud manually!
elev <- get.elev(17.7606071, -64.8000398) - get.elev(17.7536017, -64.7755428)
# Correct the pressure from SR2
weather <- pres.correct(wd, weather, elev)
# Supply rad, temp, rh, and wind from SR2
# With a universal correction coefficient
splice.meta.add(wd, sitename, "2024-05-06 16:00:00", "2024-07-10 12:30:00", "rad", "gap", "neighbor.atmos", NA)

weather$rad[weather$date >= "2024-05-06 16:00:00" & weather$date <= "2024-07-10 12:30:00"] <- 
  (sr2.weather$rad[sr2.weather$date >= "2024-05-06 16:00:00" & sr2.weather$date <= "2024-07-10 12:30:00"]) *
  (mean(weather$rad, na.rm = TRUE)/mean(sr2.weather$rad))
# Same with temp
splice.meta.add(wd, sitename, "2024-05-06 16:00:00", "2024-07-10 12:30:00", "temp", "gap", "neighbor.atmos", NA)

weather$temp[weather$date >= "2024-05-06 16:00:00" & weather$date <= "2024-07-10 12:30:00"] <- 
  (sr2.weather$temp[sr2.weather$date >= "2024-05-06 16:00:00" & sr2.weather$date <= "2024-07-10 12:30:00"]) *
  (mean(weather$temp, na.rm = TRUE)/mean(sr2.weather$temp))
# Same with rh
splice.meta.add(wd, sitename, "2024-05-06 16:00:00", "2024-07-10 12:30:00", "rh", "gap", "neighbor.atmos", NA)

weather$rh[weather$date >= "2024-05-06 16:00:00" & weather$date <= "2024-07-10 12:30:00"] <- 
  (sr2.weather$rh[sr2.weather$date >= "2024-05-06 16:00:00" & sr2.weather$date <= "2024-07-10 12:30:00"]) *
  (mean(weather$rh, na.rm = TRUE)/mean(sr2.weather$rh))
# Same with wind
splice.meta.add(wd, sitename, "2024-05-06 16:00:00", "2024-07-10 12:30:00", "wind", "gap", "neighbor.atmos", NA)

weather$wind[weather$date >= "2024-05-06 16:00:00" & weather$date <= "2024-07-10 12:30:00"] <- 
  (sr2.weather$wind[sr2.weather$date >= "2024-05-06 16:00:00" & sr2.weather$date <= "2024-07-10 12:30:00"]) *
  (mean(weather$wind, na.rm = TRUE)/mean(sr2.weather$wind))
# The remaining gaps, in wind, can be handled with daytime interp
weather <- interp(wd, weather, "wind", 15)
gaplist0 <- allgaps(weather, 15) # only precip remains

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # fine
plot(weather$date, weather$temp)  # fine
plot(weather$date, weather$rh)    # handful of extreme low values
plot(weather$date, weather$wind)  # fine
plot(weather$date, weather$pres)  # fine
# If any manual QA/QC is needed, perform it here
# Use splice.meta.add() before performing any direct manual data editing
# and use quick.index.interp() for quick interpolation by index which will perform splice for you, e.g.
weather <- quick.index.interp(wd, sitename, weather, "rh", which(weather$date == "2023-07-30 00:00:00"), which(weather$date == "2023-07-30 00:30:00"))
weather <- quick.index.interp(wd, sitename, weather, "rh", which(weather$date == "2023-02-11 00:00:00"), which(weather$date == "2023-02-11 00:30:00"))
weather <- quick.index.interp(wd, sitename, weather, "rh", which(weather$date == "2024-09-11 00:00:00"), which(weather$date == "2024-09-11 00:30:00"))

# Plot again when needed to check for success
plot(weather$date, weather$rh)    # fixed

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Import SR2 precip for the very long gap
splice.meta.add(wd, sitename, "2024-05-06 16:00:00", "2024-07-10 12:30:00", "precip", "gap", "neighbor.atmos", NA)

weather$precip[weather$date >= "2024-05-06 16:00:00" & weather$date <= "2024-07-10 12:30:00"] <- 
  (sr2.weather$precip[sr2.weather$date >= "2024-05-06 16:00:00" & sr2.weather$date <= "2024-07-10 12:30:00"])
gaplist0 <- allgaps(weather, 15) # Filled the very long gap

# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # gaps eliminated
plot(weather$date, weather$precip) # looks good

################################################################################
# Next we will attach the archive from SR2 until the beginning of the hydro period
# Starting 2021-11-24 14:30:00 to 2022-09-13 12:45:00
setwd(wd.archive); load("sr2.weather.rda")
sr2.add <- sr2.weather[sr2.weather$date >= "2021-11-24 14:30:00" & sr2.weather$date <= "2022-09-13 12:45:00",]
# Perform pressure correction incoming SR2 pressure
sr2.add <- pres.correct(wd, sr2.add, elev)

# Attach to the SR1 weather record
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "precip", "gap", "neighbor.atmos", NA)
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "rad", "gap", "neighbor.atmos", NA)
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "temp", "gap", "neighbor.atmos", NA)
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "rh", "gap", "neighbor.atmos", NA)
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "wind", "gap", "neighbor.atmos", NA)
splice.meta.add(wd, sitename, "2021-11-24 14:30:00", "2022-09-13 12:45:00", "pres", "gap", "neighbor.atmos", NA)
weather <- rbind(sr2.add, weather)
attachpoint <- as.POSIXct("2022-09-13 12:45:00", tz = "America/Port_of_Spain")
# Now visual check before archiving
plot(weather$date, weather$rad); abline(v = attachpoint, col = "red", lty = 2)    # fine
plot(weather$date, weather$temp); abline(v = attachpoint, col = "red", lty = 2)   # fine 
plot(weather$date, weather$rh); abline(v = attachpoint, col = "red", lty = 2)     # fine
plot(weather$date, weather$wind); abline(v = attachpoint, col = "red", lty = 2)   # fine
plot(weather$date, weather$pres); abline(v = attachpoint, col = "red", lty = 2)   # fine
plot(weather$date, weather$precip); abline(v = attachpoint, col = "red", lty = 2) # fine 

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# Success

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
type <- "hydro"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
hydro <- multi.import(wd, sitename, type, start, end)
p <- plot_ly(data = mtcars, x = ~wt, y = ~mpg, type = 'scatter', mode = 'lines', name = 'Line 1'); p

plot(hydro$date, hydro$level)
# Internal barometer failed for water level calculation 
# Error period starting at 2022-09-20 04:30:00, ending at 2023-08-02 13:00:00 (inclusive)
# Re-import the erroneous period
setwd(wd.level)
fix.baro <- read.csv("sr1_hydro_20211124-20230802.csv", header = FALSE)
fix.baro <- hobo.import(fix.baro)
fix.baro <- fix.baro[fix.baro$date >= "2022-09-20 04:30:00" & fix.baro$date <= "2023-08-02 13:00:00",]
fix.baro$pres <- NULL; fix.baro$level <- NULL
# Run this re-imported raw data as though hoboware logger to use weather station pressure
fix.baro <- hoboware.import(wd, fix.baro, sitename)
# Write the splice info
splice.meta.add(wd, sitename, "2022-09-20 04:30:00", "2023-08-02 13:00:00", "level", "splice", "new.pres.input", NA)
# Perform the splicing
hydro$level[hydro$date >= min(fix.baro$date) & hydro$date <= max(fix.baro$date)] <- fix.baro$level
plot(hydro$date, hydro$level) # almost all solved, will address the outliers in next step

# Due to streambed scouring producing false zeroes in the hobolink logger, the hoboware backup must be brought in
ranges2 <- dateranges(wd, "sr1backup")

start2 <- ranges2$startstring[ranges$type==type]
end2 <- ranges2$endstring[ranges$type==type]
hydro2 <- multi.import(wd,"sr1backup", type, start2, end2)
# Did not actual deploy this logger in the intended position till 2023-11-14 11:30:00
hydro2 <- hydro2[hydro2$date >= "2023-11-14 11:30:00",]

# conduct a comparison of each to look for where to make the scouring correction in the original data
plot(hydro$date[hydro$date >= "2023-09-14 11:30:00"], hydro$level[hydro$date >= "2023-09-14 11:30:00"], type = "l", col = "blue")
lines(hydro2$date, hydro2$level, col = "red")
# This confirms that the scouring event took place in Nov 2023, or TS Nicole's floods
# We will therefore apply a depth correction to the hydrograph of the Nicole event in the original data, 
# and from that point going forward, will use the backup hydrograph as the main hydrograph. 
plot(hydro$date[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], hydro$level[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], type = "l", col = "blue")
lines(hydro2$date, hydro2$level, col = "red")
nicole.firstpeak <- "2023-10-27 23:30:00" # identified as the initial spike in the Nicole flow - where the scouring likely occurred
# Examining the data and based on field measurements, a correction of 13 cm will create an acceptable Nicole hydrograph
#### RECORD THE SPLICE/CORRECTED DATA!!
splice.meta.add(wd, sitename, "2023-10-27 23:30:00", "2023-11-14 11:15:00", "level", "splice", "scour.correction", NA)
hydro$level[hydro$date >= nicole.firstpeak] <- hydro$level[hydro$date >= nicole.firstpeak] + 0.13
plot(hydro$date[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], hydro$level[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], type = "l", col = "blue")
lines(hydro2$date, hydro2$level, col = "red") 
# This looks good, now interpolate 2023-11-14 11:15:00
splice.meta.add(wd, sitename, "2023-11-14 11:30:00", "2023-11-14 11:30:00", "level", "splice", "copy.last.reading", NA)
hydro$level[hydro$date == "2023-11-14 11:30:00"] <- hydro$level[hydro$date == "2023-11-14 11:15:00"]

# Backup was live at 2023-11-14 11:45:00
hydro2 <- hydro2[hydro2$date >= "2023-11-14 11:45:00",]
# Overwrite hobolink with hoboware
# No splice for this because it is indefinite from now on
hydro <- hydro[hydro$date < "2023-11-14 11:45:00",]
hydro <- rbind(hydro, hydro2)
plot(hydro$date, hydro$level) # It likely worked, though manual QA/QC needed, so check the area of interest too:
plot(hydro$date[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], hydro$level[hydro$date >= "2023-10-25" & hydro$date <= "2023-12-15"], type = "l", col = "blue")
# Looks good, now let's fix the outlier errors below

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
# Several large outlier mistakes remain to fix
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-08-02 11:30:00"), which(hydro$date == "2023-08-02 12:45:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-12-28 12:30:00"), which(hydro$date == "2023-12-28 12:30:00"))
# After 2022-11-17 01:00:00 there is need of a correction to erroneously high level reading
splice.meta.add(wd, sitename, "2022-11-17 01:00:00", "2024-09-13 09:00:00", "level", "correction", "corrected.level", NA)
hydro$level[hydro$date >= "2022-11-17 01:00:00"] <- hydro$level[hydro$date >= "2022-11-17 01:00:00"] - 0.0265
hydro$level[hydro$level < 0.00000001] <- 0.00000001
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-05-06 15:45:00"), which(hydro$date == "2024-05-06 15:45:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-03-29 20:15:00"), which(hydro$date == "2024-03-29 20:15:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-08-02 11:30:00"), which(hydro$date == "2023-08-02 13:00:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-11-21 16:45:00"), which(hydro$date == "2023-11-21 17:00:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-11-28 12:45:00"), which(hydro$date == "2023-11-28 12:45:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-02-15 12:15:00"), which(hydro$date == "2024-02-15 12:45:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-02-23 15:00:00"), which(hydro$date == "2024-02-23 15:00:00"))
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-12-28 12:15:00"), which(hydro$date == "2023-12-28 12:30:00"))

plot(hydro$date, hydro$level) # Greatly improved
rownames(hydro) <- NULL

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!
# Two new points were measured in TS Ernesto, we will update qfits.csv
setwd(wd.sites); qfits <- read.csv("qfits.csv")
qfits$date <- as.POSIXct(qfits$date, tz = "America/Port_of_Spain")
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 14:15"] <- hydro$level[hydro$date == "2024-08-14 14:15"]
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 14:45"] <- hydro$level[hydro$date == "2024-08-14 14:45"]
write.csv(qfits, "qfits.csv", row.names = FALSE)
# Bring in the alt sitename
sites <- read.csv("site-ids.csv"); altname <- sites$site.alt[sites$sitename == sitename]
# Read latest qcurves full record to subset
qcurves <- read.csv("qcurves.csv")
qcurve <- qcurves[qcurves$site == sitename,]
# Run the rating curve fit function to overwrite discharge in this site's qcurve
qcurve <- fit.qcurve(qfits, altname, qcurve)
# check the curve against qfits
qfit <- qfits[qfits$site == altname,]
plot(qfit$q, qfit$level)
lines(qcurve$q, qcurve$level, type="l", col="blue", lwd = 1.5) # Looks good!

# Write the reason we have a new qcurve for the metadata
reason <- "New SR1 points measured in TS Ernesto"
new.qcurve <- qcurve
# Add this to the permanent record
add.qcurve(wd, new.qcurve, sitename, reason)

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gaps(hydro) # no gaps
plot(hydro$date, hydro$q) # Looks reasonable

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Success!

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
gaplist <- allgaps(vwc, 15) # A great many gaps remain

# setting a threshold of rainfall below which we allow auto gap filling, 6mm is normal
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # [comment here]

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Check by type, begin with hs 
vwc.hs <- vwc[vwc$type == "hs",]
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # First 6 values still equilibrating
vwc.hs <- vwc.hs[c(7:nrow(vwc.hs)),]
rownames(vwc.hs) <- NULL
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # ok
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # ok
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # ok
rownames(vwc.hs) <- NULL

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL

plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # First 8 values to drop
vwc.sb <- vwc.sb[c(9:nrow(vwc.sb)),]
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # Still has some extreme high values
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # ok
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # ok
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # extreme low value
# Perform manual QA/QC as necessary
splice.meta.add(wd, sitename, "2023-09-29 01:45:00", "2023-09-29 01:45:00", "cm100.sb", "splice", "copy.last.reading", NA)
vwc.sb$cm100[vwc.sb$date == "2023-09-29 01:45:00"] <- vwc.sb$cm100[vwc.sb$date == "2023-09-29 01:30:00"]
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # solved

splice.meta.add(wd, sitename, "2023-10-02 17:00:00", "2023-10-02 17:00:00", "cm10.sb", "splice", "copy.next.reading", NA)
vwc.sb$cm10[vwc.sb$date == "2023-10-02 17:00:00"] <- vwc.sb$cm10[vwc.sb$date == "2023-10-02 17:15:00"]
splice.meta.add(wd, sitename, "2023-09-29 01:45:00", "2023-09-29 01:45:00", "cm10.sb", "splice", "copy.last.reading", NA)
vwc.sb$cm10[vwc.sb$date == "2023-09-29 01:45:00"] <- vwc.sb$cm10[vwc.sb$date == "2023-09-29 01:30:00"]
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # solved

# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc) <- NULL

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# Success, though the large VWC gaps remain!






