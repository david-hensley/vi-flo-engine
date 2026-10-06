# VI-FLO migration: the products layout
#
# ONE-TIME SCRIPT.
#
# The data root is reorganised around the distinction that matters most: what
# is held, and what is made from it.
#
#     internal/device-data/     immutable, device-keyed, RDS
#     internal/products/        regenerable, station-keyed, csv.gz
#
# `raw` disappears. It meant something when everything under internal/ was raw
# and processing had nowhere to go; with products sitting beside device-data it
# only adds a level that says nothing.
#
# `internal/raw/streamflow`, `vwc` and `weather` were reserved for Product 2
# and never filled. They are replaced by internal/products/<domain>/<variable>/,
# which splits streamflow into level and discharge - two series with separate
# histories once a rating curve stands between them, and no business sharing a
# directory.
#
# `external/raw` and `external/processed` go too. External data is somebody
# else's, taken as given, and the processing discipline that justifies those
# names does not apply to it. It is grouped by source instead.
#
#
# WHAT MOVES
#
#   internal/raw/device-data/  ->  internal/device-data/
#
# That is 400+ MB, moved rather than copied, so it is near-instant on one
# volume. download_log.csv filepaths are rewritten in the same operation -
# a rename without the log rewrite leaves every row pointing at nothing.
#
#
# BOX
#
# The sync tool uses `rclone copy`, which never deletes - deliberately, so it
# cannot destroy anything. The cost is that Box holds every path that has ever
# existed, and a pull restores them. That is why internal/raw/streamflow came
# back full of station-prefixed files months after they were moved.
#
# So the retired paths are deleted from Box too, narrowly and with a preview.
# Never `rclone sync`, which would mirror deletions in both directions and make
# one bad local state enough to lose the archive. Box keeps its own file
# versions, so even this is recoverable through their interface.
#
# ORDER MATTERS. device-data is pushed to its NEW path on Box and verified
# there before the old path is purged. Purging first would leave 653 MB in one
# place - the laptop - until the next sync, and a failure in that window is the
# whole archive.
#
# Safe to run twice: it detects the move has happened and exits.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_products_layout.R"))

#' Pushes one path to Box and reports how many files arrived
#'
#' @param rel Character. Path relative to the data root
#' @return Number of files at the destination afterwards, or NA
box_push_path <- function(rel) {

  local <- file.path(gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT")), rel)
  remote <- paste0(sub("/$", "", BOX_DATA_PATH), "/", rel)

  cat("  pushing ", rel, " to Box...\n", sep = "")

  out <- tryCatch(
    suppressWarnings(system2("rclone",
      c("copy", shQuote(local), shQuote(remote), "--update",
        "--create-empty-src-dirs"),
      stdout = TRUE, stderr = TRUE, timeout = 3600)),
    error = function(e) NULL)

  failed <- is.null(out) ||
            (!is.null(attr(out, "status")) && attr(out, "status") != 0)
  if (failed) return(NA_integer_)

  listing <- tryCatch(
    suppressWarnings(system2("rclone", c("lsf", shQuote(remote), "--recursive",
                                         "--files-only"),
                             stdout = TRUE, stderr = FALSE, timeout = 120)),
    error = function(e) NULL)

  if (is.null(listing)) return(NA_integer_)
  length(listing[nzchar(listing)])
}


#' Deletes one path from Box, showing what goes first
#'
#' Narrow by design. It takes one path, lists what is there, and removes only
#' that. No recursion over a parent, no mirroring - a sync that mirrors
#' deletions turns one bad local state into a lost archive.
#'
#' @param rel Character. Path relative to the data root
#' @param dry_run Logical
#' @return Number of files removed, or NA if rclone could not be reached
box_retire_path <- function(rel, dry_run = TRUE) {

  remote <- paste0(sub("/$", "", BOX_DATA_PATH), "/", rel)

  listing <- tryCatch(
    suppressWarnings(system2("rclone", c("lsf", shQuote(remote), "--recursive"),
                             stdout = TRUE, stderr = FALSE, timeout = 60)),
    error = function(e) NULL)

  if (is.null(listing)) return(NA_integer_)
  listing <- listing[nzchar(listing)]
  if (length(listing) == 0) return(0L)

  cat("  ", rel, " - ", length(listing), " file(s) on Box\n", sep = "")
  for (f in head(listing, 5)) cat("      ", f, "\n", sep = "")
  if (length(listing) > 5) {
    cat("      ... and ", length(listing) - 5, " more\n", sep = "")
  }

  if (dry_run) return(length(listing))

  out <- tryCatch(
    suppressWarnings(system2("rclone", c("purge", shQuote(remote)),
                             stdout = TRUE, stderr = TRUE, timeout = 300)),
    error = function(e) NULL)

  failed <- is.null(out) ||
            (!is.null(attr(out, "status")) && attr(out, "status") != 0)

  if (failed) {
    cat("    ! could not remove it from Box - do it by hand\n")
    return(NA_integer_)
  }

  length(listing)
}


migrate_products_layout <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: the products layout\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  if (!nzchar(data_root) || !dir.exists(data_root)) {
    cat("X VI_FLO_DATA_ROOT is not set\n\n")
    return(invisible(FALSE))
  }

  old_device <- file.path(data_root, "internal/raw/device-data")
  new_device <- file.path(data_root, "internal/device-data")

  #### What the products tree will look like ####
  # Seeded with what the network measures now. A variable not listed here is
  # not forbidden - product_path() creates whatever it is given - these are
  # just the folders worth existing from the start.
  product_tree <- list(
    hydro   = c("level", "discharge"),
    weather = c("precip", "temp", "rh", "wind_speed", "wind_direction",
                "solar_radiation", "pressure", "vapor_pressure"),
    vwc     = c("vwc_10cm", "vwc_30cm", "vwc_50cm", "vwc_100cm")
  )
  stages <- c("p2", "p3", "p4")

  #### Report ####
  moving <- dir.exists(old_device)
  if (moving) {
    n <- length(list.files(old_device, recursive = TRUE, all.files = TRUE,
                           no.. = TRUE))
    size <- sum(file.size(list.files(old_device, recursive = TRUE,
                                     full.names = TRUE)), na.rm = TRUE)
    cat("Moving device-data up one level\n")
    cat("  from internal/raw/device-data\n")
    cat("  to   internal/device-data\n")
    cat("  ", n, " file(s), ", round(size / 1024^2), " MB\n\n", sep = "")
  } else {
    cat("+ device-data is already in place\n\n")
  }

  n_dirs <- length(unlist(product_tree)) * length(stages)
  cat("Creating the products tree - ", n_dirs, " folder(s)\n", sep = "")
  for (domain in names(product_tree)) {
    cat("  ", domain, ": ", paste(product_tree[[domain]], collapse = ", "),
        "\n", sep = "")
  }
  cat("  each with ", paste(stages, collapse = ", "), "\n\n", sep = "")

  #### Folders being retired ####
  retiring <- c("internal/raw/streamflow", "internal/raw/vwc",
                "internal/raw/weather", "external/raw", "external/processed")
  present <- retiring[dir.exists(file.path(data_root, retiring))]

  if (length(present) > 0) {
    cat("Retiring:\n")
    for (r in present) {
      n <- length(list.files(file.path(data_root, r), recursive = TRUE,
                             all.files = TRUE, no.. = TRUE))
      cat("  ", r, if (n > 0) paste0("  (", n, " file(s) - NOT empty)") else "",
          "\n", sep = "")
    }
    cat("\n")

  }

  #### The same paths on Box ####
  # Deleted there too, or the next pull restores them and the folders we just
  # retired reappear - which is exactly how they came back the first time.
  cat("On Box, to be removed:\n")
  box_total <- 0
  for (r in c(retiring, "internal/raw/device-data")) {
    n <- box_retire_path(r, dry_run = TRUE)
    if (!is.na(n)) box_total <- box_total + n
  }
  if (box_total == 0) cat("  nothing\n")
  cat("\n")

  #### download_log rows affected ####
  log_file <- file.path(wds("meta_internal"), "download_log.csv")
  dlog <- read.csv(log_file, stringsAsFactors = FALSE)
  hits <- grep("^internal/raw/device-data/", dlog$filepath)
  cat("download_log rows to rewrite: ", length(hits), "\n", sep = "")

  if (dry_run) {
    cat("\nRe-run with dry_run = FALSE to apply:\n")
    cat("  migrate_products_layout(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Back up the metadata before touching anything ####
  backup_metadata()
  cat("\n+ Metadata backed up\n")

  #### Move device-data ####
  if (moving) {
    if (!dir.exists(dirname(new_device))) {
      dir.create(dirname(new_device), recursive = TRUE)
    }
    ok <- file.rename(old_device, new_device)
    if (!ok) {
      cat("X Could not move device-data. Nothing else was changed.\n\n")
      return(invisible(FALSE))
    }
    cat("+ device-data moved\n")
  }

  #### Create the products tree ####
  made <- 0
  for (domain in names(product_tree)) {
    for (v in product_tree[[domain]]) {
      for (s in stages) {
        p <- file.path(data_root, "internal/products", domain, v, s)
        if (!dir.exists(p)) { dir.create(p, recursive = TRUE); made <- made + 1 }
      }
    }
  }
  cat("+ Created ", made, " product folder(s)\n", sep = "")

  #### device-data onto Box at its new path, BEFORE anything is purged ####
  # Two copies at every moment. Purging the old path first would leave the
  # whole archive on this laptop alone until the next sync.
  local_n <- length(list.files(new_device, recursive = TRUE))
  cat("\nBox - placing device-data at its new path\n")
  box_n <- box_push_path("internal/device-data")

  if (is.na(box_n)) {
    cat("\nX The push to Box failed. NOTHING has been purged - the old path\n")
    cat("  on Box still holds the archive. Fix the connection and re-run.\n\n")
    return(invisible(FALSE))
  }

  cat("+ ", box_n, " file(s) at internal/device-data on Box (", local_n,
      " locally)\n", sep = "")

  if (box_n < local_n) {
    cat("\nX Fewer files arrived than were sent. NOTHING has been purged.\n")
    cat("  Re-run once the push completes.\n\n")
    return(invisible(FALSE))
  }

  #### Only now retire the old paths ####
  for (r in present) unlink(file.path(data_root, r), recursive = TRUE)
  cat("+ Removed ", length(present), " retired folder(s) locally\n", sep = "")

  cat("\nRemoving the old paths from Box\n")
  removed <- 0
  for (r in c(retiring, "internal/raw/device-data")) {
    n <- box_retire_path(r, dry_run = FALSE)
    if (!is.na(n)) removed <- removed + n
  }
  cat("+ Removed ", removed, " file(s) from Box\n", sep = "")

  # internal/raw itself, if nothing is left in it
  raw <- file.path(data_root, "internal/raw")
  if (dir.exists(raw) &&
      length(list.files(raw, recursive = TRUE, all.files = TRUE, no.. = TRUE)) == 0) {
    unlink(raw, recursive = TRUE)
    cat("+ Removed internal/raw\n")
  }

  #### Rewrite download_log ####
  if (length(hits) > 0) {
    dlog$filepath[hits] <- sub("^internal/raw/device-data/",
                               "internal/device-data/", dlog$filepath[hits])
    write.csv(dlog, log_file, row.names = FALSE)
    cat("+ Rewrote ", length(hits), " download_log filepath(s)\n", sep = "")
  }

  #### Verify ####
  check <- read.csv(log_file, stringsAsFactors = FALSE)
  missing <- !file.exists(file.path(data_root, check$filepath))

  if (any(missing)) {
    cat("\nX download_log points at missing file(s):\n")
    for (f in head(check$filepath[missing], 10)) cat("   ", f, "\n", sep = "")
    cat("\n  Restore from metadata/internal/backups/ and investigate.\n\n")
    return(invisible(FALSE))
  }

  cat("+ Verified: all ", nrow(check),
      " logged filepath(s) resolve on disk\n\n", sep = "")

  cat("NEXT:\n")
  cat("  1. Copy the new default_datamap.csv into the engine repo's data/\n")
  cat("  2. Run tools/datamapper.py and accept the default structure\n")
  cat("  3. source start.R, then validate_metadata()\n")
  cat("  4. Repeat 1-2 on the other machine after pulling\n\n")

  invisible(TRUE)
}

migrate_products_layout(dry_run = TRUE)
