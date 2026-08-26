# VI-FLO Engine - session start
#
# Loads everything needed for an interactive VI-FLO session, in one line:
#
#   source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
#
# Sources setup_functions.R, loads every other function file, and reports any
# unfinished data tasks.
#
# To go straight into the metadata manager instead, double-click
# tools/launcher/metadata-manager.Rproj.

source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))

load_all_functions()

# Unfinished business is raised on sight, not on request
if (exists("check_pending")) check_pending()
