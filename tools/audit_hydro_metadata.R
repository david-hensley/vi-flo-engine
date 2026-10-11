# VI-FLO: audit the hydro metadata against the data
#
# Read-only. Writes nothing, changes nothing.
#
# After a run of migrations it is worth seeing the result rather than trusting
# the sequence of edits that produced it. For every hydro row this compares
# what metadata says against what the Product 1 files and the download log
# actually contain, and flags anything that does not agree.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/audit_hydro_metadata.R"))
#   audit_hydro_metadata()

audit_hydro_metadata <- function() {

  TZ <- "America/Puerto_Rico"
  TERMINAL <- c("removed", "replaced", "relocated", "decommissioned")

  meta <- load_zentra_metadata()
  dl   <- tryCatch(load_download_log(), error = function(e) NULL)

  as_utc <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "UTC"; x }
  parse_local <- function(x) as_utc(suppressWarnings(as.POSIXct(x, tz = TZ)))

  hy <- meta[meta$station_type == "hydro", , drop = FALSE]
  hy <- hy[order(hy$station_id, hy$deploy_datetime), , drop = FALSE]

  cat("\n############################################\n")
  cat("  Hydro metadata against the data\n")
  cat("############################################\n\n")

  issues <- character(0)

  cat(sprintf("  %-10s %-11s %-10s %-14s %-11s %-11s %-6s\n",
              "serial", "station", "role", "status", "last record",
              "last dl", "iv"))
  cat("  ", strrep("-", 80), "\n", sep = "")

  for (r in seq_len(nrow(hy))) {
    sn <- hy$device_serial[r]
    st <- hy$station_id[r]

    cat(sprintf("  %-10s %-11s %-10s %-14s %-11s %-11s %-6s\n",
                sn, st, substr(ifelse(is.na(hy$device_role[r]), "-",
                                      hy$device_role[r]), 1, 10),
                hy$status[r],
                substr(ifelse(is.na(hy$last_record_date[r]), "-",
                              as.character(hy$last_record_date[r])), 1, 10),
                substr(ifelse(is.na(hy$last_download_date[r]), "-",
                              as.character(hy$last_download_date[r])), 1, 10),
                ifelse(is.na(hy$interval_min[r]), "-",
                       as.character(hy$interval_min[r]))))

    #### Does the record date fall inside the deployment? ####
    from <- parse_local(hy$deploy_datetime[r])
    lr   <- parse_local(hy$last_record_date[r])
    if (!is.na(from) && !is.na(lr) && lr < from)
      issues <- c(issues, sprintf("%s %s: last record %s precedes deployment %s",
                  sn, st, substr(as.character(hy$last_record_date[r]), 1, 10),
                  substr(as.character(hy$deploy_datetime[r]), 1, 10)))

    #### A terminal row should not record after the device left ####
    if (tolower(hy$status[r]) %in% TERMINAL && !is.na(hy$last_visit[r]) &&
        !is.na(lr)) {
      lv <- parse_local(paste(as.character(hy$last_visit[r]), "23:59:59"))
      if (!is.na(lv) && lr > lv)
        issues <- c(issues, sprintf("%s %s: last record %s is after it left on %s",
                    sn, st, substr(as.character(hy$last_record_date[r]), 1, 10),
                    as.character(hy$last_visit[r])))
    }

    #### Fields the dictionary constrains ####
    if (!is.na(hy$reach_length_m[r]) &&
        (is.na(hy$device_role[r]) || hy$device_role[r] == "primary"))
      issues <- c(issues, sprintf("%s %s: reach_length_m on a %s", sn, st,
                  ifelse(is.na(hy$device_role[r]), "row with no role", "primary")))

    if (!is.na(hy$elev[r]) && is.na(hy$elev_source[r]))
      issues <- c(issues, sprintf("%s %s: has elev but no elev_source", sn, st))

    if (grepl("^\\d{1,2}/", as.character(hy$last_record_date[r])) ||
        grepl("^\\d{1,2}/", as.character(hy$deploy_datetime[r])))
      issues <- c(issues, sprintf("%s %s: a date is in US short format", sn, st))

    #### An active row with no record date and files on disk ####
    #
    # Only when NO deployment of this serial has one. A device redeployed to a
    # new station has files from its earlier life and nothing yet from this
    # one, which is the honest state until it is next offloaded - 21652377 has
    # four Reef Bay files and no St George Mint readings.
    if (!tolower(hy$status[r]) %in% TERMINAL && is.na(hy$last_record_date[r])) {
      others <- hy$last_record_date[hy$device_serial == sn &
                                    seq_len(nrow(hy)) != r]
      if (all(is.na(others))) {
        n <- length(list.files(wds("device_hobo"),
                               pattern = paste0("^", sn, "_")))
        if (n > 0)
          issues <- c(issues,
                      sprintf("%s %s: no last record date but %d file(s) on disk",
                              sn, st, n))
      }
    }
  }

  #### Serials appearing twice without distinct windows ####
  dup <- names(which(table(hy$device_serial) > 1))
  for (sn in dup) {
    rows <- hy[hy$device_serial == sn, , drop = FALSE]
    lrs <- as.character(rows$last_record_date)
    if (length(unique(lrs[!is.na(lrs)])) < sum(!is.na(lrs)))
      issues <- c(issues, sprintf("%s: two deployments share a last record date",
                  sn))
  }

  #### Product 1 files with no metadata row ####
  on_disk <- unique(sub("_.*$", "",
                        list.files(wds("device_hobo"), pattern = "_raw\\.rds$")))
  orphan <- setdiff(on_disk, meta$device_serial)
  for (sn in orphan)
    issues <- c(issues, sprintf("%s: files on disk but no metadata row", sn))

  cat("\n")
  if (length(issues) == 0) {
    cat("  + nothing inconsistent\n\n")
  } else {
    cat("  ", length(issues), " thing(s) to look at\n\n", sep = "")
    for (i in issues) cat("    - ", i, "\n", sep = "")
    cat("\n")
  }

  invisible(issues)
}
