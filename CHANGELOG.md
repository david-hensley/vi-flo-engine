# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

---

## [v0.5.0] (unreleased)

### Added
- `local_ingest_functions.R`
  - Interactive workflow for archiving manually-offloaded data (HOBO shuttle
    readouts, local Zentra downloads)
  - Instruction text held in clearly-bannered constants for easy editing
  - Detects the datetime column rather than assuming a position, since Onset's
    export format changed with the move to the LI-COR platform
  - Time-anchored scan helps locate a mis-saved export without pointing the
    user at machine-generated files
  - `update_last_record_date()` - did not previously exist
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
  - `check_pending()` surfaces outstanding offloads and flags stale ones
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
- `DATA_DICTIONARY.md`
  - Documented `$download_type`
  - Clarified that `$last_update` is `NA` for local (offline) devices by design -
    it records remote contact, which a HOBO logger structurally cannot report

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
