## This code accesses NOAA's GHCN data Global Historical Climate Network. 
## The archive is here: https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/archive/
## Download the "daily-summaries-latest.tar.gz" file in the archive when updating this import!
pref <- "C:/Users/david/Desktop"
#pref <- "C:/Users/900107520/Desktop/Research"
setup.func <- function(pref){path <- paste0(pref, "/Hydro-monitor"); code.path <- paste0(path, "/Code/Archiving"); setwd(code.path); source("00-functions.R"); wds(path)}; wd <- setup.func(pref)

library(dplyr)
meta.url <- "https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/doc/ghcnd-stations.txt"
setwd(wd.noaa)

# Get new station IDs and create new metadata sheet, 
# gz=TRUE if also downloading and untarring new archive (takes several minutes! began 3:48)
download.extract.new.ghcn(wd, meta.url, TRUE)
# Import everything into the single archive with quality flags parsed but not directly dealt with and save
archive0 <- ghcn.import.all(wd)
save(archive0, file="archive0.rda",compress="xz")
# We see these quality flags: G, L, O, S, Z
# Deal with quality flags mainly conservatively by replacing NAs, except for L which is not precip related
archive <- ghcn.import.qualflag(archive0); archive0 <- NULL
# Run some QA/QC to make sure there aren't disagreeing units or something
archive[which(archive$precip == min(archive$precip, na.rm = TRUE))[1],]
archive[which(archive$precip == max(archive$precip, na.rm = TRUE))[1],]
# One problematic observation that was not caught by qualflags
archive$precip[which(archive$station == "VQC00670260" & archive$date == "1979-09-04")] <- NA
archive$qual[which(archive$station == "VQC00670260" & archive$date == "1979-09-04")] <- "outlier"
save(archive, file="ghcn.archive.rda",compress="xz")

#################################################################################
# Bring in fresh CoCoRaHs data and combine with the NOAA dataset
coco <- import.coco.raw.full(wd)
coco <- coco.process(coco)
archive <- coco.join(coco, archive)

#################################################################################
# Bring in RAWS data and combine in a similar way
archive <- raws.join(wd, archive)

setwd(wd.weather)
save(archive, file="precip.archive.rda",compress="xz")





