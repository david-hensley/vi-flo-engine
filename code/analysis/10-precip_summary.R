setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
setwd(wd.weather); load("precip.archive.rda")

library(dplyr)
df <- archive

# Step 1: Extract year
df$year <- format(df$date, "%Y")

# Step 2: Calculate total rainfall and count missing days per station per year
station_annual <- aggregate(
  list(total_rainfall = df$precip, missing_days = is.na(df$precip)),
  by = list(station = df$station, year = df$year),
  FUN = function(x) ifelse(is.logical(x), sum(x), sum(x, na.rm = TRUE))
)

# Step 3: Filter out stations with >20 missing days
station_filtered <- subset(station_annual, missing_days <= 10)


annual_avg_rainfall <- aggregate(
  total_rainfall ~ year,
  data = station_filtered,
  FUN = mean
)


# Step 4: Count the number of stations contributing to each year
station_count <- aggregate(
  station ~ year,
  data = station_filtered,
  FUN = length
)

# Step 5: Keep only years with at least 4 stations
#valid_years <- subset(station_count, station >= 4)$year


valid_years <- station_count

# Step 6: Calculate annual average rainfall for valid years
annual_avg_rainfall <- aggregate(
  total_rainfall ~ year,
  data = station_filtered[station_filtered$year %in% valid_years, ],
  FUN = mean
)

# View the result
print(annual_avg_rainfall)


















