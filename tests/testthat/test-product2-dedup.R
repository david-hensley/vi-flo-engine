# Product 2, piece 2: one reading per device, port, measurement and moment.
# Where downloads overlap, the later fetch wins and a disagreement is marked.

VWC_A <- "z6-38175_20261001_20261001_20261001T171036_raw.rds"   # fetched 17:10:36
VWC_B <- "z6-38175_20261001_20261001_20261001T171457_raw.rds"   # fetched 17:14:57
U20   <- "21652379_20260828_20260902_raw.rds"

#### Fetch times ####

test_that("fetch times come from the log, including for a manual offload with no run_id", {
  local_test_root()
  t <- p1_fetch_times(c(VWC_A, U20))
  expect_equal(format(t, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               c("2026-10-01 17:10:36", "2026-09-02 21:11:50"))
})

test_that("a file the log does not know stops the build", {
  local_test_root()
  expect_error(p1_fetch_times("90000001_20260101_20260102_raw.rds"), "Not in the download log")
})

#### The real duplicate pair ####

test_that("z6-38175's two fetches collapse to one copy, with no conflict", {
  local_test_root()
  paths <- place_p1(c(VWC_A, VWC_B))
  one <- read_p1_set(paths[1])
  both <- read_p1_set(paths)

  expect_equal(nrow(both), nrow(one))
  expect_false(any(both$conflict))
  expect_true(all(both$source_file == VWC_B))         # the later fetch is kept
  d <- attr(both, "dedup")
  expect_equal(unname(d["removed"]), nrow(one))
  expect_equal(unname(d["conflicts"]), 0)
})

test_that("the later fetch wins whichever order the files are given in", {
  local_test_root()
  paths <- place_p1(c(VWC_A, VWC_B))
  expect_identical(read_p1_set(rev(paths))$source_file, read_p1_set(paths)$source_file)
})

#### Disagreement ####

test_that("where an earlier fetch disagrees, the later value is kept and marked", {
  local_test_root()
  paths <- place_p1(c(VWC_A, VWC_B))

  # The earlier fetch records a different water content at one moment
  x <- readRDS(paths[1])
  hit <- which(x$measurement == "Water Content" & x$port_num == 1)[1]
  later_value <- x$value[hit]
  x$value[hit] <- x$value[hit] + 0.05
  saveRDS(x, paths[1])

  out <- read_p1_set(paths)
  marked <- out[out$conflict, ]
  expect_equal(nrow(marked), 1)
  expect_equal(marked$value, later_value)
  expect_equal(marked$source_file, VWC_B)
  expect_equal(unname(attr(out, "dedup")["conflicts"]), 1)
})

test_that("a value in one copy and nothing in the other is a disagreement", {
  r <- data.frame(device_serial = "x", port = 1L, sensor = "TEROS 10",
                  measurement = "Water Content",
                  datetime = as.POSIXct(c("2026-10-01 12:00", "2026-10-01 12:00"), tz = "UTC"),
                  value = c(0.3, NA), source_file = c("a", "b"), stringsAsFactors = FALSE)
  out <- dedupe_readings(r, as.POSIXct(c("2026-10-01 13:00", "2026-10-01 14:00"), tz = "UTC"))
  expect_equal(nrow(out), 1)
  expect_true(is.na(out$value))
  expect_true(out$conflict)
})

test_that("two empty copies agree", {
  r <- data.frame(device_serial = "x", port = 1L, sensor = "TEROS 10",
                  measurement = "Water Content",
                  datetime = as.POSIXct(c("2026-10-01 12:00", "2026-10-01 12:00"), tz = "UTC"),
                  value = c(NA, NA), source_file = c("a", "b"), stringsAsFactors = FALSE)
  out <- dedupe_readings(r, as.POSIXct(c("2026-10-01 13:00", "2026-10-01 14:00"), tz = "UTC"))
  expect_false(out$conflict)
})

test_that("the same moment on two ports is two readings, not a duplicate", {
  local_test_root()
  out <- read_p1_set(place_p1(VWC_A))
  wc <- out[out$variable == "vwc", ]
  expect_true(length(unique(wc$port)) > 1)
  expect_equal(sum(duplicated(wc[, c("port", "datetime")])), 0)
})

test_that("a file that cannot be mapped is named in the error", {
  local_test_root()
  path <- place_p1(U20)
  x <- readRDS(path)
  pc <- grep("^Abs Pres", names(x))
  names(x)[pc] <- sub("kPa", "bar", names(x)[pc])
  saveRDS(x, path)
  expect_error(read_p1_set(path), U20, fixed = TRUE)
})

test_that("a HOBO file reads, maps and deduplicates through the same path", {
  local_test_root()
  out <- read_p1_set(place_p1(U20))
  expect_equal(nrow(out), 2 * 502)
  expect_equal(unname(attr(out, "dedup")["removed"]), 0)
})

#### Repeats: a logger writing two records with one timestamp ####

repeat_case <- function(values, files, kinds = "instantaneous", fetched = NULL) {
  n <- length(values)
  r <- data.frame(device_serial = "z6-14635", port = 1L, sensor = "ATMOS 41",
                  measurement = "Air Temperature", variable = "temp",
                  kind = rep(kinds, length.out = n),
                  datetime = rep(as.POSIXct("2022-09-29 04:15", tz = "UTC"), n),
                  value = values, source_file = files, stringsAsFactors = FALSE)
  if (is.null(fetched)) fetched <- rep(as.POSIXct("2026-09-14", tz = "UTC"), n)
  dedupe_readings(r, fetched)
}

test_that("a repeat within one file keeps the first record, the scheduled one", {
  out <- repeat_case(c(23.8, 23.9), c("export", "export"))
  expect_equal(nrow(out), 1)
  expect_equal(out$value, 23.8)
})

test_that("a repeat within one file is counted, and is not a conflict", {
  out <- repeat_case(c(23.8, 23.9), c("export", "export"))
  expect_false(out$conflict)
  expect_equal(out$repeats, 1L)
  expect_equal(unname(attr(out, "dedup")["repeats"]), 1)
  expect_equal(unname(attr(out, "dedup")["conflicts"]), 0)
})

test_that("rain in a repeat is recorded as dropped, never added in", {
  out <- repeat_case(c(0, 0.97), c("export", "export"), kinds = "accumulated")
  expect_equal(out$value, 0)
  expect_equal(out$repeat_dropped, 0.97)
  inst <- repeat_case(c(23.8, 23.9), c("export", "export"))
  expect_equal(inst$repeat_dropped, 0)
})

test_that("two downloads disagreeing is still a conflict, and the later still wins", {
  out <- repeat_case(c(23.8, 24.4), c("earlier", "later"),
                     fetched = as.POSIXct(c("2026-09-14", "2026-10-01"), tz = "UTC"))
  expect_true(out$conflict)
  expect_equal(out$value, 24.4)
  expect_equal(out$repeats, 0L)
})

test_that("a repeat in one download and a disagreeing later download: both counted", {
  out <- repeat_case(c(23.8, 23.9, 24.4), c("export", "export", "api"),
                     fetched = as.POSIXct(c("2026-09-14", "2026-09-14", "2026-10-01"), tz = "UTC"))
  expect_equal(out$value, 24.4)                  # the later download
  expect_true(out$conflict)                      # it disagrees with the export's own first record
  expect_equal(out$repeats, 1L)
})

test_that("a later download agreeing with a file's first record is no conflict, even with a repeat", {
  out <- repeat_case(c(23.8, 23.9, 23.8), c("export", "export", "api"),
                     fetched = as.POSIXct(c("2026-09-14", "2026-09-14", "2026-10-01"), tz = "UTC"))
  expect_false(out$conflict)
  expect_equal(out$repeats, 1L)
})

test_that("a real repeated record builds as a repeat, not a conflict, with the first kept", {
  local_test_root()
  path <- place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  x <- readRDS(path)
  # The logger writes a second 12:45 record for every port: a repeat
  extra <- x[x$datetime == as.POSIXct("2026-09-28 12:45:00", tz = "UTC"), ]
  extra$value <- extra$value + 0.1
  saveRDS(rbind(x, extra), path)
  out <- build_p2("zzu_weather", 2026, quiet = TRUE)
  expect_true(all(out$conflicts == "0"))
  expect_true(all(as.integer(out$repeats) >= 1))
  t <- read_p2_file(product_path(2, "zzu_weather", "temp", 2026))
  first <- x$value[x$measurement == "Air Temperature" &
                   x$datetime == as.POSIXct("2026-09-28 12:45:00", tz = "UTC")]
  expect_equal(t$value[format(t$datetime, "%H:%M") == "08:45"], first)
})
