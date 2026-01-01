# Calculating and examining lag times
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr)
################################################################################
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda")
load("srrc.rda")

################################################################################
# Lag time

# Exclude from analysis any SR1 lag time from before station operation
# 2022-09-13 12:45:00
srlag <- srrc[-which(srrc$start <= "2022-09-13 12:45:00" & srrc$site == "sr1"),]
rownames(srlag) <- NULL
plot(srlag$site, srlag$peaklag)

srlag$startpeak <- (as.numeric(srlag$peak.time) - as.numeric(srlag$precip.start)) / 3600
plot(srlag$site, srlag$startpeak)

# There are extremely long lags that are occurring when flow events are very long 
# and may peak long after the initial rain event
# Thus we should take the centroid of the entire flow event's rain, from rain start to end
srlag$centroid <- NA
srlag$centroid.flow <- NA
for (i in 1:nrow(srlag)){
  sitename <- as.character(srlag$site[i])
  df <- get(sitename)
  subset <- df[df$date >= srlag$precip.start[i] & df$date <= srlag$end[i],]
  # Get the centroid time with weighted average
  centroid.timestamp <- sum(as.numeric(subset$date) * subset$precip) / sum(subset$precip)
  # Convert back to datetime
  centroid.date <- as.POSIXct(centroid.timestamp, origin = "1970-01-01", tz = "America/Port_of_Spain")
  srlag$centroid[i] <- centroid.date
  
  centroid.flow.time <- sum(as.numeric(subset$date) * subset$quick) / sum(subset$quick)
  centroid.flow.date <- as.POSIXct(centroid.flow.time, origin = "1970-01-01", tz = "America/Port_of_Spain")
  srlag$centroid.flow[i] <- centroid.flow.date
}
srlag$centroid <- as.POSIXct(srlag$centroid, origin = "1970-01-01", tz = "America/Port_of_Spain")
srlag$centroid.to.peak <- (as.numeric(srlag$peak.time) - as.numeric(srlag$centroid)) / 3600
plot(srlag$site, srlag$centroid.to.peak)

srlag$centroid.to.centroid <- (as.numeric(srlag$centroid.flow) - as.numeric(srlag$centroid)) / 3600
plot(srlag$site, srlag$centroid.to.centroid)


srlag$startlag <- (as.numeric(srlag$start) - as.numeric(srlag$precip.start)) /3600
# Exclude from analysis any SR1 lag time from before station operation
# 2022-09-13 12:45:00
plot(srlag$site, srlag$startlag)

# One-way ANOVA
result <- aov(startlag ~ site, data = srlag)
# Summary of the ANOVA
summary(result)

mean(srlag$startlag[srlag$site == "sr1"]) # Lag of 3.9 hours
sd(srlag$startlag[srlag$site == "sr1"])/sqrt(nrow(srlag[srlag$site == "sr1",])) # SE +/- 1.0

mean(srlag$startlag[srlag$site == "sr2"]) # Lag of 10.1 hours for buffering
sd(srlag$startlag[srlag$site == "sr2"])/sqrt(nrow(srlag[srlag$site == "sr2",])) # SE +/- 3.1



