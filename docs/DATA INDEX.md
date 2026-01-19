# DATA INDEX

* The first section records the existing data directory from the prototype repo.
* The second section records the proposed new structure for this data.

## PRE-EXISTING DIRECTORY STRUCTURE

Can be found in /Core/vi-flo-prototype/Data

### /Analysis/

Outputted formatted data for dissertation and manuscripts - ignored for now

### /Archive/

* Processed data from field sites. sitename.datatype.rda is the naming convention.
* Also contains:

  * site.coords.csv

    * (lat/lon for each site for weather, hydro, vwc1, vwc2, if applicable)

  * site.correspondence.csv

    * (some sites use other sites' weather etc. - this notes it)

  * site.status.csv

    * (site name + sensor type + statuses e.g., active, interruptive, abandoned)

  * site-ids.shp

    * (+ dependent files)

  * splices.csv

    * (tracks QAQC changes and rationale)

  * unit.metadata.csv

    * (records units of all sensor types with column names)

  * weather.sites.csv

    * (records coordinates of weather stations alone)

* Data types are:

  * Hydro (streamflow)
  * Weather (rainfall, temperature, pressure, others)
  * VWC (soil volumetric water content)

### /Backup/

* The purpose of this is not immediately clear - may be created in code runs
* Backs up some but not all of /Archive/

### /Daymet/

* Python code and text instructions for extracting single-point Daymet precip data over time
* file1.csv is an extract of this for a single point

### /Kriging/

* Output of kriging process, daily .rdas for kriged precip for almost 100 years
* Extremely bulky

### /NASA/

* Python scripts and text instructions for extracting GPM precip data for single points
* Contains no data, precip\_NASA.R is a script containing relevant functions

### /NOAA/

This folder relates to NOAA GHCN precipitation data.

* daily-summaries-latest.tar.gz

  * This is a zip file containing a large single file
  * This is the result of a query from GHCN for the entire USVI archive up to present
  * The R script that generates it overwrites this file with a new one

* ghcn.archive.rda

  * Results of untarring process, stored single raw GHCN file from daily-summaries

* ghcn.temperature.csv

  * Results of untarring for GHCN temperature data, request of Greg Guannel

* ghcn\_meta.csv

  * Summarizes station information

* GHCN\_VI\_stations.txt

  * Station metadata pulled directly from NOAA URL

* GHCND\_documentation.pdf

  * GHCN data documentation from NOAA

* kriged.precip.rda

  * Precip data for comparison from /Kriging/

* noaa\_meta\_manual.csv

  * More station metadata, includes start and end dates of data
  * Not immediately clear why this is a separate file

* many CSVs, VQ...csv

  * station-by-station download of raw data from GHCN for entire Virgin Islands

### /Old/

No longer relevant, ignorable

### /Raw-FlowTracker

* Relatively messy storage of raw FlowTracker2 field data.
* Includes .ft files, raw from FlowTracker device
* Includes .pdf reports
* Includes various forms of CSVs
* Uses sitenames from FlowTracker input, not always perfectly matched to internal sitenames

### /Raw-hobo/

* .hobo files from water level loggers
* Naming convention is sitename\_YYYYMMDD-YYYYMMDD.hobo
* Dates may represent the actual days recording starts and stops, but may be expanded?
* Some sitenames are inconsistent due to internal device names

### /Raw-level/

* Results of export from .hobo files for water level loggers
* Convention: sitename\_hydro\_YYYYMMDD-YYYYMMDD.csv
* R code pulls from this

### /Raw-PARIO/

* .pario files from PARIO instrument in lab
* Each .pario file also has corresponding .xlsx
* These are generally intended to accompany VWC data
* Currently only SR

### /Raw-RAWS/

* Poorly named folder
* RAWS weather data is manually imported with R script guiding
* Raw data stored as .txt
* Convention: RAWS\_site\_YYYYMMDD-YYYYMMDD.txt
* raws\_meta.csv is full site names, coordinates, elevation, alternate names
* raws.csv is the full compiled data

### /Raw-VWC/

* Raw CSVs from Zentra VWC loggers
* Convention: sitename\_vwc\_position\_YYYYMMDD-YYYYMMDD.csv
* Positions can be hs (hillside) or sb (streambank)
* This should most likely be reformed into something else

### /Raw-weather/

* Contains CoCoRaHs weather data as well as Zentra weather data
* CoCoRaHs convention: cocorahs\_YYYYMMDD-YYYYMMDD.csv
* Zentra convention: sitename\_weather\_YYYYMMDD-YYYYMMDD.csv
* cocorahs.csv is the full cocorahs archive to preset, tproduced by R
* krig.atmos.compare.rda comparison file with kriged precip
* neighbor.atmos.compare.rda comparison file with nearest neighbor
* neighbor.validation.full.rda
* precip.archive.rda - this is the full precipitation archive produced by QAQC
* precip.validation.rda - one time use validation file

### /Site-info/

* Backup logger deployment data.xlsx

  * This records surveyed data of twin (backup) loggers for hydraulic slope

* coastline.rda

  * Used for raster in R code for manual precip map

* elevs.csv

  * Records elevation data for sites... but negative and meaning is unclear

* gutsurveys.csv

  * Original survey data from gut cross sections

* k.selections.csv

  * Records k and c recession constants used for sites in calculating baseflow

* qcurves.csv and successors

  * Records qcurves used (rating curve) for sites, evolving over time

* qcurves\_meta.csv

  * Records the iterations of qcurves with notes

* qfits.csv

  * Raw data used to create rating curves; flow data paired with stage

* roughness.csv

  * Proposed roughness coefficients (n) for Manning's equation at sites

* site.coords.csv

  * Same as in /Archive/

* site-ids.csv

  * Records stream gauge site info, long name, alternate name, overbank gauge

* slope\_models.csv

  * Records changing hydraulic slope with stage, a sort of rating curve to guess unmeasured slope

* slopedata.csv

  * Raw survey data of streambed slopes at sites

* vwc.meta.csv

  * Metadata for VWC stations

### /Splices/

* Splices.csv is the active current splices log
* Many backups of past versions

  * Convention: splices\_YYYY-MM-DD\_HHMMScsv

### Visible data types

* Data can be classified as raw and processed
* Raw data falls into several categories

  * Raw logger data

    * Water level
    * Weather station
    * Soil moisture

  * Raw 3rd party

    * NOAA (GHCN)
    * RAWS
    * CoCoRaHs
    * NASA (GPM)
    * Daymet

  * Raw field data

    * FlowTracker
    * Gut surveys

  * Raw lab data

    * PARIO

* Processed data has three types thus far

  * Weather
  * Hydro
  * VWC

* Metadata

  * QAQC records (splices)
  * Site info of many kinds
  * Processed data used in intermediate steps?

## Proposed categories

* In /Core/Protocols/Data, each data type should have a text document explaining the proposed process for importing raw data to the relevant folder
* The top level distinction must be raw vs. processed
* The second level distinction must be internal vs. external (3rd party)
* The third level must be broad type - timeseries, geospatial, field, lab
