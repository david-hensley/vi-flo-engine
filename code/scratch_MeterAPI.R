wd_engine <- Sys.getenv("VI_FLO_ENGINE_ROOT")
wd_data <- Sys.getenv("VI_FLO_DATA_ROOT")
wd_tools <- paste0(wd_engine, "/tools")
source(paste0(wd_engine, "/code/functions/api_functions.R"))

setwd(wd_data)
metadata <- load_zentra_metadata()
ports <- read.csv("zentra_ports.csv")

# Run set-up function to get main Zentra Cloud token
setup_zentracloud("ZENTRACLOUD_TOKEN")

path <- paste0(wd_data, "/metadata/internal")
set_named_path("meta_internal", path)
read_datamap()

setwd(wds("raw.rain"))

# Write last download date
# Write the last recorded datetime for station
# Prevent downloads from less than a week ago unless override - this stops downloads when metadata needs updating manually
# Do all the above in the wrapper function

# Make sure last update is UP TO DATE in whatever master function runs all this together!
#df <- download_zentra_station("fb1_weather", metadata, ports, start = "2024-02-06 00:00:00", end = "2024-02-07 00:00:00")

# Add $token_name to metadata



