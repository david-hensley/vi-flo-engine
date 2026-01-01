# Data export with metadata for sharing
setup.func <- function(dir, status){
  if (status == "online"){hier <- "C:/Users"; suf <- "Box/Hensley, David/03-Hydro"; setwd(paste("C:/Users", dir, "Box/Hensley, David/03-Hydro/Code/Archiving", sep = "/"))} 
  else if (status == "offline"){hier <- "C:/Users"; suf <- "Desktop/Offline_box/03-Hydro"; setwd(paste("C:/Users", dir, "Desktop/Offline_box/03-Hydro/Code/Archiving", sep = "/"))} 
  else {print("Unrecognized working status - use 'offline' or 'online'")}; source("00-functions.R"); wds(hier, dir, suf)
}
wd <- setup.func("900107520", "online")
library(dplyr); setwd(wd.archive)

# Collect all archive files 
files <- list.files()
files <- files[grepl("weather|hydro|vwc", files)]
files <- files[!files %in% c("weather.sites.csv", "jh.weather.rda", "rb.weather.rda", 
                             "tr2.weather.rda", "river.weather.rda")]


# Provide any "clips" requested - a master date range, or a site+daterange
# e.g. clip TR1 to Ernesto
load("tr1.hydro.rda")
new.tr1.hydro <- tr1.hydro[tr1.hydro$date<="2024-08-14 09:45:00",]
plot(new.tr1.hydro$date, new.tr1.hydro$level)

# and covert to CSV
export.dir <- "C:/Users/900107520/Desktop/datashare"
for (i in 1:length(files)){
  print(i)
  file <- files[i]
  loaded.name <- load(file)
  setwd(export.dir)
  write.csv(get(loaded.name), file = paste0(loaded.name, ".csv"), row.names = FALSE)
  setwd(wd.archive)
}
# Special case for tr1.hydro - manually deleted from folder and replaced
setwd(export.dir)
write.csv(new.tr1.hydro, "tr1.hydro.csv", row.names = FALSE)


# Produce metadata

# Package in a zip


