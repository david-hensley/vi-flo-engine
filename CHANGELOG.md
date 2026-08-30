# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

---

## [v0.6.1] (unreleased)

### Added
- `close_device_ports()`
  - Closes a device's port configurations when it leaves service, called on
    replacement and on decommissioning. Only device REMOVAL did this before,
    which is how a device replaced in January 2024 kept five sensors recorded
    as live for two years
  - Deliberately NOT called on relocation: a relocated device keeps its serial
    and its sensors, and ports are keyed by serial
- Decommissioning a station asks, device by device, whether a shared ZL6
  physically came out of the field. One logger can serve two stations, and
  ending one of them does not necessarily mean the box left the ground
- `ui_correct_device_details()`
  - Lists out-of-service devices too, tagged with their status. Their rows are
    the historical record, and a value recorded wrongly on one had no route to
    being fixed
  - Offers terminal-status correction for those devices, restricted to
    terminal-to-terminal and logged as `metadata_correction`. Returning a
    device to service is a reactivation - an event with its own workflow - not
    a correction
- `get_active_ports()` and a guard in `ui_initialize_ports()`. Ports belong to
  the DEVICE, not the station, so a ZL6 serving both a weather station and a
  vwc station is configured once. The second station is told so rather than
  creating a duplicate active set
- Adding a device whose serial is already active at a DIFFERENT station type
  inherits its manufacturer, model, name, coordinates, elevation, interval,
  timezone, deploy datetime, status and expiry from the existing row. It is
  the same physical box; re-typing its coordinates is how one logger ends up
  recorded at two slightly different locations
- Site list is filtered to the watershed just chosen
- `tools/migrations/migrate_lg3_to_lg1.R` - the La Grange gauge sits upstream
  of the weather station, so under the numbering convention it should carry
  the lower number. A split rather than a rename: `lg3` remains in use by the
  weather station
- `tools/migrations/migrate_fix_sr2_vwc1_replacement.R` - corrects a device
  swap recorded as `decommissioned`, and closes the port configurations that
  were left open

### Changed
- The duplicate-serial check now matches `validate_metadata()`: one active row
  per serial PER STATION TYPE. A serial active at a different station type is
  legitimate and is confirmed rather than rejected. Corrected in both the UI
  and `add_new_device()`, which each held their own copy of the rule
- `suggest_station_id()` falls back to the numbering convention of the station
  TYPE where a site has no precedent, so the first vwc station at a site is
  suggested as `_vwc1` rather than a bare `_vwc`

### Fixed
- Three port validation checks referenced `end_datetime`, `device_serial` and
  `start_datetime` - none of which are columns in `zentra_ports.csv`, where
  they are `valid_to`, `sn` and `valid_from`. A missing column returns NULL,
  `is.na(NULL)` is `logical(0)`, and the subsets came back empty, so all three
  reported success without examining anything. The first thing they found once
  repaired was a real two-year-old gap
- The terminal-device port check flagged any serial with a terminal row. A
  relocated device keeps its serial and its sensors, so a serial counts as out
  of service only when EVERY row for it is terminal
- `parse_datetime_flexible()` and `parse_date_flexible()` assumed character
  input. Given an already-parsed value they compared it to `""`, which coerces
  the empty string into a datetime and errors with "character string is not in
  a standard unambiguous format". This made port initialisation through the
  metadata manager fail every time

---
## [v0.6.0] 2026-08-29

### Added
- `local_ingest_functions.R`
  - Detects the interval the logger actually recorded at and warns when it
    differs from `interval_min`. Not corrected: `interval_min` records what a
    logger is MEANT to be set to, not what went wrong on one deployment
  - Warns when the record ends more than two days before the field visit -
    the logger stopped before anyone arrived, and that period is unrecoverable
  - Reads real HOBOware exports: skips the "Plot Title" preamble by detecting
    the header row rather than assuming a fixed offset, and handles the UTF-8
    BOM
  - Verifies the logger serial embedded in the column headers against the
    device selected, so opening the wrong .hobo file is caught outright
  - Instructions name the expected filename from `device_name`
- `logger_relaunch` action type, offered for HOBO devices only
- `code/start.R`
  - Loads everything needed for an interactive session in one line
- `setup_functions.R`
  - `load_all_functions()` discovers every `*_functions.R` file rather than
    listing them, so a new one is picked up with no list to update. The
    launcher's `.Rprofile` now uses it too - its hardcoded list had already
    drifted out of date
- `device_metadata.csv` and `SAMPLE_device_metadata.csv`
  - Added `$model` column immediately after `$mfger`. The model determines what
    the numbers mean: a HOBO U20-001-01 is the 9 m range version and the -04 is
    4 m, so without it a pressure reading cannot be judged in or out of spec
- `metadata_functions.R`
  - `is_hobo_device()` holds the accepted manufacturer spellings in one place,
    replacing the same alias check repeated at five call sites
- `metadata_manager_functions.R`
  - `ui_correct_device_details()` (existing station work, option 9) corrects
    descriptive fields recorded wrongly or left blank: model, device name,
    device role, interval, deploy datetime, latitude, longitude. Deliberately
    not a general row editor - things that HAPPENED belong in their own
    workflows, which log them
  - `suggest_station_id()` proposes the station ID from site and type, reading
    the numbering rule from existing data rather than hardcoding it. Whether a
    type carries a counter is whatever that type does at that site
  - `ui_prompt_device_status()` lists statuses in a deliberate order with their
    meanings. The previous prompt sorted whatever values happened to exist
    alphabetically, which put `defunct` first and could not offer a status
    nobody had typed yet
  - Site name is now chosen from a list, and its abbreviation derived from the
    existing record, so a typo can no longer fragment one site into two
  - Replacing a device at a hydro station now clears the inherited elevation
    and explains why: at a dual-logger gauge the elevation difference IS the
    hydraulic slope, so a stale figure silently produces wrong flow. Missing is
    safer than wrong
- `backup_restore_functions.R`
  - `save_metadata_state()` and `revert_metadata_state()`. These are SAVEPOINTS,
    not backups: one only, no history, taken deliberately to reset a testing
    session. `backup_metadata()` remains the actual backup - automatic,
    timestamped, per-file
- `tools/migrations/` and `README.md`
  - One-off scripts separated from live utilities, each stamped with the date
    it was applied, to be deleted at the next version tag. The README records
    the shape a migration should follow
- `README.md`
  - Data provenance section: the network was deployed under Ridge to Reef
    VI-EPSCoR (2021-2025) and VI-FLO began in 2026, so device-level history
    from that period was not recorded and is not recoverable. The data is
    unaffected; what is missing is provenance, not measurements
- `validation_functions.R`
  - Loads and checks `download_log.csv`, which validation had never examined
  - Confirms every logged filepath resolves to a file that exists. The log is
    the record of what has been archived; if a file is moved or renamed by
    hand, the log still claims it exists and nothing else would notice
  - Confirms every station in the download log exists in device metadata
- `metadata_manager_functions.R`
  - Survey now ASSIGNS device roles from the elevations it measures, rather
    than requiring them beforehand. Requiring roles first was backwards - you
    had to guess a role to obtain the measurement that tells you the role.
    Primary is downstream, downstream is lower, and the survey measures that
  - Where roles are already set, the survey warns if the measurement
    contradicts them - a secondary logger measuring lower than the primary
    means the roles are inverted and the hydraulic slope would come out with
    the wrong sign
  - Adding a device that COMPLETES a paired stream gauge now offers to record
    the elevation survey immediately, since the difference between the two is
    the hydraulic slope and it cannot be measured until both rows exist. A
    lone logger gets no such prompt - a single gauge rated from flow-meter
    measurements is a finished arrangement, not a half-built pair
  - Where a survey measurement contradicts the recorded roles, the workflow
    offers to switch them, naming both devices. The measurement is the
    evidence, so it corrects the record rather than sending the user elsewhere
  - Guardrail when creating a station whose ID already exists: for hydro it
    explains that a paired gauge is two devices at ONE station, and names the
    correct workflow. Previously it suggested a numbered second station
  - `device_label()` renders a device as name-then-serial throughout the survey

### Changed
- Manufacturer is recorded as `HOBO` rather than `Onset` - it is what the
  loggers are called operationally, what the software is named, and what the
  file extension says. `Onset` is still accepted on input as an alias
- `restore_directory()` reports the age of the backup and warns above 14 days.
  A stale snapshot in the expected place is indistinguishable from a fresh one,
  and reverting to it succeeds silently rather than failing
- Station `fb1_vwc1` renamed to `fb2_vwc1`. A site is a neighbourhood within a
  watershed and several station types may share one, but the Fish Bay soil
  moisture station sits at the coastal neighbourhood, which by the numbering
  convention is fb2 - leaving fb1 for a possible upstream gauge. The Fish Bay
  weather station is genuinely upstream and remains fb1
- `DATA_DICTIONARY.md`
  - Documented `$model`; noted that `$deploy_datetime` may predate the specific
    device for stations established before VI-FLO
  - Corrected `deploy_date` to `deploy_datetime`; removed markdown escapes
- Routine maintenance actions are now a declared list rather than the standard
  four plus every action type ever seen in the log minus an exclusion list.
  That list could not keep up - workflow-written types like
  `station_established` were being offered as things a human could hand-log
- Main menu offers `r. Resume an unfinished data task` when something is
  pending. Previously `check_pending()` reported work with no way to act on
  it, and the obvious guess would have duplicated the field record
- Reminder on exit to file station photos

### Removed
- `tools/log_maintenance_interactive.R`, `tools/initialize_port_config.R`,
  `tools/update_port_configs.R`
  - Superseded by the metadata manager, which does the same jobs and logs them.
    1,614 lines that looked live and would have written to real metadata
- `tools/testing/`
  - Replaced by `save_metadata_state()` and `revert_metadata_state()`, which
    need no separate scripts

### Fixed
- `metadata_manager_functions.R`
  - `$last_record_date` was omitted from `format_datetime_safe()` in all ten
    metadata writers, so the first real value written by the ingest workflow
    would have been mangled into a raw number by the next save
- `setup_functions.R`
  - `format_datetime_safe()` assumed a POSIXct column. A column that is
    entirely NA comes back from `read.csv()` typed as logical, and one read
    without date parsing as character; `format()` reads its second argument as
    `trim` for both and errored. Now checks the type first
- `metadata_manager_functions.R`
  - `ui_correct_device_details()` treated the return of `ui_select_from_menu()`
    as an index when it returns the selected string, so the station lookup
    silently found nothing
  - Display of a metadata value compared it to `""`, which errors on POSIXct
    and yields NA on numeric. `blank_or_value()` converts before testing
  - After a role switch during survey, the secondary elevation shown in the
    confirmation was computed before the swap and displayed a stale figure.
    The saved values were correct; only the display was wrong

---

## [v0.5.0] - 2026-08-25

### Added
- `local_ingest_functions.R`
  - Interactive workflow for archiving manually-offloaded data - HOBO shuttle
    readouts and cable-downloaded Zentra loggers
  - Instruction text held in clearly-bannered constants for easy editing
  - Detects the datetime column rather than assuming a position, since Onset's
    export format changed with the move to the LI-COR platform
  - Time-anchored scan helps locate a mis-saved export without pointing the
    user at machine-generated files. The anchor is what makes it trustworthy:
    nothing machine-generated is written while the workflow waits for the user,
    so anything newer is necessarily theirs
  - `archive_local_data()` holds all writing and never prompts, so a future GUI
    can call it directly rather than reimplementing it
  - `update_last_record_date()` - did not previously exist
- `status = "manual"` for devices with no cloud pathway at all - data comes off
  by shuttle or cable and is archived by hand. Distinct from `local`, which
  means out of cellular service but still reaching ZentraCloud once offloaded
  on site and uploaded
- `tools/launcher/`
  - RStudio project and `.Rprofile` that launch the metadata manager directly
    on double-click, via the `rstudio.sessionInit` hook. Batch files cannot do
    this because `readline()` returns immediately in non-interactive R
- `metadata_manager_functions.R`
  - Function code file for `metadata_manager.R`
  - Separates UI functions from core functions
- `file_naming_functions.R`
  - Single source of truth for raw data file naming, used by both the automated
    API path and the manual field-offload path so the two cannot drift apart
  - `build_raw_filename()` builds `{station}_{YYYYMMDD}_{YYYYMMDD}_raw.{ext}`
  - `parse_raw_filename()` reads a filename back into station and date range,
    parsing right-anchored so station IDs containing underscores are handled
  - `list_raw_files()` inventories archived files for a station
  - `check_raw_overlap()` warns when a proposed date range overlaps already
    archived data. Non-blocking by design: boundary-day overlap is normal for a
    logger downloaded and redeployed the same day, and duplicate records are
    resolved at processing by deduplicating on timestamp
  - `coerce_datetime_flexible()` accepts POSIXct, Date, text, or an Excel serial
    number, chaining `parse_datetime_flexible()` then `parse_date_flexible()`
- `download_log.csv` and `SAMPLE_download_log.csv`
  - Added `$download_type` column - `automatic` for ZentraCloud API downloads,
    `manual` for data offloaded by hand from a logger in the field
- `/tools/migrate_download_type.R`
  - One-time migration adding `$download_type` to an existing download log and
    backfilling all prior rows as `automatic`. Backs up before writing, verifies
    after, and is safe to run twice
- `pending_ingest_functions.R`
  - Tracks field data offloads that have been started but not finished, so an
    interrupted download workflow is remembered by the system rather than by a
    person - the failure mode VI-FLO exists to prevent
  - `pending_ingest.csv` records station, device, field visit, and the stage
    reached; nothing is written to the download log or `last_record_date`
    until data is genuinely archived
  - `check_pending()` runs at the top of every metadata manager menu and flags
    stale items
  - `awaiting_cloud_upload` stage covers a `local` Zentra offloaded on site but
    not yet uploaded to ZentraCloud - until it is, the data exists only on the
    field device
  - Deferred writes rather than transactional rollback: nothing is ever
    un-written, so nothing can be un-written incorrectly

### Changed
- `default_datamap.csv`
  - Renamed named path `internal_raw_streamflow` to `internal_raw_hydro` to match
    the `station_type` values used in device metadata. Underlying path unchanged
  - Fixes path resolution for hydro stations, which failed because
    `safe_download_zentra_station()` builds the key as
    `paste0("internal_raw_", station_type)`
- `api_functions.R`
  - `safe_download_zentra_station()` now delegates filename generation to
    `build_raw_filename()` instead of formatting its own string
  - Runs `check_raw_overlap()` before saving
  - Records `download_type = "automatic"` in the download log
- `ui_log_download()`
  - Branches on `status`: `manual` devices route to the local ingest workflow;
    `local` devices are asked whether the data has been uploaded to ZentraCloud
  - Field records - maintenance entry, `last_visit`, `last_download_date` - are
    written immediately, since they stay true regardless of whether the file
    ever reaches the archive. `download_log` and `last_record_date` assert
    something about the archive and are written only once that is true
- Download approval and cloud subscription expiry now gate on `manual` rather
  than `local`. `local` devices ARE API-downloadable - their data reaches
  ZentraCloud, just not over the air - so treating them as un-downloadable was
  wrong, and had caused real confusion about `fb1_vwc1`
- `validation_functions.R`
  - Accepts `manual` as a valid status
  - Check 6 moved from `local` to `manual`
- `DATA_DICTIONARY.md`
  - Documented `$download_type` and the `manual` status
  - Rewrote `$status` to describe every active value and how data reaches the
    archive for each, plus the terminal statuses
  - Clarified that `$last_update` is `NA` by design for `local` and `manual`
    devices - it records remote contact, which they structurally cannot report
  - Corrected `deploy_date` to `deploy_datetime` to match the schema
  - Removed markdown escape characters throughout

### Fixed
- `SAMPLE_download_log.csv`
  - Corrected a sample row filing a `_vwc1` station under `internal/raw/weather/`
- `file_naming_functions.R`
  - `%Y` silently accepted two-digit years, so HOBOware's default `MM/DD/YY`
    export parsed "03/02/26" as the year 26 AD. Now detected and re-parsed,
    with a hard guard rejecting any year outside 1970-2100

---

## [v0.4.0] - 2026-03-15

### Changed
- `log_maintenance_interactive.R`
  - Fixed bugs in maintenance logging script writing to devices metadata
  - Added handling of relocated devices
  - Added add_device() function for new devices and new stations

---

## [v0.3.0] - 2026-02-02

### Added
- `log_maintenance_interactive.R`
  - Standalone R script to live in `/tools/` and as a bridge before building GUI
- `maintenance_log.csv` and `SAMPLE_maintenance_log.csv`
  - Tracks station maintenance over time in metadata
- `SAMPLE_download_log.csv`

### Changed
- `device_metadata.csv`
  - Added `$device_role` column to track stations that may require more than one device such as Manning formula gauges
- `DATA_DICTIONARY.md`
  - Reflected added maintenance log and updates to device metadata
- `metadata_functions.R`
  - Added functions `load_maintenance_log()`, `load_download_log()`, 
- `api_functions.R`
  - Altered download logging in `safe_download_zentra_station()` to show only relative path of download in data root

---

## [v0.2.1] - 2026-01-26

### Changed
- `api_functions.R`
  - Fixes to `safe_download_zentra_station()` to correctly write to `device_metadata.csv`
- `setup_functions.R`
  - General helper function `format_datetime_safe` for use to convert POSIXct to string before write.csv()
  
---

## [v0.2.0] - 2026-01-25

### Added
- `metadata_functions.R`
  - Moved `load_zentra_metadata()` and added new `load_zentra_port_data()` functions
  - New function `backup_metadata()` and helper `clean_old_backups()` to backup local metadata

### Changed
- `setup_functions.R`
  - New functions to parse Excel or R dates and datetimes flexibly
- `api_functions.R`
  - New function `validate_zentra_metadata()` ensures logical consistency before download
  - New function `safe_download_zentra_station()` behaves more flexibly than raw download and stores output
- `devices_metadata.csv` and `DATA_DICTIONARY.md` and `SAMPLE_devices_metadata.csv`
  - Re-ordered and added columns e.g. `$last_download_date` and `$download_approved`
- `default_datamap.csv`
  - Added new named paths

---

## [v0.1.2] - 2026-01-25

### Added
- `setup_functions.R`
  - Home for top-level set-up functions to be read into any new R script for VI-FLO
  - Includes functions to easily manage the datamap
- `SAMPLE_device_metadata.csv` and `SAMPLE_zentra_ports.csv`
  - Fake metadata with columns for reference
- `DATA_DICTIONARY.md`
  - Full explanation of all files within /data/ 

### Changed
- `setup_win.exe` and `setup_win.py` and `datamapper.py`
  - Minor fixes to datamapper setup, checks in case of overwrite

---

## [v0.1.1] - 2026-01-23

### Changed
- `setup_win.exe` and `setup_win.py` and `datamapper.py`
  - Removed references to sample data root and sample datamap
  - Requires user specified data root folder, allows use of a default data map

---

## [v0.1.0] - 2026-01-23

### Added
- `/code/functions/api_functions.R`
  - Station-level ZentraCloud download functionality (`download_zentra_station()`)
  - Multi-device data collation for Zentra stations with device replacements or relocations
  - Port configuration system with time-based history tracking (`zentra_port_configure()`)
  - Sensor-specific configuration helpers (`configure_teros()`, `configure_atmos()`)
  - Metadata query functions (`get_zentra_metadata()`, `query_last_zentra_update()`)
- `/tools/set_api_tokens.py`
  - Sets environmental variables for given API tokens found in api_tokens.csv, found in /tools

### Changed
- `setup_win.exe` and `/tools/setup_win.py`
  - Integrated set_api_tokens.py into setup script

---


## [v0.0.1] - 2025-12-30

### Added
- `setup_win.exe` and `/tools/setup_win.py`:
  - Windows setup routine for new users of the VI-FLO Engine repository.
  - Sets global environment variables for the repo root and prompts the 
    user to select a data root via GUI.
  - Calls `datamapper.py` to map named paths from 
    `vi-flo-engine/data/named_paths.csv` to absolute paths, allowing 
    users to accept defaults or specify manually.

- `/tools/datamapper.py`:
  - Separate script to support mapping paths across platforms.
  - Can be reused in future OS-specific setup routines.

---

## [v0.0.0] - 2025-12-26

### Added
- Repository initialized.
- Directory scaffolding created.
