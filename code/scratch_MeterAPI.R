library(remotes)
url <- "https://gitlab.com/meter-group-inc/pubpackages/zentracloud"
remotes::install_git(url = url)

library(zentracloud)

setZentracloudOptions(
  token = Sys.getenv("ZENTRACLOUD_TOKEN"),
  domain = "default"
)

# Check if it worked
getZentracloudOptions()


# Embed this code in download functions to ensure zentracloud package
# and Git are both installed
if (!require("zentracloud", quietly = TRUE)) {
  if (!require("remotes")) install.packages("remotes")
  
  tryCatch({
    remotes::install_git("https://gitlab.com/meter-group-inc/pubpackages/zentracloud")
  }, error = function(e) {
    if (grepl("Git does not seem to be installed", e$message)) {
      stop("Git is not installed or not found in system PATH.\n",
           "Please install Git from https://git-scm.com/downloads\n",
           "After installing, restart R and try again.")
    } else {
      stop(e)  # Re-throw other errors
    }
  })
  
  library(zentracloud)
}