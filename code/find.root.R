# Inside the script
this_file <- function() {
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  match <- grep("--file=", cmdArgs)
  if (length(match) > 0) {
    return(normalizePath(sub("--file=", "", cmdArgs[match])))
  } else {
    return(NULL)
  }
}

# Get directory
dirname(this_file())

repo.root <- Sys.getenv("VI_FLO_ENGINE_ROOT")
setwd(repo.root)
list.files()
