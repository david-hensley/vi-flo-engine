# Product 2, piece 3: attribution to stations, and the 15-minute grid.
#
# Fixture stations for the real loggers: zzu_weather and zzu_vwc1 share the
# UVI ZL6 (ATMOS on port 1, TEROS on 2-6 at 10, 20, 30, 50 and 100 cm),
# zzv_vwc1 has the vwc-only ZL6, zzb_hydro bta2b's U20, zzs_hydro SR1's
# HOBOlink logger. The export-shaped z6-30133 has no deployment at all.

U20      <- "21652379_20260828_20260902_raw.rds"
UVI      <- "z6-13368_20260928_20260928_20260928T134705_raw.rds"
VWC      <- "z6-38175_20261001_20261001_20261001T171457_raw.rds"
EXPORT   <- "z6-30133_20241212_20241212_20260914T000000_raw.rds"
HOBOLINK <- "21180078_20230802_20230803_raw.rds"

attributed <- function(files) attribute_readings(read_p1_set(place_p1(files)))
utc <- function(x) as.POSIXct(x, tz = "UTC")

#### Attribution ####

test_that("a co-located ZL6 splits by port: ATMOS to weather, TEROS to vwc with depths", {
  local_test_root()
  a <- attributed(UVI)
  w <- unique(a$variable[a$station_id == "zzu_weather"])
  v <- unique(a$variable[a$station_id == "zzu_vwc1"])
  expect_true(all(c("temp", "precip", "pressure") %in% w))
  expect_false(any(grepl("^vwc", w)))
  expect_setequal(v, c("vwc_10cm", "vwc_20cm", "vwc_30cm", "vwc_50cm", "vwc_100cm"))
})

test_that("the logger's own barometer goes to the weather station only, where there is one", {
  local_test_root()
  a <- attributed(UVI)
  expect_equal(unique(a$station_id[a$variable == "logger_pressure"]), "zzu_weather")
})

test_that("on a vwc-only logger the barometer goes to its one station", {
  local_test_root()
  a <- attributed(VWC)
  expect_equal(unique(a$station_id[a$variable == "logger_pressure"]), "zzv_vwc1")
})

test_that("readings from a logger with no deployment are reported, not forced onto a station", {
  local_test_root()
  a <- attributed(EXPORT)
  expect_equal(nrow(a), 0)
  u <- attr(a, "unattributed")
  expect_equal(unique(u$device_serial), "z6-30133")
  expect_equal(sum(u$rows), 3)
})

test_that("a HOBO is attributed by device and moment", {
  local_test_root()
  a <- attributed(c(U20, HOBOLINK))
  expect_setequal(unique(a$station_id), c("zzb_hydro", "zzs_hydro"))
  expect_equal(nrow(attr(a, "unattributed")), 0)
})

#### The grid: real loggers ####

test_that("the U20's :08:37 readings are interpolated onto the quarter hour", {
  local_test_root()
  p <- assemble_p2(attributed(U20))
  s <- p[["zzb_hydro|abs_pressure|2026"]]$series
  # First reading 10:08:37 AST is 14:08:37 UTC; the first quarter hour after it is 14:15
  expect_equal(s$datetime[1], utc("2026-08-28 14:15:00"))
  expect_true(all(as.numeric(s$datetime) %% 900 == 0))
  expect_true(all(s$flag == "observed"))

  # Checked by hand against the two readings either side
  raw <- read_p1_long(fixture_path("p1", U20))
  pr <- raw[raw$measurement == "Abs Pres", ]
  t0 <- as.numeric(pr$datetime[1]); t1 <- as.numeric(pr$datetime[2])
  expected <- pr$value[1] + (pr$value[2] - pr$value[1]) * (as.numeric(utc("2026-08-28 14:15:00")) - t0) / (t1 - t0)
  expect_equal(s$value[1], expected)
  expect_equal(p[["zzb_hydro|abs_pressure|2026"]]$methods[["21652379"]], "interpolated to the quarter hour")
})

test_that("HOBOlink's 5-minute readings keep the one on each quarter hour", {
  local_test_root()
  p <- assemble_p2(attributed(HOBOLINK))
  s <- p[["zzs_hydro|abs_pressure|2023"]]$series
  raw <- read_p1_long(fixture_path("p1", HOBOLINK))
  raw <- raw[raw$measurement == "water_pressure_kpa", ]
  at <- match(as.numeric(s$datetime), as.numeric(raw$datetime))
  expect_true(all(!is.na(at)))
  expect_equal(s$value, raw$value[at])
  expect_true(all(as.numeric(s$datetime) %% 900 == 0))
})

test_that("error-coded readings are missing with the device still named", {
  local_test_root()
  p <- assemble_p2(attributed(UVI))
  s <- p[["zzu_vwc1|vwc_10cm|2026"]]$series     # port 2: three error-coded readings
  expect_true(all(s$flag == "missing"))
  expect_true(all(s$device_serial == "z6-13368"))
  ok <- p[["zzu_vwc1|vwc_20cm|2026"]]$series
  expect_true(all(ok$flag == "observed"))
})

test_that("a gap in the readings becomes rows flagged missing, with no device", {
  local_test_root()
  paths <- place_p1(U20)
  x <- readRDS(paths); x <- x[-(100:111), ]; saveRDS(x, paths)
  s <- assemble_p2(attribute_readings(read_p1_set(paths)))[["zzb_hydro|abs_pressure|2026"]]$series
  gap <- s[s$flag == "missing", ]
  expect_true(nrow(gap) >= 10)
  expect_true(all(is.na(gap$device_serial)))
  expect_true(all(is.na(gap$value)))
  expect_equal(nrow(s), length(seq(min(s$datetime), max(s$datetime), by = 900)))
})

#### The grid: the rules, on constructed series ####

series_of <- function(minutes, values, kind, start = "2026-10-01 12:00:00") {
  t <- utc(start) + minutes * 60
  align_to_grid(t, values, kind, rep("f", length(t)), rep(FALSE, length(t)))
}

test_that("5-minute rain is summed into the quarter hour it ends in, only when complete", {
  a <- series_of(c(5, 10, 15, 20, 25, 30), c(0.2, 0.4, 0.6, 1, 1, 1), "accumulated")
  expect_equal(a$rows$value, c(1.2, 3))
  b <- series_of(c(5, 10, 15, 20, 30), c(0.2, 0.4, 0.6, 1, 1), "accumulated")
  expect_true(is.na(b$rows$value[2]))           # 12:25 missing: no partial sum
  expect_true(b$rows$recorded[2])
})

test_that("5-minute gusts take the highest, and minima the lowest", {
  expect_equal(series_of(c(5, 10, 15), c(3, 7, 5), "maximum")$rows$value, 7)
  expect_equal(series_of(c(5, 10, 15), c(3, 7, 5), "minimum")$rows$value, 3)
})

test_that("a 30-minute series is never interpolated onto the quarter hours between", {
  a <- series_of(c(0, 30, 60), c(1, 2, 3), "instantaneous")
  expect_equal(as.numeric(a$rows$datetime) %% 1800, c(0, 0, 0))
  expect_equal(a$rows$value, c(1, 2, 3))
})

test_that("instantaneous readings are never interpolated across a gap", {
  a <- series_of(c(8.6, 23.6, 68.6, 83.6), c(1, 2, 5, 6), "instantaneous")
  q <- format(a$rows$datetime, "%H:%M", tz = "UTC")
  expect_equal(q, c("12:15", "13:15"))          # 12:30-13:00 lie across the gap
})

test_that("accumulated data off the quarter hour is refused rather than guessed", {
  a <- series_of(c(8, 23, 38), c(1, 1, 1), "accumulated")
  expect_equal(nrow(a$rows), 0)
  expect_match(a$problem, "cannot be aligned")
})

test_that("a logger swap is one continuous grid, the changeover a gap with no device", {
  first  <- data.frame(device_serial = "A", datetime = utc("2026-10-01 12:00") + (0:3) * 900,
                       value = 1:4, kind = "instantaneous", source_file = "a", conflict = FALSE)
  second <- data.frame(device_serial = "B", datetime = utc("2026-10-01 14:00") + (0:3) * 900,
                       value = 5:8, kind = "instantaneous", source_file = "b", conflict = FALSE)
  s <- p2_series(rbind(first, second))$series
  expect_equal(nrow(s), 12)
  expect_equal(s$device_serial[1:4], rep("A", 4))
  expect_true(all(is.na(s$device_serial[5:8])))
  expect_true(all(s$flag[5:8] == "missing"))
  expect_equal(s$device_serial[9:12], rep("B", 4))
})

test_that("a station-year is split on the local new year, not Greenwich's", {
  r <- data.frame(device_serial = "A", station_id = "zzt_hydro", variable = "abs_pressure",
                  kind = "instantaneous", source_file = "a", conflict = FALSE,
                  datetime = as.POSIXct("2026-12-31 23:30:00", tz = "America/Puerto_Rico") + (0:3) * 900,
                  value = 1:4)
  attr(r$datetime, "tzone") <- "UTC"
  p <- assemble_p2(r)
  expect_setequal(names(p), c("zzt_hydro|abs_pressure|2026", "zzt_hydro|abs_pressure|2027"))
  expect_equal(nrow(p[["zzt_hydro|abs_pressure|2026"]]$series), 2)   # 23:30 and 23:45
})
