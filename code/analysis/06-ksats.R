# Pedotransfer function
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly)
################################################################################
setwd(wd.analysis)
ksats <- read.csv("ksats.csv")
# percent sand silt clay and bd in g/cm3
# This is the WMF330 PTF proposed in Ottoni et al 2019 which fit well
# with both tropical and temperate soils and includes BD, which allows the use of
# the Torri relation described in Nasri et al 2015 for stony soils when 35%+
bds <- read.csv("sr_bulkdensity.csv")
bds$bd <- rowMeans(bds[, c("a", "b")], na.rm = TRUE)
vol <- 98.125
bds$bd <- bds$bd / vol
ksats$bd <- NA
ksats$ksat <- NA
for (i in 1:nrow(ksats)){
  ksats$bd[i] <- bds$bd[bds$site == ksats$site[i] & bds$location == ksats$position[i] & bds$depth == ksats$depth[i]] 
  if (ksats$rw[i] > 0.34){
    ksats$bd[i] <- torri.bdm(ksats$bd[i], ksats$rw[i])
  }
  ksats$ksat[i] <- ottoni.ksat(ksats$silt[i], ksats$clay[i], ksats$bd[i])
}
load("srrc.rda")
srrc$ksat <- NA
for (i in 1:nrow(srrc)){
  if (srrc$site[i] == "sr1"){
    srrc$ksat[i] <- 39.42993
  } else {
    srrc$ksat[i] <- 24.65413
  }
}
# Drop any NAs
srrc <- srrc[!is.na(srrc$unsat.mm.hs),]
srrc$intens <- srrc$precip.mm / srrc$duration
srrc$x <- srrc$intens/srrc$ksat
srrc$y <- srrc$precip.mm / srrc$unsat.mm.hs
#srrc$x <- log10(srrc$x)
#srrc$y <- log10(srrc$y)
srrc$z <- srrc$rc


# Define the color palette and map z to colors
color_palette <- colorRampPalette(c("blue", "green", "yellow", "red"))(100)
library(scales)  # for the scientific notation formatter
ggplot(srrc, aes(x = x, y = y)) +
  # Points with color and shape
  geom_point(aes(color = z, shape = factor(site)), size = 3) +
  # Continuous color scale
  scale_color_gradientn(colors = color_palette, name = "RC") +
  # Shape legend
  scale_shape_manual(values = c(16, 17), 
                     labels = c("SR1", "SR2"), 
                     name = "Site") +
  # Axis labels with subscript for "Ksat" and superscript for units
  labs(
    x = expression(paste("Intensity / K"["sat"], " [mm h"^-1, " / mm h"^-1, "]")),
    y = "Rain depth / Unsaturated storage",
    title = NULL
  ) +
  # Log scale with breaks at whole exponents
  scale_x_continuous(
    trans = 'log10', 
    breaks = c(10^-2, 10^-1, 10^0, 10^1, 10^2, 10^3),  # Specify breaks at whole exponents
    labels = scales::trans_format('log10', scales::math_format(10^.x))  # Format labels as powers of 10
  ) +
  scale_y_continuous(
    trans = 'log10', 
    breaks = c(10^-2, 10^-1, 10^0, 10^1, 10^2, 10^3),  # Specify breaks at whole exponents
    labels = scales::trans_format('log10', scales::math_format(10^.x))  # Format labels as powers of 10
  ) +
  # Theme adjustments
  theme_minimal() +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_line(color = "black", size = 1),
    axis.ticks = element_line(color = "black", size = 1),
    legend.position = "top",  # Place legend at the top
    legend.direction = "horizontal",  # Lay out the legend items horizontally
    legend.box = "horizontal",  # Keep legend items in a horizontal box
    legend.key = element_rect(fill = "white")  # Add space between legend items
  )



################################################################################
# Now constructing a Dunne-plot with rain events included
# Minimum precip threshold is based on Holwerda
load("sr1.rda"); load("sr2.rda")
sr1.rains <- rainfall.delineation(sr1, 6, 0.1575, "America/Port_of_Spain")
sr2.rains <- rainfall.delineation(sr2, 6, 0.1575, "America/Port_of_Spain")
sr1rc <- srrc[srrc$site == "sr1",]; sr2rc <- srrc[srrc$site == "sr2",]

del <- c()
for (i in 1:nrow(sr1rc)){
  del0 <- which(sr1.rains$date.begin >= sr1rc$precip.start[i] & sr1.rains$date.begin <= sr1rc$end[i])
  del <- c(del, del0)
}
sr1.rains <- sr1.rains[-del,]
del <- c()
for (i in 1:nrow(sr2rc)){
  del0 <- which(sr2.rains$date.begin >= sr2rc$precip.start[i] & sr2.rains$date.begin <= sr2rc$end[i])
  del <- c(del, del0)
}
sr2.rains <- sr2.rains[-del,]

# Add unsat and ksat to rains, form x and y, and plot as empties instead of RC 
df <- bds
vol <- 98.125
df$a <- df$a/vol; df$b <- df$b/vol
df$a <- df$a / 2.65; df$b <- df$b / 2.65
df$a <- 1 - df$a; df$b <- 1 - df$b
df$rho <- (df$a + df$b)/2 
# Only one sample was retrievable at 100 cm SB in both places
df$rho[df$site == "sr1" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr1" & df$location == "sb" & df$depth == 100]
df$rho[df$site == "sr2" & df$location == "sb" & df$depth == 100] <- df$a[df$site == "sr2" & df$location == "sb" & df$depth == 100]
sr1.rho <- df[df$site == "sr1",]; sr2.rho <- df[df$site == "sr2",]

sr1 <- sat.unsat(sr1, sr1.rho)
sr2 <- sat.unsat(sr2, sr2.rho)
sr1.rains$unsat <- NA
sr1.rains$ksat <- 39.42993
for (i in 1:nrow(sr1.rains)){
  sr1.rains$unsat[i] <- sr1$unsat.hs[sr1$date == sr1.rains$date.begin[i]]
}
sr2.rains$unsat <- NA
sr2.rains$ksat <- 24.65413
for (i in 1:nrow(sr2.rains)){
  sr2.rains$unsat[i] <- sr2$unsat.hs[sr2$date == sr2.rains$date.begin[i]]
}
sr1.rains$site <- "sr1"
sr2.rains$site <- "sr2"
rains <- rbind(sr1.rains, sr2.rains)
rains$site <- as.factor(rains$site)
rains$intens <- rains$prec.depth / rains$duration
rains$x <- rains$intens/rains$ksat
rains$y <- rains$prec.depth / rains$unsat
#rains$x <- log10(rains$x)
#rains$y <- log10(rains$y)

srrc$runoff <- TRUE
rains$runoff <- FALSE
rains$precip <- rains$prec.depth
rains <- rains[,c("site", "x", "y", "runoff")]
srrc2 <- srrc[,c("site", "x", "y", "runoff")]
all.events <- rbind(rains, srrc2)

x <- all.events$x; y <- all.events$y; z <- all.events$runoff; category <- all.events$site
all.events$z <- all.events$runoff




# Define colors and symbols based on site
site_colors <- c("blue", "green")   # Colors for each site
site_symbols <- c(16, 17)           # Filled circle (16) for site 1, filled triangle (17) for site 2
runoff_symbols <- c(16, 1)          # Filled black circle for TRUE (runoff), open black circle for FALSE (no runoff)
# Plot using ggplot
ggplot(all.events, aes(x = x, y = y)) +
  # Points with color for site
  geom_point(aes(color = factor(site), shape = factor(z)), size = 3) +
  # Color scale for site (blue for SR1, green for SR2), only for filled shapes
  scale_color_manual(values = site_colors, name = "Site", 
                     labels = c("SR1", "SR2")) +
  # Shape scale: filled black circle (16) for TRUE (runoff), open black circle (1) for FALSE (no runoff)
  scale_shape_manual(values = c(1, 16),  # TRUE is now filled (16), FALSE is open (1)
                     labels = c("No runoff", "Runoff"), 
                     name = "Runoff Status") +
  # Axis labels with subscript for "Ksat" and superscript for units
  labs(
    x = expression(paste("Intensity / K"["sat"], " [mm h"^-1, " / mm h"^-1, "]")),
    y = "Rain depth / Unsaturated storage",
    title = NULL
  ) +
  # Log scale with breaks at whole exponents
  scale_x_continuous(
    trans = 'log10', 
    breaks = c(10^-2, 10^-1, 10^0, 10^1, 10^2, 10^3),  # Specify breaks at whole exponents
    labels = scales::trans_format('log10', scales::math_format(10^.x))  # Format labels as powers of 10
  ) +
  scale_y_continuous(
    trans = 'log10', 
    breaks = c(10^-2, 10^-1, 10^0, 10^1, 10^2, 10^3),  # Specify breaks at whole exponents
    labels = scales::trans_format('log10', scales::math_format(10^.x))  # Format labels as powers of 10
  ) +
  # Theme adjustments
  theme_minimal() +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_line(color = "black", size = 1),
    axis.ticks = element_line(color = "black", size = 1),
    legend.position = "top",  # Place legend at the top
    legend.direction = "horizontal",  # Lay out the legend items horizontally
    legend.box = "horizontal",  # Keep legend items in a horizontal box
    legend.key = element_rect(fill = "white")  # Add space between legend items
  ) +
  # Remove unnecessary legends and simplify
  guides(
    shape = guide_legend(order = 1), 
    color = guide_legend(order = 2)
  ) +
  theme(legend.title = element_blank())  # Remove legend titles

