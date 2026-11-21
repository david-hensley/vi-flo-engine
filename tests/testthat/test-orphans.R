################################################################################
# Orphaned raw files: files on disk with no download_log row
#
# The September 2026 full-history exports left three behind under names a day
# off - dates once taken in UTC - beside the logged copies. A copy holding the
# same readings as a logged file is a duplicate and can go; anything else is
# left alone and reported.
################################################################################

orphan_pair <- function(same = TRUE) {
  dir <- wds("device_zentra")
  logged <- "z6-90777_20210713_20250108_20260914T000000_raw.rds"
  stray  <- "z6-90777_20210713_20250109_20260914T000000_raw.rds"
  d <- data.frame(timestamp = 1:3, value = c(1.5, 2.5, 3.5))
  saveRDS(d, file.path(dir, logged))
  saveRDS(if (same) d else transform(d, value = value + 1), file.path(dir, stray),
          compress = "xz")        # different bytes, same readings when same
  append_rows("download_log", data.frame(
    timestamp_utc = as.POSIXct("2026-09-14 00:00:00", tz = "UTC"), run_id = "20260914T000000",
    device_serial = "z6-90777",
    start_date = as.POSIXct("2021-07-13 12:45:00", tz = PROJECT_TZ),
    end_date = as.POSIXct("2025-01-08 22:30:00", tz = PROJECT_TZ),
    n_records = 3L, filepath = file.path("internal/device-data/zentra", logged),
    download_type = "export", battery = NA_real_, stringsAsFactors = FALSE))
  stray
}

test_that("a copy a day off, with the same readings, is found as a duplicate", {
  local_test_root()
  stray <- orphan_pair(same = TRUE)
  o <- find_orphan_raw_files()
  o <- o[o$file == stray, ]
  expect_equal(o$duplicate_of, "z6-90777_20210713_20250108_20260914T000000_raw.rds")
  expect_true(o$identical)
})

test_that("a copy a day off with different readings is not a duplicate", {
  local_test_root()
  stray <- orphan_pair(same = FALSE)
  o <- find_orphan_raw_files()
  expect_false(o$identical[o$file == stray])
})
