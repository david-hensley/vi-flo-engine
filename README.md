# VI-FLO Engine

Backend data and code engine for the Virgin Islands Freshwater and Landscapes Observatory (VI-FLO).

**Status:** v2.8.0

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

Product 1 itself is complete, including the 2021-2025 archive imported in
October 2026. `validate_product1()` checks every file against the download log
and reports the archive's current size.

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
internal/discrete/surveys/gut_surveys/          paired-gauge surveys
```

Survey records are keyed by STATION, unlike the device-keyed files above: a
fall and a reach describe a pair of loggers, not one instrument. Each is named
`<station>_<quantity>_<method>_<date>` - `bta2_hydro_fall_rod_20261014.csv`
holds the rod readings exactly as typed, in the units they were read in;
`bta2_hydro_reach_trupulse_20261014.txt` is the TruPulse export as it came off
the device. What was concluded from them goes in the maintenance log.

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
internal/products/p2/hydro/sr1_hydro/abs_pressure/sr1_hydro_abs_pressure_p2_2026.csv.gz
internal/products/p3/weather/uvi_weather/precip/uvi_weather_precip_p3_2025.csv.gz
internal/products/p4/vwc/bta2_vwc1/vwc_30cm/bta2_vwc1_vwc_30cm_p4_2024.csv.gz
```

Station-year files, one variable each, `.csv.gz` - a format anything can open,
compressed because a station-variable-year is about 1.3 MB as plain text.
Filed by level first, because each level has its own life - Product 2 is
rebuilt freely, Product 4 rests on human decisions, a release ships one level -
and then by station, because a station-year is what regenerates together.
Named in full, so a file copied out of its folder still says what it is.

What becomes a variable, in which unit, and whether it is instantaneous or
accumulated, is set by `data/variables.csv` - one row for every measurement
any logger reports, kept or dropped.

Every value carries a flag: `observed`, `interpolated`, `substituted`,
`estimated`, `manual`, `missing` or `suspect`. So a decision resting on a
filled value is distinguishable from one resting on a measurement, and a user
can see what proportion of a series was actually measured.

### Product 2 - what it is

One file per station, variable and year, where the series is:

1. **attributed** - only readings that belonged to that station, by metadata
   as it stood at that moment. A ZL6 serving two stations is split by port;
   its own barometer goes to the weather station where there is one
2. **deduplicated** - where downloads overlap, the later fetch wins, and a
   disagreement is marked in the `conflict` column rather than resolved
   silently. A moment a logger itself recorded twice within one file - ZL6s
   write an extra record at 00:15 on scattered nights, plainly in ZENTRA's own
   export - is a repeat, not a conflict: the first, scheduled record is kept
   and the repeats are counted in the manifest
3. **on the network's 15-minute grid** - every quarter hour from the
   station's first reading of the year to its last has a row, and a gap is a
   row flagged `missing`, not two rows far apart. Logger swaps and changes of
   interval are absorbed here
4. **consistently named and in consistent units**, by `data/variables.csv`.
   At a hydro or pond station each deployment is its own series, named by
   its row in `device_metadata.csv`: `abs_pressure_h-0021`. A paired gauge's
   loggers measure at the same time in different places, and a deployment is
   one logger in one place, with one elevation and one sensor height - the
   unit anything computing level needs. Roles stay out of Product 2: how
   deployments combine into a station's level or discharge is decided
   later, and each series is one lookup from its role and everything else.
   Row ids run in order of creation, so the name also says which is older
5. **neither judged nor invented** - values as recorded, flagged only
   `observed` or `missing`. No quality control, no filled gaps: that is
   Product 3

How a reading reaches the quarter hour depends on what it is. An
instantaneous reading - pressure, temperature, water content - on the quarter
hour is used as is; off it, as a U20 launched at 10:08:37 is, it is
interpolated between the readings either side, but only between two real
readings no more than 15 minutes apart, never across a gap. An accumulated
reading finer than 15 minutes - 5-minute rain - is summed over the quarter
hour it ends in, and a maximum or minimum takes the highest or lowest, only
when every reading is present: a partial sum would undercount the rain
without saying so. Nothing coarser than 15 minutes is spread onto the quarter
hours between.

```csv
datetime,value,flag,device_serial,source_file,conflict
2026-09-28 08:15:00,0.291,observed,z6-13368,z6-13368_..._raw.rds,FALSE
2026-09-28 08:30:00,,missing,z6-13368,z6-13368_..._raw.rds,FALSE
2026-09-28 08:45:00,,missing,,,FALSE
```

Times are plain local times in the project's zone, which the manifest
records. A `missing` row with a device named is a moment the logger recorded
and the sensor gave nothing usable - a ZL6 error code, for one; with no device
it is a moment nothing recorded at all.

`build_p2()` builds a station-year from its devices' Product 1 files, writes
every variable, and removes anything an earlier build made that the current
inputs would not. Its summary sorts readings that belong to no station three
ways - UNEXPLAINED, KNOWN (periods in `metadata/internal/known_unattributed.csv`)
and AROUND INSTALLATIONS - each with the last 12 months first and newest
first. Nothing is hidden; only what is new is set out for attention. `products/p2/manifest.csv` has a row per file - one row,
replaced when the file is rebuilt - saying what it holds (rows observed and
missing, conflicts, repeats, any rain set aside in a repeat), how each logger
was aligned and the interval it actually kept, every Product 1 file read for
it, fingerprints of the metadata and ports of the loggers deployed there that
year, and the engine commit that built it.

Products are only ever built from a commit. `build_p2()` refuses while the
engine repo has any uncommitted change - code, docs, anything - because a
product must name the code that made it.

`build_p2_stale()` rebuilds exactly the station-years that are out of date:
never built, fed by a Product 1 file they were not built from, built from
metadata or ports of their loggers that have since changed, built by Product 2
code that has since changed, or no longer made by the current inputs. A
fingerprint covers only what decides Product 2 - which logger was where, from
when to when - so a battery reading rebuilds nothing, and correcting one
station's deployment rebuilds that station alone. The weekly job runs it after
every download; run it by hand after ingesting a HOBO offload or correcting
metadata, or `build_p2_stale(dry_run = TRUE)` to see what it would do.

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
paperwork. This way discharge exists within days, honestly labeled, and P4
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

Fallback never crosses a **barometric zone**. St Croix is one zone, St Thomas
and St John together the other. Within a zone, pressure differs by well under a
hectopascal on an ordinary day, and the zone's stations see the same weather
systems. Between zones the difference is small on a quiet day and wrong exactly
when it matters: a system moving through steepens the gradient, which is when
there is flow to measure. So a declared pairing names only same-zone sources,
and a cross-zone source is never automatic - it is possible only as a Product 4
decision, with a reason and a span, realistically for a zero-flow period. Like
any Product 4 input, the source station's pressure must itself be at Product 4.

St John has one weather station and St Thomas two, so the case this rule
actually governs is the St John station failing, with its gauges falling back
to St Thomas.

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

A release carries whatever level each series has reached, labeled. Waiting for
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

The practical consequence was that device-level history from that period was
not systematically recorded. Much of it has since been recovered: in October
2026 every station was reconstructed from logger exports, file boundaries,
field notes and photographs, and the reasoning for each is written up in
`docs/backfill/`. Those documents are the evidence behind any deployment date
that predates the system.

`record_confirmed.csv` marks the date each station came under VI-FLO's
standards. A deployment recorded before that date is reconstruction; one after
it was recorded as it happened. The distinction is deliberate and permanent -
a user who wants nothing to do with reconstructed history can filter on it.

Some things could not be recovered and are recorded as lost rather than
guessed. Two logger exports from Fish Bay are missing, one of them covering
Tropical Storm Philippe. The data itself is unaffected and remains good to
use, and site locations are accurate to within 5-10 meters.

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
It updates the engine from GitHub, pulls from Box, fetches whatever ZentraCloud
has that you do not, and pushes the result back.

The same job runs weekly on whichever machine holds the scheduled task, and a
logon or unlock after a missed Monday offers to run it. All three routes update
the code before fetching, so a machine that has been off for a week does not
run a week-old downloader. See
`tools/download/SCHEDULING.md`.

**To use the metadata manager**, double-click
`tools/launcher/metadata-manager.Rproj`. It opens RStudio, loads everything,
and goes straight to the menu.

**To look at a logger**, `view_device("z6-14635", "2021-07-01", "2022-10-01")`
draws everything it recorded in that period, one panel per variable and port,
against where metadata says it was - its deployments as solid and dashed
lines, labeled by station. Readings outside them are the ones Product 2 leaves
unattributed, and the picture usually says why: a sensor reading air in a
storeroom looks nothing like one in soil.

**To run the tests**, before calling a change good, after `start.R`:

```r
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tests/run_tests.R"))
```

Each test builds its own throwaway data root, so real metadata is never in
reach. Workflows are driven by scripted answers and checked by what they leave
behind. The suite is run by hand - not on every push, not on every session -
and takes a few seconds. A bug fixed should arrive with the test that would
have caught it.

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
│       ├── attribution_functions.R  # Readings to stations, and regularisation
│       ├── orphan_functions.R       # Archived files with no log row
│       ├── validate_product1_functions.R  # The archive against the log
│       ├── survey_functions.R       # Paired-gauge survey arithmetic, Product 0 writers
│       ├── product2_functions.R     # Product 2: registry, readers, grid, build_p2()
│       ├── inspect_functions.R      # Names for loggers; view_device() draws one's record
│       └── backup_restore_functions.R
│   └── jobs/
│       └── download_job.R           # Pull, fetch, push - scheduled or on demand
├── tests/
│   ├── run_tests.R   # The suite, run by hand
│   └── testthat/     # Tests, helpers and fixtures
├── data/         # Data dictionary, variable registry, sample metadata
├── docs/
│   ├── ROADMAP.md    # Open work, where it came from, what it waits on
│   ├── PLACE_NAMES.md  # VI-FLO's names for guts and watersheds, and everyone else's
│   ├── backfill/     # A dossier per station reconstructing its history
│   └── ...           # Additional documentation and notes
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
  * `testthat`, for the test suite only

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

