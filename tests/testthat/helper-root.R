################################################################################
# Test helpers, loaded automatically before every test file
################################################################################

fixture_path <- function(...) {
  file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tests", "testthat", "fixtures", ...)
}

#' A throwaway data root for one test
#'
#' Builds a temporary data root with every named path from
#' default_datamap.csv, writes its datamap_engine.csv, copies in the fixture
#' metadata and maintenance log, and points VI_FLO_DATA_ROOT at it. Undone
#' when the calling test ends: the environment variable is restored and the
#' folder deleted.
#'
#' @param env The test's environment, so cleanup runs when it ends
#' @return Character. The root's path
local_test_root <- function(env = parent.frame()) {
  engine <- Sys.getenv("VI_FLO_ENGINE_ROOT")
  root <- normalizePath(tempfile("viflo-test-"), winslash = "/", mustWork = FALSE)
  dir.create(root, recursive = TRUE)

  dm <- read.csv(file.path(engine, "data", "default_datamap.csv"),
                 stringsAsFactors = FALSE)
  dm$absolute_path <- file.path(root, dm$path)
  for (p in dm$absolute_path) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  write.csv(dm, file.path(root, "datamap_engine.csv"), row.names = FALSE)

  meta <- dm$absolute_path[dm$named_path == "meta_internal"]
  file.copy(fixture_path("device_metadata.csv"), meta)
  file.copy(fixture_path("maintenance_log.csv"), meta)
  file.copy(fixture_path("download_log.csv"), meta)
  file.copy(fixture_path("zentra_ports.csv"), meta)

  old <- Sys.getenv("VI_FLO_DATA_ROOT")
  Sys.setenv(VI_FLO_DATA_ROOT = root)
  withr::defer({
    Sys.setenv(VI_FLO_DATA_ROOT = old)
    unlink(root, recursive = TRUE)
  }, envir = env)

  root
}

#' Runs an interactive workflow with scripted answers
#'
#' Replaces readline() for the duration, feeding it `inputs` in order. Fails
#' if the workflow asks more questions than were supplied, or fewer: either
#' means the workflow no longer asks what the test thinks it asks, which is
#' exactly what a workflow test is for.
#'
#' @param inputs Character vector of answers, in order
#' @param expr The workflow call
#' @return List: value (what the workflow returned), output (what it printed)
with_inputs <- function(inputs, expr) {
  queue <- as.character(inputs)
  fake <- function(prompt = "") {
    if (length(queue) == 0) {
      stop("The workflow asked for more input than the test supplied",
           call. = FALSE)
    }
    x <- queue[1]
    queue <<- queue[-1]
    x
  }

  had <- exists("readline", envir = globalenv(), inherits = FALSE)
  if (had) old <- get("readline", envir = globalenv())
  assign("readline", fake, envir = globalenv())
  on.exit({
    if (had) assign("readline", old, envir = globalenv())
    else rm("readline", envir = globalenv())
  }, add = TRUE)

  value <- NULL
  output <- utils::capture.output(value <- expr)
  if (length(queue) > 0) {
    stop(length(queue), " answer(s) left unused - the workflow asked fewer ",
         "questions than the test expected", call. = FALSE)
  }
  list(value = value, output = output)
}

#' The fixture metadata as it now stands on disk
meta_row <- function(unique_id) {
  m <- load_zentra_metadata()
  m[m$unique_id == unique_id, ]
}

#' The maintenance log as it now stands on disk
read_log <- function() {
  read.csv(file.path(wds("meta_internal"), "maintenance_log.csv"),
           stringsAsFactors = FALSE)
}

#' Copies Product 1 fixtures into the test root where the archive keeps them
#'
#' @param files Character. Filenames under fixtures/p1/
#' @return Character. Their paths in the test root
place_p1 <- function(files) {
  vapply(files, function(f) {
    dir <- if (startsWith(f, "z6-")) wds("device_zentra") else wds("device_hobo")
    to <- file.path(dir, f)
    file.copy(fixture_path("p1", f), to, overwrite = TRUE)
    to
  }, character(1), USE.NAMES = FALSE)
}
# Tests build in throwaway roots without a commit. Set for the suite only:
# run_tests.R restores the session's own value afterwards
options(viflo.test_build = TRUE)
