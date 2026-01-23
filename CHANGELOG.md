# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

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
