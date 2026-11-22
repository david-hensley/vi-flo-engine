# Whole metadata manager workflows, driven by scripted answers and checked by
# what they leave in the metadata and the logs. These replace walking the
# menus by hand: if a workflow starts asking different questions, or writes
# something different, a test here fails.

rod <- function(ft, inch, e8) c(ft, inch, e8, "Y")   # one reading, confirmed

no_surveys <- function() write_table("surveys", load_surveys()[0, ], guard = FALSE)

test_that("the BTA2 paired survey of 14 October records what the rod measured", {
  local_test_root()
  no_surveys()
  file.copy(fixture_path("trupulse_bta2_20261014.txt"),
            file.path(get_gut_survey_dir(), "BTA_2_Reach_Length_2026-10-14.txt"))

  answers <- c(
    "2026-10-14", "1",           # date, logged by DAH
    "1",                         # station: bta2_hydro
    "1", "2",                    # rod survey; upstream is bta2b (secondary)
    "1",                         # feet, inches, eighths
    rod(4, 3, 2), rod(4, 11, 2), "Y",
    rod(4, 8, 2), rod(5, 1, 1.5), "Y",
    rod(4, 7, 6.5), rod(5, 1, 0.5), "N",
    "2", "24.94", "24.94",       # offsets in cm
    "Y",                         # accept setups 2+3
    "1", "Y", "1", "Y",          # TruPulse, in the folder, the file, accept
    "1"                          # save both
  )
  run <- with_inputs(answers, ui_survey_gut_pair())
  expect_true(isTRUE(run$value))

  # What the rod measured: each rebar top above its sensor, and the upstream
  # rebar top above the downstream one; and the reach
  s <- load_surveys()
  expect_equal(nrow(s), 4)
  r <- s[s$unique_id == "t-0002" & s$relative_to_id %in% "t-0001" & s$quantity == "height_cm", ]
  expect_equal(c(r$point, r$relative_to, r$method), c("rebar", "rebar", "level"))
  expect_equal(r$value, 12.94)
  expect_equal(s$value[s$unique_id == "t-0001" & s$point %in% "rebar"], 24.94)
  expect_equal(s$relative_to[s$unique_id == "t-0001" & s$point %in% "rebar"], "sensor")
  expect_equal(s$value[s$quantity == "reach_m"], 24.16)
  expect_equal(s$method[s$quantity == "reach_m"], "laser")
  # ...and the fall between the sensors, chained from them, is the one logged
  expect_equal(survey_height("t-0002", "sensor", "t-0001", "sensor", s), 12.94)

  # Elevations are the ground, and a survey no longer touches them
  expect_equal(meta_row("t-0002")$elev, 17.54)
  expect_equal(meta_row("t-0001")$elev, 17.54)

  # Product 0: the readings as typed, and the export under its standard name
  dir <- get_gut_survey_dir()
  expect_true(file.exists(file.path(dir, "bta2_hydro_fall_rod_20261014.csv")))
  expect_true(file.exists(file.path(dir, "bta2_hydro_reach_trupulse_20261014.txt")))
  expect_false(file.exists(file.path(dir, "BTA_2_Reach_Length_2026-10-14.txt")))
  p0 <- read.csv(file.path(dir, "bta2_hydro_fall_rod_20261014.csv"), colClasses = "character")
  expect_equal(p0$entered[p0$setup == "2" & p0$sight == "FS"], "5 1 1.5")

  log <- read_log()
  entry <- log[nrow(log), ]
  expect_equal(entry$action_type, "survey")
  expect_equal(entry$unique_id, "t-0002")
  expect_match(entry$details, "accepted 2+3", fixed = TRUE)
  expect_match(entry$details, "upstream testb (90000002", fixed = TRUE)
  expect_match(entry$details, "slope 0.00536", fixed = TRUE)
})

test_that("a fall typed by hand records the points it was measured between", {
  local_test_root()
  no_surveys()
  answers <- c(
    "2026-10-27", "1", "1",      # date, DAH, bta2_hydro
    "2", "2",                    # typed fall; upstream is bta2b
    "0.2",                       # meters
    "2",                         # between the sensors
    "1", "laser file x.txt",     # laser; note
    "2", "30", "2", "",          # reach typed, 30 m, by laser, no note
    "1"                          # save both
  )
  run <- with_inputs(answers, ui_survey_gut_pair())
  expect_true(isTRUE(run$value))
  s <- load_surveys()
  f <- s[s$quantity == "height_cm", ]
  expect_equal(c(f$unique_id, f$point, f$relative_to, f$relative_to_id, f$method),
               c("t-0002", "sensor", "sensor", "t-0001", "laser"))
  expect_equal(f$value, 20)
  expect_equal(f$notes, "laser file x.txt")
  expect_equal(survey_reach("t-0002", "t-0001", s), 30)
})

test_that("a typed fall whose points were not recorded is kept, and chains nothing", {
  local_test_root()
  no_surveys()
  answers <- c("2026-10-27", "1", "1", "2", "2", "0.2", "3", "3", "", "3", "1")
  run <- with_inputs(answers, ui_survey_gut_pair())
  expect_true(isTRUE(run$value))
  s <- load_surveys()
  expect_true(is.na(s$point) && is.na(s$relative_to))
  expect_equal(s$value, 20)
  expect_true(is.na(survey_height("t-0002", "sensor", "t-0001", "sensor", s)))
  expect_true(any(grepl("points measured were not recorded", run$output)))
})

test_that("the paired survey refuses a fall that comes out as a climb", {
  local_test_root()
  before <- load_surveys()
  answers <- c(
    "2026-10-14", "1", "1",
    "1", "2", "3",               # rod survey, upstream bta2b, meters
    "1.482", "Y", "1.300", "Y", "N",   # backsight higher reading = lower point
    "2", "0", "0",
    "2",                         # skip the fall
    "3"                          # skip the reach - nothing to save
  )
  run <- with_inputs(answers, ui_survey_gut_pair())
  expect_null(run$value)
  expect_equal(load_surveys(), before)
  expect_true(any(grepl("a climb, not a fall", run$output)))
})

test_that("a measured height is recorded between the two points chosen", {
  local_test_root()
  answers <- c(
    "2026-11-01", "1",           # date, DAH
    "1", "1",                    # bta2_hydro, bta2a (the primary)
    "1", "1",                    # the sensor, and the bed
    "1", "2",                    # the sensor is higher, by 2 cm
    "3", "",                     # by tape, no note
    "Y"
  )
  run <- with_inputs(answers, ui_survey_measurement())
  expect_true(isTRUE(run$value))
  s <- load_surveys()
  new <- s[s$measured_on == as.Date("2026-11-01"), ]
  expect_equal(c(new$unique_id, new$point, new$relative_to, new$method),
               c("t-0001", "sensor", "bed", "tape"))
  expect_equal(new$value, 2)
  expect_false("t-0001 sensor height" %in% paste(survey_needs()$unique_id, survey_needs()$need))
  expect_equal(read_log()$action_type[nrow(read_log())], "survey")
})

test_that("the two points can be named in either order - the higher one decides", {
  local_test_root()
  answers <- c("2026-11-01", "1", "1", "1",
               "2", "1",                 # the bed first, then the sensor
               "2", "2",                 # the sensor is higher, by 2 cm
               "3", "", "Y")
  with_inputs(answers, ui_survey_measurement())
  s <- load_surveys()
  new <- s[s$measured_on == as.Date("2026-11-01"), ]
  expect_equal(c(new$point, new$relative_to), c("sensor", "bed"))
  expect_equal(new$value, 2)
})

test_that("two points level with each other are recorded as 0", {
  local_test_root()
  answers <- c("2026-11-01", "1", "1", "1", "1", "1", "3", "3", "", "Y")
  with_inputs(answers, ui_survey_measurement())
  s <- load_surveys()
  expect_equal(s$value[s$measured_on == as.Date("2026-11-01")], 0)
})

test_that("a height can be measured against a point on another logger", {
  local_test_root()
  answers <- c(
    "2026-11-01", "1", "1",
    "2",                         # bta2b
    "4",                         # the overflow
    "5",                         # and a point on another logger
    "1", "1",                    # bta2a, its sensor
    "1", "30",                   # bta2b's overflow is higher, by 30 cm
    "2", "pool spill",           # by level
    "Y"
  )
  run <- with_inputs(answers, ui_survey_measurement())
  expect_true(isTRUE(run$value))
  s <- load_surveys()
  new <- s[s$measured_on == as.Date("2026-11-01"), ]
  expect_equal(c(new$unique_id, new$point, new$relative_to, new$relative_to_id),
               c("t-0002", "overflow", "sensor", "t-0001"))
  # chains: bta2b's overflow above its own sensor = 30 - 12.94
  expect_equal(survey_height("t-0002", "overflow", "t-0002", "sensor", s), 17.06)
})

test_that("Windsor's GNSS survey converts through GEOID18 and logs the arithmetic", {
  local_test_root()
  answers <- c(
    "2026-10-16", "1",           # date, DAH
    "2",                         # station: srl1_pond
    "2", "-10.366", "-41.632",   # ellipsoidal height and geoid height
    "1",                         # ground shot
    "test note",
    "Y"
  )
  run <- with_inputs(answers, ui_survey_ground_elevation())
  expect_true(isTRUE(run$value))

  w <- meta_row("t-0004")
  expect_equal(w$elev, 31.266)
  expect_equal(w$elev_source, "gnss")

  entry <- read_log()[nrow(read_log()), ]
  expect_equal(entry$action_type, "survey")
  expect_match(entry$details, "GEOID18 N -41.632 m = H 31.266 m", fixed = TRUE)
  expect_match(entry$details, "test note", fixed = TRUE)
})

test_that("a shot on the measuring point is brought back to the ground by the surveyed sensor height", {
  local_test_root()
  answers <- c("2026-10-16", "1", "2", "2", "-10.086", "-41.632", "2", "", "Y")
  with_inputs(answers, ui_survey_ground_elevation())
  expect_equal(meta_row("t-0004")$elev, 31.266)       # 31.546 less 28 cm
})

test_that("a shot on the measuring point with no sensor height surveyed saves nothing", {
  local_test_root()
  before <- load_zentra_metadata()
  answers <- c("2026-10-16", "1", "1", "1", "2", "-10.086", "-41.632", "2")
  run <- with_inputs(answers, ui_survey_ground_elevation())
  expect_null(run$value)
  expect_identical(load_zentra_metadata(), before)
})

test_that("a survey row entered by mistake can be removed, and the removal is logged", {
  local_test_root()
  before <- load_surveys()
  answers <- c("1", "1", "Y", "typed against the wrong logger", "1")
  run <- with_inputs(answers, ui_remove_survey())
  expect_true(isTRUE(run$value))
  expect_equal(nrow(load_surveys()), nrow(before) - 1)
  entry <- read_log()[nrow(read_log()), ]
  expect_equal(entry$action_type, "metadata_deletion")
  expect_match(entry$details, "Survey row removed", fixed = TRUE)
  expect_match(entry$details, "wrong logger", fixed = TRUE)
})

test_that("a replacement in the same housing carries the surveys it is told still hold", {
  local_test_root()
  # bta2a (t-0001) replaced by a new primary, t-0012, in the same housing
  m <- read_table("device_metadata")
  new <- m[m$unique_id == "t-0001", ]
  new$unique_id <- "t-0012"; new$device_serial <- "90000009"
  new$deploy_datetime <- as.POSIXct("2026-11-10 10:00:00", tz = PROJECT_TZ)
  m$status[m$unique_id == "t-0001"] <- "replaced"
  m$end_datetime[m$unique_id == "t-0001"] <- new$deploy_datetime
  write_table("device_metadata", rbind(m, new), guard = FALSE)

  run <- with_inputs("Y", ui_carry_surveys("t-0001", "t-0012"))
  s <- load_surveys()
  carried <- s[s$unique_id == "t-0012", ]
  expect_equal(nrow(carried), 1)
  expect_equal(carried$carried_from, "t-0001")
  expect_equal(carried$measured_on, as.Date("2026-10-14"))

  # bta2b was surveyed against the old primary, and still chains to the new
  expect_equal(survey_height("t-0002", "sensor", "t-0012", "sensor", s), 12.94)
  expect_equal(survey_reach("t-0002", "t-0012", s), 24.16)
  n <- survey_needs()
  expect_false(any(n$unique_id == "t-0002" & n$need %in% c("fall to primary", "reach to primary")))
})

test_that("a replacement told nothing holds carries nothing, and the pair needs surveying", {
  local_test_root()
  m <- read_table("device_metadata")
  new <- m[m$unique_id == "t-0001", ]
  new$unique_id <- "t-0012"; new$device_serial <- "90000009"
  m$status[m$unique_id == "t-0001"] <- "replaced"
  write_table("device_metadata", rbind(m, new), guard = FALSE)

  with_inputs("N", ui_carry_surveys("t-0001", "t-0012"))
  expect_false(any(load_surveys()$unique_id == "t-0012"))
  n <- survey_needs()
  expect_true(any(n$unique_id == "t-0002" & n$need == "fall to primary"))
})

test_that("a new device's sensor height goes to surveys.csv against its deployment", {
  local_test_root()
  h <- 200; attr(h, "method") <- "nominal"
  res <- add_new_device(list(
    device_serial = "z6-77777", station_id = "new_weather", watershed = "Test",
    area = NA, site_full = "Test New", site = "new", station_type = "weather",
    device_role = NA, device_name = "new box", mfger = "Meter", model = "ZL6",
    lat = 17.7, lon = -64.8, elev = 20, elev_source = "usgs_3dep_1m",
    sensor_height_cm = h, interval_min = 15, timezone = PROJECT_TZ,
    deploy_datetime = as.POSIXct("2026-11-15 09:00:00", tz = PROJECT_TZ),
    status = "online", metadata_approved = TRUE))
  expect_true(isTRUE(res))
  uid <- load_zentra_metadata()$unique_id[load_zentra_metadata()$device_serial == "z6-77777"]
  s <- load_surveys()
  r <- s[s$unique_id == uid, ]
  expect_equal(c(r$point, r$relative_to, r$method), c("sensor", "ground", "nominal"))
  expect_equal(r$value, 200)
  expect_equal(r$measured_on, as.Date("2026-11-15"))
})

test_that("a GNSS elevation on either logger of a pair goes on both", {
  local_test_root()
  answers <- c("2026-11-01", "1", "1", "2",   # bta2_hydro, bta2b
               "1", "17.7", "1", "", "Y")       # orthometric 17.7, ground shot
  run <- with_inputs(answers, ui_survey_ground_elevation())
  expect_true(isTRUE(run$value))
  expect_equal(meta_row("t-0001")$elev, 17.7)
  expect_equal(meta_row("t-0002")$elev, 17.7)
  expect_equal(meta_row("t-0003")$elev, 7.6)          # the retired row stays put
  expect_true(any(grepl("a paired gauge carries one elevation", run$output)))
})

test_that("a new logger at a paired gauge takes the primary's elevation", {
  local_test_root()
  se <- station_elevation("bta2_hydro")
  expect_equal(se$elev, 17.54)
  expect_equal(se$elev_source, "usgs_3dep_1m")
})

test_that("validation catches a paired logger whose elevation is not its primary's", {
  local_test_root()
  res <- validate_metadata(verbose = FALSE)
  expect_false("PAIRED_ELEVATION_DIFFERS" %in% names(res$violations))
  m <- read_table("device_metadata")
  m$elev[m$unique_id == "t-0002"] <- 17.6694
  write_table("device_metadata", m, guard = FALSE)
  res <- validate_metadata(verbose = FALSE)
  expect_true("PAIRED_ELEVATION_DIFFERS" %in% names(res$violations))
})

#### Establishing a new station ####

test_that("1a: a lone HOBO gauge at a new site is established whole, from the main menu", {
  local_test_root()
  answers <- c(
    "2", "1",                        # new station
    "1",                             # Bethlehem
    "Y", "1",                        # area: Adventure, the only one in Bethlehem
    "2", "1", "Y",                   # a new site, number 1, named for its area
    "",                              # abbreviation as suggested
    "1", "",                         # hydro; station ID as suggested
    "99999901", "1", "3",            # serial; HOBO; U20-001-04 (13 ft)
    "N", "Test Gut 1",               # no role - a lone gauge; its name
    "17.74", "-64.80",
    "33.5", "1",                     # offline, so typed: from a DEM site
    "12", "", "",                    # sensor height; interval and zone default
    "2026-11-20 10:00", "1",         # deployed; manual
    "Y", "", "1",                    # confirm; no note; DAH
    "Y",                             # the record matches reality
    "N"                              # nothing else
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")

  # Asked for what a new site needs, with names suggested from what exists
  expect_match(out, "Select area in Bethlehem:\n  1. Adventure\n  2. other", fixed = TRUE)
  expect_match(out, "Site name: Bethlehem Adventure 1", fixed = TRUE)
  expect_match(out, "Suggested: bta1", fixed = TRUE)
  expect_match(out, "U20-001-04 (13 ft)", fixed = TRUE)
  expect_false(grepl("ZL6", sub("(?s).*Select model:(.*?)Enter selection.*", "\\1", out, perl = TRUE)))
  expect_match(out, "HOBO device added - no port configuration needed", fixed = TRUE)

  m <- load_zentra_metadata()
  r <- m[m$station_id == "bta1_hydro", ]
  expect_equal(nrow(r), 1)
  expect_equal(c(r$site, r$site_full, r$area, r$watershed),
               c("bta1", "Bethlehem Adventure 1", "Adventure", "Bethlehem"))
  expect_equal(c(r$device_serial, r$device_name, r$mfger, r$model, r$status),
               c("99999901", "Test Gut 1", "HOBO", "U20-001-04", "manual"))
  expect_true(is.na(r$device_role))
  expect_equal(c(r$elev, r$elev_source), c("33.5", "dem_manual"))
  expect_equal(format(r$deploy_datetime, "%Y-%m-%d %H:%M"), "2026-11-20 10:00")
  expect_true(isTRUE(r$metadata_approved))

  # The sensor height is a survey against this deployment, not a device column
  s <- load_surveys()
  h <- s[s$unique_id == r$unique_id, ]
  expect_equal(nrow(h), 1)
  expect_equal(c(h$point, h$relative_to, h$value), c("sensor", "bed", "12"))

  # One entry, dated the day it went in, naming the device
  log <- read_log()
  e <- log[log$unique_id == r$unique_id, ]
  expect_equal(nrow(e), 1)
  expect_equal(c(e$action_type, e$field_visit_date, e$logged_by),
               c("station_established", "2026-11-20", "DAH"))
  expect_equal(e$details, "New station established: Bethlehem Adventure 1, with Test Gut 1 (99999901)")
})

test_that("1b: a paired gauge - primary established, secondary added - shares one place and elevation", {
  local_test_root()
  answers <- c(
    # The primary, establishing the station
    "2", "1", "1", "Y", "1", "2", "1", "Y", "", "1", "",
    "99999902", "1", "3",
    "Y", "1",                        # role: primary, of primary and secondary
    "Test Gut 1a", "17.74", "-64.80", "33.5", "1",
    "10", "", "", "2026-11-20 10:00", "1",
    "Y", "", "1",
    "Y", "Y",                        # record matches; something else
    # The secondary, added to it
    "2", "2", "1",                   # bta1_hydro, first in the list
    "99999903", "1", "3",
    "Y", "1",                        # role: secondary, the only one open
    "Test Gut 1b",                   # location and elevation are inherited
    "8", "", "", "2026-11-20 10:30", "1",
    "Y", "", "1",
    "N",                             # no survey data yet
    "Y", "N"
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")

  # rb2's tertiary is not on offer, and the primary is not offered twice
  expect_false(grepl("tertiary", out, fixed = TRUE))
  expect_match(out, "Select device role:\n  1. secondary\n", fixed = TRUE)
  # The survey is offered once there is a pair, and only then
  expect_equal(lengths(regmatches(out, gregexpr("--- GUT SURVEY ---", out, fixed = TRUE))), 1)

  m <- load_zentra_metadata()
  r <- m[m$station_id == "bta1_hydro", ]
  r <- r[order(r$device_serial), ]
  expect_equal(r$device_serial, c("99999902", "99999903"))
  expect_equal(r$device_role, c("primary", "secondary"))
  expect_equal(r$device_name, c("Test Gut 1a", "Test Gut 1b"))
  expect_equal(r$lat, c(17.74, 17.74))
  expect_equal(r$elev, c(33.5, 33.5))
  expect_equal(r$elev_source, c("dem_manual", "dem_manual"))

  s <- load_surveys()
  expect_equal(s$value[s$unique_id %in% r$unique_id & s$point %in% "sensor"], c(10, 8))

  log <- read_log()
  e <- log[log$unique_id %in% r$unique_id, ]
  expect_equal(e$action_type, c("station_established", "device_added"))
  expect_equal(e$details, c("New station established: Bethlehem Adventure 1, with Test Gut 1a (99999902)",
                            "Device added to existing station: Test Gut 1b (99999903)"))
  expect_equal(e$field_visit_date, c("2026-11-20", "2026-11-20"))
})

test_that("a station with its primary and secondary offers a third logger no role", {
  local_test_root()
  run <- with_inputs(character(0), ui_prompt_device_role("hydro", "bta2_hydro"))
  expect_true(is.na(run$value))
  expect_match(paste(run$output, collapse = "\n"),
               "bta2_hydro already has its primary and secondary", fixed = TRUE)
})

test_that("1c: a ZL6 with weather and soil sensors sets up both stations, and its ports go to each", {
  local_test_root()
  answers <- c(
    "2", "1", "1", "Y", "1", "2", "1", "Y", "",
    "4", "",                         # weather; bta1_weather
    "z6-99999", "2", "1",            # Meter; ZL6
    "N", "Test weather 1",
    "17.74", "-64.80", "33.5", "1",
    "", "", "",                      # standard 200 cm; interval and zone default
    "2026-11-20 10:00", "2",         # deployed; online
    "Y", "", "1",
    "Y",                             # initialize ports
    "Y", "1", "N", "Y",              # 1: ATMOS 41
    "Y", "2", "Y", "10", "Y",        # 2-4: TEROS 10 at 10, 30, 50 cm
    "Y", "2", "Y", "30", "Y",
    "Y", "2", "Y", "50", "Y",
    "N", "N",                        # 5, 6 empty
    "Y",                             # save
    "Y",                             # set up the vwc station
    "",                              # bta1_vwc1
    "Y",                             # its sensors went in with the logger
    "Y", "1",                        # role: primary, the only one open
    "Y", "", "1",
    "Y", "Y",                        # weather matches; so does vwc, same logger
    "N"
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")
  expect_match(out, "Ports 2, 3, 4 hold vwc sensors", fixed = TRUE)
  expect_match(out, "bta1_vwc1 is on the same logger.", fixed = TRUE)
  expect_equal(lengths(regmatches(out, gregexpr("--- METADATA REVIEW", out, fixed = TRUE))), 1)
  expect_false(grepl("Add this device to a new station as well?", out, fixed = TRUE))
  expect_equal(lengths(regmatches(out, gregexpr("ANOTHER STATION ON THIS LOGGER", out, fixed = TRUE))), 1)

  m <- load_zentra_metadata()
  w <- m[m$station_id == "bta1_weather", ]
  v <- m[m$station_id == "bta1_vwc1", ]
  expect_equal(c(nrow(w), nrow(v)), c(1, 1))
  expect_equal(c(v$device_serial, v$site, v$device_role, v$model), c("z6-99999", "bta1", "primary", "ZL6"))
  expect_true(is.na(w$device_role))
  expect_equal(c(v$lat, v$lon, v$elev), c(w$lat, w$lon, w$elev))
  expect_equal(format(v$deploy_datetime), format(w$deploy_datetime))
  expect_true(isTRUE(w$metadata_approved) && isTRUE(v$metadata_approved))

  # Each sensor recorded against the station it serves, once
  p <- read_table("zentra_ports")
  expect_equal(p$port[p$unique_id == w$unique_id], 1)
  expect_equal(sort(p$port[p$unique_id == v$unique_id]), 2:4)
  expect_equal(p$depth_cm[p$unique_id == v$unique_id][order(p$port[p$unique_id == v$unique_id])],
               c(10, 30, 50))

  log <- read_log()
  e <- log[log$unique_id %in% c(w$unique_id, v$unique_id), ]
  expect_equal(e$station_id, c("bta1_weather", "bta1_vwc1"))
  expect_true(all(e$action_type == "station_established"))
})

test_that("ports for a station declined stay unrecorded, and the rest are saved", {
  local_test_root()
  answers <- c(
    "2", "1", "1", "Y", "1", "2", "1", "Y", "", "4", "",
    "z6-99999", "2", "1", "N", "Test weather 1",
    "17.74", "-64.80", "33.5", "1", "", "", "", "2026-11-20 10:00", "2",
    "Y", "", "1",
    "Y", "Y", "1", "N", "Y", "Y", "2", "Y", "10", "Y", "N", "N", "N", "N",
    "Y",
    "N",                             # no vwc station now
    "Y", "N"
  )
  run <- with_inputs(answers, metadata_manager())
  expect_match(paste(run$output, collapse = "\n"),
               "Port 2 not recorded - record it with 'Port configuration change'", fixed = TRUE)
  m <- load_zentra_metadata()
  w <- m[m$station_id == "bta1_weather", ]
  p <- read_table("zentra_ports")
  expect_equal(p$port[p$unique_id == w$unique_id], 1)
  expect_false("bta1_vwc1" %in% m$station_id)
})

#### Replacing a device ####

test_that("2a: a HOBO replaced in the same housing takes the old one's role and the surveys that hold", {
  local_test_root()
  answers <- c(
    "1", "4",                        # existing station work; replacement
    "1", "2", "Y",                   # bta2_hydro; testb, the secondary
    "99999904", "1", "3",
    "Y", "1",                        # role: secondary, freed by testb leaving
    "Test Gut 2b",                   # location and elevation inherited
    "9", "", "", "2026-11-21 09:00", "1",
    "Y",                             # confirm the new device
    "Y", "N", "Y",                   # reach and fall hold; the sensor height does not
    "1",                             # DAH
    "Y",                             # record matches
    "N", "N"                         # nothing else here; nothing else at all
  )
  run <- with_inputs(answers, metadata_manager())

  old <- meta_row("t-0002")
  expect_equal(old$status, "replaced")
  expect_equal(format(old$end_datetime, "%Y-%m-%d %H:%M"), "2026-11-21 09:00")

  m <- load_zentra_metadata()
  new <- m[m$device_serial == "99999904", ]
  expect_equal(c(new$station_id, new$device_role, new$device_name, new$status),
               c("bta2_hydro", "secondary", "Test Gut 2b", "manual"))
  expect_equal(new$elev, meta_row("t-0001")$elev)

  # The reach and the fall are carried, naming where they came from; the new
  # sensor height is its own
  s <- load_surveys()
  mine <- s[s$unique_id == new$unique_id, ]
  expect_equal(nrow(mine), 3)
  expect_equal(sum(mine$carried_from %in% "t-0002"), 2)
  expect_equal(survey_height(new$unique_id, "sensor", "t-0001", "sensor", s), NA_real_)
  expect_equal(mine$value[mine$quantity == "height_cm" & mine$point == "sensor"], 9)

  log <- read_log()
  e <- log[log$unique_id == new$unique_id, ]
  expect_equal(nrow(e), 1)
  expect_equal(c(e$action_type, e$field_visit_date), c("device_replacement", "2026-11-21"))
  expect_equal(e$details, "Replaced testb (90000002) with Test Gut 2b (99999904); 2 survey rows carried over")
})

test_that("2b: a shared ZL6 replaced takes over at both its stations, with the sensors moved across", {
  local_test_root()
  answers <- c(
    "1", "4",
    "7", "1", "Y",                   # zzu_weather; its ZL6
    "z6-99998", "2", "1",            # Meter; ZL6
    "N", "Test U new",               # no role; name
    "", "", "",                      # standard height; interval and zone default
    "2026-11-21 09:00", "2",         # deployed; online
    "Y", "1",                        # confirm; DAH
    "Y",                             # same sensors, same ports
    "Y", "Y",                        # both records match
    "N", "N"
  )
  run <- with_inputs(answers, metadata_manager())
  expect_match(paste(run$output, collapse = "\n"),
               "also served zzu_vwc1 - the new logger takes over there too", fixed = TRUE)

  expect_equal(meta_row("t-0009")$status, "replaced")
  expect_equal(meta_row("t-0010")$status, "replaced")
  expect_equal(format(meta_row("t-0010")$end_datetime, "%Y-%m-%d %H:%M"), "2026-11-21 09:00")

  m <- load_zentra_metadata()
  new <- m[m$device_serial == "z6-99998", ]
  new <- new[order(new$station_id), ]
  expect_equal(new$station_id, c("zzu_vwc1", "zzu_weather"))
  expect_equal(new$device_name, c("Test U new", "Test U new"))
  expect_equal(format(new$deploy_datetime, "%Y-%m-%d %H:%M"), rep("2026-11-21 09:00", 2))

  # The sensors moved across, each to its own station's row on the new logger
  p <- read_table("zentra_ports")
  open <- p[is.na(p$valid_to) & p$unique_id %in% new$unique_id, ]
  expect_equal(open$port[open$unique_id == new$unique_id[2]], 1)
  expect_equal(sort(open$port[open$unique_id == new$unique_id[1]]), 2:6)
  old_open <- p[is.na(p$valid_to) & p$unique_id %in% c("t-0009", "t-0010"), ]
  expect_equal(nrow(old_open), 0)

  log <- read_log()
  e <- log[log$unique_id %in% new$unique_id, ]
  expect_equal(sort(e$station_id), c("zzu_vwc1", "zzu_weather"))
  expect_true(all(e$action_type == "device_replacement"))
})

#### Relocating a station ####

test_that("3a: a station moving with its logger ends the old row there and starts one at the new spot", {
  local_test_root()
  answers <- c(
    "1", "6", "5", "Y",              # relocation; zzb_hydro
    "1",                             # the same logger moves
    "17.75", "-64.79", "20", "1",    # new position; elevation typed from a DEM
    "11",                            # its sensor height there
    "2026-11-21 09:00", "1",         # moved; manual
    "Y", "1",                        # confirm; DAH
    "Y", "N"
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")
  expect_false(grepl("Ports:", out, fixed = TRUE))   # a HOBO has none

  old <- meta_row("t-0007")
  expect_equal(old$status, "relocated")
  expect_equal(format(old$end_datetime, "%Y-%m-%d %H:%M"), "2026-11-21 09:00")
  expect_equal(format(old$last_visit), "2026-11-21")

  m <- load_zentra_metadata()
  new <- m[m$station_id == "zzb_hydro" & m$status == "manual", ]
  expect_equal(nrow(new), 1)
  expect_equal(c(new$device_serial, new$lat, new$lon, new$elev),
               c("21652379", "17.75", "-64.79", "20"))
  expect_equal(format(new$deploy_datetime, "%Y-%m-%d %H:%M"), "2026-11-21 09:00")

  s <- load_surveys()
  h <- s[s$unique_id == new$unique_id, ]
  expect_equal(c(h$point, h$relative_to, h$value), c("sensor", "bed", "11"))

  log <- read_log()
  e <- log[log$unique_id == new$unique_id, ]
  expect_equal(c(e$action_type, e$field_visit_date), c("station_relocation", "2026-11-21"))
  expect_equal(e$details, "Station relocated from (17.7, -64.8) to (17.75, -64.79)")
})

test_that("a move dated before the station's deployment began is asked again", {
  local_test_root()
  answers <- c("1", "6", "5", "Y", "1", "17.75", "-64.79", "20", "1", "",
               "2020-01-01 09:00",            # before zzb_hydro began (2026-08-01)
               "2026-11-21 09:00", "1",
               "N",                           # not confirmed
               "q", "q")                      # out of both menus
  run <- with_inputs(answers, metadata_manager())
  expect_match(paste(run$output, collapse = "\n"),
               "That is before its current deployment began", fixed = TRUE)
  expect_equal(meta_row("t-0007")$status, "manual")
})

test_that("3b: a ZL6 moving while its soil station stays behind removes that station, its sensors closing", {
  local_test_root()
  answers <- c(
    "1", "6", "7", "Y",              # zzu_weather
    "N",                             # zzu_vwc1 did not move
    "1",                             # the same logger moves
    "Y",                             # the ATMOS moved with it
    "17.71", "-64.81", "30", "1", "",
    "2026-11-21 09:00", "2",
    "Y", "1", "Y", "N"
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")
  expect_match(out, "Staying behind, closed at the move:", fixed = TRUE)
  expect_match(out, "Moving with the logger:\n\n  Port 1: ATMOS 41", fixed = TRUE)

  expect_equal(meta_row("t-0009")$status, "relocated")
  stayed <- meta_row("t-0010")
  expect_equal(stayed$status, "removed")
  expect_equal(format(stayed$end_datetime, "%Y-%m-%d %H:%M"), "2026-11-21 09:00")

  m <- load_zentra_metadata()
  new <- m[m$station_id == "zzu_weather" & m$status == "online", ]
  expect_equal(nrow(new), 1)
  expect_false(any(m$station_id == "zzu_vwc1" & !m$status %in% TERMINAL_STATUSES))

  # The ATMOS moved to the new row; the TEROS closed with the station left behind
  p <- read_table("zentra_ports")
  expect_equal(p$port[p$unique_id == new$unique_id & is.na(p$valid_to)], 1)
  expect_equal(sum(p$unique_id == "t-0010" & is.na(p$valid_to)), 0)

  log <- read_log()
  r <- log[log$station_id == "zzu_vwc1" & log$action_type == "device_removal", ]
  expect_equal(nrow(r), 1)
  expect_equal(r$unique_id, "t-0010")
  expect_match(r$details, "moved with zzu_weather and its sensors came out", fixed = TRUE)
})

test_that("a coordinate outside the Virgin Islands is shown and asked again unless confirmed", {
  run <- with_inputs(c("2", "1", "N", "17.74", "-64.8"), ui_prompt_coordinates())
  expect_equal(unname(run$value), c(17.74, -64.8))
  expect_match(paste(run$output, collapse = "\n"), "is outside the Virgin Islands", fixed = TRUE)
})

test_that("3c: a station moving onto a new logger closes the old one's ports and takes its sensors across", {
  local_test_root()
  answers <- c(
    "1", "6", "8", "Y",              # zzv_vwc1, a lone vwc ZL6
    "2",                             # a different logger goes in
    "z6-99997", "2", "1", "New vwc", # Meter; ZL6; its name
    "17.72", "-64.82", "25", "1",
    "2026-11-21 09:00", "2",
    "Y", "1",
    "Y",                             # the same sensors went into it
    "Y", "N"
  )
  run <- with_inputs(answers, metadata_manager())

  old <- meta_row("t-0011")
  expect_equal(old$status, "relocated")
  m <- load_zentra_metadata()
  new <- m[m$device_serial == "z6-99997", ]
  expect_equal(c(new$station_id, new$device_name, new$model, new$status),
               c("zzv_vwc1", "New vwc", "ZL6", "online"))
  expect_equal(c(new$lat, new$lon), c(17.72, -64.82))

  p <- read_table("zentra_ports")
  expect_equal(sum(p$unique_id == "t-0011" & is.na(p$valid_to)), 0)
  now <- p[p$unique_id == new$unique_id & is.na(p$valid_to), ]
  expect_equal(now$port[order(now$port)], 1:4)
  expect_equal(now$depth_cm[order(now$port)], c(10, 30, 50, 100))
  expect_equal(format(unique(now$valid_from), "%Y-%m-%d %H:%M"), "2026-11-21 09:00")

  log <- read_log()
  e <- log[log$unique_id == new$unique_id, ]
  expect_equal(e$action_type, "station_relocation")
  expect_match(e$details, "device changed from real vwc ZL6 (z6-38175) to New vwc (z6-99997)", fixed = TRUE)
})

test_that("both stations on a ZL6 moving onto a new logger are moved, logged, and reviewed once", {
  local_test_root()
  answers <- c(
    "1", "6", "7", "Y",
    "Y",                             # zzu_vwc1 moved too
    "2", "z6-99996", "2", "1", "U new",
    "17.71", "-64.81", "30", "1", "",
    "2026-11-21 09:00", "2",
    "Y", "1",
    "Y",                             # same sensors, same ports
    "Y", "Y",                        # zzu_weather; zzu_vwc1, same logger
    "N"
  )
  run <- with_inputs(answers, metadata_manager())
  out <- paste(run$output, collapse = "\n")
  expect_equal(lengths(regmatches(out, gregexpr("--- METADATA REVIEW", out, fixed = TRUE))), 1)

  m <- load_zentra_metadata()
  new <- m[m$device_serial == "z6-99996", ]
  expect_equal(sort(new$station_id), c("zzu_vwc1", "zzu_weather"))
  expect_true(all(new$lat == 17.71))
  p <- read_table("zentra_ports")
  open <- p[is.na(p$valid_to) & p$unique_id %in% new$unique_id, ]
  expect_equal(nrow(open), 6)
  log <- read_log()
  e <- log[log$unique_id %in% new$unique_id, ]
  expect_equal(sort(e$station_id), c("zzu_vwc1", "zzu_weather"))
  expect_true(all(e$action_type == "station_relocation"))
})
