################################################################################
# run_tests.R - the VI-FLO Engine test suite
#
# Run by hand before calling a change good, after start.R:
#
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tests/run_tests.R"))
#
# Every test builds its own throwaway data root and points VI_FLO_DATA_ROOT
# at it, so a test can save, back up, migrate and log freely: real metadata
# is never in reach, and the session's own root is restored afterwards.
#
# Needs testthat: install.packages("testthat"), once.
################################################################################

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("The test suite needs testthat. Run install.packages(\"testthat\") once.",
       call. = FALSE)
}

local({
  engine <- Sys.getenv("VI_FLO_ENGINE_ROOT")
  if (!nzchar(engine)) {
    stop("VI_FLO_ENGINE_ROOT is not set - run start.R first.", call. = FALSE)
  }

  # The session is left exactly as found, whatever a test does. Every test
  # points VI_FLO_DATA_ROOT at a throwaway folder and restores it; this is the
  # guard behind them, after one test once cancelled its own cleanup and left
  # a session on a test's folder - writing, from then on, to fixture data
  data_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (grepl("viflo-test-", data_root, fixed = TRUE)) {
    stop("This session's data root is a test's throwaway folder:\n  ", data_root,
         "\nRestart R and run start.R before running the suite.", call. = FALSE)
  }
  old_option <- getOption("viflo.test_build")
  on.exit({
    if (!identical(Sys.getenv("VI_FLO_DATA_ROOT"), data_root)) {
      message("! A test left the data root changed - restored to ", data_root)
      Sys.setenv(VI_FLO_DATA_ROOT = data_root)
    }
    options(viflo.test_build = old_option)
  }, add = TRUE)

  # Load the functions fresh, so the suite tests the files on disk rather
  # than whatever this session last sourced
  # test_dir() attaches testthat, which masks functions of the same name in
  # other packages - terra's compare() and describe(), for one. Left as found.
  was_attached <- "package:testthat" %in% search()
  on.exit(if (!was_attached && "package:testthat" %in% search()) {
    detach("package:testthat")
  }, add = TRUE)

  source(file.path(engine, "code/functions/setup_functions.R"))
  suppressMessages(load_all_functions(quiet = TRUE))

  results <- testthat::test_dir(file.path(engine, "tests", "testthat"),
                                env = globalenv(), stop_on_failure = FALSE,
                                reporter = "progress")

  df <- as.data.frame(results)
  failed <- sum(df$failed) + sum(df$error)
  cat("\n")
  if (failed == 0) {
    cat("\u2713 All ", sum(df$nb), " expectations passed across ",
        nrow(df), " tests\n", sep = "")
  } else {
    cat("\u274c ", failed, " test(s) failed - see above\n", sep = "")
  }
  invisible(results)
})
