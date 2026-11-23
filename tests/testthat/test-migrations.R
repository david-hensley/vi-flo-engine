# Migrations that change real metadata, tried on the fixtures first

source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
                 "tools/migrations/migrate_day_end_placeholders_v2.9.R"))

test_that("a retired row ending at 23:59:59 on its successor's day ends when the successor went in", {
  local_test_root()
  m <- load_zentra_metadata()
  old <- m[m$unique_id == "t-0007", ]
  old$unique_id <- "t-0099"
  old$device_serial <- "21652300"
  old$device_name <- "old U20"
  old$status <- "replaced"
  old$deploy_datetime <- as.POSIXct("2025-01-01 12:00:00", tz = PROJECT_TZ)
  old$end_datetime <- as.POSIXct("2026-08-01 23:59:59", tz = PROJECT_TZ)
  # A removal the same day another logger went in is not a swap: left alone
  gone <- old
  gone$unique_id <- "t-0098"
  gone$device_serial <- "21652301"
  gone$status <- "removed"
  write_table("device_metadata", rbind(m, old, gone), guard = FALSE)
  n_before <- nrow(read_log())

  dry <- capture.output(migrate_day_end_placeholders())
  expect_match(paste(dry, collapse = "\n"), "ends 2026-08-01 23:59 -> 12:00", fixed = TRUE)
  expect_equal(format(meta_row("t-0099")$end_datetime, "%H:%M:%S"), "23:59:59")

  # A port that closed later that day closes with the row, at the successor's time
  p <- read_table("zentra_ports")
  write_table("zentra_ports", rbind(p, data.frame(
    unique_id = "t-0099", port = 1, sensor = "x", depth_cm = NA, status = NA,
    valid_from = as.POSIXct("2025-01-01 12:00:00", tz = PROJECT_TZ),
    valid_to = as.POSIXct("2026-08-01 12:01:35", tz = PROJECT_TZ))), guard = FALSE)

  capture.output(migrate_day_end_placeholders(dry_run = FALSE))
  expect_equal(format(meta_row("t-0099")$end_datetime, "%Y-%m-%d %H:%M:%S"), "2026-08-01 12:00:00")
  p <- read_table("zentra_ports")
  expect_equal(format(p$valid_to[p$unique_id == "t-0099"], "%H:%M:%S"), "12:00:00")
  # Removals are left as they were
  expect_equal(format(meta_row("t-0098")$end_datetime, "%H:%M:%S"), "23:59:59")
  expect_equal(format(meta_row("t-0008")$end_datetime, "%H:%M:%S"), "23:59:59")
  log <- read_log()
  expect_equal(nrow(log), n_before + 1)
  expect_match(log$details[nrow(log)], "when its successor went in", fixed = TRUE)
})
