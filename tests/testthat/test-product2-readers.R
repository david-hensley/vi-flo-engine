# Product 2, piece 1: the variable registry, and one reader for all three
# shapes of Product 1. The fixtures are real Product 1 files: bta2b's U20, the
# UVI ZL6 serving a weather and a vwc station at once, a vwc-only ZL6 fetched
# twice four minutes apart, and the first 400 rows of SR1's HOBOlink logger.

p1 <- function(f) fixture_path("p1", f)
U20      <- "21652379_20260828_20260902_raw.rds"
UVI      <- "z6-13368_20260928_20260928_20260928T134705_raw.rds"
VWC_A    <- "z6-38175_20261001_20261001_20261001T171036_raw.rds"
VWC_B    <- "z6-38175_20261001_20261001_20261001T171457_raw.rds"
HOBOLINK <- "21180078_20230802_20230803_raw.rds"

#### The registry ####

test_that("the registry names each source's measurement once", {
  reg <- load_variable_registry()
  expect_false(any(duplicated(paste(reg$source, reg$measurement))))
})

test_that("every kept measurement has a variable, a known unit and a kind", {
  reg <- load_variable_registry()
  k <- reg[reg$keep, ]
  expect_false(any(is.na(k$variable)))
  expect_true(all(k$unit %in% CANONICAL_UNITS))
  expect_true(all(k$kind %in% VARIABLE_KINDS))
})

test_that("a variable has one unit and one kind, whichever source it comes from", {
  k <- load_variable_registry()
  k <- k[k$keep, ]
  for (v in unique(k$variable)) {
    expect_equal(length(unique(k$unit[k$variable == v])), 1, label = v)
    expect_equal(length(unique(k$kind[k$variable == v])), 1, label = v)
  }
})

test_that("HOBOlink's computed level is never called level", {
  reg <- load_variable_registry()
  expect_equal(reg$variable[reg$measurement == "water_level_m"], "hobolink_level")
  expect_false("level" %in% reg$variable)
})

#### Units ####

test_that("units are recognized however they are spelled", {
  expect_equal(normalize_unit(c("\u00b0C", "\u00b0F", "kPa", "psi", "m\u00b3/m\u00b3",
                                "W/m\u00b2", "mm/hr", "")),
               c("degC", "degF", "kPa", "psi", "m3/m3", "W/m2", "mm/h", ""))
})

test_that("conversions are right, and an unknown one is refused", {
  expect_equal(convert_units(212, "degF", "degC"), 100)
  expect_equal(convert_units(1, "psi", "kPa"), 6.894757)
  expect_equal(convert_units(1013.25, "hPa", "kPa"), 101.325)
  expect_error(convert_units(1, "furlong", "m"), "No conversion")
})

#### The three shapes ####

test_that("a U20 export reads as two measurements in UTC, with the counter left out", {
  l <- read_p1_long(p1(U20))
  expect_setequal(unique(l$measurement), c("Abs Pres", "Temp"))
  expect_equal(nrow(l), 2 * 502)
  # 10:08:37 at GMT-04:00 is 14:08:37 UTC
  expect_equal(format(min(l$datetime), "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-08-28 14:08:37")
  expect_true(all(is.na(l$port)))
  expect_equal(unique(l$device_serial), "21652379")
})

test_that("a ZL6 file reads with its ports and error codes, times in UTC", {
  l <- read_p1_long(p1(UVI))
  expect_equal(nrow(l), 100)
  expect_true(all(c(1, 3, 8) %in% l$port))
  expect_equal(sum(l$error_code != 0, na.rm = TRUE), 6)
  expect_equal(format(min(l$datetime), "%H:%M", tz = "UTC"), "12:30")
})

test_that("a HOBOlink file reads from local time into UTC", {
  l <- read_p1_long(p1(HOBOLINK))
  expect_true(all(c("water_pressure_kpa", "barometric_kpa", "water_level_m") %in% l$measurement))
  # 13:05 Atlantic is 17:05 UTC
  expect_equal(format(min(l$datetime), "%Y-%m-%d %H:%M", tz = "UTC"), "2023-08-02 17:05")
  expect_equal(unique(l$device_serial), "21180078")
})

#### Mapping ####

test_that("a U20 maps to abs_pressure in kPa and water_temp in degC", {
  m <- map_measurements(read_p1_long(p1(U20)))
  expect_setequal(unique(m$variable), c("abs_pressure", "water_temp"))
  expect_equal(unique(m$unit[m$variable == "abs_pressure"]), "kPa")
  expect_equal(nrow(attr(m, "unmapped")), 0)
})

test_that("a U20 exported in psi and degF converts to the same values", {
  x <- readRDS(p1(U20))
  pc <- grep("^Abs Pres", names(x)); tc <- grep("^Temp", names(x))
  x[[pc]] <- x[[pc]] / 6.894757
  x[[tc]] <- x[[tc]] * 9 / 5 + 32
  names(x)[pc] <- sub("kPa", "psi", names(x)[pc])
  names(x)[tc] <- sub("\u00b0C", "\u00b0F", names(x)[tc])
  f <- withr::local_tempfile(fileext = "_raw.rds"); saveRDS(x, f)

  a <- map_measurements(read_p1_long(p1(U20)))
  b <- map_measurements(read_p1_long(f, device_serial = "21652379"))
  expect_equal(b$value, a$value, tolerance = 1e-9)
  expect_equal(b$unit, a$unit)
})

test_that("a unit with no known conversion stops the build", {
  x <- readRDS(p1(U20))
  pc <- grep("^Abs Pres", names(x))
  names(x)[pc] <- sub("kPa", "bar", names(x)[pc])
  f <- withr::local_tempfile(fileext = "_raw.rds"); saveRDS(x, f)
  expect_error(map_measurements(read_p1_long(f, device_serial = "21652379")),
               "Cannot convert abs_pressure")
})

test_that("a ZL6 keeps measurements, drops diagnostics and computed values", {
  m <- map_measurements(read_p1_long(p1(UVI)))
  kept <- unique(m$variable)
  expect_true(all(c("temp", "precip", "pressure", "vwc", "logger_pressure") %in% kept))
  expect_false(any(c("Battery Percent", "Signal", "Raw VWC", "VPD", "Dew Point") %in% m$measurement))
  expect_equal(nrow(attr(m, "unmapped")), 0)
  expect_true(all(m$depth[m$variable == "vwc"]))
})

test_that("an error-coded reading keeps its row but loses its value", {
  m <- map_measurements(read_p1_long(p1(UVI)))
  bad <- m[!is.na(m$error_code) & m$error_code != 0, ]
  expect_equal(nrow(bad), 3)           # Water Content on port 2; Raw VWC is dropped
  expect_true(all(is.na(bad$value)))
  expect_true(all(bad$port == 2))
})

test_that("a nonzero code with a number attached still loses the number", {
  x <- readRDS(p1(UVI))
  x$value[x$error_code != 0] <- 9999
  f <- withr::local_tempfile(fileext = "_raw.rds"); saveRDS(x, f)
  m <- map_measurements(read_p1_long(f, device_serial = "z6-13368"))
  expect_false(any(m$value == 9999, na.rm = TRUE))
})

test_that("a measurement the registry has never heard of is reported, not silently lost", {
  x <- readRDS(p1(VWC_A))
  x$measurement[x$measurement == "Logger Temperature"] <- "Matric Potential"
  f <- withr::local_tempfile(fileext = "_raw.rds"); saveRDS(x, f)
  m <- map_measurements(read_p1_long(f, device_serial = "z6-38175"))
  un <- attr(m, "unmapped")
  expect_equal(un$measurement, "Matric Potential")
  expect_false("Matric Potential" %in% m$measurement)
})

test_that("HOBOlink maps its own barometer to pressure and its level to hobolink_level", {
  m <- map_measurements(read_p1_long(p1(HOBOLINK)))
  expect_setequal(unique(m$variable), c("abs_pressure", "water_temp", "pressure", "hobolink_level"))
  expect_false(any(c("diff_pressure_kpa", "line_no") %in% m$measurement))
  expect_equal(unique(m$unit[m$variable == "hobolink_level"]), "m")
})

test_that("the two fetches of z6-38175 read identically", {
  a <- map_measurements(read_p1_long(p1(VWC_A)))
  b <- map_measurements(read_p1_long(p1(VWC_B)))
  expect_identical(a, b)
})

#### The layout ####

test_that("product files are filed by level, then type, station and variable", {
  local_test_root()
  root <- wds("products")
  expect_equal(product_path(2, "uvi_weather", "precip", 2026),
               file.path(root, "p2", "weather", "uvi_weather", "precip",
                         "uvi_weather_precip_p2_2026.csv.gz"))
  expect_equal(product_path(3, "uvi_vwc1", "vwc_30cm", 2026),
               file.path(root, "p3", "vwc", "uvi_vwc1", "vwc_30cm",
                         "uvi_vwc1_vwc_30cm_p3_2026.csv.gz"))
  expect_equal(dirname(dirname(product_path(2, "bt1_pond", "abs_pressure", 2026))),
               file.path(root, "p2", "pond", "bt1_pond"))
  expect_equal(station_type_of("bt1_hydro2"), "hydro")
})

test_that("product files can be listed by station, variable and year", {
  local_test_root()
  for (f in c(product_path(2, "bta2_hydro", "abs_pressure", 2025, create = TRUE),
              product_path(2, "bta2_hydro", "abs_pressure", 2026, create = TRUE),
              product_path(2, "uvi_weather", "precip", 2026, create = TRUE))) {
    file.create(f)
  }
  expect_length(list_product_files(2), 3)
  expect_length(list_product_files(2, station = "bta2_hydro"), 2)
  expect_length(list_product_files(2, variable = "precip"), 1)
  expect_length(list_product_files(2, years = 2026), 2)
  expect_length(list_product_files(3), 0)
  file.create(product_path(3, "bta2_hydro", "abs_pressure", 2026, create = TRUE))
  expect_length(list_product_files(3), 1)
  expect_length(list_product_files(2), 3)
})
