################################################################################
#                           SESSION STATUS                                     #
#                                                                              #
# What a person needs to know on opening a session, without having to ask:     #
# whether work was left uncommitted on this machine or another, whether the    #
# metadata has drifted from its last savepoint, when the archive last updated, #
# and whether anything is unfinished.                                          #
#                                                                              #
# Every one of those has been a real question. Working across two machines,    #
# "which one did I last use, and did I commit?" is not answerable from memory  #
# and is expensive to get wrong.                                               #
#                                                                              #
# get_session_status() gathers; print_session_status() renders. Separate, so   #
# a dashboard or a scheduled job can use the same facts without a console.     #
################################################################################


# The Box location, as rclone addresses it. Not a path on any disk - "Box:" is
# the remote you configured, and what follows is a location in the Box account
# itself, so this is the same string on every machine.
#
# Deliberately a constant here rather than an entry in the datamap or a new
# config file. The whole Box check is temporary: it exists because the archive
# lives on Box today, and it disappears when the archive moves to Hugging Face
# and metadata to git. Keeping it in the file that will be deleted means
# nothing else has to learn about it and then forget.
BOX_DATA_PATH <- "Box:/VI-FLO/Core/data"


#' Runs a git command in a repository, returning its output
#'
#' @param args Character vector of arguments
#' @param repo Character. Repository directory
#' @param timeout Numeric. Seconds before giving up
#' @return Character vector of output lines, or NULL if git could not run
git_run <- function(args, repo, timeout = 10) {
  if (!dir.exists(file.path(repo, ".git"))) return(NULL)

  out <- tryCatch(
    suppressWarnings(
      system2("git", c("-C", shQuote(repo), args),
              stdout = TRUE, stderr = FALSE, timeout = timeout)),
    error = function(e) NULL)

  if (is.null(out)) return(NULL)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) return(NULL)
  out
}


#' State of a git repository
#'
#' Fetches first, so "behind" means something. Without it the answer is only
#' about this machine, and the question that prompted this was about the other
#' one. A failed fetch is not an error - it usually means no network, and the
#' local facts are still worth reporting.
#'
#' @param repo Character. Repository directory
#' @param fetch Logical. Contact the remote first
#' @return List with available, clean, uncommitted, ahead, behind, branch
git_state <- function(repo, fetch = TRUE) {

  none <- list(available = FALSE, clean = NA, uncommitted = NA_integer_,
               files = character(0),
               ahead = NA_integer_, behind = NA_integer_, branch = NA_character_,
               fetched = FALSE)

  if (is.null(git_run("rev-parse --git-dir", repo))) return(none)

  fetched <- FALSE
  if (fetch) {
    fetched <- !is.null(git_run(c("fetch", "--quiet"), repo, timeout = 15))
  }

  dirty <- git_run(c("status", "--porcelain"), repo)
  branch <- git_run(c("rev-parse", "--abbrev-ref", "HEAD"), repo)

  counts <- git_run(c("rev-list", "--left-right", "--count", "HEAD...@{u}"), repo)
  ahead <- behind <- NA_integer_
  if (!is.null(counts) && length(counts) == 1) {
    parts <- suppressWarnings(as.integer(strsplit(trimws(counts), "\\s+")[[1]]))
    if (length(parts) == 2) { ahead <- parts[1]; behind <- parts[2] }
  }

  list(available   = TRUE,
       clean       = length(dirty) == 0,
       uncommitted = length(dirty),
       # Named, not counted. "2 uncommitted changes" prompts a second command
       # to find out which, which is the question the line was meant to answer.
       files       = if (length(dirty) > 0) substring(dirty, 4) else character(0),
       ahead       = ahead,
       behind      = behind,
       branch      = if (is.null(branch)) NA_character_ else branch[1],
       fetched     = fetched)
}


#' How far the metadata has drifted from its last savepoint
#'
#' Not a backup check - a change check. A file differing from the savepoint
#' means something was written since, which is normal after using the manager
#' and worth knowing before running a migration.
#'
#' @return List with available, changed, added, savepoint_time
metadata_drift <- function() {

  none <- list(available = FALSE, changed = character(0), added = character(0),
               savepoint_time = NA)

  live <- tryCatch(wds("meta_internal"), error = function(e) NULL)
  save <- tryCatch(wds("backup"), error = function(e) NULL)
  if (is.null(live) || is.null(save) || !dir.exists(save)) return(none)

  # Top-level CSVs only. The backups and photo folders are not state.
  live_files <- list.files(live, pattern = "\\.csv$")
  save_files <- list.files(save, pattern = "\\.csv$")

  changed <- character(0)
  for (f in intersect(live_files, save_files)) {
    a <- tools::md5sum(file.path(live, f))
    b <- tools::md5sum(file.path(save, f))
    if (!identical(unname(a), unname(b))) changed <- c(changed, f)
  }

  stamp <- if (length(save_files) > 0) {
    max(file.mtime(file.path(save, save_files)))
  } else NA

  list(available      = TRUE,
       changed        = changed,
       added          = setdiff(live_files, save_files),
       savepoint_time = stamp)
}


#' The most recent scheduled download
#'
#' @return One row of run_log.csv, or NULL
last_run <- function() {
  f <- tryCatch(file.path(wds("meta_internal"), "run_log.csv"),
                error = function(e) NULL)
  if (is.null(f) || !file.exists(f)) return(NULL)

  log <- tryCatch(read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(log) || nrow(log) == 0) return(NULL)

  log[nrow(log), ]
}


#' Gathers everything worth knowing at session start
#'
#' @param fetch Logical. Contact the git remote
#' @param box Logical. Ask rclone what Box holds
#' @param quiet Logical. Suppress the please-wait line
#' @return List of facts, for printing or for a caller that wants them
get_session_status <- function(fetch = TRUE, box = TRUE, quiet = FALSE) {

  # Said before, not after. The git fetch and the two rclone checks take about
  # a dozen seconds between them, and a console that sits silent for that long
  # looks like it has hung.
  if (!quiet && (fetch || box)) {
    cat("  Checking session status (a few seconds)...\n")
    flush.console()
  }

  list(
    engine   = git_state(Sys.getenv("VI_FLO_ENGINE_ROOT"), fetch = fetch),
    drift    = metadata_drift(),
    run      = last_run(),
    box      = if (box) box_data_state() else NULL
  )
}


#' Renders the session status
#'
#' Silent where there is nothing to say. A line that appears every time is a
#' line that stops being read, so the git state is only mentioned when it is
#' not clean and current.
#'
#' @param status List from get_session_status()
#' @return Invisible TRUE
print_session_status <- function(status) {

  # Overwrite the please-wait line rather than leaving it above the report
  cat("\r", strrep(" ", 48), "\r", sep = "")

  # Every category reports, including when it has nothing to say. Silence is
  # ambiguous - a line that does not appear could mean "checked and fine" or
  # "never ran", and after waiting twelve seconds for the Box check the
  # difference matters.
  label <- function(x) cat("  ", format(x, width = 15), sep = "")

  #### Engine repo ####
  g <- status$engine

  if (!g$available) {
    label("Engine repo:"); cat("not a git checkout\n")
  } else {
    bits <- character(0)
    if (!isTRUE(g$clean)) {
      bits <- c(bits, paste0(g$uncommitted, " uncommitted change",
                             if (g$uncommitted != 1) "s" else ""))
    }
    if (!is.na(g$ahead) && g$ahead > 0) {
      bits <- c(bits, paste0(g$ahead, " commit", if (g$ahead != 1) "s" else "",
                             " not pushed"))
    }
    if (!is.na(g$behind) && g$behind > 0) {
      bits <- c(bits, paste0(g$behind, " commit", if (g$behind != 1) "s" else "",
                             " to pull"))
    }

    if (length(bits) == 0) {
      label("Engine repo:")
      cat(if (g$fetched) "clean and up to date\n"
          else "clean locally (could not reach the remote)\n")
    } else {
      label("Engine repo:"); cat(paste(bits, collapse = ", "), "\n", sep = "")

      for (f in head(g$files, 6)) cat("                   ", f, "\n", sep = "")
      if (length(g$files) > 6) {
        cat("                   ... and ", length(g$files) - 6, " more\n", sep = "")
      }
      if (!is.na(g$behind) && g$behind > 0) {
        cat("                   (work from the other machine - pull before editing)\n")
      }
      if (!g$fetched) {
        cat("                   (could not reach the remote - the pull side is unchecked)\n")
      }
    }
  }

  #### Metadata against its savepoint ####
  d <- status$drift
  if (!isTRUE(d$available)) {
    label("Metadata:"); cat("no savepoint to compare against\n")
  } else {
    n <- length(d$changed) + length(d$added)
    age <- ""
    if (!is.na(d$savepoint_time)) {
      age <- paste0("savepoint ", format(d$savepoint_time, "%Y-%m-%d %H:%M"))
    }

    if (n == 0) {
      label("Metadata:")
      cat("matches the savepoint", if (nzchar(age)) paste0("  (", age, ")") else "",
          "\n", sep = "")
    } else {
      label("Metadata:")
      cat(n, " file", if (n != 1) "s" else "",
          " changed since the last savepoint: ",
          paste(c(d$changed, d$added), collapse = ", "), "\n", sep = "")
      if (nzchar(age)) cat("                   ", age, "\n", sep = "")
    }
  }

  #### Box ####
  b <- status$box
  if (is.null(b)) {
    label("Box:"); cat("not checked\n")
  } else if (!isTRUE(b$available)) {
    label("Box:"); cat("could not check - ", b$reason, "\n", sep = "")
  } else {
    pull <- if (is.na(b$missing_here)) 0 else b$missing_here
    push <- if (is.na(b$missing_there)) 0 else b$missing_there
    diff <- if (is.na(b$differing)) 0 else b$differing

    if (pull + push + diff == 0) {
      label("Box:"); cat("in sync\n")
    } else {
      # Stated, not interpreted. A file on one side and not the other means
      # either that it was added there or removed here, and rclone cannot tell
      # which - so neither can this. Saying "PULL before working" would be
      # wrong half the time, and a warning that is wrong half the time is one
      # nobody reads.
      label("Box:")
      cat("differs\n")

      show <- function(heading, files, n) {
        if (n == 0) return(invisible(NULL))
        cat("                   ", heading, "\n", sep = "")
        for (f in head(files, 6)) cat("                     ", f, "\n", sep = "")
        if (length(files) > 6) {
          cat("                     ... and ", length(files) - 6, " more\n", sep = "")
        }
        # Counted but unnamed means rclone said how many without saying which
        if (length(files) == 0) {
          cat("                     (", n, " file", if (n != 1) "s" else "",
              ", not named by rclone)\n", sep = "")
        }
      }

      show("on Box, not here:", b$files_on_box, pull)
      show("here, not on Box:", b$files_here, push)
      show("on both but different:", b$files_differ, diff)
    }
  }

  #### Last download ####
  r <- status$run
  if (is.null(r)) {
    label("Last download:"); cat("no runs recorded\n")
  } else {
    when <- tryCatch(as.POSIXct(r$started_utc, tz = "UTC"), error = function(e) NA)
    if (is.na(when)) {
      label("Last download:"); cat("unreadable run log\n")
    } else {
      days <- as.numeric(difftime(Sys.time(), when, units = "days"))
      label("Last download:")
      cat(format(when, "%Y-%m-%d"), "  (",
          if (days < 1) "today" else paste0(round(days), "d ago"), ")",
          if (!identical(r$status, "ok")) paste0("  - ", r$status) else "",
          "\n", sep = "")
      if (days > 8) cat("                   the archive is going stale\n")
    }
  }

  cat("\n")
  invisible(TRUE)
}


#' How the local data root differs from Box
#'
#' `rclone check` compares listings by size and modification time. Nothing is
#' transferred and nothing can be deleted - it only reports.
#'
#' Run in both directions, because the two answers mean different things. Files
#' present on Box but not here mean somebody worked on the other machine and
#' this copy is stale. Files here but not on Box mean this session's work -
#' metadata, an ingested .hobo file, a station photo - has not been pushed.
#'
#' The whole data root, not just metadata. The manager writes archive files too,
#' and a check that covered only metadata would call a session clean while an
#' ingested file existed nowhere else.
#'
#' Around six seconds for 650 files. Slow enough to notice, worth it for one
#' answer about everything rather than two about parts.
#'
#' @param timeout Numeric. Seconds before giving up
#' @return List with available, missing_here, missing_there, differing, reason
box_data_state <- function(timeout = 60) {

  none <- function(reason) list(available = FALSE, missing_here = NA_integer_,
                                missing_there = NA_integer_,
                                differing = NA_integer_, reason = reason)

  box_data <- BOX_DATA_PATH
  local_root <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (!nzchar(local_root)) return(none("VI_FLO_DATA_ROOT not set"))

  # datamap_*.csv is machine-specific by design and is never synced. The rest
  # is editor and OS litter - not data, and a sync warning driven by a stray
  # .Rhistory is a warning that stops being read.
  ignore <- c("datamap_*.csv", ".Rhistory", ".RData", ".Rproj.user/**",
              "Thumbs.db", ".DS_Store", "~$*")

  check <- function(src, dst) {
    args <- c("check", shQuote(src), shQuote(dst), "--one-way")
    for (pat in ignore) args <- c(args, "--exclude", shQuote(pat))

    out <- tryCatch(
      suppressWarnings(
        system2("rclone", args, stdout = TRUE, stderr = TRUE, timeout = timeout)),
      error = function(e) NULL)

    if (is.null(out)) return(NULL)

    grab <- function(pattern) {
      hit <- grep(pattern, out, value = TRUE)
      if (length(hit) == 0) return(0L)
      as.integer(sub(paste0(".*?(\\d+) ", pattern, ".*"), "\\1", hit[1]))
    }

    # The filenames, not only the counts. rclone names each one on an ERROR
    # line; discarding them meant the report could say how many differed but
    # not which, leaving the reader to go and run something to find out.
    detail <- function(marker) {
      hits <- grep(paste0("ERROR : .*: ", marker), out, value = TRUE)
      if (length(hits) == 0) return(character(0))
      trimws(sub("^.*ERROR : (.*?): .*$", "\\1", hits))
    }

    list(missing   = grab("files missing"),
         differing = grab("differences found"),
         missing_files   = detail("file not in"),
         differing_files = detail("sizes differ|md5 differ|modification time"))
  }

  # What Box has that we do not
  from_box <- check(box_data, local_root)
  if (is.null(from_box)) return(none("rclone could not be reached"))

  # What we have that Box does not
  from_here <- check(local_root, box_data)

  list(available     = TRUE,
       missing_here  = from_box$missing,
       missing_there = if (is.null(from_here)) NA_integer_ else from_here$missing,
       differing     = from_box$differing,
       files_on_box  = from_box$missing_files,
       files_here    = if (is.null(from_here)) character(0) else from_here$missing_files,
       files_differ  = from_box$differing_files,
       reason        = "")
}
