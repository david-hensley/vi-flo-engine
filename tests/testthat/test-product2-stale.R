# Keeping Product 2 up to date: which station-years are stale, and why, and
# rebuilding exactly those.

U20 <- "21652379_20260828_20260902_raw.rds"
VWC <- "z6-38175_20261001_20261001_20261001T171457_raw.rds"

set_meta <- function(edit) {
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  write.csv(edit(m), path, row.names = FALSE)
}
reasons <- function(s, st) s$reason[s$station_id == st]

test_that("a station-year never built is stale", {
  local_test_root(); place_p1(U20)
  s <- p2_stale()
  expect_equal(reasons(s, "zzb_hydro"), "not built yet")
})

test_that("after a build, nothing is stale", {
  local_test_root(); place_p1(c(U20, VWC))
  build_p2(c("zzb_hydro", "zzv_vwc1"), 2026, quiet = TRUE)
  expect_equal(nrow(p2_stale()), 0)
})

test_that("a new Product 1 file makes its station-year stale - and only that one", {
  local_test_root(); place_p1(c(U20, VWC))
  build_p2(c("zzb_hydro", "zzv_vwc1"), 2026, quiet = TRUE)
  # A second offload of the U20, logged
  extra <- "21652379_20260902_20260910_raw.rds"
  file.copy(file.path(wds("device_hobo"), U20), file.path(wds("device_hobo"), extra))
  lp <- file.path(wds("meta_internal"), "download_log.csv")
  dl <- read.csv(lp, stringsAsFactors = FALSE)
  row <- dl[dl$device_serial == "21652379", ][1, ]; row$filepath <- sub(U20, extra, row$filepath)
  write.csv(rbind(dl, row), lp, row.names = FALSE)
  s <- p2_stale()
  expect_equal(reasons(s, "zzb_hydro"), "1 new Product 1 file(s)")
  expect_length(reasons(s, "zzv_vwc1"), 0)
})

test_that("a station's metadata changing makes it stale, and no other", {
  local_test_root(); place_p1(c(U20, VWC))
  build_p2(c("zzb_hydro", "zzv_vwc1"), 2026, quiet = TRUE)
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-02 12:00:00"; m })
  s <- p2_stale()
  expect_equal(reasons(s, "zzb_hydro"), "its loggers' metadata changed")
  expect_length(reasons(s, "zzv_vwc1"), 0)
})

test_that("a visit makes nothing stale", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  set_meta(function(m) { m$last_visit[m$unique_id == "t-0007"] <- "2026-10-19"; m })
  expect_equal(nrow(p2_stale()), 0)
})

test_that("a port change makes its logger's stations stale", {
  local_test_root(); place_p1(VWC)
  build_p2("zzv_vwc1", 2026, quiet = TRUE)
  p <- load_zentra_ports_data()
  p$depth_cm[p$sn == "z6-38175" & p$port == 1] <- 15
  save_zentra_ports(p)
  expect_equal(reasons(p2_stale(), "zzv_vwc1"), "its loggers' ports changed")
})

test_that("a product the inputs no longer make is stale, and rebuilding removes it", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2027-01-01 12:00:00"; m })
  s <- p2_stale()
  expect_equal(reasons(s, "zzb_hydro"), "no longer made by the current inputs")
  build_p2_stale(quiet = TRUE)
  expect_length(list_product_files(2, station = "zzb_hydro"), 0)
  expect_false("zzb_hydro" %in% read_manifest(2)$station_id)
})

test_that("rebuilding the stale leaves nothing stale, and a dry run builds nothing", {
  local_test_root(); place_p1(c(U20, VWC))
  dry <- build_p2_stale(dry_run = TRUE, quiet = TRUE)
  expect_equal(nrow(dry), 2)
  expect_length(list_product_files(2), 0)
  build_p2_stale(quiet = TRUE)
  expect_true(length(list_product_files(2)) > 0)
  expect_equal(nrow(p2_stale()), 0)
})

test_that("a manifest from before fingerprints counts as stale", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2); m$metadata_fingerprint <- NULL; m$inputs <- NULL
  write.csv(m, manifest_path(2), row.names = FALSE)
  expect_equal(reasons(p2_stale(), "zzb_hydro"), "built before fingerprints were recorded")
})

test_that("only a change to the code a build runs counts as the code changing", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_false("zzb_hydro" %in% p2_stale()$station_id)

  # A function Product 2 never runs: nothing to rebuild
  old_todo <- get("print_network_todo", envir = globalenv())
  withr::defer(assign("print_network_todo", old_todo, envir = globalenv()))
  assign("print_network_todo", function(...) "changed", envir = globalenv())
  expect_false("zzb_hydro" %in% p2_stale()$station_id)

  # How the build's report reads: nothing to rebuild either
  old_rep <- get("print_p2_report", envir = globalenv())
  withr::defer(assign("print_p2_report", old_rep, envir = globalenv()))
  assign("print_p2_report", function(...) cat("said differently\n"), envir = globalenv())
  expect_false("zzb_hydro" %in% p2_stale()$station_id)

  # Something in the session that merely shares a local variable's name
  assign("files", "a session's own object", envir = globalenv())
  withr::defer(rm("files", envir = globalenv()))
  expect_false("zzb_hydro" %in% p2_stale()$station_id)

  # A function it does run, even outside product2_functions.R: rebuild
  old_parse <- get("parse_raw_filename", envir = globalenv())
  withr::defer(assign("parse_raw_filename", old_parse, envir = globalenv()))
  assign("parse_raw_filename", function(...) { x <- 1; old_parse(...) }, envir = globalenv())
  expect_equal(reasons(p2_stale(), "zzb_hydro"), "the Product 2 code changed")
})

test_that("a comment or layout change is not a code change", {
  f1 <- function(x) {
    x + 1
  }
  f2 <- function(x) { x + 1 }    # said differently
  expect_identical(deparse(utils::removeSource(f1)), deparse(utils::removeSource(f2)))
})

test_that("a station-year built and found empty is recorded, and is not stale", {
  local_test_root(); place_p1(U20)
  # zzb_hydro's logger read nothing in 2026 as far as attribution goes, once
  # its deployment is moved past its readings
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-12-30 12:00:00"; m })
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  e <- m[m$station_id == "zzb_hydro" & m$year == "2026", ]
  expect_equal(e$variable, "(nothing)")
  expect_equal(e$rows, "0")
  expect_false("zzb_hydro" %in% p2_stale()$station_id)

  # New readings, and it is stale again
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-01 12:00:00"; m })
  expect_true("zzb_hydro" %in% p2_stale()$station_id)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  expect_false("(nothing)" %in% m$variable[m$station_id == "zzb_hydro"])
})

test_that("a run over several stations prints one report, at the end", {
  local_test_root(); place_p1(c(U20, VWC))
  # Something for the report to say: zzb's logger recorded before its deployment
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-30 12:00:00"; m })
  printed <- utils::capture.output(build_p2_stale())
  expect_equal(sum(grepl("^Unattributed", printed)), 1)
  expect_equal(sum(grepl("^Worth a look", printed)), 1)
  last_progress <- max(grep("file(s)", printed, fixed = TRUE))
  expect_true(is.finite(last_progress))
  expect_true(grep("^Unattributed", printed) > last_progress)   # after every station
})

test_that("a station's fingerprint ignores the logger's deployments elsewhere at other times", {
  local_test_root()
  # 90000002 is bta2b now (t-0002) and was at Reef Bay before (t-0003). A
  # change to the Reef Bay row does not touch bta2's fingerprint
  m <- load_zentra_metadata()
  p <- load_zentra_ports_data()
  fp1 <- p2_fingerprints("bta2_hydro", 2026L, m, p, deployment_windows(m))
  m$status[m$unique_id == "t-0003"] <- "replaced"
  fp2 <- p2_fingerprints("bta2_hydro", 2026L, m, p, deployment_windows(m))
  expect_identical(fp1, fp2)
  # A change to bta2's own row does
  m$deploy_datetime[m$unique_id == "t-0002"] <- m$deploy_datetime[m$unique_id == "t-0002"] + 3600
  fp3 <- p2_fingerprints("bta2_hydro", 2026L, m, p, deployment_windows(m))
  expect_false(identical(fp1$metadata, fp3$metadata))
})

test_that("a shared logger's other station counts, where it serves at the same time", {
  local_test_root()
  # z6-13368 serves zzu_weather and zzu_vwc1 at once
  m <- load_zentra_metadata()
  p <- load_zentra_ports_data()
  fp1 <- p2_fingerprints("zzu_weather", 2026L, m, p, deployment_windows(m))
  p$depth_cm[p$unique_id == "t-0010"][1] <- 99
  fp2 <- p2_fingerprints("zzu_weather", 2026L, m, p, deployment_windows(m))
  expect_false(identical(fp1$ports, fp2$ports))
})

test_that("a build that writes nothing still reports what it found", {
  local_test_root(); place_p1(U20)
  # Every reading falls before the deployment: no file, but unattributed readings
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-12-30 12:00:00"; m })
  b <- build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_true(is.data.frame(b))
  expect_equal(nrow(b), 0)
  expect_true(nrow(attr(b, "unattributed_readings")) > 0)
  s <- build_p2_stale(quiet = TRUE)
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-12-29 12:00:00"; m })
  s <- build_p2_stale(quiet = TRUE)
  expect_true(nrow(attr(s, "unattributed_readings")) > 0)
})

test_that("a manifest row whose file has gone is cleared by the rebuild", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  # The station-year stops being made, and one of its files is already missing
  f <- list_product_files(2, station = "zzb_hydro")
  file.remove(f[1])
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2027-01-01 12:00:00"; m })
  build_p2_stale(quiet = TRUE)
  expect_false("zzb_hydro" %in% read_manifest(2)$station_id)
  expect_equal(nrow(p2_stale()), 0)

  # And a row naming a file no longer made, in a year still built, goes too
  set_meta(function(m) { m$deploy_datetime[m$unique_id == "t-0007"] <- "2026-08-01 12:00:00"; m })
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  ghost <- m[m$station_id == "zzb_hydro", ][1, ]
  ghost$variable <- "renamed_away"; ghost$file <- "p2/hydro/zzb_hydro/renamed_away/x_p2_2026.csv.gz"
  write.csv(rbind(m, ghost), manifest_path(2), row.names = FALSE)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_false("renamed_away" %in% read_manifest(2)$variable)
})
