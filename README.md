# VI-FLO Engine

Backend data and code engine for the Virgin Islands Freshwater and Landscapes Observatory (VI-FLO).

**Status:** v2.4.1

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

**Processing.** The product scheme is defined and the folders exist, but
nothing is written into them yet. Attribution resolves readings to stations
and variables; writing Product 2, automatic quality control, the derived
series and the published archive follow it.

---

## Data products

The data root divides on the property that governs everything else: what is
held, and what is made from it.

```
internal/
    device-data/     what instruments gave us
    products/        what we derived from it
    discrete/        what people measured by hand
```

One side is written once and never touched. The other is thrown away and
rebuilt whenever a parameter changes. That decides what is backed up carefully,
what is versioned, and what a migration has to preserve.

### Product 0 - source artifacts

Exactly what came off the instrument or out of the vendor's export, kept
permanently and never edited.

```
internal/device-data/hobo/shuttle_readouts/     .hobo files
internal/device-data/zentra/backfill/exports/   ZentraCloud export zips
```

### Product 1 - device-keyed readings

One row per measurement, identified by device serial and port number. No
station, no depth, no interpretation.

```
internal/device-data/zentra/
    z6-12874_20260925_20260928_20260928T090359_raw.rds
    serial _ first record _ last record _ when fetched

internal/device-data/hobo/
    21352826_20250903_20260201_raw.rds
```

A station name in a filename is an ATTRIBUTION, and attributions can be wrong:
a logger swapped between stations and logged late leaves files filed under the
wrong one. The device serial never needs correcting, so Product 1 is keyed by
it and station attribution is deferred.

Files are written once and never rewritten. Each is exactly what one fetch or
one offload returned, with a matching row in `download_log.csv`.

RDS, because a faithful copy is the point and type fidelity is what faithful
means - a datetime stays a datetime rather than becoming a string somebody has
to parse correctly forever.

### Products 2 and up - station-attributed series

Every variable has its own ladder:

| | |
|---|---|
| **P2** | attributed, regularly spaced, gaps inventoried |
| **P3** | automatic quality control, declared parameters |
| **P4** | human decisions applied |

```
internal/products/hydro/level/p2/sr1_hydro_2026.csv.gz
internal/products/weather/precip/p3/uvi_weather_2025.csv.gz
internal/products/vwc/vwc_30cm/p4/bta2_vwc1_2024.csv.gz
```

Station-year files, one variable each, `.csv.gz` - a format anything can open,
compressed because a station-variable-year is about 1.3 MB as plain text.

Every value carries a flag: `observed`, `interpolated`, `substituted`,
`estimated`, `manual`, `missing` or `suspect`. So a decision resting on a
filled value is distinguishable from one resting on a measurement, and a user
can see what proportion of a series was actually measured.

### Derived series

Some variables are computed rather than measured, and the chain runs deeper
than it looks. A stream gauge records absolute pressure, not water level:

```
abs_pressure  +  barometric  ->  level  +  rating curve  ->  discharge
```

**A derived series takes the product number of its weakest input.** Level
computed from pressure that has had automatic quality control but no human
review is level P3, and discharge from that is P3 too. When the underlying
pressure reaches P4, regeneration produces P4 versions of both.

That matters more than it sounds. Requiring P4 inputs would mean nobody sees a
hydrograph until two stations had been reviewed by hand - research waiting on
paperwork. This way discharge exists within days, honestly labelled, and P4
follows when review catches up.

The gate runs the other way: **P4 of a derived series requires P4 inputs.**
Reviewing level built on unreviewed pressure means deciding about values that
will change underneath you.

A **rating curve** and a **barometric pairing** are PARAMETER SETS, not data. A
new curve produces a new version of the discharge series, recording which curve
built it; the product does not change and both versions stay reproducible.

### Barometric pairing

Level needs barometric pressure from a weather station, corrected for the
elevation difference between it and the gauge - which metadata already holds
for both.

The pairing is DECLARED, per station, with validity periods and a priority
order. A weather station can die: dor1_weather stopped reporting in October
2026, and every gauge paired to it needed a fallback.

```csv
station_id,baro_source,priority,valid_from,valid_to,reason
dor2_hydro,dor1_weather,1,2025-11-05,,nearest - 1.2 km
dor2_hydro,uvi_weather,2,2025-11-05,,fallback - 11 km
```

The rule is then deterministic: the highest-priority source with data at that
timestamp. Fallback happens automatically but within a declared order, so the
result is reproducible - the ordering is a parameter, not runtime cleverness.
Values built on a fallback carry the `substituted` flag and record which source
was used.

### Regeneration

Products 2 and up are REGENERATED, never edited. There is one file per
station-year per product, overwritten when rebuilt - so regeneration never adds
files and nothing accumulates. The manifest records what built it: input
versions, parameters, decisions, when. An old version is recovered by
rebuilding from those, not by keeping a copy.

Something upstream changing is what triggers it - new readings, corrected
metadata, a changed parameter, a new decision, or a dependency regenerating.
The unit is the station-year, so new data for October 2026 rebuilds that year
for that station and leaves 2024 alone.

Regeneration is dependency-ordered, because a derived series can depend on
another station's: a correction at a weather station ripples to every gauge
paired to it.

**P4 regenerates too.** Decisions are rows, so rebuilding means reapplying them
- but each records the span of evidence it rested on. A decision whose evidence
did not change carries forward untouched; one whose evidence moved is flagged
for re-review rather than silently reapplied. That is why the evidence span is
recorded when the decision is made and cannot be worked out afterwards.

### Releases

A citation needs more than a version number. The manifest points at parameters
and decisions in a repository that could be amended; a reviewer in 2030 needs
the numbers, not a recipe and some trust.

So a release is a frozen snapshot with a DOI - the actual files, plus the
parameters, decisions and metadata as they stood. Made when something needs
citing, not on a schedule.

A release carries whatever level each series has reached, labelled. Waiting for
everything to reach P4 would mean releasing nothing.

### Discrete measurements

```
internal/discrete/hydro/flowtracker2/
internal/discrete/sediment/ssc/
internal/discrete/soil/saturo/  ksat/  hyprop2/  wp4c/
```

A FlowTracker gauging measures discharge. So does the series under
`products/hydro/discharge`. The difference is not the quantity but how it was
arrived at - one logged by an instrument on a schedule, one measured by a
person standing in the stream. So the two sit beside each other, and someone
asking what discharge data exists finds both in parallel places.

No product stages here. A gauging is what it is.

Named for the instrument, because one HYPROP run yields retention and
unsaturated conductivity together and naming the folder after either would
leave the other homeless. `ssc` is the exception: there is no instrument,
bottles go to whichever lab has capacity.

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

**Do not open the ZentraCloud integrations page to read the token.** Viewing it
appears to regenerate the key, which invalidates it on every machine already
using it. Copy `api_tokens.csv` between machines instead.

After changing a token, run `set_api_tokens.py`, then **close RStudio entirely**
and reopen - a running session keeps the environment it started with, and
Session > Restart R is not enough.

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

This sources `setup_functions.R`, loads every other function file, connects to
ZentraCloud, reports the state of the session - uncommitted work, metadata
changed since the last savepoint, how the data root differs from Box, when the
last download ran - and raises any unfinished data tasks.

**To see the network**, `print_network_status()` for every station and how it
is doing, or `print_network_todo()` for what needs attention. Both are also in
the metadata manager under option 3.

**To download the latest data**, double-click `tools/download/run_download.bat`.
The same job runs weekly on whichever machine holds the scheduled task; see
`tools/download/SCHEDULING.md`.

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
│       ├── zentra_download_functions.R   # ZentraCloud v5 downloads
│       ├── elevation_functions.R    # USGS 3DEP and global elevation lookup
│       ├── local_ingest_functions.R # HOBO and cable offload archiving
│       ├── file_naming_functions.R  # Raw file naming, shared by both paths
│       ├── pending_ingest_functions.R    # Unfinished field tasks
│       ├── validation_functions.R   # Metadata consistency checks
│       ├── session_functions.R      # What to know at session start
│       ├── guard_functions.R        # Refuses writes over a changed file
│       ├── network_status_functions.R  # What needs attention across the network
│       └── backup_restore_functions.R
│   └── jobs/
│       └── download_job.R           # Pull, fetch, push - scheduled or on demand
├── data/         # Data dictionary and sample metadata
├── docs/         # Additional documentation and notes
├── tools/
│   ├── launcher/     # Double-click entry to the metadata manager
│   ├── migrations/   # One-off schema and data migrations, with a README
│   ├── backfill/     # One-time ZentraCloud export parser, kept for audit
│   ├── download/     # Double-click launcher, logon prompt, scheduling notes
│   ├── setup_win.py  # Setup routine, built to setup_win.exe
│   └── datamapper.py
├── .gitignore    # Ignores api_tokens.csv for security, do not delete!
├── CHANGELOG.md  # Notes on major changes and versions
├── LICENSE.md    # Licensing and copyright information
├── README.md     # This file
└── setup_win.exe # Launches repo for first-time user (Windows)
```

---

## Data sources

Elevations are looked up from the **USGS Elevation Point Query Service**,
which interpolates the 3DEP dynamic elevation service - 1 m lidar where
available, NAVD88 vertical datum. This covers the US Virgin Islands, Puerto
Rico, Culebra and Vieques.

Where USGS reports no coverage, the lookup falls through to the
**[Open-Meteo](https://open-meteo.com/) elevation API**, a global product at
roughly 90 m resolution. Open-Meteo data is provided under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) and is free for
non-commercial use.

`elev_source` in `device_metadata.csv` records which was used, because the two
differ substantially in accuracy. See `data/DATA_DICTIONARY.md`.

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

