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
  r <- view_device("z6-13368", file = f, variables = c("temp", "vwc"), open = FALSE)
  expect_true(file.exists(f))
  expect_true(file.info(f)$size > 1000)
  expect_setequal(unique(r$variable), c("temp", "vwc"))
})

test_that("with no file given, view_device draws to a temporary picture of its own size", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  r <- view_device("z6-13368", open = FALSE)       # every panel: more than a pane holds
  f <- attr(r, "file")
  expect_true(file.exists(f))
  expect_true(grepl("\\.png$", f))
  expect_false(f %in% c("", NA))
})

test_that("view_device says so when there is nothing to draw", {
  local_test_root()
  expect_error(view_device("90000001"), "No logged Product 1 files")
})

test_that("the build summary puts a desk launch under installations, by name", {
  local_test_root(); place_p1("21652379_20260828_20260902_raw.rds")
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-30 12:00:00"   # two days after its first reading
  write.csv(m, path, row.names = FALSE)
  printed <- utils::capture.output(build_p2("zzb_hydro", 2026))
  expect_true(any(grepl("AROUND INSTALLATIONS", printed, fixed = TRUE)))
  expect_true(any(grepl("around 1 installation(s), set aside as settling in", printed, fixed = TRUE)))
  expect_true(any(grepl("UNEXPLAINED", printed, fixed = TRUE)))
  expect_true(any(grepl("none", printed, fixed = TRUE)))
})

test_that("a device goes by one name everywhere, by one rule", {
  local_test_root()
  m <- load_zentra_metadata()
  cloud <- data.frame(device_id = c("z6-77777", "z6-90001"), name = c("Someone's box", "Cloud name"),
                      stringsAsFactors = FALSE)
  # Its current row, wherever it is - not the removed one it had before
  expect_equal(device_display_name("90000002", m), "testb")
  # At a named station, that station's row, even a removed one
  expect_equal(device_display_name("90000002", m, station = "rb2_hydro"), "testb-old")
  # Metadata wins over ZentraCloud; ZentraCloud over the serial; the serial last
  expect_equal(device_display_name(c("z6-90001", "z6-77777", "z6-00000"), m, devices = cloud),
               c("Test weather", "Someone's box", "z6-00000"))
  # A blank metadata name falls through to the cloud
  m$device_name[m$device_serial == "z6-90001"] <- NA
  expect_equal(device_display_name("z6-90001", m, devices = cloud), "Cloud name")

  expect_equal(device_label("90000001"), "testa (90000001)")
  expect_equal(device_label(m[m$unique_id == "t-0001", ], with_role = TRUE), "testa (90000001, primary)")
  expect_equal(device_label("z6-00000"), "z6-00000")
  # A name that already carries its serial is not given it twice
  expect_equal(device_label(data.frame(device_serial = "z6-35228", device_name = "z6-35228 - ET2")),
               "z6-35228 - ET2")
})
