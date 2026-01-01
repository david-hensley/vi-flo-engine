# In this code, which could take hours to run from start to finish in entirety, 
# we document various approaches to check the validity of filling daily rain
# data gaps at a given lat/lon in the Virgin Islands using Daymet data, NASA GPM
# satellite data, and data from krigin or other spatial interpolation of the 
# combined GHCN/RAWS/CoCoRaHs archive. The end result is to find that Daymet, NASA
# and kriging are all relatively poor predictors judged by R^2, while the final
# segment investigates all these versus simply nearest-neighbor replacement. The
# end result is that nearest neighbor remains the best method, with R^2 around 0.5.
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr)

################################################################################
#####################           DAYMET VALIDATION          #####################
################################################################################
setwd(wd.weather); load("precip.archive.rda") # Load the full rain gauge archive
# To start with, Daymet goes back to 1980, so delete the archive before that
archive <- archive[archive$date >= "1980-01-01",]
stations <- unique(archive$station)
archive$daymet <- NA
for (i in 1:length(stations)){
  station <- stations[i]
  df <- archive[archive$station == station,]
  archive <- archive[archive$station != station,]
  daymet <- daymet.rain(wd, df$date[1], df$date[nrow(df)], df$lat[1], df$lon[1])
  df <- merge(df, daymet, by = "date", all = TRUE)
  df$daymet <- df$prcp; df$prcp <- NULL
  archive <- rbind(df, archive)
  archive <- archive[order(archive$station, archive$date), ]
  rownames(archive) <- NULL
}
# Save this for speed if wanted
setwd(wd.daymet); save(archive, file="daymet.archive.rda",compress="xz")
# Look only at rows that have a daymet observation
archive <- archive[!is.na(archive$daymet),]
# Plot actual vs. predicted Daymet precip
plot(archive$precip, archive$daymet, main = "Observed vs. Daymet predicted precipitation")
# Unfortunately Daymet is a really bad predictor of real rainfall at a gauge site. 
# We must use other means to interpolate rainfall at a given date and location

################################################################################
#####################          NASA GPM VALIDATION         #####################
################################################################################
setwd(wd.weather); load("precip.archive.rda") # Load the full rain gauge archive
# Take some random selection of station-days from the archive
set.seed(123)  # Set seed for reproducibility
n <- 30  # Replace with the number of rows you want to select
df <- archive[archive$date >= "2000-06-02",] # IMERG Final data begins here
df <- df[!is.na(df$precip), ]; df <- df[df$precip >= 3,] # Subset only days with some rain
rownames(df) <- NULL; random.indices <- sample(nrow(df), n)
dfs <- df[random.indices, ]; rownames(dfs) <- NULL #dfs stands for df-sample

# Calculate dailies from NASA IMERG for these
dfs$start <- as.POSIXct(dfs$date, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
# Have to correct for a strange formatting problem
datestrings <- paste0(as.character(dfs$date), " 00:00:00")
dfs$start <- as.POSIXct(datestrings, format="%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
dfs$end <- dfs$start + 3600*24; dfs$nasa <- NA
for (i in 1:nrow(dfs)){
  day <- nasa.rain(wd, dfs$lat[i], dfs$lon[i], dfs$start[i], dfs$end[i], "thucydides15", "S@lt_R1v3r_hydro", "America/Port_of_Spain")
  dailyrain <- sum(day$precip); dfs$nasa[i] <- dailyrain
  write.csv(dfs, "nasa.daily.check.csv", row.names = FALSE)
}
# Compare
dfs$diff <- dfs$precip - dfs$nasa; plot(dfs$precip, dfs$nasa) 
# NASA severely underestimates rain as well. Try kriging or IDW next.

################################################################################
###################     KRIGING/INTERPOLATION VALIDATION     ###################
################################################################################
# Here prepare a daily summary of available UVI ATMOS gauge data
atmos <- quick.atmos.compile(wd); atmos <- krig.compare(wd, atmos)
# Save to use later if wanting to save time
setwd(wd$path[wd$wd=="weather"]); save(atmos, file="krig.atmos.compare.rda",compress="xz")
# Need to remove weird negatives from the kriging interpolations
atmos$kriged.precip[atmos$kriged.precip < 0] <- 0
# There are also some non-QA/QC'd high values here that should be ignored
atmos <- atmos[atmos$precip < 200,]
# The plot is not particularly convincing!
plot(atmos$precip, atmos$kriged.precip, ylim = c(0,max(c(max(atmos$precip), max(atmos$kriged.precip, na.rm=TRUE)), na.rm = TRUE)))
model <- lm(atmos$kriged.precip ~ atmos$precip); abline(model, col = "red")
siteplots(atmos) # Doesn't really help when done by site either. 

################################################################################
###################        NEAREST NEIGHBOR VALIDATION       ###################
################################################################################
# For our final attempt we will look at the nearest neighbor's daily gauge reading
# And assess whether this is any better than these other methods
# We will also apply the mathematical scaling formula of 
# P(x) = P(ws) x P(daymet, x)/P(daymet, ws)
# Where daymet could be any other means of interpolating at an unmeasured point

# Extract non-zero 500 random site*dates from 2022-01-01 to present in the archive
# Also extract 100 random site*dates that equal zero
setwd(wd$paths[wd$wd=="weather"]); load("precip.archive.rda")
df <- archive[archive$date >= "2022-01-01",]; df <- df[!is.na(df$precip),]
df <- df[df$date < "2024-01-01",]
set.seed(111)
df1 <- df[df$precip > 0,]; idx1 <- runif(500, 0, nrow(df1))
df0 <- df[df$precip == 0,]; idx0 <- runif(100, 0, nrow(df0))
df1 <- df1[idx1,]; df0 <- df0[idx0,]
df <- rbind(df0,df1); rownames(df) <- NULL; df$qual <- NULL
# Now we use this df to create predicted precipitations based on a series of techniques
df$neighbor <- NA; df$daymet <- NA; df$kriging <- NA; df$dist <- NA
meta <- full.precip.meta(wd); meta$dist <- NA

######################## NEIGHBOR AND DAYMET
# Here we use the normalization formula above for Daymet in hopes of improving its performance
for (i in 1:nrow(df)){
  # Get today's rain gauge data
  today <- archive[archive$date == df$date[i],]; today$dist <- NA
  for (j in 1:nrow(today)){today$dist[j] <- haversine.distance(df$lat[i], df$lon[i], today$lat[j], today$lon[j])}
  today <- today[today$dist != 0,] # Remove the selfsame gauge
  # Get nearest neighboring gauge precip
  neighbor <- today[today$dist == min(today$dist),]
  df$dist[i] <- min(today$dist); df$neighbor[i] <- today$precip[today$dist == min(today$dist)]
  # Get daymet
  daymet <- daymet.rain(wd, df$date[i], df$date[i], df$lat[i], df$lon[i])
  daymet.ws <- daymet.rain(wd, df$date[i], df$date[i], neighbor$lat[1], neighbor$lat[1])
  # If the current year, there will be no Daymet data
  if (nrow(daymet) == 0){df$daymet[i] <- NA} else {
    # Apply the formula when daymet succeeds
    factor <- (daymet$prcp / daymet.ws$prcp)
    if (is.nan(factor)){factor <- 1}
    df$daymet[i] <- df$neighbor[i] * factor
  }
  print(i)
}
# Save at this step to save time
validation <- df; save(validation, file="precip.validation.rda",compress="xz"); load("precip.validation.rda")
df <- validation

######################## "KRIGING" (ACTUALLY IDW)
# Here we use a "micro" interpolation approach of doing IDW only inside a 5km radius
# Instead of using the entire USVI-kriged map for this date as we tried above
for (i in 1:nrow(df)){
  print(paste0("Starting ", i, "..."))
  # Get today's rain gauge data
  today <- archive[archive$date == df$date[i],]; today$dist <- NA
  for (j in 1:nrow(today)){today$dist[j] <- haversine.distance(df$lat[i], df$lon[i], today$lat[j], today$lon[j])}
  today <- today[today$dist != 0,] # Remove the selfsame gauge
  today <- today[today$dist < 5,] # Get stations within 5km radius
  if (nrow(today) <= 1){df$kriging[i] <- NA; print("Assigned value to NA, moving to next"); next}
  # Get an AOI box with about 500m or 0.005 degree buffer
  maxlat <- max(today$lat + 0.005); minlat <- min(today$lat - 0.005)
  maxlon <- max(today$lon + 0.005); minlon <- min(today$lon - 0.005)
  aoi <- data.frame(lat = c(minlat, maxlat), lon = c(minlon, maxlon))
  resolution <- 100; library(sf); library(gstat)
  # Filter observations that may lie outside the AOI
  today <- today %>% filter(lat >= min(aoi$lat) & lat <= max(aoi$lat) & lon >= min(aoi$lon) & lon <= max(aoi$lon))
  # Remove rows where precipitation is NA
  today <- today %>% filter(!is.na(precip))
  if (nrow(today) <= 1){df$kriging[i] <- NA; print("Assigned value to NA, moving to next"); next}
  # Define the grid resolution, the argument should come in in meters
  xseq <- seq(from = min(aoi$lon), to = max(aoi$lon), by = resolution / 111320) # Convert meters to degrees
  # Get longitude degrees from meters by using 111320 * cos(lat_radians)
  yseq <- seq(from = min(aoi$lat), to = max(aoi$lat), by = resolution / 111320*cos((((min(aoi$lat) + max(aoi$lat))/2)*pi)/180)) 
  # Create a grid of points and filter by min and max lons just in case
  grid.df <- expand.grid(lon = xseq, lat = yseq)
  grid.df <- grid.df %>% filter(lon >= min(aoi$lon) & lon <= max(aoi$lon) & lat >= min(aoi$lat) & lat <= max(aoi$lat))
  df.sf <- st_as_sf(today, coords = c("lon", "lat"), crs = 4326) # Convert df.date to sf object
  grid.sf <- st_as_sf(grid.df, coords = c("lon", "lat"), crs = 4326) # Convert grid.df to sf object
  # Create a gstat object for variogram modeling
  gstat.obj <- gstat(id = "precip", formula = precip ~ 1, data = df.sf)
  variogram.model <- variogram(gstat.obj) # Compute the variogram
  # Perform kriging
  kriging.result <- predict(gstat.obj, newdata = grid.sf, model = fit.model)
  # Convert result to a data frame
  result.df <- as.data.frame(kriging.result)
  # Add coordinates to the result
  result.df$lon <- st_coordinates(grid.sf)[, 1]; result.df$lat <- st_coordinates(grid.sf)[, 2]
  result.df$geometry <- NULL; result.df$precip <- result.df$precip.pred
  kriged.precip <- result.df[,c("lat","lon","precip")]
  # Extract precip at location
  df$kriging[i] <- predicted.precip(df$lat[i], df$lon[i], kriged.precip)
  print(i)
}
# Save as a new file
validation <- df; save(validation, file="precip.validation2.rda",compress="xz")
df <- validation

################################################################################
# The data has all been queried at this step. Now compare plots and linear models.
# Plot nearest neighbor gauge data
plot(df$neighbor, df$precip); n.model <- lm(df$precip ~ df$neighbor); abline(n.model, col = "red")
# Plot daymet prediction - because of Daymet's poor resolution this is effectively identifical to neighbor
plot(df$daymet, df$precip); d.model <- lm(df$precip ~ df$daymet); abline(d.model, col = "red")
# Plot interpolated (IDW not really kriging)
plot(df$kriging, df$precip); k.model <- lm(df$precip ~ df$kriging); abline(k.model, col = "red")
# Observe the neighbor method has the best r.squared
summary(n.model)$r.squared; summary(d.model)$r.squared; summary(k.model)$r.squared
# Plot the neighbor graph with distance colored to look for a relationship to distance
colors <- colorRampPalette(c("darkblue", "lightblue"))(length(df$dist))
plot(df$neighbor, df$precip, col = colors[rank(df$dist)], pch = 19)
legend("topleft", legend = c("Low", "High"), fill = colorRampPalette(c("darkblue", "lightblue"))(2), title = "Distance")
# Distance does not appear to be really affecting the quality of the prediction. But let's check it one last time
df$diff <- abs(df$precip - df$neighbor); plot(df$dist, df$diff)
# This looks like a histogram clustering around 3 km more than anything -- no real indication neighbor is a poor choice

################################################################################
# Perform the neighbor method on the entire archive in the modern era, e.g. since 1970
setwd(wd$paths[wd$wd=="weather"]); load("precip.archive.rda")
df <- archive[archive$date >= "1970-01-01",]; df <- df[!is.na(df$precip),]
rownames(df) <- NULL; df$qual <- NULL
# Now we use this df to create predicted precipitations based on a series of techniques
df$neighbor <- NA; df$dist <- NA
for (i in 1:nrow(df)){
  # Get today's rain gauge data
  today <- archive[archive$date == df$date[i],]; today$dist <- NA
  for (j in 1:nrow(today)){today$dist[j] <- haversine.distance(df$lat[i], df$lon[i], today$lat[j], today$lon[j])}
  today <- today[today$dist != 0,] # Remove the selfsame gauge
  # Get nearest neighboring gauge precip
  neighbor <- today[today$dist == min(today$dist),]
  df$dist[i] <- min(today$dist); df$neighbor[i] <- today$precip[today$dist == min(today$dist)]
  print(paste0("Finished ", i, " of ", nrow(df)))
}
# Save and plot again
save(df, file="neighbor.validation.full.rda",compress="xz")
load("neighbor.validation.full.rda")
colors <- colorRampPalette(c("darkblue", "lightblue"))(length(df$dist))
plot(df$neighbor, df$precip, col = colors[rank(df$dist)], pch = 19)  # 'rank(z)' is to match color to z's order
legend("topleft", legend = c("Low", "High"), fill = colorRampPalette(c("darkblue", "lightblue"))(2), title = "Distance")
n.model <- lm(df$precip ~ df$neighbor); abline(n.model, col = "red"); summary(n.model)$r.squared; n.model$coefficients
# It does appear that distance may matter when all the data comes into play
df$diff <- abs(df$precip - df$neighbor); plot(df$dist, df$diff)
# So let's generate a slope and r2 for 3km bins
maxdist <- max(df$dist); intervals <- seq(0, ceiling(maxdist / 3) * 3, by = 3)
buckets <- data.frame(start = rep(NA, length(intervals)-1), end = rep(NA, length(intervals)-1), r2 = rep(NA, length(intervals)-1), slope = rep(NA, length(intervals)-1))
for (i in 2:length(intervals)){
  start <- intervals[i-1]; buckets$start[i-1] <- start; end <- intervals[i]; buckets$end[i-1] <- end
  subset <- df[df$dist >= start & df$dist < end,]
  if (nrow(subset) <= 1){
    buckets$r2[i-1] <- NA; buckets$slope[i-1] <- NA
  } else {
    model <- lm(subset$precip ~ subset$neighbor)
    buckets$r2[i-1] <- summary(model)$r.squared
    buckets$slope[i-1] <- model$coefficients[2]
  }
}
# Not only are distances above 15 km uncommon enough to have no model,
# but we see that the original slope of all the data, 0.63, is close to 
# the bucketed slopes, so we will simply use it across the board
# Baking this into the function neighbor.daily.model, repeated here below but also
# stored in 00-functions.R
neighbor.daily.model <- function(wd, lat, lon, date){
  # Pull the full archive if we have it already, or just the non-UVI if not yet
  setwd(wd$paths[wd$wd=="archive"])
  if (file.exists("full.precip.archive.rda")){load("precip.archive.rda")} else {setwd(wd$paths[wd$wd=="weather"]); load("precip.archive.rda") }
  df <- archive; df <- df[df$date == date,]
  # Find the neighbor to these coordinates on this date
  df$dist <- haversine.distance(lat, lon, df$lat, df$lon); df <- df[df$dist != 0,]; df <- df[df$dist == min(df$dist),]
  neighbor <- df$precip
  # Apply the formula
  m <- 0.637; b <- 1.045
  daily.precip <- (m * neighbor) + b
  return(daily.precip)
}