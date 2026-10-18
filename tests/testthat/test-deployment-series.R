# At hydro and pond stations - the water level loggers - each deployment is
# its own Product 2 series, named by its device_metadata row: a paired
# gauge's loggers measure at once in different places, and a deployment is
# one logger in one place, one elevation, one sensor height.
#
# zzb_hydro carries bta2b's real U20 (21652379, row t-0007). A second logger,
# 90000009, is made from the same file with its serial changed, so a pair can
# be built end to end.

U20 <- "21652379_20260828_20260902_raw.rds"
PARTNER <- "90000009_20260828_20260902_raw.rds"

set_meta <- function(edit) {
  path <- file.path(wds("meta_internal"), "device_metadata.csv")
  m <- read.csv(path, stringsAsFactors = FALSE)
  write.csv(edit(m), path, row.names = FALSE)
}

add_partner <- function() {
  place_p1(U20)
  x <- readRDS(file.path(wds("device_hobo"), U20))
  names(x) <- gsub("21652379", "90000009", names(x))
  x[[3]] <- x[[3]] + 0.2                       # another place, another pressure
  saveRDS(x, file.path(wds("device_hobo"), PARTNER))
  lp <- file.path(wds("meta_internal"), "download_log.csv")
  dl <- read.csv(lp, stringsAsFactors = FALSE)
  row <- dl[dl$device_serial == "21652379", ]
  row$device_serial <- "90000009"; row$filepath <- sub("21652379", "90000009", row$filepath)
  write.csv(rbind(dl, row), lp, row.names = FALSE)
  set_meta(function(m) {
    p <- m[m$unique_id == "t-0007", ]
    p$unique_id <- "t-0012"; p$device_serial <- "90000009"; p$device_name <- "partner"
    rbind(m, p)
  })
}

test_that("a paired gauge builds one series per deployment, and nothing is dropped", {
  local_test_root(); add_partner()
  out <- build_p2("zzb_hydro", 2026, quiet = TRUE)
  vars <- basename(dirname(list_product_files(2, station = "zzb_hydro")))
  expect_setequal(vars, c("abs_pressure_t-0007", "abs_pressure_t-0012",
                          "water_temp_t-0007", "water_temp_t-0012"))
  expect_false(any(grepl("two devices", out$problems)))
  a <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0007", 2026))
  b <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0012", 2026))
  expect_equal(b$value - a$value, rep(0.2, nrow(a)), tolerance = 1e-9)
  m <- read_manifest(2)
  expect_equal(m$devices[m$variable == "abs_pressure_t-0012"], "90000009")
  expect_equal(m$device_names[m$variable == "abs_pressure_t-0012"], "partner")
})

test_that("one logger moved within a station is two series, one per deployment", {
  local_test_root(); place_p1(U20)
  # 21652379 moves to a new position at the station on 30 August: a new row
  set_meta(function(m) {
    p <- m[m$unique_id == "t-0007", ]
    p$unique_id <- "t-0013"; p$deploy_datetime <- "2026-08-30 12:00:00"
    rbind(m, p)
  })
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  before <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0007", 2026))
  after  <- read_p2_file(product_path(2, "zzb_hydro", "abs_pressure_t-0013", 2026))
  cut <- as.POSIXct("2026-08-30 12:00", tz = "America/Puerto_Rico")
  expect_true(max(before$datetime) < cut)
  expect_true(min(after$datetime) >= cut)
})

test_that("a lone gauge is keyed by its deployment too", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_setequal(basename(dirname(list_product_files(2, station = "zzb_hydro"))),
                  c("abs_pressure_t-0007", "water_temp_t-0007"))
})

test_that("roles play no part: a role on the row changes nothing in the name", {
  local_test_root(); place_p1(U20)
  set_meta(function(m) { m$device_role[m$unique_id == "t-0007"] <- "secondary"; m })
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  expect_false(any(grepl("secondary|primary", list_product_files(2, station = "zzb_hydro"))))
})

test_that("weather and vwc series are not keyed by deployment", {
  local_test_root(); place_p1("z6-38175_20261001_20261001_20261001T171457_raw.rds")
  build_p2("zzv_vwc1", 2026, quiet = TRUE)
  vars <- basename(dirname(list_product_files(2, station = "zzv_vwc1")))
  expect_true("vwc_10cm" %in% vars)
  expect_false(any(grepl("t-00", vars)))
})

test_that("the unit is found for a deployment-keyed variable", {
  local_test_root(); place_p1(U20)
  build_p2("zzb_hydro", 2026, quiet = TRUE)
  m <- read_manifest(2)
  expect_equal(m$unit[m$variable == "abs_pressure_t-0007"], "kPa")
  expect_equal(m$unit[m$variable == "water_temp_t-0007"], "degC")
})
