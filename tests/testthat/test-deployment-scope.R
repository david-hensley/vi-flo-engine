# A serial can carry several rows: a retired deployment and its successor, or
# one Zentra logger serving two stations. A writer must touch the row it
# means, not every row with that serial. This has been fixed twice.
#
# Fixture: serial 90000002 is bta2b (t-0002, active) and an older deployment
# at Reef Bay (t-0003, removed). z6-90001 serves uvi_weather (t-0005) and
# uvi_vwc1 (t-0006).

test_that("the single-device writer changes one row, by unique_id", {
  local_test_root()
  before <- load_zentra_metadata()
  expect_true(survey_device_elevation("t-0004", elev = 31.3, elev_source = "gnss",
                                      sensor_height_cm = 30))
  after <- load_zentra_metadata()

  expect_equal(after$elev[after$unique_id == "t-0004"], 31.3)
  expect_equal(after$sensor_height_cm[after$unique_id == "t-0004"], 30)
  others <- after$unique_id != "t-0004"
  expect_identical(after[others, ], before[others, ])
})

test_that("surveying bta2b leaves its retired Reef Bay deployment of the same serial alone", {
  local_test_root()
  retired <- meta_row("t-0003")
  survey_device_elevation("t-0002", sensor_height_cm = 3)
  expect_equal(meta_row("t-0002")$sensor_height_cm, 3)
  expect_equal(meta_row("t-0003"), retired)
})

test_that("a weather station's sensor height does not leak onto its co-located vwc row", {
  local_test_root()
  survey_device_elevation("t-0005", sensor_height_cm = 210)
  m <- load_zentra_metadata()
  expect_equal(m$sensor_height_cm[m$unique_id == "t-0005"], 210)
  expect_true(is.na(m$sensor_height_cm[m$unique_id == "t-0006"]))
})

test_that("moving a primary moves its surveyed partner by the same amount", {
  local_test_root()
  survey_device_elevation("t-0001", elev = 17.60, elev_source = "gnss",
                          sensor_height_cm = NA,
                          shift_unique_ids = "t-0002", shift_by = 0.06)
  m <- load_zentra_metadata()
  expect_equal(m$elev[m$unique_id == "t-0002"], 17.823)
  expect_equal(m$elev[m$unique_id == "t-0003"], 7.6)   # the retired row stays put
})

test_that("the paired-survey writer leaves a retired deployment of the same serial alone", {
  local_test_root()
  before <- meta_row("t-0003")
  expect_true(survey_dual_logger_elevations("bta2_hydro", "90000001", "90000002",
                                            primary_elev = 17.54,
                                            elevation_diff = 0.1294,
                                            reach_length_m = 24.16))
  expect_equal(meta_row("t-0002")$elev, 17.6694)
  expect_equal(meta_row("t-0002")$reach_length_m, 24.16)
  # equal, not identical: read.csv types a column by what it holds, so a
  # column that gains 24.16 comes back double where it was integer
  expect_equal(meta_row("t-0003"), before)
})

test_that("a paired survey can write either half alone", {
  local_test_root()
  survey_dual_logger_elevations("bta2_hydro", "90000001", "90000002",
                                primary_elev = 17.54, elevation_diff = NA,
                                reach_length_m = 24.16)
  expect_equal(meta_row("t-0002")$elev, 17.763)     # untouched
  expect_equal(meta_row("t-0002")$reach_length_m, 24.16)

  survey_dual_logger_elevations("bta2_hydro", "90000001", "90000002",
                                primary_elev = 17.54, elevation_diff = 0.1294,
                                reach_length_m = NA)
  expect_equal(meta_row("t-0002")$elev, 17.6694)
  expect_equal(meta_row("t-0002")$reach_length_m, 24.16)  # kept from before
})
