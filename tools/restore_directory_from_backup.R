################################################################################
# restore_directory_from_backup.R
# Restores meta_internal folder from backup
#
# USAGE:
#   1. Edit the paths below if needed (should match backup script)
#   2. Run this script anytime you want to reset to pristine state
#   3. Type 'YES' when prompted to confirm
################################################################################

# Load functions
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
load_functions("backup_restore")

################################################################################
#### CONFIGURE PATHS (Edit these as needed) ####
################################################################################

# Where the backup is stored (should match backup script)
backup_dir <- wds("backup")

# Where to restore to (default: meta_internal folder in your data root)
destination_dir <- wds("meta_internal")

################################################################################
#### RUN RESTORATION ####
################################################################################

restore_directory(
  backup_dir = backup_dir,
  dest_dir = destination_dir,
  confirm = TRUE  # Set to FALSE to skip confirmation prompt
)
