# The arithmetic behind the paired-gauge survey. Pure functions, no data root.

test_that("feet-inches-eighths readings convert, decimal eighths included", {
  expect_equal(parse_rod_reading("4 7 3", "ft_in_8")$value_m, (4 * 12 + 7 + 3 / 8) * 0.0254)
  expect_equal(parse_rod_reading("5 1 1.5", "ft_in_8")$value_m, (5 * 12 + 1 + 1.5 / 8) * 0.0254)
  expect_equal(parse_rod_reading("4.37", "ft")$value_m, 4.37 * 0.3048)
  expect_equal(parse_rod_reading("148.2", "cm")$value_m, 1.482)
})

test_that("impossible rod readings are refused, not converted", {
  expect_false(parse_rod_reading("4 12 0", "ft_in_8")$ok)    # 12 inches is a foot
  expect_false(parse_rod_reading("4 7 8", "ft_in_8")$ok)     # no ninth eighth
  expect_false(parse_rod_reading("4 7.5 2", "ft_in_8")$ok)   # fractions go in eighths
  expect_false(parse_rod_reading("4 7", "ft_in_8")$ok)
  expect_false(parse_rod_reading("-1", "m")$ok)
})

test_that("eighths are shown as entered, not reduced", {
  expect_equal(format_rod_reading("4 3 2", "ft_in_8"), "4' 3 2/8\"")
  expect_equal(format_rod_reading("5 1 1.5", "ft_in_8"), "5' 1 1.5/8\"")
  expect_equal(format_rod_reading("4 3 0", "ft_in_8"), "4' 3\"")
})

test_that("a fall has no sign, and a negative one says it is a climb", {
  expect_equal(format_fall(0.1294), "0.1294 m")
  expect_match(format_fall(-0.0555), "a climb, not a fall")
})

test_that("BTA2's 14 October readings give its surveyed fall", {
  r <- function(t) parse_rod_reading(t, "ft_in_8")$value_m
  bs <- vapply(c("4 3 2", "4 8 2", "4 7 6.5"), r, numeric(1), USE.NAMES = FALSE)
  fs <- vapply(c("4 11 2", "5 1 1.5", "5 1 0.5"), r, numeric(1), USE.NAMES = FALSE)
  falls <- compute_falls(bs, fs, 0.2494, 0.2494)
  expect_equal(round(falls, 4), c(0.2032, 0.1254, 0.1334))

  sel <- select_agreeing_pair(falls)
  expect_equal(c(sel$i, sel$j), c(2L, 3L))
  expect_true(sel$within)
  expect_equal(round(sel$diff_m * 1000, 1), 7.9)
  expect_equal(round(sel$fall_m, 4), 0.1294)
})

test_that("agreement exactly at the tolerance passes; beyond it does not", {
  expect_true(select_agreeing_pair(c(0.200, 0.210))$within)
  expect_false(select_agreeing_pair(c(0.200, 0.2101))$within)
  one <- select_agreeing_pair(0.2)
  expect_true(one$single)
  expect_true(is.na(one$within))
})

test_that("the real BTA2 TruPulse export reads as 24.16 m in two legs", {
  p <- read_trupulse_export(fixture_path("trupulse_bta2_20261014.txt"))
  expect_true(p$ok)
  expect_equal(p$legs, c(7.67, 16.49))
  expect_equal(p$total_m, 24.16)
  expect_equal(format_reach_arithmetic(p), "7.67 + 16.49 = 24.16 m")
})

test_that("a TruPulse export in feet converts, and one that mixes units is refused", {
  x <- readLines(fixture_path("trupulse_bta2_20261014.txt"))
  feet <- sub("Units: Meters", "Units: Feet", x)
  feet <- sub("([0-9.]+) Meters", "\\1 Feet", feet)
  f <- withr::local_tempfile(fileext = ".txt"); writeLines(feet, f)
  p <- read_trupulse_export(f)
  expect_true(p$ok)
  expect_equal(p$total_m, 24.16 * 0.3048)

  mixed <- sub("16.49 Feet", "16.49 Meters", feet)
  writeLines(mixed, f)
  expect_false(read_trupulse_export(f)$ok)
})

test_that("a TruPulse export whose leg count disagrees with its header is refused", {
  x <- readLines(fixture_path("trupulse_bta2_20261014.txt"))
  x <- sub("Total Measurements: 2", "Total Measurements: 3", x)
  f <- withr::local_tempfile(fileext = ".txt"); writeLines(x, f)
  expect_false(read_trupulse_export(f)$ok)
})

test_that("survey filenames follow the standard, and never overwrite", {
  d <- withr::local_tempdir()
  n1 <- build_survey_filename("bta2_hydro", "fall", "rod", "2026-10-14", "csv", dir = d)
  expect_equal(n1, "bta2_hydro_fall_rod_20261014.csv")
  file.create(file.path(d, n1))
  expect_equal(build_survey_filename("bta2_hydro", "fall", "rod", "2026-10-14", "csv", dir = d),
               "bta2_hydro_fall_rod_20261014_2.csv")
  expect_true(is_standard_survey_filename("bta2_hydro_reach_trupulse_20261014.txt"))
  expect_false(is_standard_survey_filename("BTA_2_Reach_Length_2026-10-14.txt"))
})

test_that("slope is higher minus lower over reach, whichever end is primary", {
  expect_equal(compute_slope(0.1294, 24.16), 0.1294 / 24.16)
  expect_equal(compute_slope(-0.1294, 24.16), 0.1294 / 24.16)
  expect_true(is.na(compute_slope(NA, 24.16)))
})
