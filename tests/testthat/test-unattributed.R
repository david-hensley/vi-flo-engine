# Unattributed readings sorted three ways - unexplained, known, around
# installations - and printed newest first, the last 12 months apart.
#
# Fixture deployments used: the UVI ZL6 z6-13368 starts at zzu_weather on
# 2021-10-08 16:15 and at zzu_vwc1 on 2023-01-01 12:00; bta2b's U20 21652379
# starts at zzb_hydro on 2026-08-01 12:00.

tz <- "America/Puerto_Rico"
at <- function(x) { t <- as.POSIXct(x, tz = tz); attr(t, "tzone") <- "UTC"; t }
reading <- function(sn, port, when, variable = "vwc") {
  data.frame(device_serial = sn, port = port, variable = variable, datetime = at(when),
             stringsAsFactors = FALSE)
}
write_known <- function(rows) {
  write.csv(rows, file.path(wds("meta_internal"), "known_unattributed.csv"), row.names = FALSE, na = "")
}

test_that("no known file means nothing is known", {
  local_test_root()
  expect_equal(nrow(load_known_unattributed()), 0)
})

test_that("a known period covers its logger, and only between its dates", {
  local_test_root()
  write_known(data.frame(device_serial = "z6-13368", device_name = "real ZL6", port = NA,
                         from = "2024-02-16 00:00:00", to = NA, reason = "retired port"))
  u <- rbind(reading("z6-13368", 2L, "2024-03-01 10:00"), reading("z6-13368", 2L, "2023-06-01 10:00"))
  c <- classify_unattributed(u, deployment_windows(), load_known_unattributed())
  expect_equal(c$category, c("known", "unexplained"))
})

test_that("a known period on one port never hides another port of the same logger", {
  local_test_root()
  write_known(data.frame(device_serial = "z6-13368", device_name = "real ZL6", port = 2,
                         from = "2024-02-16 00:00:00", to = NA, reason = "retired port 2"))
  u <- rbind(reading("z6-13368", 2L, "2024-03-01 10:00"), reading("z6-13368", 3L, "2024-03-01 10:00"))
  c <- classify_unattributed(u, deployment_windows(), load_known_unattributed())
  expect_equal(c$category, c("known", "unexplained"))
})

test_that("up to 7 days before a deployment, or its first 2 hours, is around an installation", {
  local_test_root()
  u <- rbind(reading("21652379", NA_integer_, "2026-07-27 09:00", "abs_pressure"),   # 5 days before
             reading("21652379", NA_integer_, "2026-08-01 13:30", "abs_pressure"),   # 1.5 h after
             reading("21652379", NA_integer_, "2026-07-20 09:00", "abs_pressure"))   # 12 days before
  c <- classify_unattributed(u, deployment_windows(), load_known_unattributed())
  expect_equal(c$category, c("installation", "installation", "unexplained"))
})

test_that("a known period wins over the installation window", {
  local_test_root()
  write_known(data.frame(device_serial = "21652379", device_name = "real U20", port = NA,
                         from = "2026-07-25 00:00:00", to = "2026-08-01 12:00:00", reason = "an accident"))
  c <- classify_unattributed(reading("21652379", NA_integer_, "2026-07-27 09:00", "abs_pressure"),
                             deployment_windows(), load_known_unattributed())
  expect_equal(c$category, "known")
})

test_that("unexplained readings are episodes split wherever a day passes with nothing", {
  local_test_root()
  u <- rbind(reading("z6-13368", 3L, "2024-03-01 10:00"), reading("z6-13368", 3L, "2024-03-01 10:15"),
             reading("z6-13368", 3L, "2024-05-01 10:00"))
  ep <- unattributed_episodes(classify_unattributed(u, deployment_windows(), load_known_unattributed()))
  expect_equal(nrow(ep), 2)
  expect_equal(ep$moments, c(1L, 2L))                         # newest first
  expect_true(ep$last[1] > ep$last[2])
})

test_that("an episode counts moments once and names every variable in it", {
  local_test_root()
  u <- rbind(reading("21652379", NA_integer_, "2026-03-01 10:00", "abs_pressure"),
             reading("21652379", NA_integer_, "2026-03-01 10:00", "water_temp"))
  ep <- unattributed_episodes(classify_unattributed(u, deployment_windows(), load_known_unattributed()))
  expect_equal(ep$moments, 1L)
  expect_equal(ep$variables, "abs_pressure, water_temp")
})

test_that("the summary puts the last 12 months first, newest first, with names and reasons", {
  local_test_root()
  write_known(data.frame(device_serial = "z6-13368", device_name = "real ZL6", port = 2,
                         from = "2024-02-16 00:00:00", to = NA, reason = "retired port 2"))
  u <- rbind(reading("z6-13368", 3L, "2026-09-01 10:00"),
             reading("z6-13368", 3L, "2023-06-01 10:00"),
             reading("z6-13368", 2L, "2026-09-01 10:00"))
  ep <- unattributed_episodes(classify_unattributed(u, deployment_windows(), load_known_unattributed()))
  printed <- utils::capture.output(print_unattributed(ep, load_zentra_metadata(), load_known_unattributed(),
                                                       now = at("2026-10-18 12:00")))
  unexplained <- grep("UNEXPLAINED", printed)
  known <- grep("KNOWN", printed)
  recent <- grep("last 12 months", printed)
  older <- grep("older", printed)
  expect_true(unexplained < known)
  expect_true(recent[1] < older[1] && older[1] < known)        # within unexplained: recent, then older
  expect_true(any(grepl("real ZL6 \\(z6-13368\\).*port 2.*retired port 2", printed)))
})

test_that("a logger's ports in one story are one episode, listed compactly", {
  local_test_root()
  u <- rbind(reading("z6-13368", 3L, "2024-03-01 10:00"), reading("z6-13368", 4L, "2024-03-01 10:00"),
             reading("z6-13368", 5L, "2024-03-01 10:00"), reading("z6-13368", 8L, "2024-03-01 10:00", "logger_pressure"))
  ep <- unattributed_episodes(classify_unattributed(u, deployment_windows(), load_known_unattributed()))
  expect_equal(nrow(ep), 1)
  expect_equal(ep$ports, "3-5, 8")
  expect_equal(ep$variables, "logger_pressure, vwc")
})

test_that("a logger reporting a few times a week is one episode until a week passes", {
  local_test_root()
  u <- rbind(reading("z6-13368", 3L, "2024-03-01 10:00"), reading("z6-13368", 3L, "2024-03-05 10:00"),
             reading("z6-13368", 3L, "2024-03-10 10:00"), reading("z6-13368", 3L, "2024-03-25 10:00"))
  ep <- unattributed_episodes(classify_unattributed(u, deployment_windows(), load_known_unattributed()))
  expect_equal(sort(ep$moments), c(1L, 3L))
})

test_that("a deployment's whole first day counts as its installation", {
  local_test_root()
  c <- classify_unattributed(reading("21652379", NA_integer_, "2026-08-01 18:00", "abs_pressure"),
                             deployment_windows(), load_known_unattributed())
  expect_equal(c$category, "installation")           # six hours after it began
  c <- classify_unattributed(reading("21652379", NA_integer_, "2026-08-02 14:00", "abs_pressure"),
                             deployment_windows(), load_known_unattributed())
  expect_equal(c$category, "unexplained")            # past the first day
})

#### A logger's barometer follows its ports ####

close_port <- function(sn, port, when) {
  path <- file.path(wds("meta_internal"), "zentra_ports.csv")
  p <- read.csv(path, stringsAsFactors = FALSE)
  p$valid_to[p$sn == sn & p$port %in% port] <- when
  write.csv(p, path, row.names = FALSE, na = "")
}
barometer_station <- function() {
  r <- read_p1_set(file.path(wds("device_zentra"), "z6-13368_20260928_20260928_20260928T134705_raw.rds"))
  a <- attribute_readings(r)
  list(station = unique(a$station_id[a$variable == "logger_pressure"]),
       lost = sum(attr(a, "unattributed")$variable == "logger_pressure"))
}

test_that("the barometer goes to weather while weather's port is open", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  expect_equal(barometer_station()$station, "zzu_weather")
})

test_that("once weather's sensor has moved on, the barometer goes to the station still served", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  close_port("z6-13368", 1, "2026-09-01 12:00:00")
  expect_equal(barometer_station()$station, "zzu_vwc1")
})

test_that("a logger serving no station through any port has a barometer belonging to none", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  close_port("z6-13368", 1:6, "2026-09-01 12:00:00")
  b <- barometer_station()
  expect_length(b$station, 0)
  expect_equal(b$lost, 1)
})
