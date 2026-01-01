# Importing Fish Bay
# WEATHER 2021-10-21 to 2024-08-20
# HYDRO   2021-10-21 to 2024-06-05
# VWC     2022-09-22 to 2024-06-05
# Slope model and new qcurves.
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
sitename <- "fb"
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

# We are told there were gaps in the record, likely when the weather station was moved
# A number of gaps identified, many in precip, a few in rad, temp, rh, wind, and pres
# which we will interpolate - likely again related to the weather station moving
weather <- interp(wd, weather, "rad", 15); weather <- interp(wd, weather, "temp", 15)
weather <- interp(wd, weather, "rh", 15); weather <- interp(wd, weather, "wind", 15); weather <- interp(wd, weather, "pres", 15)
gaplist0 <- allgaps(weather, 15) # dealt with except for precip

# HOWEVER!! We do still need to correct the pressure reading for when the station 
# was moved from the seacoast uphill. This will be obvious in these plots
plot(weather$date, weather$rad)   # fine
plot(weather$date, weather$temp)  # fine
plot(weather$date, weather$rh)    # fine
plot(weather$date, weather$wind)  # fine
plot(weather$date, weather$pres)  # obvious problem
# First replace the readings from when we were ascending the mountain with the previous reading
# But you must always first record the splice in case it alerts of an override
splice.meta.add(wd, sitename, "2024-02-06 08:45:00", "2024-02-06 10:00:00", "pres", "splice", "copy.last.reading", NA)

weather$pres[weather$date >= "2024-02-06 08:45:00" & weather$date <= "2024-02-06 10:00:00"] <- weather$pres[weather$date == "2024-02-06 08:30:00"]
# Now the pressure correction itself
#Extract everything before the station was installed in its new location and cut out the rest
splice.meta.add(wd, sitename, "2021-10-21 16:00:00", "2024-02-06 10:15:00", "pres", "correction", "elev.formula", NA)

weather0 <- weather[weather$date < "2024-02-06 10:15:00",]; weather <- weather[weather$date >= "2024-02-06 10:15:00",]
# Get the elevation difference between old deployment and new - negative means it went up
setwd(wd.sites); elevs <- read.csv("elevs.csv"); elev <- elevs$elev[elevs$site == sitename]
# To calculate the correction we also need g and density of air at known temperature (which we assume is 30 C in the USVI)
airdense30c <- 1.1644; g <- 9.8 # acceleration of gravity
gpo <- g*airdense30c; p0 <- weather0$pres # measured pressure given in kPa
p0 <- p0*1000; gp0 <- gpo/p0; weather0$pres <- p0*exp(-gp0*-elev)/1000
weather <- rbind(weather0, weather)
plot(weather$date, weather$pres) # remove extreme low value below 93 kpa
weather <- quick.index.interp(wd, sitename, weather, "pres", 18409, 18411)

plot(weather$date, weather$pres) # fixed

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # dealt with all
plot(weather$date, weather$precip) # Certainly much improved!

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# No error messages indicating new archive is good

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
# Some extreme values appear to occur that are likely not natural
# Points at 2021-12-23 04:15:00 and 2021-12-23 04:30:00 are bogus
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2021-12-23 04:15:00"), which(hydro$date == "2021-12-23 04:30:00"))
# Another of these occurs at 2023-11-05 14:15:00 to 14:45:00
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-11-05 14:15:00"), which(hydro$date == "2023-11-05 14:45:00"))
# Another of these occurs at 2024-04-13 23:00:00 to 23:00:00
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2024-04-13 23:00:00"), which(hydro$date == "2024-04-13 23:00:00"))
# Another of these occurs at 2023-11-15 10:30:00 to 10:45:00, this time abnormally low level
hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2023-11-15 10:30:00"), which(hydro$date == "2023-11-15 10:45:00"))
plot(hydro$date, hydro$level) # Looks good
rownames(hydro) <- NULL

# CANNOT ARCHIVE YET - NEED TO CALCULATE DISCHARGE, BUT TO DO THIS WE NEED
# THE HYDRAULIC SLOPE CURVE, WHICH WE CALCULATE IN THE FOLLOWING SEGMENT

################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
#############                                                      #############
#############              HYDRAULIC SLOPE REGRESSION              #############
#############                                                      #############
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
dist <- -50.687 #negative because downstream
height <- -0.253 #negative because below reference - downstream
slope.sitename <- "fbslope"
ranges.slope <- dateranges(wd, slope.sitename) # Acknowledge the dates

slope.start <- ranges.slope$startstring[ranges.slope$type==type]; slope.end <- ranges.slope$endstring[ranges.slope$type==type]
hydro.slope <- multi.import(wd, slope.sitename, type, slope.start, slope.end)
gaps(hydro.slope) # No gaps
# Further QA/QC is needed for water level to calculate discharge correctly
hydro.slope <- level.qaqc(wd, hydro.slope, sitename) 
# The deployment was not actual until 2024-02-05 12:05:00
hydro.slope <- hydro.slope[hydro.slope$date > "2024-02-05 12:05:00 AST",]
plot(hydro.slope$date, hydro.slope$level) # Looks good
hydro.slope$level.slope <- hydro.slope$level; hydro.slope$level <- NULL
rownames(hydro.slope) <- NULL
################################################################################
# Now we bring in the slope logger data by performing a left join
hydro <- hydro %>%
  left_join(hydro.slope, by = "date")
# Subset only the common rows to create a relationship
df.slope <- hydro[!is.na(hydro$level.slope),]
# View a plot to see if the relationship is real
plot(df.slope$date, df.slope$level, type = "l", col = "blue", lwd = 2, 
     ylim = c(min(df.slope$level, df.slope$level.slope), max(df.slope$level, df.slope$level.slope)))
lines(df.slope$date, df.slope$level.slope, col = "red", lwd = 2)
# Plot the difference
df.slope$diff <- df.slope$level.slope - df.slope$level
# The difference does change some over time
plot(df.slope$date, df.slope$diff, type = "l", col = "blue", lwd = 2)
# Look at it against the reference water level
df.slope0 <- df.slope
df.slope[nrow(df.slope)+1,] <- NA
df.slope$level[nrow(df.slope)] <- 0
df.slope$diff[nrow(df.slope)] <- 0
df.slope <- df.slope[order(df.slope$level), ]
plot(df.slope$level, df.slope$diff, type = "l", col = "blue", lwd = 2)

# This is extremely interesting - we see a perfect -1 slope line that shows us
# how the main logger, found in a pool, can show water level in the absence of 
# any water at the downstream slope logger. We can actually use this to glean
# a GZF for this site, but to do so we need to find the exact level where 
# water appears at the downstream location. So I will perform some subsets and find.
sub <- df.slope[df.slope$level >= 0.2 & df.slope$level <= 0.3,]
plot(sub$level, sub$diff) # It is a bit clearer here - somewhere between 0.24 and 0.26
sub <- df.slope[df.slope$level >= 0.24 & df.slope$level <= 0.26,]
plot(sub$level, sub$diff) # A few ocurrences of flow blow 0.255, but 0.255 is a fair GZF
sub <- df.slope[df.slope$level >= 0.255,]
gzf <- 0.255
plot(sub$level, sub$diff) # This really works well - you can see the empirical relationship
# We should, though, remove the points that fall on the perfect slope line beyond the GZF
abline(a = 0, b = -1, col = "red", lwd = 1)
# Exclude points within a 1e-7 tolerance range around the line, due to the non-zero levels
sub <- sub[!(abs(sub$diff - (-1*sub$level)) <= 1e-7), ]; plot(sub$level, sub$diff)

# Let's now get an equation for this part of the curve, then apply the GZF < 0.255
# Fit polynomial regression model (=2nd degree)
model <- lm(diff ~ poly(level, 2), data = sub)
curve(predict(model, newdata = data.frame(level = x)), add = TRUE, col = "red")

slope.model <- data.frame(level = seq(0, 5, by = 0.01))
slope.model$y <- predict(model, newdata = slope.model)
slope.model$x <- slope.model$level
slope.model <- slope.model[,c("x","y")]
plot(slope.model$x, slope.model$y)
points(sub$level, sub$diff, col = "red", pch = 17) # We need to stop this curve at the peak
# Let's accept the max of this parabola as the breakpoint to achieve constant slope
# A faux-asymptote, effective, and label this breakpt
breakpt <- slope.model$x[slope.model$y == max(slope.model$y)]
peak <- max(slope.model$y)
# Zero out the slope below the GZF, since no flow is occurring then
slope.model$y[slope.model$x < gzf] <- 0
slope.model$y[slope.model$x > breakpt] <- peak
plot(slope.model$x, slope.model$y)

# This looks good, let's use it to get hydraulic slopes
# Distance (m) between loggers, slope should be positive, so higher logger 
# was used to calculate continuous altitude. Now convert to predicted slope by levels
alt <- slope.model$y
level <- slope.model$x
slope.model <- create.slope.model(wd, alt, level, dist, height, sitename)
plot(slope.model$level, slope.model$slope)

# Revert df back to level alone with no slope level, which is no longer needed
hydro$timestamp <- hydro$timestamp.x
hydro <- hydro[,c("date","timestamp","level")]

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!

# Write the reason we have a new qcurve for the metadata
reason <- "re-ran FB with slope model, includes FB GZF at 0.255m"

# Calculate a new qcurve using the slope model
new.qcurve <- manning.qcurve(wd, sitename, TRUE)
add.qcurve(wd, new.qcurve, sitename, reason)

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gaps(hydro) # No gaps
plot(hydro$date, hydro$q) # looks ok

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# No error messages indicating new archive is good

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
plot(vwc$date, vwc$cm10) # index 46251 read the date wrong
vwc <- vwc[-46249,]; rownames(vwc) <- NULL
plot(vwc$date, vwc$cm10) # had to fix this problem before auto-qaqc
vwc <- vwc.qaqc(wd, vwc)
gaplist <- allgaps(vwc, 15) # Many gaps remain

# setting a threshold of rainfall below which we allow auto gap filling
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # This time all gaps were fillable using this process

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
vwc.sb <- vwc[vwc$type == "sb",] # Normally we will do this subset to stay consistent
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # Remove the first 4 obs from deployment
vwc.sb <- vwc.sb[c(4:nrow(vwc.sb)),]; rownames(vwc.sb) <- NULL; plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm")
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # Looks fine
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # Looks fine
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # Looks fine

# Reform into a single df once finished
# vwc <- rbind(vwc.hs, vwc.sb)
vwc <- vwc.sb

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# No error messages indicating new archive is good
