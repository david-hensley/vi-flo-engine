################################################################################
# backup_restore_functions.R
# Generic functions for backing up and restoring directory contents
#
# Functions are designed to be reusable for any directory backup/restore needs
################################################################################

#' Backup entire directory contents to a backup location
#' 
#' Recursively copies all files and subdirectories from source to backup location.
#' By default, will not overwrite an existing backup (safety feature).
#' 
#' @param source_dir Character. Path to directory that will be backed up
#' @param backup_dir Character. Path where backup will be created
#' @param confirm Logical. If TRUE, prompts for confirmation before proceeding (default TRUE)
#' @param allow_overwrite Logical. If TRUE, allows overwriting existing backup (default FALSE)
#' @return TRUE if successful, stops with error message if failed
#' 
#' @examples
#' backup_directory("C:/data/meta_internal", "C:/backup/meta_internal")
#' backup_directory(source, backup, confirm = FALSE)  # No prompt
backup_directory <- function(source_dir, backup_dir, confirm = TRUE, allow_overwrite = FALSE) {
  
  cat("\n============================================\n")
  cat("  Backup Directory\n")
  cat("============================================\n\n")
  
  # Validate source exists
  if (!dir.exists(source_dir)) {
    stop("❌ Source directory does not exist: ", source_dir)
  }
  
  # Check if backup already exists
  if (dir.exists(backup_dir) && !allow_overwrite) {
    stop("❌ Backup directory already exists: ", backup_dir, "\n",
         "Delete it first or set allow_overwrite = TRUE")
  }
  
  # Show what will be backed up
  cat("Source:      ", source_dir, "\n")
  cat("Destination: ", backup_dir, "\n\n")
  
  # Count files and subdirectories
  all_files <- list.files(source_dir, recursive = TRUE, full.names = FALSE, all.files = TRUE)
  all_files <- all_files[!all_files %in% c(".", "..")]  # Remove . and ..
  
  if (length(all_files) == 0) {
    stop("❌ Source directory is empty")
  }
  
  cat("Files/directories to backup: ", length(all_files), "\n\n")
  
  # Confirmation
  if (confirm) {
    cat("Type 'YES' to proceed with backup: ")
    response <- toupper(trimws(readline()))
    
    if (response != "YES") {
      cat("❌ Backup cancelled\n")
      return(FALSE)
    }
    cat("\n")
  }
  
  # Create backup directory
  dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Copy all files and subdirectories
  cat("Backing up...\n")
  
  # Get list of all items (files and directories)
  all_items <- list.files(source_dir, recursive = TRUE, full.names = TRUE, 
                          all.files = TRUE, include.dirs = TRUE)
  all_items <- all_items[!basename(all_items) %in% c(".", "..")]
  
  success_count <- 0
  fail_count <- 0
  
  for (item in all_items) {
    # Get relative path
    rel_path <- sub(paste0("^", normalizePath(source_dir, winslash = "/"), "/?"), "", 
                    normalizePath(item, winslash = "/"))
    dest_path <- file.path(backup_dir, rel_path)
    
    # If it's a directory, create it
    if (dir.exists(item)) {
      dir.create(dest_path, recursive = TRUE, showWarnings = FALSE)
    } else {
      # It's a file - create parent directory if needed
      parent_dir <- dirname(dest_path)
      if (!dir.exists(parent_dir)) {
        dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
      }
      
      # Copy file
      result <- file.copy(
        from = item,
        to = dest_path,
        overwrite = allow_overwrite
      )
      
      if (result) {
        success_count <- success_count + 1
      } else {
        fail_count <- fail_count + 1
        cat("  ❌ Failed:", rel_path, "\n")
      }
    }
  }
  
  # Verify backup
  backup_files <- list.files(backup_dir, recursive = TRUE, full.names = FALSE, all.files = TRUE)
  backup_files <- backup_files[!backup_files %in% c(".", "..")]
  
  cat("\n============================================\n")
  cat("Backup Summary:\n")
  cat("  Source files:    ", length(all_files), "\n")
  cat("  Backed up files: ", length(backup_files), "\n")
  cat("  Location:        ", backup_dir, "\n")
  cat("============================================\n\n")
  
  if (length(backup_files) != length(all_files)) {
    warning("⚠️  File count mismatch - some files may not have been backed up")
  }
  
  cat("✓ Backup complete!\n\n")
  
  return(TRUE)
}


#' Restore directory contents from backup
#' 
#' Recursively copies all files and subdirectories from backup to destination.
#' OVERWRITES existing files in destination.
#' 
#' @param backup_dir Character. Path to backup directory
#' @param dest_dir Character. Path where files will be restored
#' @param confirm Logical. If TRUE, prompts for confirmation before proceeding (default TRUE)
#' @return TRUE if successful, stops with error message if failed
#' 
#' @examples
#' restore_directory("C:/backup/meta_internal", "C:/data/meta_internal")
#' restore_directory(backup, dest, confirm = FALSE)  # No prompt
restore_directory <- function(backup_dir, dest_dir, confirm = TRUE) {
  
  cat("\n============================================\n")
  cat("  Restore Directory from Backup\n")
  cat("============================================\n\n")
  
  # Validate backup exists
  if (!dir.exists(backup_dir)) {
    stop("❌ Backup directory does not exist: ", backup_dir)
  }
  
  # Count files in backup
  backup_files <- list.files(backup_dir, recursive = TRUE, full.names = FALSE, all.files = TRUE)
  backup_files <- backup_files[!backup_files %in% c(".", "..")]
  
  if (length(backup_files) == 0) {
    stop("❌ Backup directory is empty")
  }
  
  # Show what will be restored
  cat("Source:      ", backup_dir, "\n")
  cat("Destination: ", dest_dir, "\n")
  cat("Files to restore: ", length(backup_files), "\n\n")
  
  cat("⚠️  WARNING: This will OVERWRITE existing files in destination!\n\n")
  
  # Confirmation
  if (confirm) {
    cat("Type 'YES' to proceed with restoration: ")
    response <- toupper(trimws(readline()))
    
    if (response != "YES") {
      cat("❌ Restoration cancelled\n")
      return(FALSE)
    }
    cat("\n")
  }
  
  # Create destination if it doesn't exist
  if (!dir.exists(dest_dir)) {
    cat("Creating destination directory...\n")
    dir.create(dest_dir, recursive = TRUE)
  }
  
  # Copy entire directory tree
  cat("Restoring...\n")
  
  # Get list of all files and directories in backup
  all_items <- list.files(backup_dir, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  all_items <- all_items[!basename(all_items) %in% c(".", "..")]
  
  success_count <- 0
  fail_count <- 0
  
  for (item in all_items) {
    # Get relative path
    rel_path <- sub(paste0("^", backup_dir, "/?"), "", item)
    dest_path <- file.path(dest_dir, rel_path)
    
    # Create parent directory if needed
    parent_dir <- dirname(dest_path)
    if (!dir.exists(parent_dir)) {
      dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
    }
    
    # Copy file (skip if it's a directory)
    if (!dir.exists(item)) {
      result <- file.copy(
        from = item,
        to = dest_path,
        overwrite = TRUE
      )
      
      if (result) {
        success_count <- success_count + 1
      } else {
        fail_count <- fail_count + 1
        cat("  ❌ Failed:", rel_path, "\n")
      }
    }
  }
  
  cat("\n============================================\n")
  cat("Restoration Summary:\n")
  cat("  Files restored: ", success_count, "\n")
  if (fail_count > 0) {
    cat("  ⚠️  Failed:     ", fail_count, "\n")
  }
  cat("  Location:       ", dest_dir, "\n")
  cat("============================================\n\n")
  
  if (fail_count > 0) {
    warning("⚠️  Some files failed to restore")
  }
  
  cat("✓ Restoration complete!\n\n")
  
  return(TRUE)
}