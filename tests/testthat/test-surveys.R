################################################################################
# The survey records: surveys.csv, chained into the distances slope needs
#
# A row records one distance between two named points. What is tested here is
# that rows chain into the distances nobody measured directly - a secondary's
# sensor relative to its primary's - and that what is still missing is found
# rather than recorded.
################################################################################

test_that("the fixture's surveys read with their types", {
  local_test_root()
  s <- load_surveys()
  expect_equal(nrow(s), 6)
  expect_s3_class(s$measured_on, "Date")
  expect_true(is.numeric(s$value))
  expect_true(is.na(s$point[s$quantity == "reach_m"]))
})

test_that("a missing surveys.csv is an empty table, not an error", {
  local_test_root()
  file.remove(table_path("surveys"))
  s <- load_surveys()
  expect_equal(nrow(s), 0)
  expect_equal(names(s), names(TABLE_SCHEMA$surveys$columns))
  expect_true(is.na(survey_height("t-0002", "sensor", "t-0001", "sensor", s)))
})

test_that("bta2's sensors chain through the rebar tops, either way round", {
  local_test_root()
  s <- load_surveys()
  # sensor -> rebar (+24.94) -> primary's rebar (+12.94) -> primary's sensor
  expect_equal(survey_height("t-0002", "sensor", "t-0001", "sensor", s), 12.94)
  expect_equal(survey_height("t-0001", "sensor", "t-0002", "sensor", s), -12.94)
  expect_equal(survey_height("t-0002", "rebar", "t-0001", "rebar", s), 12.94)
  expect_equal(survey_height("t-0002", "rebar", "t-0002", "rebar", s), 0)
})

test_that("a chain with a missing link is NA, not a guess", {
  local_test_root()
  s <- load_surveys()
  expect_true(is.na(survey_height("t-0002", "sensor", "t-0001", "bed", s)))
  expect_true(is.na(survey_height("t-0004", "sensor", "t-0001", "sensor", s)))
})

test_that("a row whose points were not recorded links nothing", {
  local_test_root()
  s <- load_surveys()
  s$point[3] <- NA; s$relative_to[3] <- NA
  expect_true(is.na(survey_height("t-0002", "sensor", "t-0001", "sensor", s)))
})

test_that("where two points were surveyed twice, the newest survey stands", {
  local_test_root()
  s <- load_surveys()
  again <- s[3, ]
  again$measured_on <- as.Date("2026-12-01"); again$value <- 13.5
  older <- s[3, ]
  older$measured_on <- as.Date("2025-01-01"); older$value <- 99
  s <- rbind(s, again, older)
  expect_equal(survey_height("t-0002", "sensor", "t-0001", "sensor", s), 13.5)
})

test_that("a negative height means below, and chains like any other", {
  local_test_root()
  s <- load_surveys()
  s$value[3] <- -127.5
  expect_equal(survey_height("t-0002", "sensor", "t-0001", "sensor", s), -127.5)
})

test_that("the reach is found either way round", {
  local_test_root()
  s <- load_surveys()
  expect_equal(survey_reach("t-0002", "t-0001", s), 24.16)
  expect_equal(survey_reach("t-0001", "t-0002", s), 24.16)
  expect_true(is.na(survey_reach("t-0002", "t-0007", s)))
})

test_that("survey_needs lists what each current deployment lacks", {
  local_test_root()
  n <- survey_needs()
  key <- paste(n$unique_id, n$need)
  # bta2: neither sensor's height above the bed, but the fall chains
  expect_true(all(c("t-0001 sensor height", "t-0002 sensor height") %in% key))
  expect_false(any(c("t-0002 fall to primary", "t-0002 reach to primary") %in% key))
  # the pond and the weather station have theirs; vwc needs nothing here
  expect_false(any(c("t-0004 sensor height", "t-0005 sensor height") %in% key))
  expect_false(any(grepl("^t-0006 |^t-0010 |^t-0011 ", key)))
  # a weather station with nothing recorded, and a single gauge
  expect_true("t-0009 sensor height" %in% key)
  expect_true("t-0007 sensor height" %in% key)
  # a retired deployment needs nothing
  expect_false(any(grepl("^t-0003 |^t-0008 ", key)))
})

test_that("a secondary with no chain or reach to its primary is listed for both", {
  local_test_root()
  s <- load_surveys()
  s <- s[!(s$unique_id == "t-0002" & (s$quantity == "reach_m" | !is.na(s$relative_to_id))), ]
  n <- survey_needs(surveys = s)
  expect_true(all(c("fall to primary", "reach to primary") %in%
                    n$need[n$unique_id == "t-0002"]))
})

test_that("the network to-do lists a pair that cannot give a slope, and nothing else", {
  local_test_root()
  todo <- get_network_todo()
  expect_false(any(todo$type == "survey"))

  s <- load_surveys()
  write_table("surveys", s[s$quantity != "reach_m", ], guard = FALSE)
  todo <- get_network_todo()
  sv <- todo[todo$type == "survey", ]
  expect_equal(nrow(sv), 1)
  expect_match(sv$issue, "no reach to testa")
})

test_that("validation passes the fixture's surveys and catches malformed rows", {
  local_test_root()
  res <- validate_metadata(verbose = FALSE)
  expect_false(any(grepl("^SURVEY_", names(res$violations))))

  s <- load_surveys()
  bad <- s[c(4, 1, 1, 1), ]
  bad$point[1] <- "rebar"                 # a reach with a point
  bad$relative_to[2] <- NA                # a point with no reference
  bad$point[3] <- "pipe"                  # not a point in the list
  bad$unique_id[4] <- "t-9999"            # no such logger
  write_table("surveys", rbind(s, bad), guard = FALSE)
  res <- validate_metadata(verbose = FALSE)
  expect_true(all(c("SURVEY_MALFORMED", "SURVEY_UNKNOWN_WORD", "SURVEY_UNKNOWN_LOGGER") %in%
                    names(res$violations)))
})
