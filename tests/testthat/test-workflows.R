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
  expect_match(entry$details, "upstream 90000002", fixed = TRUE)
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
