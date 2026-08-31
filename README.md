# VI-FLO Engine

Backend data and code engine for the Virgin Islands Freshwater and Landscapes Observatory (VI-FLO).

**Status:** v1.0.0

---

## Overview

VI-FLO Engine is the core data and code backend for the VI-FLO project. It
manages the metadata and raw data archive for a network of environmental
monitoring stations across the US Virgin Islands.

### What it does

**Metadata management.** An interactive manager records every station, device,
field visit, and data download. Establishing a station, swapping a device,
relocating or decommissioning one, reconfiguring sensor ports, surveying
elevations - each has a workflow that writes both the current state and a
maintenance log entry explaining it.

**Data download and archiving.** Zentra loggers are pulled from ZentraCloud
through its API. HOBO loggers are offloaded by hand in the field, and a guided
workflow walks the user through exporting and archiving them - verifying the
logger's serial against the file, detecting the recording interval, and warning
when a record ends before the visit that collected it.

**Validation.** A single command checks the metadata for internal consistency:
duplicate identifiers, orphaned references, port configurations on retired
devices, download log entries pointing at files that no longer exist.

### What it does not do yet

**Multi-user editing.** `device_metadata.csv` is a file, not a database, and
nothing prevents two people editing it between syncs. Until that is addressed,
one person at a time should be writing metadata. See CHANGELOG for the plan.

**Processing.** Water level to discharge, quality control tiers, and the
published archive are not part of this release.

---

## Data provenance

The VI-FLO monitoring network collects three kinds of data across the Virgin
Islands: weather station data, soil moisture sensor data, and water level
sensor data. One function of this repository is to systematically manage and
document that incoming data.

The network was first deployed under the Ridge to Reef VI-EPSCoR project
(2021-2025, [viepscor.org](https://viepscor.org)). The VI-FLO data management
system was not begun until 2026, so part of the archive predates the system
that manages it.

The practical consequence is that device-level history from the 2021-2025
period was not systematically recorded. Where a station's `deploy_datetime`
predates VI-FLO, it generally reflects the earliest archived record rather
than the installation of that specific device.

The data itself is unaffected and remains good to use. Site locations are
accurate to within 5-10 metres. What is missing is provenance, not
measurements, and VI-FLO exists so that the gap closes going forward rather
than widening.

### Published literature using VI-EPSCoR data

Lancellotti, B.V., Hensley, D.A. (2025). Controls on nitrogen export to an
ephemeral stream network of St. Croix, US Virgin Islands. *Journal of
Environmental Quality* 54(2), 465-482.
[doi.org/10.1002/jeq2.20667](https://doi.org/10.1002/jeq2.20667)

Hensley, D.A., Knappenberger, T., Lancellotti, B.V., Brantley, E., Shaw, J.N.,
Dobre, M., Lindner, J.R. (2025). Runoff generation in ephemeral streams of the
Virgin Islands: The case of Salt River, St. Croix. *Journal of Hydrology:
Regional Studies* 59, 102372.
[doi.org/10.1016/j.ejrh.2025.102372](https://doi.org/10.1016/j.ejrh.2025.102372)


---

## API tokens

Contact the authorized person (David Hensley) for the api_tokens.csv file.
This file contains all the necessary API keys for automatic downloading.
Store this file in the VI-FLO Engine `/tools/` folder, then run the setup program.

DO NOT DELETE THE `.gitignore` FILE - THIS PROTECTS THE API KEY FROM BEING PUBLISHED!

---

## Setup

Before using the engine for the first time, run the included helper (Windows only): `setup_win.exe`

**What it does:**

* Converts relative paths to absolute paths
* Finds the location of the repo for scripts and data
* Sets two key environmental path variables: `VI_FLO_DATA_ROOT` and `VI_FLO_ENGINE_ROOT`
* If you move this repository or the database to a new location, you must re-run this!

> Note: `setup_win.exe` is stable and included in the repo for convenience.

---

## Usage

You must have an accompanying database with structural paths specified in
`datamap_engine.csv`, which `setup_win.exe` generates in your data root. That
file holds absolute paths for one specific machine and is deliberately
excluded from sync - re-run setup on each computer rather than copying it.

**To work in R**, load everything in one line:

```r
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/start.R"))
```

This sources `setup_functions.R`, loads every other function file, and reports
any unfinished data tasks.

**To use the metadata manager**, double-click
`tools/launcher/metadata-manager.Rproj`. It opens RStudio, loads everything,
and goes straight to the menu.

---

## Repository Structure

```
├── code/
│   ├── start.R              # One-line session setup
│   └── functions/
│       ├── setup_functions.R        # Paths, datamap, date parsing
│       ├── metadata_functions.R     # Loaders and metadata operations
│       ├── ui_prompt_functions.R    # Shared interactive prompts
│       ├── metadata_manager_functions.R  # Workflows and the menu
│       ├── api_functions.R          # ZentraCloud downloads
│       ├── local_ingest_functions.R # HOBO and cable offload archiving
│       ├── file_naming_functions.R  # Raw file naming, shared by both paths
│       ├── pending_ingest_functions.R    # Unfinished field tasks
│       ├── validation_functions.R   # Metadata consistency checks
│       └── backup_restore_functions.R
├── data/         # Data dictionary and sample metadata
├── docs/         # Additional documentation and notes
├── tools/
│   ├── launcher/     # Double-click entry to the metadata manager
│   ├── migrations/   # One-off schema and data migrations, with a README
│   ├── setup_win.py  # Setup routine, built to setup_win.exe
│   └── datamapper.py
├── .gitignore    # Ignores api_tokens.csv for security, do not delete!
├── CHANGELOG.md  # Notes on major changes and versions
├── LICENSE.md    # Licensing and copyright information
├── README.md     # This file
└── setup_win.exe # Launches repo for first-time user (Windows)
```

---

## Dependencies

* R version 4 or higher
* Required R packages:

  * `dplyr`
  * `ggplot2`

---

## Notes

* `setup_win.exe` is included for convenience; the main code lives in `/code/`.
* Use git tags to track major versions and changes.
* `device_metadata.csv` should not be opened outside the metadata manager.
  Editing it in Excel silently rewrites datetime formats, and there is no
  workflow that cannot do what a hand edit would.

---

## License and Authorship

License is MIT. For more information, see `LICENSE.md`. Primary codebase
author is David A. Hensley, University of the Virgin Islands
(david.hensley@uvi.edu)

