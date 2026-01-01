# All necessary functions for hydrologic analyses (Summer 2024) are stored here
library(dplyr); library(zoo)

######################       SETUP AND IMPORTING          ######################
# Setup and archive functions
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Analysis", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-analysis_functions.R"); wds(hier, dir, suf)
}
wds <- function(hier, dir, suf){
  wd.level <<- paste(hier, dir, suf, "Data/Raw-level", sep = "/")
  wd.weather <<- paste(hier, dir, suf, "Data/Raw-weather", sep = "/")
  wd.vwc <<- paste(hier, dir, suf, "Data/Raw-VWC", sep = "/")
  wd.archive <<- paste(hier, dir, suf, "Data/Archive", sep = "/")
  wd.code <<- paste(hier, dir, suf, "Code/Archiving", sep = "/")
  wd.backup <<- paste(hier, dir, suf, "Data/Backup", sep = "/")
  wd.sites <<- paste(hier, dir, suf, "Data/Site-info", sep = "/")
  wd.nasa <<- paste(hier, dir, suf, "Data/NASA", sep = "/")
  wd.daymet <<- paste(hier, dir, suf, "Data/Daymet", sep = "/")
  wd.raws <<- paste(hier, dir, suf, "Data/Raw-RAWS", sep = "/")
  wd.noaa <<- paste(hier, dir, suf, "Data/NOAA", sep = "/")
  wd.krige <<- paste(hier, dir, suf, "Data/Kriging", sep = "/")
  wd.splices <<- paste(hier, dir, suf, "Data/Splices", sep = "/")
  wd.analysis <<- paste(hier, dir, suf, "Data/Analysis", sep = "/")
  all.wds <- data.frame(wd = c("level", "weather", "vwc", "archive", "code", 
                               "backup", "sites", "nasa", "daymet", "raws", "noaa", "krige", "splices", "analysis"),
                        paths = c(wd.level, wd.weather, wd.vwc, wd.archive, wd.code, 
                                  wd.backup, wd.sites, wd.nasa, wd.daymet, wd.raws, wd.noaa, wd.krige, wd.splices, wd.analysis))
  print(all.wds)
  return(all.wds)
}
haversine.distance <- function(lat1, lon1, lat2, lon2) {
  R <- 6371  # Earth's radius in km
  lat1 <- lat1 * pi / 180
  lon1 <- lon1 * pi / 180
  lat2 <- lat2 * pi / 180
  lon2 <- lon2 * pi / 180
  dlat <- lat2 - lat1
  dlon <- lon2 - lon1
  a <- sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))
  d <- R * c
  return(d)
}
vwc.wide <- function(vwc.long){
  depths <- c("cm10", "cm30", "cm50", "cm100")
  types <- unique(vwc.long$type)
  dates <- unique(vwc.long$date)
  dates <- sort(dates)
  dummy = data.frame(date = dates)
  for (i in 1:length(types)){
    type <- types[i]
    df <- vwc.long[vwc.long$type == type,]
    df$timestamp <- NULL
    df$type <- NULL
    for(j in 1:length(depths)){
      depth <- depths[j]
      newname <- paste0(depth, ".", type)
      colnames(df)[colnames(df) == depth] <- newname
    }
    dummy <- merge(dummy, df, by = "date", all = TRUE)
  }
  result <- dummy
  return(result)
}
# Smooth the q flow between peaks to deal with intrinsic sensor error
# requires user selection of peak protection threshold
qsmoothing <- function(df, roll){
  library(zoo)
  # Computing rolling means
  df$medroll <- rolling.na.mean(df$q, roll)
  df$qdiff <- abs(df$q - df$medroll)
  # Plot smoothed flow
  p <- plot_ly(data = df, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
  p <- p %>% add_trace(x = ~date, y = ~medroll, type = 'scatter', mode = 'lines', name = 'Smoothed Q')
  p <- p %>% add_trace(x = ~date, y = ~qdiff, type = 'scatter', mode = 'lines', name = 'Q diff')
  p <- p %>% layout(title = paste0("Total flow and smoothed flow at site")); print(p)
  repeat {
    cat("Please supply a peak protection threshold based on the plot provided:\n")
    response <- readline(); numeric <- as.numeric(response)
    if (is.na(numeric)) {
      cat("Invalid input! Please enter a numeric value.\n")
    } else if (numeric < 0) {
      cat("Number is outside of an expected range. Try again.\n")
    } else {
      cat("You entered threshold = ", numeric, "\n")
      noise <- numeric
      break  # Exit the inner loop after valid input
    }
  }
  # Identify peaks based on the threshold
  peaks <- which(df$qdiff > noise)
  df$q0 <- df$q
  df$q0[peaks] <- NA  # Set the peak indices to NA
  # Computing rolling means
  df$longroll <- smooth.between.peaks(peaks, df$q0, 1000)
  df$medroll <- smooth.between.peaks(peaks, df$q0, 100)
  df$shortroll <- smooth.between.peaks(peaks, df$q0, 10)
  
  # Initialize the qsmooth column
  df$qsmooth <- df$q  # Start with original data
  # Assign the smoothing based on proximity to peaks
  for (i in 1:nrow(df)) {
    # Handle the last row case
    if (i == nrow(df) && i %in% peaks) {
      df$qsmooth[i] <- df$q[i]
      next  # Skip to the next iteration, avoiding further processing for the last row
    }
    # Forward smoothing
    long <- c(i:min(i + 500, nrow(df)))
    med <- c(i:min(i + 50, nrow(df)))
    short <- c(i:min(i + 5, nrow(df)))
    # Forward peak checking
    if (any(long %in% peaks)){
      long.stop <- peaks[peaks %in% long][1] - 1
      long.splice <- c(i:long.stop)
      df$qsmooth[long.splice] <- df$longroll[long.splice]
      # Check medium range
      if (any(med %in% peaks)){
        med.stop <- peaks[peaks %in% med][1] - 1
        med.splice <- c(i:med.stop)
        df$qsmooth[med.splice] <- df$medroll[med.splice]
        # Check short range
        if (any(short %in% peaks)){
          short.stop <- peaks[peaks %in% short][1] - 1
          short.splice <- c(i:short.stop)
          df$qsmooth[short.splice] <- df$q[short.splice]
        }
      }
    } else {
      # When there is nothing coming up, just use long smoothing the whole period
      df$qsmooth[long] <- df$longroll[long]
    }
    
    # Backward smoothing
    long <- c(max(1, i - 500):i)
    med <- c(max(1, i - 50):i)
    short <- c(max(1, i - 5):i)
    # Backward peak checking
    if (any(long %in% peaks)){
      long.stop <- peaks[peaks %in% long][length(peaks[peaks %in% long])] + 1
      long.splice <- c(long.stop:i)
      df$qsmooth[long.splice] <- df$longroll[long.splice]
      if (any(med %in% peaks)){
        med.stop <- peaks[peaks %in% med][length(peaks[peaks %in% med])] + 1
        med.splice <- c(med.stop:i)
        df$qsmooth[med.splice] <- df$medroll[med.splice]
        if (any(short %in% peaks)){
          short.stop <- peaks[peaks %in% short][length(peaks[peaks %in% short])] + 1
          short.splice <- c(short.stop:i)
          df$qsmooth[short.splice] <- df$q[short.splice]
        }
      }
    } else {
      df$qsmooth[long] <- df$longroll[long]
    }
    # Ensure peak values are recorded faithfully
    if (i %in% peaks){
      df$qsmooth[i] <- df$q[i]
    }
  }
  return(df$qsmooth)
}
# Custom rolling mean function that ignores NAs
rolling.na.mean <- function(x, k) {
  # Use rollapply to compute the rolling mean
  result <- rollapply(x, width = k, 
                      FUN = function(values) mean(values, na.rm = TRUE), # Calculate mean ignoring NAs
                      fill = NA,  # Fill with NA for positions where full window is not available
                      align = "center",  # Align the window to the center
                      partial = TRUE)  # Allow partial windows
  return(result)  # Return the computed rolling mean
}
smooth.between.peaks <- function(peaks, q0, k){
  for (i in 1:length(peaks)){
    # On the first peak, average from the beginning of flow to before first peak
    if (i == 1){
      # Except if the first observation is a peak, then move on
      if (peaks[i] == 1){
        next
      }
      subset <- q0[1:(peaks[i]-1)]
      start <- 1; end <- (peaks[i]-1)
    } else {
      # If it is the last peak
      if (i == length(peaks)){
        if (peaks[i] == length(q0)){
          # When the last peak is in fact the last reading
          next
        }
        subset <- q0[(peaks[i]+1):length(q0)]
        start <- (peaks[i]+1); end <- length(q0)
      } else {
        # When the next peak is adjacent to this one
        if (peaks[i+1] - peaks[i] == 1){
          next
        }
        # Otherwise in normal conditions subset between this peak and the next
        subset <- q0[(peaks[i]+1):(peaks[i+1]-1)]
        start <- (peaks[i]+1); end <- (peaks[i+1]-1)
      }
    }
    qsmooth <- rolling.na.mean(subset, (0.5*length(subset)))
    q0[start:end] <- qsmooth
  }
  return(q0)
}

######################       BASEFLOW SEPARATION          ######################
# This is the master function
k.selection <- function(wd, sitename, df){
  # Here we will follow Duncan's (2019) approach for baseflow separation 
  # He describes "a single backward pass through the observed data to fit
  # an exponential master baseflow recession curve, followed by a single 
  # forward pass of the Lyne and Hollick (1979) algorithms to smooth the
  # connection between segments of the master recession." (p. 310).
  
  # Step 1 is the master recession curve. In the context of baseflow, 
  # "recession" refers to the physically predictable recession of baseflow over 
  # time, which is used to create a "base" between troughs in a hydrograph
  # the equation given is: Mn0 <- (Mn1 - c)/k + c
  
  # "...where Mn1 is the master recession value on day n1, k is the recession constant, 
  # and c is a constant flow added to the exponential decay component (Mn0 is the 
  # resulting master recession value for the current day in question). The output
  # is constrained so that the separated baseflow is not greater than the original
  # streamflow. The master recession should be fitted by eye, using a few 
  # guidelines provided by Duncan. Duncan also notes that the parameters k and c
  # necessarily will vary between catchments, a limitation of this approach, but
  # he suggests this can be resolved in the calibration phase, and is justified by
  # the physically-based nature of this approach as opposed to purely theoretical 
  # objective attempts at baseflow separation in other methods. 
  
  # This function relies on the if() statement forcing the
  # estimated baseflow of the recession curve (df$rec) to be less
  # than or equal to the total discharge df$q. This ensures that 
  # when spikes in the hydrograph occur, the estimated baseflow
  # will also be constrained down to zero. 
  setwd(wd$path[wd$wd=="analysis"])
  # read in k.selections
  k.sel <- read.csv("k.selections.csv")
  # begin with Duncan's default value for ephemeral streams
  k.daily <- 0.91
  constants <- recession.fit(k.daily, df)
  # Record these constants in the log
  cat(paste0("Recording these selections in k.selections.csv for ", sitename, "...\n"))
  k <- nroot(constants$k, 15)
  c <- constants$c
  k.sel$k[k.sel$site == sitename] <- constants$k
  k.sel$c[k.sel$site == sitename] <- c
  k.sel$k.15min[k.sel$site == sitename] <- k
  write.csv(k.sel, "k.selections.csv", row.names = FALSE)
  # Calculate the recession curve with the selected k and c
  init.b <- df$q[nrow(df)] - 0.01*df$q[nrow(df)] # Same initialization as in recession.fit()
  # calculate a recession curve
  df <- master.recession(df, c, k, init.b)
  # Calculate actual baseflow here with Lyne.Holick
  # return df with baseflow calculated and maybe BFI index
  df <- lyne.hollick(df, k)
  # Drop recession curve
  df$rec <- NULL
  # Plot it and ask for user's approval
  p <- plot_ly(data = df, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
  p <- p %>% add_trace(x = ~date, y = ~base, type = 'scatter', mode = 'lines', name = 'Baseflow')
  p <- p %>% layout(title = paste0("Final baseflow, k = ", constants$k, " at site ", sitename)); print(p)
  repeat{
    cat("Does this plot of baseflow look correct? (Y/N)\n")
    response <- readline(); response <- toupper(response)
    if (response == "Y"){
      cat("Baseflow calculation has been accepted! Returning data...\n")
      return(df)
    } else if (response == "N"){
      cat("Baseflow plot rejected. Closing function, please try again!\n")
      return()
    } else {
      cat("Invalid input. Please enter Y or N.\n")
    }
  }
}
# The two functions below are used in baseflow separation
# recession fitting function requires initial estimate of b for final time-step
master.recession <- function(df, c, k, init.b){
  df$rec <- NA
  df$rec[nrow(df)] <- init.b
  for (i in nrow(df):2){
    df$rec[i-1] <- (df$rec[i] - c) / k + c
    if (df$rec[i-1] < 0){
      df$rec[i-1] <- 0
    }
    if (df$rec[i-1] > df$q[i-1]){
      df$rec[i-1] <- df$q[i-1]
    }
  }
  # deal with i = 1
  if (df$rec[1] < 0){
    df$rec[1] <- 0
  }
  if (df$rec[1] > df$q[1]){
    df$rec[1] <- df$q[1]
  }
  return(df)
}
# An inner function used to fit the k constant by eye
recession.fit <- function(k.daily, df){
  repeat {
    # take the nth root of this based on the timestep, the original k is for daily units
    k <- nroot(k.daily, 15)
    # c is set to negative 20% of mean flow (when flow exists), units are
    # m3/s which allows contextualization of why this constant is necessary - it
    # models the fact that some flow is lost to the hyporheic zone, whereas it is 
    # positive in situations of, for example, snowmelt
    c <- -mean(df$q[df$q > 0]) * 0.25
    # acquire initial baseflow estimate for the backwards pass
    # it is 99% of the total flow q, because it is best to assume too high - this
    # will be trimmed off after the analysis anyway
    init.b <- df$q[nrow(df)] - 0.01*df$q[nrow(df)]
    # calculate a recession curve
    df <- master.recession(df, c, k, init.b)
    # Plot with precip to fit the k recession better
    df$precip.plot <- df$precip * -1 
    p <- plot_ly(data = df, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q') %>%
      add_trace(x = ~date, y = ~rec, type = 'scatter', mode = 'lines', name = 'Recession') %>%
      add_trace(x = ~date, y = ~precip.plot, type = 'scatter', mode = 'lines', name = 'Rainfall', yaxis = "y2", line = list(color = 'blue', dash = 'dot')) %>%
      layout(
        title = paste0("Recession curves with daily k = ", k.daily),
        yaxis = list(title = "Discharge (Q)"),
        yaxis2 = list(
          title = "Rainfall (mm)",        # Title for secondary y-axis
          overlaying = "y",               # Overlay on the same x-axis
          side = "right",                 # Place y-axis on the right side
          showgrid = FALSE,               # Option to hide grid lines on secondary y-axis
          range = c(2*min(df$precip.plot), 0)
        )
      )
    print(p)
    
    cat(paste0("Look at this hydrograph and fit k by eye according to Duncan's guidelines:\n",
               "1. Master recession curve should step up during significant rain, unless shortly\n",
               "   after a previous event, where runoff is still present - if not, lower k\n",
               "2. Master recession curve should not lie much below total flow in the absence of rain\n",
               "   except short after an event. If it does, lower k.\n",
               "3. Master recession curve should not cling tightly to total flow in the absence of\n",
               "   rain and be continually held fown by 'not greater than total flow' condition.\n",
               "   If it does, increase k.\n",
               "4. A negative c is necessary if zero flow ever occurs. Typically 'a few percent' of the\n",
               "   mean flow at the site. This was automatically calculated as 20% of mean flow.\n\n"))
    cat(paste0("Does this recession curve fit the guidelines? (Y/N)\n"))
    response <- readline(); response <- toupper(response)
    if (response == "Y") {
      cat(paste0("Returning these chosen k and c values!\n"))
      constants <- list(k = k.daily, c = c)
      return(constants)
    } else if (response == "N") {
      cat("Starting over with a new value for constant k...\n")
      # Start the inner repeat loop to request a valid numeric input
      repeat {
        cat("Please supply a new value for recession constant k (daily):\n")
        response <- readline(); numeric <- as.numeric(response)
        if (is.na(numeric)) {
          cat("Invalid input! Please enter a numeric value.\n")
        } else if (numeric < 0 || numeric > 2) {
          cat("Number is outside of an expected range. Try again.\n")
        } else {
          cat("You entered k = ", numeric, "\n")
          k.daily <- numeric
          break  # Exit the inner loop after valid input
        }
      }
    } else {
      cat("Invalid input. Please enter Y or N.\n")
    }
  }
}
lyne.hollick <- function(df, k){
  # Duncan suggests using the Lyne and Hollick smoothing formula on the recession
  # curve rather than actual total flow as others do with this technique
  # The first pass is forward - thus we need to set the pass1 value at index 1
  # set as equal to the 90% of the initial value of the recession curve
  df$q1 <- NA
  df$q1[1] <- df$rec[1]*0.90
  for (i in 2:nrow(df)){
    df$q1[i] <- k*df$q1[i-1] + ((df$rec[i] - df$rec[i-1]) * ((1+k)/2))
    if(df$q1[i] < 0 ){
      df$q1[i] <- 0
    }
    if (df$q1[i] > df$rec[i]){
      df$q1[i] <- df$rec[i]
    }
  }
  df$base <- df$rec-df$q1
  df$quick <- df$q - df$base
  df$q1 <- NULL
  # Duncan refers to a "single pass" of the digital recursive filter despite
  # what Lyne and Hollick say - so we will stop here
  return(df)
}
# simple function to take a daily k value and return an adjusted k using the nth
# root based on a timestep given in minutes
nroot <- function(daily.k, timestep){
  root <- 1440/timestep
  sub.k <- daily.k^(1/root)
  return(sub.k)
}

######################        EVENT DELINEATION           ######################
# At each point: does the next value go up? If yes, what about the one after that? 
# And so on till the peak is found. Now assess the magnitude, either absolute or relative:
# how much does this spike? If it meets the requirements, classify the current index as event start
# and now move ahead until we either reach the minimum flow threshold or till a new flow event is initiated
# If a new flow event wants to take over, only allow it to do so if the MIT has elapsed since the peak, otherwise continue
# Parameters:
#     --spike     = magnitude of increase over minimum,
#     --threshold = flow value below which flow is taken to be zero or effectively zero, and 
#     --MIT       = minimum inter-event time, in hours, which should match that used for rain events
hydrograph.sep <- function(df, spike, threshold, MIT){
  # initialize events database
  # initialize empty data frame to store storm events
  flow.events <- data.frame(
    event.num = integer(),
    start = integer(),
    end = integer()
  )
  # initialize variables
  event.num <- 0
  start <- NULL
  end <- NULL
  last.peak <- NULL
  for (i in 1:(nrow(df)-1)){
    date <- df$date[i]
    # If this is the first step
    if (i == 1){
      # Check if we should start an event - is there a max ahead?
      # We do not check if we are above threshold as this stops events starting from zero from being initialized
      if (check.max(df, i, spike)){
        # So we begin an event here
        start <- date
        # This now acts as the event number
        event.num <- event.num + 1
        last.peak <- get.spike(df, i, spike) # note down the time of this last peak
      }
    } else {
      # It is not the first step. Check to see whether an event should start now
      if (is.null(start)) {
        # If no event is ongoing, check if we should start one now
        if (check.max(df, i, spike)){
          start <- date
          # This now acts as the event number
          event.num <- event.num + 1 
          last.peak <- get.spike(df, i, spike) # note down the time of this last peak
        }
      } else {
        # An event is ongoing. Should it end?
        # Event should end if we either 1) fall below threshold,
        # or 2) if another event should begin here due to rising flow
        #   --But it shouldn't end if the last spike-peak occurred less than MIT ago
        if (check.max(df, i, spike)){
          # This means a new event wants to begin here
          # To determine if we permit a new event to begin, see how long since last peak, actual or attempted
          time.since.peak <- as.numeric(date) - as.numeric(last.peak)
          time.since.peak <- time.since.peak / 3600 # seconds to hours
          if (time.since.peak > MIT) {
            # If more than the MIT in hours has passed since the last peak, we will begin a new one
            # This entails, first of all, ending the current one
            end <- df$date[i-1] # End the current one at the last observation before this
            flow.event <- data.frame(event.num = event.num, start = start, end = end)
            flow.events <- rbind(flow.events, flow.event)
            # Reset the start and end for the next event
            start <- NULL
            end <- NULL
            # And beginning the new one
            start <- date
            # This now acts as the event number
            event.num <- event.num + 1
          } 
          last.peak <- get.spike(df, i, spike) # Note down regardless the timestamp for the peak ahead
        } else if (df$q[i] <= threshold | df$quick[i] <= threshold){
          # PERHAPS USE (df$quick[i] <= threshold){}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
          # We have fallen below flow threshold or quickflow is near zero, and the event ends
          #   --But it should not end if it has been less than MIT till the start of the next event
          plus.mit <- as.numeric(date) + (MIT*3600)
          plus.mit <- as.POSIXct(plus.mit, origin = "1970-01-01", tz = "America/Port_of_Spain")
          subset <- df[df$date >= date,]
          subset$trystart <- NA
          checks <- seq(from = date, to = plus.mit, by = "15 min")
          # See whether any observations to the end of plus.mit will trigger an event start
          for (j in 1:length(checks)){
            subset$trystart[j] <- check.max(subset, j, spike)
          }
          subset <- subset[subset$date <= plus.mit,]
          if (all(!subset$trystart)){
            # If all the observations from here to plus.mit result in no start of a new event, we can end
            end <- date
            flow.event <- data.frame(event.num = event.num, start = start, end = end)
            flow.events <- rbind(flow.events, flow.event)
            # Reset the start and end for the next event
            start <- NULL
            end <- NULL
          }
        } else if (i == nrow(df)-1) {
          # When an event has started but we reach the end of the data and it didn't naturally end
          end <- date
          flow.event <- data.frame(event.num = event.num, start = start, end = end)
          flow.events <- rbind(flow.events, flow.event)
          # Reset the start and end for the next event
          start <- NULL
          end <- NULL
        } 
      }
    }
  }
  # Now use this to create summary statistics of the flow events
  flow.events$peak.flow = NA
  flow.events$total.flow = NA
  flow.events$total.quick = NA
  flow.events$duration = NA
  flow.events$peak.time = NA
  # Trim the start times and durations of these events by the min threshold
  # such that we make a subset of each event, and see the first obs or first series
  # of obs are less than threshold. When they are, trim this. This may also result 
  # in flow events of length < 1, these should be dropped and event.nums re-ordered.
  for (i in 1:nrow(flow.events)){
    subset <- df[df$date >= flow.events$start[i] & df$date <= flow.events$end[i],]
    rownames(subset) <- NULL
    # Determine if the first few observations sit below the threshold
    if (subset$q[1] < threshold){
      index <- 1  # Setting the index to one to find the index of the last obs below threshold
      # Check ahead for further readings below threshold
      for (j in 2:nrow(subset)) {
        if (subset$q[j] < threshold) {
          index <- index + 1
        } else {
          # If the next value is not greater, break the loop
          break
        }
      }
      # Index of final start observation below observation has been found
      if (index+1 > nrow(subset)){
        # The entire event is cut out in this case, set start equal to end
        true.start <- flow.events$end[i]
      } else {
        true.start <- subset$date[index+1]
      }
      flow.events$start[i] <- true.start # set the new start
      # And create a new subset for summary stats
      subset <- subset[subset$date >= flow.events$start[i] & subset$date <= flow.events$end[i],]
      rownames(subset) <- NULL
    }
    flow.events$peak.flow[i] <- max(subset$q)
    flow.events$total.flow[i] <- sum(subset$q)
    flow.events$total.quick[i] <- sum(subset$quick)
    flow.events$duration[i] <- (as.numeric(flow.events$end[i]) - as.numeric(flow.events$start[i])) / 3600
    flow.events$peak.time[i] <- subset$date[subset$q == max(subset$q)][1]
  }
  flow.events$peak.time <- as.POSIXct(flow.events$peak.time, origin = "1970-01-01", tz = "America/Port_of_Spain")
  
  # Now excise any events that have duration 0 or less
  flow.events <- flow.events[flow.events$duration > 0,]
  # And reset the event numbering
  rownames(flow.events) <- NULL
  flow.events$event.num <- 1:nrow(flow.events)

  # Plot the events
  p <- plot_ly(data = df, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q')
  # Add shading for events
  for(i in 1:nrow(flow.events)) {
    p <- p %>% add_trace(x = c(df$date[df$date == flow.events$start[i]], df$date[df$date == flow.events$end[i]], 
                               df$date[df$date == flow.events$end[i]], df$date[df$date == flow.events$start[i]]),
                         y = c(0, 0, max(df$q), max(df$q)), # Adjust the y-values as needed
                         fill = 'toself', fillcolor = 'rgba(200, 100, 80, 0.4)', 
                         line = list(color = 'rgba(255, 255, 255, 0)'),
                         showlegend = FALSE)
  }
  
  # Add layout options and display plot
  p <- p %>% layout(title = paste0("Flow increase threshold = ", spike, ", minimum flow threshold = ", threshold))
  print(p)
  print(flow.events)
  
  return(flow.events)
}
check.max <- function(df, i, spike){
  # Check if the next value is greater than the current one
  if (df$q[i+1] > df$q[i] + (spike/10)) {
    current.max <- df$q[i]  # Start with the current value
    # Check ahead for the maximum in the increasing sequence
    for (j in (i+1):(nrow(df)-1)) {
      if (df$q[j] > current.max) {
        current.max <- df$q[j]
      } else {
        # If the next value is not greater, break the loop
        break
      }
    }
    # Record the difference between the upcoming max and the current value
    difference <- current.max - df$q[i]
  } else {
    difference <- 0
  }
  if (difference > spike){
    return(TRUE)
  } else {
    return(FALSE)
  }
}
get.spike <- function(df, i, spike){
  # Check if the next value is greater than the current one
  if (df$q[i+1] > df$q[i]) {
    current.max <- df$q[i]  # Start with the current value
    # Check ahead for the maximum in the increasing sequence
    for (j in (i+1):(nrow(df)-1)) {
      if (df$q[j] > current.max) {
        current.max <- df$q[j]
      } else {
        # If the next value is not greater, break the loop
        break
      }
    }
    # Record the difference between the upcoming max and the current value
    difference <- current.max - df$q[i]
  } else {
    difference <- 0
  }
  if (difference > spike){
    subset <- df[df$date >= df$date[i],]
    #maxflow <- df$q[i] + difference
    peaktime <- subset$date[subset$q == current.max][1]
    return(peaktime)
  } else {
    return()
  }
}
rainfall.delineation <- function(data, MIT, minprecip, time.zone) {
  data$time.stamp <- as.numeric(data$date)
  # initialize empty data frame to store storm events
  q.storms <- data.frame(
    time.stamp.begin = integer(),
    time.stamp.end = integer(),
    prec.depth = numeric(),
    prec.intensity = numeric(),
    prec.intensity.max = numeric(),
    duration = numeric()
  )
  
  # MIT from hours to seconds
  MIT.s <- MIT * 3600
  # initialize variables
  start.time <- NULL
  end.time <- NULL
  total.precip <- 0
  max.intensity <- 0
  event.start.index <- NULL
  
  for (i in 1:nrow(data)) {
    timestamp <- data$time.stamp[i]
    precip <- data$precip[i]
    
    # check if current observation exceeds minprecip
    # this also means that any precip readings under minprecip will not get entered into the totals
    if (precip > minprecip) {
      # If start.time is not set, it means a new storm event begins
      if (is.null(start.time)) {
        start.time <- timestamp
        event.start.index <- i
      }
      # update total.precip and max.intensity
      total.precip <- total.precip + precip
      max.intensity <- max(max.intensity, precip)
    } else {
      # if precip falls below minprecip, and start.time is set, check the future MIT period 
      # to see if we should end the event now
      if (!is.null(start.time)) {
        end.MIT <- timestamp + MIT.s # this determines the timestamp of the end of the MIT from now
        # now a subset of the timestamps from the current row to the end of the dataset which are less than the one MIT
        # from now are counted up by the <= logical operator, and summed, and added to the index of the current row
        # which is then subtracted from 1 to correct for the fact that we don't count the current row
        # and the minimum function makes sure that no indexes or timestamps beyond the end of the dataframe are used
        event.end.index <- min(i + sum(data$time.stamp[i:nrow(data)] <= end.MIT) - 1, nrow(data))
        
        # check if any subsequent observation exceeds minprecip within MIT period
        next.mit <- data$precip[i:event.end.index]
        has.rain <- any(next.mit > minprecip)
        
        # if no rain observations found, mark the end of the event at current row
        if (!has.rain) {
          end.time <- data$time.stamp[i]
          
          #calculate the storm parameters
          duration <- (end.time - start.time) / 3600  # convert to hours
          
          # Calculate average intensity
          avg.intensity <- total.precip / (duration)  
          
          # Append storm event information to the data frame
          q.storms <- rbind(q.storms, data.frame(
            time.stamp.begin = start.time,
            time.stamp.end = end.time,
            prec.depth = total.precip,
            prec.intensity = avg.intensity,
            prec.intensity.max = max.intensity,
            duration = duration
          ))
          # Reset variables for the next storm event
          start.time <- NULL
          end.time <- NULL
          total.precip <- 0
          max.intensity <- 0
          event.start.index <- NULL
        }
      }
    }
  }
  # create column with dates in local time in addition to time stamps
  q.storms$date.begin<-q.storms$time.stamp.begin
  q.storms$date.end<-q.storms$time.stamp.end
  class(q.storms$date.begin) = c('POSIXt','POSIXct')
  class(q.storms$date.end) = c('POSIXt','POSIXct')
  attr(q.storms$date.begin, "tzone") <- time.zone
  attr(q.storms$date.end, "tzone") <- time.zone
  
  # creates additional column for antecedent dry period
  q.storms$antecedent.dry.period <- NULL
  # deals with first entry by measuring time since beginning of precip dataset
  q.storms$antecedent.dry.period[1] <- q.storms$time.stamp.begin[1] - data$time.stamp[1]
  
  # loops through all remaining rows in this column by subtracting beginning time of the event minus end of last
  for (i in 1:(nrow(q.storms)-1)){
    q.storms$antecedent.dry.period[i+1] <- q.storms$time.stamp.begin[i+1] - q.storms$time.stamp.end[i]  
  }
  q.storms$antecedent.dry.period <- q.storms$antecedent.dry.period/3600 #returns antecedent dry in hours
  
  # Now let's find the rain centroid
  q.storms$prec.centroid <- NA
  for(i in 1:nrow(q.storms)){
    sub <- data[data$date >= q.storms$date.begin[i] & data$date <= q.storms$date.end[i],]
    sub$timestamp <- as.numeric(sub$date)
    q.storms$prec.centroid[i] <- weighted.mean(sub$timestamp, sub$precip)
  }
  q.storms$prec.centroid <- as.POSIXct(q.storms$prec.centroid, origin = "1970-01-01", tz = "America/Port_of_Spain")
  q.storms <- q.storms[,c("date.begin", "date.end", "prec.centroid", "prec.depth", "prec.intensity", "prec.intensity.max", "duration", "antecedent.dry.period")]
  
  return(q.storms)
}
flows.plot <- function(flows, df, title){
  df$precip.plot <- df$precip * -1 
  # Plot the events
  p <- plot_ly(data = df, x = ~date, y = ~q, type = 'scatter', mode = 'lines', name = 'Total Q') %>%
    add_trace(x = ~date, y = ~base, type = 'scatter', mode = 'lines', name = 'Base') %>%
    add_trace(x = ~date, y = ~precip.plot, type = 'scatter', mode = 'lines', 
              name = 'Rainfall', yaxis = "y2", line = list(color = 'blue', dash = 'dot')) %>%
    layout(
      title = paste0("Events and baseflow before merging"),
      yaxis = list(title = "Discharge (Q)"),
      yaxis2 = list(
        title = "Rainfall (mm)",        # Title for secondary y-axis
        overlaying = "y",               # Overlay on the same x-axis
        side = "right",                 # Place y-axis on the right side
        showgrid = FALSE,               # Option to hide grid lines on secondary y-axis
        range = c(2*min(df$precip.plot), 0)
      )
    )
  # Add shading for events
  for(i in 1:nrow(flows)) {
    p <- p %>% add_trace(x = c(df$date[df$date == flows$start[i]], df$date[df$date == flows$end[i]], 
                               df$date[df$date == flows$end[i]], df$date[df$date == flows$start[i]]),
                         y = c(0, 0, max(df$q), max(df$q)), # Adjust the y-values as needed
                         fill = 'toself', fillcolor = 'rgba(200, 100, 80, 0.4)', 
                         line = list(color = 'rgba(255, 255, 255, 0)'),
                         showlegend = FALSE)
  }
  # Add layout options and display plot
  p <- p %>% layout(title = paste0(title))
  print(p)
}
# Pairs each flow event with rain events - beginning by merging flow events for long rain events
# where no new rain event starts a new flow event, and then by grabbing the preceding rainfall
# event within MIT of the start of the flow event, and excluding this rain from calculation of 
# flow event precip totals of other events. Also calculates lag times in hours, precip in mm
event.pairing <- function(flows, rains, df, spike, threshold, MIT){
  flows.plot(flows, df, "Before merging")
  
  ############################################################################## 
  # Here we perform a first merge, where events not sufficiently independent
  # (determined by a factor of the spike threshold) from a previous or still ongoing
  # even are merged as a single flow event. In this, we lose information about spikes
  # caused by an individual rainstorm but preserve the independence of a single flow event and all the rain 
  # associated with it in aggregate
  flows$merged <- FALSE
  flows$starting.quick <- NA
  for (i in 1:nrow(flows)){
    flows$starting.quick[i] <- df$quick[df$date == flows$start[i]-900]
  }
  
  flows2 <- data.frame(start = as.POSIXct(character()),
                       end = as.POSIXct(character()),
                       merged = logical(), 
                       stringsAsFactors = FALSE)
  for (i in nrow(flows):2){
    if (flows$merged[i]) next  # Skip already merged events
    # If the starting quick flow (less min. thresh) is larger than the spike parameter, 
    # merging with previous event in time is needed to protect event independence
    if (flows$starting.quick[i] > spike - threshold){
      # Initialize a vector to hold the indices of flow events to merge
      merge.indices <- c(i)  # Start with this event index
      # Check all previous events to see if they should be merged
      for (j in i:2) {
        if (flows$starting.quick[j] > spike - threshold) {
          # If a merge is true, add the next iteration number to the merge indices, since a true merge
          # is to be done with the preceding event in every case, and the initialized merged.indices already
          # included the selfsame starting number. This also takes care of the first event in the series,
          # so no firstevent.merged logic is needed
          merge.indices <- c(merge.indices, j-1)
        } else {
          break  # Stop if we find a flow event that doesn't meet the condition
        }
      }
      # Mark the identified flow events as merged
      flows$merged[merge.indices] <- TRUE
      # Create the merged event row
      merged.event <- data.frame(
        start = min(flows$start[merge.indices]),  # Earliest start time
        end = max(flows$end[merge.indices]),      # Latest end time
        merged = TRUE,
        stringsAsFactors = FALSE
      )
      # Add the merged event to flows2
      flows2 <- rbind(flows2, merged.event)
    } else {
      # No merging, so just add the already existing event to flows2
      # If no merging occurs, copy the current row to flows2
      flows2 <- rbind(flows2, data.frame(
        start = flows$start[i],
        end = flows$end[i],
        merged = FALSE,
        stringsAsFactors = FALSE
      ))
    }
  }
  # add event numbering and sort
  flows2$event.num <- c(nrow(flows2):1)
  flows2 <- flows2[order(flows2$event.num), ]
  rownames(flows2) <- NULL; flows <- flows2
  flows <- flows[,c("event.num", "start", "end")]
  
  flows.plot(flows, df, "After first merge")
  
  ##############################################################################
  # Second, we deal with falsely separated flow events when rain was ongoing:
  # Add a column to track merged events
  flows$merged <- FALSE
  # Initialize the flows2 dataframe
  flows2 <- data.frame(start = as.POSIXct(character()),
                       end = as.POSIXct(character()),
                       merged = logical(), 
                       stringsAsFactors = FALSE)
  # Check when finding the start-rain to see whether that rain event 
  # began before the start of the previous flow event. If it did, that single
  # rain event really caused both the previous flow and the current one, 
  # and these should be pooled together.
  firstevent.merged <- FALSE # This tells us whether the first event in time is part of a merge or not
  for (i in nrow(flows):2){
    if (flows$merged[i]) next  # Skip already merged events
    # For these purposes the start is the event start minus MIT hours
    start <- as.POSIXct((as.numeric(flows$start[i]) - (MIT*3600)), origin = "1970-01-01", tz = "America/Port_of_Spain")
    # Select the rain event that immediately resulted in this flow event, take the first when there are a few
    rainevent <- rains[rains$date.begin <= flows$end[i] & rains$date.end >= start, ]
    if (nrow(rainevent) == 0){
      # This is for when there is no rain event for this flow event - in such a case it should be simply deleted
      # We accomplish this by moving to the next iteration without adding the event to flows2
      next
    }
    rainevent <- rainevent[1,]
    # Record the start time of the rain event
    rainstart <- rainevent$date.begin
    # If the rain started before the beginning of the previous event in the series, merging is needed
    if (rainstart < flows$start[i-1]){
      # Initialize a vector to hold the indices of flow events to merge
      merge.indices <- c(i)  # Start with the current event index
      # Check previous events to see if they should also be merged
      for (j in (i-1):1) {
        if (rainstart < flows$start[j]) {
          if (j == 1){
            firstevent.merged <- TRUE
          }
          merge.indices <- c(merge.indices, j)
        } else {
          break  # Stop if we find a flow event that doesn't meet the condition
        }
      }
      # Mark the identified flow events as merged
      flows$merged[merge.indices] <- TRUE
      # Create the merged event row
      merged.event <- data.frame(
        start = min(flows$start[merge.indices]),  # Earliest start time
        end = max(flows$end[merge.indices]),      # Latest end time
        merged = TRUE,
        stringsAsFactors = FALSE
      )
      # Add the merged event to flows2
      flows2 <- rbind(flows2, merged.event)
    } else {
      # No merging, so just add the already existing event to flows2
      # If no merging occurs, copy the current row to flows2
      flows2 <- rbind(flows2, data.frame(
        start = flows$start[i],
        end = flows$end[i],
        merged = FALSE,
        stringsAsFactors = FALSE
      ))
    }
  }
  if (firstevent.merged == FALSE){
    # When the first event was part of no merge, it must be attached to flows2 now
    flows2 <- rbind(flows2, data.frame(
      start = flows$start[1],
      end = flows$end[1],
      merged = FALSE,
      stringsAsFactors = FALSE
    ))
  }
  # add event numbering and sort
  flows2$event.num <- c(nrow(flows2):1)
  flows2 <- flows2[order(flows2$event.num), ]
  rownames(flows2) <- NULL; flows <- flows2
  flows <- flows[,c("event.num", "start", "end")]
  
  flows.plot(flows, df, "After second merge")
  ##############################################################################
  
  # Flow summary stats must be recalculated, initialize them now
  flows$peak.time <- NA
  flows$peak.flow <- NA
  flows$total.flow <- NA
  flows$total.quick <- NA
  flows$duration <- NA
  # And some additional statistics
  flows$precip.start <- NA
  flows$precip.depth <- NA
  flows$precip.intensity <- NA
  flows$lag <- NA # For this find the centroid of the event ongoing or preceding the peak
  flows$peaklag <- NA # This will be peak rain to peak flow
  
  # From the last event, move backwards.
  # Look at the beginning of the event, is there a rain event ongoing
  # or having ended within MIT? If yes, pair this rain event to the
  # flow event. Then all take all rain that occurred during flow event,
  # except for any rain from rain events already marked as paired
  # (i.e., rain events that initiated a new event), and sum it for this
  rains$paired <- FALSE
  rains$indices <- c(1:nrow(rains))
  flows$del <- FALSE
  for (i in nrow(flows):1){
    print(i)
    start <- as.POSIXct((as.numeric(flows$start[i]) - (MIT*3600)), origin = "1970-01-01", tz = "America/Port_of_Spain")
    rainevent <- rains[rains$date.begin <= flows$end[i] & rains$date.end >= start, ]; rainevent <- rainevent[1,]
    # Begin calculating summary statistics
    subset <- df[df$date >= flows$start[i] & df$date <= flows$end[i],]
    rownames(subset) <- NULL
    flows$peak.flow[i] <- max(subset$q)
    flows$total.flow[i] <- sum(subset$q) # This is just the crude flow during the event
    
    flows$total.quick[i] <- sum(subset$quick)
    flows$duration[i] <- (as.numeric(flows$end[i]) - as.numeric(flows$start[i])) / 3600
    flows$peak.time[i] <- subset$date[subset$q == max(subset$q)][1]
    flows$precip.start[i] <- rainevent$date.begin
    # Collect all rain events that occurred from start of rain for this event to event end
    all.event.rain <- rains[rains$date.begin < flows$end[i] & rains$date.end >= start, ]
    # Now remove those events that are paired already
    all.event.rain <- all.event.rain[all.event.rain$paired == FALSE,]
    if (nrow(all.event.rain) == 0){
      # This is a special case where the rain event was already paired, so we must resolve the conflict
      rainset <- df[df$date >= rainevent$date.begin & df$date <= rainevent$date.end,]
      # Do this by favoring the flow event where the peak flow is observed after the peak rain
      rainpeak <- rainset$date[rainset$precip == max(rainset$precip)]
      if (flows$peak.time[i] >= as.numeric(rainpeak)){
        # This means we will reassign this rain event to our current event and merge the later one with this one
        rains$paired[rainevent$indices] <- FALSE # Re-class the rain event as not paired
        # Recalculate event rain
        all.event.rain <- rains[rains$date.begin < flows$end[i] & rains$date.end >= start, ]
        # Merge the two flow events
        flows$end[i] <- flows$end[i+1]
        flows$peak.flow[i] <- max(subset$q)
        flows$total.flow[i] <- sum(subset$q) # This is just the crude flow during the event
        flows$total.quick[i] <- sum(subset$quick)
        flows$duration[i] <- (as.numeric(flows$end[i]) - as.numeric(flows$start[i])) / 3600
        flows$peak.time[i] <- subset$date[subset$q == max(subset$q)][1]
        flows$precip.start[i] <- rainevent$date.begin
        flows$del[i+1] <- TRUE
      } else if (flows$end[i-1] + 900 == flows$end[i]) { 
        # This means the current even sees its rainfall peak after its peak flow,
        # so attach it to the previous event in time if it was immediately before now
        flows$end[i-1] <- flows$end[i]
        flows$del[i] <- TRUE
      } else {
        # But just delete if not
        flows$del[i] <- TRUE
      }
    }
    rains$paired[rainevent$indices] <- TRUE # Marked as a paired event so as to ignore this rain in summary calculations
    flows$precip.depth[i] <- sum(all.event.rain$prec.depth)
    # The duration of rainfall, hours
    rain.period <- (as.numeric(all.event.rain$date.end[nrow(all.event.rain)]) - as.numeric(all.event.rain$date.begin[1])) / 3600
    flows$precip.intensity[i] <- flows$precip.depth[i] / rain.period
    flows$lag[i] <- (as.numeric(flows$peak.time[i]) - as.numeric(all.event.rain$prec.centroid[1])) / 3600
    # Subset the actual hyetograph to get the time of max rain of the initial rain event
    rain.subset <- df[df$date >= all.event.rain$date.begin[1] & df$date <= all.event.rain$date.end[1], ]
    rain.peak <- rain.subset$date[rain.subset$precip == max(rain.subset$precip)][1]
    flows$peaklag[i] <- (as.numeric(flows$peak.time[i]) - as.numeric(rain.peak)) / 3600
  }
  flows$peak.time <- as.POSIXct(flows$peak.time, origin = "1970-01-01", tz = "America/Port_of_Spain")
  flows$precip.start <- as.POSIXct(flows$precip.start, origin = "1970-01-01", tz = "America/Port_of_Spain")
  # If anything was merged, delete the leftovers now
  flows <- flows[flows$del == FALSE,]
  # Now delete flow events where precip was less than 1 mm - these are generally artifacts of rain gauge errors
  flows <- flows[flows$precip.depth >= 1,]
  flows$event.num <- c(1:nrow(flows)); rownames(flows) <- NULL; flows$del <- NULL
  return(flows)
}

######################       RUNOFF COEFFICIENTS          ######################
# receive area in ha and timestep in min to convert m3/s to mm of flow variables
flow.to.mm <- function(area, timestep, flow){
  flow.m3 <- flow * 60 * timestep
  flow.m <- flow.m3 / (area * 10000)
  flow.mm <- flow.m * 1000
  return(flow.mm)
}
saturation <- function(flows, df){
  flows$unsat.mm.hs <- NA
  flows$avg.sat.hs <- NA
  flows$unsat.mm.sb <- NA
  flows$avg.sat.sb <- NA
  for (i in 1:nrow(flows)){
    flows$unsat.mm.hs[i] <- df$unsat.hs[df$date == flows$start[i]]
    flows$unsat.mm.sb[i] <- df$unsat.sb[df$date == flows$start[i]]
    flows$avg.sat.hs[i] <- mean(df$sat.hs[df$date >= flows$start[i] & df$date <= flows$end[i]])
    flows$avg.sat.sb[i] <- mean(df$sat.sb[df$date >= flows$start[i] & df$date <= flows$end[i]])
  }
  return(flows)
}
sat.unsat <- function(df, rho){
  # Renders unsaturated storage in mm
  df$cm10.hs.unsat  <- (rho$rho[rho$location == "hs" & rho$depth == 10] - df$cm10.hs)   * 200
  df$cm10.hs.sat    <- (df$cm10.hs / rho$rho[rho$location == "hs" & rho$depth == 10])   * 100
  df$cm30.hs.unsat  <- (rho$rho[rho$location == "hs" & rho$depth == 30] - df$cm30.hs)   * 200
  df$cm30.hs.sat    <- (df$cm30.hs / rho$rho[rho$location == "hs" & rho$depth == 30])   * 100
  df$cm50.hs.unsat  <- (rho$rho[rho$location == "hs" & rho$depth == 50] - df$cm50.hs)   * 350
  df$cm50.hs.sat    <- (df$cm50.hs / rho$rho[rho$location == "hs" & rho$depth == 50])   * 100
  df$cm100.hs.unsat <- (rho$rho[rho$location == "hs" & rho$depth == 100] - df$cm100.hs) * 250
  df$cm100.hs.sat   <- (df$cm100.hs / rho$rho[rho$location == "hs" & rho$depth == 100]) * 100
  df$unsat.hs       <- df$cm10.hs.unsat + df$cm30.hs.unsat + df$cm50.hs.unsat + df$cm100.hs.unsat
  df$sat.hs         <- df$cm10.hs.sat * 0.2 + df$cm30.hs.sat * 0.2 + df$cm50.hs.sat * 0.35 + df$cm100.hs.sat * 0.25
  
  df$cm10.sb.unsat  <- (rho$rho[rho$location == "sb" & rho$depth == 10] - df$cm10.sb)   * 200
  df$cm10.sb.sat    <- (df$cm10.sb / rho$rho[rho$location == "sb" & rho$depth == 10])   * 100
  df$cm30.sb.unsat  <- (rho$rho[rho$location == "sb" & rho$depth == 30] - df$cm30.sb)   * 200
  df$cm30.sb.sat    <- (df$cm30.sb / rho$rho[rho$location == "sb" & rho$depth == 30])   * 100
  df$cm50.sb.unsat  <- (rho$rho[rho$location == "sb" & rho$depth == 50] - df$cm50.sb)   * 350
  df$cm50.sb.sat    <- (df$cm50.sb / rho$rho[rho$location == "sb" & rho$depth == 50])   * 100
  df$cm100.sb.unsat <- (rho$rho[rho$location == "sb" & rho$depth == 100] - df$cm100.sb) * 250
  df$cm100.sb.sat   <- (df$cm100.sb / rho$rho[rho$location == "sb" & rho$depth == 100]) * 100
  df$unsat.sb       <- df$cm10.sb.unsat + df$cm30.sb.unsat + df$cm50.sb.unsat + df$cm100.sb.unsat
  df$sat.sb         <- df$cm10.sb.sat * 0.2 + df$cm30.sb.sat * 0.2 + df$cm50.sb.sat * 0.35 + df$cm100.sb.sat * 0.25
  return(df)
}
rainfall.concentration <- function(flows, df){
  flows$rci <- NA
  df0 <- df
  for (i in 1:nrow(flows)){
    print(i)
    df <- df0[df0$date >= flows$precip.start[i] & df0$date <= flows$end[i],]
    # Divide data into 12 intervals, or the number of rows, whichever is less
    n_intervals <- min(20, nrow(df)) # Use either 12 or the row count, whichever is smaller
    df$interval <- cut(df$date, breaks = n_intervals, labels = FALSE)
    # Sum rainfall in each interval
    interval_sums <- aggregate(precip ~ interval, data = df, sum)
    # Sort intervals by rainfall amount (descending)
    interval_sums <- interval_sums[order(interval_sums$precip, decreasing = TRUE), ]
    # Calculate the total rainfall in the event
    total_rainfall <- sum(interval_sums$precip)
    # Select the top 25% of intervals (top 3 if you have 12 intervals)
    top <- ceiling((1/20) * n_intervals)
    top_intervals <- interval_sums[1:top, ]
    # Calculate Rainfall Concentration Index (RCI)
    flows$rci[i] <- sum(top_intervals$precip) / total_rainfall
  }
  return(flows)
}

######################        REGRESSION MODELS           ######################
# This is an altered form of runoff.threshold() that takes the right hand line
# and uses its x intercept to assume the left hand line has slope = 0
runoff.threshold2 <- function(bp, x, y, label) {
  library(ggplot2)
  # Optimize the breakpoint to minimize the RMSE
  optimal <- optim(par = bp, fn = piecewise.nest, x = x, y = y, method = "Brent",
                   lower = min(x, na.rm = TRUE), upper = max(x, na.rm = TRUE))
  # Extract the optimal breakpoint and RMSE
  thresh <- piecewise.model(optimal$par, x, y)$bp
  cat("Optimal Breakpoint:", thresh, "\n")
  cat("Minimum RMSE:", optimal$value, "\n")
  # Prepare data for plotting
  xvalid <- x[!is.na(x)]
  result <- piecewise.model(thresh, x, y)
  data <- data.frame(x = x, y = y)
  
  # Create data for the fitted lines
  left_line <- data.frame(
    x = seq(min(xvalid), thresh, length.out = 100),
    y = 0,  # Left segment is a flat zero line
    segment = "Left"
  )
  # Adjust the intercept of the right segment for plotting
  left.y <- 0  # Since the left slope and intercept are both zero
  right.y <- result$right.slope * thresh + result$right.intercept
  adjustment <- left.y - right.y
  adjusted.right.b <- result$right.intercept + adjustment
  
  right_line <- data.frame(
    x = seq(thresh, max(xvalid), length.out = 100),
    y = result$right.slope * seq(thresh, max(xvalid), length.out = 100) + adjusted.right.b,
    segment = "Right"
  )
  # Combine line data
  lines_data <- rbind(left_line, right_line)
  
  # Create ggplot
  p <- ggplot(data, aes(x = x, y = y)) +
    geom_line(data = lines_data, aes(x = x, y = y, color = segment), size = 1.2) +
    geom_point(color = "blue", size = 2) +
    scale_color_manual(values = c("Left" = "red", "Right" = "green")) +
    geom_vline(xintercept = thresh, linetype = "dashed", color = "black") +
    scale_x_continuous(limits = c(150, 500)) +  # Set x-axis limits
    scale_y_continuous(limits = c(0, 30)) +  # Set y-axis limits
    labs(
      x = "ASW+P (mm)",
      y = "Quickflow (mm)",
      title = NULL
    ) +
    theme_minimal() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(color = "black", size = 1),
      axis.ticks = element_line(color = "black", size = 1),
      legend.position = "none"
    ) +
    annotate(
      "text",
      x = 150,
      y = 20,
      label = label,
      size = 4.5,  # Adjust size to make it large
      hjust = 0,  # Left-align the text
      vjust = 1   # Align the top of the text to the y position
    )
  print(p)
  
  #return(list(
  #  rmse = optimal$value,
  #  left.slope = 0,
  #  left.intercept = 0,
  #  right.slope = result$right.slope,
  #  right.intercept = result$right.intercept,
  #  bp = thresh
  #))
  return(p)
}
runoff.threshold <- function(bp, x, y, label) {
  library(ggplot2)
  # Optimize the breakpoint to minimize the RMSE
  optimal <- optim(par = bp, fn = piecewise.nest, x = x, y = y, method = "Brent",
                   lower = min(x, na.rm = TRUE), upper = max(x, na.rm = TRUE))
  # Extract the optimal breakpoint and RMSE
  thresh <- piecewise.model(optimal$par, x, y)$bp
  cat("Optimal Breakpoint:", thresh, "\n")
  cat("Minimum RMSE:", optimal$value, "\n")
  # Prepare data for plotting
  xvalid <- x[!is.na(x)]
  result <- piecewise.model(thresh, x, y)
  data <- data.frame(x = x, y = y)
  
  # Create data for the fitted lines
  left_line <- data.frame(
    x = seq(min(xvalid), thresh, length.out = 100),
    y = result$left.slope * seq(min(xvalid), thresh, length.out = 100) + result$left.intercept,
    segment = "Left"
  )
  # Adjust the intercept of the right segment for plotting
  left.y <- result$left.slope * thresh + result$left.intercept
  right.y <- result$right.slope * thresh + result$right.intercept
  adjustment <- left.y - right.y
  adjusted.right.b <- result$right.intercept + adjustment
  
  right_line <- data.frame(
    x = seq(thresh, max(xvalid), length.out = 100),
    y = result$right.slope * seq(thresh, max(xvalid), length.out = 100) + adjusted.right.b,
    segment = "Right"
  )
  # Combine line data
  lines_data <- rbind(left_line, right_line)
  
  # Create ggplot
  p <- ggplot(data, aes(x = x, y = y)) +
    geom_line(data = lines_data, aes(x = x, y = y, color = segment), size = 1.2) +
    geom_point(color = "blue", size = 2) +
    scale_color_manual(values = c("Left" = "red", "Right" = "green")) +
    geom_vline(xintercept = thresh, linetype = "dashed", color = "black") +
    scale_x_continuous(limits = c(150, 500)) +  # Set x-axis limits
    scale_y_continuous(limits = c(0, 30)) +  # Set y-axis limits
    labs(
      x = "ASW+P (mm)",
      y = "Quickflow (mm)",
      title = NULL
    ) +
    theme_minimal() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(color = "black", size = 1),
      axis.ticks = element_line(color = "black", size = 1),
      legend.position = "none"
    ) +
    annotate(
      "text",
      x = 150,
      y = 20,
      label = label,
      size = 4.5,  # Adjust size to make it large
      hjust = 0,  # Left-align the text
      vjust = 1   # Align the top of the text to the y position
    )
  print(p)
  #return(piecewise.model(thresh, x, y))
  return(p)
}
# Function for piecewise breakpoint selection
piecewise.model <- function(bp, x, y) {
  # Remove NAs in x or y
  valid <- !is.na(x) & !is.na(y)
  x <- x[valid]; y <- y[valid]
  # Split predictor into two parts based on breakpoint
  left <- x <= bp
  right <- x > bp
  # Initialize vectors for predictions
  predicted <- rep(NA, length(x))  # Start with all NAs to avoid issues
  left.slope <- left.intercept <- right.slope <- right.intercept <- NA  # Default to NA
  

  # Fit and predict for the left segment and right segements
  if (any(left)) {
    left.model <- lm(y[left] ~ x[left])
    left.slope <- coef(left.model)[2]
    left.intercept <- coef(left.model)[1]
    # Predictions for the left segment
    predicted[left] <- predict(left.model, newdata = data.frame(x = x[left]))
  }
  if (any(right)) {
    right.model <- lm(y[right] ~ x[right])
    right.slope <- coef(right.model)[2]
    right.intercept <- coef(right.model)[1]
    # Predictions for the right segment
    predicted[right] <- predict(right.model, newdata = data.frame(x = x[right]))
  }
  
  # If either slope is NA, return a large penalty value (e.g., Inf)
  if (is.na(left.slope) || is.na(right.slope)) {
    return(list(
      rmse = 1e10, # A very large value, effectively ignoring this run in the optimization
      left.slope = 1,
      left.intercept = 0,
      right.slope = 1,
      right.intercept = 0,
      bp = bp  # New breakpoint where the lines intersect
    ))
    return(1e10)  # A very large value, effectively ignoring this run in the optimization
  }
  
  # Now, calculate the intersection point of the two lines
  # Solving for x:
  if (left.slope != right.slope) {
    new.bp <- (right.intercept - left.intercept) / (left.slope - right.slope)
  } else {
    # If slopes are equal, lines are parallel, no intersection
    new.bp <- bp
  }
  
  # Weighting function: Inverse distance from the median of y in the left segment (flat region)
  median.left <- median(y[left], na.rm = TRUE)
  weight.left <- 1 / (abs(y[left] - median.left) + 1)  # Use +1 to avoid division by zero
  median.right <- median(y[right], na.rm = TRUE)
  weight.right <- 1 / (abs(y[right] - median.right) + 1)
  # Calculate weighted RMSE for the left and right segments
  left.rmse <- sqrt(sum(weight.left * (y[left] - predicted[left])^2, na.rm = TRUE) / sum(weight.left, na.rm = TRUE))
  right.rmse <- sqrt(sum(weight.right * (y[right] - predicted[right])^2, na.rm = TRUE) / sum(weight.right, na.rm = TRUE))
  # Return the average weighted RMSE for both segments
  avg.rmse <- (left.rmse + right.rmse) / 2
  
  return(list(
    rmse = avg.rmse,
    left.slope = left.slope,
    left.intercept = left.intercept,
    right.slope = right.slope,
    right.intercept = right.intercept,
    bp = new.bp  # New breakpoint where the lines intersect
  ))
}
# Nest the above function to get only rmse for optimization
piecewise.nest <- function(bp, x, y){
  result <- piecewise.model(bp, x, y)
  return(result$rmse)
}

# Provide a df where the first column is response and the rest are predictors - all numeric predictors only
# Function for fitting a linear model with Lasso regularization
fit_linear_lasso <- function(df) {
  library(glmnet)
  y <- df[,1] # extract the response variable
  predictors <- df[,c(2:ncol(df))]
  X <- as.matrix(predictors)
  # Fit a Lasso model (alpha = 1 for Lasso)
  lasso_model <- cv.glmnet(X, y, alpha = 1, standardize = TRUE) 
  # Get the best lambda (penalty parameter) from cross-validation
  best_lambda <- lasso_model$lambda.min
  # Fit the model using the best lambda
  final_model <- glmnet(X, y, alpha = 1, lambda = best_lambda, standardize = TRUE)
  # Extract the coefficients for the best lambda
  coefficients <- coef(final_model, s = best_lambda)
  # Predict on the training set
  predictions <- predict(final_model, s = best_lambda, newx = X)
  # Calculate R-squared
  residuals <- y - predictions
  ss_total <- sum((y - mean(y))^2)
  ss_residual <- sum(residuals^2)
  r_squared <- 1 - (ss_residual / ss_total)
  # Return the model and R-squared value
  return(list(model = final_model, r_squared = r_squared, coefficients = coefficients))
}
fit_nonlinear_lasso <- function(df, degree = 2, max_terms = 3) {
  # Load necessary library
  library(glmnet)
  
  # Separate response and predictors
  y <- df[[1]]  # First column as response
  predictors <- df[, -1]  # All other columns as predictors
  
  # Create polynomial terms for predictors up to the specified degree
  poly_data <- data.frame(y)  # Start with the response variable
  for (i in 1:ncol(predictors)) {
    predictor_name <- colnames(predictors)[i]
    poly_terms <- poly(predictors[[i]], degree, raw = TRUE)  # Raw terms to avoid orthogonal polynomials
    colnames(poly_terms) <- paste0(predictor_name, "_poly", 1:degree)
    poly_data <- cbind(poly_data, poly_terms)
  }
  
  # Convert predictors to a matrix for glmnet
  X <- as.matrix(poly_data[, -1])  # Drop the response column
  
  # Fit a Lasso model with cross-validation for lambda selection
  lasso_model <- cv.glmnet(X, y, alpha = 1)  # Lasso (alpha = 1)
  
  # Get the best lambda from cross-validation
  best_lambda <- lasso_model$lambda.min
  
  # Fit the final Lasso model using the best lambda
  final_model <- glmnet(X, y, alpha = 1, lambda = best_lambda)
  
  # Extract coefficients and limit to the top `max_terms` based on absolute magnitude
  coef_matrix <- as.matrix(coef(final_model))  # Convert coefficients to a matrix
  non_zero_coefs <- coef_matrix[coef_matrix != 0]  # Filter out zero coefficients
  
  # Get names and absolute values of non-zero coefficients
  coef_names <- rownames(coef_matrix)[coef_matrix != 0]
  coef_values <- abs(non_zero_coefs)
  
  # Sort coefficients by absolute value in descending order and select the top `max_terms`
  if (length(coef_values) > max_terms + 1) {  # +1 to account for the intercept term
    intercept <- coef_matrix[1, ]  # Extract intercept
    intercept_name <- coef_names[1]
    sans_intercept <- coef_values[2:length(coef_values)] # Ignore intercept
    sans_intercept_names <- coef_names[2:length(coef_names)]
    top_indices <- order(sans_intercept, decreasing = TRUE)[1:(max_terms)] 
    selected_coef_names <- sans_intercept_names[top_indices]
    selected_coef_values <- sans_intercept[top_indices]
    # Add intercept back at the start of selected coefficients
    selected_coef_names <- c(intercept_name, selected_coef_names)
    selected_coef_values <- c(intercept, selected_coef_values)
  } else {
    # If fewer terms than max_terms, use all available coefficients, including intercept
    selected_coef_names <- coef_names
    selected_coef_values <- non_zero_coefs
  }
  
  # Identify the positions of selected coefficient names in poly_data
  selected_indices <- match(selected_coef_names, colnames(poly_data))
  selected_indices <- selected_indices[!is.na(selected_indices)]  # Remove NA for intercept
  selected_indices <- selected_indices - 1
  
  # Refit the model using only the selected top terms
  if (length(selected_indices) == 1) {
    # Run final_model here and extract results for the function: model, rsquared, coef names
    # Use the original final model for the single predictor case
    predictions <- predict(final_model, newx = X)
    sst <- sum((y - mean(y))^2)  # Total sum of squares
    sse <- sum((y - predictions)^2)  # Sum of squared errors
    r_squared <- 1 - sse / sst
    
    # Return the final model, R-squared, and coefficients
    result <- list(
      model = final_model,
      best_lambda = best_lambda,
      r_squared = r_squared,
      coefficients = coef(final_model)
    )
    return(result)
    
  } else {
    selected_X <- X[, selected_indices, drop = FALSE]  # Subset matrix with selected predictors
    
    final_model_restricted <- glmnet(selected_X, y, alpha = 1, lambda = best_lambda)
    
    # Calculate R-squared for the restricted model
    predictions <- predict(final_model_restricted, newx = selected_X)
    sst <- sum((y - mean(y))^2)  # Total sum of squares
    sse <- sum((y - predictions)^2)  # Sum of squared errors
    r_squared <- 1 - sse / sst
    
    # Return the final restricted model and evaluation metrics
    result <- list(
      model = final_model_restricted,
      best_lambda = best_lambda,
      r_squared = r_squared,
      coefficients = coef(final_model_restricted)
    )
    return(result)
  }
  
}
# Master function receives df where first column is numeric response and all the other numeric predictors
# Regardless of collinearity, selects model between linear and nonlinear options
select_model_collinear <- function(df){
  linear <- fit_linear_lasso(df)
  nonlinear <- fit_nonlinear_lasso(df)
  linear_r <- linear$r_squared
  nonlinear_r <- nonlinear$r_squared
  if (linear_r >= nonlinear_r){
    print("Linear model selected")
    return(linear)
  } else {
    print("Nonlinear model selected")
    return(nonlinear)
  }
}

######################     PEDOTRANSFER FUNCTIONS         ######################
torri.bdm <- function(bd, rw){
  bdm <- bd * (1 - 1.67*rw^3.39)
  return(bdm)
}
ottoni.ksat <- function(silt, clay, bd){
  ksat <- 1266 * (0.582 - (0.00216*silt) - (0.00232*clay) - (0.203*bd))^1.853
  # This is in cm/d, convert to mm/h
  ksat <- ksat*10 # Now mm/d
  ksat <- ksat/24 # now mm/h
  return(ksat)
}