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

test_that("every table is backed up before it is replaced - logs too - once a session", {
  local_test_root()
  rm(list = ls(.table_backups), envir = .table_backups)     # a fresh session
  dir <- file.path(wds("meta_internal"), "backups")
  original <- unname(tools::md5sum(table_path("download_log")))

  write_table("download_log", read_table("download_log"))
  backups <- list.files(dir, pattern = "^download_log_", full.names = TRUE)
  expect_length(backups, 1)
  expect_identical(unname(tools::md5sum(backups)), original)  # the table as it was

  # Later writes in the same session add nothing: the copy from before the
  # session touched the table is the one worth keeping
  x <- read_table("download_log")
  x$n_records[1] <- x$n_records[1] + 1L
  write_table("download_log", x)
  expect_length(list.files(dir, pattern = "^download_log_"), 1)

  # A new session backs up again - but not if nothing changed since the last copy
  rm(list = ls(.table_backups), envir = .table_backups)
  write_table("download_log", read_table("download_log"))
  expect_length(list.files(dir, pattern = "^download_log_"), 2)
  rm(list = ls(.table_backups), envir = .table_backups)
  write_table("download_log", read_table("download_log"))
  expect_length(list.files(dir, pattern = "^download_log_"), 2)
})

test_that("save_device_metadata writes through the layer, from POSIXct or text alike", {
  local_test_root()
  x <- load_zentra_metadata()
  x$deploy_datetime <- format_datetime_safe(x$deploy_datetime)    # as some callers do
  x$last_visit <- as.character(x$last_visit)
  x$elev[1] <- "41.96"                                           # a number typed as text
  expect_true(save_device_metadata(x))
  y <- load_zentra_metadata()
  expect_equal(y$elev[1], 41.96)
  expect_s3_class(y$deploy_datetime, "POSIXct")
  expect_true(table_round_trip("device_metadata")$bytes_identical)

  x <- load_zentra_metadata()
  x$elev[1] <- "high"
  expect_error(save_device_metadata(x), "Not a number")
  expect_error(save_device_metadata(cbind(x, scratch = 1)), "Not a column")
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

test_that("nothing but the data layer opens a metadata table", {
  engine <- Sys.getenv("VI_FLO_ENGINE_ROOT")
  files <- c(list.files(file.path(engine, "code", "functions"), pattern = "\\.R$", full.names = TRUE),
             list.files(file.path(engine, "code", "jobs"), pattern = "\\.R$", full.names = TRUE))
  code_lines <- function(f) {
    x <- readLines(f, warn = FALSE)
    data.frame(file = basename(f), line = seq_along(x),
               text = sub("#.*$", "", x),              # comments may name anything
               stringsAsFactors = FALSE)
  }
  code <- do.call(rbind, lapply(files, code_lines))

  # 1. A table's file name is written once, in TABLE_SCHEMA. Anywhere else, a
  #    path is being built by hand - the way a port deletion once went to the
  #    working directory instead of the metadata folder
  names_re <- paste0("\"(", paste(gsub(".", "\\.", vapply(TABLE_SCHEMA, `[[`, "", "file"),
                                       fixed = TRUE), collapse = "|"), ")\"")
  hits <- code[grepl(names_re, code$text) & code$file != "table_functions.R", ]
  expect_equal(nrow(hits), 0,
               info = paste(paste0(hits$file, ":", hits$line), collapse = ", "))

  # 2. Reading and writing CSV directly is for files that are not metadata
  #    tables: the products and their manifest, the datamap, logger and survey
  #    exports, and the guard's own snapshot of a table it remembers. A new
  #    file here is a new way into the metadata until shown otherwise
  allowed <- c("table_functions.R", "guard_functions.R", "product2_functions.R",
               "setup_functions.R", "local_ingest_functions.R", "survey_functions.R")
  csv <- code[grepl("\\b(read\\.csv|write\\.csv|write\\.table|read\\.table)\\(", code$text) &
                !code$file %in% allowed, ]
  expect_equal(nrow(csv), 0,
               info = paste(paste0(csv$file, ":", csv$line), collapse = ", "))
})

test_that("deleting a row deletes its own ports, and only those", {
  local_test_root()
  # z6-13368 serves two stations in the fixture: its ATMOS port is zzu_weather's
  # (t-0009), its TEROS ports zzu_vwc1's (t-0010). Deleting the vwc row takes
  # the vwc ports with it and leaves the weather station's
  run <- with_inputs(c("t-0010", "Y", "Y"), ui_delete_metadata_row())
  expect_false("t-0010" %in% load_zentra_metadata()$unique_id)
  p <- load_zentra_ports_data()
  expect_false("t-0010" %in% p$unique_id)
  expect_equal(p$sensor[p$unique_id == "t-0009"], "ATMOS 41")
})

test_that("deleting a logger's only row deletes its ports from the real port table", {
  local_test_root()
  # z6-38175 is on one row only, t-0011
  run <- with_inputs(c("t-0011", "Y", "Y"), ui_delete_metadata_row())
  expect_false("z6-38175" %in% load_zentra_ports_data()$sn)
  expect_true("z6-13368" %in% load_zentra_ports_data()$sn)
  expect_false(file.exists(file.path(getwd(), "zentra_ports.csv")))
})

test_that("validate_metadata runs to the end when logged files are missing", {
  local_test_root()
  # The fixture's download log names Product 1 files the test root does not
  # hold. Listing them once selected a `timestamp` column the log never had -
  # it existed only through a partial-matching accident in the old loader
  out <- capture.output(v <- validate_metadata(verbose = TRUE))
  expect_type(v, "list")
})

test_that("a pending offload names its deployment, and is found again by logger", {
  local_test_root()
  add_pending_ingest("bta2_hydro", "90000002", "2026-11-20", "DAH", "awaiting_offload", "note")
  p <- load_pending_ingest()
  expect_equal(p$unique_id, "t-0002")
  expect_match(p$created_utc, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}$")

  expect_true(update_pending_stage("bta2_hydro", "90000002", "awaiting_rename"))
  expect_equal(load_pending_ingest()$stage, "awaiting_rename")
  # The same logger at another station is another task
  expect_false(update_pending_stage("rb2_hydro", "90000002", "awaiting_rename"))

  expect_true(clear_pending_ingest("bta2_hydro", "90000002"))
  expect_equal(nrow(load_pending_ingest()), 0)
  expect_error(add_pending_ingest("srl1_pond", "90000002", "2026-11-20", "DAH",
                                  "awaiting_offload"), "has no row at")
})
