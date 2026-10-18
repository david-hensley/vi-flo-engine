################################################################################
#                           LOOKING AT A LOGGER                                #
#                                                                              #
# A serial number says nothing on sight, and a count of unattributed readings  #
# says nothing about WHY. These put a name to a logger, and draw what it       #
# recorded against where metadata says it was - so "in storage" or "deployed   #
# somewhere metadata does not know" is something you can see.                  #
################################################################################


#' The names a logger has gone by, and where
#'
#' @param device_serial Character, one or more
#' @param metadata Data frame, or NULL to load
#' @return Character, one per serial: "FishBay1 at fb2_hydro; FishBay_slope at
#'   fb2_hydro", or "(not in metadata)"
device_names_for <- function(device_serial, metadata = NULL) {
  if (is.null(metadata)) metadata <- load_zentra_metadata()
  vapply(device_serial, function(sn) {
    m <- metadata[metadata$device_serial == sn, , drop = FALSE]
    if (nrow(m) == 0) return("(not in metadata)")
    m <- m[order(m$deploy_datetime), , drop = FALSE]
    parts <- unique(paste0(ifelse(is.na(m$device_name), "(no name)", m$device_name),
                           " at ", m$station_id))
    paste(parts, collapse = "; ")
  }, character(1), USE.NAMES = FALSE)
}

#' Plots what a logger recorded, against where metadata says it was
#'
#' One panel per variable and port, from Product 1 - every reading, whether or
#' not it belongs to a station. Deployment starts are drawn as solid lines and
#' ends as dashed ones, each labeled with its station; a ZL6's port windows as
#' dotted lines in the panels they apply to. Readings outside every line are
#' the unattributed ones.
#'
#' @param device_serial Character
#' @param from,to Dates or "YYYY-MM-DD", project-local, or NULL for everything
#' @param variables Character, or NULL for every kept variable
#' @param file Character. A .png path to write to, or NULL to draw on screen
#' @param max_panels Integer
#' @return Invisibly, the readings plotted
view_device <- function(device_serial, from = NULL, to = NULL, variables = NULL,
                        file = NULL, max_panels = 8) {
  tz <- "America/Puerto_Rico"
  metadata <- load_zentra_metadata()
  windows  <- deployment_windows(metadata)
  pwindows <- port_windows()

  logged <- basename(load_download_log()$filepath)
  files <- c(list.files(wds("device_zentra"), "_raw\\.rds$", full.names = TRUE),
             list.files(wds("device_hobo"),   "_raw\\.rds$", full.names = TRUE))
  files <- files[startsWith(basename(files), paste0(device_serial, "_")) &
                   basename(files) %in% logged]
  if (length(files) == 0) stop("No logged Product 1 files for ", device_serial, call. = FALSE)

  r <- do.call(rbind, lapply(files, function(f) map_measurements(read_p1_long(f))))
  r <- r[!duplicated(r[, c("port", "measurement", "datetime")]), , drop = FALSE]
  # Project-local throughout: compared with local dates, drawn on a local axis
  attr(r$datetime, "tzone") <- tz
  if (!is.null(from)) r <- r[r$datetime >= as.POSIXct(as.character(from), tz = tz), , drop = FALSE]
  if (!is.null(to))   r <- r[r$datetime <  as.POSIXct(as.character(to), tz = tz) + 86400, , drop = FALSE]
  if (!is.null(variables)) r <- r[r$variable %in% variables, , drop = FALSE]
  if (nrow(r) == 0) stop("No readings for ", device_serial, " in that period", call. = FALSE)

  r$panel <- ifelse(is.na(r$port), r$variable, paste0(r$variable, "  port ", r$port))
  panels <- sort(unique(r$panel))
  if (length(panels) > max_panels) {
    message(length(panels), " panels - showing the first ", max_panels,
            "; narrow with `variables`")
    panels <- panels[seq_len(max_panels)]
  }

  w <- windows[windows$device_serial == device_serial, , drop = FALSE]
  pw <- pwindows[pwindows$device_serial == device_serial, , drop = FALSE]
  # The period asked for, so a deployment line inside it always shows
  xlim <- range(r$datetime)
  if (!is.null(from)) xlim[1] <- as.POSIXct(as.character(from), tz = tz)
  if (!is.null(to))   xlim[2] <- as.POSIXct(as.character(to), tz = tz) + 86400

  if (!is.null(file)) {
    grDevices::png(file, width = 1600, height = 260 * length(panels) + 80, res = 110)
    on.exit(grDevices::dev.off(), add = TRUE)
  }
  old <- graphics::par(mfrow = c(length(panels), 1), mar = c(2, 4.5, 1.6, 1),
                       oma = c(1, 0, 3, 0))
  on.exit(graphics::par(old), add = TRUE)

  for (p in panels) {
    x <- r[r$panel == p, , drop = FALSE]
    x <- x[order(x$datetime), ]
    if (all(is.na(x$value))) {
      # Recorded, but nothing usable - an error-coded sensor, say
      plot(xlim, c(0, 1), type = "n", xlab = "", ylab = "", yaxt = "n",
           main = p, cex.main = 0.95, font.main = 1)
      graphics::text(mean(xlim), 0.5, "readings recorded, no usable values", col = "grey40")
    } else {
      plot(x$datetime, x$value, type = "l", xlim = xlim, xlab = "", ylab = "",
           main = p, cex.main = 0.95, font.main = 1, col = "grey25", lwd = 0.6)
    }
    for (i in seq_len(nrow(w))) {
      graphics::abline(v = w$starts[i], col = "darkgreen", lwd = 1.5)
      if (!is.na(w$ends[i])) graphics::abline(v = w$ends[i], col = "firebrick", lwd = 1.5, lty = 2)
      graphics::text(w$starts[i], graphics::par("usr")[4], w$station_id[i],
                     adj = c(-0.05, 1.4), cex = 0.65, col = "darkgreen")
    }
    port_no <- suppressWarnings(as.integer(sub(".*port ", "", p)))
    if (!is.na(port_no)) {
      q <- pw[pw$port == port_no, , drop = FALSE]
      for (i in seq_len(nrow(q))) {
        graphics::abline(v = q$starts[i], col = "steelblue", lty = 3)
        if (!is.na(q$ends[i])) graphics::abline(v = q$ends[i], col = "steelblue", lty = 3)
      }
    }
  }
  graphics::mtext(paste0(device_serial, "  -  ", device_names_for(device_serial, metadata)),
                  outer = TRUE, line = 1.2, cex = 0.9)
  graphics::mtext("solid green: deployment starts   dashed red: ends   dotted blue: port windows",
                  outer = TRUE, line = 0.1, cex = 0.65, col = "grey40")
  invisible(r)
}
