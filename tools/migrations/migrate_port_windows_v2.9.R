################################################################################
# migrate_port_windows_v2.9.R
#
# APPLIED: 2026-11-21
#
# Clips every port window to its deployment's - step 7b. A port row says this
# sensor was on this port, for this deployment, from this time to that; it
# cannot begin before the deployment did or run on after it ended.
#
#   valid_from before the deployment's start   ->  the deployment's start
#   valid_to after the deployment's end        ->  the deployment's end
#
# The deployment's dates are taken as the true ones (DAH): they were set by
# the workflow that made the change, or decided at step 4.4. Where the port's
# date is the better one instead, the fix is the deployment's date, made by
# hand before this runs - the dry run lists every case so that can be decided
# first.
#
# A port row lying wholly outside its deployment cannot be clipped - nothing
# would be left - so the migration stops, writes nothing, and lists it.
#
# Readings are only ever attributed inside both windows, so Product 2 is built
# from exactly what it was before; the snapshot comparison confirms it.
#
# Usage, after start.R:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
#                    "tools/migrations/migrate_port_windows_v2.9.R"))
#   migrate_port_windows()                 # dry run: lists every change
#   migrate_port_windows(dry_run = FALSE)  # applies it
################################################################################

migrate_port_windows <- function(dry_run = TRUE) {

  ports <- read_table("zentra_ports", remember = FALSE)
  meta  <- read_table("device_metadata", remember = FALSE)
  at <- match(ports$unique_id, meta$unique_id)
  if (any(is.na(at))) {
    stop("Port rows name deployments not in metadata - fix those first. Nothing written.",
         call. = FALSE)
  }
  d_start <- meta$deploy_datetime[at]
  d_end   <- meta$end_datetime[at]

  early <- !is.na(ports$valid_from) & !is.na(d_start) & ports$valid_from < d_start
  late  <- !is.na(ports$valid_to) & !is.na(d_end) & ports$valid_to > d_end
  touch <- which(early | late)

  if (length(touch) == 0) {
    cat("✓ Every port window lies inside its deployment - nothing to do\n")
    return(invisible(TRUE))
  }

  fmt <- function(x) ifelse(is.na(x), "(open)", format(x, "%Y-%m-%d %H:%M", tz = PROJECT_TZ))
  name <- function(i) paste0(meta$device_name[at[i]], " (", meta$station_id[at[i]], ", ",
                             ports$unique_id[i], ")")

  out <- ports
  out$valid_from[early] <- d_start[early]
  out$valid_to[late] <- d_end[late]

  # Clipped to nothing: the port lies wholly outside its deployment
  empty <- touch[!is.na(out$valid_to[touch]) & !is.na(out$valid_from[touch]) &
                   out$valid_to[touch] <= out$valid_from[touch]]

  cat("\nPort windows reaching outside their deployment: ", length(touch), "\n", sep = "")
  for (st in unique(meta$station_id[at[touch]])) {
    rows <- touch[meta$station_id[at[touch]] == st]
    cat("\n  ", st, "\n", sep = "")
    for (i in rows) {
      cat(sprintf("    %-38s port %d %-14s\n", name(i), ports$port[i],
                  if (is.na(ports$sensor[i])) "" else ports$sensor[i]))
      cat(sprintf("      deployment  %s -> %s\n", fmt(d_start[i]), fmt(d_end[i])))
      cat(sprintf("      port was    %s -> %s\n", fmt(ports$valid_from[i]), fmt(ports$valid_to[i])))
      cat(sprintf("      becomes     %s -> %s%s\n", fmt(out$valid_from[i]), fmt(out$valid_to[i]),
                  if (i %in% empty) "   WHOLLY OUTSIDE - cannot be clipped" else ""))
    }
  }

  if (length(empty) > 0) {
    stop(length(empty), " port row(s) lie wholly outside their deployment. Decide each ",
         "by hand - the wrong deployment, or the wrong dates - then run again. Nothing written.",
         call. = FALSE)
  }

  if (dry_run) {
    cat("\nDry run - nothing written. migrate_port_windows(dry_run = FALSE) to apply it.\n")
    return(invisible(out))
  }

  write_table("zentra_ports", out, guard = FALSE)

  #### Verify ####
  back <- read_table("zentra_ports", remember = FALSE)
  if (nrow(back) != nrow(ports)) stop("zentra_ports.csv did not read back as written", call. = FALSE)
  untouched <- setdiff(seq_len(nrow(ports)), touch)
  same <- isTRUE(all.equal(back[untouched, ], ports[untouched, ], check.attributes = FALSE))
  if (!same) stop("A port row that needed no clipping changed", call. = FALSE)
  res <- validate_metadata(verbose = FALSE)
  cat("\n✓ zentra_ports.csv written: ", length(touch), " window(s) clipped, every other row as it was\n",
      sep = "")
  if ("PORT_OUTSIDE_DEPLOYMENT" %in% names(res$violations)) {
    cat("✗ validation still finds port windows outside their deployments\n")
  } else {
    cat("✓ validation: every port window lies inside its deployment\n")
  }
  invisible(TRUE)
}
