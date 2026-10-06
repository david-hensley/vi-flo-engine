# VI-FLO migration: discrete measurements, and the last of internal/raw
#
# ONE-TIME SCRIPT. Finishes what migrate_products_layout.R began.
#
#
# DISCRETE
#
# A FlowTracker gauging measures discharge. So does the series under
# products/hydro/discharge. The difference is not the quantity but how it was
# arrived at - one logged by an instrument on a schedule, one measured by a
# person standing in the stream.
#
# So `discrete` mirrors `products`, domain then variable, and the two sit
# beside each other:
#
#     products/hydro/discharge/   the series, in stages
#     discrete/hydro/discharge/   gaugings
#
# Someone asking what discharge data exists finds both in parallel places. No
# product stages, because a gauging has none - it is what it is.
#
# This also gives suspended sediment and soil characterisation a home, and
# takes the last file out of internal/raw so that path can go entirely.
#
#
# WHAT ELSE GOES
#
#   internal/raw/zentra-backfill   superseded by device-data/zentra/backfill
#   internal/processed             empty, never used
#   external/processed             empty, never used
#
# The first was missed by the layout migration; the last two were missed
# because the Box helper returned early on an empty directory and so never
# purged one.
#
# Safe to run twice.
#
# Usage:
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/migrations/migrate_discrete_and_cleanup.R"))

migrate_discrete_and_cleanup <- function(dry_run = TRUE) {

  cat("\n============================================\n")
  cat("  Migration: discrete, and the last of raw\n")
  if (dry_run) cat("  DRY RUN - nothing will be changed\n")
  cat("============================================\n\n")

  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  if (!nzchar(data_root) || !dir.exists(data_root)) {
    cat("X VI_FLO_DATA_ROOT is not set\n\n")
    return(invisible(FALSE))
  }

  #### The discrete tree ####
  # Seeded with what exists or is expected shortly. Like the products tree,
  # a folder not listed is not forbidden - these are the ones worth existing.
  # Named for the INSTRUMENT, not the quantity. One HYPROP run yields retention
  # and unsaturated conductivity together; a FlowTracker gauging yields a
  # velocity profile as well as the discharge computed from it. Naming a folder
  # after one output would leave the rest homeless, and the raw files these
  # instruments write belong with their own output anyway.
  #
  # `ssc` is the exception, and honestly so: there is no instrument. Bottles go
  # to whichever lab has capacity, and what comes back is a concentration.
  discrete_tree <- list(
    hydro    = c("flowtracker2"),
    sediment = c("ssc"),
    soil     = c("saturo", "ksat", "hyprop2", "wp4c")
  )

  cat("Creating the discrete tree\n")
  for (d in names(discrete_tree)) {
    cat("  ", d, ": ", paste(discrete_tree[[d]], collapse = ", "), "\n", sep = "")
  }
  cat("\n")

  #### Moving the sediment inventory ####
  old_sediment <- file.path(data_root, "internal/raw/sediment")
  sediment_files <- if (dir.exists(old_sediment)) list.files(old_sediment) else character(0)

  if (length(sediment_files) > 0) {
    cat("Moving from internal/raw/sediment to discrete/sediment/ssc:\n")
    for (f in sediment_files) cat("  ", f, "\n", sep = "")
    cat("\n")
  }

  #### Stale paths ####
  stale <- c("internal/raw/zentra-backfill", "internal/processed",
             "external/processed")

  cat("Stale paths:\n")
  for (s in stale) {
    local_n <- if (dir.exists(file.path(data_root, s))) {
      length(list.files(file.path(data_root, s), recursive = TRUE))
    } else NA
    cat("  ", s, "  local: ",
        if (is.na(local_n)) "not here" else paste0(local_n, " file(s)"),
        "\n", sep = "")
  }
  cat("\n")

  #### The same on Box ####
  cat("On Box:\n")
  for (s in stale) {
    out <- tryCatch(
      suppressWarnings(system2("rclone",
        c("lsf", shQuote(paste0(sub("/$", "", BOX_DATA_PATH), "/", s)),
          "--recursive", "--files-only"),
        stdout = TRUE, stderr = FALSE, timeout = 60)),
      error = function(e) NULL)
    n <- if (is.null(out)) NA else length(out[nzchar(out)])
    cat("  ", s, "  ", if (is.na(n)) "could not check" else paste0(n, " file(s)"),
        "\n", sep = "")
  }
  cat("\n")

  #### Is the backfill on Box duplicated locally? ####
  # Nothing is purged on the strength of a path looking superseded. The files
  # have to be demonstrably present at the new location first.
  box_bf <- tryCatch(
    suppressWarnings(system2("rclone",
      c("lsf", shQuote(paste0(sub("/$", "", BOX_DATA_PATH),
                              "/internal/raw/zentra-backfill")),
        "--recursive", "--files-only"),
      stdout = TRUE, stderr = FALSE, timeout = 60)),
    error = function(e) NULL)

  if (!is.null(box_bf) && length(box_bf) > 0) {
    local_bf <- list.files(wds("device_zentra_backfill"), recursive = TRUE)
    orphans <- setdiff(basename(box_bf[nzchar(box_bf)]), basename(local_bf))

    # Two files are known to be superseded rather than missing:
    #
    #   zentra_backfill_log.csv  records the abandoned v4 paging experiment -
    #                            33 five-day chunks of one device at 2.4
    #                            minutes each, before the exports and zentraR
    #                            made that unnecessary. None of what it fetched
    #                            is in the archive.
    #   zl6_sns.xlsx             the Excel serial list, replaced by the CSV.
    #
    # Anything else unaccounted for still blocks.
    known_superseded <- c("zentra_backfill_log.csv", "zl6_sns.xlsx")
    unexplained <- setdiff(orphans, known_superseded)

    if (length(unexplained) > 0) {
      cat("X ", length(unexplained), " backfill file(s) on Box are not present\n",
          "  at device-data/zentra/backfill, and are not known to be\n",
          "  superseded:\n", sep = "")
      for (f in head(unexplained, 10)) cat("    ", f, "\n", sep = "")
      cat("\n  Nothing purged. Account for those first.\n\n")
      return(invisible(FALSE))
    }

    if (length(orphans) > 0) {
      cat("+ Backfill files on Box are accounted for\n")
      cat("  (", length(orphans), " superseded: ",
          paste(orphans, collapse = ", "), ")\n\n", sep = "")
    } else {
      cat("+ Every backfill file on Box is present at the new location\n\n")
    }
  }

  if (dry_run) {
    cat("Re-run with dry_run = FALSE to apply:\n")
    cat("  migrate_discrete_and_cleanup(dry_run = FALSE)\n\n")
    return(invisible(TRUE))
  }

  #### Create ####
  made <- 0
  for (d in names(discrete_tree)) {
    for (v in discrete_tree[[d]]) {
      p <- file.path(data_root, "internal/discrete", d, v)
      if (!dir.exists(p)) { dir.create(p, recursive = TRUE); made <- made + 1 }
    }
  }
  cat("+ Created ", made, " discrete folder(s)\n", sep = "")

  #### Move the sediment inventory ####
  if (length(sediment_files) > 0) {
    dest <- file.path(data_root, "internal/discrete/sediment/ssc")
    moved <- 0
    for (f in sediment_files) {
      if (file.rename(file.path(old_sediment, f), file.path(dest, f))) {
        moved <- moved + 1
      }
    }
    cat("+ Moved ", moved, " file(s) into discrete/sediment/ssc\n", sep = "")
  }

  #### Push the new path to Box before anything is purged ####
  cat("\nPlacing discrete/ on Box\n")
  pushed <- tryCatch(
    suppressWarnings(system2("rclone",
      c("copy", shQuote(file.path(data_root, "internal/discrete")),
        shQuote(paste0(sub("/$", "", BOX_DATA_PATH), "/internal/discrete")),
        "--update", "--create-empty-src-dirs"),
      stdout = TRUE, stderr = TRUE, timeout = 600)),
    error = function(e) NULL)

  if (is.null(pushed) ||
      (!is.null(attr(pushed, "status")) && attr(pushed, "status") != 0)) {
    cat("X The push failed. NOTHING purged - re-run when Box is reachable.\n\n")
    return(invisible(FALSE))
  }
  cat("+ discrete/ is on Box\n")

  #### Now purge ####
  cat("\nPurging stale paths\n")
  for (s in stale) {
    local_p <- file.path(data_root, s)
    if (dir.exists(local_p)) {
      unlink(local_p, recursive = TRUE)
      cat("  + removed locally: ", s, "\n", sep = "")
    }
    out <- tryCatch(
      suppressWarnings(system2("rclone",
        c("purge", shQuote(paste0(sub("/$", "", BOX_DATA_PATH), "/", s))),
        stdout = TRUE, stderr = TRUE, timeout = 300)),
      error = function(e) NULL)
    ok <- !is.null(out) &&
          (is.null(attr(out, "status")) || attr(out, "status") == 0)
    cat("  ", if (ok) "+" else "!", " Box: ", s,
        if (ok) "" else " - could not remove, do it by hand", "\n", sep = "")
  }

  #### internal/raw itself ####
  raw <- file.path(data_root, "internal/raw")
  if (dir.exists(raw)) {
    left <- list.files(raw, recursive = TRUE, all.files = TRUE, no.. = TRUE)
    if (length(left) == 0) {
      unlink(raw, recursive = TRUE)
      cat("\n+ Removed internal/raw locally\n")
      tryCatch(suppressWarnings(system2("rclone",
        c("purge", shQuote(paste0(sub("/$", "", BOX_DATA_PATH), "/internal/raw"))),
        stdout = TRUE, stderr = TRUE, timeout = 300)), error = function(e) NULL)
      cat("+ Removed internal/raw from Box\n")
    } else {
      cat("\n! internal/raw still holds ", length(left), " file(s):\n", sep = "")
      for (f in head(left, 10)) cat("    ", f, "\n", sep = "")
    }
  }

  cat("\nNEXT:\n")
  cat("  1. Copy the new default_datamap.csv into the engine repo's data/\n")
  cat("  2. Run tools/datamapper.py and accept the default structure\n")
  cat("  3. source start.R, then validate_metadata()\n\n")

  invisible(TRUE)
}

migrate_discrete_and_cleanup(dry_run = TRUE)
