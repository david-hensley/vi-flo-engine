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
  out <- utils::capture.output(expect_error(save_device_metadata(m), "was not saved"))
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
  utils::capture.output(ok <- tryCatch(save_device_metadata(m), error = function(e) FALSE))
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

test_that("a change that fails partway is put back whole", {
  local_test_root()
  before <- load_zentra_metadata()
  log_before <- read_log()

  # A first save lands, then the change reports failure: nothing is kept
  res <- with_metadata_change("a test change", {
    m <- load_zentra_metadata()
    m$device_name[m$unique_id == "t-0004"] <- "renamed halfway"
    save_device_metadata(m)
    "Failed: the second step did not happen"
  })
  expect_equal(res, "Failed: the second step did not happen")
  expect_equal(load_zentra_metadata(), before)

  # The same when it fails by error, after a log entry was written
  expect_error(with_metadata_change("a test change", {
    m <- load_zentra_metadata()
    m$device_name[m$unique_id == "t-0004"] <- "renamed halfway"
    save_device_metadata(m)
    create_maintenance_entry(field_visit_date = Sys.Date(), station_id = "srl1_pond",
                             unique_id = "t-0004", action_type = "inspection",
                             details = "x", logged_by = "TST")
    stop("broke after the log")
  }), "broke after the log")
  expect_equal(load_zentra_metadata(), before)
  expect_equal(nrow(read_log()), nrow(log_before))

  # And a relocation-shaped failure, a list saying so
  res <- with_metadata_change("a test change", {
    m <- load_zentra_metadata()
    m$device_name[m$unique_id == "t-0004"] <- "renamed halfway"
    save_device_metadata(m)
    list(success = FALSE, error = "no")
  })
  expect_false(res$success)
  expect_equal(load_zentra_metadata(), before)
})

test_that("a maintenance entry with an action type not on the list is a problem", {
  local_test_root()
  expect_false("UNKNOWN_ACTION_TYPE" %in% names(validate_metadata(verbose = FALSE)$violations))
  log <- read_table("maintenance_log")
  log$action_type[1] <- "elevation_survey"          # an old name a migration missed
  write_table("maintenance_log", log, guard = FALSE)
  v <- validate_metadata(verbose = FALSE)
  expect_true("UNKNOWN_ACTION_TYPE" %in% names(v$violations))
  expect_match(v$violations$UNKNOWN_ACTION_TYPE$description, "elevation_survey")
})

test_that("a refused save is reported as a failure, never as done", {
  local_test_root()
  before <- readLines(table_path("device_metadata"))
  # A latitude off the planet: validation refuses the save, and the caller -
  # which once ignored the refusal and said "done" - says it failed
  utils::capture.output(res <- update_device_location("z6-38175", 500, -64.8, NA))
  expect_false(isTRUE(res))
  expect_match(res, "was not saved")
  expect_identical(readLines(table_path("device_metadata")), before)
})

test_that("a field time can be typed without seconds", {
  out <- with_inputs("2026-11-03 14:30", ui_prompt_datetime("When?", allow_now = TRUE))
  expect_equal(format(out$value, "%Y-%m-%d %H:%M:%S"), "2026-11-03 14:30:00")
})
