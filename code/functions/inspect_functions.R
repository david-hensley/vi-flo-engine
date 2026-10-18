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
#' Always drawn to an image sized for its panels and then opened, rather than
#' into RStudio's plot pane: eight stacked panels do not fit a pane of
#' ordinary size, and R refuses ("figure margins too large") rather than
#' shrinking them.
#'
#' @param variables Character, or NULL for every kept variable
#' @param file Character. A .png path to keep the picture at, or NULL for a
#'   temporary one
#' @param max_panels Integer
#' @param open Logical. Open the picture once drawn
#' @return Invisibly, the readings plotted, with the picture's path as the
#'   attribute "file"
view_device <- function(device_serial, from = NULL, to = NULL, variables = NULL,
                        file = NULL, max_panels = 8, open = interactive()) {
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

  if (is.null(file)) file <- tempfile(paste0(device_serial, "_"), fileext = ".png")
  grDevices::png(file, width = 1600, height = 260 * length(panels) + 120, res = 110)
  dev_id <- grDevices::dev.cur()
  # Closed below; this only guards against an error part way through drawing
  on.exit(if (dev_id %in% grDevices::dev.list()) grDevices::dev.off(dev_id), add = TRUE)
  graphics::par(mfrow = c(length(panels), 1), mar = c(2, 4.5, 1.6, 1),
                oma = c(1, 0, 3, 0))

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
  grDevices::dev.off(dev_id)

  if (open) utils::browseURL(file)
  attr(r, "file") <- file
  invisible(r)
}


################################################################################
#                       UNATTRIBUTED READINGS, EXPLAINED                       #
#                                                                              #
# Every build lists the readings that belong to no station. Most are known:    #
# a logger in an earlier experiment, one sitting in a shed, a launch at the    #
# desk. Listing those in full every time teaches a reader to stop reading, so  #
# the summary sorts them three ways and prints all three - nothing hidden,     #
# but only what is new set out for attention:                                  #
#                                                                              #
#   UNEXPLAINED          everything else - look at these                       #
#   KNOWN                a period in metadata/internal/known_unattributed.csv  #
#   AROUND INSTALLATIONS up to 7 days before a deployment starts - a desk      #
#                        launch, a test - or in its first 24 hours, before     #
#                        its sensors' port windows open                        #
#                                                                              #
# Within each, the last 12 months come first, then older, newest first.        #
################################################################################

INSTALL_BEFORE <- 7 * 86400    # seconds before a deployment starts
INSTALL_AFTER  <- 24 * 3600    # seconds after it starts: a deployment's first day

#' Loads known_unattributed.csv - an absent file means none are known
#'
#' One row per explained period: device_serial, device_name (for the reader;
#' not matched on), port (blank for the whole logger), from and to
#' (project-local; blank for open-ended), reason.
#'
#' @return Data frame, datetimes as POSIXct
load_known_unattributed <- function() {
  path <- file.path(wds("meta_internal"), "known_unattributed.csv")
  tz <- "America/Puerto_Rico"
  empty <- data.frame(device_serial = character(0), device_name = character(0),
                      port = integer(0), from = as.POSIXct(character(0), tz = tz),
                      to = as.POSIXct(character(0), tz = tz), reason = character(0),
                      stringsAsFactors = FALSE)
  if (!file.exists(path)) return(empty)
  k <- read.csv(path, stringsAsFactors = FALSE, colClasses = "character", na.strings = c("", "NA"))
  if (nrow(k) == 0) return(empty)
  k$port <- suppressWarnings(as.integer(k$port))
  k$from <- parse_datetime_flexible(k$from, tz)
  k$to   <- parse_datetime_flexible(k$to, tz)
  k
}

#' Sorts unattributed readings into unexplained, known and around installations
#'
#' @param u Data frame: device_serial, port, variable, datetime
#' @param windows Data frame from deployment_windows()
#' @param known Data frame from load_known_unattributed()
#' @return u, plus category ("unexplained", "known", "installation") and
#'   episode - the known row, or the deployment start, the reading belongs to
classify_unattributed <- function(u, windows, known) {
  u$category <- "unexplained"
  u$episode  <- NA_character_
  t <- as.numeric(u$datetime)

  #### Known periods ####
  for (i in seq_len(nrow(known))) {
    k <- known[i, ]
    hit <- u$category == "unexplained" & u$device_serial == k$device_serial &
      (is.na(k$port) | (!is.na(u$port) & u$port == k$port)) &
      (is.na(k$from) | t >= as.numeric(k$from)) &
      (is.na(k$to)   | t <  as.numeric(k$to))
    u$category[hit] <- "known"
    u$episode[hit]  <- paste0("known:", i)
  }

  #### Around installations ####
  for (dev in unique(u$device_serial[u$category == "unexplained"])) {
    starts <- sort(unique(as.numeric(windows$starts[windows$device_serial == dev])))
    for (s in starts) {
      hit <- u$category == "unexplained" & u$device_serial == dev &
        t >= s - INSTALL_BEFORE & t <= s + INSTALL_AFTER
      u$category[hit] <- "installation"
      u$episode[hit]  <- paste0("install:", dev, ":", s)
    }
  }

  #### Unexplained: per logger, runs split where a week passes with nothing ####
  # A logger's ports nearly always go together - one story, one episode - and
  # a logger in storage may report only a few times a week
  for (dev in unique(u$device_serial[u$category == "unexplained"])) {
    rows <- which(u$category == "unexplained" & u$device_serial == dev)
    rows <- rows[order(t[rows])]
    run <- cumsum(c(TRUE, diff(t[rows]) > EPISODE_GAP))
    u$episode[rows] <- paste0("open:", dev, ":", run)
  }
  u
}

EPISODE_GAP <- 7 * 86400       # seconds of silence that end an unexplained episode

#' Ports as a compact list: 1, 2, 3, 4, 6, 8 -> "1-4, 6, 8"
compact_ports <- function(p) {
  p <- sort(unique(p[!is.na(p)]))
  if (length(p) == 0) return("")
  runs <- split(p, cumsum(c(1, diff(p) != 1)))
  paste(vapply(runs, function(r) if (length(r) == 1) as.character(r)
                                 else paste0(r[1], "-", r[length(r)]), character(1)),
        collapse = ", ")
}

#' Unattributed readings as episodes: one line per logger, port and episode
#'
#' @param u Data frame from classify_unattributed()
#' @return Data frame: category, device_serial, ports (compact), episode,
#'   first, last, moments (distinct times), variables
unattributed_episodes <- function(u) {
  if (nrow(u) == 0) return(NULL)
  key <- paste(u$category, u$device_serial, u$episode, sep = "|")
  k <- unique(key)
  i <- match(k, key)
  t <- as.numeric(u$datetime)
  f <- factor(key, levels = k)
  ep <- data.frame(
    category      = u$category[i],
    device_serial = u$device_serial[i],
    ports         = as.character(tapply(u$port, f, compact_ports)),
    episode       = u$episode[i],
    first   = as.POSIXct(as.numeric(tapply(t, f, min)), origin = "1970-01-01", tz = "UTC"),
    last    = as.POSIXct(as.numeric(tapply(t, f, max)), origin = "1970-01-01", tz = "UTC"),
    moments = as.integer(tapply(t, f, function(x) length(unique(x)))),
    variables = as.character(tapply(u$variable, f, function(v) paste(sort(unique(v)), collapse = ", "))),
    stringsAsFactors = FALSE)
  ep[order(-as.numeric(ep$last)), , drop = FALSE]
}

#' A logger's most recent name
device_short_name <- function(device_serial, metadata) {
  vapply(device_serial, function(sn) {
    m <- metadata[metadata$device_serial == sn, , drop = FALSE]
    if (nrow(m) == 0) return(sn)
    m <- m[order(m$deploy_datetime, decreasing = TRUE), , drop = FALSE]
    if (is.na(m$device_name[1])) sn else m$device_name[1]
  }, character(1), USE.NAMES = FALSE)
}

#' Prints the build summary's unattributed section
#'
#' @param ep Data frame from unattributed_episodes()
#' @param metadata Data frame
#' @param known Data frame from load_known_unattributed()
#' @param now POSIXct. "The last 12 months" is counted back from here
print_unattributed <- function(ep, metadata, known, now = Sys.time()) {
  if (is.null(ep) || nrow(ep) == 0) return(invisible(NULL))
  tz <- "America/Puerto_Rico"
  d <- function(x) format(x, "%Y-%m-%d", tz = tz)
  recent <- as.numeric(ep$last) >= as.numeric(now) - 365 * 86400
  who <- function(i) paste0(device_short_name(ep$device_serial[i], metadata),
                            " (", ep$device_serial[i], ")")
  port_of <- function(i) {
    p <- ep$ports[i]
    if (is.na(p) || !nzchar(p)) "" else paste0(if (grepl("[-,]", p)) "ports " else "port ", p)
  }

  cat("\nUnattributed - read from these stations' loggers, belonging to no station.\n")
  cat("view_device(serial, from, to) draws any of them against its deployments.\n")

  periods <- function(sel, line) {
    for (when in c("last 12 months", "older")) {
      rows <- which(sel & if (when == "last 12 months") recent else !recent)
      if (length(rows) == 0) next
      cat("    ", when, "\n", sep = "")
      for (i in rows) line(i)
    }
  }

  #### Unexplained ####
  sel <- ep$category == "unexplained"
  cat("\n  UNEXPLAINED - look at these\n")
  if (!any(sel)) cat("    none\n")
  periods(sel, function(i) {
    cat(sprintf("      %-30s %-13s %s to %s  %8s moments  %s\n", who(i), port_of(i),
                d(ep$first[i]), d(ep$last[i]), format(ep$moments[i], big.mark = ","),
                ep$variables[i]))
  })

  #### Known ####
  sel <- ep$category == "known"
  if (any(sel)) {
    cat("\n  KNOWN - metadata/internal/known_unattributed.csv\n")
    periods(sel, function(i) {
      k <- known[as.integer(sub("^known:", "", ep$episode[i])), ]
      cat(sprintf("      %-30s %-13s %s to %s  %8s moments  %s\n", who(i), port_of(i),
                  d(ep$first[i]), d(ep$last[i]), format(ep$moments[i], big.mark = ","),
                  k$reason))
    })
  }

  #### Around installations: one line per period ####
  sel <- ep$category == "installation"
  if (any(sel)) {
    cat("\n  AROUND INSTALLATIONS - up to 7 days before a deployment, or its first 24 hours\n")
    for (when in c("last 12 months", "older")) {
      rows <- which(sel & if (when == "last 12 months") recent else !recent)
      if (length(rows) == 0) next
      names <- unique(vapply(rows, function(i) paste0(device_short_name(ep$device_serial[i], metadata),
                                                      " ", format(ep$last[i], "%b %Y", tz = tz)),
                             character(1)))
      cat(sprintf("    %-15s %s moments around %d installation(s): %s\n", when,
                  format(sum(ep$moments[rows]), big.mark = ","), length(unique(ep$episode[rows])),
                  paste(names, collapse = ", ")))
    }
  }
  invisible(NULL)
}
