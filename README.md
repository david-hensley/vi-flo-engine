# VI-FLO Engine

Backend data and code engine for the Virgin Islands Freshwater and Landscapes Observatory (VI-FLO).

**Status:** Pre-development / scaffolding

---

## Overview

VI-FLO Engine is the core data and code backend for the VI-FLO project.
It is designed to handle data processing, analysis, and preparation for downstream applications.

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

- Converts relative paths to absolute paths
- Finds the location of the repo for scripts and data
- Sets two key environmental path variables: `VI_FLO_DATA_ROOT` and `VI_FLO_ENGINE_ROOT`
- If you move this repository or the database to a new location, you must re-run this!

> Note: `setup_win.exe` is stable and included in the repo for convenience.

---

## Usage

Once setup is complete, you can run the engine scripts from R. 
You must have an accompanying database with structural paths specified
in `datamap.csv`, or else use the default if your database structure is VI-FLO standard.

---

## Repository Structure

```
├── code/         # Main R scripts
├── data/         # Input and example data
├── docs/         # Additional documentation and notes
├── tools/        # Helper files, such as Python scripts for setup_win.exe
├── .gitignore    # Ignores api_tokens.csv for security, do not delete!
├── CHANGELOG.md  # Notes on major changes and versions
├── LICENSE.md    # Licensing and copyright information
├── README.md     # This file
└── setup_win.exe # Launches repo for first-time user (Windows)
```
---

## Dependencies

- R version 4 or higher
- Required R packages: 
    - `dplyr`
    - `ggplot2`

---

## Notes

- This engine is currently in pre-development. Features are incomplete.
- `setup_win.exe` is included for convenience; the main code lives in `/code/`.
- Use git tags to track major versions and changes.

---

## License and Authorship

License is MIT. For more information, see `LICENSE.md`. Primary codebase 
author is David A. Hensley, University of the Virgin Islands
(david.hensley@uvi.edu)
