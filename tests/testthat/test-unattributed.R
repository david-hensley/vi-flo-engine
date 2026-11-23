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
  if (!"archive" %in% names(rows)) rows$archive <- NA
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
  # A known period is counted, not listed: its explanation is in the file
  expect_true(any(grepl("KNOWN - 1 period(s), 1 moments, as recorded in known_unattributed.csv",
                        printed, fixed = TRUE)))
  expect_false(any(grepl("retired port 2", printed)))
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
  p <- load_zentra_ports_data()
  p$valid_to[p$sn == sn & p$port %in% port] <- as.POSIXct(when, tz = "America/Puerto_Rico")
  save_zentra_ports(p)
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

#### Excluded sensors ####

test_that("an excluded sensor's readings are set aside: neither placed nor reported", {
  local_test_root(); place_p1("z6-13368_20260928_20260928_20260928T134705_raw.rds")
  r <- read_p1_set(file.path(wds("device_zentra"), "z6-13368_20260928_20260928_20260928T134705_raw.rds"))
  on_port_2 <- sum(r$port %in% 2)
  skip_if(on_port_2 == 0, "the fixture holds nothing on port 2")

  p <- load_zentra_ports_data()
  p$status[p$sn == "z6-13368" & p$port == 2] <- "excluded"
  save_zentra_ports(p)

  a <- attribute_readings(r)
  expect_false(any(a$port %in% 2))
  expect_false(any(attr(a, "unattributed_readings")$port %in% 2))
  # The logger's other sensors go on as before
  expect_true(any(a$port %in% 3))
})

test_that("readings after a logger's last deployment ended are 'after retirement'", {
  local_test_root()
  # 21180078 is t-0008, removed 2024-08-22: a reading after that, and nowhere current
  u <- reading("21180078", NA_integer_, "2025-03-01 10:00", "water_level")
  c <- classify_unattributed(u, deployment_windows(), load_known_unattributed())
  expect_equal(c$category, "retired")
  ep <- unattributed_episodes(c)
  printed <- utils::capture.output(print_unattributed(ep, load_zentra_metadata(), load_known_unattributed(),
                                                       now = at("2026-10-18 12:00")))
  expect_true(any(grepl("OUT OF THE FIELD - 1 moments from 1 logger(s) between deployments or retired: real HOBOlink",
                        printed, fixed = TRUE)))
})

test_that("a logger still deployed somewhere is not 'after retirement'", {
  local_test_root()
  # 90000002 ended at Reef Bay (t-0003) but is current at bta2 (t-0002)
  u <- reading("90000002", NA_integer_, "2024-11-01 10:00", "water_level")
  c <- classify_unattributed(u, deployment_windows(), load_known_unattributed())
  expect_false(c$category == "retired")
})

test_that("a build records what it left unexplained, and explaining it takes it off the list", {
  local_test_root()
  ep <- data.frame(category = "unexplained", device_serial = "z6-13368", ports = "2",
                   episode = "open:z6-13368:1", first = at("2026-09-01 10:00"),
                   last = at("2026-09-02 10:00"), moments = 5L, variables = "vwc",
                   stringsAsFactors = FALSE)
  save_unexplained(ep, "z6-13368 2026")
  expect_equal(nrow(load_unexplained()), 1)
  write_known(data.frame(device_serial = "z6-13368", device_name = "real ZL6", port = NA,
                         from = "2026-09-01 10:00:00", to = "2026-09-02 10:01:00", reason = "test"))
  expect_equal(nrow(load_unexplained()), 0)
  # A later build of another year leaves this one's rows alone
  save_unexplained(NULL, "z6-13368 2025")
  expect_equal(nrow(read_table("unexplained")), 1)
})

test_that("an archive-only logger is explained whole, and stops being asked about", {
  local_test_root()
  dl <- read_table("download_log")
  sn <- setdiff(unique(dl$device_serial), load_zentra_metadata()$device_serial)[1]
  out <- with_inputs(c("1", "retired, dropped from ZentraCloud", "Y", "Y"), ui_explain_unattributed(devices = no_cloud_devices()))
  expect_true(isTRUE(out$value))
  k <- load_known_unattributed()
  r <- k[k$device_serial == sn, ]
  expect_true(is.na(r$port) && is.na(r$from) && is.na(r$to))
  expect_true(r$archive)
  expect_true(sn %in% known_unattributed_loggers())
})

test_that("an unexplained period is explained with the build's own dates", {
  local_test_root()
  dl <- read_table("download_log")
  archive_only <- setdiff(unique(dl$device_serial), load_zentra_metadata()$device_serial)
  write_known(data.frame(device_serial = archive_only, device_name = NA, port = NA, from = NA, to = NA,
                         reason = "retired", archive = TRUE))
  save_unexplained(data.frame(category = "unexplained", device_serial = "z6-13368", ports = "8",
                              episode = "x", first = at("2021-09-10 10:00"), last = at("2021-09-10 10:15"),
                              moments = 2L, variables = "logger_pressure", stringsAsFactors = FALSE),
                   "z6-13368 2021")
  out <- with_inputs(c("1", "two stray readings before deployment", "Y"), ui_explain_unattributed(devices = no_cloud_devices()))
  expect_true(isTRUE(out$value))
  k <- load_known_unattributed()
  r <- k[k$device_serial == "z6-13368", ]
  expect_equal(as.numeric(r$from), as.numeric(at("2021-09-10 10:00")))
  expect_true(is.na(r$archive))
  expect_equal(nrow(load_unexplained()), 0)
})

test_that("validation catches a known row with no reason, or an archive choice on a period", {
  local_test_root()
  write_known(data.frame(device_serial = c("z6-1", "z6-2"), device_name = NA, port = c(NA, 2),
                         from = NA, to = NA, reason = c("", "a reason"), archive = c(NA, TRUE)))
  v <- validate_metadata(verbose = FALSE)$violations$KNOWN_UNATTRIBUTED_MALFORMED
  expect_equal(nrow(v$data), 2)
})

test_that("a known period on one port does not explain an episode on others", {
  local_test_root()
  write_table("unexplained", data.frame(
    device_serial = "z6-13368", ports = "1-4",
    first = as.POSIXct("2025-01-05", tz = PROJECT_TZ), last = as.POSIXct("2025-01-20", tz = PROJECT_TZ),
    moments = 100L, variables = "vwc", found_utc = Sys.time(), stringsAsFactors = FALSE), guard = FALSE)
  k <- table_empty("known_unattributed")
  row <- data.frame(device_serial = "z6-13368", device_name = "real ZL6", port = 2L,
                    from = as.POSIXct("2025-01-01", tz = PROJECT_TZ), to = as.POSIXct("2025-02-01", tz = PROJECT_TZ),
                    reason = "rain gauge being tested", archive = NA, stringsAsFactors = FALSE)
  write_table("known_unattributed", rbind(k, row[, names(k)]), guard = FALSE)
  expect_equal(nrow(load_unexplained()), 1)
  # Explained on every port, it is gone
  row$port <- NA_integer_
  write_table("known_unattributed", rbind(k, row[, names(k)]), guard = FALSE)
  expect_equal(nrow(load_unexplained()), 0)
  expect_equal(expand_ports("1-4, 6, 8"), c(1L, 2L, 3L, 4L, 6L, 8L))
})

test_that("a reading stamped exactly at a swap is out of the field, not unexplained", {
  local_test_root()
  # 90000002 left Reef Bay (t-0003) at 2024-11-05 10:00; it went in at bta2 weeks later
  m <- load_zentra_metadata()
  m$deploy_datetime[m$unique_id == "t-0002"] <- as.POSIXct("2024-12-01 14:00:00", tz = PROJECT_TZ)
  write_table("device_metadata", m, guard = FALSE)
  at_end <- reading("90000002", NA_integer_, "2024-11-05 10:00", "water_level")
  between <- reading("90000002", NA_integer_, "2024-11-15 12:00", "water_level")
  w <- deployment_windows()
  expect_equal(classify_unattributed(at_end, w, load_known_unattributed())$category, "retired")
  expect_equal(classify_unattributed(between, w, load_known_unattributed())$category, "retired")
})
