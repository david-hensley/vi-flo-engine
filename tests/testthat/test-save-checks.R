################################################################################
# Validation on save: a save that would add a problem is refused; one that
# leaves a known problem as it was goes through. A change of several saves is
# checked once, at its end, and put back whole if refused.
################################################################################

test_that("a save that would add a problem is refused, and nothing is written", {
  local_test_root()
  before <- readLines(table_path("device_metadata"))
  m <- load_zentra_metadata()
  m$status[m$unique_id == "t-0004"] <- "sleeping"          # not a status
  out <- utils::capture.output(ok <- save_device_metadata(m))
  expect_false(isTRUE(ok))
  expect_identical(readLines(table_path("device_metadata")), before)
  expect_true(any(grepl("SAVE REFUSED", out)))
  expect_true(any(grepl("INVALID_STATUS", out)))
})

test_that("a problem already there does not stop an unrelated save", {
  local_test_root()
  m <- read_table("device_metadata")
  m$status[m$unique_id == "t-0004"] <- "sleeping"
  write_table("device_metadata", m, guard = FALSE)          # planted, as a hand edit would
  m <- load_zentra_metadata()
  m$device_name[m$unique_id == "t-0005"] <- "renamed"
  expect_true(isTRUE(save_device_metadata(m)))
  expect_equal(meta_row("t-0005")$device_name, "renamed")
})

test_that("a second row with a known problem is still a new problem", {
  local_test_root()
  m <- read_table("device_metadata")
  m$status[m$unique_id == "t-0004"] <- "sleeping"
  write_table("device_metadata", m, guard = FALSE)
  m <- load_zentra_metadata()
  m$status[m$unique_id == "t-0005"] <- "dozing"
  utils::capture.output(ok <- save_device_metadata(m))
  expect_false(isTRUE(ok))
})

test_that("a log row that would add a problem is refused", {
  local_test_root()
  n <- nrow(read_log())
  expect_error(utils::capture.output(append_rows("maintenance_log", data.frame(
    logged_utc = Sys.time(), field_visit_date = Sys.Date(), station_id = "bta2_hydro",
    unique_id = "t-9999", action_type = "inspection", details = "x", logged_by = "DAH"))),
    "nothing added")
  expect_equal(nrow(read_log()), n)
})

test_that("a change of several saves is checked once, at its end", {
  local_test_root()
  # Retiring z6-13368's weather row closes its ports as well: halfway, the row
  # has ended with its ports open - fine, because only the end is checked
  uid <- load_zentra_metadata()
  uid <- uid$unique_id[uid$device_serial == "z6-13368" & uid$station_type == "weather"]
  expect_true(isTRUE(retire_row(uid, as.POSIXct("2026-11-01 10:00:00", tz = PROJECT_TZ),
                                status = "removed")))
  expect_equal(meta_row(uid)$status, "removed")
})

test_that("a change that would add a problem is put back whole", {
  local_test_root()
  meta_before <- readLines(table_path("device_metadata"))
  ports_before <- readLines(table_path("zentra_ports"))
  out <- utils::capture.output(res <- with_metadata_change("a test", {
    p <- load_zentra_ports_data()
    p$valid_to[1] <- as.POSIXct("2026-11-01", tz = PROJECT_TZ)
    save_zentra_ports(p)                                     # fine on its own
    m <- load_zentra_metadata()
    m$status[m$unique_id == "t-0004"] <- "sleeping"          # not fine
    save_device_metadata(m)
    TRUE
  }))
  expect_match(res, "Refused")
  expect_identical(readLines(table_path("device_metadata")), meta_before)
  expect_identical(readLines(table_path("zentra_ports")), ports_before)
  expect_true(any(grepl("CHANGE REFUSED", out)))
})

test_that("correcting one logger's elevation corrects its whole pair", {
  local_test_root()
  # field 4 is elev in the corrections list for a hydro row; typed by hand
  m <- load_zentra_metadata()
  i <- which(m$unique_id == "t-0002")
  m$elev[m$unique_id %in% elevation_shared_with("t-0002", m)] <- 18
  expect_true(isTRUE(save_device_metadata(m)))
  expect_equal(meta_row("t-0001")$elev, 18)
  expect_equal(meta_row("t-0002")$elev, 18)
})

test_that("the session line says valid, or names the problems", {
  local_test_root()
  out <- utils::capture.output(print_validation_line())
  m <- read_table("device_metadata")
  m$status[m$unique_id == "t-0004"] <- "sleeping"
  write_table("device_metadata", m, guard = FALSE)
  out <- utils::capture.output(print_validation_line())
  expect_true(any(grepl("INVALID_STATUS", out)))
  expect_match(validation_summary_line(), "INVALID_STATUS")
})
