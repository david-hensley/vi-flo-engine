################################################################################
# check_layer_v2.9.R - proves the v2.9 data layer changes nothing
#
# APPLIED: not yet
#
# Step 3 of v2.9 routes every read and write of the metadata through one new
# layer (table_functions.R). It is meant to change plumbing only: the tables
# and Product 2 should come out exactly as they were. This script is how we
# know they did, rather than how we hope.
#
# Two halves, run on the same machine, with start.R loaded:
#
#   layer_check_before()  ONCE, now - before the layer's code is pulled.
#                         Keeps a copy of every metadata table and a
#                         fingerprint of every Product 2 file, in one file in
#                         metadata/internal/backups. Copies of the tables (they
#                         are small) rather than fingerprints, so that a
#                         difference later can be shown cell by cell
#
#   layer_check_after()   After the layer's code is in and build_p2_stale()
#                         has rebuilt Product 2 with it. Compares, and changes
#                         nothing
#
# What "after" checks:
#
#   1. Each metadata table against its copy. Byte-identical is the hope. Where
#      not, it says what differs - rows added, rows gone, cells changed by
#      column - so a week's download (new download_log rows, a new battery
#      reading) is told apart from the layer reformatting something
#   2. Each table read and written back through the layer, to a temporary
#      file, against the file on disk. This is the real test of the layer on
#      real data. Every value must survive. The bytes may differ once, on a
#      table not yet written through the layer, whose old formatting is
#      normalized on its first write
#   3. Each Product 2 file whose inputs are unchanged since "before" - the
#      same Product 1 files, the same metadata and port fingerprints - against
#      its fingerprint. Its content and its manifest row must match exactly.
#      A file whose inputs changed (a download since) is listed and not
#      compared: it was always going to differ
#
# Deleted at the v2.9 tag with its fingerprint file, as the migrations
# README's rule says.
################################################################################

LAYER_CHECK_FILE <- function() {
  file.path(wds("meta_internal"), "backups", "layer_v2.9_fingerprints.rds")
}

# The manifest columns that describe what a file holds. engine and built_utc
# are left out: a rebuild changes both by design.
LAYER_CHECK_MANIFEST_COLS <- c(
  "rows", "observed", "missing", "conflicts", "repeats", "repeat_dropped",
  "first", "last", "timezone", "unit", "devices", "deployments", "device_names",
  "alignment", "intervals", "problems", "source_files"
)

#' MD5 of a gzip file's decompressed content
#'
#' The compressed bytes are not compared: a gzip header can carry the time it
#' was written, so the same content compressed twice can differ.
layer_check_content_md5 <- function(path) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  src <- gzfile(path, "rb")
  dst <- file(tmp, "wb")
  repeat {
    chunk <- readBin(src, "raw", 1e6)
    if (length(chunk) == 0) break
    writeBin(chunk, dst)
  }
  close(src)
  close(dst)
  unname(tools::md5sum(tmp))
}

#' Takes the "before" record
#'
#' @param overwrite Logical. Replace an existing record. Only ever wanted if
#'   the layer's code has not been pulled yet - after that, a new "before"
#'   would be taken with the new code and prove nothing
layer_check_before <- function(overwrite = FALSE) {
  f <- LAYER_CHECK_FILE()
  if (file.exists(f) && !overwrite) {
    stop("A 'before' record already exists:\n  ", f,
         "\nIt is only ever taken once. Use overwrite = TRUE only if the data ",
         "layer's code has not been pulled yet.", call. = FALSE)
  }
  if (exists("read_table") || exists("write_table")) {
    stop("The data layer is already loaded in this session, so this would not ",
         "be a record of 'before'. Take it on the engine as it was at v2.8.1.",
         call. = FALSE)
  }

  #### Product 2 must be current, or "after" would differ for other reasons ####
  cat("Checking Product 2 is current...\n")
  stale <- p2_stale()
  # Empty station-years show as "not built yet" on every run - there is
  # nothing to build. They have no file, so they have nothing to compare.
  empty <- stale[stale$reason == "not built yet", , drop = FALSE]
  stale <- stale[stale$reason != "not built yet", , drop = FALSE]
  if (nrow(stale) > 0) {
    print(stale, row.names = FALSE)
    stop("Product 2 is not current. Run build_p2_stale(), then this again.",
         call. = FALSE)
  }

  #### Metadata: a copy of every table ####
  meta_dir <- wds("meta_internal")
  tables <- list.files(meta_dir, pattern = "\\.csv$")
  copies <- lapply(tables, function(t) {
    p <- file.path(meta_dir, t)
    readBin(p, "raw", file.size(p))
  })
  names(copies) <- tables

  #### Product 2: a fingerprint of every file, with its manifest row ####
  m <- read_manifest(2)
  if (is.null(m) || nrow(m) == 0) stop("No Product 2 manifest to record.", call. = FALSE)
  cat("Fingerprinting ", nrow(m), " Product 2 files...\n", sep = "")
  m$content_md5 <- vapply(file.path(wds("products"), m$file), function(p) {
    if (file.exists(p)) layer_check_content_md5(p) else NA_character_
  }, character(1), USE.NAMES = FALSE)
  if (anyNA(m$content_md5)) {
    print(m$file[is.na(m$content_md5)])
    stop("The manifest names files that are not here. Resolve that first.",
         call. = FALSE)
  }

  record <- list(
    taken_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    machine   = unname(Sys.info()[["nodename"]]),
    engine    = engine_commit()$commit,
    tables    = copies,
    p2        = m
  )
  dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
  saveRDS(record, f)

  cat("\n✓ 'Before' recorded: ", length(copies), " metadata tables, ",
      nrow(m), " Product 2 files\n  ", f, "\n", sep = "")
  if (nrow(empty) > 0) {
    cat("  (", nrow(empty), " empty station-year(s) have no file and are not ",
        "recorded: ", paste(paste(empty$station_id, empty$year), collapse = ", "),
        ")\n", sep = "")
  }
  invisible(f)
}

#' What changed between two versions of one table, cell by cell
#'
#' Compared by meaning, each column read through its schema type: "NA" and an
#' empty cell are both missing, and "2026-03-02" and "3/2/2026" are the same
#' date. Compared as raw text, the layer's one-time normalization of a table's
#' formatting would show as hundreds of changed values that are not changes.
layer_check_table_diff <- function(old_raw, new_path) {
  name <- sub("\\.csv$", "", basename(new_path))
  read_chr <- function(con) read.csv(con, colClasses = "character",
                                     na.strings = c("", "NA"), check.names = FALSE)
  old <- read_chr(textConnection(rawToChar(old_raw)))
  new <- read_chr(new_path)
  out <- character(0)
  if (!identical(names(old), names(new))) {
    return(paste0("columns differ: was ", paste(names(old), collapse = ","),
                  " / now ", paste(names(new), collapse = ",")))
  }
  if (nrow(new) != nrow(old)) {
    out <- c(out, paste0(nrow(old), " rows before, ", nrow(new), " now"))
  }
  cols <- if (name %in% names(TABLE_SCHEMA)) TABLE_SCHEMA[[name]]$columns else NULL
  n <- min(nrow(old), nrow(new))
  if (n > 0) {
    for (col in names(old)) {
      a <- old[[col]][seq_len(n)]
      b <- new[[col]][seq_len(n)]
      if (!is.null(cols)) {
        a <- table_parse_column(a, cols[[col]], col, basename(new_path))
        b <- table_parse_column(b, cols[[col]], col, basename(new_path))
      }
      same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
      k <- sum(!same)
      if (k > 0) out <- c(out, paste0(k, " value(s) changed in `", col, "`"))
    }
  }
  if (length(out) == 0) out <- "same values, formatting normalized"
  out
}

#' Compares now against the "before" record. Changes nothing
layer_check_after <- function() {
  f <- LAYER_CHECK_FILE()
  if (!file.exists(f)) stop("No 'before' record. Nothing to compare with.", call. = FALSE)
  if (!exists("table_round_trip")) {
    stop("The data layer is not loaded - there is nothing to check yet.", call. = FALSE)
  }
  b <- readRDS(f)
  ok <- TRUE

  here <- unname(Sys.info()[["nodename"]])
  if (!identical(here, b$machine)) {
    cat("! The 'before' record was taken on ", b$machine, ", this is ", here,
        ".\n  Product 2 is compared as this machine built it.\n\n", sep = "")
  }
  cat("Comparing against 'before' taken ", b$taken_utc, " UTC, engine ", b$engine, "\n\n", sep = "")

  #### 1. Metadata tables against their copies ####
  cat("1. Metadata tables, against their copies\n")
  meta_dir <- wds("meta_internal")
  for (t in names(b$tables)) {
    p <- file.path(meta_dir, t)
    if (!file.exists(p)) { cat("   ✗ ", t, ": gone\n", sep = ""); ok <- FALSE; next }
    now <- readBin(p, "raw", file.size(p))
    if (identical(now, b$tables[[t]])) { cat("   ✓ ", t, ": identical\n", sep = ""); next }
    cat("   • ", t, ": differs - ", paste(layer_check_table_diff(b$tables[[t]], p),
                                         collapse = "; "), "\n", sep = "")
  }
  cat("   A difference here is not a failure by itself: a download since adds\n",
      "   rows. Check each one is something that really happened.\n\n", sep = "")

  #### 2. Each table read and written back through the layer ####
  cat("2. Each table read and written back through the layer\n")
  for (t in names(b$tables)) {
    name <- sub("\\.csv$", "", t)
    res <- tryCatch(table_round_trip(name), error = function(e) conditionMessage(e))
    if (is.character(res)) {
      cat("   ✗ ", t, ": ", res, "\n", sep = ""); ok <- FALSE
    } else if (!res$values_identical) {
      cat("   ✗ ", t, ": values changed\n", sep = "")
      for (d in res$differences) cat("       ", d, "\n", sep = "")
      ok <- FALSE
    } else if (res$bytes_identical) {
      cat("   ✓ ", t, ": byte-identical\n", sep = "")
    } else {
      # A table not yet written through the layer: its old formatting is
      # normalized on its first write. Every value is the same
      cat("   ✓ ", t, ": values identical, formatting not yet normalized\n", sep = "")
    }
  }
  cat("\n")

  #### 3. Product 2 ####
  cat("3. Product 2, file by file\n")
  old <- b$p2
  cur <- read_manifest(2)
  key_cols <- c("inputs", "metadata_fingerprint", "ports_fingerprint")
  same <- different <- inputs_changed <- not_rebuilt <- gone <- character(0)

  for (i in seq_len(nrow(old))) {
    o <- old[i, ]
    j <- match(o$file, cur$file)
    if (is.na(j)) { gone <- c(gone, o$file); next }
    n <- cur[j, ]
    if (any(vapply(key_cols, function(k) !identical(o[[k]], n[[k]]), logical(1)))) {
      inputs_changed <- c(inputs_changed, o$file); next
    }
    if (identical(o$engine, n$engine)) { not_rebuilt <- c(not_rebuilt, o$file); next }
    why <- character(0)
    if (!identical(o$content_md5,
                   layer_check_content_md5(file.path(wds("products"), n$file)))) {
      why <- c(why, "content")
    }
    for (k in intersect(LAYER_CHECK_MANIFEST_COLS, names(cur))) {
      if (!identical(as.character(o[[k]]), as.character(n[[k]]))) why <- c(why, k)
    }
    if (length(why) == 0) same <- c(same, o$file)
    else different <- c(different, paste0(o$file, " (", paste(why, collapse = ", "), ")"))
  }
  new_files <- setdiff(cur$file, old$file)

  cat("   ✓ ", length(same), " identical\n", sep = "")
  show <- function(label, x, bad) {
    if (length(x) == 0) return(invisible())
    cat("   ", if (bad) "✗ " else "• ", length(x), " ", label, "\n", sep = "")
    for (v in head(x, 20)) cat("       ", v, "\n", sep = "")
    if (length(x) > 20) cat("       ... and ", length(x) - 20, " more\n", sep = "")
  }
  show("DIFFERENT, with the same inputs - the layer changed something", different, TRUE)
  show("not rebuilt since 'before' - run build_p2_stale(), then this again", not_rebuilt, TRUE)
  show("gone from the manifest", gone, TRUE)
  show("with new inputs since 'before' - not compared, expected after a download",
       inputs_changed, FALSE)
  show("new since 'before'", new_files, FALSE)
  if (length(different) + length(not_rebuilt) + length(gone) > 0) ok <- FALSE

  cat("\n", if (ok) "✓ PASS - the layer changed nothing it should not have\n"
           else "✗ FAIL - see above\n", sep = "")
  invisible(ok)
}

#### Product 2 before and after one migration ####
#
# The layer check above compares only files whose inputs are unchanged. A
# migration that rewrites a table Product 2 reads - the port table, the device
# table - changes every fingerprint, so that check would compare nothing. These
# two compare content alone: a snapshot just before the migration, and a
# comparison once Product 2 has been rebuilt on it. Run both with no download
# in between, so that the only thing changed is the table.

p2_snapshot_file <- function(label) {
  file.path(wds("meta_internal"), "backups", paste0("p2_snapshot_", label, ".rds"))
}

#' Fingerprints every Product 2 file's content, before a migration
p2_snapshot <- function(label) {
  m <- read_manifest(2)
  m <- m[!is.na(m$file) & nzchar(m$file), , drop = FALSE]     # empty builds name no file
  cat("Fingerprinting ", nrow(m), " Product 2 files...\n", sep = "")
  m$content_md5 <- vapply(file.path(wds("products"), m$file), layer_check_content_md5,
                          character(1), USE.NAMES = FALSE)
  dir.create(dirname(p2_snapshot_file(label)), showWarnings = FALSE, recursive = TRUE)
  saveRDS(list(taken_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               p2 = m[, c("file", "content_md5", "rows", "observed", "missing", "engine")]),
          p2_snapshot_file(label))
  cat("✓ Snapshot '", label, "' taken: ", nrow(m), " files\n", sep = "")
  invisible(TRUE)
}

#' Compares Product 2 now with a snapshot, by content. Changes nothing
#'
#' @param label Character. The snapshot's label
#' @param expect Character. Files allowed to differ - a predicted change
p2_compare <- function(label, expect = character(0)) {
  b <- readRDS(p2_snapshot_file(label))$p2
  m <- read_manifest(2)
  m <- m[!is.na(m$file) & nzchar(m$file), , drop = FALSE]     # empty builds name no file
  gone <- setdiff(b$file, m$file)
  new_files <- setdiff(m$file, b$file)
  both <- intersect(b$file, m$file)
  rebuilt <- both[m$engine[match(both, m$file)] != b$engine[match(both, b$file)]]
  if (length(rebuilt) < length(both)) {
    cat("! ", length(both) - length(rebuilt), " file(s) not rebuilt since the snapshot - ",
        "run build_p2_stale() first\n", sep = "")
  }
  now <- vapply(file.path(wds("products"), both), layer_check_content_md5,
                character(1), USE.NAMES = FALSE)
  differ <- both[now != b$content_md5[match(both, b$file)]]
  bad <- setdiff(c(differ, gone, new_files), expect)
  cat("Product 2 against snapshot '", label, "':\n", sep = "")
  cat("  ✓ ", length(both) - length(differ), " identical\n", sep = "")
  for (x in list(list("differ", differ), list("gone", gone), list("new", new_files))) {
    if (length(x[[2]]) > 0) {
      cat("  • ", length(x[[2]]), " ", x[[1]], "\n", sep = "")
      for (f in head(x[[2]], 20)) cat("      ", f, if (f %in% expect) "  (expected)" else "", "\n", sep = "")
    }
  }
  cat(if (length(bad) == 0) "✓ PASS\n" else "✗ FAIL - an unexpected difference\n")
  invisible(length(bad) == 0)
}

cat("check_layer_v2.9.R loaded.\n",
    "  layer_check_before()  once, before the data layer's code is pulled\n",
    "  layer_check_after()   once the layer is in and Product 2 rebuilt\n",
    "  p2_snapshot(label)    just before a migration Product 2 reads\n",
    "  p2_compare(label)     after it, once Product 2 is rebuilt\n", sep = "")
