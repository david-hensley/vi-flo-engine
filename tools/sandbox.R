################################################################################
# sandbox.R
#
# Try a metadata manager workflow on a throwaway copy of the real metadata.
#
# sandbox_start() copies every metadata table, and the gut survey files, into
# a temporary data root and points the session at it. From then until
# sandbox_end(), everything the engine reads and writes is the copy: run
# metadata_manager() and do anything - add a survey, replace a logger, remove
# a row - and the real data is never touched. sandbox_changes() shows what
# the workflows did to the copy; sandbox_end() puts the session back and
# deletes the copy.
#
# Usage, after start.R - which loads this file:
#   sandbox_start()
#   metadata_manager()          # or any workflow
#   sandbox_changes()           # what changed in the copy
#   sandbox_end()
################################################################################

sandbox_start <- function() {
  real <- Sys.getenv("VI_FLO_DATA_ROOT")
  if (grepl("viflo-sandbox-|viflo-test-", real)) {
    stop("This session is already on a sandbox or test root:\n  ", real,
         "\nRun sandbox_end(), or restart R and run start.R.", call. = FALSE)
  }
  real_meta <- wds("meta_internal")
  real_gut  <- get_gut_survey_dir(create = FALSE)

  root <- normalizePath(tempfile("viflo-sandbox-"), winslash = "/", mustWork = FALSE)
  dir.create(root, recursive = TRUE)
  dm <- utils::read.csv(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "data",
                                  "default_datamap.csv"), stringsAsFactors = FALSE)
  dm$absolute_path <- file.path(root, dm$path)
  for (p in dm$absolute_path) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(dm, file.path(root, "datamap_engine.csv"), row.names = FALSE)

  meta <- dm$absolute_path[dm$named_path == "meta_internal"]
  tables <- list.files(real_meta, pattern = "\\.csv$", full.names = TRUE)
  file.copy(tables, meta)
  options(viflo.sandbox = list(real = real, root = root,
                               devices = read_table("device_metadata", remember = FALSE),
                               surveys = read_table("surveys", remember = FALSE),
                               log_rows = nrow(read_table("maintenance_log", remember = FALSE))))
  Sys.setenv(VI_FLO_DATA_ROOT = root)
  gut <- get_gut_survey_dir(create = TRUE)
  if (dir.exists(real_gut)) file.copy(list.files(real_gut, full.names = TRUE), gut)

  cat("\n✓ Sandbox ready - ", length(tables), " tables copied", sep = "")
  if (dir.exists(real_gut)) cat(", and the gut survey files")
  cat("\n\n  The session now reads and writes a COPY. Your real data is untouched\n")
  cat("  until sandbox_end().\n\n")
  cat("  To try a TruPulse export, copy it into:\n    ", gut, "\n\n", sep = "")
  cat("  metadata_manager()    run any workflow\n")
  cat("  sandbox_changes()     see what it did to the copy\n")
  cat("  sandbox_end()         back to the real data; the copy is deleted\n\n")
  invisible(root)
}


sandbox_changes <- function() {
  sb <- getOption("viflo.sandbox")
  if (is.null(sb)) { cat("No sandbox running\n"); return(invisible(NULL)) }
  meta <- read_table("device_metadata", remember = FALSE)
  now <- read_table("surveys", remember = FALSE)
  key <- function(d) do.call(paste, c(lapply(d, as.character), sep = "\r"))
  added <- now[!key(now) %in% key(sb$surveys), , drop = FALSE]
  gone  <- sb$surveys[!key(sb$surveys) %in% key(now), , drop = FALSE]

  # The device table, field by field: what each row was, and is now
  was <- sb$devices
  cat("\nDevice rows changed in the sandbox:\n")
  n_dev <- 0
  for (uid in union(was$unique_id, meta$unique_id)) {
    a <- was[was$unique_id == uid, , drop = FALSE]
    b <- meta[meta$unique_id == uid, , drop = FALSE]
    label <- paste0(if (nrow(b) > 0) b$device_name else a$device_name, " (",
                    if (nrow(b) > 0) b$station_id else a$station_id, ")")
    if (nrow(a) == 0) { cat("  + ", label, " - new row ", uid, "\n", sep = ""); n_dev <- n_dev + 1; next }
    if (nrow(b) == 0) { cat("  - ", label, " - row ", uid, " deleted\n", sep = ""); n_dev <- n_dev + 1; next }
    for (col in names(a)) {
      va <- format(a[[col]]); vb <- format(b[[col]])
      if (!identical(va, vb)) {
        cat("  ~ ", label, ": ", col, " ", va, " -> ", vb, "\n", sep = "")
        n_dev <- n_dev + 1
      }
    }
  }
  if (n_dev == 0) cat("  (none)\n")

  cat("\nSurvey rows added in the sandbox: ", nrow(added), "\n", sep = "")
  for (i in seq_len(nrow(added))) {
    cat("  + ", describe_survey_row(added[i, ], meta, with_logger = TRUE), "\n", sep = "")
    if (!is.na(added$notes[i])) cat("      notes: ", added$notes[i], "\n", sep = "")
  }
  cat("Survey rows removed in the sandbox: ", nrow(gone), "\n", sep = "")
  for (i in seq_len(nrow(gone))) {
    cat("  - ", describe_survey_row(gone[i, ], meta, with_logger = TRUE), "\n", sep = "")
  }

  log <- read_table("maintenance_log", remember = FALSE)
  if (nrow(log) > sb$log_rows) {
    cat("\nMaintenance log entries written:\n")
    new <- log[(sb$log_rows + 1):nrow(log), , drop = FALSE]
    for (i in seq_len(nrow(new))) {
      cat("  ", format(new$field_visit_date[i]), "  ", new$station_id[i], "  ",
          new$action_type[i], ": ", new$details[i], "\n", sep = "")
    }
  }

  n <- survey_needs(meta, now)
  slope <- n[n$need %in% c("fall to primary", "reach to primary", "no primary"), , drop = FALSE]
  cat("\nPaired gauges that cannot give a slope now: ", nrow(slope), "\n", sep = "")
  for (i in seq_len(nrow(slope))) {
    cat("  ", slope$station_id[i], "  ", slope$device_name[i], ": ", slope$detail[i], "\n", sep = "")
  }
  cat("\n")
  invisible(list(added = added, removed = gone))
}


sandbox_end <- function() {
  sb <- getOption("viflo.sandbox")
  if (is.null(sb)) { cat("No sandbox running\n"); return(invisible(FALSE)) }
  Sys.setenv(VI_FLO_DATA_ROOT = sb$real)
  unlink(sb$root, recursive = TRUE)
  options(viflo.sandbox = NULL)
  cat("✓ Back on the real data (", sb$real, "). The sandbox copy is deleted.\n", sep = "")
  invisible(TRUE)
}
