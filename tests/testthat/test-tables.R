################################################################################
# The data layer: read_table(), write_table(), append_rows()
#
# The layer is the one way into and out of the metadata, so what is tested
# here is what every table relies on: values survive a read and a write, the
# file is always written the one way, and a write that would lose something is
# refused rather than made.
################################################################################

test_that("every fixture table keeps its values through the layer, then its bytes", {
  local_test_root()
  for (name in c("device_metadata", "download_log", "maintenance_log", "zentra_ports")) {
    first <- table_round_trip(name)
    expect_true(first$values_identical, info = paste(name, first$differences, collapse = "; "))

    # Written once through the layer, the file is in its final form: a second
    # round trip must reproduce it byte for byte
    write_table(name, read_table(name))
    second <- table_round_trip(name)
    expect_true(second$values_identical, info = name)
    expect_true(second$bytes_identical, info = name)
  }
})

test_that("a table is written the one way", {
  local_test_root()
  rows <- data.frame(
    run_id = "r1", started_utc = as.POSIXct("2026-11-20 13:00:00", tz = "UTC"),
    finished_utc = NA, job = "zentra_download", devices_seen = 3,
    devices_fetched = 2, devices_up_to_date = 1, devices_errored = 0,
    rows_fetched = 100000, status = "ok", message = 'said "hello", twice',
    machine = NA, stringsAsFactors = FALSE)
  write_table("run_log", rows)
  bytes <- readBin(table_path("run_log"), "raw", 10000)
  text <- rawToChar(bytes)

  expect_false(grepl("\r", text, fixed = TRUE))                 # Unix line endings
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  expect_equal(lines[2], paste0(
    '"r1","2026-11-20 13:00:00",,"zentra_download",3,2,1,0,100000,"ok",',
    '"said ""hello"", twice",'))
  # missing is empty, never NA; a big number is not 1e+05; quotes are doubled
  expect_false(grepl("NA", lines[2], fixed = TRUE))
})

test_that("a header that does not match the schema is refused on reading", {
  local_test_root()
  p <- table_path("record_confirmed")
  writeLines(c('"station_id","reason"', '"(default)","x"'), p)
  expect_error(read_table("record_confirmed"), "does not have the columns")
})

test_that("a value that is not its column's type is refused, naming the row", {
  local_test_root()
  p <- table_path("device_metadata")
  lines <- readLines(p)
  # An epoch where a datetime belongs - what a bare POSIXct assignment once wrote
  lines[2] <- sub('"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}"', '"1791468900"', lines[2])
  writeLines(lines, p)
  expect_error(read_table("device_metadata"), "row 2")
})

test_that("a write with a column the table lacks, or without one it has, is refused", {
  local_test_root()
  x <- read_table("zentra_ports")
  expect_error(write_table("zentra_ports", cbind(x, extra = 1)), "Not a column")
  expect_error(write_table("zentra_ports", x[, -1]), "missing column")
})

test_that("columns may arrive in any order and are written in schema order", {
  local_test_root()
  x <- read_table("zentra_ports")
  write_table("zentra_ports", x[, rev(names(x))])
  expect_identical(names(read_table("zentra_ports")), names(TABLE_SCHEMA$zentra_ports$columns))
})

test_that("append_rows puts each value under its own column, by name", {
  local_test_root()
  before <- read_table("download_log")
  append_rows("download_log", data.frame(
    filepath = "internal/device-data/zentra/x_raw.rds", device_serial = "z6-1",
    n_records = 5, stringsAsFactors = FALSE))
  after <- read_table("download_log")
  expect_equal(nrow(after), nrow(before) + 1)
  last <- after[nrow(after), ]
  expect_equal(last$filepath, "internal/device-data/zentra/x_raw.rds")
  expect_equal(last$device_serial, "z6-1")
  expect_true(is.na(last$run_id))
  expect_error(append_rows("download_log", data.frame(nope = 1)), "Not a column")
})

test_that("append_rows does not glue a row onto a file missing its final newline", {
  local_test_root()
  p <- table_path("download_log")
  text <- rawToChar(readBin(p, "raw", file.size(p)))
  con <- file(p, "wb"); writeBin(charToRaw(sub("\n+$", "", text)), con); close(con)
  n <- nrow(read_table("download_log"))
  append_rows("download_log", data.frame(filepath = "y_raw.rds", stringsAsFactors = FALSE))
  expect_equal(nrow(read_table("download_log")), n + 1)
})

test_that("a write is refused if the file changed since it was read", {
  local_test_root()
  x <- read_table("zentra_ports")
  p <- table_path("zentra_ports")
  cat('"z6-9",1,"vwc","TEROS 10",10,,"2026-01-01 00:00:00",\n', file = p, append = TRUE)
  changed <- unname(tools::md5sum(p))
  out <- capture.output(res <- write_table("zentra_ports", x))
  expect_false(res)
  expect_identical(unname(tools::md5sum(p)), changed)            # nothing written
})

test_that("every table is backed up before it is replaced - logs too", {
  local_test_root()
  write_table("download_log", read_table("download_log"))
  backups <- list.files(file.path(wds("meta_internal"), "backups"), pattern = "^download_log_")
  expect_length(backups, 1)
  # Unchanged since that backup: no second copy
  write_table("download_log", read_table("download_log"))
  first <- list.files(file.path(wds("meta_internal"), "backups"), pattern = "^download_log_")
  expect_length(first, 2)    # the normalized file differs from the original once
  write_table("download_log", read_table("download_log"))
  expect_length(list.files(file.path(wds("meta_internal"), "backups"), pattern = "^download_log_"), 2)
})

test_that("a write leaves no temporary file behind", {
  local_test_root()
  write_table("zentra_ports", read_table("zentra_ports"))
  expect_length(list.files(wds("meta_internal"), pattern = "\\.partial$"), 0)
})

test_that("a missing table reads as empty, with the schema's columns", {
  local_test_root()
  x <- read_table("record_confirmed")
  expect_equal(nrow(x), 0)
  expect_identical(names(x), names(TABLE_SCHEMA$record_confirmed$columns))
})

test_that("the loaders read through the layer", {
  local_test_root()
  # The download log no longer grows a stray `timestamp` column - partial
  # matching once handed it timestamp_utc, parsed as local time
  expect_false("timestamp" %in% names(load_download_log()))
  expect_type(load_download_log()$timestamp_utc, "character")

  # Counts are whole numbers, as they always were
  expect_type(load_zentra_ports_data()$port, "integer")
  expect_type(load_zentra_metadata()$interval_min, "integer")

  # A value the layer cannot read stops the loader, rather than becoming NA
  p <- table_path("zentra_ports")
  lines <- readLines(p)
  lines[2] <- sub('"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}"', '"not a date"', lines[2])
  writeLines(lines, p)
  expect_error(load_zentra_ports_data(), "not a datetime_local")
})

test_that("pending ingest reads as text, missing as empty, with or without rows", {
  local_test_root()
  empty <- load_pending_ingest()
  expect_equal(nrow(empty), 0)
  expect_true(all(vapply(empty, is.character, logical(1))))
  expect_true(file.exists(table_path("pending_ingest")))
})

test_that("record_confirmed is seeded with its default when absent", {
  local_test_root()
  rc <- load_record_confirmed()
  expect_equal(rc$station_id, "(default)")
  expect_equal(rc$confirmed_from, RECORD_CONFIRMED_DEFAULT)
  expect_equal(record_confirmed_from("anything"), as.Date(RECORD_CONFIRMED_DEFAULT))
})
