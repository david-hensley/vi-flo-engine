# Adding additional figures or information for revisions
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly); library(viridis)
setwd(wd.code); source("00-functions.R")
sites <- read.csv(paste0(wd.sites, "/site-ids.csv"))

################################################################################
# Distances of stations from key points
# Centroid lat lon
sr2.lat <- 17.755271670863692
sr2.lon <- -64.779456081293716
sr1.lat <- 17.759471066555076
sr1.lon <- -64.798249309699500
# Weather station lat lon
sr2.w.lat <- 17.7536017
sr2.w.lon <- -64.7755428
sr1.w.lat <- 17.7605797
sr1.w.lon <- -64.8000021
# Weather station distances from centroid
sr1.w.dist <- haversine.distance(sr1.lat, sr1.lon, sr1.w.lat, sr1.w.lon)
sr2.w.dist <- haversine.distance(sr2.lat, sr2.lon, sr2.w.lat, sr2.w.lon)
# Gauge lat lon
sr2.g.lat <- sites$lat[sites$sitename=="sr2"]
sr2.g.lon <- sites$lon[sites$sitename=="sr2"]
sr1.g.lat <- sites$lat[sites$sitename=="sr1"]
sr1.g.lon <- sites$lon[sites$sitename=="sr1"]
# Gauge distance from weather
sr1.g.dist <- haversine.distance(sr1.g.lat, sr1.g.lon, sr1.w.lat, sr1.w.lon)
sr2.g.dist <- haversine.distance(sr2.g.lat, sr2.g.lon, sr2.w.lat, sr2.w.lon)
# Distance from SR1 gauge to soil transition
trans.lon <- -64.79070
trans.lat <- 17.75237
trans.dist <- haversine.distance(sr1.g.lat, sr1.g.lon, trans.lat, trans.lon)

################################################################################
# QA/QC validation

splices <- read.csv(paste0(wd.archive, "/splices.csv"))
splices <- splices[splices$site=="sr1" | splices$site == "sr2",]
splices <- splices[rowSums(is.na(splices)) < ncol(splices), ]
splices$start <- as.POSIXct(splices$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
splices$end <- as.POSIXct(splices$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
splices <- splices[rowSums(is.na(splices)) < ncol(splices), ]
setwd(wd.analysis)
load("sr1.raw.rda")
load("sr2.raw.rda")
startdate <- sr1$date[1]
enddate <- sr1$date[nrow(sr1)]
studylong <- (as.numeric(enddate) - as.numeric(startdate)) / 3600
splices <- splices[splices$start >= startdate & splices$end <= enddate,]
splices$duration <- (as.numeric(splices$end) - as.numeric(splices$start)) / 3600


site <- "sr1"
sitename <- site; ts <- get(site)
var <- "precip"
method <- "sim.pluviograph"
ts <- sr1
synthetic.gaps <- function(site, var, method, splices, ts, multiplier){
  df <- splices[splices$site==site & splices$var==var & splices$method != "neighbor.atmos" & splices$method == method,]
  # Timeseries of datetimes that were spliced
  avoid <- c()
  for (i in 1:nrow(df)){
    start <- df$start[i]; end <- df$end[i]
    thisgap <- seq(from = start, to = end, by = "15 min")
    avoid <- c(avoid, thisgap)
  }
  avoid <- as.POSIXct(avoid, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  set.seed(123)
  # Define possible starting points (excluding 'avoid' times)
  all.times <- seq(min(ts$date), max(ts$date), by = "15 min")
  valid.times <- setdiff(all.times, avoid)
  n <- nrow(df) * multiplier
  # Randomly sample the same number of starting points as we had filled gaps
  starts <- as.POSIXct(sample(valid.times, size = n, replace = FALSE), format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  durations <- sample(df$duration, size = n, replace = TRUE)
  # Ensure that all synthetic gaps exist outside the avoid period, resample if needed
  valid.starts <- c()
  # Loop to check validity and retry if necessary
  for (i in 1:n) {
    is.valid <- FALSE
    while (!is.valid) {
      # Sample a random start time and corresponding duration
      start <- starts[i]
      duration <- durations[i]
      end <- start + duration * 3600  # Assuming 'duration' is in minutes
      # Create a time series from start to end
      time.sequence <- seq(from = start, to = end, by = "15 min")
      # Check if any of the times in the sequence overlap with 'avoid'
      overlap <- any(time.sequence %in% avoid)
      # Also check if any of the values for this var are NA
      fuller.sequence <- c(start - 900, time.sequence, end + 900)
      missing <- any(is.na(ts[[var]][ts$date %in% fuller.sequence]))
      if (!overlap & !missing) {
        valid.starts <- c(valid.starts, start)
        is.valid <- TRUE
      } else {
        starts[i] <- sample(valid.times, 1)
      }
    }
  }
  test <- data.frame(start = valid.starts, end = valid.starts + durations * 3600, duration = durations, method = method)
  test$start <- as.POSIXct(test$start, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  test$end <- as.POSIXct(test$end, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
  return(test)
}
test1 <- synthetic.gaps(site, var, method, splices, ts, 1)
test.sim.pluv <- function(wd, test, sitename, site, ts){
  df <- quick.wind.compile(wd)
  atmos <- quick.atmos.compile(wd, TRUE)
  for (i in 1:nrow(test)){
    start <- test$start[i]; end <- test$end[i]
    result <- rel.pluviograph(wd, df, atmos, site, start, end)
    rel.pluv <- result$rel.pluv; match <- result$match; type <- result$type
    # Pulling daily rainfall for each day of this gap
    start.date <- as.Date(start, tz = "America/Port_of_Spain"); end.date <- as.Date(end, tz = "America/Port_of_Spain")
    daylist <- seq(from = start.date, to = end.date, by = "day"); days <- data.frame(date = daylist, precip = rep(NA, length(daylist)))
    for (j in 1:nrow(days)){
      days$precip[j] <- neighbor.daily.model(wd, getlat(wd, sitename), getlon(wd, sitename), days$date[j])
    }
    # Adding the daily rainfall into the relative pluviograph to get the final pluviograph to splice
    if (i == 1){
      pluv <- sim.pluviograph(rel.pluv, days$precip, match)
    } else {
      pluv2 <- sim.pluviograph(rel.pluv, days$precip, match)
      pluv <- rbind(pluv, pluv2)
    }
  }
  pluv$sim.precip <- pluv$precip
  pluv <- pluv[,c("date", "sim.precip")]
  result <- merge(pluv, ts, by = "date", all.x = TRUE)
  result <- result[,c("date", "precip", "sim.precip")]
  # Summarize by day, here we sum precip
  result <- result %>%
    mutate(date = as.Date(date)) %>%  # Extract the date
    group_by(date) %>%  # Group by the date
    summarise(sim.precip = sum(sim.precip),
              obs.precip = sum(precip))  # Sum precip for each day
  return(result)
}
test1 <- test.sim.pluv(wd, test0, sitename, site, ts);  test1 <- as.data.frame(test1)
method <- "interp.linear"
test2 <- synthetic.gaps(site, var, method, splices, ts, 1)
test.interp.linear <- function(test, ts, var){
  for (i in 1:nrow(test)){
    start <- test$start[i]; end <- test$end[i]
    intervals <- (as.numeric(end) - as.numeric(start)) / 900 + 1
    obs1 <- ts[[var]][ts$date == start - 900]
    obs2 <- ts[[var]][ts$date == end + 900]
    interp.values <- seq(from = obs1, to = obs2, length.out = intervals + 2)[-c(1, intervals + 2)]
    dates <- seq(as.numeric(start), as.numeric(end), by = 900)
    dates <- as.POSIXct(dates, format = "%Y-%m-%d %H:%M:%S", tz = "America/Port_of_Spain")
    real.values <- ts[[var]][ts$date >= start & ts$date <= end]
    if (i == 1){
      result <- data.frame(date = dates, sim.vals = interp.values, real.vals = real.values)
    } else {
      result2 <- data.frame(date = dates, sim.vals = interp.values, real.vals = real.values)
      result <- rbind(result, result2)
    }
  }
  sim.name <- paste0("sim.", var)
  obs.name <- paste0("obs.", var)
  result[[sim.name]] <- result$sim.vals
  result[[obs.name]] <- result$real.vals
  result$sim.vals <- NULL
  result$real.vals <- NULL
  return(result)
}
test2 <- test.interp.linear(test2, ts, var)
method <- "zeroed.manual"
test3 <- synthetic.gaps(site, var, method, splices, ts, 1)
test.zeroed.manual <- function(test, ts, var){
  for (i in 1:nrow(test)){
    start <- test$start[i]; end <- test$end[i]
    dates <- seq(start, end, by = "15 mins")
    real.values <- ts[[var]][ts$date >= start & ts$date <= end]
    if (i == 1){
      result <- data.frame(date = dates, sim.vals = rep(0, length(dates)), real.vals = real.values)
    } else {
      result2 <- data.frame(date = dates, sim.vals = rep(0, length(dates)), real.vals = real.values)
      result <- rbind(result, result2)
    }
  }
  sim.name <- paste0("sim.", var)
  obs.name <- paste0("obs.", var)
  result[[sim.name]] <- result$sim.vals
  result[[obs.name]] <- result$real.vals
  result$sim.vals <- NULL
  result$real.vals <- NULL
  return(result)
}
test3 <- test.zeroed.manual(test3, ts, var)
precip.test <- rbind(test1, test2, test3)
plot(precip.test$obs.precip, precip.test$sim.precip)
r2.sr1.rain <- cor(precip.test$obs.precip, precip.test$sim.precip) * cor(precip.test$obs.precip, precip.test$sim.precip)

site <- "sr2"
sitename <- site; ts <- get(site)
method <- "sim.pluviograph"
test1 <- synthetic.gaps(site, var, method, splices, ts, 1)
test1 <- test.sim.pluv(wd, test0, sitename, site, ts);  test1 <- as.data.frame(test1)
method <- "interp.linear"
test2 <- synthetic.gaps(site, var, method, splices, ts, 1)
test2 <- test.interp.linear(test2, ts, var)
precip.test <- rbind(test1, test2)
plot(precip.test$obs.precip, precip.test$sim.precip)
r2.sr2.rain <- cor(precip.test$obs.precip, precip.test$sim.precip) * cor(precip.test$obs.precip, precip.test$sim.precip)

site <- "sr1"
sitename <- site; ts <- get(site)
var <- "level"
method <- "interp.linear"
test <- synthetic.gaps(site, var, method, splices, ts, 1)
test <- test.interp.linear(test, ts, var)
plot(test$obs.level, test$sim.level)
r2.sr1.level <- cor(test$obs.level, test$sim.level) * cor(test$obs.level, test$sim.level)
# No interpolation in SR2 level

site <- "sr1"
sitename <- site; ts <- get(site)
vars <- c("cm10.hs", "cm30.hs", "cm50.hs", "cm100.hs", "cm10.sb", "cm30.sb", "cm50.sb", "cm100.sb")
method <- "interp.linear"
sr1.vwc.r2s <- c()
for (i in 1:length(vars)){
  var <- vars[i]
  test <- synthetic.gaps(site, var, method, splices, ts, 1)
  test <- test.interp.linear(test, ts, var)
  obscol <- paste0("obs.", var)
  simcol <- paste0("sim.", var)
  r2 <- cor(test[[obscol]], test[[simcol]])
  sr1.vwc.r2s <- c(sr1.vwc.r2s, r2)
}
sr1.vwc.r2 <- mean(sr1.vwc.r2s, na.rm = TRUE)


site <- "sr2"
sitename <- site; ts <- get(site)
vars <- c("cm10.hs", "cm30.hs", "cm50.hs", "cm100.hs", "cm10.sb", "cm30.sb", "cm50.sb", "cm100.sb")
method <- "interp.linear"
sr2.vwc.r2s <- c()
for (i in 1:length(vars)){
  var <- vars[i]
  test <- synthetic.gaps(site, var, method, splices, ts, 1)
  test <- test.interp.linear(test, ts, var)
  obscol <- paste0("obs.", var)
  simcol <- paste0("sim.", var)
  r2 <- cor(test[[obscol]], test[[simcol]])
  sr2.vwc.r2s <- c(sr2.vwc.r2s, r2)
}
sr2.vwc.r2 <- mean(sr2.vwc.r2s, na.rm = TRUE)

round(r2.sr1.rain, 3)
round(r2.sr2.rain, 3)
round(r2.sr1.level, 3)
round(sr1.vwc.r2, 3)
round(sr2.vwc.r2, 3)

################################################################################
# Event delineation justification
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda")
MIT <- 1 # Was previously 6

mits <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 20, 24)
flow.lags <- c()
rain.lags <- c()
for (i in 1:length(mits)){
  MIT <- mits[i]
  sr1.flows <- hydrograph.sep(sr1, 0.01, 0.003, MIT)
  sr1.rains <- rainfall.delineation(sr1, MIT, 0.1575, "America/Port_of_Spain")

  sr1.flows <- tryCatch({
    event.pairing(sr1.flows, sr1.rains, sr1, 0.01, 0.003, MIT)
  }, error = function(e) {
    return(NULL)  # Return NULL if event.pairing fails
  })
  if (is.null(sr1.flows)){
    flow.lag <- NA
  } else {
    flow.intervals <- diff(as.numeric(sr1.flows$start)) / 3600
    flow.acf <- acf(flow.intervals)
    flow.lag <- flow.acf$acf[2]
  }
  flow.lags <- c(flow.lags, flow.lag)
}
sr1.lag.result <- data.frame(mit = mits, flow.lag = flow.lags)

flow.lags <- c()
rain.lags <- c()
for (i in 1:length(mits)){
  MIT <- mits[i]
  sr2.1 <- sr2[sr2$date < "2024-05-01 00:00:00",]
  sr2.2 <- sr2[sr2$date >= "2024-05-01 00:00:00",]
  sr2.flows1 <- hydrograph.sep(sr2.1, 0.01, 0.003, MIT)
  sr2.flows2 <- hydrograph.sep(sr2.2, 0.035, 0.003, MIT) #sensor noisiness increased dramatically after May 2024
  sr2.flows <- rbind(sr2.flows1, sr2.flows2)
  sr2.flows$event.num <- c(1:nrow(sr2.flows)) 
  sr2.rains <- rainfall.delineation(sr2, MIT, 0.1575, "America/Port_of_Spain")
  sr2.flows <- tryCatch({
    event.pairing(sr2.flows, sr2.rains, sr2, 0.01, 0.003, MIT)
  }, error = function(e) {
    return(NULL)  # Return NULL if event.pairing fails
  })
  if (is.null(sr2.flows)){
    flow.lag <- NA
  } else {
    flow.intervals <- diff(as.numeric(sr2.flows$start)) / 3600
    flow.acf <- acf(flow.intervals)
    flow.lag <- flow.acf$acf[2]
  }
  flow.lags <- c(flow.lags, flow.lag)
}
sr2.lag.result <- data.frame(mit = mits, flow.lag = flow.lags)
lags <- sr1.lag.result
lags$sr1.lag <- lags$flow.lag
lags$sr2.lag <- sr2.lag.result$flow.lag
lags$flow.lag <- NULL

acf.range.sr1 <- c(0.10651275, 0.13068661)
acf.range.sr2 <- c(-0.07483470, 0.07950248)

################################################################################
# Singh's wetting front velocity and preferential flow
setwd(wd.analysis)
load("sr1.raw.rda"); load("sr2.raw.rda")
sr1.rains <- rainfall.delineation(sr2, 6, 0.1575, "America/Port_of_Spain")
sr2.rains <- rainfall.delineation(sr2, 6, 0.1575, "America/Port_of_Spain")

rains <- sr1.rains
vwc <- sr1

wfv <- function(rains, vwc){
  rains$wetup.cm10.hs <- FALSE
  rains$wetup.cm30.hs <- FALSE
  rains$wetup.cm50.hs <- FALSE
  rains$wetup.cm100.hs <- FALSE
  
  rains$wetup.cm10.sb <- FALSE
  rains$wetup.cm30.sb <- FALSE
  rains$wetup.cm50.sb <- FALSE
  rains$wetup.cm100.sb <- FALSE
  
  rains$pref.cm10.hs <- NA
  rains$pref.cm30.hs <- NA
  rains$pref.cm50.hs <- NA
  
  rains$pref.cm10.sb <- NA
  rains$pref.cm30.sb <- NA
  rains$pref.cm50.sb <- NA
  
  rains$wfv.cm10.hs <- NA
  rains$wfv.cm30.hs <- NA
  rains$wfv.cm50.hs <- NA
  rains$wfv.cm100.hs <- NA
  
  rains$wfv.cm10.sb <- NA
  rains$wfv.cm30.sb <- NA
  rains$wfv.cm50.sb <- NA
  rains$wfv.cm100.sb <- NA
  
  for (i in 1:nrow(rains)){
    # Subset the rain event plus MIT for the VWC record
    sub <- vwc[vwc$date >= rains$date.begin[i] & vwc$date <= rains$date.end[i]+6*3600,]
    # Also acquire the 4 hours before rain onset to obtain wetup threshold
    sub0 <- vwc[vwc$date >= rains$date.begin[i] - 4*3600 & vwc$date <= rains$date.begin[i],]
    cols <- c("cm10.hs", "cm30.hs", "cm50.hs", "cm100.hs", "cm10.sb", "cm30.sb", "cm50.sb", "cm100.sb")
    cols2 <- c("cm10.hs", "cm30.hs", "cm50.hs", "cm10.sb", "cm30.sb", "cm50.sb")
    threshes <- rep(NA, length(cols))
    
    # Determine if this threshold is met within 1 hour during the subset
    for (j in 1:length(cols)){
      # Threshold for wet up is either sensor precision of the SD of the last 4 hours, whichever is greater
      thresh <- sd(sub[[cols[j]]])
      if (is.na(thresh)){
        # When data is missing, go to the next column and leave this columns entries as defaults
        next
      }
      if(thresh > 0.03){
        threshes[j] <- thresh
      } else {
        threshes[j] <- 0.03
      }
      col <- sub[[cols[j]]]
      thresh <- threshes[j]
      for (k in 1:(length(col)-4)){
        # Search forward the next hour and see if the threshold is met
        now <- col[k]
        later <- col[k+4]
        if (later - now >= thresh){
          wetupcol <- paste0("wetup.", cols[j])
          rains[[wetupcol]][i] <- TRUE
          wfvcol <- paste0("wfv.", cols[j])
          rains[[wfvcol]][i] <- (as.numeric(sub$date[k]) - as.numeric(rains$date.begin[i])) / 3600 # Wetting arrival in hours
          # Change this to wetting fron velocity - depth over wetting arrival time in mm/h
          if (j == 1 | j == 5){
            rains[[wfvcol]][i] <- 100 / rains[[wfvcol]][i]
          } else if (j == 2 | j == 6){
            rains[[wfvcol]][i] <- 300 / rains[[wfvcol]][i]
          } else if (j == 3 | j == 7){
            rains[[wfvcol]][i] <- 500 / rains[[wfvcol]][i]
          } else if (j == 4 | j == 8){
            rains[[wfvcol]][i] <- 1000 / rains[[wfvcol]][i]
          }
        }
      }
      # Search the layer below (unless 100cm) to see if it responded before we did
      if (!(cols[j] %in% c("cm100.hs", "cm100.sb"))){
        prefcol <- paste0("pref.", cols[j])
        wfvcol <- paste0("wetup.", cols[j])
        wfvcol2 <- paste0("wetup.", cols[j+1])
        if (is.na(rains[[wfvcol2]][i])){
          next # Proceed to next column, no further action in this one
        } else if (rains[[wfvcol2]][i] > rains[[wfvcol]][i]){
          rains[[prefcol]][i] <- 1
        } else {
          rains[[prefcol]][i] <- 0
        }
      }
    }
  }
  rains$wfv.cm10.hs[is.infinite(rains$wfv.cm10.hs)] <- NA
  rains$wfv.cm30.hs[is.infinite(rains$wfv.cm30.hs)] <- NA
  rains$wfv.cm50.hs[is.infinite(rains$wfv.cm50.hs)] <- NA
  rains$wfv.cm100.hs[is.infinite(rains$wfv.cm100.hs)] <- NA
  rains$wfv.cm10.sb[is.infinite(rains$wfv.cm10.sb)] <- NA
  rains$wfv.cm30.sb[is.infinite(rains$wfv.cm30.sb)] <- NA
  rains$wfv.cm50.sb[is.infinite(rains$wfv.cm50.sb)] <- NA
  rains$wfv.cm100.sb[is.infinite(rains$wfv.cm100.sb)] <- NA
  return(rains)
}
sr1.rains <- wfv(sr1.rains, sr1)
sr2.rains <- wfv(sr2.rains, sr2)

any(sr1.rains$wetup.cm10.hs == FALSE & sr1.rains$wetup.cm30.hs == TRUE)
any(sr1.rains$wetup.cm10.hs == FALSE & sr1.rains$wetup.cm50.hs == TRUE)
any(sr1.rains$wetup.cm10.hs == FALSE & sr1.rains$wetup.cm100.hs == TRUE)
any(sr1.rains$wetup.cm10.hs == FALSE & sr1.rains$wetup.cm30.hs == TRUE)


mean(sr1.rains$wfv.cm10.hs, na.rm = TRUE)
mean(sr1.rains$wfv.cm30.hs, na.rm = TRUE)
mean(sr1.rains$wfv.cm50.hs, na.rm = TRUE)
mean(sr1.rains$wfv.cm100.hs, na.rm = TRUE)

mean(sr2.rains$wfv.cm10.hs, na.rm = TRUE)
mean(sr2.rains$wfv.cm30.hs, na.rm = TRUE)
mean(sr2.rains$wfv.cm50.hs, na.rm = TRUE)
mean(sr2.rains$wfv.cm100.hs, na.rm = TRUE)

mean(sr1.rains$wfv.cm10.sb, na.rm = TRUE)
mean(sr1.rains$wfv.cm30.sb, na.rm = TRUE)
mean(sr1.rains$wfv.cm50.sb, na.rm = TRUE)
mean(sr1.rains$wfv.cm100.sb, na.rm = TRUE)

mean(sr2.rains$wfv.cm10.sb, na.rm = TRUE)
mean(sr2.rains$wfv.cm30.sb, na.rm = TRUE)
mean(sr2.rains$wfv.cm50.sb, na.rm = TRUE)
mean(sr2.rains$wfv.cm100.sb, na.rm = TRUE)



sd(sr1.rains$wfv.cm10.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm10.hs)))
sd(sr1.rains$wfv.cm30.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm30.hs)))
sd(sr1.rains$wfv.cm50.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm50.hs)))
sd(sr1.rains$wfv.cm100.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm100.hs)))

sd(sr2.rains$wfv.cm10.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm10.hs)))
sd(sr2.rains$wfv.cm30.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm30.hs)))
sd(sr2.rains$wfv.cm50.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm50.hs)))
sd(sr2.rains$wfv.cm100.hs, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm100.hs)))

sd(sr1.rains$wfv.cm10.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm10.sb)))
sd(sr1.rains$wfv.cm30.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm30.sb)))
sd(sr1.rains$wfv.cm50.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm50.sb)))
sd(sr1.rains$wfv.cm100.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr1.rains$wfv.cm100.sb)))

sd(sr2.rains$wfv.cm10.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm10.sb)))
sd(sr2.rains$wfv.cm30.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm30.sb)))
sd(sr2.rains$wfv.cm50.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm50.sb)))
sd(sr2.rains$wfv.cm100.sb, na.rm = TRUE) / sqrt(sum(!is.na(sr2.rains$wfv.cm100.sb)))



sr1.rains$sr1.wfv.hs <- rowMeans(sr1.rains[, c("wfv.cm10.hs", "wfv.cm30.hs", "wfv.cm50.hs", "wfv.cm100.hs")], na.rm = TRUE)
plot(sr1.rains$prec.intensity, sr1.rains$sr1.wfv.hs)
model <- lm(sr1.rains$sr1.wfv.hs ~ sr1.rains$prec.intensity)
slope.sr1.hs <- coef(model)[2]

sr1.rains$sr1.wfv.sb <- rowMeans(sr1.rains[, c("wfv.cm10.sb", "wfv.cm30.sb", "wfv.cm50.sb", "wfv.cm100.sb")], na.rm = TRUE)
plot(sr1.rains$prec.intensity, sr1.rains$sr1.wfv.sb)
model <- lm(sr1.rains$sr1.wfv.sb ~ sr1.rains$prec.intensity)
slope.sr1.sb <- coef(model)[2]

sr2.rains$sr2.wfv.hs <- rowMeans(sr2.rains[, c("wfv.cm10.hs", "wfv.cm30.hs", "wfv.cm50.hs", "wfv.cm100.hs")], na.rm = TRUE)
plot(sr2.rains$prec.intensity, sr2.rains$sr2.wfv.hs)
model <- lm(sr2.rains$sr2.wfv.hs ~ sr2.rains$prec.intensity)
slope.sr2.hs <- coef(model)[2]

sr2.rains$sr2.wfv.sb <- rowMeans(sr2.rains[, c("wfv.cm10.sb", "wfv.cm30.sb", "wfv.cm50.sb", "wfv.cm100.sb")], na.rm = TRUE)
plot(sr2.rains$prec.intensity, sr2.rains$sr2.wfv.sb)
model <- lm(sr2.rains$sr2.wfv.sb ~ sr2.rains$prec.intensity)
slope.sr2.sb <- coef(model)[2]

plot(sr1.rains$prec.depth, sr1.rains$sr1.wfv.hs)
plot(sr1.rains$prec.depth, sr1.rains$sr1.wfv.sb)
plot(sr2.rains$prec.depth, sr2.rains$sr2.wfv.hs)
plot(sr2.rains$prec.depth, sr2.rains$sr2.wfv.sb)

slope.sr1.hs
slope.sr1.sb
slope.sr2.hs
slope.sr2.sb


# No clear preferential flow (deeper layers wetting first) seen, but rising WFV with depth is seen.


################################################################################
# Average slopes
sr2.avg.slope.scalar <- 0.3943


# Checking porosity and saturation against real VWC

# Repeat porosity calculation
df <- read.csv("sr_bulkdensity.csv")
vol <- 98.125
df$a <- df$a/vol; df$b <- df$b/vol
df$a <- df$a / 2.65; df$b <- df$b / 2.65
df$a <- 1 - df$a; df$b <- 1 - df$b
df$rho <- (df$a + df$b)/2 
df$rho[df$site == "sr1" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr1" & df$location == "sb" & df$depth == 100]
df$rho[df$site == "sr2" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr2" & df$location == "sb" & df$depth == 100]
sr1.rho <- df[df$site == "sr1",]; sr2.rho <- df[df$site == "sr2",]

# Confirm these porosities by looking at max VWCs
load("sr1.vwc.rda"); load("sr2.vwc.rda")
sr1 <- sr1.vwc; sr2 <- sr2.vwc
cm10.hs <- max(sr1$cm10[sr1$type=="hs"], na.rm = TRUE)
cm30.hs <- max(sr1$cm30[sr1$type=="hs"], na.rm = TRUE)
cm50.hs <- max(sr1$cm50[sr1$type=="hs"], na.rm = TRUE)
cm100.hs <- max(sr1$cm100[sr1$type=="hs"], na.rm = TRUE)
cm10.sb <- max(sr1$cm10[sr1$type=="sb"], na.rm = TRUE)
cm30.sb <- max(sr1$cm30[sr1$type=="sb"], na.rm = TRUE)
cm50.sb <- max(sr1$cm50[sr1$type=="sb"], na.rm = TRUE)
cm100.sb <- max(sr1$cm100[sr1$type=="sb"], na.rm = TRUE)
maxes <- c(cm10.hs, cm30.hs, cm50.hs, cm100.hs, cm10.sb, cm30.sb, cm50.sb, cm100.sb)
sr1.rho$a <- NULL; sr1.rho$b <- NULL
sr1.rho$max <- maxes
