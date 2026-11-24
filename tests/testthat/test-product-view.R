# Reading a product back, and stepping through it by eye

U20_FILE <- "21652379_20260828_20260902_raw.rds"

build_zzb <- function(partner = FALSE) {
  place_p1(U20_FILE)
  if (partner) {
    # A second logger at zzb_hydro, as test-deployment-series.R builds one
    x <- readRDS(file.path(wds("device_hobo"), U20_FILE))
    names(x) <- gsub("21652379", "90000009", names(x))
    x[[3]] <- x[[3]] + 0.2
    saveRDS(x, file.path(wds("device_hobo"), "90000009_20260828_20260902_raw.rds"))
    lp <- file.path(wds("meta_internal"), "download_log.csv")
    dl <- read.csv(lp, stringsAsFactors = FALSE)
    row <- dl[dl$device_serial == "21652379", ]
    row$device_serial <- "90000009"; row$filepath <- sub("21652379", "90000009", row$filepath)
    write.csv(rbind(dl, row), lp, row.names = FALSE)
    mp <- file.path(wds("meta_internal"), "device_metadata.csv")
    m <- read.csv(mp, stringsAsFactors = FALSE)
    p <- m[m$unique_id == "t-0007", ]
    p$unique_id <- "t-0012"; p$device_serial <- "90000009"; p$device_name <- "partner"
    write.csv(rbind(m, p), mp, row.names = FALSE)
  }
  invisible(build_p2("zzb_hydro", 2026, quiet = TRUE, print_report = FALSE))
}

test_that("a variable is read by its name without the deployment, each series named by its device", {
  local_test_root(); build_zzb(partner = TRUE)
  x <- read_product("zzb_hydro", "abs_pressure")
  expect_setequal(unique(x$series), c("abs_pressure_t-0007", "abs_pressure_t-0012"))
  expect_setequal(unique(x$device_name[!is.na(x$device_name)]), c("real U20", "partner"))
  expect_equal(attr(x, "unit"), "kPa")
  # One series by its full name
  y <- read_product("zzb_hydro", "abs_pressure_t-0012")
  expect_equal(unique(y$series), "abs_pressure_t-0012")
})

test_that("a period narrows what is read, by date or datetime", {
  local_test_root(); build_zzb()
  all <- read_product("zzb_hydro", "water_temp")
  day <- read_product("zzb_hydro", "water_temp", from = "2026-08-30", to = "2026-08-30")
  expect_lt(nrow(day), nrow(all))
  expect_true(all(format(day$datetime, "%Y-%m-%d", tz = PROJECT_TZ) == "2026-08-30"))
  expect_equal(nrow(day), 96)
})

test_that("a wrong station or variable says what there is", {
  local_test_root(); build_zzb()
  expect_error(read_product("zzb_hydro", "precip"), "It has: abs_pressure, water_temp")
  expect_error(read_product("nowhere", "precip"), "Stations with files: zzb_hydro")
})

test_that("browsing steps through each variable, and stops on q", {
  local_test_root(); build_zzb(partner = TRUE)
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f); on.exit(grDevices::dev.off(), add = TRUE)
  run <- with_inputs(c("", "q"), browse_product("zzb_hydro"))
  expect_equal(run$value, 2)
  out <- paste(run$output, collapse = "\n")
  expect_match(out, "zzb_hydro - abs_pressure   (1 of 2)", fixed = TRUE)
  expect_match(out, "zzb_hydro - water_temp   (2 of 2)", fixed = TRUE)
})

test_that("every plot can be written to one PDF instead", {
  local_test_root(); build_zzb(partner = TRUE)
  f <- tempfile(fileext = ".pdf")
  out <- utils::capture.output(n <- browse_product(pdf = f))
  expect_equal(n, 2)
  expect_true(file.exists(f) && file.size(f) > 0)
})

test_that("z switches between every value and the bulk of the data, redrawing the same plot", {
  local_test_root(); build_zzb(partner = TRUE)
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f); on.exit(grDevices::dev.off(), add = TRUE)
  run <- with_inputs(c("z", "z", "q"), browse_product("zzb_hydro"))
  out <- run$output
  plot_lines <- grep("zzb_hydro - ", out, value = TRUE)
  # The same plot three times: full, bulk, full again
  expect_equal(length(plot_lines), 3)
  expect_true(all(grepl("abs_pressure", plot_lines)))
  expect_match(plot_lines[2], "bulk of the data", fixed = TRUE)
  expect_false(grepl("bulk of the data", plot_lines[3], fixed = TRUE))
})

test_that("in the bulk of the data a wild value is drawn at the edge and counted", {
  set.seed(1)
  t0 <- as.POSIXct("2026-01-01", tz = PROJECT_TZ)
  x <- data.frame(datetime = t0 + (0:1999) * 900, value = rnorm(2000, 100, 1),
                  flag = NA, device_serial = "s1", source_file = "f", conflict = FALSE,
                  series = "abs_pressure_h-0001", device_name = "one",
                  stringsAsFactors = FALSE)
  x$value[c(10, 20)] <- c(5000, -5000)
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f); on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(draw_product_plot(x, "zz", "abs_pressure", "kPa"), 0)
  expect_equal(draw_product_plot(x, "zz", "abs_pressure", "kPa", scale = "bulk"), 2)
})
