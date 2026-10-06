################################################################################
#                          ORPHANED RAW FILES                                  #
#                                                                              #
# validate_metadata() checks that every file download_log names still exists.  #
# This is the reverse: every file that exists should have a log row naming it. #
#                                                                              #
# A file with no row is one the system does not know about. It will not be     #
# attributed, will not appear in any accounting of what the archive holds, and #
# is invisible to everything except a directory listing.                       #
#                                                                              #
# They arise from renames. `rclone copy` never deletes, so Box holds every     #
# path that has ever existed - rename a file locally and the old name is       #
# restored on the next pull, sitting beside the new one with no row to its     #
# name. That is how 37 appeared after the filename stamps were moved to UTC.   #
################################################################################


#' Raw files with no download_log row
#'
#' @param verify_duplicates Logical. For each orphan, look for a logged file
#'   with the same device and date range, and compare their contents
#' @return Data frame: file, directory, device, duplicate_of, identical
find_orphan_raw_files <- function(verify_duplicates = TRUE) {

  dl <- tryCatch(load_download_log(), error = function(e) NULL)
  if (is.null(dl)) {
    stop("Could not read download_log.csv", call. = FALSE)
  }
  logged <- basename(dl$filepath)

  found <- list()

  for (named in c("device_zentra", "device_hobo")) {
    dir <- tryCatch(wds(named), error = function(e) NULL)
    if (is.null(dir) || !dir.exists(dir)) next

    files <- list.files(dir, pattern = "_raw\\.rds$")
    orphans <- setdiff(files, logged)
    if (length(orphans) == 0) next

    for (o in orphans) {
      p <- parse_raw_filename(o)
      sn <- if (is.null(p) || is.na(p$device_serial)) NA_character_ else p$device_serial

      dup <- NA_character_
      same <- NA

      if (verify_duplicates && !is.na(sn)) {
        # A logged file for the same device covering the same range. The only
        # difference should be the fetch stamp - which is exactly what a
        # rename changes.
        # Built from the filename's own digits, not from the parsed Dates -
        # a Date formats as "2026-09-14" and would match nothing.
        stem <- paste0(sn, "_",
                       format(p$start, "%Y%m%d"), "_",
                       format(p$end, "%Y%m%d"), "_")
        candidates <- logged[startsWith(logged, stem)]

        if (length(candidates) > 0) {
          dup <- candidates[1]
          a <- file.path(dir, o)
          b <- file.path(dir, dup)
          if (file.exists(b)) {
            # Size first - cheap, and settles almost every case
            same <- file.size(a) == file.size(b)
            if (isTRUE(same)) {
              same <- identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))
            }
          }
        }
      }

      found[[length(found) + 1]] <- data.frame(
        file = o, directory = named, device = sn,
        duplicate_of = dup, identical = same,
        stringsAsFactors = FALSE)
    }
  }

  if (length(found) == 0) {
    return(data.frame(file = character(0), directory = character(0),
                      device = character(0), duplicate_of = character(0),
                      identical = logical(0), stringsAsFactors = FALSE))
  }

  do.call(rbind, found)
}


#' Reports orphaned raw files
#'
#' @param orphans Data frame from find_orphan_raw_files()
#' @return Invisible TRUE
print_orphan_raw_files <- function(orphans = NULL) {

  if (is.null(orphans)) orphans <- find_orphan_raw_files()

  if (nrow(orphans) == 0) {
    cat("\n  Every raw file has a download_log row.\n\n")
    return(invisible(TRUE))
  }

  cat("\n============================================\n")
  cat("  ", nrow(orphans), " raw file(s) with no log row\n", sep = "")
  cat("============================================\n\n")

  dupes <- orphans[isTRUE(orphans$identical) | orphans$identical %in% TRUE, ,
                   drop = FALSE]
  others <- orphans[!(orphans$identical %in% TRUE), , drop = FALSE]

  if (nrow(dupes) > 0) {
    cat("Identical to a logged file - safe to remove: ", nrow(dupes), "\n",
        sep = "")
    for (i in head(seq_len(nrow(dupes)), 5)) {
      cat("  ", dupes$file[i], "\n", sep = "")
      cat("    same as ", dupes$duplicate_of[i], "\n", sep = "")
    }
    if (nrow(dupes) > 5) cat("  ... and ", nrow(dupes) - 5, " more\n", sep = "")
    cat("\n")
  }

  if (nrow(others) > 0) {
    cat("NOT accounted for - look at these: ", nrow(others), "\n", sep = "")
    for (i in seq_len(min(nrow(others), 10))) {
      cat("  ", others$file[i],
          if (!is.na(others$duplicate_of[i]))
            paste0("   (a logged file covers the same range, but the contents differ)")
          else "   (no logged file covers this range)",
          "\n", sep = "")
    }
    if (nrow(others) > 10) cat("  ... and ", nrow(others) - 10, " more\n", sep = "")
    cat("\n")
    cat("A file holding data nothing else holds should get a log row rather\n")
    cat("than be deleted. One that duplicates a logged file under an old name\n")
    cat("can go.\n\n")
  }

  invisible(TRUE)
}


#' Removes orphans that are identical to a logged file
#'
#' Only exact duplicates, and only after comparing contents. Anything whose
#' data is not demonstrably held elsewhere is left alone and reported - a file
#' nothing else holds should gain a log row, not be deleted.
#'
#' Removes from Box as well, or the next pull restores them.
#'
#' @param dry_run Logical
#' @return Invisible number removed
remove_duplicate_orphans <- function(dry_run = TRUE) {

  orphans <- find_orphan_raw_files(verify_duplicates = TRUE)
  dupes <- orphans[orphans$identical %in% TRUE, , drop = FALSE]
  others <- orphans[!(orphans$identical %in% TRUE), , drop = FALSE]

  cat("\n============================================\n")
  cat("  Removing duplicate orphans\n")
  if (dry_run) cat("  DRY RUN - nothing will be removed\n")
  cat("============================================\n\n")

  if (nrow(others) > 0) {
    cat(nrow(others), " orphan(s) are NOT duplicates and will be left alone:\n",
        sep = "")
    for (i in seq_len(min(nrow(others), 10))) {
      cat("  ", others$file[i], "\n", sep = "")
    }
    cat("\n")
  }

  if (nrow(dupes) == 0) {
    cat("+ No duplicate orphans.\n\n")
    return(invisible(0L))
  }

  cat(nrow(dupes), " duplicate(s), verified identical to a logged file\n\n",
      sep = "")

  if (dry_run) {
    for (i in seq_len(min(nrow(dupes), 8))) {
      cat("  ", dupes$file[i], "\n", sep = "")
    }
    if (nrow(dupes) > 8) cat("  ... and ", nrow(dupes) - 8, " more\n", sep = "")
    cat("\nRe-run with dry_run = FALSE to remove:\n")
    cat("  remove_duplicate_orphans(dry_run = FALSE)\n\n")
    return(invisible(nrow(dupes)))
  }

  removed <- 0
  for (i in seq_len(nrow(dupes))) {
    dir <- wds(dupes$directory[i])
    if (file.remove(file.path(dir, dupes$file[i]))) removed <- removed + 1
  }
  cat("+ Removed ", removed, " locally\n", sep = "")

  #### Box, or the next pull puts them back ####
  data_root <- gsub("\\\\", "/", Sys.getenv("VI_FLO_DATA_ROOT"))
  box_removed <- 0

  for (i in seq_len(nrow(dupes))) {
    rel <- sub(paste0("^", data_root, "/?"), "",
               gsub("\\\\", "/", file.path(wds(dupes$directory[i]),
                                           dupes$file[i])))
    remote <- paste0(sub("/$", "", BOX_DATA_PATH), "/", rel)
    out <- tryCatch(
      suppressWarnings(system2("rclone", c("deletefile", shQuote(remote)),
                               stdout = TRUE, stderr = TRUE, timeout = 60)),
      error = function(e) NULL)
    ok <- !is.null(out) &&
          (is.null(attr(out, "status")) || attr(out, "status") == 0)
    if (ok) box_removed <- box_removed + 1
  }

  cat("+ Removed ", box_removed, " from Box\n", sep = "")
  if (box_removed < removed) {
    cat("! ", removed - box_removed, " could not be removed from Box - they\n",
        "  will return on the next pull. Remove them by hand.\n", sep = "")
  }
  cat("\n")

  invisible(removed)
}
