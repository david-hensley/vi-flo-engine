# What the archive says about a deployment is worked out from the download
# log, through the files of that deployment's own logger during that
# deployment - never stored on the row, and never credited across a logger's
# deployments. sgm2_hydro's new logger once showed a last reading from 2025:
# its Reef Bay years, counted by serial.

test_that("a deployment reaches only as far as its own logger's files during it", {
  local_test_root()
  m <- load_zentra_metadata()
  # 90000002 served rb2_hydro (t-0003) until 2024-11-05, then bta2_hydro (t-0002)
  dl <- data.frame(
    timestamp_utc = c("2024-06-01 12:00:00", "2026-10-15 12:00:00"), run_id = NA,
    device_serial = "90000002",
    start_date = as.POSIXct(c("2024-01-01 00:00:00", "2026-09-01 00:00:00"), tz = "America/Puerto_Rico"),
    end_date   = as.POSIXct(c("2024-05-31 00:00:00", "2026-10-14 00:00:00"), tz = "America/Puerto_Rico"),
    n_records = 100L, filepath = c("a_raw.rds", "b_raw.rds"), download_type = "manual",
    battery = c(NA, 90), stringsAsFactors = FALSE)
  a <- deployment_activity(m[m$unique_id %in% c("t-0002", "t-0003"), ], dl)
  expect_equal(format(a$data_to[a$unique_id == "t-0003"], "%Y-%m-%d"), "2024-05-31")
  expect_equal(format(a$data_to[a$unique_id == "t-0002"], "%Y-%m-%d"), "2026-10-14")
  expect_equal(a$battery[a$unique_id == "t-0002"], 90)
  expect_true(is.na(a$battery[a$unique_id == "t-0003"]))
})

test_that("a deployment with no files has no reach, rather than a borrowed one", {
  local_test_root()
  m <- load_zentra_metadata()
  a <- deployment_activity(m[m$unique_id == "t-0004", ])
  expect_true(is.na(a$data_to))
})
