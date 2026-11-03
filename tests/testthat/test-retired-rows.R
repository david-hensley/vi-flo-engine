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

for (status in c("removed", "replaced", "relocated", "decommissioned")) {
  test_that(paste0("a routine visit leaves a ", status, " row's date alone"), {
    local_test_root()
    add_retired_row(status)
    expect_true(isTRUE(update_last_visit("bta2_hydro", as.Date("2026-10-27"))))
    expect_equal(lv("t-0999"), "2024-08-14")
    expect_equal(lv("t-0001"), "2026-10-27")                # the deployment still there
  })
}

test_that("retire_row dates the row to the day its logger left", {
  local_test_root()
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(retire_row("t-0001", when, close_ports = FALSE)))
  expect_equal(lv("t-0001"), "2026-10-29")
})

test_that("retire_row closes the logger's open ports at that moment, not now", {
  local_test_root()
  uid <- load_zentra_metadata()
  uid <- uid$unique_id[uid$device_serial == "z6-13368"][1]
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(retire_row(uid, when)))
  p <- load_zentra_ports_data()
  p <- p[p$sn == "z6-13368" & !is.na(p$sensor) & p$sensor != "none", ]
  expect_true(all(!is.na(p$valid_to)))
  expect_true(all(format(p$valid_to, "%Y-%m-%d %H:%M", tz = "America/Puerto_Rico") ==
                  "2026-10-29 12:15"))
})

test_that("a port already closed keeps its own date", {
  local_test_root()
  path <- file.path(wds("meta_internal"), "zentra_ports.csv")
  p <- read.csv(path, stringsAsFactors = FALSE)
  p$valid_to[p$sn == "z6-13368" & p$port == 2] <- "2024-02-16 00:00:00"
  write.csv(p, path, row.names = FALSE, na = "")
  uid <- load_zentra_metadata()
  uid <- uid$unique_id[uid$device_serial == "z6-13368"][1]
  retire_row(uid, as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico"))
  p <- load_zentra_ports_data()
  expect_equal(format(p$valid_to[p$sn == "z6-13368" & p$port == 2], "%Y-%m-%d", tz = "America/Puerto_Rico"),
               "2024-02-16")
})

test_that("a removal dates the removed row to the removal, and visits its partner", {
  local_test_root()
  when <- as.POSIXct("2026-10-28 10:00:00", tz = "America/Puerto_Rico")
  expect_true(isTRUE(remove_device("90000002", when)))     # bta2_hydro's secondary
  m <- load_zentra_metadata()
  r <- m[m$unique_id == "t-0002", ]
  expect_equal(r$status, "removed")
  expect_equal(lv("t-0002"), "2026-10-28")
  expect_equal(lv("t-0001"), "2026-10-28")                  # the primary was visited too
  # And a later visit leaves it there
  update_last_visit("bta2_hydro", as.Date("2026-11-15"))
  expect_equal(lv("t-0002"), "2026-10-28")
})

test_that("a replaced row's deployment ends at its replacement, for Product 2", {
  local_test_root()
  # The old logger came out when its replacement went in
  when <- as.POSIXct("2026-10-29 12:15:00", tz = "America/Puerto_Rico")
  update_device_status("90000001", "replaced", station_id = "bta2_hydro")
  retire_row("t-0001", when)
  w <- deployment_windows()
  w <- w[w$unique_id == "t-0001", ]
  expect_equal(w$end_basis, "last visit")
  expect_equal(format(w$ends, "%Y-%m-%d", tz = "America/Puerto_Rico"), "2026-10-29")
})
