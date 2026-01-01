# Computing baseflow separation with Duncan's (2019) fitting approach
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly)
################################################################################
setwd(wd.analysis); load("sr1.raw.rda"); load("sr2.raw.rda")

# Plot SR1 flow
p <- plot_ly(data = sr1, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
p <- p %>% layout(title = paste0("Total flow at site sr1")); p
# Plot SR2 flow
p <- plot_ly(data = sr2, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
p <- p %>% layout(title = paste0("Total flow at site sr2")); p
# There needs to be a certain amount of fine-scale correction of raw Q, or else smoothing
# because of sensor instability at times, diurnal pressure variation for example produces error

################################################################################
# Now we proceed with fitting k recession constants and calculating baseflow
sr1 <- k.selection(wd, "sr1", sr1) # chose k = 0.87, given quick recession of hyporheic zone and massive quickflows
sr2 <- k.selection(wd, "sr2", sr2) # chose k = 0.85

# Save these for continuing use
setwd(wd.analysis)
save(sr1, file= "sr1.rda", compress="xz")
save(sr2, file= "sr2.rda", compress="xz")

