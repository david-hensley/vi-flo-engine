################################################################################
#  VI-FLO download job
#
#  Pull from Box, fetch whatever is new from ZentraCloud, bring Product 2 up
#  to date, push back.
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
#  WHY IT PULLS CODE FIRST
#
#  The engine repo, before anything else. This machine may be days behind -
#  a desktop that was off over a weekend, a laptop not opened since the last
#  trip - and running a week-old copy of the downloader against fresh data is
#  the kind of mistake that is only visible afterwards. The code and the data
#  should be from the same moment.
#
#  The pull here is a BACKSTOP. R has already read this file by the time it
#  runs, so an update only takes effect on the next run. The real fix is one
#  level up: tools/download/run_download_job.bat pulls before starting R, and
#  that is what the scheduled task calls. This stays for anyone who runs the
#  script directly, where a late update is better than none.
#
#  A failed git pull does not stop the job. Being unable to reach GitHub is
#  not a reason to skip a download, and the run log records what happened.
#
#
#  WHY IT PULLS DATA FIRST
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


#' Bring the engine repo up to date
#'
#' Warn and continue on failure: no network, no git on PATH, or a dirty
#' working tree are all reasons this cannot run, and none of them is a reason
#' to skip the download.
#'
#' @param root Engine repo path
#' @return TRUE if the pull succeeded or there was nothing to do
git_pull_engine <- function(root) {

  if (!nzchar(Sys.which("git"))) {
    cat("  ! git is not on PATH - the engine was not updated\n")
    return(FALSE)
  }

  owd <- setwd(root); on.exit(setwd(owd), add = TRUE)

  # A dirty tree means somebody is mid-edit. Pulling over that is worse than
  # running slightly behind, so it says so and leaves it alone.
  dirty <- suppressWarnings(system2("git", c("status", "--porcelain"),
                                    stdout = TRUE, stderr = TRUE))
  if (length(dirty) > 0 && any(nzchar(dirty))) {
    cat("  ! uncommitted changes here - the engine was NOT updated\n")
    cat("    running with the code as it stands\n")
    return(FALSE)
  }

  out <- suppressWarnings(system2("git", c("pull", "--ff-only"),
                                  stdout = TRUE, stderr = TRUE))
  ok <- is.null(attr(out, "status")) || attr(out, "status") == 0

  if (!ok) {
    cat("  ! git pull failed - the engine was not updated\n")
    for (line in utils::head(out, 4)) cat("    ", line, "\n", sep = "")
    return(FALSE)
  }

  if (any(grepl("Already up to date", out, fixed = TRUE))) {
    cat("  + already current\n")
  } else {
    cat("  + engine updated\n")
    for (line in utils::tail(out, 3)) cat("    ", line, "\n", sep = "")
    cat("  ! the updated code will apply from the NEXT run - this one is\n")
    cat("    already loaded\n")
  }
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

#### 1. Pull the code ####
cat("Engine - pulling the latest code\n")
invisible(git_pull_engine(engine_root))
cat("\n")

#### 2. Pull the data ####
cat("Box - pulling anything newer\n")
pulled <- box_transfer("pull")
if (!pulled) {
  # Not fatal. A download that cannot reach Box is still worth having locally,
  # and the push afterwards will fail the same way and say so.
  cat("  ! continuing anyway - the data is still worth fetching\n")
}
cat("\n")

#### 3. Download ####
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

#### 4. Product 2 - rebuild whatever is now out of date ####
# Station-years fed by what was just downloaded, by a HOBO offload ingested
# midweek, by metadata corrected since the last run, or by a change to the
# engine's Product 2 code. A failure here is reported and never stops the
# push: the downloaded data still has to reach Box. On a machine whose engine
# repo has uncommitted changes, build_p2() refuses to build, by design - the
# products would not name the code that made them.
cat("\nProduct 2 - rebuilding what is out of date\n")
p2_ok <- tryCatch({
  build_p2_stale()
  TRUE
}, error = function(e) {
  cat("X Product 2 not rebuilt: ", conditionMessage(e), "\n", sep = "")
  FALSE
})

#### 5. Push ####
cat("\nBox - pushing what changed\n")
pushed <- box_transfer("push")

#### 6. What needs attention ####
# The job has just asked the API about every device, so the answers are as
# fresh as they will ever be. Cheap to say here rather than wait to be asked.
if (exists("print_network_todo")) {
  try(print_network_todo(quiet_if_clean = TRUE), silent = TRUE)
}

cat("\n============================================\n")
if (!p2_ok) cat("  Product 2 was NOT brought up to date - see above.\n")
if (pushed) {
  cat("  Done.\n")
} else {
  cat("  Data fetched, but NOT pushed to Box.\n")
  cat("  This machine now holds data no other copy has.\n")
}
cat("============================================\n\n")

quit(status = if (pushed) 0 else 1)
