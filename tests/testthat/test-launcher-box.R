# The launcher's check against Box, before the metadata manager opens. Given a
# state rather than running rclone, so nothing here reaches Box.

box_state <- function(here = 0, there = 0, differ = 0,
                      on_box = character(0), on_here = character(0),
                      differing = character(0)) {
  list(available = TRUE, missing_here = here, missing_there = there,
       differing = differ, files_on_box = on_box, files_here = on_here,
       files_differ = differing, reason = "")
}

test_that("in sync, the launcher says so and opens the menu without asking", {
  r <- with_inputs(character(0), launcher_box_check(box_state()))
  expect_true(r$value)
  expect_true(any(grepl("Box:.*in sync", r$output)))
})

test_that("when Box cannot be checked, it says why and opens the menu anyway", {
  down <- list(available = FALSE, missing_here = NA, missing_there = NA,
               differing = NA, reason = "rclone could not be reached")
  r <- with_inputs(character(0), launcher_box_check(down))
  expect_true(r$value)
  expect_true(any(grepl("could not check - rclone could not be reached", r$output)))
})

test_that("when the copies differ, the files are named and the menu waits for a yes", {
  st <- box_state(here = 1, differ = 1,
                  on_box = "metadata/internal/maintenance_log.csv",
                  differing = "metadata/internal/known_unattributed.csv")
  r <- with_inputs("y", launcher_box_check(st))
  expect_true(r$value)
  out <- paste(r$output, collapse = "\n")
  expect_match(out, "differs")
  expect_match(out, "on Box, not here:\\s+metadata/internal/maintenance_log.csv")
  expect_match(out, "on both but different:\\s+metadata/internal/known_unattributed.csv")
  expect_match(out, "Open the metadata manager anyway?", fixed = TRUE)
})

test_that("answering no keeps the menu closed and says what to do", {
  r <- with_inputs("n", launcher_box_check(box_state(there = 2, on_here = c("a.csv", "b.csv"))))
  expect_false(r$value)
  out <- paste(r$output, collapse = "\n")
  expect_match(out, "here, not on Box:\\s+a.csv\\s+b.csv")
  expect_match(out, "Not opened")
})

test_that("start.R's session report prints Box the same way the launcher does", {
  st <- box_state(differ = 1, differing = "metadata/internal/surveys.csv")
  launcher <- with_inputs("y", launcher_box_check(st))$output
  session <- utils::capture.output(print_session_status(
    list(engine = list(available = FALSE), run = NULL, box = st)))
  box_lines <- function(x) x[seq(grep("Box:", x)[1], grep("surveys.csv", x)[1])]
  expect_identical(box_lines(session), box_lines(launcher))
})

test_that("box_differs reads a state as differing, in sync, or unknown", {
  expect_false(box_differs(box_state()))
  expect_true(box_differs(box_state(here = 3)))
  expect_true(is.na(box_differs(list(available = FALSE))))
  expect_true(is.na(box_differs(NULL)))
})
