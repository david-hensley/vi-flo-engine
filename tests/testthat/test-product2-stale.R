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

test_that("only a change to Product 2's code counts as the code changing", {
  skip_if(Sys.which("git") == "", "git is not installed here")
  repo <- withr::local_tempdir()
  run <- function(...) system2("git", c("-C", shQuote(repo), ...), stdout = FALSE, stderr = FALSE)
  head <- function() trimws(system2("git", c("-C", shQuote(repo), "rev-parse", "--short", "HEAD"), stdout = TRUE))
  run("init", "-q"); run("config", "user.email", "t@t"); run("config", "user.name", "t")
  dir.create(file.path(repo, "code", "functions"), recursive = TRUE)
  writeLines("a", file.path(repo, "code", "functions", "product2_functions.R"))
  writeLines("x", file.path(repo, "README.md"))
  run("add", "."); run("commit", "-q", "-m", "one"); built <- head()
  withr::local_envvar(VI_FLO_ENGINE_ROOT = repo)

  expect_false(p2_code_changed_since(built))
  writeLines("y", file.path(repo, "README.md")); run("commit", "-qam", "docs")
  expect_false(p2_code_changed_since(built))                 # a README edit rebuilds nothing
  writeLines("b", file.path(repo, "code", "functions", "product2_functions.R")); run("commit", "-qam", "code")
  expect_true(p2_code_changed_since(built))
  expect_true(p2_code_changed_since("abc1234"))              # a commit it has never seen
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
