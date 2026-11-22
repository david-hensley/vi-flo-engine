# Metadata manager: correcting recorded details, viewing ports, and the
# changes that must land whole or not at all

# The menu number of a station in the correction workflow's list
station_choice <- function(station_id) {
  ids <- vapply(get_station_list(include_retired = TRUE), `[[`, character(1), "station_id")
  as.character(match(station_id, ids))
}

test_that("viewing all ports lists a logger whose ports are all closed, by name, without stopping", {
  local_test_root()
  ports <- read_table("zentra_ports")
  # The vwc row on the shared ZL6 had its sensors taken off, and one open
  # row has no sensor recorded
  closed <- data.frame(unique_id = "t-0006", port = 2:3, sensor = "TEROS 12",
                       depth_cm = c(10, 30), status = NA,
                       valid_from = as.POSIXct("2022-01-01 12:00:00", tz = PROJECT_TZ),
                       valid_to = as.POSIXct("2023-01-01 12:00:00", tz = PROJECT_TZ))
  blank <- data.frame(unique_id = "t-0011", port = 6, sensor = NA, depth_cm = NA,
                      status = NA,
                      valid_from = as.POSIXct("2026-01-01 12:00:00", tz = PROJECT_TZ),
                      valid_to = as.POSIXct(NA, tz = PROJECT_TZ))
  write_table("zentra_ports", rbind(ports, closed, blank), guard = FALSE)

  run <- with_inputs("1", ui_view_ports())
  out <- paste(run$output, collapse = "\n")
  expect_match(out, "real vwc ZL6 (z6-38175) at zzv_vwc1", fixed = TRUE)
  expect_match(out, "Port 6: unknown sensor", fixed = TRUE)
  # Nothing open on t-0006, so it has no block among active configs
  expect_false(grepl("at uvi_vwc1", out, fixed = TRUE))
})

test_that("a device's port history is listed by deployment, chosen by name", {
  local_test_root()
  labels <- sort(vapply(c("z6-13368", "z6-38175"), device_label, character(1)))
  run <- with_inputs(c("2", as.character(match(device_label("z6-13368"), labels))),
                     ui_view_ports())
  out <- paste(run$output, collapse = "\n")
  expect_match(out, "at zzu_weather ---", fixed = TRUE)
  expect_match(out, "at zzu_vwc1 ---", fixed = TRUE)
  expect_match(out, "[2023-01-01 12:00 to present]", fixed = TRUE)
})

test_that("correcting a deploy time moves the ports that began with it, and logs the correction", {
  local_test_root()
  answers <- c(station_choice("zzv_vwc1"),   # one device there, so no device menu
               "5",                          # deploy_datetime
               "2025-12-31 09:00:00", "Y",   # the corrected time, applied
               "1",                          # logged by DAH
               "q")
  run <- with_inputs(answers, ui_correct_device_details())
  expect_true(isTRUE(run$value))

  expect_equal(format(meta_row("t-0011")$deploy_datetime, "%Y-%m-%d %H:%M:%S"),
               "2025-12-31 09:00:00")
  p <- read_table("zentra_ports")
  starts <- format(p$valid_from[p$unique_id == "t-0011"], "%Y-%m-%d %H:%M:%S")
  expect_equal(unique(starts), "2025-12-31 09:00:00")

  log <- read_log()
  entry <- log[nrow(log), ]
  expect_equal(entry$action_type, "metadata_correction")
  expect_equal(entry$unique_id, "t-0011")
  expect_match(entry$details, "deploy_datetime: 2026-01-01 12:00:00 → 2025-12-31 09:00:00",
               fixed = TRUE)
  expect_match(entry$details, "4 port rows moved with it", fixed = TRUE)
  expect_equal(entry$logged_by, "DAH")
})

test_that("a logging interval corrected on a shared ZL6 changes both rows and is logged once", {
  local_test_root()
  n_before <- nrow(read_log())
  devices_menu <- c(station_choice("uvi_weather"),
                    "4",               # interval_min
                    "5", "Y", "1",     # 5 minutes, applied, DAH
                    "q")
  run <- with_inputs(devices_menu, ui_correct_device_details())
  expect_true(isTRUE(run$value))
  expect_equal(meta_row("t-0005")$interval_min, 5)
  expect_equal(meta_row("t-0006")$interval_min, 5)

  log <- read_log()
  expect_equal(nrow(log), n_before + 1)
  expect_match(log$details[nrow(log)], "interval_min: 15 → 5 (2 rows)", fixed = TRUE)
})

test_that("a deploy time corrected to after the device came out is refused before saving", {
  local_test_root()
  n_before <- nrow(read_log())
  answers <- c(station_choice("zzs_hydro"),
               "5", "2025-01-01 12:00:00",   # after its end, 2024-08-22
               "q")
  run <- with_inputs(answers, ui_correct_device_details())
  expect_match(paste(run$output, collapse = "\n"), "after the end time", fixed = TRUE)
  expect_equal(format(meta_row("t-0008")$deploy_datetime, "%Y-%m-%d"), "2023-07-01")
  expect_equal(nrow(read_log()), n_before)
})

test_that("an end time corrected on a retired device moves the ports that closed with it", {
  local_test_root()
  ports <- read_table("zentra_ports")
  write_table("zentra_ports", rbind(ports, data.frame(
    unique_id = "t-0008", port = 1, sensor = "TEROS 12", depth_cm = 10, status = NA,
    valid_from = as.POSIXct("2023-07-01 12:00:00", tz = PROJECT_TZ),
    valid_to = as.POSIXct("2024-08-22 23:59:59", tz = PROJECT_TZ))), guard = FALSE)

  answers <- c(station_choice("zzs_hydro"),
               "9",                          # end_datetime, after the eight common fields
               "2024-08-20 10:00:00", "Y", "1",
               "q")
  run <- with_inputs(answers, ui_correct_device_details())
  expect_true(isTRUE(run$value))
  expect_equal(format(meta_row("t-0008")$end_datetime, "%Y-%m-%d %H:%M:%S"), "2024-08-20 10:00:00")
  p <- read_table("zentra_ports")
  expect_equal(format(p$valid_to[p$unique_id == "t-0008"], "%Y-%m-%d %H:%M:%S"),
               "2024-08-20 10:00:00")
})

test_that("an event time before the deployment began is asked again", {
  local_test_root()
  run <- with_inputs(c("2020-01-01 10:00", "2026-02-01 10:00"),
                     ui_prompt_event_time("When", PROJECT_TZ,
                                          as.POSIXct("2026-01-01 12:00:00", tz = PROJECT_TZ)))
  expect_equal(format(run$value, "%Y-%m-%d %H:%M"), "2026-02-01 10:00")
  expect_match(paste(run$output, collapse = "\n"), "before its current deployment began",
               fixed = TRUE)
})

test_that("a port change on a shared ZL6 is logged at the station whose sensor changed, saying how", {
  local_test_root()
  n_before <- nrow(read_log())
  answers <- c("2026-11-01 10:00",                 # when
               "N", "N", "N", "N", "N",            # ports 1-5 unchanged
               "Y", "N",                           # port 6 emptied
               "Y",                                # save
               "1")                                # logged by DAH
  run <- with_inputs(answers, ui_update_ports(preset_device_serial = "z6-13368"))
  expect_true(isTRUE(run$value))

  log <- read_log()
  expect_equal(nrow(log), n_before + 1)
  entry <- log[nrow(log), ]
  expect_equal(entry$action_type, "port_config_change")
  expect_equal(c(entry$station_id, entry$unique_id), c("zzu_vwc1", "t-0010"))
  expect_match(entry$details, "port 6: TEROS 10 @ 100cm → empty", fixed = TRUE)
  expect_match(paste(run$output, collapse = "\n"), "Logged to maintenance at zzu_vwc1", fixed = TRUE)
})

# The menu number of a live station in the maintenance workflow's list
live_choice <- function(station_id) {
  ids <- vapply(get_station_list(), `[[`, character(1), "station_id")
  as.character(match(station_id, ids))
}

test_that("maintenance at a paired gauge changes the status of the logger chosen, and a relaunch rename lands with it", {
  local_test_root()
  n_before <- nrow(read_log())
  answers <- c("2026-11-10",                      # visit date
               live_choice("bta2_hydro"), "2",    # the secondary, testb
               "5", "relaunched",                 # relaunch, details
               "1",                               # logged by DAH
               "N", "4",                          # status changed: defunct
               "Y", "testb2", "N",                # renamed; interval kept
               "Y",                               # confirm
               "N")                               # record does not match yet
  run <- with_inputs(answers, ui_log_maintenance())
  expect_false(is.null(run$value))

  expect_equal(meta_row("t-0002")$status, "defunct")
  expect_equal(meta_row("t-0001")$status, "manual")
  expect_equal(meta_row("t-0002")$device_name, "testb2")

  log <- read_log()
  expect_equal(nrow(log), n_before + 2)
  expect_equal(log$action_type[n_before + 1:2], c("logger_relaunch", "device_renamed"))
  expect_true(all(log$unique_id[n_before + 1:2] == "t-0002"))
})

test_that("a relaunch rename of a logger never named is saved, not stopped by the blank name", {
  local_test_root()
  m <- load_zentra_metadata()
  m$device_name[m$unique_id == "t-0004"] <- NA
  write_table("device_metadata", m, guard = FALSE)

  answers <- c("2026-11-10", live_choice("srl1_pond"), "1",
               "5", "", "1",                      # relaunch, no details, DAH
               "Y",                               # status kept
               "Y", "srl1", "N", "Y", "N")
  run <- with_inputs(answers, ui_log_maintenance())
  expect_false(is.null(run$value))
  expect_equal(meta_row("t-0004")$device_name, "srl1")
  expect_match(read_log()$details[nrow(read_log())], "Renamed from '(blank)' to 'srl1'", fixed = TRUE)
})
