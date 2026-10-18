# Readings belong to a place, run stamps to a moment. Product 1 filename spans
# are project-local dates; getting the zone wrong moves a late-evening reading
# onto the next day.

test_that("a 22:30 reading in the Virgin Islands is dated that day, not the next", {
  late <- as.POSIXct("2026-10-17 22:30:00", tz = "America/Puerto_Rico")
  # Same instant, expressed in UTC: already 18 October
  in_utc <- as.POSIXct(format(late, tz = "UTC"), tz = "UTC")
  expect_equal(build_raw_filename(late, late, device_serial = "90000001"),
               "90000001_20261017_20261017_raw.rds")
  expect_equal(build_raw_filename(in_utc, in_utc, device_serial = "90000001"),
               "90000001_20261017_20261017_raw.rds")
})

test_that("Product 1 filenames parse back to what built them", {
  f <- build_raw_filename(as.POSIXct("2026-05-13 18:00", tz = "America/Puerto_Rico"),
                          as.POSIXct("2026-12-24 06:00", tz = "America/Puerto_Rico"),
                          device_serial = "22377120")
  p <- parse_raw_filename(f)
  expect_equal(p$device_serial, "22377120")
  expect_true(is.na(p$station))
  expect_equal(p$start, as.Date("2026-05-13"))
  expect_equal(p$end, as.Date("2026-12-24"))
})

test_that("metadata datetimes are formatted in project-local time", {
  utc <- as.POSIXct("2026-10-18 02:30:00", tz = "UTC")
  expect_equal(format_datetime_safe(utc), "2026-10-17 22:30:00")
  expect_equal(format_datetime_safe(utc, tz = "UTC"), "2026-10-18 02:30:00")
})

test_that("an all-blank datetime column formats without error", {
  expect_equal(format_datetime_safe(c(NA, NA)), c(NA_character_, NA_character_))
})

test_that("a typed date and time without seconds keeps its time", {
  tz <- "America/Puerto_Rico"
  expect_equal(format(coerce_datetime_flexible("2023-11-06 10:45", tz), "%Y-%m-%d %H:%M:%S"),
               "2023-11-06 10:45:00")
  expect_equal(format(parse_datetime_flexible("2023-11-06 10:45", tz), "%H:%M"), "10:45")
  # A bare date is still midnight
  expect_equal(format(coerce_datetime_flexible("2023-11-06", tz), "%H:%M"), "00:00")
})
