# Log rows land under their own columns. The HOBO ingest wrote its
# download-log row by position, without run_id and device_serial, so every
# value after the station slid two columns left - the October 2026 offloads
# were never seen as logged, and Product 2 skipped them.

dl_path <- function() file.path(wds("meta_internal"), "download_log.csv")

test_that("a HOBO ingest logs its file under the right columns", {
  local_test_root()
  csv <- tempfile(fileext = ".csv"); writeLines("x", csv)
  parsed <- list(data = data.frame(a = 1),
                 start = as.POSIXct("2026-03-23 14:20:51", tz = "America/Puerto_Rico"),
                 end   = as.POSIXct("2026-10-27 16:35:51", tz = "America/Puerto_Rico"),
                 n_records = 20938)
  name <- "21652379_20260323_20261027_raw.rds"
  r <- archive_local_data("zzb_hydro", "21652379", csv, parsed, name, wds("device_hobo"))
  expect_true(isTRUE(r$success))

  raw <- utils::read.csv(dl_path(), stringsAsFactors = FALSE, colClasses = "character")
  last <- raw[nrow(raw), ]
  expect_equal(last$device_serial, "21652379")
  expect_equal(last$station, "zzb_hydro")
  expect_equal(basename(last$filepath), name)
  expect_equal(last$download_type, "manual")
  expect_equal(last$n_records, "20938")
  expect_equal(length(strsplit(readLines(dl_path())[nrow(raw) + 1], ",")[[1]]),
               ncol(raw))                                    # nine fields, as the header
  # And so the build sees it as part of the archive
  expect_true(name %in% basename(load_download_log()$filepath))
})

test_that("append_log_row puts each value under its column, whatever its order", {
  local_test_root()
  entry <- data.frame(download_type = "manual", filepath = "internal/x.rds",
                      device_serial = "90000001", timestamp_utc = "2026-11-03 12:00:00",
                      stringsAsFactors = FALSE)
  append_log_row(entry, dl_path())
  raw <- utils::read.csv(dl_path(), stringsAsFactors = FALSE, colClasses = "character",
                         na.strings = c("", "NA"))          # missing is written empty
  last <- raw[nrow(raw), ]
  expect_equal(last$device_serial, "90000001")
  expect_equal(last$filepath, "internal/x.rds")
  expect_true(is.na(last$station))                          # a column it did not have
})

test_that("append_log_row refuses a column the file does not have", {
  local_test_root()
  before <- readLines(dl_path())
  expect_error(append_log_row(data.frame(timestamp_utc = "x", nonsense = 1), dl_path()),
               "Not a column of download_log.csv: nonsense")
  expect_identical(readLines(dl_path()), before)
})

test_that("a quote in a maintenance note is doubled, and the row keeps its columns", {
  local_test_root()
  note <- 'in "device tools", set battery type'
  utils::capture.output(create_maintenance_entry(
    field_visit_date = "2026-10-26", station_id = "bta2_hydro",
    device_serial = "90000002", action_type = "maintenance", details = note,
    logged_by = "DAH"))
  log <- read_log()
  expect_equal(log$details[nrow(log)], note)
  expect_equal(log$unique_id[nrow(log)], "t-0002")      # the deployment, found by serial
})

test_that("nothing is appended to a log whose columns are not the schema's", {
  local_test_root()
  p <- dl_path()
  lines <- readLines(p)
  lines[1] <- sub('"station",', "", lines[1])               # a log one column short
  writeLines(lines, p)
  before <- readLines(p)
  expect_error(append_log_row(data.frame(filepath = "x_raw.rds"), p),
               "does not have the columns its schema expects")
  expect_identical(readLines(p), before)
})

test_that("the job's download and run rows go through the data layer", {
  local_test_root()
  at <- as.POSIXct("2026-11-20 17:00:00", tz = "UTC")
  zentra_log_download("z6-1", as.POSIXct("2026-11-13 10:30:00", tz = "America/Puerto_Rico"),
                      as.POSIXct("2026-11-20 09:15:00", tz = "America/Puerto_Rico"),
                      100000, "z6-1_20261113_20261120_20261120T170000_raw.rds", at, "r1")
  last <- tail(load_download_log(), 1)
  expect_equal(last$timestamp_utc, "2026-11-20 17:00:00")
  expect_equal(format(last$end_date, "%Y-%m-%d %H:%M"), "2026-11-20 09:15")
  expect_equal(last$n_records, 100000L)
  expect_false(grepl("e+05", tail(readLines(dl_path()), 1), fixed = TRUE))

  zentra_log_run("r1", at, at + 30, 3, 2, 1, 0, 100, "ok")
  run <- read_table("run_log")
  expect_equal(run$run_id, "r1")
  expect_equal(run$devices_seen, 3L)
  expect_true(is.na(run$message))
})
