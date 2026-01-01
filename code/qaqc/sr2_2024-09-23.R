# Importing Salt River 2 (downstream site)
# WEATHER 2021-07-13 to 2024-09-23
# HYDRO   2021-11-22 to 2024-09-13
# VWC     2022-05-17 to 2024-09-23
# [Write any relevant notes about the run here, such as a new qcurve being run]
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
gaplist <- allgaps(weather, 15) # a number of gaps in non-precip

weather <- interp(wd, weather, "rad", 15); weather <- interp(wd, weather, "temp", 15)
weather <- interp(wd, weather, "rh", 15); weather <- interp(wd, weather, "wind", 15); weather <- interp(wd, weather, "pres", 15)
gaplist0 <- allgaps(weather, 15) # only precip gaps remain

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # fine
plot(weather$date, weather$temp)  # fine
plot(weather$date, weather$rh)    # a few rather low values at times but not outright errors most likely
plot(weather$date, weather$wind)  # possible outliers towards the end
plot(weather$date, weather$pres)  # fine
# If any manual QA/QC is needed, perform it here
# Use splice.meta.add() before performing any direct manual data editing
# and use quick.index.interp() for quick interpolation by index which will perform splice for you
# Remove the ultra-high wind values
weather <- quick.index.interp(wd, sitename, weather, "wind", which(weather$date == "2024-09-21 05:00:00"), which(weather$date == "2024-09-21 05:30:00"))
weather <- quick.index.interp(wd, sitename, weather, "wind", which(weather$date == "2024-08-26 03:15:00"), which(weather$date == "2024-08-26 03:45:00"))
weather <- quick.index.interp(wd, sitename, weather, "wind", which(weather$date == "2024-08-26 03:00:00"), which(weather$date == "2024-08-26 03:30:00"))
weather <- quick.index.interp(wd, sitename, weather, "wind", which(weather$date == "2024-04-13 00:30:00"), which(weather$date == "2024-04-13 01:15:00"))
# Plot again when needed to check for success
plot(weather$date, weather$wind)  # Fixed

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather) # Major malfunctions in 2024
gaplist0 <- allgaps(weather, 15) # Gaps are gone
plot(weather$date, weather$precip) # Hugely improved

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# Archive created

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
type <- "hydro"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
hydro <- multi.import(wd, sitename, type, start, end)
# The hobolink logger battery charging failed in Aug 2024; backup must be engaged
ranges2 <- dateranges(wd, "sr2backup")

start2 <- ranges2$startstring[ranges$type==type]
end2 <- ranges2$endstring[ranges$type==type]
hydro2 <- multi.import(wd,"sr2backup", type, start2, end2)
# Backup was live at 2024-08-15 16:00:00
hydro2 <- hydro2[hydro2$date >= "2024-08-15 16:00:00",]
plot(hydro$date[hydro$date >= "2024-08-15 16:00:00"], hydro$level[hydro$date >= "2024-08-15 16:00:00"], type = "p", col = "blue")
# Hobolink died at 2024-08-17 05:15:00
plot(hydro2$date[hydro2$date <= "2024-08-17 05:15:00"], hydro2$level[hydro2$date <= "2024-08-17 05:15:00"], col="red", pch=19)
# Hoboware requires a 3.5cm correction
hydro2$level <- hydro2$level + 0.035
# And a 6.1 cm correction post 2024-08-23 15:15:00, related to a physical data purge redeployment error
hydro2$level[hydro2$date >= "2024-08-23 15:15:00"] <- hydro2$level[hydro2$date >= "2024-08-23 15:15:00"] + 0.061
plot(hydro2$date[hydro2$date <= "2024-08-17 05:15:00"], hydro2$level[hydro2$date <= "2024-08-17 05:15:00"], col="red", pch=19)
# Overwrite hobolink with hoboware
hydro <- hydro[hydro$date < "2024-08-15 16:00:00",]
hydro <- rbind(hydro, hydro2)
plot(hydro$date, hydro$level) # It worked, though manual QA/QC needed

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
# This removed the fake negatives from hoboware backup but still needs a small correction
# Same manual process as above:
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-08-21 22:45:00"), which(hydro$date == "2024-08-22 00:00:00"))
plot(hydro$date, hydro$level) # fixed
rownames(hydro) <- NULL

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!
# Two new points were measured in TS Ernesto, we will update qfits.csv
setwd(wd.sites); qfits <- read.csv("qfits.csv")
qfits$date <- as.POSIXct(qfits$date, format = "%m/%d/%Y %H:%M", tz = "America/Port_of_Spain")
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 15:45"] <- hydro$level[hydro$date == "2024-08-14 15:45"]
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 16:15"] <- hydro$level[hydro$date == "2024-08-14 16:15"]
write.csv(qfits, "qfits.csv", row.names = FALSE)

# Because we have a GZF measured and a rating curve to fit, we will use
# the approach outlined in Kennedy (1984) with a logarithmic rating curve. Note
# here that, as is standard in hydrology, Q is the x-axis and level (D) is y-axis.
sites <- read.csv("site-ids.csv"); altname <- sites$site.alt[sites$sitename == sitename]
# Read latest qcurves full record to subset
qcurves <- read.csv("qcurves.csv"); qfits <- read.csv("qfits.csv")
qcurve <- qcurves[qcurves$site == sitename,]
# Run the kennedy function to overwrite discharge in this site's qcurve
qcurve <- kennedy(qfits, altname, qcurve)
# check the curve against qfits
qfit <- qfits[qfits$site == altname & qfits$level != 0,]
plot(qfit$q, qfit$level)
lines(qcurve$q, qcurve$level, type="l", col="blue", lwd = 1.5) # Looks good!

# Write the reason we have a new qcurve for the metadata
reason <- "New SR2 points measured in TS Ernesto"
new.qcurve <- qcurve
# Add this to the permanent record
add.qcurve(wd, new.qcurve, sitename, reason)

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gaps(hydro) # no gaps
plot(hydro$date, hydro$q) # Looks good, though of course the flood event is suspect

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# Successfully written

################################################################################
#############                    VWC IMPORTATION                   #############
################################################################################
type <- "vwc"
start <- ranges$startstring[ranges$type==type]
end <- ranges$endstring[ranges$type==type]
vwc <- multi.import(wd, sitename, type, start, end) 
# Causes a small gap in HS 2023-11-09 00:00:00 but autoqaqc should fill this

################################################################################
#############                       VWC QA/QC                      #############
################################################################################
vwc <- vwc.qaqc(wd, vwc)
gaplist <- allgaps(vwc, 15) # many gaps remain, some major

# setting a threshold of rainfall below which we allow auto gap filling, 6mm is normal
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # unfortunately many gaps remain

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Check by type, begin with hs 
vwc.hs <- vwc[vwc$type == "hs",]
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # first 3 values should be dropped
vwc.hs <- vwc.hs[c(4:nrow(vwc.hs)),]
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # fixed
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # looks good
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # looks good
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # looks good

vwc.sb <- vwc[vwc$type == "sb",] 
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # first 3 values should be dropped
vwc.sb <- vwc.sb[c(4:nrow(vwc.sb)),]
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # looks good
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # looks good
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # erroneous drop after 2024-07
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # looks good
# The drop does look strange but could be natural, so retaining it
# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc)<-NULL

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# written succesfully



