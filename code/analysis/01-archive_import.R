# Importing data from archived files into format for analysis, trimming by complete dates
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr); library(plotly)
################################################################################
# Import data from analysis folder - archive was copied here 2024-10-04
# This allows further changes to proceed with main archive while recording this for repeatability 
setwd(wd.analysis)
load("sr1.weather.rda"); load("sr1.hydro.rda"); load("sr1.vwc.rda")
load("sr2.weather.rda"); load("sr2.hydro.rda");load("sr2.vwc.rda")

# First create wide VWC data
sr1.vwc <- vwc.wide(sr1.vwc)
sr2.vwc <- vwc.wide(sr2.vwc)

# Fix QA/QC issue in SR1 hydro - this will be addressed in future imports of SR1
# but was not addressed before data was copied to this directory for analysis
plot_ly(data = sr1.hydro, x = ~date, y = ~q, type = 'scatter', mode = 'lines')
# Logger was probably moved after download on 2024-08-23, apply correction
q1 <- sr1.hydro$q[sr1.hydro$date == "2024-08-23 14:30:00"]
q2 <- sr1.hydro$q[sr1.hydro$date == "2024-08-23 15:00:00"]
correction <- q2-q1
sr1.hydro$q[sr1.hydro$date == "2024-08-23 14:45:00"] <- q1
sr1.hydro$q[sr1.hydro$date >= "2024-08-23 15:00:00"] <- sr1.hydro$q[sr1.hydro$date >= "2024-08-23 15:00:00"] - correction
plot_ly(data = sr1.hydro, x = ~date, y = ~q, type = 'scatter', mode = 'lines')
# Fixed

#SR1 VWC bounds
#2022-06-15 13:45:00
#2024-09-10 12:00:00

# SR2 VWC bounds
#2022-06-14 14:15:00
#2024-09-23 14:00:00

# SR1 bounds are the most restrictive, this will represent the entire period now
start <- "2022-06-15 14:00:00"; end <- "2024-09-10 12:00:00"
sr1.vwc <- sr1.vwc[sr1.vwc$date >= start & sr1.vwc$date <= end,]
sr2.vwc <- sr2.vwc[sr2.vwc$date >= start & sr2.vwc$date <= end,]

# Now trim weather
sr1.weather <- sr1.weather[sr1.weather$date >= start & sr1.weather$date <= end,]
sr2.weather <- sr2.weather[sr2.weather$date >= start & sr2.weather$date <= end,]

# Now hydro
sr1.hydro <- sr1.hydro[sr1.hydro$date >= start & sr1.hydro$date <= end,]
sr2.hydro <- sr2.hydro[sr2.hydro$date >= start & sr2.hydro$date <= end,]

# Now attach everything
sr1.weather$timestamp <- NULL
sr2.weather$timestamp <- NULL
sr1.hydro$timestamp <- NULL
sr2.hydro$timestamp <- NULL
sr1.hydro$site <- NULL
sr2.hydro$site <- NULL
sr1 <- merge(sr1.vwc, sr1.hydro, by = "date", all = TRUE)
sr1 <- merge(sr1, sr1.weather, by = "date", all = TRUE)
sr2 <- merge(sr2.vwc, sr2.hydro, by = "date", all = TRUE)
sr2 <- merge(sr2, sr2.weather, by = "date", all = TRUE)

# Save these for continuing use
setwd(wd.analysis)
save(sr1, file= "sr1.raw.rda", compress="xz")
save(sr2, file= "sr2.raw.rda", compress="xz")
