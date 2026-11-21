# A retired row - removed, replaced, relocated, decommissioned - is dated once,
# when it is retired, to the moment its logger left; Product 2 ends its
# deployment there. A later visit to the station must not move it.
#
# Why: a routine visit used to re-date every row at the station but relocated
# and decommissioned ones, so TR1's HOBOlink, destroyed 2024-08-14, came back
# into tr1_hydro's Product 2 after a visit in October 2026. And a replacement
# left the old row's date where it was (Dorothea and Turpentine Weather ended
# in March, losing seven months) and closed its ports at Sys.time().

meta_path <- function() file.path(wds("meta_internal"), "device_metadata.csv")
add_retired_row <- function(status, last_visit = "2024-08-14", serial = "90000099") {
  m <- read.csv(meta_path(), stringsAsFactors = FALSE, colClasses = "character")
  old <- m[m$unique_id == "t-0001", ]                      # bta2_hydro's primary
  old$unique_id <- "t-0999"; old$device_serial <- serial
  old$status <- status; old$last_visit <- last_visit
  write.csv(rbind(m, old), meta_path(), row.names = FALSE, na = "NA")
}
lv <- function(uid) {
  m <- load_zentra_metadata()
  format(as.Date(m$last_visit[m$unique_id == uid]), "%Y-%m-%d")
}
ends_at <- function(uid) {
  m <- load_zentra_metadata()
  format(m$end_datetime[m$unique_id == uid], "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico")
}

for (status in c("removed", "replaced", "relocated", "decommissioned")) {
  test_that(paste0("a routine visit leaves a ", status, " row's date alone"), {
    local_test_root()
    add_retired_row(status)
    expect_true(isTRUE(update_last_visit("bta2_hydro", as.Date("2026-10-27"))))
    expect_equal(lv("t-0999"), "2024-08-14")
    expect_equal(lv("t-0001"), "2026-10-27")                # the deployment still there
  })
}

test_that("retire_row ends the deployment at the moment its logger left", {
  local_test_root()
  before <- lv("t-0001")
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(retire_row("t-0001", when, close_ports = FALSE, status = "removed")))
  expect_equal(ends_at("t-0001"), "2026-10-29 12:15")
  expect_equal(lv("t-0001"), before)                        # the last visit is what it was
})

test_that("retire_row closes its own deployment's open ports at that moment, not now", {
  local_test_root()
  # z6-13368 serves zzu_weather (t-0009, its ATMOS) and zzu_vwc1 (t-0010,
  # its TEROS). Retiring the vwc station closes the TEROS ports only
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(retire_row("t-0010", when, status = "removed")))
  p <- load_zentra_ports_data()
  mine <- p[p$unique_id == "t-0010", ]
  expect_true(nrow(mine) > 0)
  expect_true(all(format(mine$valid_to, "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico") ==
                  "2026-10-29 12:15"))
  # The weather station on the same logger keeps its ATMOS open
  expect_true(all(is.na(p$valid_to[p$unique_id == "t-0009"])))
  expect_equal(validate_metadata(verbose = FALSE)$violations$TERMINAL_DEVICE_ACTIVE_PORTS, NULL)
})

test_that("an ended deployment's open port is flagged even while its logger runs on elsewhere", {
  local_test_root()
  # As a relocation that forgot its ports would leave it: the old row ended,
  # the logger at work under a new one, the old row's ports still open
  m <- read_table("device_metadata")
  new <- m[m$unique_id == "t-0011", ]
  new$unique_id <- "t-0098"
  m$status[m$unique_id == "t-0011"] <- "relocated"
  m$end_datetime[m$unique_id == "t-0011"] <- as.POSIXct("2026-11-01 10:00:00", tz = PROJECT_TZ)
  write_table("device_metadata", rbind(m, new), guard = FALSE)
  v <- validate_metadata(verbose = FALSE)$violations$TERMINAL_DEVICE_ACTIVE_PORTS
  expect_false(is.null(v))
  expect_true(all(v$data$unique_id == "t-0011"))
})

test_that("a port already closed keeps its own date", {
  local_test_root()
  p <- load_zentra_ports_data()
  p$valid_to[p$sn == "z6-13368" & p$port == 2] <- as.POSIXct("2024-02-16 00:00:00",
                                                             tz = "America/Puerto_Rico")
  save_zentra_ports(p)
  uid <- load_zentra_metadata()
  uid <- uid$unique_id[uid$device_serial == "z6-13368"][1]
  retire_row(uid, as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico"), status = "removed")
  p <- load_zentra_ports_data()
  expect_equal(format(p$valid_to[p$sn == "z6-13368" & p$port == 2], "%Y-%m-%d", tz = "America/Puerto_Rico"),
               "2024-02-16")
})

test_that("a removal dates the removed row to the removal, and visits its partner", {
  local_test_root()
  when <- as.POSIXct("2026-10-28 10:00:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(remove_device("t-0002", when)))       # bta2_hydro's secondary
  m <- load_zentra_metadata()
  r <- m[m$unique_id == "t-0002", ]
  expect_equal(r$status, "removed")
  expect_equal(ends_at("t-0002"), "2026-10-28 10:00")
  expect_equal(lv("t-0001"), "2026-10-28")                  # the primary was visited too
  # And a later visit leaves its end where it is
  update_last_visit("bta2_hydro", as.Date("2026-11-15"))
  expect_equal(ends_at("t-0002"), "2026-10-28 10:00")
})

test_that("a replaced row's deployment ends at its replacement, for Product 2", {
  local_test_root()
  # The old logger came out when its replacement went in
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  update_device_status("90000001", "replaced", station_id = "bta2_hydro")
  retire_row("t-0001", when)
  w <- deployment_windows()
  w <- w[w$unique_id == "t-0001", ]
  expect_equal(w$end_basis, "end")
  expect_equal(format(w$ends, "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico"), "2026-10-29 12:15")
})

test_that("an entry is given the deployment serving on the day of the visit", {
  local_test_root()
  meta <- load_zentra_metadata()
  # 90000002 has a row at bta2_hydro (t-0002) and one at rb2_hydro (t-0003):
  # the station decides
  expect_equal(resolve_deployment("90000002", "bta2_hydro", "2026-10-14"), "t-0002")
  expect_equal(resolve_deployment("90000002", "rb2_hydro", "2026-10-14"), "t-0003")
  expect_true(is.na(resolve_deployment("90000002", "srl1_pond", "2026-10-14")))

  # A move within a station: two rows, the old ending and the new beginning on
  # the same day. The entry for that day belongs to the new position
  old <- meta[meta$unique_id == "t-0005", ]
  new <- old
  new$unique_id <- "t-0099"
  new$deploy_datetime <- as.POSIXct("2026-06-01 10:00:00", tz = "America/Puerto_Rico")
  old$status <- "relocated"
  old$last_visit <- as.Date(NA)       # as at fb1_weather: it ends where the new one starts
  meta2 <- rbind(meta[meta$unique_id != "t-0005", ], old, new)
  expect_equal(resolve_deployment("z6-90001", "uvi_weather", "2026-06-01", meta2), "t-0099")
  expect_equal(resolve_deployment("z6-90001", "uvi_weather", "2026-05-01", meta2), "t-0005")
})

#### Ports name their deployment ####

PORTS_WEATHER_AND_VWC <- data.frame(
  port = 1:6,
  type = c("weather", "vwc", "vwc", "none", "none", "none"),
  sensor = c("ATMOS 41", "TEROS 10", "TEROS 10", "none", "none", "none"),
  depth_cm = c(NA, 10, 30, NA, NA, NA), status = NA, stringsAsFactors = FALSE)

test_that("on a shared logger, each sensor's row names the station it serves", {
  local_test_root()
  # z6-90001 serves uvi_weather (t-0005) and uvi_vwc1 (t-0006), and has no ports yet
  expect_true(initialize_ports("z6-90001", PORTS_WEATHER_AND_VWC))
  p <- read_table("zentra_ports")
  mine <- p[p$unique_id %in% c("t-0005", "t-0006"), ]
  expect_equal(nrow(mine), 3)                               # empty ports have no row
  expect_equal(mine$unique_id[mine$port == 1], "t-0005")
  expect_equal(sort(mine$unique_id[mine$port != 1]), c("t-0006", "t-0006"))
})

test_that("changing one port closes it and opens its successor on the right deployment", {
  local_test_root()
  initialize_ports("z6-90001", PORTS_WEATHER_AND_VWC)
  new <- PORTS_WEATHER_AND_VWC
  new$depth_cm[3] <- 50
  new$sensor[2] <- "none"; new$type[2] <- "none"
  when <- as.POSIXct("2026-11-01 10:00:00", tz = "America/Puerto_Rico")
  expect_true(update_ports("z6-90001", new, when))
  p <- read_table("zentra_ports")
  p <- p[p$unique_id %in% c("t-0005", "t-0006"), ]
  expect_equal(sum(is.na(p$valid_to)), 2)                   # the ATMOS, and port 3 at 50 cm
  expect_equal(p$depth_cm[p$port == 3 & is.na(p$valid_to)], 50)
  expect_equal(p$valid_to[p$port == 2], when)               # port 2 emptied: closed, no new row
  expect_equal(sum(p$port == 2), 1)
})

test_that("a move carries the logger's open ports to the deployment it created", {
  local_test_root()
  when <- as.POSIXct("2026-11-01 10:00:00", tz = "America/Puerto_Rico")
  # The deployment the move created
  m <- read_table("device_metadata")
  new <- m[m$unique_id == "t-0011", ]
  new$unique_id <- "t-0099"; new$deploy_datetime <- when
  m$status[m$unique_id == "t-0011"] <- "relocated"; m$end_datetime[m$unique_id == "t-0011"] <- when
  write_table("device_metadata", rbind(m, new), guard = FALSE)
  expect_true(carry_ports_over("t-0011", "t-0099", when))
  p <- read_table("zentra_ports")
  expect_true(all(p$valid_to[p$unique_id == "t-0011"] == when))
  expect_equal(sum(p$unique_id == "t-0099"), 4)
  expect_true(all(p$valid_from[p$unique_id == "t-0099"] == when))
  expect_true(all(is.na(p$valid_to[p$unique_id == "t-0099"])))
})

test_that("removing a shared ZL6 ends every station it served", {
  local_test_root()
  # z6-13368 serves zzu_weather (t-0009) and zzu_vwc1 (t-0010): the box came
  # out, so both deployments end at that moment
  when <- as.POSIXct("2026-11-01 10:00:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(remove_device("t-0010", when)))
  expect_equal(meta_row("t-0010")$status, "removed")
  expect_equal(meta_row("t-0009")$status, "removed")
  expect_equal(ends_at("t-0009"), "2026-11-01 10:00")
  p <- load_zentra_ports_data()
  expect_false(any(is.na(p$valid_to[p$unique_id %in% c("t-0009", "t-0010")])))
  # The logger's retired deployments elsewhere are left as they were
  expect_true(isTRUE(validate_metadata(verbose = FALSE)$valid) ||
                !"TERMINAL_DEVICE_ACTIVE_PORTS" %in% names(validate_metadata(verbose = FALSE)$violations))
})

test_that("the removal workflow says what else ends, and stops if the logger stayed", {
  local_test_root()
  before <- load_zentra_metadata()
  # zzu_vwc1, its logger; asked whether the box came out: no
  out <- with_inputs(c(which(sort(unique(before$station_id[!tolower(before$status) %in% TERMINAL_STATUSES])) == "zzu_vwc1"),
                       "1", "N"), ui_remove_device())
  expect_true(any(grepl("also serves zzu_weather", out$output)))
  expect_identical(load_zentra_metadata(), before)
})

test_that("a relocation moves the station's current loggers, not its retired ones", {
  local_test_root()
  # bta2_hydro gets a removed logger in its past
  m <- read_table("device_metadata")
  old <- m[m$unique_id == "t-0002", ]
  old$unique_id <- "t-0097"; old$device_serial <- "90000097"; old$device_role <- NA
  old$deploy_datetime <- as.POSIXct("2023-01-01 10:00:00", tz = PROJECT_TZ)
  old$end_datetime <- as.POSIXct("2024-01-01 10:00:00", tz = PROJECT_TZ)
  old$status <- "removed"
  write_table("device_metadata", rbind(m, old), guard = FALSE)
  res <- relocate_station("bta2_hydro", 17.72, -64.80,
                          as.POSIXct("2026-11-10 10:00:00", tz = PROJECT_TZ), "manual", TRUE)
  expect_true(isTRUE(res$success))
  expect_equal(length(res$new_unique_ids), 2)                 # bta2a and bta2b, not the removed one
  expect_equal(meta_row("t-0097")$status, "removed")
})
