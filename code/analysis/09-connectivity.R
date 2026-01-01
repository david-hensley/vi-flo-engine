# Assessing connectivity
################################################################################
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Analysis", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("david", "online")
library(dplyr); library(plotly)
################################################################################
setwd(wd.analysis); load("sr1.rda"); load("sr2.rda"); load("srrc.rda")

conec <- sr1[,c("date", "q")]
conec$sr1q <- conec$q; conec$q <- NULL
conec$sr2q <- sr2$q
conec$sr2.cm100sb <- sr2$cm100.sb

# Create a few classes of connectivity states:
#    1: "True" connectivity, when both sites are flowing and downstream is greater
#    2: "Losing" connectivity, both sites flowing but downstream lesser
#    3: Only downstream flowing
#    4: Only upstream flowing
#    5: No flow
conec$connectivity <- NA
for (i in 1:nrow(conec)){
  print(i)
  if (conec$sr1q[i] > 0.001 & conec$sr2q[i] > 0.001){
    # When both are flowing
    if (conec$sr1q[i] < conec$sr2q[i]){
      # And downstream is greatest - 
      conec$connectivity[i] <- "Gaining connectivity" #1
    } else {
      # When both flow but downstream is less than or equal, this is losing connectivity
      conec$connectivity[i] <- "Losing connectivity" #2
    }
  } else if (conec$sr2q[i] > 0.001) {
    # Only downstream is flowing
    conec$connectivity[i] <- "Only downstream flow" #3
  } else if (conec$sr1q[i] > 0.001) {
    # Only upstream is flowing
    conec$connectivity[i] <- "Only upstream flow" #4
  } else {
    # No flow
    conec$connectivity[i] <- "No flow" #5
  }
}
conec$connectivity <- as.factor(conec$connectivity)

# Plot to examine
# Create the base plot with one continuous variable as a line
p <- plot_ly(conec, x = ~date) %>%
  add_lines(y = ~sr2.cm100sb, name = 'SR1 flow', line = list(color = 'green'))
# Define neon colors for each class level
neon <- c("#FF00FF", "#00FFFF", "#00FF00", "#FF4500", "#FFFF00")  # Neon magenta, cyan, green, orange, yellow
levels <- unique(conec$connectivity)
# Loop through each class level and find continuous periods (non-overlapping)
for (i in seq_along(levels)) {
  class_df <- conec %>% filter(connectivity == levels[i])
  # Find start and end points for each continuous block of the same class
  runs <- rle(as.character(conec$connectivity))
  end_indices <- cumsum(runs$lengths)
  start_indices <- c(1, head(end_indices, -1) + 1)
  
  # Loop through each period and plot separate rectangles
  for (j in seq_along(start_indices)) {
    if (runs$values[j] == levels[i]) {
      period_df <- conec[start_indices[j]:end_indices[j], ]
      
      p <- p %>%
        add_trace(
          x = c(min(period_df$date), max(period_df$date), max(period_df$date), min(period_df$date)),
          y = c(min(conec$sr1q), min(conec$sr1q),
                max(conec$sr1q), max(conec$sr1q)),
          type = 'scatter',
          fill = 'toself',
          mode = 'none',
          fillcolor = paste0(neon[i], '50'),  # 50% transparency
          name = paste("Class", levels[i]),
          showlegend = FALSE  # Do not show legend for rectangles
        )
    }
  }
  # Add a single legend entry for each class
  p <- p %>%
    add_trace(
      x = c(NA, NA),  # Dummy x-values to avoid drawing a line
      y = c(NA, NA),  # Dummy y-values to avoid drawing a line
      type = 'scatter',
      mode = 'lines',
      line = list(color = neon[i]),
      name = paste("Class", levels[i]),
      showlegend = TRUE  # Show legend for this entry
    )
}
# Show the plot
print(p)

#####################################
# ggplot for paper

library(ggplot2)
library(dplyr)
# Generate neon colors for each class level
neon <- c("#FF00FF", "#00FFFF", "#00FF00", "#FF4500", "#FFFF00")  # Neon magenta, cyan, green, orange, yellow
levels <- unique(conec$connectivity)

events <- data.frame(
  start = as.POSIXct(character(0)),  
  end = as.POSIXct(character(0)),  
  class = factor(character(0))          
)
for (i in 1:nrow(conec)){
  print(i)
  # Do we start a new event?
  if (i == 1){
    # If this is the first row, start an event
    start <- conec$date[i]; class <- conec$connectivity[i]
    # Find the end of the event
    for (j in i:nrow(conec)){
      if (conec$connectivity[j+1] != conec$connectivity[j]){
        # When the next step is a different class than current, it marks the end
        end <- conec$date[j]
        break
      }
    }
    # Collect the info into a dataframe row
    event <- data.frame(start = start, end = end, class = class)
    # Attach to events record
    events <- rbind(events, event)
  } else if (conec$connectivity[i] != conec$connectivity[i-1]){
    # If this is the first row or if the last class was different than this one, it's a new event
    start <- conec$date[i]; class <- conec$connectivity[i]
    # Find the end of the event
    for (j in i:nrow(conec)){
      if (conec$connectivity[j+1] != conec$connectivity[j] | j == nrow(conec)){
        # When the next step is a different class than current, it marks the end
        end <- conec$date[j]
        break
      }
    }
    # Collect the info into a dataframe row
    event <- data.frame(start = start, end = end, class = class)
    # Attach to events record
    events <- rbind(events, event)
  }
}

# Get the global ymin and ymax values (fixed across all shaded regions)
ymin_value <- min(conec$sr2.cm100sb, na.rm = TRUE)
ymax_value <- max(conec$sr2.cm100sb, na.rm = TRUE)

# Update the events dataframe to use the global ymin and ymax
events <- events %>%
  mutate(
    ymin = ymin_value,
    ymax = ymax_value
  )

# Create the ggplot
# Create the ggplot
ggplot(conec, aes(x = date, y = sr2.cm100sb)) +
  # Add shaded regions from the 'events' dataframe
  geom_rect(
    data = events,
    aes(
      xmin = start,
      xmax = end,
      ymin = ymin,  # Fixed ymin for all shaded regions
      ymax = ymax,  # Fixed ymax for all shaded regions
      fill = class
    ),
    inherit.aes = FALSE,
    alpha = 0.5  # Transparency for shaded regions
  ) +
  geom_line(color = "black", size = 1, aes(group = 1)) +
  
  scale_fill_manual(
    values = setNames(neon, levels),
    name = NULL
  ) +
  labs(
    x = NULL,
    y = expression("VWC [cm"^3~cm^{-3}~"]"),  # Correct superscript notation
    title = NULL
  ) +
  scale_x_datetime(
    expand = c(0, 0),  # No padding on the x-axis
    date_breaks = "3 months",  # Tick marks every 3 months
    date_labels = "%m-%Y"  # Format labels as "MM-YYYY"
  ) +
  scale_y_continuous(expand = c(0, 0)) +  # No padding on the y-axis
  theme_minimal() +
  theme(
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    axis.line = element_line(color = "black", size = 1),  # Black axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Black ticks
    legend.position = "top",  # Position legend inside plot area
    legend.title = element_blank(),  # Remove legend title
    axis.text.x = element_text(angle = 45, hjust = 1)  # Rotate x-axis labels for readability
  )


################################################################################
# Simplify the classes for ANOVA

conec$connectivity <- NA
for (i in 1:nrow(conec)){
  print(i)
  if (conec$sr1q[i] > 0.001 & conec$sr2q[i] > 0.001){
    # When both are flowing
    if (conec$sr1q[i] < conec$sr2q[i]){
      # And downstream is greatest - 
      conec$connectivity[i] <- "Connected" #1
    } else {
      # When both flow but downstream is less than or equal, this is losing connectivity
      conec$connectivity[i] <- "Connected" #2
    }
  } else if (conec$sr2q[i] > 0.001) {
    # Only downstream is flowing
    conec$connectivity[i] <- "Disconnected" #3
  } else if (conec$sr1q[i] > 0.001) {
    # Only upstream is flowing
    conec$connectivity[i] <- "Disconnected" #4
  } else {
    # No flow
    conec$connectivity[i] <- "No flow" #5
  }
}
conec$connectivity <- as.factor(conec$connectivity)

# Now buffer the conec data by the lag time in all events
# Begin by collecting a summary list of all connectivity events
# Initialize and add the first event
events <- data.frame(
  start = as.POSIXct(character(0)),  
  end = as.POSIXct(character(0)),  
  class = factor(character(0))          
)
for (i in 1:nrow(conec)){
  print(i)
  # Do we start a new event?
  if (i == 1){
    # If this is the first row, start an event
    start <- conec$date[i]; class <- conec$connectivity[i]
    # Find the end of the event
    for (j in i:nrow(conec)){
      if (conec$connectivity[j+1] != conec$connectivity[j]){
        # When the next step is a different class than current, it marks the end
        end <- conec$date[j]
        break
      }
    }
    # Collect the info into a dataframe row
    event <- data.frame(start = start, end = end, class = class)
    # Attach to events record
    events <- rbind(events, event)
  } else if (conec$connectivity[i] != conec$connectivity[i-1]){
    # If this is the first row or if the last class was different than this one, it's a new event
    start <- conec$date[i]; class <- conec$connectivity[i]
    # Find the end of the event
    for (j in i:nrow(conec)){
      if (conec$connectivity[j+1] != conec$connectivity[j] | j == nrow(conec)){
        # When the next step is a different class than current, it marks the end
        end <- conec$date[j]
        break
      }
    }
    # Collect the info into a dataframe row
    event <- data.frame(start = start, end = end, class = class)
    # Attach to events record
    events <- rbind(events, event)
  }
}
# Now trim the events by the lag time
lag <- 10.09 * 3600
events$start2 <- events$start + lag; events$end2 <- events$end - lag
# If any events were shorter than lag, drop them
#events <- events[(as.numeric(events$end) - as.numeric(events$start)) > lag,]
conec2 <- conec
valid_rows <- logical(nrow(conec))
# Loop through each row of conec
for (i in 1:nrow(conec)) {
  # Check if the date falls within any event range
  valid_rows[i] <- any(as.numeric(conec$date[i]) >= as.numeric(events$start2) & as.numeric(conec$date[i]) <= as.numeric(events$end2))
}
# Subset the conec dataframe based on the valid rows
conec2 <- conec[valid_rows, ]


# One-way ANOVA
result <- aov(sr2.cm100sb ~ connectivity, data = conec2)
# Summary of the ANOVA
summary(result)
plot(conec2$connectivity, conec2$sr2.cm100sb)

# Perform Tukey's HSD post-hoc test
post_hoc <- TukeyHSD(result)
post_hoc$connectivity # All these are different from one another!

ggplot(conec2, aes(x = connectivity, y = sr2.cm100sb)) + 
  geom_violin(fill = "lightblue", color = "black") +  # Adjust violin plot colors
  theme_minimal() +
  labs(
    y = expression("VWC [cm"^3~cm^{-3}~"]"),  # Superscript in y-axis label
    title = NULL  # Remove plot title
  ) +
  theme(
    axis.title.x = element_blank(),  # Remove x-axis label
    axis.text = element_text(size = 12),  # Adjust text size to match
    axis.title.y = element_text(size = 14),  # Adjust y-axis title font size
    axis.line = element_line(color = "black", size = 1),  # Black axis lines
    axis.ticks = element_line(color = "black", size = 1),  # Black axis ticks
    panel.grid.major = element_blank(),  # Remove major grid lines
    panel.grid.minor = element_blank(),  # Remove minor grid lines
    plot.title = element_blank()  # Ensure plot title is removed
  ) +
  # Add annotations near each category
  geom_text(
    data = data.frame(connectivity = levels(conec2$connectivity), label = c("      a", "      b", "      c")), 
    aes(x = connectivity, y = Inf, label = label), 
    vjust = 1.5,  # Move the labels down a bit
    size = 5,  # Adjust size of the annotation text
    fontface = "bold",  # Make the labels bold
    color = "black"  # Color for the annotations
  )


mean(conec2$sr2.cm100sb[conec2$connectivity == "Connected"])
sd(conec2$sr2.cm100sb[conec2$connectivity == "Connected"])/sqrt(nrow(conec2[conec2$connectivity == "Connected",]))

mean(conec2$sr2.cm100sb[conec2$connectivity == "Disconnected"])
sd(conec2$sr2.cm100sb[conec2$connectivity == "Disconnected"])/sqrt(nrow(conec2[conec2$connectivity == "Disconnected",]))

mean(conec2$sr2.cm100sb[conec2$connectivity == "No flow"])
sd(conec2$sr2.cm100sb[conec2$connectivity == "No flow"])/sqrt(nrow(conec2[conec2$connectivity == "No flow",]))

sr2$date[sr2$q == max(sr2$q)]

################################################################################
# Mangrove salinity dataset
salt <- read.csv("salinity.csv")
plot(salt$location, salt$salinity.ppt)
