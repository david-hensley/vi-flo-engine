################################################################################
#  VI-FLO Metadata Manager - launcher
#
#  Double-clicking vi-flo-manager.Rproj opens RStudio here, and this file runs
#  automatically at session start, dropping you straight into the manager.
#
#  This folder exists ONLY to launch the manager. Do not edit code from this
#  project - open the engine repo normally for that, or you will land in the
#  menu every time you sit down to work.
################################################################################

setHook("rstudio.sessionInit", function(newSession) {

  engine_root <- Sys.getenv("VI_FLO_ENGINE_ROOT")

  if (!nzchar(engine_root) || !dir.exists(engine_root)) {
    cat("\nX VI_FLO_ENGINE_ROOT is not set, or does not exist.\n")
    cat("  Run setup_win.exe in the engine repo, then try again.\n\n")
    return(invisible(NULL))
  }

  source(file.path(engine_root, "code/functions/setup_functions.R"))

  # Discovers the function files rather than listing them, so a new one is
  # picked up here automatically
  load_all_functions(quiet = TRUE)

  cat("\n")
  metadata_manager()

}, action = "append")
