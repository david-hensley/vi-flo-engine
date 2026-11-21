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

test_that("the network status names devices, and keeps the cloud and archive dates apart", {
  local_test_root()
  roster <- get_station_roster(devices = data.frame(device_id = character(0),
                                                    last_measurement = as.POSIXct(character(0))))
  out <- utils::capture.output(print_station_roster(roster))
  header <- out[grepl("station", out) & grepl("archived to", out)]
  expect_length(header, 1)
  expect_true(regexpr("cloud contact", header) < regexpr("batt", header))
  expect_true(regexpr("batt", header) < regexpr("archived to", header))
  expect_true(any(grepl("testb", out)))                    # bta2b by its name
  expect_false(any(grepl("90000002", out)))                # not its serial
})

test_that("the to-do list names devices too", {
  local_test_root()
  todo <- data.frame(station = "bta2_hydro", device = "90000002", severity = "low",
                     issue = "no survey", type = "survey", stringsAsFactors = FALSE)
  todo$severity <- factor(todo$severity, levels = c("high", "medium", "low", "error"))
  todo$type <- factor(todo$type, levels = c("reporting", "battery", "memory", "survey",
                                            "known broken", "ports", "not established", "metadata review"))
  out <- utils::capture.output(print_network_todo(todo))
  expect_true(any(grepl("testb", out)))
  expect_false(any(grepl("90000002", out)))
})
