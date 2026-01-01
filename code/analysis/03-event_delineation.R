# Event delineation of rainfall and streamflow events
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly)
################################################################################
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda")

# Begin by inspecting the hydrograph to determine reasonable parameters for 
# the hydrograph separation, based on local maxima. In particular we need a 
# threshold which is the minimum for an event to occur. 
# Plot SR1 flow
p <- plot_ly(data = sr1, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
p <- p %>% layout(title = paste0("Total flow at site sr1")); p
# Plot SR2 flow
p <- plot_ly(data = sr2, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
p <- p %>% layout(title = paste0("Total flow at site sr2")); p

# Gleaning flow events, from the thresholds identified based on sensor error observed in graphs
# All flow units are m3/s, durations in hours, rainfall in mm or mm/hr
MIT <- 6 # Was previously 6
sr1.flows <- hydrograph.sep(sr1, 0.01, 0.003, MIT)
sr2.1 <- sr2[sr2$date < "2024-05-01 00:00:00",]
sr2.2 <- sr2[sr2$date >= "2024-05-01 00:00:00",]
sr2.flows1 <- hydrograph.sep(sr2.1, 0.01, 0.003, MIT)
sr2.flows2 <- hydrograph.sep(sr2.2, 0.035, 0.003, MIT) #sensor noisiness increased dramatically after May 2024
sr2.flows <- rbind(sr2.flows1, sr2.flows2)
sr2.flows$event.num <- c(1:nrow(sr2.flows))

# Minimum precip threshold is based on Holwerda
sr1.rains <- rainfall.delineation(sr1, MIT, 0.1575, "America/Port_of_Spain")
sr2.rains <- rainfall.delineation(sr2, MIT, 0.1575, "America/Port_of_Spain")
# Pair flow events to rain events and get rainfall-runoff info
sr1.flows <- event.pairing(sr1.flows, sr1.rains, sr1, 0.01, 0.003, MIT)
sr2.flows <- event.pairing(sr2.flows, sr2.rains, sr2, 0.01, 0.003, MIT)

# Save these for continuing use
setwd(wd.analysis)
save(sr1.flows, file= "sr1.flows.rda", compress="xz")
save(sr2.flows, file= "sr2.flows.rda", compress="xz")


