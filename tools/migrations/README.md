# Migrations

One-off scripts that alter the structure or contents of the database, kept
separate from `/tools/` so that live utilities and spent scripts are never
confused for each other.

A script here has already been run. It is retained only so the change it made
is legible, and it will be deleted at the next version tag.

## The rule

**Applied on every machine, and released?** Delete it. Git history keeps it if
anyone ever needs to see what was done, and the change itself is recorded in
`CHANGELOG.md`.

**Not yet applied everywhere?** Leave it. A second machine that has not run a
migration still needs the script.

Each file carries an `APPLIED:` line recording when it was run.

## What a migration should do

Every script here follows the same shape, and new ones should too:

- **Back up first.** Before touching anything, so a failure is recoverable.
- **Detect prior application** and exit cleanly. Safe to run twice.
- **Read with `read.csv()`**, not `load_zentra_metadata()`. Reading raw keeps
  every column a character string, so a migration sees the table exactly as
  it stands - including the shape it is changing, which the engine's schema
  may already have moved past.
- **Write through the data layer** - `write_table()` in `table_functions.R` -
  from v2.9 on. It writes the table in its one format, refuses a value that
  is not its column's type, and backs the table up first. A migration that
  writes the file itself is a second way into the metadata, which is what the
  layer exists to end.

  The October 2026 migrations did not follow this and read through
  `load_zentra_metadata()` instead. Nothing was lost - `validate_metadata()`
  now checks every datetime field parses, and it passes - but the rule stands
  because that check was written after the fact rather than before.
- **Verify afterwards** and say what it checked. Where a migration renames
  files, verification should confirm that every path recorded in the logs
  still resolves to a file that exists - that is the check which catches a
  half-completed rename.
- **Never guess.** A new column is left blank rather than filled with a
  plausible value. An invented value looks authoritative and will never be
  questioned.

Where a migration is risky enough to want a preview, give it a `dry_run`
argument defaulting to `TRUE`, as `migrate_fb1_to_fb2.R` does.

## In progress: v2.9

v2.9 moves the tables to their new shape one at a time, each by its own
script below, alongside a check that the data layer changed nothing. They
stay until the v2.9 tag, then join the table under *Applied*.

| Script | Applied | What it does |
|---|---|---|
| `check_layer_v2.9.R` | 2026-11-20 (before), 2026-11-20 (after: pass) | Not a migration: a record of every table and Product 2 file taken before the data layer, and the comparison that showed the layer changed nothing |
| `migrate_maintenance_log_v2.9.R` | 2026-11-21 | Step 4.1: entries name their deployment; `logged_utc`; `station_type` and `ports_updated` dropped; `elevation_survey` becomes `survey` |
| `migrate_logs_v2.9.R` | 2026-11-21 | Step 4.2: the download log drops `station` and gains `battery`; pending tasks name their deployment, with UTC stamps |
| `migrate_ports_v2.9.R` | 2026-11-21 | Step 4.3: port rows name their deployment; empty-port placeholders dropped; rain gauges excluded; a row spanning a move split in two |

## Applied

Every script below has been run and released. The scripts themselves are gone -
git history holds them, and because a migration changes DATA rather than code,
a second machine already has the result through Box and never needs to run one.

| Migration | Applied | What it did |
|---|---|---|
| `migrate_download_type.R` | 2026-08-23 | Added `download_type` to `download_log.csv`, backfilling existing rows as `automatic` |
| `migrate_add_model.R` | 2026-08-26 | Added `model` to `device_metadata.csv`, positioned after `mfger`, left blank |
| `migrate_fb1_to_fb2.R` | 2026-08-26 | Renamed station `fb1_vwc1` to `fb2_vwc1` across metadata, logs, archived files, and photos |
| `migrate_add_reach_length.R` | 2026-09-12 | Added `reach_length_m` - distance along the channel to a station's primary logger, without which a surveyed elevation difference cannot produce a slope |
| `migrate_fill_elevations.R` | 2026-09-12 | Looked up `elev` for every active device from USGS 3DEP, recording `elev_source` |
| `migrate_uvi_breadfruit_area.R` | 2026-09-26 | Set `area` on the UVI breadfruit soil moisture stations, grouping them as one experiment |
| `migrate_collapse_sr2_weather.R` | 2026-09-26 | Removed a row asserting the old logger was deployed at the new sr2_weather position - an artefact of logging one field operation as a relocation followed by a replacement |
| `migrate_fix_uvi_ports.R` | 2026-09-26 | Corrected four depths and every installation date on z6-13368. Established from the export's configuration history and from response lag to 49 rainfall events - the sensors are buried and cannot be checked by hand |
| `migrate_clear_api_archive.R` | 2026-09-26 | Deleted seventeen files downloaded through the v4 API, which baked port depths into column names so a corrected depth silently invalidated them |
| `migrate_device_data_layout.R` | 2026-09-27 | Reorganised raw data into `device-data/`, keyed by device rather than station |
| `migrate_download_log_serial.R` | 2026-09-28 | Added `device_serial` - a Product 1 download has no station, so the serial is what identifies it |
| `migrate_download_log_timezones.R` | 2026-09-28 | `timestamp` became `timestamp_utc`; reading times became project-local. A reading belongs to a place, a run timestamp to a moment |
| `migrate_utc_filename_stamps.R` | 2026-09-28 | Restamped 37 Product 1 filenames in UTC, matching the log rows that point at them |
| `migrate_metadata_approved.R` | 2026-09-28 | `download_approved` became `metadata_approved`, with `last_reviewed_utc` beside it. The flag alone said someone once confirmed the record, not whether that was this morning or in March |
| `migrate_clear_meaningless_roles.R` | 2026-09-28 | Cleared ten `device_role` values that meant neither of the two things a role can mean - including three separate stations at Limetree labelled primary, secondary and tertiary |
| `migrate_hobo_batch_review.R` | 2026-09-28 | Recorded a review of twenty HOBO records, blank only because the flag they inherited was forced FALSE for manual devices |
| `migrate_download_log_run_id.R` | 2026-09-30 | Added `run_id`, joining a Product 1 file, its download row and its run row |
| `migrate_products_layout.R` | 2026-10-01 | Reorganised the data root around what is held and what is made from it: `internal/device-data/` immutable and device-keyed, `internal/products/` regenerable and station-keyed. `raw` disappeared |
| `catchup_products_layout.R` | 2026-10-01 | Brought a second machine onto that layout. `rclone copy` never deletes, so a pull alone leaves the old folders in place - this retired them |
| `migrate_discrete_and_cleanup.R` | 2026-10-02 | Separated discrete measurements from logged series. A gauging and a discharge record hold the same quantity arrived at differently, one by an instrument on a schedule and one by a person standing in the stream |
| `migrate_backfill_to_product1.R` | 2026-10-03 | Gave the 26 parsed full-history exports their bookkeeping - date ranges and fetch stamps in the filenames, and a `download_log` row each - so they became Product 1 rather than intermediate working output |
| `migrate_fix_pit_depths_and_reviews.R` | 2026-10-06 | Corrected the six-port pit depths on three replicate-plot loggers, and cleared legacy review flags |
| `migrate_prototype_metadata.R` | 2026-10-11 | Wrote the prototype era into metadata: ten device rows for loggers that had recorded for a VI-FLO station and had none, including four HOBOlink sensors and Turpentine Run 2, whose station did not exist at all. Corrected deploy dates a device had inherited from its station's establishment, and the maintenance entries that named the device present now rather than the one present then |
| `migrate_prototype_metadata_2.R` | 2026-10-11 | Filled what the first pass left: device roles, Dorothea's surveyed reach, last-visit dates, and elevations for every row that lacked one. Corrected Reef Bay's coordinates, where three pairs had been in circulation and none was right |
| `migrate_fishbay_correction.R` | 2026-10-11 | Replaced a removal that never happened. A further export showed Fish Bay's upstream logger ran five months longer than the dossier had it, and left the gut when it was dug out after Tropical Storm Philippe |
| `migrate_device_facts_repair.R` | 2026-10-11 | Undid facts written per serial rather than per deployment, which had given a retired deployment its successor's dates. Restored declared logging intervals from a backup, and carried the Adventure elevation survey into metadata |
| `migrate_datetime_repair.R` | 2026-10-11 | Formatted eighteen datetime values stored as UNIX epochs, filled `last_download_date` on every Zentra row, and renamed five Product 1 files whose span was a day ahead of their own data |
| `migrate_u20_model_04.R` | 2026-10-17 | Corrected all 27 HOBO U20 stream gauge rows from `U20-001-01`, the 9 m model, to `U20-001-04`, the 4 m model they are. By explicit `unique_id`, because real `U20-001-01` loggers were joining at the ponds |
| `migrate_add_sensor_height.R` | 2026-10-17 | Added `sensor_height_cm` after `elev_source`: 200 on every weather row, blank elsewhere. On hydro blank means not yet measured, on vwc not applicable |
| `migrate_remove_windsor_note.R` | 2026-10-17 | Removed the Windsor Pond survey note logged as routine maintenance, before the survey was re-entered through the rebuilt single-device workflow |
| `migrate_known_unattributed.R` | 2026-10-18 | Created `known_unattributed.csv` with the eleven verified periods of readings that belong to no station - the plantain loggers, DiscoveryG's orchard year, R2R Farm in its shed and the rest - then, run again, added SR2 Hillside's weeks in storage |
| `migrate_hobo_log_rows.R` | 2026-11-03 | Repaired eight download-log rows the HOBO ingest had appended by position, two columns short, so the October 2026 offloads were never seen as logged and Product 2 skipped them |
| `migrate_retired_dates.R` | 2026-11-03 | Re-dated 13 retired rows and 12 port windows that routine visits and replacements had moved, so their Product 2 deployments ended when their loggers actually left; recorded three known unattributed periods |

