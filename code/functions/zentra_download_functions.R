################################################################################
#                      ZENTRA API DOWNLOAD (v5)                                #
#                                                                              #
# Fetches readings from ZentraCloud through the v5 API and writes them as       #
# Product 1 - one file per download, keyed by DEVICE:                           #
#                                                                              #
#     internal/raw/device-data/zentra/                                          #
#         z6-12874_20260924_20260926_20260927T143022_raw.rds                    #
#                                                                              #
#     serial _ first record _ last record _ when fetched                        #
#                                                                              #
# Station attribution happens at Product 2. A station name in a Product 1       #
# filename would be an attribution, and attributions can be wrong.              #
#                                                                              #
#                                                                              #
# WHY FILE PER DOWNLOAD RATHER THAN ONE FILE PER DEVICE                         #
#                                                                              #
# zentraR's own store keeps one accumulating file per device, rewritten on      #
# every sync. That is simpler, but every rewrite is a new full copy in version  #
# control - roughly 47 GB of stored revisions after five years against 1.8 GB   #
# for files written once and never touched again.                              #
#                                                                              #
# Immutable files also mean a download can be audited: each file is exactly     #
# what one fetch returned, and download_log has one row pointing at it.         #
#                                                                              #
#                                                                              #
# WHERE EACH DEVICE RESUMES FROM                                                #
#                                                                              #
#   1. the latest timestamp in its existing Product 1 files                     #
#   2. failing that, the latest in the parsed backfill exports - this is what   #
#      the first run uses, and it is why the backfill and the API meet without  #
#      a gap or an overlap                                                      #
#   3. failing that, the device's first measurement, from the API               #
#                                                                              #
# Devices are discovered from the API, not from metadata. A logger reporting    #
# to ZentraCloud that VI-FLO does not yet know about still gets downloaded -    #
# an admin oversight should not become data loss. Attribution decides later     #
# what has a station.                                                           #
################################################################################


#' Timestamp of the newest reading already held for a device
#'
#' @param device_sn Character
#' @return POSIXct, or NA if nothing is held
zentra_last_held <- function(device_sn) {

  #### Product 1 files ####
  p1 <- list.files(wds("device_zentra"), pattern = "_raw\\.rds$",
                   full.names = TRUE)
  mine <- p1[startsWith(basename(p1), paste0(device_sn, "_"))]

  if (length(mine) > 0) {
    # The newest file's last record - reading only one file rather than all
    ends <- vapply(basename(mine), function(f) {
      parts <- strsplit(sub("_raw\\.rds$", "", f), "_")[[1]]
      if (length(parts) < 3) return(NA_character_)
      parts[3]                      # the end date segment
    }, character(1), USE.NAMES = FALSE)

    newest <- mine[which.max(as.Date(ends, format = "%Y%m%d"))]
    d <- readRDS(newest)
    if (nrow(d) > 0) return(max(d$datetime, na.rm = TRUE))
  }

  #### Parsed backfill exports ####
  bf <- file.path(wds("device_zentra_backfill"), "parsed",
                  paste0(device_sn, "_parsed.rds"))
  if (file.exists(bf)) {
    d <- readRDS(bf)
    if (nrow(d) > 0) return(max(d$timestamp_utc, na.rm = TRUE))
  }

  as.POSIXct(NA)
}


#' Downloads new readings for every device the key can reach
#'
#' @param devices Character vector of serials, or NULL for all
#' @param end POSIXct or date string. Latest reading to fetch, default now
#' @param max_active Integer. Devices fetched concurrently. The readings rate
#'   limit is per device, so above 1 is substantially faster
#' @param dry_run Logical. Report the plan without fetching
#' @param key Character. API key, for a second ZentraCloud account
#' @return Invisible data frame, one row per device
zentra_download <- function(devices = NULL, end = NULL, max_active = 4L,
                            dry_run = FALSE, key = NULL) {

  if (!requireNamespace("zentraR", quietly = TRUE)) {
    stop("zentraR is not installed", call. = FALSE)
  }

  out_dir <- wds("device_zentra")
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  cat("\n============================================\n")
  cat("  ZentraCloud download\n")
  if (dry_run) cat("  DRY RUN - nothing will be fetched\n")
  cat("============================================\n\n")

  #### Who exists ####
  known <- tryCatch(
    zentraR::zc_list_devices(expand = "max_min_timestamp", key = key),
    error = function(e) {
      cat("X Could not list devices: ", conditionMessage(e), "\n\n", sep = "")
      NULL
    })
  if (is.null(known)) return(invisible(NULL))

  if (!is.null(devices)) known <- known[known$device_id %in% devices, ]

  cat("Devices reachable: ", nrow(known), "\n\n", sep = "")

  #### Where each resumes ####
  plan <- data.frame(
    device_sn = known$device_id,
    name      = known$name,
    api_last  = known$last_measurement,
    stringsAsFactors = FALSE
  )
  plan$from <- as.POSIXct(vapply(plan$device_sn, function(s)
    as.numeric(zentra_last_held(s)), numeric(1)), origin = "1970-01-01", tz = "UTC")

  plan$source <- ifelse(is.na(plan$from), "first measurement", "existing data")
  plan$from[is.na(plan$from)] <-
    known$first_measurement[is.na(plan$from)]

  # Nothing newer than what we hold
  plan$skip <- !is.na(plan$api_last) & !is.na(plan$from) &
               plan$api_last <= plan$from

  for (i in seq_len(nrow(plan))) {
    cat("  ", format(plan$device_sn[i], width = 10),
        format(substr(plan$name[i], 1, 20), width = 21),
        if (plan$skip[i]) "up to date" else
          paste0("from ", format(plan$from[i], "%Y-%m-%d %H:%M"),
                 "  (", plan$source[i], ")"),
        "\n", sep = "")
  }

  todo <- plan[!plan$skip & !is.na(plan$from), ]
  cat("\nTo fetch: ", nrow(todo), " device(s)\n", sep = "")

  if (dry_run || nrow(todo) == 0) {
    if (nrow(todo) > 0) cat("\nRe-run with dry_run = FALSE to fetch.\n\n")
    else cat("\nEverything is up to date.\n\n")
    return(invisible(plan))
  }

  #### Fetch ####
  cat("\n--------------------------------------------\n\n")

  fetched_at <- Sys.time()
  stamp <- format(fetched_at, "%Y%m%dT%H%M%S")
  results <- list()

  for (i in seq_len(nrow(todo))) {
    sn <- todo$device_sn[i]

    # A second past the last held reading, so nothing is fetched twice
    from <- todo$from[i] + 1

    data <- tryCatch(
      zentraR::zc_sync(device_id = sn, store = NULL, start = from, end = end,
                       max_active = 1L, quiet = TRUE, progress = FALSE,
                       key = key),
      error = function(e) {
        cat("  X ", sn, ": ", conditionMessage(e), "\n", sep = "")
        NULL
      })

    if (is.null(data) || nrow(data) == 0) {
      cat("  - ", format(sn, width = 10), "nothing new\n", sep = "")
      results[[length(results) + 1]] <- data.frame(
        device_sn = sn, rows = 0L, file = NA_character_,
        stringsAsFactors = FALSE)
      next
    }

    first <- min(data$datetime, na.rm = TRUE)
    last  <- max(data$datetime, na.rm = TRUE)

    fname <- paste0(sn, "_",
                    format(first, "%Y%m%d"), "_",
                    format(last,  "%Y%m%d"), "_",
                    stamp, "_raw.rds")

    saveRDS(data, file.path(out_dir, fname))

    zentra_log_download(sn, first, last, nrow(data), fname, fetched_at)

    cat("  + ", format(sn, width = 10),
        format(nrow(data), width = 8, big.mark = ","), " rows   ",
        format(first, "%Y-%m-%d"), " to ", format(last, "%Y-%m-%d"), "\n",
        sep = "")

    results[[length(results) + 1]] <- data.frame(
      device_sn = sn, rows = nrow(data), file = fname,
      stringsAsFactors = FALSE)
  }

  res <- do.call(rbind, results)

  cat("\n--------------------------------------------\n")
  cat("Fetched ", format(sum(res$rows), big.mark = ","), " reading(s) across ",
      sum(res$rows > 0), " device(s)\n\n", sep = "")

  invisible(res)
}


#' Appends a Product 1 download to download_log.csv
#'
#' station is left NA: a Product 1 download is not attributed to one, and
#' guessing here would bake in exactly the kind of assumption that Product 1
#' exists to avoid.
#'
#' @param device_sn,first,last,n,fname,fetched_at Download details
#' @return Invisible TRUE
zentra_log_download <- function(device_sn, first, last, n, fname, fetched_at) {

  log_file <- file.path(wds("meta_internal"), "download_log.csv")

  rel <- sub(paste0("^", gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT")), "/?"),
             "", gsub("\\\\", "/", file.path(wds("device_zentra"), fname)))

  entry <- data.frame(
    timestamp     = format(fetched_at, "%Y-%m-%d %H:%M:%S"),
    station       = NA_character_,
    device_serial = device_sn,
    start_date    = format(first, "%Y-%m-%d %H:%M:%S"),
    end_date      = format(last,  "%Y-%m-%d %H:%M:%S"),
    n_records     = n,
    filepath      = rel,
    download_type = "automatic",
    stringsAsFactors = FALSE
  )

  if (file.exists(log_file)) {
    existing <- read.csv(log_file, stringsAsFactors = FALSE, nrows = 1)
    entry <- entry[, names(existing), drop = FALSE]
    write.table(entry, log_file, sep = ",", append = TRUE,
                row.names = FALSE, col.names = FALSE, qmethod = "double")
  } else {
    write.csv(entry, log_file, row.names = FALSE)
  }

  invisible(TRUE)
}
