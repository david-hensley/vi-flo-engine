################################################################################
#                        CONCURRENT WRITE GUARD                                #
#                                                                              #
# A write that overwrites somebody else's work is silent. The file is valid,   #
# nothing errors, and the loss is only noticed when a station's status is      #
# wrong months later - if at all.                                              #
#                                                                              #
# The guard makes it loud. Every read records the file's hash; every write     #
# checks the hash is still what was read. If it is not, the file changed in    #
# between and the write is refused.                                            #
#                                                                              #
#                                                                              #
# WHAT IT CATCHES, AND WHAT IT DOES NOT                                        #
#                                                                              #
# It catches a change made DURING a session: the scheduled download appending  #
# while the manager is open, or a second person writing at the same time.      #
#                                                                              #
# It does NOT catch starting from a stale copy. If the file was already out of #
# date when the session began, its hash matches its own stale read and the     #
# write proceeds. That is what the session status is for - the two cover       #
# different halves of the same problem.                                        #
#                                                                              #
#                                                                              #
# WHY NO FORCE OPTION                                                          #
#                                                                              #
# An escape hatch becomes the routine path. The manager exists so the correct  #
# way is the easy way, and the costs are not symmetric: redoing a workflow     #
# costs minutes, forcing a write over someone's change costs corruption nobody #
# finds for months. A refusal that genuinely obstructs is evidence for         #
# revisiting this - a hypothetical one is not.                                 #
################################################################################


# Hashes of files as this session last read them. Not in the metadata, not on
# disk - it is a fact about this R session, and it should not survive one.
.vi_flo_read_hashes <- new.env(parent = emptyenv())


#' Records the hash of a file as read
#'
#' @param path Character. File that was just read
#' @return Invisible the hash
remember_file_hash <- function(path) {
  if (!file.exists(path)) return(invisible(NA_character_))

  # The content as well as the hash, so a refusal can name which rows differ
  # rather than only reporting that something did. Tens of rows of metadata -
  # the memory is nothing against having to diff the file by hand.
  content <- tryCatch(read.csv(path, stringsAsFactors = FALSE),
                      error = function(e) NULL)

  h <- unname(tools::md5sum(path))
  assign(normalizePath(path, winslash = "/"),
         list(hash = h, content = content), envir = .vi_flo_read_hashes)
  invisible(h)
}


#' The hash this session recorded for a file, if any
#'
#' @param path Character
#' @return Character hash, or NA if this session has not read it
remembered_file_hash <- function(path) {
  r <- remembered_file(path)
  if (is.null(r)) NA_character_ else r$hash
}


#' What this session read: hash and content
#'
#' @param path Character
#' @return List with hash and content, or NULL
remembered_file <- function(path) {
  key <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!exists(key, envir = .vi_flo_read_hashes, inherits = FALSE)) return(NULL)
  get(key, envir = .vi_flo_read_hashes, inherits = FALSE)
}


#' Rows differing between what this session read and what is on disk now
#'
#' Named by whatever identifies them - unique_id, station_id, serial - so the
#' answer is in terms someone recognises rather than row numbers.
#'
#' @param path Character
#' @return Character vector of descriptions, empty if not comparable
rows_changed_on_disk <- function(path) {

  base <- remembered_file(path)
  if (is.null(base) || is.null(base$content)) return(character(0))

  now <- tryCatch(read.csv(path, stringsAsFactors = FALSE),
                  error = function(e) NULL)
  if (is.null(now)) return(character(0))

  id_cols <- Reduce(intersect, list(
    c("unique_id", "station_id", "device_serial", "sn", "port"),
    names(base$content), names(now)))
  if (length(id_cols) == 0) return(character(0))

  shared <- intersect(names(base$content), names(now))

  key_of <- function(df) {
    if (length(id_cols) == 1) as.character(df[[id_cols]])
    else apply(df[, id_cols, drop = FALSE], 1, paste, collapse = " ")
  }
  text_of <- function(df) {
    apply(df[, shared, drop = FALSE], 1,
          function(r) paste(as.character(r), collapse = "\u001f"))
  }

  kb <- key_of(base$content); tb <- setNames(text_of(base$content), kb)
  kn <- key_of(now);          tn <- setNames(text_of(now), kn)

  changed <- character(0)
  for (k in unique(c(kb, kn))) {
    if (!k %in% kb) { changed <- c(changed, paste0(k, "  (added)")); next }
    if (!k %in% kn) { changed <- c(changed, paste0(k, "  (removed)")); next }
    if (!identical(unname(tb[k][1]), unname(tn[k][1]))) changed <- c(changed, k)
  }

  changed
}


#' Forgets a recorded hash
#'
#' Used after a deliberate overwrite - a migration, a restore - where the file
#' on disk is meant to differ from what was read.
#'
#' @param path Character, or NULL for all
#' @return Invisible TRUE
forget_file_hash <- function(path = NULL) {
  if (is.null(path)) {
    rm(list = ls(envir = .vi_flo_read_hashes), envir = .vi_flo_read_hashes)
  } else {
    key <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (exists(key, envir = .vi_flo_read_hashes, inherits = FALSE)) {
      rm(list = key, envir = .vi_flo_read_hashes)
    }
  }
  invisible(TRUE)
}


#' Refuses a write and explains what happened
#'
#' @param path Character. The file
#' @param writing Data frame. What was about to be written
#' @param intent Character. What the caller was doing, in a few words
#' @return Invisible FALSE
report_write_conflict <- function(path, writing, intent = NULL) {

  cat("\n============================================\n")
  cat("  WRITE REFUSED - the file changed underneath\n")
  cat("============================================\n\n")

  cat(basename(path), " is not what this session read. Something else wrote\n",
      sep = "")
  cat("to it - a scheduled download, another machine, or another person.\n\n")

  if (!is.null(intent) && nzchar(intent)) {
    cat("You were doing:\n")
    cat("  ", intent, "\n\n", sep = "")
  }

  mt <- file.mtime(path)
  if (!is.na(mt)) {
    cat("It was last written ", format(mt, "%Y-%m-%d %H:%M"), ".\n\n", sep = "")
  }

  changed <- tryCatch(rows_changed_on_disk(path), error = function(e) character(0))
  if (length(changed) > 0) {
    cat("Changed since you read it:\n")
    for (r in head(changed, 12)) cat("  ", r, "\n", sep = "")
    if (length(changed) > 12) {
      cat("  ... and ", length(changed) - 12, " more\n", sep = "")
    }
    cat("\n")
  }

  cat("Nothing was written. To continue:\n\n")
  cat("  1. Pull the current data if the change came from another machine\n")
  cat("  2. Re-run start.R\n")
  cat("  3. Repeat what you were doing\n\n")

  invisible(FALSE)
}
