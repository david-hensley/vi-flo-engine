# Whole metadata manager workflows, driven by scripted answers and checked by
# what they leave in the metadata and the logs. These replace walking the
# menus by hand: if a workflow starts asking different questions, or writes
# something different, a test here fails.

rod <- function(ft, inch, e8) c(ft, inch, e8, "Y")   # one reading, confirmed

test_that("the BTA2 paired survey of 14 October writes 17.669 m and 24.16 m", {
  local_test_root()
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

  b <- meta_row("t-0002")
  expect_equal(b$elev, 17.6694)
  expect_equal(b$reach_length_m, 24.16)
  expect_equal(b$elev_source, "surveyed_relative")
  expect_equal(meta_row("t-0001")$elev, 17.54)        # the anchor is untouched
  expect_equal(meta_row("t-0003")$elev, 7.6)          # so is the retired row

  # Product 0: the readings as typed, and the export under its standard name
  dir <- get_gut_survey_dir()
  expect_true(file.exists(file.path(dir, "bta2_hydro_fall_rod_20261014.csv")))
  expect_true(file.exists(file.path(dir, "bta2_hydro_reach_trupulse_20261014.txt")))
  expect_false(file.exists(file.path(dir, "BTA_2_Reach_Length_2026-10-14.txt")))
  p0 <- read.csv(file.path(dir, "bta2_hydro_fall_rod_20261014.csv"), colClasses = "character")
  expect_equal(p0$entered[p0$setup == "2" & p0$sight == "FS"], "5 1 1.5")

  log <- read_log()
  entry <- log[nrow(log), ]
  expect_equal(entry$action_type, "elevation_survey")
  expect_match(entry$details, "accepted 2+3", fixed = TRUE)
  expect_match(entry$details, "upstream 90000002", fixed = TRUE)
})

test_that("the paired survey refuses a fall that comes out as a climb", {
  local_test_root()
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
  expect_equal(meta_row("t-0002")$elev, 17.763)
  expect_true(any(grepl("a climb, not a fall", run$output)))
})

test_that("Windsor's single-device survey converts through GEOID18 and logs the arithmetic", {
  local_test_root()
  answers <- c(
    "2026-10-16", "1",           # date, DAH
    "2",                         # station: srl1_pond
    "",                          # sensor height: keep 28
    "2", "-10.366", "-41.632",   # ellipsoidal height and geoid height
    "1",                         # ground shot
    "test note",
    "Y"
  )
  run <- with_inputs(answers, ui_survey_single_device())
  expect_true(isTRUE(run$value))

  w <- meta_row("t-0004")
  expect_equal(w$elev, 31.266)
  expect_equal(w$elev_source, "gnss")
  expect_equal(w$sensor_height_cm, 28)

  entry <- read_log()[nrow(read_log()), ]
  expect_equal(entry$action_type, "elevation_survey")
  expect_match(entry$details, "GEOID18 N -41.632 m = H 31.266 m", fixed = TRUE)
  expect_match(entry$details, "test note", fixed = TRUE)
})

test_that("a shot on the measuring point is brought back to the ground", {
  local_test_root()
  answers <- c("2026-10-16", "1", "2", "", "2", "-10.086", "-41.632", "2", "", "Y")
  with_inputs(answers, ui_survey_single_device())
  expect_equal(meta_row("t-0004")$elev, 31.266)       # 31.546 less 28 cm
})

test_that("a hydro secondary is sent to the paired survey, and nothing is written", {
  local_test_root()
  before <- load_zentra_metadata()
  answers <- c("2026-10-16", "1", "1", "2")   # bta2_hydro, then bta2b
  run <- with_inputs(answers, ui_survey_single_device())
  expect_null(run$value)
  expect_identical(load_zentra_metadata(), before)
})
