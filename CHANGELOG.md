# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

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
