################################################################################
#                          ELEVATION LOOKUP                                    #
#                                                                              #
# Looks up ground elevation for a coordinate from the USGS Elevation Point     #
# Query Service, which interpolates the 3DEP dynamic elevation service - the   #
# same data the NRCS Geospatial Data Gateway serves, at 1 m lidar resolution   #
# where available.                                                             #
#                                                                              #
# Deterministic: the same coordinate returns the same value every time,        #
# because it is interpolated from a fixed raster. That matters more than it    #
# sounds - a lookup site that returned 22, 26 and 28 m for one point is why    #
# this exists.                                                                 #
#                                                                              #
# Datum: NAVD88 vertical, NAD83/WGS84 horizontal.                              #
#                                                                              #
# No API key, no rate limit, and no hard dependency - jsonlite is used when    #
# present, with a regex fallback when it is not. A failed lookup is not an     #
# error: the caller is expected to fall back to manual entry.                  #
################################################################################

EPQS_URL <- "https://epqs.nationalmap.gov/v1/json"

#' Builds the lookup URL for a coordinate
#'
#' Exposed separately so a workflow can show the user a URL to open by hand
#' when the automatic lookup is unavailable.
#'
#' @param lat Numeric. Latitude, decimal degrees
#' @param lon Numeric. Longitude, decimal degrees (negative in the Americas)
#' @return Character. A URL
build_elevation_url <- function(lat, lon) {
  paste0(EPQS_URL, "?x=", lon, "&y=", lat,
         "&wkid=4326&units=Meters&includeDate=false")
}


#' Looks up ground elevation for a coordinate
#'
#' @param lat Numeric. Latitude, decimal degrees
#' @param lon Numeric. Longitude, decimal degrees
#' @param timeout Numeric. Seconds to wait (default 10)
#' @return List with elev (numeric or NA), resolution (numeric or NA),
#'   ok (logical), and message (character) describing any failure
lookup_elevation <- function(lat, lon, timeout = 10) {

  fail <- function(msg) list(elev = NA_real_, resolution = NA_real_,
                             ok = FALSE, message = msg)

  if (is.na(lat) || is.na(lon)) return(fail("No coordinates"))

  url <- build_elevation_url(lat, lon)

  raw <- tryCatch({
    con <- url(url, open = "r")
    on.exit(try(close(con), silent = TRUE), add = TRUE)
    paste(readLines(con, warn = FALSE), collapse = "")
  }, error = function(e) NULL,
     warning = function(w) NULL)

  if (is.null(raw) || !nzchar(raw)) {
    return(fail("Could not reach the elevation service"))
  }

  #### Parse ####
  # jsonlite where available; a regex otherwise. The regex is the weaker of
  # the two and would break if the response shape changed - but a broken parse
  # returns NA, and the caller falls back to manual entry.
  value <- NA_real_
  resolution <- NA_real_

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(e) NULL)
    if (!is.null(parsed) && !is.null(parsed$value)) {
      value <- suppressWarnings(as.numeric(parsed$value))
      if (!is.null(parsed$resolution)) {
        resolution <- suppressWarnings(as.numeric(parsed$resolution))
      }
    }
  }

  if (is.na(value)) {
    m <- regmatches(raw, regexpr('"value"\\s*:\\s*"?-?[0-9.]+"?', raw))
    if (length(m) > 0) {
      value <- suppressWarnings(as.numeric(gsub('[^0-9.-]', '', m)))
    }
  }

  if (is.na(value)) return(fail("Could not read a value from the response"))

  #### The service's own failure signals ####
  # Outside the United States, EPQS returns -1000000 rather than an error
  if (value < -99999) {
    return(fail("Outside USGS coverage - no elevation available for this point"))
  }
  # Inside the US but not on land returns exactly 0
  if (value == 0) {
    return(fail("Returned 0 - the point may be over water, check the coordinates"))
  }

  list(elev = round(value, 2), resolution = resolution,
       ok = TRUE, message = "")
}


#' Builds the elev_source label for a lookup result
#'
#' Records WHICH dataset and at what resolution, not merely "a DEM". EPQS
#' returns 1 m lidar where it exists and falls back to coarser seamless data
#' elsewhere, so a bare label would hide a real difference in quality - and it
#' gets worse the moment a non-US station arrives with a 30 m global product
#' in the same column.
#'
#' @param res Result list from lookup_elevation()
#' @return Character, e.g. "usgs_3dep_1m"
elevation_source_label <- function(res) {
  if (is.null(res) || !isTRUE(res$ok)) return(NA_character_)
  if (is.na(res$resolution)) return("usgs_3dep")
  paste0("usgs_3dep_", res$resolution, "m")
}
