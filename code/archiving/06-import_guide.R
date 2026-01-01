# IMPORTING NEW DATA -- A QUICK START GUIDE
# In this file you will be guided to import new 
# environmental data in three categories:
#    1. "Weather" including rainfall
#    2. "Hydro" meaning streamflow
#    3. "VWC" meaning soil moisture. 
# IF A NEW SITE HAS BEEN ESTABLISHED - ENTER THE INFORMATION MANUALLY IN THE CSVS FIRST
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr); setwd(wd.archive)

# Each of these has a site name code. Let's begin by querying all the sites 
# that currently have archived data
archived.date.ranges(wd)
# Some of these sitenames are not a full weather-hydro pair
# and instead pair a hydro sitename to a weather site. Check if 
# this requires an update:
read.csv("site.correspondence.csv")
# Some of these sites are inactive or abandoned - here is the current status
# Update if necessary!
read.csv("site.status.csv")

# Begin by downloading weather data for the active sites you wish to update.
# Enter the site name of the site you are interested in here to receive more information
get.site.info(wd)

# Now proceed with import processes. For weather and VWC:
#   1. Go to https://zentracloud.com/ and log in 
#   2. Navigate to the download button on the left
#   3. Select the weather or VWC station name from the drop-down
#   4. Custom range: from "last data entered" (INCLUSIVE) to today or latest
#   5. Request data + download
#   6. Open the zip and find the ONE OR MORE "configuration" files
#   7. Move this CSV to Data > Raw-weather or Raw-VWC
#   8. Name with convention: sitename_weather_YYYYMMDD-YYYYMMDD showing date range
#   9. Convention for VWC can include sitename_vwc_hs_YYYYMMDD-YYYYMMDD or sb or other code

# For water level:
#   1. Water level will only be current to the last manual field download date
#   2. There may be more than one depending on how long since new raw data was archived
#   3. Raw data from HOBO shuttle must be converted to CSV from Hoboware first
#   4. Naming convention for this is sitename_hydro_YYYYMMDD-YYYYMMDD.csv
#   5. For 2-logger pairs for slope, it is sitenameslope_hydro_YYYYMMDD.csv
#   6. Open .hobo file in HOBOware Pro
#   7. Select internal logger events to plot: None (abs pres and temp ONLY)
#   8. Plot
#   9. File > Export table data
#   10. Save with file name convention in Data > Raw-level

# When the required files have all been downloaded and named in the correct folders, move to the import code template

