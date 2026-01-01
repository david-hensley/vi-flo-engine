# Calculating runoff coefficients, soil moisture status, other event statistics 
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(viridis)
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda")
load("sr1.flows.rda"); load("sr2.flows.rda")

################################################################################
# RUNOFF COEFFICIENTS 

# To calculate the runoff coefficient, we need numbers for the catchments sizes
# So we will use WEPP. For SR1: 150 ha, for SR2: 860 ha
sr1w <- 150/860; sr2w <- 1 - sr1w
# Change everything into mm
sr1$precip.mm <- sr1$precip
# Weighted average for SR2 since we assume SR1 covers itself
sr2$precip.mm <- (sr1$precip * sr1w) + (sr2$precip * sr2w) 
# Convert flow variables to mm
sr1$q.mm <- flow.to.mm(150, 15, sr1$q); sr2$q.mm <- flow.to.mm(860, 15, sr2$q)
sr1$quick.mm <- flow.to.mm(150, 15, sr1$quick); sr2$quick.mm <- flow.to.mm(860, 15, sr2$quick)
sr1$base.mm <- flow.to.mm(150, 15, sr1$base); sr2$base.mm <- flow.to.mm(860, 15, sr2$base)
# Add the needed columns to flows
sr1.flows$precip.mm <- sr1.flows$precip.depth
sr1.flows$quick.mm <- NA
sr1.flows$flow.mm <- NA
for (i in 1:nrow(sr1.flows)){
  subset <- sr1[sr1$date >= sr1.flows$start[i] & sr1$date <= sr1.flows$end[i],]
  sr1.flows$quick.mm[i] <- sum(subset$quick.mm)
  sr1.flows$flow.mm[i] <- sum(subset$q.mm)
}
sr2.flows$precip.mm <- NA
sr2.flows$quick.mm <- NA
sr2.flows$flow.mm <- NA
for (i in 1:nrow(sr2.flows)){
  subset <- sr2[sr2$date >= sr2.flows$precip.start[i] & sr2$date <= sr2.flows$end[i],]
  subset2 <- sr2[sr2$date >= sr2.flows$start[i] & sr2$date <= sr2.flows$end[i],]
  sr2.flows$precip.mm[i] <- sum(subset$precip.mm)
  sr2.flows$quick.mm[i] <- sum(subset2$quick.mm)
  sr2.flows$flow.mm[i] <- sum(subset2$q.mm)
  
}
# Event runoff coefficients
sr1.flows$rc <- sr1.flows$quick.mm / sr1.flows$precip.mm 
sr2.flows$rc <- sr2.flows$quick.mm / sr2.flows$precip.mm 
# Inf and maybe NA can occur when there was no actual rainfall observed, so drop these
sr1.flows <- sr1.flows[!is.na(sr1.flows$rc) & !is.infinite(sr1.flows$rc), ]
sr2.flows <- sr2.flows[!is.na(sr2.flows$rc) & !is.infinite(sr2.flows$rc), ]

################################################################################
# SOIL MOISTURE STATUS
# Bring in porosity data
df <- read.csv("sr_bulkdensity.csv")
# bulk density sampler cylinder volume is 98.125 cm3
vol <- 98.125
df$a <- df$a/vol; df$b <- df$b/vol
df$a <- df$a / 2.65; df$b <- df$b / 2.65
df$a <- 1 - df$a; df$b <- 1 - df$b
df$rho <- (df$a + df$b)/2 
# Only one sample was retrievable at 100 cm SB in both places
df$rho[df$site == "sr1" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr1" & df$location == "sb" & df$depth == 100]
df$rho[df$site == "sr2" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr2" & df$location == "sb" & df$depth == 100]
sr1.rho <- df[df$site == "sr1",]; sr2.rho <- df[df$site == "sr2",]
# In the time series record, calculate unsaturated storage and saturated percent
sr1.sat <- sat.unsat(sr1, sr1.rho)
sr2.sat <- sat.unsat(sr2, sr2.rho)
sr1.flows <- saturation(sr1.flows, sr1.sat)
sr2.flows <- saturation(sr2.flows, sr2.sat)
# Antecedent soil water per Farrick and Branfireun 2014
sr1.flows$asw.hs <- NA
sr1.flows$asw.sb <- NA
for (i in 1:nrow(sr1.flows)){
  subset <- sr1[sr1$date >= sr1.flows$precip.start[i] & sr1$date <= sr1.flows$end[i],]
  sr1.flows$asw.hs[i] <- (subset$cm10.hs[1] * 20) + (subset$cm30.hs[1] * 20) +  (subset$cm50.hs[1] * 35) + (subset$cm100.hs[1] * 25)
  sr1.flows$asw.sb[i] <- (subset$cm10.sb[1] * 20) + (subset$cm30.sb[1] * 20) +  (subset$cm50.sb[1] * 35) + (subset$cm100.sb[1] * 25)
}
sr2.flows$asw.hs <- NA
sr2.flows$asw.sb <- NA
for (i in 1:nrow(sr2.flows)){
  subset <- sr2[sr2$date >= sr2.flows$precip.start[i] & sr2$date <= sr2.flows$end[i],]
  sr2.flows$asw.hs[i] <- (subset$cm10.hs[1] * 20) + (subset$cm30.hs[1] * 20) +  (subset$cm50.hs[1] * 35) + (subset$cm100.hs[1] * 25)
  sr2.flows$asw.sb[i] <- (subset$cm10.sb[1] * 20) + (subset$cm30.sb[1] * 20) +  (subset$cm50.sb[1] * 35) + (subset$cm100.sb[1] * 25)
}
# convert to mm
sr1.flows$asw.hs <- sr1.flows$asw.hs * 10
sr1.flows$asw.sb <- sr1.flows$asw.sb * 10
sr2.flows$asw.hs <- sr2.flows$asw.hs * 10
sr2.flows$asw.sb <- sr2.flows$asw.sb * 10

################################################################################
# TIME SINCE LAST FLOW
sr1.flows$recentflow <- NA
for (i in 2:nrow(sr1.flows)){
  sr1.flows$recentflow[i] <- (as.numeric(sr1.flows$start[i]) - as.numeric(sr1.flows$end[i-1])) / 3600
}
sr2.flows$recentflow <- NA
for (i in 2:nrow(sr2.flows)){
  sr2.flows$recentflow[i] <- (as.numeric(sr2.flows$start[i]) - as.numeric(sr2.flows$end[i-1])) / 3600
}
# FLOW AT START OF NEW FLOW EVENT
sr1.flows$qstart <- NA
for (i in 1:nrow(sr1.flows)){
  sr1.flows$qstart[i] <- sr1$q[sr1$date == sr1.flows$start[i]]
}
sr2.flows$qstart <- NA
for (i in 1:nrow(sr2.flows)){
  sr2.flows$qstart[i] <- sr2$q[sr2$date == sr2.flows$start[i]]
}
# PERCENTAGE OF TOTAL EVENT FLOW THAT PRECEDES PEAK
sr1.flows$qfirst <- NA
for (i in 1:nrow(sr1.flows)){
  sr1.flows$qfirst[i] <- mean(sr1$q[sr1$date >= sr1.flows$start[i] & sr1$date <= sr1.flows$peak.time[i]]) / sr1.flows$peak.flow[i]
}
sr2.flows$qfirst <- NA
for (i in 1:nrow(sr2.flows)){
  sr2.flows$qfirst[i] <- mean(sr2$q[sr2$date >= sr2.flows$start[i] & sr2$date <= sr2.flows$peak.time[i]]) / sr2.flows$peak.flow[i]
}
# PERCENTAGE OF EVENT ELAPSED BEFORE PEAK
sr1.flows$whenpeaked <- NA
for (i in 1:nrow(sr1.flows)){
  subset <- sr1[sr1$date >= sr1.flows$start[i] & sr1$date <= sr1.flows$end[i],]
  peaktime <- subset$date[which.max(subset$q)]
  sr1.flows$whenpeaked[i] <- (as.numeric(peaktime) - as.numeric(sr1.flows$start[i])) / (as.numeric(sr1.flows$end[i]) - as.numeric(sr1.flows$start[i]))
}
sr2.flows$whenpeaked <- NA
for (i in 1:nrow(sr2.flows)){
  subset <- sr2[sr2$date >= sr2.flows$start[i] & sr2$date <= sr2.flows$end[i],]
  peaktime <- subset$date[which.max(subset$q)]
  sr2.flows$whenpeaked[i] <- (as.numeric(peaktime) - as.numeric(sr2.flows$start[i])) / (as.numeric(sr2.flows$end[i]) - as.numeric(sr2.flows$start[i]))}
# Rainfall concentration index - how much rain fall in the rainiest 20% of the total period
sr1.flows <- rainfall.concentration(sr1.flows, sr1)
sr2.flows <- rainfall.concentration(sr2.flows, sr2)

################################################################################
# Bind into single summary file
# Remove the flow event during which the scouring occurred - level depths are erroneous
sr1.flows <- sr1.flows[sr1.flows$rc < 0.8,]
sr1.flows$site <- "sr1"
sr2.flows$site <- "sr2"
srrc <- rbind(sr1.flows, sr2.flows) 
srrc$site <- as.factor(srrc$site)
# Save these for continuing use
setwd(wd.analysis)
save(srrc, file= "srrc.rda", compress="xz")     











################################################################################
################################################################################


sr1rc <- srrc[srrc$site == "sr1",]
sr2rc <- srrc[srrc$site == "sr2",]

flows.plot(sr1rc, sr1, "SR1 flows")

sr1 <- sat.unsat(sr1, sr1.rho)
sr1rc$start.sat <- NA
sr1rc$surf.unsat <- NA
for (i in 1:nrow(sr1rc)){
  sr1rc$start.sat[i] <- sr1$sat.hs[sr1$date == sr1rc$start[i]]
  sr1rc$surf.unsat[i] <- sr1$cm10.hs.unsat[sr1$date == sr1rc$start[i]]
}

sr1rc$peakhour <- sr1rc$whenpeaked * sr1rc$duration

flows.plot(sr1rc, sr1, "SR1")
sr1rc0 <- sr1rc
sr1rc$intensity <- sr1rc$precip.mm / (as.numeric(sr1rc$end) - as.numeric(sr1rc$precip.start))/3600


sr1rc <- sr1rc[sr1rc$rc < 0.8,]
sr1rc <- sr1rc[sr1rc$precip.mm > 10,]

plot(sr1rc$precip.intensity, sr1rc$rc)
plot(sr1rc$duration, sr1rc$precip.intensity)
# INTERACTION PRECIP AND STARTING FLOW
plot(sr1rc$precip.depth *  sr1rc$qstart, sr1rc$rc)
plot(sr1rc$intensity, sr1rc$rc)

sr2rc0 <- sr2rc 
sr2rc <- sr2rc0
sr2rc <- sr2rc[sr2rc$rc > 0.0001,]

plot(sr2rc$whenpeaked, sr2rc$rc)
plot(sr2rc$precip.intensity, sr2rc$rc)
plot(sr2rc$precip.depth, sr2rc$rc)

plot(sr2rc$peak.flow, sr2rc$rc)
plot(sr2rc$duration, sr2rc$rc)

plot(sr2rc$duration * sr2rc$precip.mm, sr2rc$rc)
plot(sr2rc$precip.mm, sr2rc$rc)
plot(sr2rc$precip.intensity, sr2rc$rc)
plot(sr2rc$flow.mm, sr2rc$rc)
plot(sr2rc$unsat.mm.hs, sr2rc$flow.mm)

# What about intensity over ksat as an RC predictor? The DUnne plot seems to show this
sr2rc$intensity <- sr2rc$precip.mm / ((as.numeric(sr2rc$end) - as.numeric(sr2rc$precip.start)) / 3600)
sr2rc$ratio <- sr2rc$intensity / 24.65413
plot(sr2rc$ratio, sr2rc$rc)
plot(sr2rc$intensity, sr2rc$rc)
plot(sr2rc$avg.sat.hs, sr2rc$rc) # The best explanation I have is avg.sat.hs and intensity

plot(sr1rc$precip.mm / sr1rc$unsat.mm.hs, sr1rc$rc)
plot(sr2rc$precip.mm / sr2rc$unsat.mm.hs, sr2rc$rc)


# Sample data
x <- sr2rc$intensity 
y <- sr2rc$rc  # y follows an exponential decay

# Nonlinear model
model <- nls(y ~ a * exp(b * x), start = list(a = 1, b = -0.1))

# View the summary of the model
summary(model)



plot(sr1rc$precip.intensity, sr1rc$rc)

##############################
# It appears that there is a negative relationship between precip intensity and RC at both sites
# This is counterintuitive....
#############################

plot(sr2rc$unsat.mm.hs, sr2rc$rc)
plot(sr2rc$unsat.mm.sb, sr2rc$rc)
plot(sr2rc$avg.sat.hs, sr2rc$rc)
plot(sr2rc$avg.sat.sb, sr2rc$rc)
plot(sr2rc$recentflow, sr2rc$rc)
plot(sr2rc$qstart, sr2rc$rc)
plot(sr2rc$qfirst, sr2rc$rc)
plot(sr2rc$whenpeaked, sr2rc$rc)




plot(sr1rc$avg.sat.hs, sr1rc$rc)
plot(sr1rc$avg.sat.sb, sr1rc$rc)

plot(sr1rc$peak.time, sr1rc$rc)
plot(sr1rc$peak.flow, sr1rc$rc)

plot(sr1rc$total.flow, sr1rc$rc)
plot(sr2rc$total.flow, sr2rc$rc)

plot(sr1rc$avg.sat.hs, sr1rc$rc)
plot(sr2rc$avg.sat.hs, sr2rc$rc)

plot(sr1rc$precip.depth, sr1rc$rc)
plot(sr1rc$precip.depth * sr1rc$unsat.mm.sb, sr1rc$rc)
plot(sr1rc$precip.depth * sr1rc$qstart * sr1rc$duration, sr1rc$rc)

plot(sr1rc$precip.depth * sr1rc$qstart * sr1rc$duration, sr1rc$rc)
plot(sr1rc$precip.depth * sr1rc$duration, sr1rc$rc)
plot(sr2rc$precip.depth * sr2rc$duration, sr2rc$rc)
plot(sr2rc$precip.depth * sr2rc$qstart * sr2rc$duration, sr2rc$rc)

plot(sr1rc$precip.depth / sr1rc$duration, sr1rc$rc)
sr1rc$ratio <- sr1rc$precip.depth / sr1rc$duration
plot(log10(sr1rc$precip.depth / sr1rc$duration), sr1rc$rc)


plot(sr1rc$precip.depth, sr1rc$duration)
plot(sr1rc$qstart)

plot(sr1rc$unsat.mm.hs, sr1rc$total.flow)
plot(sr1rc$surf.unsat, sr1rc$total.flow)
plot(sr1rc$avg.sat.hs, sr1rc$total.flow)


plot(sr1rc$duration, sr1rc$rc)
plot(sr1rc$precip.depth, sr1rc$rc)
plot(sr1rc$precip.intensity, sr1rc$rc)
plot(sr1rc$lag, sr1rc$rc)
plot(sr1rc$quick.mm, sr1rc$rc)
plot(sr1rc$unsat.mm.hs, sr1rc$rc)
plot(sr1rc$avg.sat.hs, sr1rc$rc)
plot(sr1rc$unsat.mm.sb, sr1rc$rc)
plot(sr1rc$avg.sat.sb, sr1rc$rc)
plot(sr1rc$recentflow, sr1rc$rc)
plot(sr1rc$qstart, sr1rc$rc)
plot(sr1rc$qfirst, sr1rc$rc)
plot(sr1rc$whenpeaked, sr1rc$rc)
plot(sr1rc$start.sat, sr1rc$rc)
plot(sr1rc$surf.unsat, sr1rc$rc)
plot(sr1rc$peakhour, sr1rc$rc)

plot(sr1rc$whenpeaked * sr1rc$peak.flow, sr1rc$rc)


zvar <- sr1rc$peakhour + 0.0001
# Ensure finite values in zvar before transformation
zvar_finite <- zvar[is.finite(zvar)]  # Filter to finite values only
zvar_log <- log1p(zvar_finite)
zvarname <- "Peak flow time, hours"
colors <- viridis(100)[as.numeric(cut(zvar_log, breaks = 100))]

# Create the plot with custom colors
plot(sr1rc$avg.sat.hs, sr1rc$rc, col = colors, pch = 19,
     xlab = "Average soil saturation, %", ylab = "RC", main = "Upstream salt river")

# Add a color legend, with the original zvar range for interpretation
legend_labels <- expm1(seq(min(zvar_log), max(zvar_log), length.out = 5))  # Reverse log1p
legend("topleft", legend = round(legend_labels, 2), 
       fill = viridis(5), title = zvarname)







zvar <- sr2rc$whenpeaked * sr2rc$duration
# Ensure finite values in zvar before transformation
zvar_finite <- zvar[is.finite(zvar)]  # Filter to finite values only
zvar_log <- log1p(zvar_finite)
zvarname <- "Peak flow time, hours"
colors <- viridis(100)[as.numeric(cut(zvar_log, breaks = 100))]


# Create the plot with custom colors
plot(sr2rc$avg.sat.hs, sr2rc$rc, col = colors, pch = 19,
     xlab = "Average soil saturation, %", ylab = "RC", main = "Downstream salt river")

# Add a color legend, with the original zvar range for interpretation
legend_labels <- expm1(seq(min(zvar_log), max(zvar_log), length.out = 5))  # Reverse log1p
legend("topleft", legend = round(legend_labels, 2), 
       fill = viridis(5), title = zvarname)


plot(sr1rc$precip.mm, sr1rc$avg.sat.hs)

plot(sr1rc$avg.sat.hs, sr1rc$rc)

################################################################################
# Plotting
plot(srrc$precip.mm, srrc$quick.mm)
abline(a = 0, b = 1, col = "red") 
plot(srrc$precip.mm, srrc$rc)

plot(sr1.flows$precip.mm, sr1.flows$quick.mm)
plot(sr2.flows$precip.mm, sr2.flows$quick.mm)
plot(sr1.flows$precip.mm, sr1.flows$rc)
plot(sr2.flows$precip.mm, sr2.flows$rc)

# All time RC
sum(sr1$q.mm) / sum(sr1$precip.mm)
sum(sr2$q.mm) / sum(sr2$precip.mm)

# Annual RC

# Monthly RC

sr1$year.month <- format(sr1$date, "%Y-%m")
sr2$year.month <- format(sr2$date, "%Y-%m")
# Aggregate by year and month
sr1.month <- aggregate(cbind(precip.mm, q.mm) ~ year.month, data = sr1, sum)
sr2.month <- aggregate(cbind(precip.mm, q.mm) ~ year.month, data = sr2, sum)
sr1.month$rc <- sr1.month$q.mm / sr1.month$precip.mm
sr2.month$rc <- sr2.month$q.mm / sr2.month$precip.mm
sr1.month$year.month <- as.Date(paste0(sr1.month$year.month, "-01"), format="%Y-%m-%d")
sr2.month$year.month <- as.Date(paste0(sr2.month$year.month, "-01"), format="%Y-%m-%d")
plot(sr1.month$year.month, sr1.month$rc)
plot(sr2.month$year.month, sr2.month$rc)

  
