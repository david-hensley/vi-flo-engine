# The download date goes to the logger's active row at the station logged -
# never to every row with its serial. 21652376 is tr1slope at tr1_hydro and
# was TR2, decommissioned; matching by serial gave two time zones ("invalid
# 'tz' value") and would have stamped the decommissioned row.

test_that("a download date goes only to the logger's active row at the station logged", {
  local_test_root()
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  old <- m[m$unique_id == "t-0007", ]                       # the U20 at zzb_hydro
  old$unique_id <- "t-0999"; old$station_id <- "zzx_hydro"
  old$status <- "decommissioned"; old$last_download_date <- NA
  write.csv(rbind(m, old), path, row.names = FALSE)

  expect_true(isTRUE(update_last_download_date(old$device_serial, "2026-10-27",
                                               station_id = "zzb_hydro")))
  m2 <- load_zentra_metadata()
  expect_equal(format(m2$last_download_date[m2$unique_id == "t-0007"], "%Y-%m-%d"), "2026-10-27")
  expect_true(is.na(m2$last_download_date[m2$unique_id == "t-0999"]))
})

test_that("a station where the logger is retired gets no download date", {
  local_test_root()
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  old <- m[m$unique_id == "t-0007", ]
  old$unique_id <- "t-0999"; old$station_id <- "zzx_hydro"
  old$status <- "decommissioned"; old$last_download_date <- NA
  write.csv(rbind(m, old), path, row.names = FALSE)

  r <- update_last_download_date(old$device_serial, "2026-10-27", station_id = "zzx_hydro")
  expect_match(r, "No active row")
  m2 <- load_zentra_metadata()
  expect_true(is.na(m2$last_download_date[m2$unique_id == "t-0999"]))
})
