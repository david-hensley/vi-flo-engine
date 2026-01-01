# EXAMPLE IMPORT PROCEDURE: USE THIS TEMPLATE FOR A NEW IMPORT!
# Remove these top five lines, and replace site name etc. where needed
# Be sure to replace text that is written in comments inside [brackets],
# as these are guides for the user setting up the template!
################################################################################
# Importing [write the full site name in English]
# WEATHER YYYY-MM-DD to YYYY-MM-DD
# HYDRO   YYYY-MM-DD to YYYY-MM-DD
# VWC     YYYY-MM-DD to YYYY-MM-DD
# [Write any relevant notes about the run here, such as a new qcurve being run]
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
sitename <- "sitename"
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
gaplist <- allgaps(weather, 15) # [comment here]

# If gaps remain in weather variables, you may interpolate all except precip
# when the gaps are not eregiously long, e.g.:
#weather <- interp(wd, weather, "rad", 15)
gaplist0 <- allgaps(weather, 15) # [comment here]

################################################################################
# MANUAL QA/QC
# Plot the meteo variables to check for need of manual QA/QC
plot(weather$date, weather$rad)   # [comment here]
plot(weather$date, weather$temp)  # [comment here]
plot(weather$date, weather$rh)    # [comment here]
plot(weather$date, weather$wind)  # [comment here]
plot(weather$date, weather$pres)  # [comment here]
# If any manual QA/QC is needed, perform it here
# Use splice.meta.add() before performing any direct manual data editing
# and use quick.index.interp() for quick interpolation by index which will perform splice for you, e.g.
#weather <- quick.index.interp(wd, sitename, weather, "pres", which(weather$date == "2021-12-23 04:15:00"), which(weather$date == "2021-12-23 04:30:00"))

# Plot again when needed to check for success

################################################################################
# Now we move to precipitation
plot(weather$date, weather$precip)
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
weather <- rain.qaqc(wd, sitename, weather)
gaplist0 <- allgaps(weather, 15) # [comment here]
plot(weather$date, weather$precip) # [comment here]

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, weather, sitename, type, overwrite)
# [comment here]

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
gap.print(hydro, 15) # [comment here]

################################################################################
# MANUAL QA/QC
hydro <- level.qaqc(wd, hydro, sitename)
# [comment here]
# Same manual process as above, e.g.:
#hydro <- quick.index.interp(wd, sitename, hydro, "level", which(hydro$date == "2021-12-23 04:15:00"), which(hydro$date == "2021-12-23 04:30:00"))
plot(hydro$date, hydro$level) # [comment here]
rownames(hydro) <- NULL

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# Skip this if re-running this code!!!!!!!
# If you created a new slope model or changed anything, create a segment before
# this one to record it, then run the new qcurve here with reasons specified.
# Normally, you may delete this section if you do not change the qcurve.

# Write the reason we have a new qcurve for the metadata
reason <- "reason for running new qcurve"

# Calculate a new qcurve using the slope model
new.qcurve <- manning.qcurve(wd, sitename, TRUE)
add.qcurve(wd, new.qcurve, sitename, reason)

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
hydro <- qflux(wd, hydro, sitename)
hydro <- auto.qaqc(wd, hydro)
gap.print(hydro, 15) # [comment here]
plot(hydro$date, hydro$q) # [comment here]

################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, hydro, sitename, type, overwrite)
# [comment here]

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
gaplist <- allgaps(vwc, 15) # [comment here]

# setting a threshold of rainfall below which we allow auto gap filling, 6mm is normal
threshold <- 6
vwc <- vwc.rain.fill(wd, vwc, sitename, threshold)
gaplist <- allgaps(vwc, 15) # [comment here]

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Check by type, begin with hs 
vwc.hs <- vwc[vwc$type == "hs",]
rownames(vwc.hs) <- NULL
plot(vwc.hs$date, vwc.hs$cm10, main = "HS 10cm") # [comment here]
plot(vwc.hs$date, vwc.hs$cm30, main = "HS 30cm") # [comment here]
plot(vwc.hs$date, vwc.hs$cm50, main = "HS 50cm") # [comment here]
plot(vwc.hs$date, vwc.hs$cm100, main = "HS 100cm") # [comment here]
# Perform manual QA/QC as necessary

vwc.sb <- vwc[vwc$type == "sb",] 
rownames(vwc.sb) <- NULL
plot(vwc.sb$date, vwc.sb$cm10, main = "SB 10cm") # [comment here]
plot(vwc.sb$date, vwc.sb$cm30, main = "SB 30cm") # [comment here]
plot(vwc.sb$date, vwc.sb$cm50, main = "SB 50cm") # [comment here]
plot(vwc.sb$date, vwc.sb$cm100, main = "SB 100cm") # [comment here]
# Perform manual QA/QC as necessary

# Reform into a single df once finished
vwc <- rbind(vwc.hs, vwc.sb)
rownames(vwc) <- NULL


################################################################################
# Archive it
overwrite <- FALSE
archive <- archive.data(wd, vwc, sitename, type, overwrite)
# [comment here]

# Template ends here! Below follows further documentation
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
# Layout with plain text explaining the purpose of each step:

################################################################################
# Importing [write the full site name in English]
# WEATHER YYYY-MM-DD to YYYY-MM-DD
# HYDRO   YYYY-MM-DD to YYYY-MM-DD
# VWC     YYYY-MM-DD to YYYY-MM-DD
# This segment provides a notation of what dates were run originally in the import
# which is important because these dates will not be retrievable once the archive
# has been saved over, as they are retrived by dateranges() from the current 
# extent of the archive. This is why dateranges() prompts user to acknowledge this.
################################################################################
######               PACKAGES, FUNCTIONS AND WD INFORMATION               ######
################################################################################
# Allows user to bring in all necessary functions, and specify directories
# Sitename is specified here and date ranges are provided to record above and use 
# for this import. A backup of splices occurs in the dateranges run, and the time
# the run began, which can be used to retrieve the splices backup in case of problems,
# is also recorded here. 

################################################################################
#######                    WEATHER DATA IMPORTATION                     ########
################################################################################
# Pulls from the raw data archive with the standard naming conventions the files
# referred to by the date ranges, such that new data will be automatically pulled.
# Do note however that this relies on following the naming conventions of:
# sitename_type_YYYYMMDD-YYYYMMDD.csv, in which the start and end dates represent
# the calendar dates of the start and end of the actual data in the CSV.

################################################################################
############                   WEATHER DATA QA/QC                  #############
################################################################################
# Begins with auto.qaqc(), which ensures evenly spaced intervals, producing NAs
# when the raw data has skips in the timestamps, and automatically fills gaps
# and writes splice record for meto variables' gas of <12 hours, and <1 hour
# for precip. Remaining gaps are identified in a print statement.

# Gaps often remain in meteo variables (non precip) which are usually fixable with
# the "daily interpolation" approach, where the running average of the observation
# of that meteo variable at that time of day for the four days before and after the gap
# are used to interpolate across that timeslot only for as many days as the gap lasts,
# which permits more realistic than linear interpolation for a longer gap

################################################################################
# MANUAL QA/QC
# Further manual interventions are sometimes necessary, and are logged here.
# User must manually record the splice information with splice.meta.add BEFORE
# performing actual data editing to ensure no record of what was done is lost

################################################################################
# Now we move to precipitation
# Move to precipitation with the rain.qaqc master function. This includes:
#   --Gap zeroing when little to no rain is suspected
#   --User-prompts for dealing with remaining gaps
#   --Checks of suspicious periods that do not agree with neighboring rain gauges
# This function acts as the rain QA/QC "master function" and creates a simulated
# pluviograph using a blend of upwind and downwind (when available) UVI-owned ATMOS
# stations in the same island group to infer a timeseries pluviograph for otherwise
# unfixable gaps in precip. If no neighboring ATMOS exists, user is prompted and can
# either accept the unfixed data, zero it out, do simple interpolation, or 
# use NASA GPM satellite data to create a simulated timeseries for the gap.

################################################################################
# Archive it
# Overwrites the archive, so caution is needed, though the function has warnings.

################################################################################
#############             HYDROGRAPH DATA IMPORTATION              #############
################################################################################
# Pulls raw level data in the same manner and same naming convention as weather.

################################################################################
#############                 HYDROGRAPH DATA QA/QC                #############
################################################################################
# Same auto.qaqc process as with weather data.

################################################################################
# MANUAL QA/QC
# But a further step of level.qaqc is needed since there can be strange outliers
# or other problems with the water level data, which usually have to be manually
# dealt with, as is done in this segment. 

################################################################################
#############               NEW QCURVE CALCULATION                 #############
################################################################################
# This is space to calculate a new qcurve either from slope model or from manning,
# and add it to the qcurves record with a metadata description of why this was done.

################################################################################
#############                 DISCHARGE CALCULATION                #############
################################################################################
# Uses the qcurves lookup table to convert level to discharge in m3/s for the 
# final hydrograph before archiving.

################################################################################
# Archive it

################################################################################
#############                    VWC IMPORTATION                   #############
################################################################################
# Imports VWC data, but also is capable of handling various "vwctype" sub-categories
# referring to the type of VWC station deployment location, normally sb (streambank)
# or hs (hillside).

################################################################################
#############                       VWC QA/QC                      #############
################################################################################
# Follows a similar process to auto.qaqc but subsets the full dataset (which by
# default is in long form with a $type column) to perform automatic QA/QC and 
# splice records for each subset before bringing it back together. For remaining
# gaps, it is permitted to zero out the gap when the rain record shows no rain
# above a stated threshold, usually 6mm, was seen during that time. Remaining gaps
# after this must be retained and dealt with as gaps, not filled. 

################################################################################
#############                  MANUAL VWC QA/QC                    #############
################################################################################
# Manual plotting and checking occurs here.

################################################################################
# Archive it









