# A serial can carry several rows: a retired deployment and its successor, or
# one Zentra logger serving two stations. A writer must touch the row it
# means, not every row with that serial. This has been fixed twice.
#
# Fixture: serial 90000002 is bta2b (t-0002, active) and an older deployment
# at Reef Bay (t-0003, removed). z6-90001 serves uvi_weather (t-0005) and
# uvi_vwc1 (t-0006).

test_that("the elevation writer changes one row, by unique_id", {
  local_test_root()
  before <- load_zentra_metadata()
  expect_true(survey_device_elevation("t-0004", elev = 31.3, elev_source = "gnss"))
  after <- load_zentra_metadata()

  expect_equal(after$elev[after$unique_id == "t-0004"], 31.3)
  others <- after$unique_id != "t-0004"
  expect_identical(after[others, ], before[others, ])
})

test_that("surveying bta2b leaves its retired Reef Bay deployment of the same serial alone", {
  local_test_root()
  retired <- meta_row("t-0003")
  survey_device_elevation("t-0002", elev = 17.7, elev_source = "gnss")
  expect_equal(meta_row("t-0002")$elev, 17.7)
  expect_equal(meta_row("t-0003"), retired)
})

test_that("a survey row belongs to one deployment, not to every row with its serial", {
  local_test_root()
  # z6-90001 serves uvi_weather (t-0005) and uvi_vwc1 (t-0006); 90000002 is
  # bta2b now and was at Reef Bay before
  expect_true(add_survey_rows(survey_row("uvi_weather", "t-0005", "2026-11-01", "height_cm",
                                         "sensor", 210, "ground", method = "tape")))
  s <- load_surveys()
  expect_equal(survey_height("t-0005", "sensor", "t-0005", "ground", s), 210)
  expect_true(is.na(survey_height("t-0006", "sensor", "t-0006", "ground", s)))
  expect_false(any(s$unique_id == "t-0003"))
})
