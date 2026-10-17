# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

---

## [Unreleased]

### Added
- **`docs/PLACE_NAMES.md`**, a gazetteer. It sets out the naming convention:
  a watershed is named for the gut at its mouth, its main stem carries that
  name to the headwaters, and tributaries become areas. It records why, and
  the three names that do not follow it Then, watershed by watershed, it gives the
  names other sources use and the reason for each choice VI-FLO made
  - **Bethlehem.** Adventure, `bta`, is the western branch that USGS and DPNR
    call River Gut, and McGuire (1925) Jealousy Gut. VI-FLO does not use
    "River Gut" in site names because USGS applies it to the trunk below the
    confluence as well. The smaller tributary also called Adventure Gut,
    joining just downstream of `bta2`, would be Bethlehem Adventure West,
    `btw`. The watershed is Bethlehem rather than Fairplain because Fairplain
    is falling out of use and recent DPNR documents use Bethlehem
  - **Limetree**, the other exception: not one gut but several, draining
    toward the former Krause Lagoon, which other sources group as the
    Hovensa watershed. What unites them is the south shore industrial
    complex downstream of them all
  - **UVI**, named for the Albert A. Sheen campus, which lies within the
    Bethlehem watershed. Its areas are campus projects, not tributaries
  - **Caledonia, Creque, La Grange, Salt River, St. George, Dorothea,
    Turpentine Run, Fish Bay and Reef Bay**, with their historical, upstream
    and alternative names, drawing on McGuire's 1925 *Geographic Dictionary*
    wherever it has an entry
  - The spelling of gut, ghut and ghaut, in the words of Hensley (2025)

- **`sensor_height_cm`** in `device_metadata.csv`, after `elev_source`: the
  height of a device's measuring point above the ground at its coordinates.
  `elev` is the ground, and a water level becomes a water-surface elevation
  only once this is added. A stream gauge's few centimeters have been ignored,
  but a pond logger's measuring point can sit 28 cm up
  - Added by `tools/migrations/migrate_add_sensor_height.R`: 200 on every
    weather row, the known mounting height, and blank everywhere else. On
    hydro, blank means not yet measured - no gauge has had it taken, and a
    guess would never be questioned. On vwc it means not applicable
  - Asked when a device is added, including as a replacement, since a new
    logger can sit higher or lower than the old one. Weather suggests
    200 cm; vwc is not asked, because its sensor depths are per port in
    `zentra_ports.csv`. Correctable under 'Correct device details', and
    cleared on relocation, since it was measured at the old position

### Changed
- **The single-device survey is rebuilt** (field surveyed elevation,
  option 2), as `ui_survey_single_device()`
  - Sensor height first, then the elevation by one of three routes: typed as
    an orthometric height; computed from a NAD83(2011) ellipsoidal height and
    the GEOID18 geoid height, H = h - N, with the NGS link printed for the
    device's own coordinates; or kept. A shot on the measuring point has the
    sensor height taken off, because `elev` is the ground
  - Writes `elev_source` with the value, takes an optional note, and logs as
    `elevation_survey` with the full arithmetic
  - A hydro secondary or tertiary is sent to the paired survey - its
    elevation is the fall. Moving a hydro primary moves its surveyed
    partners by the same amount, so the measured falls are kept
- Registering a station or device asks for a note, which goes into its
  `station_established` or `device_added` entry rather than a second one
- `DATA_DICTIONARY.md`: `area`'s example no longer implies that Adventure Gut
  is the tributary `bta2` sits on. `watershed` and `area` both point to the
  gazetteer
- The `bta2_hydro` and `bta2_vwc` dossiers say which channel they are on, and
  point to the gazetteer
- `README.md`: the gazetteer is listed in the repo layout

### Fixed
- Removed the Windsor Pond elevation note logged as routine maintenance on
  2026-10-17, by `tools/migrations/migrate_remove_windsor_note.R`. It stood in
  for a survey the old workflow could not record; the survey is re-entered
  through the rebuilt one, so keeping both would log it twice
- **The old single-device survey wrote to every row with the serial**, other
  stations and retired deployments included, and never touched
  `elev_source` - so a surveyed elevation kept claiming to be a DEM lookup.
  `survey_device_elevation()` now writes one row, by `unique_id`
- `DATA_DICTIONARY.md` said `usgs_3dep_1m` elevations are NAVD88, which does
  not extend to the Virgin Islands. They come from the 2018 post-Maria lidar,
  on VIVD09. The `gnss` entry now says how a receiver's ellipsoidal height
  reaches the same datum: GEOID18, from the NAD83(2011) ellipsoid. The
  stored `elev_source` value names the source, not the datum, so no data
  changes; the header of `elevation_functions.R` carried the same wrong note
  and is corrected
- **Every HOBO U20 stream gauge was recorded as the wrong model.** All 27
  rows, active and retired, said `U20-001-01`, the 9 m (30 ft) range logger.
  They are `U20-001-04`, the 4 m (13 ft) model, so any check of a reading
  against its sensor's range would have used the wrong limit.
  `tools/migrations/migrate_u20_model_04.R` corrects them by explicit
  `unique_id` rather than by model, because real `U20-001-01` loggers are
  about to join the network at the pond sites

---

## [v2.6.0] - 2026-10-14

The paired-gauge survey now goes from field notebook to metadata in one
workflow. Before, it asked for an elevation difference and a reach length
already worked out by hand - so the reduction lived in a notebook and the
arithmetic was never checked.

### Added
- **`ui_survey_gut_pair()`**, reached as option 1 of the field elevation
  survey. Survey date and initials first, then the station and pair, then
  each half in turn
  - **The fall**, from a builder's level and rod or typed in meters. For the
    rod: its units are chosen up front - feet-inches-eighths, decimal feet,
    meters or centimeters - then backsight (upstream rebar) and foresight
    (downstream rebar) for as many independent setups as were taken, then the
    rebar-to-measuring-point offset at each logger in their own units, chosen
    separately because a tape can be in anything
  - Each rod reading is entered one number at a time - feet, inches, then
    eighths, with decimal eighths accepted for a reading between graduations -
    and read back for confirmation ("You entered 4' 3 2/8\" - correct?")
    before it is used. Eighths are shown as entered, not reduced, so the
    screen matches the notebook
  - Each setup gives `fall = (FS + d_down) - (BS + d_up)`. The two that agree
    most closely are offered, and averaged if within 10 mm. One setup alone is
    accepted only as UNCHECKED. No agreeing pair means no fall from those
    readings - start again, type it, or skip it
  - A fall that is not positive means the end named upstream is not higher,
    so it is refused outright: mislabeled ends or a bad reading. Falls are
    shown without a sign, and a negative one is labeled as a climb
  - **The reach**, from a TruPulse export or typed in meters. The export's
    horizontal distances are summed and the arithmetic shown, in feet or
    meters as the device recorded them. It refuses a file whose legs disagree
    with its header unit, or whose leg count disagrees with its own total,
    and warns when shots are dated other than the survey date
  - A typed fall or reach requires a line saying how it was measured, so a
    manual value never looks like a surveyed one later. This is also the
    route for a reach that would need turning points
  - Either half can be skipped, and at the end saved alone: a re-measured
    reach does not need a re-leveled fall. The confirm screen shows old and
    new values for both, and the slope
- **`code/functions/survey_functions.R`** - the arithmetic, with no prompts:
  rod and offset conversion, the fall, pair selection, the TruPulse reader,
  slope, and the Product 0 writers. Testable on its own
- **Product 0 for surveys**, in `internal/discrete/surveys/gut_surveys/`,
  keyed by station and named `<station>_<quantity>_<method>_<date>`
  - The rod readings are written as typed, in their original units, beside
    their value in meters, to `<station>_fall_rod_<date>.csv`. Which setups
    were accepted is a decision, not a reading, so it goes in the maintenance
    log instead
  - The TruPulse export is renamed to `<station>_reach_trupulse_<date>.txt`
    rather than copied, as with HOBO exports. A same-day re-survey gets `_2`
  - Written before anything touches the metadata. If they fail, nothing is
    saved

### Changed
- **Role is no longer position.** Primary means the anchor - the logger whose
  elevation is sourced externally, where flow is gauged, the position kept
  long-term. Normally downstream, but not required to be
  - The survey asks which logger is upstream, reminding that it is normally
    the secondary. It no longer offers to switch roles when the primary
    turns out higher
  - The rod readings cannot tell which LOGGER stood at the backsight end, so
    a mix-up there still gives a positive fall - and a wrong elevation. Two
    guards instead: naming the primary as upstream asks for confirmation,
    and a survey that puts the surveyed logger on the other side of the
    primary from the record says so on the summary screen, before saving.
    Both came out of the first live survey, at Bethlehem Adventure 2, where
    the primary was named upstream by mistake and saved - caught only
    afterwards, from the maintenance log, and reverted
  - Where roles are not yet set, it suggests the downstream logger as primary
    and you choose
  - Slope is now `|surveyed elev - primary elev| / reach`, positive whichever
    end is primary. RB-c, a tertiary below its primary, works without special
    handling
- `survey_dual_logger_elevations()` writes either half alone - NA leaves a
  value as it is - and records the primary's `elev_source` when the survey
  had to establish its elevation
- The maintenance log line for a survey records the arrangement as measured,
  the method behind each half, old and new values, and the slope
- **American spelling throughout** the function files and the README, data
  dictionary and roadmap: meters, centimeters, canceled, labeled, recognized
  and the rest. User-facing prompts included. The backfill dossiers and the
  older CHANGELOG entries are left as written

### Fixed
- **The station list counted every HOBO ever installed.** Dorothea showed
  four loggers, two of them long removed. Removed, replaced, relocated and
  decommissioned loggers are now excluded from the list and from the pair
- **A survey that assigned roles was never logged.** The roles-not-yet-set
  path saved the elevations and returned before the maintenance entry and
  `last_visit`. Option 1 is now one path, so every survey is logged

### Documentation
- `DATA_DICTIONARY.md`: `device_role` redefined as above; `elev` for a hydro
  logger is the sensor's elevation, 1-2 cm above the bed; the slope formula
- `README.md`: status brought up to date; the survey Product 0 folder; the
  barometric zone rule - St Croix one zone, St Thomas and St John the other,
  automatic fallback only within a zone, cross-zone only as a Product 4
  decision
- `ROADMAP.md`: the survey section rewritten around what remains; turning
  points recorded as deliberately deferred; survey geometry over time folded
  into the time-varying role question, with the decision to rely on the
  maintenance log and Product 0 for now

---

## [v2.5.2] - 2026-10-12

Logging a battery replacement printed the menu and then dropped to the R
console. One unbound variable, ten broken prompts.

### Fixed
- `ui_select_or_specify()` referenced `extra_key`, `extra_options`,
  `extra_label` and `showing_extra` without any of them being parameters or
  local variables. The function printed its menu, hit the first mention, and
  died before reading a selection - so whatever the user typed next went to
  the R console and echoed back
  - Every call was affected, not only the one that surfaced it: the action
    prompt in the maintenance logger, and the watershed, area, site, site
    abbreviation, station type, device role, manufacturer and model prompts
    that make up the establish-a-station path
  - The three parameters are now in the signature with NULL defaults, and the
    second list a caller can offer behind a key - retired stations behind "r",
    say - works as intended rather than existing as dead code

### Note
- This is what a metadata manager test pass is for, and the roadmap has one
  outstanding since 7 October. The fault was not subtle and would have been
  found in minutes by walking the menus; it survived because nothing walks
  them

---

## [v2.5.1] - 2026-10-12

A power cut over the weekend left the desktop off at 07:00 on Monday, and the
weekly download simply did not happen. Nothing noticed until somebody looked.
Three faults in the same chain.

### Fixed
- **The catch-up prompt measured staleness, not the schedule.** It asked
  whether the last download was more than seven days old, which is a
  different question from whether Monday's run happened. A Monday missed
  while the machine was off would not have been raised until the Wednesday,
  because the previous Thursday's run was still inside the window
  - It now finds the most recent Monday 07:00 and asks whether a download has
    run since. One hour's grace, so 07:00 is not late at 07:30
  - The dialog names the date the job was due, and lists what running it will
    do

- **Nothing in the download chain updated the engine.** Box was pulled before
  every run and pushed after, but the CODE was whatever happened to be on
  disk - which on a machine untouched for a week is a week-old downloader
  working on today's data
  - `tools/download/run_download_job.bat` is new: it pulls the engine, then
    runs the job. The scheduled task calls it instead of invoking Rscript
    directly
  - The interactive `run_download.bat` and the catch-up prompt go through the
    same path, so all three routes update before R starts
  - Pulling from inside `download_job.R` was not enough on its own: R has
    already read the script by then, so an update would only apply to the
    next run. It stays as a backstop for anyone running the script directly
  - A pull is refused over uncommitted changes, and a failed pull does not
    stop the download. Being unable to reach GitHub is not a reason to skip a
    week of data

- **The catch-up prompt could not launch the job.** Task Scheduler runs it
  with `-WindowStyle Hidden`, which is what keeps it silent on every unlock
  when there is nothing to say - but a child process inheriting that absent
  console cannot start, and failed with `0xc0000142`. It now asks Windows for
  a fresh console rather than the parent's

- A `goto` out of a `for` loop in both batch wrappers exited the enclosing
  `if` as well, so the job reported `git is not on PATH` immediately after
  successfully running `git status`

---

## [v2.5.0] - 2026-10-11

The 2021-2025 Ridge to Reef archive is in. 76 exports, 1.46 million readings,
and a dossier for every station explaining where each claim comes from. The
prototype era is now something the repository can point at rather than
something tangled up in it.

### Added
- 70 HOBO U20 exports imported as Product 1 with their `download_log` rows,
  via `import_hobo_backfill.R`
  - The serial comes from the file header, never the filename. Seven files
    named `RB-2021*` hold Fish Bay's upstream logger under the plot title
    `FishBay1`; reading the name would have filed two years of one site's
    record under another
  - Duplicates are matched on serial, span and reading count to the minute,
    because the same export exists at two precisions - with and without
    seconds - and comparing to the second treats them as different files
  - A contained span is superseded; a seam overlap is reported and allowed,
    since a logger read in the morning and relaunched that afternoon carries
    readings either side of the visit
- 6 HOBOlink telemetry exports imported, 781,506 readings at five minutes,
  via `import_hobolink_backfill.R`
  - Keyed by the water pressure SENSOR rather than the base. Salt River 1's
    base was replaced in August 2023 and the sensor stayed in the water;
    keying on the base would have split one continuous record in two
  - Columns are read by their `M-` sensor code, never by position: the
    barometric column is third in one Salt River 1 file and sixth in the other
  - The station's own computed water level is kept. Product 2 will recompute
    from pressure so every station derives the same way, with the computed
    column as a check against that
- `docs/backfill/` - 22 dossiers covering every station, each a dated sequence
  with its evidence quoted beneath, and claims graded established, inferred or
  unknown
- `record_confirmed.csv` now carries a date for every active station: when it
  was born to VI-FLO, with everything earlier marked as reconstruction
- Ten prototype-era device rows, including four HOBOlink sensors and
  Turpentine Run 2, whose station did not exist in metadata at all
- `audit_hydro_metadata.R` - read-only, checks every hydro row against the
  data rather than against the migrations that produced it

### Changed
- Device facts are derived per DEPLOYMENT, not per serial. A device that
  served two stations was being given one date for both, so a retired
  deployment inherited its successor's. A deployment now ends at whichever
  comes first: the next deployment, or the day the device left
- `interval_min` is no longer written from observed timestamps. The field
  carries the DECLARED interval, set at relaunch through the metadata manager;
  the observed one belongs to the data, where the memory check already reads
  it. A declared fifteen against an actual ten is what cost Salt River 1 and
  La Grange a month each
- Product 1 filenames carry their span in PROJECT LOCAL time. A filename holds
  both kinds of time - its fetch stamp is a machine event and stays UTC - and
  five files had been named for the day after their own last reading

### Fixed
- `zentra_update_device_facts()` assigned a POSIXct straight into a character
  column, which R coerces to its numeric epoch. Eighteen rows read
  `1791468900` instead of `2026-10-08 10:15:00`. It also never wrote
  `last_download_date`, leaving every Zentra row blank in a field the
  dictionary defines for all devices
- Fish Bay's reconstruction had its upstream logger removed in March 2023. An
  export in a subfolder earlier scans had not descended into showed it ran
  until September, and a message sent a week after Tropical Storm Philippe
  records what actually happened: the mounting stake snapped, a boulder came
  to rest on the housing, and the logger was dug out intact
- Reef Bay's coordinates. Three pairs were in circulation and none was right -
  the authoritative positions are 286 m and 166 m from what had been recorded

### Added - validation
- `validate_product1()` and `product1_coverage()` in
  `validate_product1_functions.R`. Eight checks on the archive itself: every
  file reads back, holds a datetime column that parses and carries a zone,
  matches its log row on rows and span, holds measurements rather than only
  timestamps, and runs forward in time
  - The measurement check is the one that matters. A file whose numeric
    columns came back as text passes every other test - right count, right
    span, right dates - and carries nothing usable
  - Rows and distinct timestamps are reported separately, because a Zentra
    file is long format: 24,795 rows can be 1,066 timestamps across 23
    port-variables
- Six checks added to `validate_metadata()`, now 34
  - `EPOCH_IN_DATETIME_FIELD`, `UNPARSEABLE_DATETIME` and
    `FILENAME_SPAN_MISMATCH`. Two writers each broke a rule the dictionary
    already stated and nothing noticed; a repair fixes the instance, a check
    fixes the class
  - `REACH_LENGTH_ON_PRIMARY`, `ELEVATION_WITHOUT_SOURCE` and
    `RECORD_DATE_OUTSIDE_DEPLOYMENT`, folded in from a one-off audit rather
    than left in a script nobody would run again
  - The filename check initially passed on the bug it exists to catch.
    `as.Date()` on a POSIXct converts to UTC unless told otherwise, so it
    turned a local 21:58 into the following day and then agreed with a
    filename that had made exactly that mistake

### Changed - datetime handling
- Every path that writes a datetime into metadata or a log now goes through
  `format_datetime_safe()`, which takes a timezone and can only produce a
  formatted string
  - The local ingest path had found this bug once and fixed it locally, with
    a thorough comment. The Zentra downloader then made the same mistake
    independently. The knowledge existed and did not travel, because the fix
    was a workaround rather than a shared helper

### Added - documentation
- `docs/ROADMAP.md` - open work, where each item came from, what it waits on.
  The list had been living in session transcripts and in recollection, which
  meant rediscovering it each time and carrying at least one item that had
  never existed
- `DATA_DICTIONARY.md` gains a section on which times are local and which are
  UTC, with both traps named: `as.Date()` on a POSIXct silently converting to
  UTC, and a POSIXct assigned into a character column becoming its epoch

### Note
- River, on Fair Plain Gut, is in Product 1 with no metadata row and no
  station id. The reach cannot be gauged at any stage that matters - anchored
  gear is swept away, and there is no stage worth measuring at which it is
  safe to enter the water - so stage can never become discharge there. The
  absence is a decision, and `river_hydro.md` exists to say so
- Two Fish Bay exports are missing and are not recoverable. One covers
  Tropical Storm Philippe

---

## [v2.4.1] - 2026-10-09

### Fixed
- The ZentraCloud key was set in `start.R`, which is not the only way in. The
  metadata manager launcher calls `load_all_functions()` directly, so the
  manager's network views failed with "no API key found" while the same
  functions worked from the console. Moved to `connect_zentracloud()`, called
  from `load_all_functions()` - the path both routes already take
  - It warns on a missing key even when loading quietly. The launcher loads
    quietly, and that is precisely where it was being missed
  - The warning names the trap: a running R session keeps the environment it
    started with, so updating a token means closing RStudio, not restarting
    the session
- A failed `zc_list_devices()` was caught and discarded, so the checks that
  depend on it found nothing and reported all clear. A dead API key read as
  "every device is fine" - the worst way for a check to fail, and it hid a
  station that had been down six days. Both views now say what could not be
  checked: the to-do list gains a COULD NOT CHECK section, and the roster says
  its contact times are unknown rather than absent

### Note
- Viewing the ZentraCloud integrations page appears to regenerate the API
  token, invalidating it everywhere it is in use. Both machines lost access
  twice in one afternoon this way. Copy the token between machines by file;
  do not open that page to read it

---

## [v2.4.0] - 2026-10-08

The engine answers two different questions now, and says which is which.
`print_network_status()` is the roster - every station and how it is doing.
`print_network_todo()` is what needs attention. The second was previously
called the first, which made the obvious question unanswerable.

### Added
- `get_station_roster()` and `print_network_status()` - every active station
  grouped by watershed, with device, status, battery, last cloud contact and
  how far the archive reaches
  - `data_to` comes from download_log rather than a metadata field, because a
    file arrives without touching metadata. It is the only honest answer to
    "how current is this station's data"
  - A manual device shows `offload` rather than a contact time. A cloud
    timestamp for a logger that has never spoken to the cloud is not missing,
    it is meaningless
- Both views reachable from the metadata manager, under option 3. The launcher
  alone now gets you field recording, the roster and the to-do list
- `start.R` loads zentraR and sets the ZentraCloud key. Every function that
  reaches the API needed this done first, and doing it by hand each session is
  a step that only ever gets forgotten - the download then failed with an
  authentication error rather than saying what was actually missing
- `start.R` ends with the handful of commands a session usually starts with.
  Not a menu, just the spelling

### Changed
- `get_network_status()` and `print_network_status()` became
  `get_network_todo()` and `print_network_todo()`
- Hydro logger memory is reported as a DEADLINE, not a percentage. "88% full"
  needs arithmetic before it can be acted on; "fills 03 Nov 2026 - 25 days" is
  a date to plan a trip around. Past the deadline it reads "FULL since 20 Sep
  2026 - 18 days of readings already lost"
  - Capacity lowered from 21,700 to 21,600. Three loggers have been observed
    stopping between 21,693 and 21,695 readings; a warning that fires a few
    days early costs nothing and one that fires late costs the data
  - Warns within 60 days, which is roughly the planning horizon for a trip to
    another island
- The to-do list is ordered field work first - not reporting, battery, memory,
  survey, known broken - then what can be answered from a desk
- Every section prints whether or not it has anything in it. A heading that
  disappears leaves the reader to notice an absence, which nobody does; a
  heading saying "no low batteries" is read in a second and believed

### Fixed
- The memory check took its interval from metadata, which is what someone
  meant to set rather than what the logger did. 21352826 and 21652375 ran at
  ten minutes while metadata declared fifteen, so they filled in 150 days
  rather than 225 - twice, costing a month at Salt River and La Grange on each
  occasion. The interval now comes from the timestamps of the most recent
  file, and a disagreement with metadata is named in the warning

---

## [v2.3.0] - 2026-10-06

The data root is reorganised around the distinction that governs everything
else: what is held, and what is made from it. `internal/raw` is gone.

```
internal/
    device-data/     what instruments gave us - immutable, device-keyed, RDS
    products/        what we derived - regenerable, station-keyed, csv.gz
    discrete/        what people measured by hand
```

BREAKING for anything that resolved a path through the datamap:
`internal_raw_hydro`, `internal_raw_vwc` and `internal_raw_weather` no longer
exist. Nothing outside the engine consumed them, which is why this is a minor
bump rather than a major one.

### Added
- `internal/products/<domain>/<variable>/p<n>/` - station-year files, one
  variable each
  - Every variable has its own ladder. P2 attributed and regularly spaced with
    gaps inventoried, P3 automatic quality control with declared parameters,
    P4 human decisions applied
  - A DERIVED variable starts its ladder from the top of its input's: discharge
    P2 is computed from level P4, not from level P2. Otherwise every correction
    made to level would have to be made again to discharge, and inconsistently
  - Which splits the old `streamflow` folder in two. Once a rating curve stands
    between level and discharge they are series with separate histories, and a
    new curve regenerates one without touching the other
- `internal/discrete/<domain>/<instrument>/` - what a person measured rather
  than what an instrument logged
  - A FlowTracker gauging measures discharge. So does the series. The
    difference is not the quantity but how it was arrived at, so the two sit
    beside each other rather than one above the other
  - Named for the instrument, because one HYPROP run yields retention and
    unsaturated conductivity together and naming the folder after either would
    leave the other homeless. `ssc` is the exception: there is no instrument,
    bottles go to whichever lab has capacity
- `product_path()` and `discrete_path()`. The structure is composed in code
  rather than enumerated in the datamap, so changing it later means changing
  one function instead of an entry per stage
- First-pass network status - devices gone quiet, low battery, HOBOs filling,
  subscriptions, stations with no ports configured, stale reviews, paired
  gauges with no survey. Printed after a download, when the API has just been
  asked about every device and the answers are as fresh as they get

### Changed
- Products 2 and up are `.csv.gz`, not RDS. RDS is right for Products 0 and 1 -
  a faithful copy nobody reads by hand, where type fidelity is the point. From
  P2 the audience changes: a researcher asking for a station's rainfall should
  get a file that opens in anything
- `external/raw` and `external/processed` are gone. External data is somebody
  else's, taken as given, and the processing discipline those names imply does
  not apply to it. Grouped by source instead

### Removed
- The v4 ZentraCloud path - `api_functions.R` and the scratch file that drove
  it. Nothing outside itself called any of its twelve functions
- Seventeen applied migrations, their record kept in `tools/migrations/README.md`.
  A migration changes DATA, which syncs through Box, so a second machine
  already has the result and never needs to run the script
- Build artefacts that should never have been committed - compiled Python and
  PyInstaller intermediates - now in `.gitignore` so they stay out
- Spent plans: a roadmap for a v0.2.0 reached differently, v0.0.2 checklists
  long done, a TODO list of functions that exist. The two naming rules worth
  keeping were moved into the data dictionary

### Fixed
- `rclone copy` never deletes, so Box held every path that had ever existed and
  a pull restored them - which is how `internal/raw/streamflow` came back full
  of station-prefixed files months after they were moved. Retired paths are now
  purged from Box too, narrowly and with a preview. Never `rclone sync`, which
  would mirror deletions in both directions and make one bad local state enough
  to lose the archive
- The migration pushes to the new path and verifies the count before purging
  the old one, so there are never fewer than two copies of 650 MB

---

## [v2.2.0] - 2026-10-01

The download runs itself. A scheduled job keeps the archive current without
anyone remembering to fetch, and the session reports what it found rather than
leaving it to be asked.

### Added
- `code/jobs/download_job.R` - pull from Box, fetch what ZentraCloud has that
  the archive does not, push back
  - Pulls FIRST. Box carries whole files, so appending to a stale
    download_log.csv and pushing would overwrite the other machine's rows. This
    narrows the window in which that can happen from a week to the job's own
    runtime - it does not close it, which is why the prompts say not to run it
    while somebody is working elsewhere
  - Exits 0 or 1, so a scheduler can tell. A failed push says plainly that this
    machine now holds data no other copy has
- `tools/download/run_download.bat` - the same job on a double-click, for when
  you want the data now rather than on Monday
- `tools/download/check_download_due.ps1` - at logon, if the last successful
  download is more than 7 days 2 hours old, a dialog offers to run one
  - Deliberately NOT Task Scheduler's own catch-up, which fires at an
    unpredictable moment - possibly while somebody is writing metadata on the
    other machine, which is the collision the job exists to avoid. A prompt
    fires when a person is at the keyboard and can answer
- `tools/download/SCHEDULING.md` - setting up both tasks, and moving them to
  another machine
- `run_log.csv` - one row per invocation, whether or not anything was fetched
  - download_log.csv records what was FETCHED. A run that fetched nothing
    leaves no row there at all, which is exactly the failure worth catching:
    a job that silently stops working looks identical to a quiet week
  - `devices_seen` is worth as much as the rest. If it drops from 17 to 13 one
    week, something changed in the account and nothing else would say so
  - `machine` records which computer ran it. Two names alternating means a
    scheduled task was installed somewhere and never removed - the one
    configuration that loses data
- `run_id` joins the three records: a Product 1 file, its download_log row and
  its run_log row all carry the same UTC stamp
- Session status on start.R - uncommitted work and unpushed commits, metadata
  changed since the last savepoint, how the data root differs from Box, and
  when the last download ran. Every category reports, including when it has
  nothing to say: silence is ambiguous between "checked and fine" and "never
  ran", and after waiting for the Box check the difference matters
- A concurrent write guard. Every read records the file's hash; a write that
  finds the hash changed is refused and names the rows that differ. It catches
  a change made DURING a session - the scheduled job appending while the
  manager is open - not a session that started from a stale copy, which is what
  the session status is for

### Changed
- `wds()` no longer changes the working directory. It is called by almost
  everything, so a setwd() there moved the session's directory on every path
  lookup - which is how .Rhistory files ended up written into metadata/internal
- Both logs widen when a column is added. An append reshapes the new row to the
  existing header, so a new column was dropped silently on every run - `machine`
  would never have appeared

### Fixed
- The download resume point broke ties by end DATE alone, so every file fetched
  on one day looked equally recent and an arbitrary one was chosen. A second
  run in the same hour resumed from hours earlier and refetched readings
  already held. Ordered by the fetch stamp too, which has seconds in it
- Backup verification compares file names rather than counts, and names what is
  missing

---

## [v2.1.0] - 2026-09-28

The metadata review. `download_approved` is renamed and given a meaning it can
actually keep, plus a round of workflow polish driven by using the manager for
real field work.

### Added
- `metadata_approved` and `last_reviewed_utc` replace `download_approved`
  - The old flag was named for a job it no longer does. It was meant to stop
    an automated download filing data against a stale record - but a Product 1
    download applies no metadata at all, so the same file arrives whether the
    record is current or hopelessly out of date. Blocking it would forfeit
    data and protect nothing
  - What it actually asserts is that a HUMAN has confirmed the record matches
    what is physically out there. That matters at Product 2, where station
    identity and sensor depth get applied
  - The flag alone was never enough. TRUE says someone once confirmed the
    record; it does not say whether that was this morning or in March. The
    pair answers the question - how long since a human looked
  - The timestamp updates whether the answer is yes or no. "I looked and
    something is missing" is as much a review as "I looked and it is fine"
- Relocation handles a station moving AND its logger changing as ONE event.
  Logged as two workflows it produced a third row asserting the OLD device was
  deployed at the NEW position, which never happened
- Relocation asks about every station on the logger. What physically moves is
  a DEVICE, so relocating only the station that was named left a companion
  recorded at coordinates its own logger had left - one box in two places. A
  companion that did not travel is recorded as `removed`: its sensors came out
  while the logger went elsewhere
- Relocation asks whether every sensor moved with the logger, rather than
  assuming. A weather station can relocate while the soil profile it also
  served stays in the ground
- Establishing a station on a logger whose ports carry a type no station covers
  offers to set that station up too, inheriting the site, type and serial
  rather than asking for them again
- Watershed headings and station labels in every menu. `bta2_hydro (Adventure,
  "bta2a" / "bta2b")` - area, then device names in quotes, serial where a
  device is unnamed. vwc1/vwc2/vwc3 are arbitrary and say nothing about which
  station is which

### Changed
- The metadata review is asked LAST, after ports and any survey. Asking before
  them had someone confirm a record that was knowably incomplete
- Every Y/N prompt validates. Anything that was not `Y` or `1` used to mean no,
  so `15` typed at a port prompt silently skipped port configuration. `yes`,
  `no` and the spelled-out forms are accepted; anything else re-asks
- "Keep same status?" replaces "Change status?", so Y means nothing happened -
  matching the rest of the manager
- Stations whose every device is terminal are hidden from selection lists,
  except in 'Correct device details', which exists partly to reach those rows.
  Terminal devices are dropped from station labels for the same reason
- The port change summary shows the whole configuration, not only the lines
  that changed. What is being saved is the state of a device, and a list of
  three edits leaves the reader holding the other three ports in their head
- The role prompt explains what a role means per station type and no longer
  calls it "recommended", which is what invited `primary` when unsure
- Decommissioning says the distinction from `removed` is INTENT, not
  permanence: monitoring ends with no intention of resuming, and reactivation
  stays possible because nobody knows the future
- Port initialisation says to configure every port on the logger whatever
  station each sensor belongs to - the workflow runs inside a question about
  one station while configuring a device that may serve two
- Backup verification compares file NAMES rather than counts, and names what
  is missing. The two lists were built differently, so a source containing any
  directory warned that files were missing when none were
- `download_log.csv`: `timestamp` becomes `timestamp_utc`, and reading times
  are project-local. A reading belongs to a place with a recorded timezone; a
  run timestamp belongs to a moment and could be triggered from anywhere

### Fixed
- A terminal transition no longer clears the approval. That was right when the
  flag gated downloading, but a relocated row's record is accurate and frozen -
  and its archived data still has to be attributed. Clearing it would block
  that on the strength of the device having since moved
- Approving a station no longer touches its terminal rows, which would re-date
  a relocated deployment's review to today
- `relocate_station()` did not date the review it recorded, so a relocated row
  inherited a review date from before the move
- The companion station created after a shared-logger setup was left
  unapproved while the station that led there was approved twice
- Device roles cleared where they carry no meaning. `primary` means the
  downstream logger of a hydro pair, or the vwc station sharing a weather
  station's logger - ten rows had one that meant neither, including three
  separate stations at Limetree labelled primary, secondary and tertiary

---

## [v2.0.0] - 2026-09-28

Data products. Raw readings are now organised by DEVICE rather than by station,
and move through numbered products that are each derivable from the one below.

BREAKING: the raw data layout, filenames and `download_log` schema have all
changed. Anything written against the previous structure will need updating.

### Added
- `zentra_download_functions.R` - ZentraCloud v5 downloads producing Product 1
  - Devices are discovered from the API, not from metadata. A logger reporting
    to ZentraCloud that VI-FLO does not yet know about is still downloaded -
    an admin oversight should not become data loss
  - Each device resumes from the latest reading already held: its Product 1
    files, then the parsed backfill exports, then its first measurement. This
    is how the backfill and the API meet without a gap or an overlap
  - Takes a `key` throughout, so a second ZentraCloud account is a second call
    rather than a redesign
- `tools/backfill/parse_zentra_exports.R` - reads the September 2026
  full-history exports, 26 devices and 2.3 million timestamps reaching back to
  2021. Kept for audit: the exports are the source of record and this is how
  they were read
  - Configuration numbers are not chronological, and each configuration has a
    different column layout - so the output is long rather than wide
  - Timestamps are local EXCEPT where the logger had no timezone set, which
    the export records as `UTC Offset = Not Set`. Those are UTC. Read as local
    they land four hours out and appear to overlap the configuration that
    follows. Confirmed on z6-13388, where correcting it turns an impossible
    overlap into a smooth battery decline across an afternoon's installation
- `device_serial` in `download_log.csv`. A Product 1 download has no station,
  so the serial is what identifies it
- Validation: a download row must name a station or a device. A blank station
  is no longer an error - it is what a Product 1 row looks like
- `area` on the UVI soil moisture stations groups them as one experiment.
  Campus work is many and short-lived where field stations are few and
  long-lived, so numbering alone would give `uvi_vwc27` within a few years

### Changed
- Raw data reorganised into `internal/raw/device-data/`, split by manufacturer,
  with each instrument's source artifacts beside the readings derived from them
- Product 1 filenames carry the serial, the data range and when it was fetched:
  `z6-12874_20260925_20260928_20260928T090359_raw.rds`. A station name in a
  filename is an attribution, and attributions can be wrong
- `build_raw_filename()`, `parse_raw_filename()`, `list_raw_files()` and
  `check_raw_overlap()` all work by device or by station. Overlap is checked
  against the DEVICE's own record, which is the more correct question anyway
- HOBO ingest writes Product 1: serial-only filenames into `device-data/hobo/`,
  with the temp export named for the device rather than the station
- `zc_get_readings()` rather than `zc_sync()`. zc_sync returned nothing for
  windows where zc_get_readings returned thousands of readings, and did so
  SILENTLY - reporting success while fetching nothing. For a job that will run
  unattended that is disqualifying

### Removed
- The seventeen station files downloaded through the v4 API in January 2026.
  They baked port depths into column names, so a correction to a port's
  recorded depth silently invalidated them - which had already happened at
  uvi_vwc1, where two ports both claimed 10 cm and one overwrote the other.
  Every station they covered is covered by the exports, eight months later

### Fixed
- `zentra_ports.csv` for z6-13368 (UVI): four depths were shifted by one
  position and every port carried the wrong installation date. Corrected from
  the export's configuration history and from response lag to 49 rainfall
  events - port 6 wets within the hour, port 5 responds to three events out of
  49 and then a day late. The sensors are buried and cannot be checked by hand
- Adding a device to an existing station inherited coordinates from the
  station's FIRST row rather than its current one, so a device added after a
  relocation landed at the old position
- `elev` is correctable, and correcting coordinates offers a fresh lookup

---

## [v1.1.0] - 2026-09-12

Elevation and paired-logger survey. A stream gauge's hydraulic slope is now
derivable from stored metadata alone, and the workflows that could invalidate
a survey - relocation, replacement, removal - clear the values that no longer
describe reality rather than leaving them to mislead.

### Added
- `elevation_functions.R`
  - `lookup_elevation()` resolves a coordinate to a ground elevation, trying
    USGS 3DEP first and falling through to Open-Meteo where USGS reports no
    coverage. USGS returns 1 m lidar for the US Virgin Islands, Puerto Rico,
    Culebra and Vieques; Open-Meteo covers everywhere else at roughly 90 m,
    so the British Virgin Islands are reachable
  - No new dependency: `jsonlite` is used where present, with a regex
    fallback otherwise. A parse that fails returns NA and the caller falls
    back to manual entry
  - USGS signals "outside the United States" by returning -1000000 rather
    than an error, and "not on land" by returning 0. Both are caught
- `elev_source` column in `device_metadata.csv`, recording WHICH dataset a
  value came from and at what resolution - `usgs_3dep_1m`, `open_meteo`,
  `gnss`, `dem_manual`, `surveyed_relative`. Without it a +/-5 m estimate and
  a surveyed value are indistinguishable
- `ui_prompt_elevation()` in station establishment. Looks up automatically
  while the coordinates are still on screen, names whichever source answered,
  and accepts a typed value instead. A failed lookup prints the URL
- `tools/migrations/migrate_fill_elevations.R` - added `elev_source` and
  filled 35 existing devices from USGS 3DEP, all at 1 m resolution

- `reach_length_m` column - distance from a secondary or tertiary hydro logger
  to its station's primary, measured ALONG THE CHANNEL. With it, hydraulic
  slope is derivable from stored values alone:
  `(secondary elev - primary elev) / reach_length_m`
- The elevation survey now requires reach length alongside the elevation
  difference, and shows the resulting slope before saving. A survey without a
  distance cannot produce a slope, and realistically nobody measures one
  without the other. A slope outside roughly 0.0001 to 0.1 asks for
  confirmation - that range covers essentially every real stream reach, so
  anything beyond it is usually a decimal slip
- `invalidate_pair_geometry()` - relocating, replacing or removing half a
  paired gauge clears the survey values that described the old positions, and
  says which. Moving the PRIMARY clears both loggers' elevations and the reach
  length, since the secondary's was measured against a position that no longer
  exists; moving a secondary clears only its own. A wrong slope is worse than
  a missing one - a missing one announces itself, a wrong one silently biases
  every discharge value computed from the reach
- `ui_prompt_elevation()` now runs wherever coordinates are entered:
  establishment, relocation, and reactivation at new coordinates
- `tools/migrations/migrate_add_reach_length.R`
### Changed
- A `secondary` or `tertiary` hydro logger is never given an elevation
  automatically, by lookup or by inheritance. Its elevation is the primary's
  plus a surveyed difference, and that difference is what hydraulic slope
  uses - a DEM value there would be the difference between two samples of a
  raster, and an inherited one would make the difference exactly zero
- The confirmation summary when adding a device shows elevation and its
  source, so the value being approved is visible at the point of approval
- `DATA_DICTIONARY.md` documents `elev` and the `elev_source` vocabulary,
  including that `surveyed_relative` inherits its absolute accuracy from the
  primary while being millimetre-accurate relative to it
- `README.md` records the Open-Meteo attribution required under CC BY 4.0

---

- `survey_dual_logger_elevations()` sets the secondary's `elev_source` to
  `surveyed_relative`, which nothing was doing, and scopes its writes by
  station rather than by serial alone
- Reactivating a station at its ORIGINAL coordinates carries the old
  `elev_source` with the elevation, rather than leaving the value unlabelled
### Fixed
- `relocate_station()` built the new row as a copy of the old device, so a
  relocated station carried the OLD location's elevation to its new
  coordinates. For a paired station the geometry invalidation caught it; for a
  lone gauge nothing did
- Reactivating at NEW coordinates left elevation NA with no prompt, so every
  station reactivated at a new location started without one
- `update_device_location()` matched on serial with no status or station
  filter, so a new location could be written onto a closed historical row -
  moving a station that never went anywhere
- A `secondary` or `tertiary` hydro logger added to an existing station
  inherited the primary's elevation, which would have made the pair's
  elevation difference exactly zero

---

## [v1.0.0] - 2026-08-31

First release. The metadata manager is feature-complete for single-user work:
every workflow has been exercised against real field data, and the metadata
schema is settled. Breaking changes get a major bump from here.

This release does NOT claim multi-user safety. `device_metadata.csv` is a
file, not a database, and nothing prevents two people editing it between
syncs. That work is planned for v1.1.

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

- `close_specific_ports()` retires named ports, where `close_device_ports()`
  retires everything on a device
- Decommissioning asks about the sensors belonging to the retired station, not
  just the device. A shared ZL6 stays on site for its other station, but an
  ATMOS that exists for the weather station usually comes off with it - asking
  only whether the logger came out was the wrong granularity
- Relocation sets the old row's `last_visit`. Moving a station is a visit, and
  `update_last_visit()` deliberately skips relocated rows - correct for a
  routine visit, wrong for the visit that did the relocating
- `last_visit` is set when a device is created. Establishing a station on a
  date means somebody stood at it on that date
- `tools/migrations/migrate_backfill_last_visit.R` - fills blank `last_visit`
  from the maintenance log rather than from `deploy_datetime`, which for
  pre-VI-FLO rows may be the earliest archived record rather than a visit
- `close_specific_ports()` retires named ports, where `close_device_ports()`
  retires everything on a device
- Decommissioning asks about the sensors belonging to the retired station, not
  just the device. A shared ZL6 stays on site for its other station, but an
  ATMOS that exists for the weather station usually comes off with it
- Reactivating a station whose sensor was removed detects that the logger has
  active ports but none of that station's type, and offers to record the
  sensor there. Full initialisation would overwrite the other station's
  configuration, so it routes to the per-port workflow instead
- `ui_update_ports()` accepts a device, so a workflow that already knows which
  logger it is acting on does not ask again
- `save_device_metadata()` - one function writes `device_metadata.csv`.
  Nineteen call sites previously repeated the same six lines, and two of them
  had drifted: `api_functions.R` and `set_download_approved()` formatted only
  three of the datetime columns because they predate the others. That is how
  `last_record_date` came to be written as a Unix epoch
- `get_device_row()` resolves a serial to ONE row - active rows preferred,
  narrowed by station where the caller knows it. A serial does not identify a
  row: it can carry a terminal row plus its successor, or two active rows
  where one ZL6 serves two stations. `initialize_ports()` was reading
  `deploy_datetime` from an arbitrary one and stamping every port with it
- `ui_prompt_functions.R` - the shared prompts, split out from the workflows
  so an existing prompt is easy to find. Five near-identical download-approval
  prompts once existed because it was not
- Validation checks pending data tasks: the station must exist, and the stage
  must be one the workflow can resume from. Deliberately NOT checked is whether
  the device is still active - a station can be decommissioned while data
  offloaded from it has yet to be archived, and the pending row is then doing
  its job
### Changed
- The duplicate-serial check now matches `validate_metadata()`: one active row
  per serial PER STATION TYPE. A serial active at a different station type is
  legitimate and is confirmed rather than rejected. Corrected in both the UI
  and `add_new_device()`, which each held their own copy of the rule
- `suggest_station_id()` falls back to the numbering convention of the station
  TYPE where a site has no precedent, so the first vwc station at a site is
  suggested as `_vwc1` rather than a bare `_vwc`

- `update_device_status()` matches on serial AND active status, optionally
  narrowed by station. A serial does not identify a row: one can carry a
  relocated row plus its successor, or two active rows where a single ZL6
  serves both a weather and a vwc station. Matching on serial alone would
  restatus all of them, overwriting closed history or dragging a second
  station along
- Terminal statuses clear `download_approved` in the same write, covering
  every transition at once rather than leaving each workflow to remember
- All five download-approval prompts replaced by one shared function that
  explains what the question means. It had drifted into five wordings, and the
  cloud-upload branch was setting the flag from whether data had reached the
  cloud - a different question entirely. `apply = FALSE` for callers building
  a row that does not exist yet
- `get_active_ports()` takes a station type. "Does this device have active
  ports?" is the wrong question for a shared logger: a weather station
  reactivated on a box whose vwc ports are open but whose ATMOS came off would
  be told its ports were fine
- Relocation uses the declared status list, so `local` can be recorded for a
  station moved out of cellular range
- `remove_device()` takes the first ACTIVE row for a serial rather than the
  first row, which may be closed history
- `update_ports()` versions each port separately. It previously detected that
  ANY port had changed and rewrote all six, which wrote a configuration-change
  event for the other station's sensors on a shared ZL6 - a discontinuity that
  never physically happened
- `get_current_port_config()` builds its result by PORT NUMBER rather than by
  position. With one port closed there are five active rows, and returning
  them sorted shifted every later port up by one: port 2's sensor displayed as
  port 1's, and callers indexing 1:6 ran off the end
- `update_station_status()` clears `download_approved` on terminal statuses.
  This was added to `update_device_status()` only, so station-level
  transitions - decommissioning - were missed
- The device list in `ui_update_ports()` shows one entry per SERIAL, excluding
  terminal rows. Ports belong to the device, and a shared ZL6 was appearing
  three times: its decommissioned row, its other station, and its reactivated
  row
- The ingest temp file is named per DEVICE, not per station. At a paired gauge
  an abandoned export sat waiting to be picked up by the next logger, where
  the serial check rejected it as "the wrong .hobo file" - which is not what
  had gone wrong
- `metadata_manager_functions.R` reorganised into labelled sections and then
  split three ways: core logic joins `metadata_functions.R`, shared prompts
  become `ui_prompt_functions.R`, and the workflows and menu keep the original
  name. Every function body is byte-identical; only their homes changed
- `ui_survey_elevations()` reports a failed `last_visit` write instead of
  passing silently
### Fixed
- `ui_update_ports()` referenced `metadata` after it had been moved inside a
  conditional branch
- Relocation wrote `download_approved` before the move was confirmed, and onto
  the row about to go terminal
- The prompt after routine maintenance conflated "I also did something else"
  with "I picked the wrong workflow", and offered to delete the entry for
  both. Doing maintenance and a port change on one visit is normal
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
