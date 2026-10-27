################################################################################
# oprhansweep.R - clear Box of what this machine's products no longer hold
#
# Run after a commit and push, on the machine that did the last Product 2
# build, with start.R loaded. Two jobs:
#
#   1. Product FILES on Box that are not here - retired by a rebuild; a
#      copy-only push never deletes them. Listed, and deleted from Box only
#      when you type the confirmation.
#   2. EMPTY FOLDERS under products/, here and on Box. Removed; an empty
#      folder holds nothing to lose.
#
# What it will never do: delete anything here but an empty folder; touch
# anything on Box outside internal/products; delete a Box file that is not a
# Product 2 data file; delete a file the manifest lists.
#
# And it refuses outright, deleting nothing, when anything looks wrong:
#
#   - the session's data root is unset, or is a test's throwaway folder
#   - this machine has no products, or no manifest
#   - Box cannot be listed (no network, no rclone, a broken remote)
#   - Box's manifest differs from this machine's: another machine built since
#     you last pulled, and its new files would look like orphans here
#   - the files to delete are more than a quarter of Box's products: a sweep
#     clears a handful, and hundreds means something else is wrong
################################################################################

local({

  stop_sweep <- function(...) stop("\nSweep stopped - nothing deleted.\n  ", ..., call. = FALSE)

  #### Where we are ####
  root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (!nzchar(root)) stop_sweep("VI_FLO_DATA_ROOT is not set. Run start.R first.")
  if (grepl("viflo-test-", root, fixed = TRUE)) {
    stop_sweep("This session is on a test's throwaway folder:\n  ", root,
               "\n  Restart R and run start.R.")
  }
  if (!exists("BOX_DATA_PATH") || !nzchar(BOX_DATA_PATH)) {
    stop_sweep("BOX_DATA_PATH is not set. Run start.R first.")
  }
  here <- file.path(root, "internal", "products")
  box  <- paste0(BOX_DATA_PATH, "/internal/products")
  if (!grepl("/internal/products$", box)) stop_sweep("Box path does not end in internal/products: ", box)

  rclone <- function(args) {
    out <- suppressWarnings(system2("rclone", args, stdout = TRUE, stderr = TRUE))
    list(out = out, status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"))
  }

  #### This machine must have products and a manifest ####
  manifest_here <- file.path(here, "p2", "manifest.csv")
  if (!dir.exists(here)) stop_sweep("No products folder here: ", here)
  if (!file.exists(manifest_here)) stop_sweep("No Product 2 manifest here: ", manifest_here)
  manifest <- read.csv(manifest_here, stringsAsFactors = FALSE)
  if (nrow(manifest) == 0) stop_sweep("This machine's Product 2 manifest is empty.")
  local_files <- list.files(here, recursive = TRUE, all.files = TRUE)
  if (length(local_files) == 0) stop_sweep("No product files here.")

  #### Box must be listable ####
  listed <- rclone(c("lsf", "-R", "--files-only", shQuote(box)))
  if (listed$status != 0) {
    stop_sweep("Box could not be listed (rclone exit ", listed$status, "):\n  ",
               paste(utils::head(listed$out, 5), collapse = "\n  "))
  }
  box_files <- listed$out[nzchar(listed$out)]

  #### Box's manifest must be this machine's ####
  box_manifest <- tempfile(fileext = ".csv")
  got <- rclone(c("copyto", shQuote(paste0(box, "/p2/manifest.csv")), shQuote(box_manifest)))
  if (got$status != 0 || !file.exists(box_manifest)) {
    stop_sweep("Could not read Box's Product 2 manifest.")
  }
  if (!identical(unname(tools::md5sum(box_manifest)), unname(tools::md5sum(manifest_here)))) {
    stop_sweep("Box's Product 2 manifest differs from this machine's. Either another\n  ",
               "machine has built since you last pulled - pull first - or this\n  ",
               "machine's build has not been pushed - push first.")
  }

  #### 1. Product files on Box but not here ####
  gone <- setdiff(box_files, local_files)
  is_product <- grepl("^p[0-9]/[a-z0-9]+/[^/]+/[^/]+/[^/]+_p[0-9]_[0-9]{4}\\.csv\\.gz$", gone)
  in_manifest <- gone %in% manifest$file
  deletable <- gone[is_product & !in_manifest]
  left_alone <- gone[!(is_product & !in_manifest)]

  cat(length(box_files), "product file(s) on Box,", length(local_files), "here\n")
  cat(length(gone), "on Box but not here\n")
  if (length(left_alone) > 0) {
    cat("\nNot Product 2 data files, or listed in the manifest - left alone:\n")
    for (f in left_alone) cat("  ", f, "\n", sep = "")
  }

  if (length(deletable) > 0) {
    if (length(deletable) > 0.25 * length(box_files)) {
      stop_sweep(length(deletable), " of Box's ", length(box_files), " product files would be ",
                 "deleted - more than a quarter.\n  A sweep clears a handful; this many ",
                 "means something else is wrong.")
    }
    cat("\nRetired product files on Box - to delete:\n")
    for (f in deletable) cat("  ", f, "\n", sep = "")
    cat("\nType  delete ", length(deletable), "  to delete them from Box, anything else to skip: ",
        sep = "")
    answer <- trimws(readline())
    if (identical(answer, paste("delete", length(deletable)))) {
      failed <- character(0)
      for (f in deletable) {
        r <- rclone(c("deletefile", shQuote(paste0(box, "/", f))))
        if (r$status != 0) failed <- c(failed, f)
      }
      cat(length(deletable) - length(failed), "deleted from Box\n")
      if (length(failed) > 0) {
        cat("Could not delete:\n"); for (f in failed) cat("  ", f, "\n", sep = "")
      }
    } else {
      cat("Skipped - nothing deleted\n")
    }
  }

  #### 2. Empty folders, here and on Box ####
  # Only folders with nothing in them, checked again immediately before each
  # removal; deepest first, until none are left
  removed <- 0
  repeat {
    d <- list.dirs(here, recursive = TRUE)
    d <- d[d != here]
    empty <- d[vapply(d, function(x) length(list.files(x, all.files = TRUE, no.. = TRUE,
                                                        recursive = TRUE, include.dirs = TRUE)) == 0,
                      logical(1))]
    if (length(empty) == 0) break
    for (x in empty) {
      if (length(list.files(x, all.files = TRUE, no.. = TRUE)) == 0) {
        unlink(x, recursive = TRUE)
        removed <- removed + 1
      }
    }
  }
  cat(removed, "empty folder(s) removed here\n")

  # rclone rmdirs removes only directories with nothing in them
  r <- rclone(c("rmdirs", shQuote(box), "--leave-root"))
  cat(if (r$status == 0) "Empty folders on Box removed\n"
      else paste0("Could not clear empty folders on Box (rclone exit ", r$status, ")\n"))
})
