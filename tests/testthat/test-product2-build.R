# Product 2, piece 4: writing station-year files and the manifest, and
# build_p2() running every piece end to end on the real fixture loggers.

U20      <- "21652379_20260828_20260902_raw.rds"
UVI      <- "z6-13368_20260928_20260928_20260928T134705_raw.rds"
VWC_A    <- "z6-38175_20261001_20261001_20261001T171036_raw.rds"
VWC_B    <- "z6-38175_20261001_20261001_20261001T171457_raw.rds"
HOBOLINK <- "21180078_20230802_20230803_raw.rds"

test_that("a station-year is written where the layout says, in plain local time", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  path <- product_path(2, "zzb_hydro", "abs_pressure", 2026)
  expect_true(file.exists(path))
  expect_true(file.exists(product_path(2, "zzb_hydro", "water_temp", 2026)))

  raw <- read.csv(path, colClasses = "character")
  expect_equal(names(raw), P2_COLUMNS)
  expect_equal(raw$datetime[1], "2026-08-28 10:15:00")
  expect_equal(raw$flag[1], "observed")
  expect_equal(raw$source_file[1], U20)
})

test_that("what is written reads back as what was built", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  built <- assemble_p2(attribute_readings(read_p1_set(file.path(wds("device_hobo"), U20))))
  s <- built[["zzb_hydro|abs_pressure|2026"]]$series
  back <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure", 2026))
  expect_equal(as.numeric(back$datetime), as.numeric(s$datetime))
  expect_equal(back$value, s$value, tolerance = 1e-12)
  expect_equal(back$flag, s$flag)
})

test_that("the manifest says what each file holds and what built it", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  expect_equal(nrow(m), 2)
  r <- m[m$variable == "abs_pressure", ]
  expect_equal(r$file, "p2/hydro/zzb_hydro/abs_pressure/zzb_hydro_abs_pressure_p2_2026.csv.gz")
  expect_equal(r$unit, "kPa")
  expect_equal(r$timezone, "America/Puerto_Rico")
  expect_equal(r$devices, "21652379")
  expect_equal(r$alignment, "21652379 interpolated to the quarter hour")
  expect_equal(r$intervals, "21652379 15 min")
  expect_equal(r$source_files, U20)
  expect_equal(r$metadata_md5,
               unname(tools::md5sum(file.path(wds("meta_internal"), "device_metadata.csv"))))
  expect_equal(as.integer(r$rows), as.integer(r$observed) + as.integer(r$missing))
})

test_that("rebuilding replaces files and manifest rows, never adds to them", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  first <- read_manifest(2)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_equal(nrow(read_manifest(2)), nrow(first))
  expect_length(list_product_files(2, station = "zzb_hydro"), 2)
})

test_that("a file the current inputs no longer make is removed, with its row", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  # A stray product left by an earlier build - a variable since dropped
  stray <- product_path(2, "zzb_hydro", "old_variable", 2026, create = TRUE)
  file.create(stray)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_false(file.exists(stray))
  expect_length(list_product_files(2, station = "zzb_hydro"), 2)
})

test_that("a co-located logger builds both its stations, each with only its own series", {
  local_test_root(); place_p1(UVI)
  build_p2(c("zzu_weather", "zzu_vwc1"), 2026, quiet = TRUE)
  w <- basename(dirname(list_product_files(2, station = "zzu_weather")))
  v <- basename(dirname(list_product_files(2, station = "zzu_vwc1")))
  expect_true(all(c("temp", "precip", "logger_pressure") %in% w))
  expect_setequal(v, c("vwc_10cm", "vwc_20cm", "vwc_30cm", "vwc_50cm", "vwc_100cm"))
})

test_that("the duplicate fetches build one series, with no conflict", {
  local_test_root(); place_p1(c(VWC_A, VWC_B))
  out <- build_p2("zzv_vwc1", 2026, quiet = TRUE)
  expect_true(all(out$conflicts == "0"))
  s <- read_p2_file(product_path(2, "zzv_vwc1", "vwc_10cm", 2026))
  expect_equal(anyDuplicated(s$datetime), 0)
  expect_true(all(s$source_file == VWC_B))
})

test_that("a declared interval the logger did not keep is reported", {
  local_test_root(); place_p1(HOBOLINK)
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$interval_min[m$unique_id == "t-0008"] <- 15   # it logged every 5
  write.csv(m, path, row.names = FALSE)
  out <- build_p2("zzs_hydro", 2023, quiet = TRUE)
  expect_true(all(grepl("declared 15 min, logged 5 min", out$intervals)))
})

test_that("a station's years come from its devices' files", {
  local_test_root(); place_p1(c(U20, HOBOLINK))
  w <- deployment_windows()
  expect_equal(p2_years_for("zzb_hydro", w), 2026L)
  expect_equal(p2_years_for("zzs_hydro", w), 2023L)
})
