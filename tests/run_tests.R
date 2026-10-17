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
