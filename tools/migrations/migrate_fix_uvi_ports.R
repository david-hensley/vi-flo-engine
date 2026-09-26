# VI-FLO migration: correct the port configuration for z6-13368 (UVI)
#
# ONE-TIME SCRIPT.
#
# The ports for z6-13368 - the ZL6 serving uvi_weather and uvi_vwc1 - were
# recorded from half-recollection when zentra_ports.csv was first assembled,
# after the fact. Every vwc port carried valid_from = 2024-05-06, the day port
# 6 was added, and the depths were shifted by one position.
#
# The September 2026 ZentraCloud export settles it. Its configuration history
# is ZentraCloud's own record of when ports changed, and the readings
# themselves establish which depth each port sits at.
#
#
# WHAT THE EVIDENCE SHOWS
#
# Installation dates, from the export's configuration boundaries:
#
#   2023-11-06 10:45  ports 2,3,4,5 installed together
#   2024-02-16 12:30  port 2 stops returning values
#   2024-05-06 11:00  port 6 added
#   2024-11-10        port 2 returns five impossible values (0.97 - 1.05
#                     m3/m3, above saturation) then stops for good. Outside
#                     its validity window, so excluded by construction
#
# Depth ordering, from response lag to 49 rainfall events of >=5 mm since
# January 2025 - median hours from rain to a measurable rise, and how many
# events each port responded to at all:
#
#   port 6   0.00 h   30 of 49   shallowest
#   port 3   0.25 h   18
#   port 4   1.00 h    6
#   port 5  27.75 h    3         deepest
#
# A shallow sensor wets within the hour and drains fast; a deep one responds
# rarely and late. The ordering 6 - 3 - 4 - 5 is unambiguous.
#
# Against the standard install of 10/30/50/100 on ports 2-5, with port 6
# replacing port 2 at 10 cm after it failed, that gives:
#
#   port 2 = 10 cm (until it died), 3 = 30, 4 = 50, 5 = 100, 6 = 10
#
# which matches the lag ordering exactly.
#
#
# WHAT THIS CHANGES
#
#   port 2   valid_from -> 2023-11-06 10:45   valid_to -> 2024-02-16 12:30
#            status -> defunct.   Depth 10 cm was already correct
#   port 3   depth 10 -> 30       valid_from -> 2023-11-06 10:45
#   port 4   depth 30 -> 50       valid_from -> 2023-11-06 10:45
#   port 5   depth 50 -> 100      valid_from -> 2023-11-06 10:45
#   port 6   depth 100 -> 10      valid_from unchanged (2024-05-06 correct)
#   port 1   unchanged
#
# No maintenance entries are written. Nothing happened in the field - this
# corrects a record that was wrong when it was made.
#
# Safe to run twice: it checks the current values and exits if already applied.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_fix_uvi_ports.R"))

migrate_fix_uvi_ports <- function(dry_run = TRUE) {

  SN <- "z6-13368"

  # Local time, matching the file's convention. Derived from UTC timestamps in
  # the export: 2023-11-06 14:45 UTC and 2024-02-16 16:30 UTC.
  INSTALL <- "2023-11-06 10:45:00"
  P2_END  <- "2024-02-16 12:30:00"

  target <- data.frame(
    port       = 2:6,
    depth_cm   = c(10, 30, 50, 100, 10),
    valid_from = c(INSTALL, INSTALL, INSTALL, INSTALL, NA),
    valid_to   = c(P2_END, NA, NA, NA, NA),
    status     = c("defunct", NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )

  cat("\n============================================\n")
  cat("  Migration: correct ports for ", SN, "\n", sep = "")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  port_file <- file.path(wds("meta_internal"), "zentra_ports.csv")
  ports <- read.csv(port_file, stringsAsFactors = FALSE)

  rows <- which(ports$sn == SN)
  if (length(rows) == 0) {
    cat("X No rows for ", SN, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("Current:\n\n")
  for (i in rows) {
    cat("  Port ", ports$port[i], "  ", format(ports$sensor[i], width = 10),
        " depth ", format(as.character(ports$depth_cm[i]), width = 4),
        "  from ", format(as.character(ports$valid_from[i]), width = 20),
        "  to ", as.character(ports$valid_to[i]),
        "  status ", as.character(ports$status[i]), "\n", sep = "")
  }

  #### Work out what actually needs changing ####
  changes <- list()

  for (k in seq_len(nrow(target))) {
    pt <- target$port[k]
    i <- rows[as.character(ports$port[rows]) == as.character(pt)]
    if (length(i) != 1) {
      cat("\nX Expected exactly one row for port ", pt, ", found ", length(i),
          "\n\n", sep = "")
      return(invisible(FALSE))
    }

    same <- function(a, b) {
      if (is.na(b)) return(TRUE)                 # NA in target means leave alone
      !is.na(a) && trimws(as.character(a)) == trimws(as.character(b))
    }

    if (!same(ports$depth_cm[i], target$depth_cm[k]))
      changes[[length(changes) + 1]] <- list(i = i, col = "depth_cm",
        from = ports$depth_cm[i], to = target$depth_cm[k], port = pt)

    if (!same(ports$valid_from[i], target$valid_from[k]))
      changes[[length(changes) + 1]] <- list(i = i, col = "valid_from",
        from = ports$valid_from[i], to = target$valid_from[k], port = pt)

    if (!same(ports$valid_to[i], target$valid_to[k]))
      changes[[length(changes) + 1]] <- list(i = i, col = "valid_to",
        from = ports$valid_to[i], to = target$valid_to[k], port = pt)

    if (!same(ports$status[i], target$status[k]))
      changes[[length(changes) + 1]] <- list(i = i, col = "status",
        from = ports$status[i], to = target$status[k], port = pt)
  }

  if (length(changes) == 0) {
    cat("\n+ Already correct - nothing to do.\n\n")
    return(invisible(TRUE))
  }

  cat("\nChanges (", length(changes), "):\n\n", sep = "")
  for (ch in changes) {
    cat("  Port ", ch$port, "  ", format(ch$col, width = 11), " ",
        format(as.character(ch$from), width = 20), " -> ",
        as.character(ch$to), "\n", sep = "")
  }

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_fix_uvi_ports(dry_run = FALSE)\n\n")
    return(invisible(length(changes)))
  }

  #### Back up ####
  backup_dir <- file.path(wds("meta_internal"), "backups")
  if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("zentra_ports_", stamp, ".csv"))
  file.copy(port_file, backup_file)
  cat("\n+ Backed up to: ", basename(backup_file), "\n", sep = "")

  for (ch in changes) ports[[ch$col]][ch$i] <- ch$to

  write.csv(ports, port_file, row.names = FALSE)
  cat("+ Applied ", length(changes), " change(s)\n", sep = "")

  #### Verify ####
  check <- read.csv(port_file, stringsAsFactors = FALSE)
  crows <- which(check$sn == SN)

  cat("\nNow:\n\n")
  for (i in crows) {
    cat("  Port ", check$port[i], "  ", format(check$sensor[i], width = 10),
        " depth ", format(as.character(check$depth_cm[i]), width = 4),
        "  from ", format(as.character(check$valid_from[i]), width = 20),
        "  to ", as.character(check$valid_to[i]),
        "  status ", as.character(check$status[i]), "\n", sep = "")
  }

  ok <- TRUE

  # One active row per port
  active <- check[check$sn == SN & is.na(check$valid_to), ]
  if (any(duplicated(active$port))) {
    cat("\nX More than one active row for some port\n"); ok <- FALSE
  }

  # Active vwc depths must be distinct - two sensors cannot share a depth
  vwc <- active[active$type == "vwc" & !is.na(active$depth_cm), ]
  if (any(duplicated(vwc$depth_cm))) {
    cat("\nX Two active vwc ports share a depth\n"); ok <- FALSE
  }

  if (!ok) {
    cat("\nX Verification FAILED. Restore from:\n  ", backup_file, "\n\n", sep = "")
    return(invisible(FALSE))
  }

  cat("\n+ Verified: one active row per port, active vwc depths distinct\n\n")
  cat("NEXT: run validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_fix_uvi_ports(dry_run = TRUE)
