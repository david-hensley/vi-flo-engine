################################################################################
# backup_directory_for_testing.R
# Creates a complete backup of meta_internal folder for safe testing
#
# USAGE:
#   1. Edit the paths below if needed
#   2. Run this script ONCE before testing
#   3. Don't run again until testing is complete
################################################################################

# Load functions
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
load_functions("backup_restore")

################################################################################
#### CONFIGURE PATHS (Edit these as needed) ####
################################################################################

# Directory to backup (default: meta_internal folder in your data root)
source_dir <- wds("meta_internal")

# Where to store the backup (edit this path if you want it elsewhere)
backup_dir <- wds("backup")

################################################################################
#### RUN BACKUP ####
################################################################################

backup_directory(
  source_dir = source_dir,
  backup_dir = backup_dir,
  confirm = TRUE,           # Set to FALSE to skip confirmation prompt
  allow_overwrite = TRUE   # Set to TRUE to allow overwriting existing backup
)
