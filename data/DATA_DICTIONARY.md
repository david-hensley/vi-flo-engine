# Data Dictionary

Explanation of data files and formats

---

## Rules

Every table below follows the same six rules. They are what keep the
metadata from drifting, so a change that would break one is a change to
discuss before making.

1. **Identity.** A row about a deployment carries its `unique_id`. A serial
   number appears only where a row is about a physical logger's own record -
   `download_log.csv`, `known_unattributed.csv` - since a logger's record can
   span several deployments, and deciding which deployment owns which reading
   is Product 2's job.
2. **Store observations and decisions; compute everything else.** A value that
   can be worked out from another table is worked out when it is needed, never
   kept as a copy. A copy can only drift. See *Computed, not stored* below.
3. **One kind of writer per table.** Each table is written either by a person,
   through the metadata manager, or by the machine - never both.
4. **Times.** When something was *written* is UTC, and the column says so:
   `_utc`. When something happened *in the field* - a reading, a deployment, a
   visit - is project-local. See *Which times are local, and which are UTC*.
5. **Fixed vocabularies are defined once,** in code, and every workflow and
   check reads that one definition: statuses, maintenance actions, survey
   quantities, port statuses.
6. **Unknown is blank, never a placeholder.** A plausible invented value looks
   authoritative and will never be questioned. The one documented exception is
   the fetch stamp on the full-history export rows of `download_log.csv`.

---

## Metadata

Generally stored in a top-level directory alongside raw and processed databases.

### `device_metadata.csv`

One row per deployment: a device, at a station, for a span of time. Written
only by a person, through the metadata manager. This is the network's master
sheet - everything decided about what is deployed where, since when, and in
what state.

* `unique_id`: Identifies unique combination of device, station deployment, and location

  * Initial letter 'z' for Zentra data loggers, 'h' for Hobo data loggers
* `watershed`: Name of broad watershed area, usually literal. Named after the largest DOWNSTREAM gut or the bay it reaches (e.g. Caledonia, Salt River, Dorothea) - so that a watershed is identified by where its water goes rather than by whichever tributary was instrumented first. The main stem carries the watershed's name all the way to its headwaters, even where it goes by other names locally. Bethlehem is the one exception. Other names for each watershed and its parts, and the reasons for each choice, are in `docs/PLACE_NAMES.md`
* `area`: Sub-watershed area name if applicable. Often a tributary basin name - e.g. Adventure, the western branch of the Bethlehem watershed, which USGS and DPNR call River Gut. VI-FLO's area names do not always match other sources; see `docs/PLACE_NAMES.md`. At UVI, which is a campus rather than a watershed, an area is a project on the campus, e.g. Breadfruit.
* `site_full`: Full English name of the site including numeric. Lower numbers indicate a higher topographic position in the watershed.

  * If new sites are established between two integers, decimals must be used e.g. Salt River 0.5
  * Sites are theoretically unified areas of several station deployments e.g. stream gauge, weather station, soil moisture
  * A number is required. Some sites may be established in a downstream area with the possibility of upstream sites in the future, in such cases a Site Name 2 with no Site Name 1 may exist.
  * A site established alone, with no others in its watershed yet, takes 1 if it sits in an upland area and 2 if lowland - leaving room on whichever side the network is likely to grow
* `site`: Standard abbreviation of full site name.

  * This is two or three letters for the watershed plus one letter for area if necessary.
  * Three letters maximum, followed by numbers e.g. sr1, sr0.5, dor1.
  * Three letters must not be used for watershed abbreviation unless it is certain no "area" will exist for that watershed e.g. Dorothea -> dor. (Would apply mainly to small watersheds)
* `station_type`: Type of information collected by a station, weather, vwc (soil moisture), hydro (stream gauge), pond (pond gauge), etc.
* `station_id`: Concatenates site name and station type for a unique ID for a station
* `device_serial`: Manufacturer's serial number for the device. One logger can appear on several rows - one per deployment it has served, and on a shared ZL6, one per station it serves at the same time. A serial therefore never identifies a row on its own; `unique_id` does
* `device_role`: `primary`, `secondary` or `tertiary`, for paired water level loggers at a hydro station. The primary is the ANCHOR: the logger whose elevation is sourced externally and against which every other logger at the station is surveyed, where flow is gauged, and the position kept long-term even through replacements. Normally that is the downstream logger, but role is not position and nothing requires it - upstream and downstream come from the surveys, and slope does not depend on which end is primary. A role changes only when the anchor deliberately moves.
* `device_name`: The name written into the device itself - on a HOBO when it is launched, on a ZL6 in ZentraCloud. It changes from time to time, so each row records the name the logger carried during that deployment. It is how a person keeps track of a logger, and how loggers are referred to in reports
* `mfger`: Manufacturer of device e.g. Meter, HOBO, etc. Onset loggers are recorded as `HOBO` - that is what they are called operationally, what the software is named, and what the file extension says. `Onset` is still accepted on input as an alias
* `model`: Device model e.g. `U20-001-01`, `ZL6`. This determines what the numbers mean - a HOBO U20-001-01 is the 9 m range version and the -04 is 4 m, so without it you cannot tell whether a pressure reading is in spec or off the end of the sensor
* `lat`: Latitude of deployment
* `lon`: Longitude of deployment
* `elev`: Ground elevation at these coordinates, in meters, looked up from a DEM - on every row, whatever the station type or role. It serves where an approximate absolute elevation is enough, such as correcting barometric pressure at a weather station. It is NOT used for the difference between two loggers: a hydraulic slope needs the difference measured in the field, which is recorded in `surveys.csv`, where the shared datum error cancels
* `elev_source`: Where the elevation came from. This matters because the values are not comparable in quality:

  * `usgs_3dep_1m`: USGS Elevation Point Query Service, 1 m lidar DEM. The default for US territories. In the Virgin Islands the source is the 2018 post-Maria lidar, on VIVD09, the Virgin Islands vertical datum (via GEOID12B) - not NAVD88, which does not extend here. A GNSS height converted with GEOID18 lands on the same datum, so the two compare to within a few centimeters, well inside the lidar's own vertical accuracy
  * `usgs_3dep_10m`, `usgs_3dep_30m`: The same service where lidar is unavailable and it falls back to coarser seamless data. The suffix is the resolution EPQS itself reported
  * `open_meteo`: Open-Meteo elevation API, a global product at roughly 90 m. Used only where USGS reports no coverage - outside US territory, such as the British Virgin Islands. Coarser than 3DEP by a wide margin, which is why it is recorded distinctly rather than lumped in as "a DEM"
  * `dem_manual`: Typed in after being looked up by hand on some DEM site. Use the SAME site for every station, or the values stop being comparable
  * `gnss`: Measured in the field with a GNSS receiver. Check whether the receiver reported orthometric or ellipsoidal height - in the Caribbean the two differ by tens of meters. An ellipsoidal height is converted with NGS GEOID18, H = h - N, from the NAD83(2011) ellipsoid to VIVD09, which puts it on the same datum as `usgs_3dep_1m`

  Blank means no elevation has been looked up yet
* `interval_min`: The TARGET logging interval in minutes - what the logger is meant to run at. A logger can run at another, and some HOBOs logged at 10 minutes for years: Product 2 brings any interval that divides the quarter hour onto its 15-minute grid, and records the interval each logger actually kept in its manifest
* `timezone`: Named time zone for R, "America/Puerto_Rico" for the Virgin Islands
* `deploy_datetime`: Date-time of actual deployment + functionality of sensor (an hour after initialization). For a station established before VI-FLO began in 2026 this is reconstructed rather than recorded: the device-level history of the 2021-2025 Ridge to Reef period was not kept at the time, and was recovered afterwards from logger exports, file boundaries and field notes. `record_confirmed.csv` marks the date each station came under VI-FLO's standards, so any deployment before it is reconstruction. The reasoning for each one is in docs/backfill/. See the provenance section of the README
* `end_datetime`: Date-time the deployment ended - the moment the logger left: its removal, or its replacement going in. Blank while the deployment is current, and required once its `status` is terminal. Set once, by the workflow that retires the row, and never moved by anything that happens at the station afterwards. Product 2 ends the deployment here, and the deployment's port windows close here
* `status`: Device status, set by a person. Never changed automatically - the machine may flag something worth a look, but the decision stays human.

  Active statuses describe how the device works and how its data reaches the archive:

  * `online`: Working, reports to the cloud over a cellular connection
  * `local`: Working, but out of cellular service. Data reaches the cloud only when offloaded on site (e.g. Bluetooth) and uploaded afterwards - though it may occasionally manage a connection on its own. Still API-downloadable, and a cloud subscription is required
  * `manual`: Working, but no cloud pathway at all. Data comes off by shuttle or cable and is archived by hand via the local ingest workflow
  * `defunct`: Broken or assumed lost, but still deployed

  An `online` logger that has gone quiet is not a status. The network to-do list and the doctor report flag any `online` logger with no contact in 14 days; whether that means anything is for a person to decide.

  Terminal statuses are historical markers and are excluded from active workflows. Each requires `end_datetime`:

  * `removed`: The device was taken out of the field. DEVICE-level and reversible - the station stands, and something may go back in. Use this when a logger comes out for repair, or when a position is left empty for now. Also covers a station whose sensors came out while the logger went elsewhere: when one ZL6 serves a weather and a vwc station and only the weather station relocates, the vwc station's sensors were removed even though the logger was not
  * `replaced`: Swapped for a new device at the same station. See the newer row for what took over
  * `relocated`: The station moved. See the newer row for where it went
  * `decommissioned`: STATION-level. Monitoring at this site has ended with no intention of resuming - in some cases its exact position is no longer known. Reactivation is possible and the workflow exists, because nobody knows the future; but a station expected to return should be `removed` instead. The distinction is intent, not permanence: `removed` means the position is waiting, `decommissioned` means it is not
* `last_visit`: Date of the most recent field visit to the station while this deployment was current. Written by the visit workflow at the same moment it writes the visit to `maintenance_log.csv`, and checked against it: it must equal the latest `field_visit_date` logged at the station within the deployment's span. Kept here, though the log holds it too, because it is the date most worth seeing at a glance. On a retired row it stays at the last visit before the deployment ended; when the deployment ended is `end_datetime`
* `metadata_approved`: Whether a human has confirmed that everything known about this station is recorded. This does NOT gate downloading - raw data is archived whatever the record says, because a Product 1 file applies no metadata at all. It gates ATTRIBUTION: readings are only assigned to a station whose configuration is known to be current. Applies to `manual` devices too, since their readings get attributed like any other. On a terminal row the value is frozen: it records what was confirmed while that deployment was current, which is what makes its archived data attributable
* `last_reviewed_utc`: When a human last answered that question, in UTC. The flag alone says someone once confirmed the record; it does not say whether that was this morning or in March, and a stale confirmation is worth less than a recent one. Updated whether the answer was yes or no - "I looked and something is missing" is as much a review as "I looked and it is fine". Blank means nobody has been asked yet

### Computed, not stored

These were once columns of `device_metadata.csv`. Each can be worked out from
a table that already holds it, so each is computed when it is needed - in the
network status, the to-do list, the doctor report - and never kept as a copy.

| Value | Worked out from |
|---|---|
| Last record - how current the data is | `end_date` of the newest Product 1 file attributed to the deployment, from `download_log.csv` |
| Last download | `timestamp_utc` of the newest row for the logger in `download_log.csv` |
| Battery | `battery` on the newest row for the logger in `download_log.csv` |
| Silent `online` logger | last record more than 14 days old |
| Cloud subscription expiry | asked of ZentraCloud when needed, if its API offers it; otherwise not tracked |
| Surveyed elevations, slope, sensor height | `surveys.csv` |

### `surveys.csv`

Measurements taken in the field with an instrument or a tape: one row per
number measured. Written only by a person, through the metadata manager.
Long rather than wide, so a new kind of measurement is a new word in the list
of quantities rather than a new column.

What is stored is what was measured, against what it was measured from. A
value relative to anything else - the overflow point relative to the
streambed, say - is computed by chaining rows, so that re-surveying one link
never leaves another value silently wrong.

**Signs.** Every quantity is defined so that its normal arrangement is
positive. A negative value means the reverse of what is expected - a rebar
top below the overflow point, a sensor below the streambed - and the doctor
report flags it for a second look.

* `station_id`: The station
* `unique_id`: The deployment measured
* `measured_on`: Date of the measurement, project-local
* `quantity`: What was measured, from a fixed list. The unit is part of the name:

  * `rebar_offset_cm`: How far this logger's rebar top sits above `relative_to` - normally `bed`, the streambed at the logger - in centimeters
  * `sensor_height_cm`: How far the logger's measuring point sits above `relative_to`, in centimeters. For a stream gauge `bed`, the streambed - a few centimeters. For a pond logger, also `bed`, and it can be tens of centimeters. For a weather station `ground`, the mounting height, normally 200 and recorded with method `nominal`. Never recorded for vwc: a soil moisture logger carries several sensors at several depths, recorded per port as `depth_cm` in `zentra_ports.csv`
  * `gzf_offset_cm`: Gauge of zero flow - how deep the pool must be before it overflows and streamflow begins. Recorded as how far `relative_to` - normally `rebar`, the main logger's rebar top - sits above the overflow point at the pool's edge, in centimeters. Surveyed only at some hydro stations, on the main logger, so never listed as missing
  * `elev_rel_m`: How far this logger's rebar top sits above the rebar top of `relative_to`, another deployment - normally the station's primary - in meters
  * `reach_length_m`: Distance from this logger to `relative_to`, another deployment - normally the station's primary - measured ALONG THE CHANNEL, in meters. Always positive. On a straight reach the along-channel distance and the straight-line distance are the same; where the channel bends the straight line is shorter, and using it overestimates slope and therefore discharge
* `value`: The measured number, in the unit the quantity names
* `relative_to`: What the measurement was taken from. Always filled in, even where it is the usual reference, so no row depends on a convention to be read:

  * `rebar`: this logger's rebar top
  * `bed`: the streambed (or pond bed) at the logger
  * `ground`: the ground at the station's coordinates
  * a `unique_id`: another deployment's rebar top
* `method`: How it was measured: `laser`, `level`, `tape`, `nominal` (a standard value, not measured - weather mounting height), or `record` (taken from an earlier record, such as prototype code or a field book, rather than measured for VI-FLO)
* `carried_from`: Blank for a measurement made on this deployment. When a logger is replaced and a survey still holds - the rebar did not move - the replacement workflow copies the row to the new deployment, keeping its original date and method, and records here the `unique_id` it was copied from. The row then reads truthfully: measured on that date, by that method, on the logger before this one
* `notes`: Free text - the source file, conditions, anything worth knowing

A quantity a station type requires and its current deployment lacks - sensor
height at a hydro station, say - is not recorded as missing. The doctor report
works it out and lists it as needing survey; a measurement clears it.

How Product 3 chooses among several surveys of the same quantity over time is
decided with Product 3.

### Which times are local, and which are UTC

Two kinds of time appear in this archive and they follow different rules.

A **field time** belongs to a place. Every measurement timestamp, and every
field describing something that happened at a station - `deploy_datetime`,
`end_datetime`, `last_visit`, `field_visit_date`, `measured_on`, `valid_from`,
`valid_to`, `start_date`, `end_date` - is in project local time,
`America/Puerto_Rico`.

A **machine event** does not. When a row was written is a moment, not a place,
and a download can be triggered from anywhere, including a cloud runner. Every
such column is UTC and ends in `_utc`: `timestamp_utc`, `logged_utc`,
`started_utc`, `finished_utc`, `created_utc`, `updated_utc`,
`last_reviewed_utc`.

A Product 1 filename carries both: its span dates are reading times and are
local, while its fetch stamp is a machine event and is UTC.

Two practical traps follow from this.

`as.Date()` on a POSIXct converts to UTC unless given `tz`. A reading at 21:58
local becomes the following day, which is how two filenames once came to be
dated a day ahead of their own data.

A POSIXct assigned into a character column becomes its numeric epoch -
`1791468900` rather than `2026-10-08 10:15:00`. Format before assigning.
`validate_metadata()` checks for both.

### `zentra_ports.csv`

What is plugged into each port of a ZL6, and over what span. Written only by
a person, through the metadata manager.

Each row belongs to one deployment. On a ZL6 shared between two stations -
Dorothea Weather's ATMOS and dor1_vwc1's TEROS sensors on one logger - the
weather port's row points at the weather deployment and the TEROS ports' rows
at the vwc deployment, and that is how Product 2 knows which readings go to
which station.

An empty port has no row. The logger's internal channels - its battery, its
own barometer - need none either; the logger's own barometer counts for a
station while any of that station's ports on the logger is open.

* `unique_id`: The deployment the port serves. The logger's serial comes from that row
* `port`: Port number, 1-6
* `sensor`: Sensor model, e.g. `TEROS 10`, `ATMOS 41`
* `depth_cm`: Depth of a soil sensor, in centimeters. Blank where not applicable
* `status`: Blank for a working sensor, or:

  * `defunct`: the sensor has failed but is still plugged in. Its readings are kept and flagged
  * `excluded`: plugged in and recorded, but its readings are never ingested - a sensor that never produced anything worth keeping, such as the ECRN-50 rain gauges on the early vwc loggers. The row exists so the record of what was plugged in stays truthful
* `valid_from`: Date-time of the first valid reading (i.e. an hour after installation). Required
* `valid_to`: Date-time of the last valid reading. Blank while the sensor is in place. Both must fall within the deployment's span: from its `deploy_datetime`, to its `end_datetime` if it has one

### `maintenance_log.csv`

One row per action at a station. Written only by a person, through the
metadata manager - by hand for routine actions, and by the workflows that
change the network for everything else.

* `logged_utc`: When the entry was written, in UTC
* `field_visit_date`: Date of the actual visit to the station, project-local
* `station_id`: The station
* `unique_id`: The deployment the entry concerns. Blank only for an entry about the station as a whole
* `action_type`: What was done, from a fixed list.

  Chosen by hand, for routine visits:

  * `inspection`, `cleaning`, `maintenance`, `battery`
  * `logger_relaunch`: HOBO only - a ZL6 is not launched and relaunched

  Written by the workflow that makes the change, and never chosen by hand:

  * `download`
  * `station_established`, `station_relocation`, `station_decommissioned`, `station_reactivated`
  * `device_added`, `device_replacement`, `device_removal`, `device_renamed`
  * `port_config_change`
  * `survey`: a visit on which measurements were taken. The numbers themselves are in `surveys.csv`
  * `metadata_correction`, `metadata_deletion`
* `details`: Free text describing what was done
* `logged_by`: Initials of the person logging

### `download_log.csv`

One row per Product 1 file. Files are written once and never rewritten, so
each row points at exactly what one fetch or one offload returned. Written
only by the machine: the scheduled job, and the HOBO ingest.

Keyed by the logger, not the deployment, because a Product 1 file is what a
physical logger recorded and can span deployments - the full-history exports
do. Which station each reading belongs to is decided at Product 2.

* `timestamp_utc`: When the download occurred, in UTC. Matches the fetch stamp in the filename, which is also UTC. The 26 `export` rows carry `2026-09-14 00:00:00`, the day the exports became Product 1, at midnight; their true fetch times are not known. It matches the stamp in their filenames and is kept so the two agree - the one documented exception to "unknown is blank"
* `run_id`: On an `automatic` row, the run in `run_log.csv` that fetched it. On a `manual` row, the ingest session that archived it - the files from one field trip share one. Blank on `export` rows
* `device_serial`: The logger the data came from. This is what identifies a Product 1 file
* `start_date`: Datetime of the first record in the file, in PROJECT LOCAL time
* `end_date`: Datetime of the last record in the file, in PROJECT LOCAL time
* `n_records`: Number of rows in the file
* `filepath`: Relative filepath within the data root
* `download_type`: How the data was obtained:

  * `automatic`: pulled through the ZentraCloud API
  * `manual`: offloaded by hand from a logger in the field
  * `export`: parsed from a ZentraCloud full-history export. These reach back before the API serves data, to 2021 in places - but the device-level history of that era was not systematically recorded, so attributing them rests on reconstruction rather than on a logged deployment. A user who wants nothing to do with that can filter on this column
* `battery`: The logger's battery percentage at the end of the file. Blank where the file carries none

Two downloads can overlap - a run repeated the same day, or a catch-up after a
failure. That is expected and is not corrected here: Product 1 records what
each fetch returned, and deduplication on timestamp happens at Product 2.

### `run_log.csv`

One row per run of the download job, scheduled or started by hand. Written
only by the machine. HOBO ingests are not runs and do not appear here.

* `run_id`: Identifies the run. Its Product 1 files and their `download_log.csv` rows carry the same value
* `started_utc`, `finished_utc`: When the run began and ended, in UTC
* `job`: Which job ran, e.g. `zentra_download`
* `devices_seen`: Loggers the run considered
* `devices_fetched`: Loggers it downloaded new data for
* `devices_up_to_date`: Loggers that had nothing new
* `devices_errored`: Loggers whose download failed
* `rows_fetched`: Readings downloaded in all
* `status`: How the run ended, e.g. `ok`
* `message`: Anything the run had to say
* `machine`: Which computer ran it

### `record_confirmed.csv`

From when each station's record can be trusted - meaning: from when do we know
which logger was serving it, as a contemporaneous log rather than a
reconstruction from notes.

The ZentraCloud exports reach back to 2021, but device-level history of that
era was not systematically recorded. Attribution needs to know which station a
device served; before some point per station, that is weaker knowledge.

Where exactly is a judgment. It cannot be derived - the obvious rule, that an
entry written long after the visit it describes was reconstructed, fails
because some real entries were logged from field notes six months late.

* `station_id`: The station, or `(default)` for the backstop row
* `confirmed_from`: Date from which the record is trusted
* `reason`: Why that date - what makes it the boundary

A station absent from this file is confirmed from the default. The file holds
exceptions only; an entry for every station would be a list of rows saying
"yes, this one is fine".

Written through `review_station_records()`, which shows what is known about a
station before asking.

### `known_unattributed.csv`

Periods of readings that belong to no station and are explained: a logger in
an earlier experiment, one sitting in a shed, an accident before deployment.
A Product 2 build prints these as KNOWN, apart from the UNEXPLAINED readings
that need looking at. Every row is verified against the logger's record or a
written source; the story behind each is in `docs/backfill/README.md`. Kept
newest first. An absent file means none are known. Written only by a person,
through the metadata manager.

Keyed by the logger, because these readings belong to no deployment. A sensor
that belongs to a deployment but whose readings should never be used is a
different case: its port is `excluded` in `zentra_ports.csv`.

* `device_serial`: The logger
* `device_name`: Its name, for the reader. Not matched on
* `port`: One port, or blank for the whole logger. A port narrows a period so it cannot hide something new on the logger's other ports
* `from`, `to`: Project-local, `YYYY-MM-DD HH:MM:SS`. Blank `from` is the start of the logger's record; blank `to` means still open
* `reason`: Why these readings belong to no station

Readings up to 7 days before one of a logger's deployments, or in its first 2
hours, are recognized without a row here, as AROUND INSTALLATIONS: a desk
launch, a test, the settling hour before a port's window opens.

### `pending_ingest.csv`

Offloads that have been started but not finished - the data is still on the
shuttle, or the CSV has not been exported yet. Rather than leave a person to
remember, a row records where the workflow stopped, and the metadata manager
raises it every time it is opened. Nothing reaches `download_log.csv` until
the data is genuinely archived. Written only by a person, through the
metadata manager; a row is removed when its ingest completes.

* `created_utc`: When the row was written, in UTC
* `updated_utc`: When it last moved stage, in UTC
* `station_id`: The station
* `unique_id`: The deployment whose data is waiting
* `field_visit_date`: Date of the visit the data came off on, project-local
* `logged_by`: Initials of the person logging
* `stage`: Where the workflow stopped:

  * `awaiting_offload`: data still on the shuttle
  * `awaiting_shuttle_drop`: offloaded, readout folder not yet filed
  * `awaiting_temp_csv`: readout in place, CSV not yet exported
  * `awaiting_rename`: CSV made, file not yet archived
  * `awaiting_cloud_upload`: a `local` Zentra offloaded on site, not yet uploaded to ZentraCloud - until it is, the data exists only on the field device
* `notes`: Free text
