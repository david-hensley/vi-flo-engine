################################################################################
# product_view_functions.R - reading and looking at the products
#
# read_product() returns a station's variable across every year it was built,
# as one table. browse_product() steps through a product one station and
# variable at a time, each over its full span, to look for anything odd.
#
# Kept out of product2_functions.R on purpose: everything a Product 2 build
# reaches is fingerprinted, and a change there rebuilds every station-year.
# Nothing here is reached by a build.
################################################################################

# A deployment-keyed variable ends in its row id: abs_pressure_h-0021
DEPLOYMENT_SUFFIX <- "_[a-z]-[0-9]+$"

#' The variable a product file holds, without its deployment
#'
#' @param variable Character. "abs_pressure_h-0021", "vwc_30cm", "temp"
#' @return Character. "abs_pressure", "vwc_30cm", "temp"
base_variable <- function(variable) sub(DEPLOYMENT_SUFFIX, "", variable)

#' The station, variable and year of each product file, from its path
#'
#' @param files Character paths, as list_product_files() returns them
#' @return Data frame: file, station, variable, base, year
product_index <- function(files) {
  if (length(files) == 0) {
    return(data.frame(file = character(0), station = character(0), variable = character(0),
                      base = character(0), year = integer(0), stringsAsFactors = FALSE))
  }
  parts <- strsplit(files, "/", fixed = TRUE)
  n <- lengths(parts)
  variable <- mapply(function(p, k) p[k - 1], parts, n, USE.NAMES = FALSE)
  data.frame(file = files,
             station = mapply(function(p, k) p[k - 2], parts, n, USE.NAMES = FALSE),
             variable = variable,
             base = base_variable(variable),
             year = as.integer(sub("^.*_([0-9]{4})\\.csv\\.gz$", "\\1", files)),
             stringsAsFactors = FALSE)
}

#' One station's variable, every year joined, as one table
#'
#' At a hydro or pond station each deployment is its own series. Asked for
#' "abs_pressure", every deployment's comes back together, each row naming
#' its series and the device that read it - nobody need know a row id.
#'
#' @param station Character. A station id
#' @param variable Character. A variable as filed ("vwc_30cm",
#'   "abs_pressure_h-0021") or without its deployment ("abs_pressure")
#' @param from,to Optional. Dates or datetimes bounding the period, in the
#'   project's time zone; either may be left out
#' @param product Integer. 2 or above
#' @return Data frame: datetime, value, flag, device_serial, source_file,
#'   conflict, series, device_name - sorted by series then time. Its "unit"
#'   attribute holds the unit, where the manifest records it
read_product <- function(station, variable, from = NULL, to = NULL, product = 2) {
  idx <- product_index(list_product_files(product, station = station))
  if (nrow(idx) == 0) {
    have <- unique(product_index(list_product_files(product))$station)
    stop("No Product ", product, " files for '", station, "'.",
         if (length(have) > 0) paste0("\nStations with files: ", paste(sort(have), collapse = ", ")),
         call. = FALSE)
  }
  pick <- idx[idx$variable == variable | idx$base == variable, , drop = FALSE]
  if (nrow(pick) == 0) {
    stop("'", station, "' has no Product ", product, " variable '", variable, "'.\n",
         "It has: ", paste(sort(unique(idx$base)), collapse = ", "), call. = FALSE)
  }
  pick <- pick[order(pick$variable, pick$year), , drop = FALSE]

  as_time <- function(x, end = FALSE) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "POSIXct")) return(x)
    s <- as.character(x)
    if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", s)) {
      s <- paste(s, if (end) "23:59:59" else "00:00:00")
    }
    as.POSIXct(s, tz = PROJECT_TZ)
  }
  t0 <- as_time(from)
  t1 <- as_time(to, end = TRUE)
  if (!is.null(t0)) pick <- pick[pick$year >= as.integer(format(t0, "%Y", tz = PROJECT_TZ)), , drop = FALSE]
  if (!is.null(t1)) pick <- pick[pick$year <= as.integer(format(t1, "%Y", tz = PROJECT_TZ)), , drop = FALSE]

  out <- do.call(rbind, lapply(seq_len(nrow(pick)), function(i) {
    x <- read_p2_file(pick$file[i])
    x$series <- rep(pick$variable[i], nrow(x))
    x
  }))
  if (is.null(out)) out <- read_p2_file(idx$file[1])[0, ]
  if (!is.null(t0)) out <- out[out$datetime >= t0, , drop = FALSE]
  if (!is.null(t1)) out <- out[out$datetime <= t1, , drop = FALSE]

  # Each series by its device's name: a deployment-keyed series is one row of
  # the metadata; a station-keyed one is named by whichever devices read it
  # Named once per device, not once per row: a station's few years are
  # hundreds of thousands of rows, and naming each was most of the wait
  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)
  serials <- unique(out$device_serial[!is.na(out$device_serial)])
  names_of <- if (is.null(meta) || length(serials) == 0) setNames(serials, serials) else
    setNames(device_display_name(serials, meta, station = station), serials)
  out$device_name <- unname(names_of[out$device_serial])
  rownames(out) <- NULL

  mf <- tryCatch(read_manifest(product), error = function(e) NULL)
  if (!is.null(mf) && all(c("station_id", "variable", "unit") %in% names(mf))) {
    u <- unique(mf$unit[mf$station_id == station & mf$variable %in% pick$variable &
                          !is.na(mf$unit) & nzchar(mf$unit)])
    if (length(u) > 0) attr(out, "unit") <- u[1]
  }
  out
}

#' Steps through a product, one station and variable at a time
#'
#' Each plot is a variable over its full span: gaps as breaks in the line,
#' never joined across; every deployment start - a new logger, a swap, a move
#' - as a dashed line labeled with its device; disagreements between
#' downloads marked in red. A paired gauge's loggers share one plot, in two
#' colors: they should track each other, and where they part is the kind of
#' thing this is for.
#'
#' Each plot shows every value, the extremes included - they are real
#' Product 2 data, for Product 3 to deal with. One wild value can flatten the
#' rest into a line, so z switches to the bulk of the data: the middle 99.8%,
#' with anything beyond drawn as a triangle at the edge and counted in the
#' title. z again switches back; the choice holds for the plots that follow.
#'
#' Enter for the next, b for back, n for the next station, z to switch the
#' scale, q to stop. Or write the lot to one PDF to page through later.
#'
#' @param station Character vector, or NULL for every station with files
#' @param product Integer. 2 or above
#' @param pdf Character. A file to write every plot to, instead of showing
#'   them one at a time
#' @param scale "full" for every value, or "bulk" for the middle 99.8%
#' @return Invisibly, the number of plots shown or written
browse_product <- function(station = NULL, product = 2, pdf = NULL,
                           scale = c("full", "bulk")) {
  scale <- match.arg(scale)
  idx <- product_index(list_product_files(product, station = station))
  if (nrow(idx) == 0) {
    cat("No Product ", product, " files", if (!is.null(station)) paste0(" for ", paste(station, collapse = ", ")),
        "\n", sep = "")
    return(invisible(0))
  }

  # Stations in the menus' order - by watershed - and variables in the
  # registry's, depths in order of depth
  st_order <- tryCatch(vapply(get_station_list(include_retired = TRUE), `[[`, character(1), "station_id"),
                       error = function(e) character(0))
  stations <- unique(idx$station)
  stations <- c(intersect(st_order, stations), sort(setdiff(stations, st_order)))
  reg <- tryCatch(unique(load_variable_registry()$variable), error = function(e) character(0))
  var_rank <- function(v) {
    root <- sub("_[0-9]+cm$", "", v)
    depth <- suppressWarnings(as.numeric(sub("^.*_([0-9]+)cm$", "\\1", v)))
    r <- match(root, reg)
    order(ifelse(is.na(r), length(reg) + 1, r), root, ifelse(is.na(depth), 0, depth))
  }
  plots <- do.call(rbind, lapply(stations, function(s) {
    b <- unique(idx$base[idx$station == s])
    data.frame(station = s, base = b[var_rank(b)], stringsAsFactors = FALSE)
  }))

  windows <- tryCatch(deployment_windows(), error = function(e) NULL)
  meta <- tryCatch(load_zentra_metadata(), error = function(e) NULL)

  # The last one read is kept, so switching the scale redraws at once
  cached <- list(k = 0, x = NULL)
  draw <- function(k) {
    p <- plots[k, ]
    if (cached$k != k) cached <<- list(k = k, x = read_product(p$station, p$base, product = product))
    x <- cached$x
    draw_product_plot(x, p$station, p$base, attr(x, "unit"), windows, meta,
                      position = paste0(k, " of ", nrow(plots)), scale = scale)
  }

  if (!is.null(pdf)) {
    grDevices::pdf(pdf, width = 11, height = 6)
    on.exit(grDevices::dev.off(), add = TRUE)
    for (k in seq_len(nrow(plots))) draw(k)
    cat("✓ ", nrow(plots), " plot(s) written to ", pdf, "\n", sep = "")
    return(invisible(nrow(plots)))
  }

  k <- 1
  shown <- 0
  repeat {
    draw(k)
    shown <- shown + 1
    cat(plots$station[k], " - ", plots$base[k], "   (", k, " of ", nrow(plots), ")",
        if (scale == "bulk") "   bulk of the data" else "", "\n", sep = "")
    cat("[Enter] next   b back   n next station   z ",
        if (scale == "full") "bulk of the data" else "every value", "   q quit: ", sep = "")
    a <- tolower(trimws(readline()))
    if (a == "q") break
    if (a == "z") { scale <- if (scale == "full") "bulk" else "full"; next }
    if (a == "b") { k <- max(1, k - 1); next }
    if (a == "n") {
      later <- which(plots$station != plots$station[k] & seq_len(nrow(plots)) > k)
      if (length(later) == 0) break
      k <- later[1]
      next
    }
    if (k == nrow(plots)) break
    k <- k + 1
  }
  invisible(shown)
}

#' One product plot - see browse_product()
#'
#' @param x Data frame from read_product()
#' @param station,variable,unit Character
#' @param windows Data frame from deployment_windows(), or NULL
#' @param meta Data frame, the device metadata, or NULL
#' @param position Character, e.g. "12 of 214", or NULL
#' @param scale "full" for every value, "bulk" for the middle 99.8%
#' @return Invisibly, the number of values drawn off scale
draw_product_plot <- function(x, station, variable, unit, windows = NULL, meta = NULL,
                              position = NULL, scale = "full") {
  series <- unique(x$series)
  cols <- c("black", "#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#8c564b")
  has <- !is.na(x$value)

  span <- range(x$datetime, na.rm = TRUE)
  yr <- if (any(has)) range(x$value[has]) else c(0, 1)
  off <- rep(FALSE, nrow(x))
  if (scale == "bulk" && sum(has) > 10) {
    q <- stats::quantile(x$value[has], c(0.001, 0.999), names = FALSE)
    pad <- 0.05 * max(diff(q), .Machine$double.eps)
    yr <- c(q[1] - pad, q[2] + pad)
    off <- has & (x$value < yr[1] | x$value > yr[2])
  }
  if (diff(yr) == 0) yr <- yr + c(-1, 1)

  missing_pct <- if (nrow(x) > 0) round(100 * mean(x$flag == "missing"), 1) else 0
  n_conflict <- sum(x$conflict %in% TRUE)
  title <- paste0(station, "  -  ", variable, if (!is.null(unit)) paste0(" (", unit, ")"))
  sub <- paste0(format(span[1], "%Y-%m-%d", tz = PROJECT_TZ), " to ",
                format(span[2], "%Y-%m-%d", tz = PROJECT_TZ), "   ",
                missing_pct, "% missing   ", n_conflict, " conflict", if (n_conflict != 1) "s",
                if (scale == "bulk") paste0("   ", sum(off), " value", if (sum(off) != 1) "s",
                                            " off scale") else "",
                if (!is.null(position)) paste0("   [", position, "]"))

  op <- graphics::par(mar = c(3, 4, 4, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(span, yr, type = "n", xlab = "", ylab = if (is.null(unit)) variable else unit,
                 main = title, xaxt = "n", ylim = yr, yaxs = if (scale == "bulk") "i" else "r")
  graphics::mtext(sub, side = 3, line = 0.3, cex = 0.8)
  graphics::axis.POSIXct(1, at = pretty(span, 8), format = if (diff(as.numeric(span)) > 400 * 86400) "%Y-%m" else "%Y-%m-%d")

  # Where a deployment began: a new logger, a swap, a move
  if (!is.null(windows) && nrow(windows) > 0) {
    w <- windows[windows$station_id == station & windows$starts >= span[1] &
                   windows$starts <= span[2], , drop = FALSE]
    # Loggers that went in on the same day share one line and one label -
    # a pair installed together printed its names on top of each other
    if (nrow(w) > 0) {
      lab_of <- function(sn) if (is.null(meta)) sn else device_label(sn, meta = meta, station = station)
      day <- format(w$starts, "%Y-%m-%d", tz = PROJECT_TZ)
      for (d in unique(day)) {
        at <- min(w$starts[day == d])
        lab <- paste(unique(vapply(w$device_serial[day == d], lab_of, character(1))), collapse = " / ")
        graphics::abline(v = at, lty = 2, col = "grey55")
        graphics::text(at, yr[2], lab, srt = 90, adj = c(1, -0.4), cex = 0.65, col = "grey35")
      }
    }
  }

  # NA breaks the line, so a gap is drawn as a gap
  # Slightly see-through, so a series under another still shows
  for (j in seq_along(series)) {
    s <- x[x$series == series[j], , drop = FALSE]
    s <- s[order(s$datetime), , drop = FALSE]
    v <- s$value
    if (scale == "bulk") v[!is.na(v) & (v < yr[1] | v > yr[2])] <- NA
    graphics::lines(s$datetime, v, col = grDevices::adjustcolor(cols[(j - 1) %% length(cols) + 1], 0.65),
                    lwd = 0.7)
  }
  # Off scale: a triangle at the edge it went past, pointing the way
  if (any(off)) {
    hi <- off & x$value > yr[2]
    lo <- off & x$value < yr[1]
    if (any(hi)) graphics::points(x$datetime[hi], rep(yr[2], sum(hi)), pch = 24, bg = "orange", col = "orange3", cex = 0.8)
    if (any(lo)) graphics::points(x$datetime[lo], rep(yr[1], sum(lo)), pch = 25, bg = "orange", col = "orange3", cex = 0.8)
  }
  bad <- x$conflict %in% TRUE & has & !off
  if (any(bad)) graphics::points(x$datetime[bad], x$value[bad], col = "red", pch = 4, cex = 0.8)

  if (length(series) > 1) {
    who <- vapply(series, function(s) {
      d <- unique(x$device_name[x$series == s & !is.na(x$device_name)])
      if (length(d) == 0) s else paste(d, collapse = " / ")
    }, character(1))
    graphics::legend("topleft", legend = who, col = cols[(seq_along(series) - 1) %% length(cols) + 1],
                     lwd = 2, bty = "n", cex = 0.75)
  }
  invisible(sum(off))
}
