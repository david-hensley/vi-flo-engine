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
  todo$type <- factor(todo$type, levels = c(TODO_FIELD, TODO_DESK, "error"))
  out <- utils::capture.output(print_network_todo(todo))
  expect_true(any(grepl("testb", out)))
  expect_false(any(grepl("90000002", out)))
})

test_that("the to-do prints field and desk in boxes, every section, names for unknown loggers", {
  local_test_root()
  devices <- data.frame(device_id = c("z6-13368", "z6-77001"), name = c("real ZL6", "near southeast"),
                        last_measurement = as.POSIXct(c("2026-11-20 10:00", "2026-11-21 10:00"), tz = "UTC"),
                        stringsAsFactors = FALSE)
  todo <- get_network_todo(devices = devices)
  out <- utils::capture.output(print_network_todo(todo))
  expect_true(which(grepl("\\|  FIELD", out)) < which(grepl("\\|  DESK", out)))
  for (h in c("NOT REPORTING", "SURVEYS OUTSTANDING", "VALIDATION", "PRODUCT 2", "NOT IN METADATA")) {
    expect_true(any(out == h), info = h)
  }
  # A logger VI-FLO has no row for, by its ZentraCloud name and its serial
  line <- out[grepl("near southeast", out)]
  expect_length(line, 1)
  expect_match(line, "z6-77001 - on ZentraCloud")
})

test_that("a retired logger going quiet is not listed as not reporting", {
  local_test_root()
  # 21180078 is t-0008, removed; ZentraCloud still lists it, silent for weeks
  devices <- data.frame(device_id = "21180078", name = "old", stringsAsFactors = FALSE,
                        last_measurement = as.POSIXct("2026-01-01 10:00", tz = "UTC"))
  todo <- get_network_todo(devices = devices)
  expect_false(any(todo$type == "reporting"))
})

test_that("a Product 2 file the manifest does not list is found", {
  local_test_root()
  dir <- file.path(wds("products"), "p2", "hydro", "zzb_hydro", "water_level")
  dir.create(dir, recursive = TRUE)
  writeLines("x", gzfile(file.path(dir, "zzb_hydro_water_level_p2_2024.csv.gz")))
  expect_true(any(grepl("zzb_hydro_water_level_p2_2024.csv.gz", p2_unlisted_files())))
})

test_that("a logger recorded as wholly unattributed is not asked about", {
  local_test_root()
  write_table("known_unattributed", data.frame(
    device_serial = "z6-77001", device_name = "near southeast", port = NA_integer_,
    from = as.POSIXct(NA), to = as.POSIXct(NA), reason = "not VI-FLO's",
    stringsAsFactors = FALSE), guard = FALSE)
  devices <- data.frame(device_id = "z6-77001", name = "near southeast", stringsAsFactors = FALSE,
                        last_measurement = as.POSIXct("2026-11-21 10:00", tz = "UTC"))
  todo <- get_network_todo(devices = devices)
  expect_false(any(todo$type == "not in metadata" & grepl("z6-77001", todo$issue)))
})
