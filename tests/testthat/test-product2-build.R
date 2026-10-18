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
  path <- product_path(2, "zzb_hydro", "abs_pressure_t-0007", 2026)
  expect_true(file.exists(path))
  expect_true(file.exists(product_path(2, "zzb_hydro", "water_temp_t-0007", 2026)))

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
  s <- built[["zzb_hydro|abs_pressure_t-0007|2026"]]$series
  back <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0007", 2026))
  expect_equal(as.numeric(back$datetime), as.numeric(s$datetime))
  expect_equal(back$value, s$value, tolerance = 1e-12)
  expect_equal(back$flag, s$flag)
})

test_that("the manifest says what each file holds and what built it", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  expect_equal(nrow(m), 2)
  r <- m[m$variable == "abs_pressure_t-0007", ]
  expect_equal(r$file, "p2/hydro/zzb_hydro/abs_pressure_t-0007/zzb_hydro_abs_pressure_t-0007_p2_2026.csv.gz")
  expect_equal(r$deployments, "t-0007")
  expect_equal(r$device_names, "real U20")
  expect_equal(r$unit, "kPa")
  expect_equal(r$timezone, "America/Puerto_Rico")
  expect_equal(r$devices, "21652379")
  expect_equal(r$alignment, "21652379 interpolated to the quarter hour")
  expect_equal(r$intervals, "21652379 15 min")
  expect_equal(r$source_files, U20)
  expect_equal(r$inputs, U20)
  fp <- p2_fingerprints("zzb_hydro", 2026, load_zentra_metadata(), load_zentra_ports_data(),
                        deployment_windows())
  expect_equal(r$metadata_fingerprint, fp$metadata)
  expect_equal(r$ports_fingerprint, fp$ports)
  expect_false(any(grepl("md5|uncommitted", c(names(r), unlist(r)))))
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

test_that("a logger running off its target interval is recorded, not flagged", {
  local_test_root(); place_p1(HOBOLINK)
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$interval_min[m$unique_id == "t-0008"] <- 15   # the target; it logged every 5
  write.csv(m, path, row.names = FALSE)
  out <- build_p2("zzs_hydro", 2023, quiet = TRUE)
  expect_true(all(out$intervals == "21180078 5 min"))
  expect_true(all(!nzchar(out$problems)))
})

test_that("a station's years come from its devices' files", {
  local_test_root(); place_p1(c(U20, HOBOLINK))
  w <- deployment_windows()
  expect_equal(p2_years_for("zzb_hydro", w), 2026L)
  expect_equal(p2_years_for("zzs_hydro", w), 2023L)
})

test_that("readings outside every deployment are counted in the build's summary", {
  local_test_root(); place_p1(U20)
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-30 12:00:00"   # after the first readings
  write.csv(m, path, row.names = FALSE)
  out <- build_p2("zzb_hydro", 2026, quiet = TRUE)
  u <- attr(out, "unattributed")
  expect_setequal(u$variable, c("abs_pressure", "water_temp"))
  expect_true(all(u$device_serial == "21652379"))
  expect_true(all(u$rows > 0))
  expect_true(all(format(u$last, "%Y-%m-%d", tz = "America/Puerto_Rico") <= "2026-08-30"))
})

test_that("a station is only built for years it was deployed in", {
  local_test_root(); place_p1(U20)
  w <- deployment_windows()
  expect_equal(p2_years_for("zzb_hydro", w), 2026L)
  w$starts[w$station_id == "zzb_hydro"] <- as.POSIXct("2027-01-01 12:00:00", tz = "America/Puerto_Rico")
  expect_length(p2_years_for("zzb_hydro", w), 0)
})

test_that("unattributed readings are counted once, however many builds read them", {
  local_test_root(); place_p1(UVI)
  # zzu_vwc1 deployed after these readings: its five water content series
  # belong to no station, and the logger is read from both its stations
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$deploy_datetime[m$unique_id == "t-0010"] <- "2026-12-01 12:00:00"
  write.csv(m, path, row.names = FALSE)

  out <- build_p2(c("zzu_weather", "zzu_vwc1", "zzu_weather"), 2026, quiet = TRUE)
  u <- attr(out, "unattributed")
  expect_equal(sum(u$rows), 5 * 3)               # five ports, three readings each
  expect_setequal(u$port, 2:6)
  expect_true(all(u$device_serial == "z6-13368"))
})

test_that("a file the download log does not name is skipped and listed, not fatal", {
  local_test_root(); place_p1(U20)
  stray <- file.path(wds("device_hobo"), "21652379_20260828_20260903_raw.rds")
  file.copy(file.path(wds("device_hobo"), U20), stray)     # an old name, unlogged
  out <- build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_equal(attr(out, "unlogged"), basename(stray))
  expect_length(list_product_files(2, station = "zzb_hydro"), 2)
  expect_equal(read_manifest(2)$source_files[1], U20)
})

test_that("a logger shared by two stations is read once in a build", {
  local_test_root(); place_p1(UVI)
  out <- build_p2(c("zzu_vwc1", "zzu_weather"), 2026, quiet = TRUE)
  expect_equal(attr(out, "reads"), UVI)
  expect_true(length(list_product_files(2, station = "zzu_vwc1")) > 0)
  expect_true(length(list_product_files(2, station = "zzu_weather")) > 0)
})

test_that("a manifest written before a column existed takes rows that carry it", {
  local_test_root(); place_p1(U20)
  old <- data.frame(station_id = "zzs_hydro", variable = "abs_pressure", year = "2023",
                    file = "p2/hydro/zzs_hydro/abs_pressure/zzs_hydro_abs_pressure_p2_2023.csv.gz",
                    rows = "10", stringsAsFactors = FALSE)
  dir.create(dirname(manifest_path(2)), recursive = TRUE, showWarnings = FALSE)
  write.csv(old, manifest_path(2), row.names = FALSE)
  expect_no_error(build_p2("zzb_hydro", 2026, quiet = TRUE))
  m <- read_manifest(2)
  expect_true(all(c("deployments", "device_names") %in% names(m)))
  expect_true("zzs_hydro" %in% m$station_id)          # the old row kept
  expect_true(is.na(m$deployments[m$station_id == "zzs_hydro"]) ||
              m$deployments[m$station_id == "zzs_hydro"] == "")
})

test_that("a logger removed and later redeployed belongs to no station in between", {
  local_test_root(); place_p1(U20)
  # 21652379: removed from zzb_hydro on 29 August, redeployed there on 1 September.
  # Its readings from the 30th and 31st were taken in storage.
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  m$status[m$unique_id == "t-0007"] <- "removed"
  m$last_visit[m$unique_id == "t-0007"] <- "2026-08-29"
  again <- m[m$unique_id == "t-0007", ]
  again$unique_id <- "t-0014"; again$status <- "manual"; again$last_visit <- NA
  again$deploy_datetime <- "2026-09-01 12:00:00"
  write.csv(rbind(m, again), path, row.names = FALSE)

  w <- deployment_windows()
  w <- w[w$unique_id == "t-0007", ]
  expect_equal(w$end_basis, "last visit")
  expect_equal(format(w$ends, "%Y-%m-%d %H:%M"), "2026-08-29 23:59")

  out <- build_p2("zzb_hydro", 2026, quiet = TRUE)
  first <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0007", 2026))
  second <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0014", 2026))
  expect_true(max(first$datetime) < as.POSIXct("2026-08-30", tz = "America/Puerto_Rico"))
  expect_true(min(second$datetime) >= as.POSIXct("2026-09-01 12:00", tz = "America/Puerto_Rico"))
  u <- attr(out, "unattributed")
  expect_true(all(as.numeric(u$first) >= as.numeric(as.POSIXct("2026-08-30", tz = "America/Puerto_Rico"))))
  expect_true(all(as.numeric(u$last) < as.numeric(as.POSIXct("2026-09-01 12:00", tz = "America/Puerto_Rico"))))
})

#### Fingerprints and commits ####

set_meta <- function(edit) {
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  write.csv(edit(m), path, row.names = FALSE)
}
fps <- function(st, yr) p2_fingerprints(st, yr, load_zentra_metadata(), load_zentra_ports_data(),
                                        deployment_windows())

test_that("a battery reading or a download date changes no fingerprint", {
  local_test_root()
  before <- fps("zzb_hydro", 2026)
  set_meta(function(m) { m$battery[m$unique_id == "t-0007"] <- 77
                         m$last_download_date[m$unique_id == "t-0007"] <- "2026-10-19 08:00:00"; m })
  expect_identical(fps("zzb_hydro", 2026), before)
})

test_that("a station's own deployment date changes its fingerprint, and no one else's", {
  local_test_root()
  zzb <- fps("zzb_hydro", 2026); uvi <- fps("zzu_weather", 2026)
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-02 12:00:00"; m })
  expect_false(identical(fps("zzb_hydro", 2026)$metadata, zzb$metadata))
  expect_identical(fps("zzu_weather", 2026), uvi)
})

test_that("a port change changes its logger's stations' ports fingerprint", {
  local_test_root()
  before <- fps("zzu_vwc1", 2026)
  path <- file.path(wds("meta_internal"), "zentra_ports.csv")
  p <- read.csv(path, stringsAsFactors = FALSE)
  p$depth_cm[p$sn == "z6-13368" & p$port == 3] <- 25
  write.csv(p, path, row.names = FALSE, na = "")
  after <- fps("zzu_vwc1", 2026)
  expect_identical(after$metadata, before$metadata)
  expect_false(identical(after$ports, before$ports))
})

test_that("outside the test suite, nothing is built on code that is not a commit", {
  local_test_root(); place_p1(U20)
  # withr, never a bare on.exit(): on.exit() replaces a test's other cleanup -
  # here, local_test_root()'s - and left the session on a throwaway root
  withr::local_options(viflo.test_build = FALSE)
  expect_error(build_p2("zzb_hydro", 2026, quiet = TRUE), "Not building Product 2")
  expect_length(list_product_files(2), 0)
})

test_that("a clean commit is named, and any change at all - a document included - blocks", {
  skip_if(Sys.which("git") == "", "git is not installed here")
  repo <- withr::local_tempdir()
  run <- function(...) system2("git", c("-C", shQuote(repo), ...), stdout = FALSE, stderr = FALSE)
  run("init", "-q"); run("config", "user.email", "t@t"); run("config", "user.name", "t")
  writeLines("x", file.path(repo, "README.md")); run("add", "."); run("commit", "-q", "-m", "first")
  withr::local_envvar(VI_FLO_ENGINE_ROOT = repo)

  clean <- engine_commit()
  expect_true(is.na(clean$problem))
  expect_match(clean$commit, "^[0-9a-f]{7,}$")

  writeLines("y", file.path(repo, "README.md"))              # a docs edit, uncommitted
  dirty <- engine_commit()
  expect_true(is.na(dirty$commit))
  expect_match(dirty$problem, "uncommitted")
})
