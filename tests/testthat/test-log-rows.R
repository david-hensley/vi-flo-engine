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
  expect_equal(basename(last$filepath), name)
  expect_equal(last$download_type, "manual")
  expect_equal(last$n_records, "20938")
  line <- readLines(dl_path())[nrow(raw) + 1]
  expect_equal(lengths(regmatches(line, gregexpr(",", line))) + 1,
               ncol(raw))                                    # as many fields as the header
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
  expect_true(is.na(last$run_id))                           # a column it did not have
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
  lines[1] <- sub('"run_id",', "", lines[1])                # a log one column short
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
                      100000, "z6-1_20261113_20261120_20261120T170000_raw.rds", at, "r1",
                      battery = 87)
  last <- tail(load_download_log(), 1)
  expect_equal(last$timestamp_utc, "2026-11-20 17:00:00")
  expect_equal(format(last$end_date, "%Y-%m-%d %H:%M"), "2026-11-20 09:15")
  expect_equal(last$n_records, 100000L)
  expect_equal(last$battery, 87)                           # the battery rides on its download
  expect_false(grepl("e+05", tail(readLines(dl_path()), 1), fixed = TRUE))

  zentra_log_run("r1", at, at + 30, 3, 2, 1, 0, 100, "ok")
  run <- read_table("run_log")
  expect_equal(run$run_id, "r1")
  expect_equal(run$devices_seen, 3L)
  expect_true(is.na(run$message))
})

test_that("an offload already archived is never overwritten, nor logged twice", {
  local_test_root()
  data <- data.frame(`Date Time, GMT-04:00` = c("03/23/26 10:00:00 AM", "03/23/26 10:15:00 AM"),
                     `Abs Pres, kPa (LGR S/N: 21652379)` = c(101.2, 101.3), check.names = FALSE)
  parsed <- list(data = data,
                 start = as.POSIXct("2026-03-23 10:00:00", tz = PROJECT_TZ),
                 end   = as.POSIXct("2026-03-23 10:15:00", tz = PROJECT_TZ), n_records = 2)
  name <- "21652379_20260323_20260323_raw.rds"
  csv <- function() { f <- tempfile(fileext = ".csv"); writeLines("x", f); f }
  n_logged <- function() sum(basename(load_download_log()$filepath) == name)

  expect_true(archive_local_data("zzb_hydro", "21652379", csv(), parsed, name, wds("device_hobo"))$success)
  expect_equal(n_logged(), 1)

  # The same readings again: already archived, not logged a second time
  r <- archive_local_data("zzb_hydro", "21652379", csv(), parsed, name, wds("device_hobo"))
  expect_true(r$success)
  expect_true(any(grepl("Already archived", r$messages)))
  expect_equal(n_logged(), 1)

  # Different readings under the same name: refused, the archived file untouched
  before <- readRDS(file.path(wds("device_hobo"), name))
  other <- parsed; other$data[[2]] <- c(99, 99)
  r <- archive_local_data("zzb_hydro", "21652379", csv(), other, name, wds("device_hobo"))
  expect_false(r$success)
  expect_match(r$message, "already archived, with different readings")
  expect_identical(readRDS(file.path(wds("device_hobo"), name)), before)
})

test_that("a path is made relative to the data root as text, not as a pattern", {
  expect_equal(path_relative_to(c("C:\\Data (1)\\a\\b.rds", "C:/Data (1)/c.rds", "/elsewhere/z"),
                                "C:/Data (1)/"),
               c("a/b.rds", "c.rds", "/elsewhere/z"))
})

test_that("a HOBO export is read in the zone it declares", {
  expect_equal(hobo_declared_tz("Date Time, GMT-04:00"), "Etc/GMT+4")
  expect_equal(hobo_declared_tz("Date Time, GMT+01:00"), "Etc/GMT-1")
  expect_true(is.na(hobo_declared_tz("Date Time")))
  f <- tempfile(fileext = ".csv")
  writeLines(c('"Plot Title: test"',
               '"#","Date Time, GMT-05:00","Abs Pres, kPa (LGR S/N: 21652379)"',
               '1,03/23/26 10:00:00 AM,101.2', '2,03/23/26 10:15:00 AM,101.3',
               '3,03/23/26 10:30:00 AM,101.4'), f)
  p <- read_exported_csv(f, expected_serial = "21652379")
  # 10:00 at GMT-05:00 is 11:00 in the project's zone, GMT-04:00
  expect_equal(format(p$start, "%Y-%m-%d %H:%M", tz = PROJECT_TZ), "2026-03-23 11:00")
})

test_that("no test can reach the elevation services", {
  expect_null(fetch_url_text("https://epqs.nationalmap.gov/v1/json"))
})
