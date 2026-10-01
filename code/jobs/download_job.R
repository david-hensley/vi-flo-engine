################################################################################
#  VI-FLO download job
#
#  Pull from Box, fetch whatever is new from ZentraCloud, push back.
#
#  One implementation, two triggers: the weekly scheduled task, and
#  tools/download/run_download.bat for when you want the data now. Nothing
#  about the job knows which started it.
#
#  Usage:
#      Rscript "<engine>/code/jobs/download_job.R"
#
#  Exit code 0 on success, 1 on failure - so a scheduler can tell.
#
#
#  WHY IT PULLS FIRST
#
#  Box carries whole files. If this machine's copy of download_log.csv is
#  older than Box's and the job appends to it, the push overwrites Box with a
#  version missing whatever the other machine added. Pulling first shrinks the
#  window in which that can happen from a week to the job's own runtime.
#
#  It does not close the window. If somebody is writing metadata on another
#  machine WHILE this runs, one version still wins. That is why the catch-up
#  prompt says not to run it while anyone else is working.
################################################################################

engine_root <- Sys.getenv("VI_FLO_ENGINE_ROOT")

if (!nzchar(engine_root) || !dir.exists(engine_root)) {
  cat("X VI_FLO_ENGINE_ROOT is not set, or does not exist.\n")
  cat("  Run setup_win.exe in the engine repo, then try again.\n")
  quit(status = 1)
}

source(file.path(engine_root, "code/functions/setup_functions.R"))
load_all_functions(quiet = TRUE)


#' Copies between the local data root and Box
#'
#' `copy`, never `sync` - additive, and cannot delete at the destination even
#' if the source is missing files. The same verb and exclusions the sync tool
#' uses, so the two cannot disagree about what a transfer means.
#'
#' @param direction "pull" or "push"
#' @return TRUE if rclone succeeded
box_transfer <- function(direction) {

  local_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (!nzchar(local_root)) {
    cat("  ! VI_FLO_DATA_ROOT is not set - skipping ", direction, "\n", sep = "")
    return(FALSE)
  }

  src <- if (direction == "pull") BOX_DATA_PATH else local_root
  dst <- if (direction == "pull") local_root else BOX_DATA_PATH

  args <- c("copy", shQuote(src), shQuote(dst), "--update",
            "--create-empty-src-dirs", "--stats-one-line", "--stats", "30s")
  for (pat in c("datamap_*.csv", ".Rhistory", ".RData", ".Rproj.user/**",
                "Thumbs.db", ".DS_Store", "~$*")) {
    args <- c(args, "--exclude", shQuote(pat))
  }

  cat("  ", direction, "ing ", src, " -> ", dst, "\n", sep = "")

  out <- tryCatch(
    suppressWarnings(system2("rclone", args, stdout = TRUE, stderr = TRUE,
                             timeout = 1800)),
    error = function(e) NULL)

  if (is.null(out)) {
    cat("  ! rclone could not be run\n")
    return(FALSE)
  }

  failed <- !is.null(attr(out, "status")) && attr(out, "status") != 0
  if (failed) {
    cat("  ! rclone ", direction, " failed:\n", sep = "")
    for (l in tail(out, 5)) cat("    ", l, "\n", sep = "")
    return(FALSE)
  }

  cat("  + ", direction, " complete\n", sep = "")
  TRUE
}


################################################################################
#### RUN ####
################################################################################

cat("\n============================================\n")
cat("  VI-FLO download job\n")
cat("  ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  on ",
    Sys.info()[["nodename"]], "\n", sep = "")
cat("============================================\n\n")

#### 1. Pull ####
cat("Box - pulling anything newer\n")
pulled <- box_transfer("pull")
if (!pulled) {
  # Not fatal. A download that cannot reach Box is still worth having locally,
  # and the push afterwards will fail the same way and say so.
  cat("  ! continuing anyway - the data is still worth fetching\n")
}
cat("\n")

#### 2. Download ####
token <- Sys.getenv("ZENTRACLOUD_V5_TOKEN")
if (!nzchar(token)) {
  cat("X ZENTRACLOUD_V5_TOKEN is not set in this environment.\n")
  cat("  A scheduled task does not inherit an interactive session's\n")
  cat("  variables - check it is set machine-wide, not just for your user.\n")
  quit(status = 1)
}

if (!requireNamespace("zentraR", quietly = TRUE)) {
  cat("X the zentraR package is not installed.\n")
  quit(status = 1)
}

zentraR::zc_set_key(token)

result <- tryCatch(zentra_download(),
                   error = function(e) {
                     cat("X download failed: ", conditionMessage(e), "\n", sep = "")
                     NULL
                   })

if (is.null(result)) quit(status = 1)

#### 3. Push ####
cat("\nBox - pushing what changed\n")
pushed <- box_transfer("push")

cat("\n============================================\n")
if (pushed) {
  cat("  Done.\n")
} else {
  cat("  Data fetched, but NOT pushed to Box.\n")
  cat("  This machine now holds data no other copy has.\n")
}
cat("============================================\n\n")

quit(status = if (pushed) 0 else 1)
