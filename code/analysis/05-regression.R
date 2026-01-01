# Regression of runoff magnitude
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly); library(viridis)

setwd(wd.analysis); load("sr1.rda"); load("sr2.rda"); load("srrc.rda")
s1 <- srrc[srrc$site == "sr1",]
s2 <- srrc[srrc$site == "sr2",]

################################################################################
# Piecewise regression analysis following Farrick and Branfireun of AWS+P
# Define the piecewise linear model function
# 'x' is the predictor, 'y' is the response variable, and 'bp' is the initial guess for the breakpoint
s1$aswp.hs <- s1$asw.hs + s1$precip.mm
s1$aswp.sb <- s1$asw.sb + s1$precip.mm
plot(s1$aswp.hs, s1$quick.mm) # 350mm starting threshold
plot(s1$aswp.sb, s1$quick.mm) # 315mm starting threshold
s2$aswp.hs <- s2$asw.hs + s2$precip.mm
s2$aswp.sb <- s2$asw.sb + s2$precip.mm
plot(s2$aswp.hs, s2$quick.mm) # 250mm starting threshold?
plot(s2$aswp.sb, s2$quick.mm) # 350mm starting threshold?

################################################################################
s1 <- s1[!is.na(s1$aswp.hs) & !is.na(s1$quick.mm), ]
bp <- 350
x <- s1$aswp.hs
y <- s1$quick.mm
s1.hs <- runoff.threshold(bp, x, y)
bp <- 315
x <- s1$aswp.sb
y <- s1$quick.mm
s1.sb <- runoff.threshold(bp, x, y)
# SR2 has far fewer points for a fit, so we rely on assumption of slope 0 on the left line
s2 <- s2[!is.na(s2$aswp.hs) & !is.na(s2$quick.mm), ]
bp <- 250
x <- s2$aswp.hs
y <- s2$quick.mm
s2.hs <- runoff.threshold2(bp, x, y)
bp <- 350
x <- s2$aswp.sb
y <- s2$quick.mm
s2.sb <- runoff.threshold2(bp, x, y)



