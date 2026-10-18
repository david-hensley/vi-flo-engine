# Putting names to loggers, and drawing what one recorded against where
# metadata says it was.

test_that("a logger is named by every name and station it has had", {
  local_test_root()
  expect_equal(device_names_for("90000002"), "testb-old at rb2_hydro; testb at bta2_hydro")
  expect_equal(device_names_for("z6-90001"), "Test weather at uvi_weather; Test weather at uvi_vwc1")
  expect_equal(device_names_for("nope"), "(not in metadata)")
})

test_that("view_device draws a logger's readings to a file", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  f <- withr::local_tempfile(fileext = ".png")
  r <- view_device("z6-13368", file = f, variables = c("temp", "vwc"))
  expect_true(file.exists(f))
  expect_true(file.info(f)$size > 1000)
  expect_setequal(unique(r$variable), c("temp", "vwc"))
})

test_that("view_device says so when there is nothing to draw", {
  local_test_root()
  expect_error(view_device("90000001"), "No logged Product 1 files")
})

test_that("the build summary groups unattributed readings under each logger's names", {
  local_test_root(); place_p1("21652379_20260828_20260902_raw.rds")
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-30 12:00:00"
  write.csv(m, path, row.names = FALSE)
  printed <- utils::capture.output(build_p2("zzb_hydro", 2026))
  expect_true(any(grepl("21652379  real U20 at zzb_hydro", printed, fixed = TRUE)))
})
