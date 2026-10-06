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
  every column a character string, so untouched values are written back
  byte-identical and no datetime is silently reformatted.
- **Verify afterwards** and say what it checked. Where a migration renames
  files, verification should confirm that every path recorded in the logs
  still resolves to a file that exists - that is the check which catches a
  half-completed rename.
- **Never guess.** A new column is left blank rather than filled with a
  plausible value. An invented value looks authoritative and will never be
  questioned.

Where a migration is risky enough to want a preview, give it a `dry_run`
argument defaulting to `TRUE`, as `migrate_fb1_to_fb2.R` does.

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

