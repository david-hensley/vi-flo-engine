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

# ZentraCloud, if the key is there. Every function that reaches the API needs
# this done first, and doing it by hand each session is a step that only ever
# gets forgotten - a download then fails with an authentication error rather
# than saying what is actually missing.
#
# Quiet on success. A missing token is worth a word, because it is the one
# thing a person can fix.
local({
  token <- Sys.getenv("ZENTRACLOUD_V5_TOKEN")

  if (!nzchar(token)) {
    cat("  ! ZENTRACLOUD_V5_TOKEN is not set - downloads will not work\n")
    cat("    Check tools/api_tokens.csv and re-run set_api_tokens.py\n")
  } else if (!requireNamespace("zentraR", quietly = TRUE)) {
    cat("  ! the zentraR package is not installed - downloads will not work\n")
  } else {
    suppressPackageStartupMessages(library(zentraR))
    try(zc_set_key(token), silent = TRUE)
  }
})

# Uncommitted work, a stale archive, metadata changed since the last savepoint.
# Silent when there is nothing to say, so that when it speaks it is read.
if (exists("get_session_status")) {
  try(print_session_status(get_session_status()), silent = TRUE)
}

# Unfinished business is raised on sight, not on request
if (exists("check_pending")) check_pending()

# The handful of things a session usually starts with. Not a menu - just the
# spelling, so none of it has to be remembered or typed from scratch.
cat("  print_network_status()  every station and how it is doing\n")
cat("  print_network_todo()    what needs attention, by kind of work\n")
cat("  save_metadata_state()   savepoint before editing\n")
cat("  revert_metadata_state() undo back to the last savepoint\n\n")
