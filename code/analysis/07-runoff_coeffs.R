# Calculating runoff coefficients, soil moisture status, other event statistics
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(viridis); library(ggplot2)
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda")
load("srrc.rda")
srrc$intens <- srrc$precip.mm / srrc$duration
s1 <- srrc[srrc$site == "sr1",]; s2 <- srrc[srrc$site == "sr2",]

################################################################################
# RUNOFF COEFFICIENTS 
# Should use the Dunne ratios as possible predictors
s1$y <- s1$precip.mm / s1$unsat.mm.hs
s1$x <- s1$intens / 39.42993
s2$y <- s2$precip.mm / s2$unsat.mm.hs
s2$x <- s2$intens / 24.65413
s1$aswp.hs <- s1$asw.hs + s1$precip.mm
s1$aswp.sb <- s1$asw.sb + s1$precip.mm
s2$aswp.hs <- s2$asw.hs + s2$precip.mm
s2$aswp.sb <- s2$asw.sb + s2$precip.mm

# Runoff coefficient summary stats
sum(s1$flow.mm)/sum(s1$precip.mm)
sum(s2$flow.mm)/sum(s2$precip.mm)
range(s1$rc)
mean(s1$rc)
range(s2$rc)
mean(s2$rc)

#########################################
# From here, we might plot dunne.x, dunne.y, or rain, or all three, with R2

#flows.plot(s1, sr1, "SR1 flows")
df <- s1
rain <- df$precip.mm
rc <- df$rc
rain <- df$precip.mm
intens <- df$intens
dunne.x <- df$x
dunne.y <- df$y
aswp.hs <- df$aswp.hs
aswp.sb <- df$aswp.sb
asw.hs <- df$asw.hs
asw.sb <- df$asw.sb
rci <- df$rci
whenpeaked <- df$whenpeaked
qfirst <- df$qfirst
qstart <- df$qstart
recentflow <- df$recentflow
duration <- df$duration
#df <- data.frame(rc, rain, dunne.x, dunne.y, qstart, whenpeaked, rci, recentflow)
df <- data.frame(rc, rain, intens, dunne.x, dunne.y, aswp.hs, aswp.sb, rci, whenpeaked, qfirst, qstart, recentflow)
plot(df$rain, df$rc)
plot(df$dunne.y, df$rc)

simple <- lm(rc ~ rain, data = df)
summary(simple)
plot(df$rain, df$rc)
abline(simple) # R2 = 0.533

df <- na.omit(df)
# Assuming df contains columns 'rain' and 'rc'
ggplot(df, aes(x = rain, y = rc)) +
  geom_smooth(method = "lm", color = "red", size = 1.2, se = FALSE) +  # Linear regression line
  geom_point(color = "blue", size = 2) +  # Data points
  scale_x_continuous(expand = c(0, 0), limits = c(0, max(df$rain)+10)) +  # Remove x-axis padding
  scale_y_continuous(expand = c(0, 0), limits = c(min(df$rc), (max(df$rc)+0.1*max(df$rc)))) +  # Match y-axis to data
  labs(
    x = "Rainfall [mm]",  # x-axis label
    y = "Runoff coefficient [-]",  # y-axis label
    title = NULL  # No plot title
  ) +
  theme_minimal() +  # Use minimal theme
  theme(
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    axis.line = element_line(color = "black", size = 1),  # Thicker axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Thicker ticks
    legend.position = "none",  # No legend
    axis.text.x = element_text(size = 12),  # Increase x-axis text size
    axis.text.y = element_text(size = 12)  # Increase y-axis text size
  ) +
  # Annotate R-squared value
  annotate("text", x = max(df$rain) - 50, y = max(df$rc), 
           label = "R² = 0.533", color = "black", size = 4, 
           fontface = "plain", hjust = 0, vjust = 0)


df <- na.omit(df)
# Fit the model using nls, specifying data as df
model <- nls(rc ~ a / (dunne.x + b), data = df, start = list(a = 0.01, b = 0.01))
# View model summary
summary(model)

# Plot the original data points
plot(df$dunne.x, df$rc, main = "Fitted Line vs Actual Data", xlab = "dunne.x", ylab = "rc", pch = 19)
# Generate predictions over a range of x values
x_range <- seq(min(df$dunne.x), max(df$dunne.x), length.out = 100)  # Create a sequence for smooth line
predicted_values <- predict(model, newdata = data.frame(dunne.x = x_range))
# Add the predicted line to the plot
lines(x_range, predicted_values, col = "blue", lwd = 2)
# Get the fitted values from the model
fitted_values <- predict(model)
# Calculate RSS (Residual Sum of Squares)
rss <- sum((df$rc - fitted_values)^2)
# Calculate TSS (Total Sum of Squares)
tss <- sum((df$rc - mean(df$rc))^2)
# Compute R-squared
r_squared <- 1 - (rss / tss)
r_squared # R2 = 0.42047

# Create a dataframe for the predicted line
predicted_df <- data.frame(dunne.x = x_range, rc = predicted_values)

# Create the plot
ggplot(df, aes(x = dunne.x, y = rc)) +
  geom_line(data = predicted_df, aes(x = dunne.x, y = rc), color = "red", size = 1.2) +  # Fitted line
  geom_point(color = "blue", size = 2) +  # Data points
  scale_x_continuous(expand = c(0, 0), limits = c(-0.001, max(df$dunne.x)+0.1)) +  # Adjust x-axis limits
  scale_y_continuous(expand = c(0, 0), 
                     limits = c(-0.001, max(df$rc) + 0.1 * max(df$rc))) +  # Adjust y-axis limits
  labs(
    x = expression(paste("Intensity / K"["sat"], " [mm h"^-1, " / mm h"^-1, "]")),  # x-axis label
    y = "Runoff coefficient [-]",  # y-axis label
    title = NULL  # No plot title
  ) +
  theme_minimal() +  # Use minimal theme
  theme(
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    axis.line = element_line(color = "black", size = 1),  # Thicker axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Thicker ticks
    legend.position = "none",  # No legend
    axis.text.x = element_text(size = 12),  # Increase x-axis text size
    axis.text.y = element_text(size = 12)  # Increase y-axis text size
  ) +
  # Annotate R-squared value in the top-right corner
  annotate("text", x = min(df$dunne.x) + 0.5, y = min(df$rc)+ 0.03, 
           label = paste("R² =", round(r_squared, 3)), color = "black", size = 4, 
           fontface = "plain", hjust = 0, vjust = 0)


#flows.plot(s2, sr2, "SR2 flows")
df <- s2
rain <- df$precip.mm
rc <- df$rc
rain <- df$precip.mm
intens <- df$intens
dunne.x <- df$x
dunne.y <- df$y
aswp.hs <- df$aswp.hs
aswp.sb <- df$aswp.sb
asw.hs <- df$asw.hs
asw.sb <- df$asw.sb
rci <- df$rci
whenpeaked <- df$whenpeaked
qfirst <- df$qfirst
qstart <- df$qstart
recentflow <- df$recentflow
duration <- df$duration
#df <- data.frame(rc, rain, dunne.x, dunne.y, qstart, whenpeaked, rci, recentflow)
df <- data.frame(rc, rain, intens, dunne.x, dunne.y, aswp.hs, aswp.sb, rci, whenpeaked, qfirst, qstart, recentflow)
plot(df$rain, df$rc)
plot(df$dunne.y, df$rc)

simple <- lm(rc ~ rain, data = df)
summary(simple)
plot(df$rain, df$rc)
abline(simple) # R2 = 0.03


df <- na.omit(df)
# Assuming df contains columns 'rain' and 'rc'
ggplot(df, aes(x = rain, y = rc)) +
  geom_smooth(method = "lm", color = "red", size = 1.2, se = FALSE) +  # Linear regression line
  geom_point(color = "blue", size = 2) +  # Data points
  scale_x_continuous(expand = c(0, 0), limits = c(-1, max(df$rain)+10)) +  # Remove x-axis padding
  scale_y_continuous(expand = c(0, 0), limits = c(-0.002, (max(df$rc)+0.1*max(df$rc)))) +  # Match y-axis to data
  labs(
    x = "Rainfall [mm]",  # x-axis label
    y = "Runoff coefficient [-]",  # y-axis label
    title = NULL  # No plot title
  ) +
  theme_minimal() +  # Use minimal theme
  theme(
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    axis.line = element_line(color = "black", size = 1),  # Thicker axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Thicker ticks
    legend.position = "none",  # No legend
    axis.text.x = element_text(size = 12),  # Increase x-axis text size
    axis.text.y = element_text(size = 12)  # Increase y-axis text size
  ) +
  # Annotate R-squared value
  annotate("text", x = max(df$rain) - 50, y = max(df$rc), 
           label = "R² = 0.032", color = "black", size = 4, 
           fontface = "plain", hjust = 0, vjust = 0)





df <- na.omit(df)
# Fit the model using nls, specifying data as df
model <- nls(rc ~ a / (dunne.x + b), data = df, start = list(a = 0.01, b = 0.01))
# View model summary
summary(model)

# Plot the original data points
plot(df$dunne.x, df$rc, main = "Fitted Line vs Actual Data", xlab = "dunne.x", ylab = "rc", pch = 19)
# Generate predictions over a range of x values
x_range <- seq(min(df$dunne.x), max(df$dunne.x), length.out = 100)  # Create a sequence for smooth line
predicted_values <- predict(model, newdata = data.frame(dunne.x = x_range))
# Add the predicted line to the plot
lines(x_range, predicted_values, col = "blue", lwd = 2)

# Get the fitted values from the model
fitted_values <- predict(model)
# Calculate RSS (Residual Sum of Squares)
rss <- sum((df$rc - fitted_values)^2)
# Calculate TSS (Total Sum of Squares)
tss <- sum((df$rc - mean(df$rc))^2)
# Compute R-squared
r_squared <- 1 - (rss / tss)
r_squared # R2 = 0.42047


# Create a dataframe for the predicted line
predicted_df <- data.frame(dunne.x = x_range, rc = predicted_values)

# Create the plot
ggplot(df, aes(x = dunne.x, y = rc)) +
  geom_line(data = predicted_df, aes(x = dunne.x, y = rc), color = "red", size = 1.2) +  # Fitted line
  geom_point(color = "blue", size = 2) +  # Data points
  scale_x_continuous(expand = c(0, 0), limits = c(-0.005, max(df$dunne.x)+0.1)) +  # Adjust x-axis limits
  scale_y_continuous(expand = c(0, 0), 
                     limits = c(-0.002, max(df$rc) + 0.1 * max(df$rc))) +  # Adjust y-axis limits
  labs(
    x = expression(paste("Intensity / K"["sat"], " [mm h"^-1, " / mm h"^-1, "]")),  # x-axis label
    y = "Runoff coefficient [-]",  # y-axis label
    title = NULL  # No plot title
  ) +
  theme_minimal() +  # Use minimal theme
  theme(
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    axis.line = element_line(color = "black", size = 1),  # Thicker axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Thicker ticks
    legend.position = "none",  # No legend
    axis.text.x = element_text(size = 12),  # Increase x-axis text size
    axis.text.y = element_text(size = 12)  # Increase y-axis text size
  ) +
  # Annotate R-squared value in the top-right corner
  annotate("text", x = min(df$dunne.x) + 0.5, y = min(df$rc)+ 0.03, 
           label = paste("R² =", round(r_squared, 3)), color = "black", size = 4, 
           fontface = "plain", hjust = 0, vjust = 0)


