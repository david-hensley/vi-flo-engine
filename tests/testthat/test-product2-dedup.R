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

test_that("a HOBO file reads, maps and deduplicates through the same path", {
  local_test_root()
  out <- read_p1_set(place_p1(U20))
  expect_equal(nrow(out), 2 * 502)
  expect_equal(unname(attr(out, "dedup")["removed"]), 0)
})
