################################################################################
# migrate_retired_dates.R
#
# APPLIED: not yet
#
# Repairs the dates on retired rows that three bugs had moved, found after the
# October 2026 St Thomas / St John trip (fixed in the same release):
#
#   1. A routine visit re-dated every row at its station but relocated and
#      decommissioned ones - so removed and replaced rows took this trip's
#      visit dates, and their Product 2 deployments ran to October 2026. TR1's
#      HOBOlink, destroyed 2024-08-14, came back into tr1_hydro.
#   2. A replacement left the old row's last_visit where it was, so Dorothea
#      and Turpentine Weather ended at their March visits, losing seven months.
#   3. A replacement closed the old logger's ports at Sys.time() - the moment
#      the swap was typed in, on 30 October - not when the new logger went in.
#
# For a retired row, last_visit is the day its deployment ended. The values
# restored here are each row's own: for the HOBO rows retired before the trip,
# their dates before it (the metadata copy of 2026-10-14); for rows retired by
# a replacement, the day the replacement went in.
#
# Also records three periods in known_unattributed.csv, confirmed by DAH:
# z6-30132's Shadehouses 2025 record before it became Dorothea Weather; the
# old Turpentine Weather logger, still reporting after its replacement; and the
# end of R2R Farm's storage-shed period, when it went in at fb2_vwc1.
#
# Every change is guarded on the value it expects to find: a value that is
# neither the old one nor the new one stops the migration, and nothing is
# written.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_retired_dates.R"))
#   migrate_retired_dates()                 # dry run
#   migrate_retired_dates(dry_run = FALSE)  # applies it
################################################################################

#### Editing a CSV as text: only the fields that change ####
# The metadata files are written with numbers, NA and TRUE unquoted. Reading
# everything as character and writing it back quotes all of them - every line
# differs though no value does. So the lines are edited in place: a changed
# field keeps its quoting, every other byte of the file stays as it was.
csv_lines <- function(f) {
  b <- readBin(f, "raw", file.info(f)$size)
  list(lines = strsplit(rawToChar(b), "\n", fixed = TRUE)[[1]],
       final_newline = length(b) > 0 && b[length(b)] == as.raw(10))
}
csv_split <- function(line) {
  cr <- endsWith(line, "\r"); if (cr) line <- substr(line, 1, nchar(line) - 1)
  out <- character(0); i <- 1; n <- nchar(line); cur <- ""; inq <- FALSE
  chars <- strsplit(line, "")[[1]]
  while (i <= n) {
    ch <- chars[i]
    if (inq) {
      if (ch == '"' && i < n && chars[i + 1] == '"') { cur <- paste0(cur, '""'); i <- i + 1 }
      else if (ch == '"') { cur <- paste0(cur, ch); inq <- FALSE }
      else cur <- paste0(cur, ch)
    } else if (ch == '"') { cur <- paste0(cur, ch); inq <- TRUE }
    else if (ch == ",") { out <- c(out, cur); cur <- "" }
    else cur <- paste0(cur, ch)
    i <- i + 1
  }
  list(fields = c(out, cur), cr = cr)
}
csv_value <- function(field) {
  if (startsWith(field, '"') && endsWith(field, '"')) gsub('""', '"', substr(field, 2, nchar(field) - 1)) else field
}
csv_set <- function(field, value) if (startsWith(field, '"')) paste0('"', value, '"') else value
# edits: function(values named by column) -> named list of column = new value, or NULL
csv_edit <- function(f, edits) {
  x <- csv_lines(f)
  header <- vapply(csv_split(x$lines[1])$fields, csv_value, character(1))
  changed <- 0
  for (i in seq_along(x$lines)[-1]) {
    if (!nzchar(x$lines[i])) next
    sp <- csv_split(x$lines[i])
    vals <- setNames(vapply(sp$fields, csv_value, character(1)), header)
    new <- edits(vals)
    if (is.null(new)) next
    for (col in names(new)) {
      k <- match(col, header)
      sp$fields[k] <- csv_set(sp$fields[k], new[[col]])
    }
    x$lines[i] <- paste0(paste(sp$fields, collapse = ","), if (sp$cr) "\r" else "")
    changed <- changed + 1
  }
  out <- paste(x$lines, collapse = "\n")
  if (x$final_newline) out <- paste0(out, "\n")
  writeBin(charToRaw(out), f)
  changed
}

migrate_retired_dates <- function(dry_run = TRUE) {

  meta_dir <- wds("meta_internal")
  f_meta  <- file.path(meta_dir, "device_metadata.csv")
  f_ports <- file.path(meta_dir, "zentra_ports.csv")
  f_known <- file.path(meta_dir, "known_unattributed.csv")
  raw <- function(f) read.csv(f, stringsAsFactors = FALSE, colClasses = "character",
                              na.strings = character(0))

  #### The changes ####
  visits <- data.frame(
    unique_id = c("z-0015", "z-0014", "z-0019", "z-0026", "z-0008", "z-0011", "z-0004",
                  "h-0021", "h-0022", "h-0023", "h-0024", "h-0025", "h-0026"),
    from = c("2026-03-24", "2026-03-23", "2026-10-30", "2026-10-27", "2026-10-27",
             "2026-09-18", "2026-09-16",
             "2026-10-28", "2026-10-28", "2026-10-28", "2026-10-27", "2026-10-27", "2026-10-27"),
    to   = c("2026-10-29", "2026-10-29", "2026-10-28", "2026-10-26", "2026-09-04",
             "2026-09-04", "2026-09-11",
             "2023-10-09", "2024-10-24", "2025-11-06", "2024-10-22", "2024-06-04", "2024-08-14"),
    why  = c("replaced 2026-10-29 by z6-30132", "replaced 2026-10-29 by z6-38175",
             "replaced 2026-10-28 by z6-34719", "replaced 2026-10-26 by z6-13370",
             "replaced 2026-09-04 by z6-38175", "replaced 2026-09-04 by z6-38174",
             "replaced 2026-09-11 by z6-37439",
             rep("removed then - restored from before the trip", 6)),
    stringsAsFactors = FALSE)

  ports <- data.frame(
    sn   = c("z6-12885", "z6-12874", "z6-13375", rep("z6-13379", 5), rep("z6-38175", 4)),
    port = c("1", "1", "1", "1", "2", "3", "4", "5", "1", "2", "3", "4"),
    from = c("2026-10-30 15:14:49", "2026-10-30 15:27:17", "2026-10-30 15:12:39",
             rep("2026-10-30 15:08:57", 5), rep("2026-10-26 19:31:23", 4)),
    to   = c("2026-10-29 12:15:00", "2026-10-29 15:00:00", "2026-10-28 13:30:00",
             rep("2026-10-28 14:30:00", 5), rep("2026-10-26 16:00:00", 4)),
    stringsAsFactors = FALSE)

  known_new <- data.frame(
    device_serial = c("z6-12874", "z6-30132"),
    device_name   = c("Turpentine Weather", "Shadehouses 2025 logger"),
    port          = c("", ""),
    from          = c("2026-10-29 15:00:00", ""),
    to            = c("", "2026-10-29 12:15:00"),
    reason        = c("Replaced at tr1_weather; out of service, still reporting",
                      "Shadehouses 2025 logger, recording from 2025-01-30; not VI-FLO - before dor1_weather"),
    stringsAsFactors = FALSE)
  r2r_end <- "2026-10-28 14:30:00"

  #### Read, and check every value is either the old one or the new ####
  meta <- raw(f_meta); pts <- raw(f_ports); known <- raw(f_known)
  problems <- character(0)

  vi <- match(visits$unique_id, meta$unique_id)
  if (any(is.na(vi))) problems <- c(problems, paste("Row not found:", visits$unique_id[is.na(vi)]))
  now_v <- meta$last_visit[vi]
  bad <- !is.na(vi) & !(now_v == visits$from | now_v == visits$to)
  for (i in which(bad)) problems <- c(problems, sprintf("%s last_visit is %s - expected %s or %s",
                                                        visits$unique_id[i], now_v[i], visits$from[i], visits$to[i]))

  pi <- vapply(seq_len(nrow(ports)), function(i) {
    w <- which(pts$sn == ports$sn[i] & pts$port == ports$port[i] &
               (pts$valid_to == ports$from[i] | pts$valid_to == ports$to[i]))
    if (length(w) == 1) w else NA_integer_
  }, integer(1))
  for (i in which(is.na(pi))) problems <- c(problems, sprintf(
    "%s port %s: no single closed window ending %s (or %s)", ports$sn[i], ports$port[i], ports$from[i], ports$to[i]))

  r2r <- which(known$device_serial == "z6-14637" & known$from == "2026-09-11 13:46:06")
  if (length(r2r) != 1) problems <- c(problems, "R2R Farm's shed period not found in known_unattributed.csv")
  else if (!known$to[r2r] %in% c("", "NA", r2r_end)) problems <- c(problems,
    paste("R2R Farm's shed period already ends at", known$to[r2r]))

  if (length(problems) > 0) {
    cat("\nStopped - nothing written. These are not what the migration expects:\n")
    for (p in problems) cat("  ", p, "\n", sep = "")
    return(invisible(FALSE))
  }

  #### What would change ####
  todo_v <- now_v != visits$to
  todo_p <- pts$valid_to[pi] != ports$to
  todo_k <- !paste(known_new$device_serial, known_new$from, known_new$to) %in%
              paste(known$device_serial, known$from, known$to)
  todo_r <- !identical(known$to[r2r], r2r_end)

  if (!any(todo_v) && !any(todo_p) && !any(todo_k) && !todo_r) {
    message("\u2713 Already applied - every date is repaired. Nothing to do.")
    return(invisible(TRUE))
  }

  cat("\n--- RETIRED ROWS: last_visit ---\n")
  for (i in which(todo_v)) cat(sprintf("  %s  %-14s %s -> %s   %s\n", visits$unique_id[i],
                                       meta$station_id[vi[i]], now_v[i], visits$to[i], visits$why[i]))
  cat("\n--- PORT WINDOWS: closed at the swap, not when it was entered ---\n")
  for (i in which(todo_p)) cat(sprintf("  %s port %s  %s -> %s\n", ports$sn[i], ports$port[i],
                                       pts$valid_to[pi[i]], ports$to[i]))
  cat("\n--- KNOWN UNATTRIBUTED ---\n")
  for (i in which(todo_k)) cat(sprintf("  add   %s %s to %s: %s\n", known_new$device_serial[i],
                                       if (nzchar(known_new$from[i])) known_new$from[i] else "(start)",
                                       if (nzchar(known_new$to[i])) known_new$to[i] else "(open)",
                                       known_new$reason[i]))
  if (todo_r) cat(sprintf("  end   z6-14637 R2R Farm's shed period at %s, when it went in at fb2_vwc1\n", r2r_end))

  if (dry_run) {
    cat("\nDry run - nothing written. Run with dry_run = FALSE to apply.\n")
    return(invisible(NULL))
  }

  #### Apply ####
  backup_metadata()
  dv <- visits[todo_v, ]
  n_meta <- csv_edit(f_meta, function(v) {
    i <- match(v[["unique_id"]], dv$unique_id)
    if (is.na(i) || v[["last_visit"]] != dv$from[i]) NULL else list(last_visit = dv$to[i])
  })
  dp <- ports[todo_p, ]
  n_ports <- csv_edit(f_ports, function(v) {
    i <- which(dp$sn == v[["sn"]] & dp$port == v[["port"]] & dp$from == v[["valid_to"]])
    if (length(i) != 1) NULL else list(valid_to = dp$to[i])
  })
  # known_unattributed.csv was written by write.csv() whole, by its own
  # migration, so it is rewritten the same way
  if (todo_r) known$to[r2r] <- r2r_end
  if (any(todo_k)) known <- rbind(known, known_new[todo_k, names(known)])
  when <- ifelse(known$from %in% c("", "NA"), known$to, known$from)
  known <- known[order(when, decreasing = TRUE), , drop = FALSE]
  write.csv(known, f_known, row.names = FALSE, na = "")
  if (n_meta != sum(todo_v) || n_ports != sum(todo_p)) {
    stop("Changed ", n_meta, " metadata and ", n_ports, " port line(s); expected ",
         sum(todo_v), " and ", sum(todo_p), " - restore from metadata/internal/backups")
  }

  #### Verify, through the engine's own readers ####
  m <- load_zentra_metadata()
  w <- deployment_windows(m)
  ok_v <- all(format(as.Date(m$last_visit[match(visits$unique_id, m$unique_id)]), "%Y-%m-%d") == visits$to)
  ends <- w[match(visits$unique_id, w$unique_id), ]
  ok_w <- all(format(ends$ends, "%Y-%m-%d", tz = "America/Puerto_Rico") <= visits$to)
  p2 <- load_zentra_ports_data()
  got <- vapply(seq_len(nrow(ports)), function(i) {
    v <- p2$valid_to[p2$sn == ports$sn[i] & p2$port == as.integer(ports$port[i]) & !is.na(p2$valid_to)]
    any(format(v, "%Y-%m-%d %H:%M:%S", tz = "America/Puerto_Rico") == ports$to[i])
  }, logical(1))
  k <- load_known_unattributed()
  ok_k <- all(known_new$device_serial %in% k$device_serial) &&
          !is.na(k$to[k$device_serial == "z6-14637"][1])
  cat("\n--- VERIFICATION ---\n")
  cat(if (ok_v) "\u2713" else "\u274c", " ", nrow(visits), " retired rows dated to the day they left\n", sep = "")
  cat(if (ok_w) "\u2713" else "\u274c", " Their Product 2 deployments end by those dates\n", sep = "")
  cat(if (all(got)) "\u2713" else "\u274c", " ", nrow(ports), " port windows close at their swaps\n", sep = "")
  cat(if (ok_k) "\u2713" else "\u274c", " Known periods recorded\n", sep = "")
  if (!(ok_v && ok_w && all(got) && ok_k)) stop("Verification failed - restore from metadata/internal/backups")
  cat("\n\u2713 Retired dates repaired. Products are stale now: build_p2_stale() rebuilds what they changed.\n")
  invisible(TRUE)
}
