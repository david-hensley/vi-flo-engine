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

EPQS_URL      <- "https://epqs.nationalmap.gov/v1/json"
OPENMETEO_URL <- "https://api.open-meteo.com/v1/elevation"

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


#' Fetches a URL and returns its body, or NULL
#' @param url Character
#' @return Character, or NULL on any failure
fetch_url_text <- function(url) {
  tryCatch({
    con <- url(url, open = "r")
    on.exit(try(close(con), silent = TRUE), add = TRUE)
    paste(readLines(con, warn = FALSE), collapse = "")
  }, error = function(e) NULL, warning = function(w) NULL)
}


#' Builds the Open-Meteo lookup URL
#' @param lat,lon Numeric
#' @return Character
build_elevation_url_global <- function(lat, lon) {
  paste0(OPENMETEO_URL, "?latitude=", lat, "&longitude=", lon)
}


#' Looks up elevation from Open-Meteo, for points outside USGS coverage
#'
#' A global fallback, so the British Virgin Islands and anywhere else beyond
#' US territory can still get a value. Coarser than 3DEP - a global product at
#' roughly 90 m rather than 1 m lidar - which is why it is second in the chain
#' and why elev_source records which was used.
#'
#' Free, no key, non-commercial use, data under CC BY 4.0 - attribution is
#' required and is recorded in the README.
#'
#' @param lat,lon Numeric
#' @return Same shape as lookup_elevation()
lookup_elevation_global <- function(lat, lon) {

  fail <- function(msg) list(elev = NA_real_, resolution = NA_real_,
                             ok = FALSE, message = msg,
                             provider = "open_meteo")

  raw <- fetch_url_text(build_elevation_url_global(lat, lon))
  if (is.null(raw) || !nzchar(raw)) {
    return(fail("Could not reach the global elevation service"))
  }

  # Open-Meteo returns the value inside an ARRAY: {"elevation":[44.812]}
  value <- NA_real_

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(e) NULL)
    if (!is.null(parsed) && !is.null(parsed$elevation)) {
      value <- suppressWarnings(as.numeric(parsed$elevation[1]))
    }
  }

  if (is.na(value)) {
    m <- regmatches(raw, regexpr('"elevation"\\s*:\\s*\\[?\\s*-?[0-9.]+', raw))
    if (length(m) > 0) {
      value <- suppressWarnings(as.numeric(gsub('[^0-9.-]', '', m)))
    }
  }

  if (is.na(value)) return(fail("Could not read a value from the response"))

  list(elev = round(value, 2), resolution = NA_real_,
       ok = TRUE, message = "", provider = "open_meteo")
}


#' Looks up ground elevation for a coordinate
#'
#' Tries USGS 3DEP first, since it is authoritative for US territories and
#' returns 1 m lidar where available. Where USGS reports no coverage - which
#' it does by returning -1000000 rather than an error - falls through to a
#' global source so that the British Virgin Islands and anywhere else beyond
#' US territory still gets a value.
#'
#' The two are not equivalent in quality, which is why the result carries the
#' provider and the caller records it in elev_source.
#'
#' @param lat Numeric. Latitude, decimal degrees
#' @param lon Numeric. Longitude, decimal degrees
#' @param allow_global Logical. Fall through to the global source (default TRUE)
#' @return List with elev, resolution, ok, message, provider
lookup_elevation <- function(lat, lon, allow_global = TRUE) {

  fail <- function(msg, provider = NA_character_) {
    list(elev = NA_real_, resolution = NA_real_, ok = FALSE,
         message = msg, provider = provider)
  }

  if (is.na(lat) || is.na(lon)) return(fail("No coordinates"))

  #### 1. USGS 3DEP ####
  raw <- fetch_url_text(build_elevation_url(lat, lon))

  usgs_value <- NA_real_
  usgs_res <- NA_real_
  outside_us <- FALSE

  if (!is.null(raw) && nzchar(raw)) {
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(e) NULL)
      if (!is.null(parsed) && !is.null(parsed$value)) {
        usgs_value <- suppressWarnings(as.numeric(parsed$value))
        if (!is.null(parsed$resolution)) {
          usgs_res <- suppressWarnings(as.numeric(parsed$resolution))
        }
      }
    }
    if (is.na(usgs_value)) {
      m <- regmatches(raw, regexpr('"value"\\s*:\\s*"?-?[0-9.]+"?', raw))
      if (length(m) > 0) {
        usgs_value <- suppressWarnings(as.numeric(gsub('[^0-9.-]', '', m)))
      }
    }
  }

  if (!is.na(usgs_value)) {
    # EPQS signals "outside the United States" with -1000000, not an error
    if (usgs_value < -99999) {
      outside_us <- TRUE
    } else if (usgs_value == 0) {
      # Inside the US but not on land
      return(fail("Returned 0 - the point may be over water, check the coordinates",
                  "usgs_3dep"))
    } else {
      return(list(elev = round(usgs_value, 2), resolution = usgs_res,
                  ok = TRUE, message = "", provider = "usgs_3dep"))
    }
  }

  #### 2. Global fallback ####
  if (!allow_global) {
    return(fail(if (outside_us) "Outside USGS coverage"
                else "Could not reach the elevation service", "usgs_3dep"))
  }

  if (outside_us) {
    cat("  (outside USGS coverage - trying global source)\n")
  }

  global <- lookup_elevation_global(lat, lon)
  if (isTRUE(global$ok)) return(global)

  fail(if (outside_us) {
         paste0("Outside USGS coverage, and the global source failed: ",
                global$message)
       } else {
         "Could not reach either elevation service"
       }, "none")
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

  provider <- if (is.null(res$provider)) "usgs_3dep" else res$provider

  if (provider == "usgs_3dep") {
    if (is.na(res$resolution)) return("usgs_3dep")
    return(paste0("usgs_3dep_", res$resolution, "m"))
  }

  provider
}
