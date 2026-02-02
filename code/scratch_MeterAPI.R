# The following line can be run alone to call in setup functions
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
load_functions("api"); load_functions("metadata")
setwd(wds("data"))
# Run set-up function to get main Zentra Cloud token
setup_zentracloud("ZENTRACLOUD_TOKEN")
metadata <- load_zentra_metadata()
stations <- unique(metadata$station_id)
mnt <- load_maintenance_log()



# Most common: Approve all devices at a station after field work
set_download_approved(station_id = "sr1_vwc")
# Approve specific device (if station has multiple devices)
set_download_approved(device_serial = "z6-12345")
# Approve all stations at once (use cautiously!)
set_download_approved(approve_all = TRUE)
# Un-approve a station (e.g., you realize you need to fix metadata)
set_download_approved(station_id = "sr2_weather", value = FALSE)
# Un-approve everything (e.g., before field season starts)
set_download_approved(approve_all = TRUE, value = FALSE)



# Need to fix UVI station download for VWC vs weather

# These commands read and then add a named path if wanted
#read_datamap()
#path <- paste0(wds("data"), "/internal/raw/streamflow")
#set_named_path("internal_raw_streamflow", path)

# Write script to make commit easy and update data to Box?
# Get all metadata update functions working
# Code the weekly job script, any other wrappers? 

# Write in elevations

# Write last download date
# Write the last recorded datetime for station
# Prevent downloads from less than a week ago unless override - this stops downloads when metadata needs updating manually
# Do all the above in the wrapper function

# Make sure last update is UP TO DATE in whatever master function runs all this together!

# Work out some sort of "rollback" process for when downloads occur with bad metadata
# Work out an external emailing system that will ask you if any metadata has changed since DATE, running every 2 weeks 


#df <- download_zentra_station("fb1_weather", metadata, ports, start = "2024-02-06 00:00:00", end = "2024-02-07 00:00:00")
station <- "fb1_weather"








