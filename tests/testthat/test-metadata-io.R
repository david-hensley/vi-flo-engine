# Metadata survives being read and written. The failures of 11 October 2026 -
# a datetime written as a UNIX epoch, a column silently retyped - were all of
# this kind, and every one was found by reading real output by eye.

test_that("load, save and load again gives back exactly what went in", {
  local_test_root()
  a <- load_zentra_metadata()
  expect_true(save_device_metadata(a))
  b <- load_zentra_metadata()
  expect_identical(b, a)
})

test_that("datetimes load as datetimes and are written as text, never epochs", {
  local_test_root()
  m <- load_zentra_metadata()
  expect_s3_class(m$deploy_datetime, "POSIXct")
  expect_s3_class(m$last_download_date, "POSIXct")

  save_device_metadata(m)
  raw <- read.csv(file.path(wds("meta_internal"), "device_metadata.csv"),
                  colClasses = "character")
  stamps <- raw$deploy_datetime[!is.na(raw$deploy_datetime)]
  expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", stamps)))
  expect_false(any(grepl("^\\d{9,}$", stamps)))
})

test_that("an 18:00 local deployment is still 18:00 after a round trip", {
  local_test_root()
  save_device_metadata(load_zentra_metadata())
  raw <- read.csv(file.path(wds("meta_internal"), "device_metadata.csv"),
                  colClasses = "character")
  expect_equal(raw$deploy_datetime[raw$unique_id == "t-0004"], "2026-05-13 18:00:00")
})

test_that("blanks stay blank, and numbers stay numbers", {
  local_test_root()
  m <- load_zentra_metadata()
  expect_true(is.numeric(m$sensor_height_cm))
  expect_true(is.na(m$sensor_height_cm[m$unique_id == "t-0001"]))
  expect_equal(m$sensor_height_cm[m$unique_id == "t-0004"], 28)
  expect_type(m$metadata_approved, "logical")
})

test_that("a file changed since this session read it is not overwritten", {
  local_test_root()
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- load_zentra_metadata()

  # Someone else - another machine, a hand edit - changes the file
  cat("\n", file = path, append = TRUE)
  changed <- readLines(path)

  utils::capture.output(ok <- save_device_metadata(m))
  expect_false(ok)
  expect_identical(readLines(path), changed)
})

test_that("a maintenance note with quotes and commas comes back exactly as typed", {
  local_test_root()
  note <- 'Replaced with lithium, in "device tools" set battery type to lithium, updated firmware'
  utils::capture.output(create_maintenance_entry(
    field_visit_date = "2026-10-26", station_id = "bta2_hydro", station_type = "hydro",
    device_serial = "90000002", action_type = "maintenance", details = note,
    ports_updated = FALSE, logged_by = "DAH"))
  log <- read_log()
  expect_equal(log$details[nrow(log)], note)
  expect_equal(ncol(log), 9)
  raw <- readLines(file.path(wds("meta_internal"), "maintenance_log.csv"))
  bs_quote <- paste0(intToUtf8(92), intToUtf8(34))          # a backslash then a quote
  expect_false(any(grepl(bs_quote, raw, fixed = TRUE)))
})
