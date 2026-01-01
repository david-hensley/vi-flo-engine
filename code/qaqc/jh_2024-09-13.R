# Importing Jolly Hill
# WEATHER NA         to NA
# HYDRO   2023-08-01 to 2024-09-13
# VWC     NA         to NA
# Does not yet have dedicated weather station, but we can use R2R
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
plot(hydro$date, hydro$level)
# A data gap occurred around New Years 2024, we must deal with it manually
hydro1 <- multi.import(wd, sitename, type, "20230801", "20231230")
hydro2 <- multi.import(wd, sitename, type, "20240201", "20240913")
hydro <- rbind(hydro1, hydro2)

################################################################################
#############                 HYDROGRAPH DATA QA/QC                #############
################################################################################
# Ensures evenly spaced time intervals, fills gaps of <1 hours for water level
# and produces a summary of remaining gaps
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # the gap is also in $site for some reason, so fix this
hydro$site <- sitename
gap.print(hydro, 15) # fixed

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
# This function zeroes NAs, but we must add them back in from our known gap
hydro$level[hydro$date >= "2023-12-30 00:45:00" & hydro$date <= "2024-02-01 08:00:00"] <- NA
plot(hydro$date, hydro$level) # solved
# Otherwise hydrograph looks good
rownames(hydro) <- NULL

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!
# Four new points require a corresponding level from the hydrograph
setwd(wd.sites); qfits <- read.csv("qfits.csv")
qfits$date <- as.POSIXct(qfits$date, tz = "America/Port_of_Spain")
qfits$level[!is.na(qfits$date) & qfits$date == "2024-02-26 16:00"] <- hydro$level[hydro$date == "2024-02-26 16:00"]
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-13 16:00"] <- hydro$level[hydro$date == "2024-08-13 16:00"]
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 10:30"] <- hydro$level[hydro$date == "2024-08-14 10:30"]
qfits$level[!is.na(qfits$date) & qfits$date == "2024-08-14 11:15"] <- hydro$level[hydro$date == "2024-08-14 11:15"]
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
reason <- "Creating curve for Jolly Hill based on 5 points"
new.qcurve <- qcurve
# Add this to the permanent record
add.qcurve(wd, new.qcurve, sitename, reason)

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
# Still dealing with human error gap manually
gapstart <- "2023-12-30 00:45:00"; gapend <- "2024-02-01 08:00:00"
hydro1 <- hydro[hydro$date < gapstart,]; hydro2 <- hydro[hydro$date > gapend,]
hydro1 <- qflux(wd, hydro1, sitename)
hydro2 <- qflux(wd, hydro2, sitename)
hydro$q[hydro$date < gapstart] <- hydro1$q
hydro$q[hydro$date > gapend] <- hydro2$q

hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # gap remains in q and level, has been recorded in splices
plot(hydro$date, hydro$q) # reasonable

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# success


