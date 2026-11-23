# VI-FLO Engine - session start
#
# Loads everything needed for an interactive VI-FLO session, in one line:
#
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#
# Sources setup_functions.R, loads every other function file, connects to
# ZentraCloud, reports anything about the session worth knowing, and raises any
# unfinished data tasks.
#
# To go straight into the metadata manager instead, double-click
# tools/launcher/metadata-manager.Rproj.

source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))

load_all_functions()

# The sandbox is loaded with everything else, so trying a workflow on a copy
# is one call. It is in tools/ rather than code/functions because nothing in
# the engine calls it - it only ever runs when asked for
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools/sandbox.R"))

# The test suite, by name, so the one line to remember is start.R. It reloads
# the functions from disk itself, so it tests the files as they stand
run_tests <- function() {
  invisible(source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tests/run_tests.R"))$value)
}

# Uncommitted work, a stale archive, a data root that differs from Box.
# Silent when there is nothing to say, so that when it speaks it is read.
if (exists("get_session_status")) {
  try(print_session_status(get_session_status()), silent = TRUE)
}

# Unfinished business is raised on sight, not on request. A table that cannot
# be read is reported, not allowed to stop the session from starting - the
# tools to repair it are loaded, and are needed most exactly then
if (exists("check_pending")) {
  tryCatch(check_pending(), error = function(e) {
    cat("\n  ! Could not list unfinished offloads:\n    ",
        gsub("\n", "\n    ", conditionMessage(e)), "\n\n", sep = "")
  })
}

# Whether the metadata holds together: one line, and never a reason not to
# start - a problem is fixed from inside the session
if (exists("print_validation_line")) {
  try(print_validation_line(), silent = TRUE)
}

# The handful of things a session usually starts with. Not a menu - just the
# spelling, so none of it has to be remembered or typed from scratch.
cat("  print_network_status()  every station and how it is doing\n")
cat("  print_network_todo()    the to-do list - field work, then desk work\n")
cat("  sandbox_start()         try a workflow on a copy of the metadata\n")
cat("  run_tests()             the test suite\n\n")
