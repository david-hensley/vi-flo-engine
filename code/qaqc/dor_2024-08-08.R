# Importing Dorothea
# WEATHER 2023-06-14 to 2024-08-08
# HYDRO   2023-06-14 to 2024-06-04
# VWC     NA         to NA
# Includes regression of hydraulic slope and new qcurve calculated from slope model
################################################################################
######               PACKAGES, FUNCTIONS AND WD INFORMATION               ######
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr)
sitename <- "dor"
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

# Relatively short gaps remain in wind only
weather <- interp(wd, weather, "wind", 15)
gaplist <- allgaps(weather, 15) # dealt with 

# Visual checks
plot(weather$date, weather$rad)
plot(weather$date, weather$temp)
plot(weather$date, weather$rh)
plot(weather$date, weather$wind)
plot(weather$date, weather$pres)
plot(weather$date, weather$precip)

################################################################################
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
# Nothing got flagged for looking wrong

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
# There are two near-zero periods that are erroneous, caused by being exposed to air
# during logger handling, so these should be interpolated across their neighbors.
# This is data point 1, which will be dropped, and 17413-17515, which will be interpolated.
hydro <- quick.index.interp(wd, sitename, hydro, "level", 17413, 17415)
hydro <- hydro[2:nrow(hydro),]
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
slope.sitename <- "dorslope"
ranges.slope <- dateranges(wd, slope.sitename) # Acknowledge the dates

slope.start <- ranges.slope$startstring[ranges.slope$type==type]; slope.end <- ranges.slope$endstring[ranges.slope$type==type]
hydro.slope <- multi.import(wd, slope.sitename, type, slope.start, slope.end)
# QA/QC
hydro.slope <- auto.qaqc(wd, hydro.slope)
gaps(hydro.slope) # No gaps
# Further QA/QC is needed for water level to calculate discharge correctly
hydro.slope <- level.qaqc(wd, hydro.slope, sitename) 
# The deployment was not actual until 2024-02-04 14:05:00
hydro.slope <- hydro.slope[hydro.slope$date > "2024-02-04 14:05:00 AST",]
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

# There is some sort of relationship! We need an equation for this
break1 <- 0.12; break2 <- 0.4
# Fit the piecewise linear model with breakpoints at 0.1 and 0.3
model <- lm(df.slope$diff ~ df.slope$level +
              pmax(0, df.slope$level - break1) +
              pmax(0, df.slope$level - break2))
lines(df.slope$level, predict(model, newdata = data.frame(df.slope$level)), 
      col = "green", lwd = 2)
# Looks good, let's use this equation for the slope model at Dorothea for now
# Extract the linear coefficients from each line
# Slope of each line is given relative to the last one
b1 <- model$coefficients[1]
m1 <- model$coefficients[2]
m2 <- model$coefficients[2] + model$coefficients[3]
m3 <- m2 + model$coefficients[4]
# To calculate the intercepts beyond the one given we must solve 
# for y of the previous equation Where x is the known breakpoint 1
y1 <- m1 * break1 + b1
# Then use this to solve for b in the second equation
b2 <- y1 - (m2 * break1)
# And solve for y at the second breakpoint x with line 2
y2 <- m2 * break2 + b2
# Then solve for b3
b3 <- y2 - (m3 * break2)
# Now make 3 dfs that predict from 0 to 5 meters, 1 cm interval, for all 3
# Which we will then cut and paste together
# THE IMPORTANT CAVEAT BEING THAT PREDICTIONS OUTSIDE OF OBSERVED LEVELS ARE
# HIGHLY LIKELY TO BE ERRONEOUS THE FURTHER WE ARE FROM OBSERVED!!!!
# This means that gage heights above 1 meter are to be taken with extreme caution for now
x <- seq(0, 5, by = 0.01)
y1 <- m1 * x + b1
df1 <- data.frame(x = x, y = y1)
y2 <- m2 * x + b2
df2 <- data.frame(x = x, y = y2)
y3 <- m3 * x + b3
df3 <- data.frame(x = x, y = y3)
# Give each line its first breakpoint, meaning line 3 is non inclusive
df1 <- df1[df1$x <= break1,]
df2 <- df2[df2$x > break1 & df2$x <= break2,]
df3 <- df3[df3$x > break2,]
# And combine these into the prediction dataset
slope.model <- rbind(df1, df2, df3)
plot(slope.model$x, slope.model$y)
# This looks good, let's use it to get hydraulic slopes
# Distance (m) between loggers, slope should be positive, so higher logger 
# was used to calculate continuous altitude. Now convert to predicted slope by levels
alt <- slope.model$y
level <- slope.model$x
dist <- 9.083
height <- (5.3 - 3.58) * 0.3048
slope.model <- create.slope.model(wd, alt, level, dist, height, sitename)

# Revert df back to level alone with no slope level, which is no longer needed
hydro$timestamp <- hydro$timestamp.x
hydro <- hydro[,c("date","timestamp","level")]

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!

# Write the reason we have a new qcurve for the metadata
reason <- "deleted Adventure site and re-ran Dorothea with slope model"

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
