# CHANGELOG
All notable changes to the VI-FLO Engine project are documented here.

---

## [Unreleased]

### Added
- **`read_product()` and `browse_product()`: reading the products back, and
  looking at them.** `read_product(station, variable, from, to)` returns a
  station's variable across every year built, as one table; asked for
  `abs_pressure` at a hydro station, it returns every deployment's series
  together, each named by its device, so nobody need know a row id.
  `browse_product()` steps through a product one station and variable at a
  time, each over its full span - gaps as breaks, every deployment start
  marked with its device (loggers that went in on the same day sharing one
  line and one label), disagreements between downloads in red, a paired
  gauge's loggers on one plot, each slightly see-through so neither hides the
  other - with Enter, `b`ack, `n`ext station and `q`; or writes every plot to
  one PDF. Every value is plotted, the extremes included: they are Product 2
  as it stands, for Product 3 to deal with. Where one wild value flattens the
  rest, `z` switches to the bulk of the data - the middle 99.8%, anything
  beyond drawn as an orange triangle at the edge it passed and counted in the
  title - and `z` again switches back. Both take a product number, so Product 3
  will read and browse the same way. Four years of a paired gauge read and
  draw in about a second and a half. In a file of their own, outside what a
  Product 2 build reaches, so adding them rebuilt nothing

### Changed
- The ROADMAP notes that ZentraCloud's v5 API reports subscription status
  and expiry, which the to-do list could use in place of the typed date
  dropped in v2.9 - and that ZentraCloud keeps only 914 days of
  measurements, so the archive is the only copy of anything older
- The ROADMAP puts local stations first in what is left of v2.10: the to-do
  list will notice a local station that is reaching ZentraCloud again and
  suggest setting it back to online, and a manual download will check
  ZentraCloud for the offloaded data rather than ask whether it was uploaded,
  since a phone offload uploads by itself. A manual download of a logger
  shared between two stations, or a change to its status, will offer to
  apply at both, and the metadata
  manager's view menu will show the surveys as it does the other tables. A
  sensor surveyed below the bed will stop showing on the to-do list as
  unsurveyed
- The ROADMAP plans coordinates on every Product 2 row for v2.10, so a
  relocated station's readings say where each was taken - and, in the same
  rebuild, `pressure` renamed `air_pressure`, so the barometer's reading is
  never mistaken for a water-level logger's `abs_pressure`
- `run_tests()` runs the test suite: `start.R` defines it, so `start.R` is
  the one line to remember. The long `source()` still works, and GitHub's run
  is unchanged

## [v2.9.0] - 2026-11-22

The structural release. Every table is read and written through one data
layer, and a change of several saves is kept whole or not at all, refused if
it would leave the metadata with a problem it did not have. Surveys are their
own table, each a distance between two named points. Deployments end, and
close their ports, when their loggers leave. One rule names a device
everywhere. Unattributed readings are explained once and stay explained.
Every metadata manager workflow was walked through on a copy of the real
metadata and is now an end-to-end test, and Product 2 was rebuilt and checked
by hand once all of it was in.

The spent v2.9 migrations, and the two left from v2.8.1, are deleted; the
migrations README lists what each did.

### Added
- **A data layer: one way into and out of the metadata tables.** Until now
  each function that needed a table read and wrote it itself, choosing its own
  folder, date format, quoting and missing-value marker - and when one chose
  wrong, only that path broke, usually silently: a port deletion written to
  the working directory, a log row appended by position into the wrong
  columns. `table_functions.R` describes every table once, in `TABLE_SCHEMA` -
  its columns in order, their types, its key and who writes it - and three
  functions do the rest: `read_table()`, `write_table()` and `append_rows()`.
  A table is always written the one way: text quoted, a missing value as an
  empty cell rather than `NA`, numbers never in scientific notation, Unix line
  endings. A write is refused if the file changed since it was read, backs up
  the table first - logs included, which `backup_metadata()` skips - and lands
  through a temporary file, so a crash cannot leave half a table. A value that
  will not read as its column's type is an error naming the row, never a
  silent `NA`. Nothing uses the layer yet: this adds it, with its tests, ahead
  of moving each reader and writer onto it
- `table_round_trip()` and `check_all_tables()`: every table read and written
  back to a temporary file, its values compared by meaning and its bytes
  compared too. The first write of a table through the layer normalizes its
  formatting once - the existing files mix `NA` with empty cells, quoted with
  unquoted rows, and Unix with Windows line endings - and after that the
  bytes hold exactly
- `tools/migrations/check_layer_v2.9.R`: a record of every metadata table and
  every Product 2 file taken before the layer, and a comparison once it is in,
  to show the move changed nothing it should not have
- **`surveys.csv`: field measurements, each a distance between two named
  points.** A row reads as a sentence - "Dor-2025b's rebar top sits 237.5 cm
  above Dor-2025a's rebar top" - with the points (`rebar`, `sensor`, `bed`,
  `ground`, `overflow`) named on both ends, so a survey is recorded against
  whatever it was actually measured from rather than assuming the rebar. Two
  quantities, `height_cm` and `reach_m`; a negative height means below.
  Anything not measured directly - a secondary's sensor relative to its
  primary's, which a slope needs - is chained from the rows by
  `survey_height()`, never stored, so re-surveying one link cannot leave
  another silently wrong. `survey_needs()` works out what each current
  deployment still lacks by station type. `validate_metadata()` checks every
  row reads as a distance between two points, in the fixed vocabularies, on
  loggers that exist
- `tools/migrations/migrate_surveys_v2.9.R` (step 4.5a) creates the table:
  the weather mounting heights and Windsor Pond's sensor height from
  `device_metadata.csv`, and the field surveys as measured - October 2026's
  four pairs and RB C from the TruPulse files, bta2's rod survey of 14 October
  2026, and SR2's gauge of zero flow from the prototype rating curves, carried
  to the current logger in the same housing. Every pair's chained fall is
  checked against the fall the maintenance log recorded. The surveys from
  before October 2026 are not carried forward. The device table's
  `sensor_height_cm`, `reach_length_m` and surveyed elevations stay until the
  workflows move onto the new table

- **Surveys can be removed when entered by mistake**, from the field survey
  menu. A measurement that was simply repeated needs no removing - the newest
  stands - so this is for the wrong logger, a typo, a duplicate. The removal
  is logged as a `metadata_deletion`
- `tools/sandbox.R`: try any metadata manager workflow on a throwaway copy of
  the real metadata. `sandbox_start()` copies every table and the gut survey
  files to a temporary root and points the session at it; `sandbox_changes()`
  shows what the workflows did to the copy; `sandbox_end()` returns to the
  real data and deletes the copy
- `tools/migrations/migrate_device_surveys_v2.9.R` (step 4.5b) takes
  `sensor_height_cm` and `reach_length_m` out of `device_metadata.csv`, after
  checking every value is in `surveys.csv`, and gives each secondary its
  primary's elevation in place of the primary's-plus-a-fall

- **The test suite runs on GitHub on every push** -
  `.github/workflows/tests.yml`, on a clean Linux machine with only the
  fixtures, so it catches a step where the tests were not run by hand, and
  anything that works only on one machine. A failure marks the commit with a
  red cross and emails whoever pushed it. `tests/run_tests.R` now ends in a
  failing exit status when run as a script and a test fails
- **Every save is checked before it is made.** A save to a table a person
  writes - the device table, ports, surveys, the maintenance log, pending
  tasks - runs `validate_metadata()` on the table as it would be, and is
  refused if it would ADD a problem, naming the check and the rows, with
  nothing written. A problem already there does not stop a save, or one bad
  row would lock every workflow, the one that would fix it included. The
  checks that look at the disk are left out of this; they are about the
  archive, not the table being written
- **A port's window must lie inside its deployment's.** `validate_metadata()`
  flags a port row starting before its deployment or ending after it, so the
  save check refuses a new one. `tools/migrations/migrate_port_windows_v2.9.R`
  (step 7b) clips the existing ones to their deployment's dates, listing each
  first; one lying wholly outside stops it for a decision by hand. Readings
  were only ever taken inside both windows, so Product 2 is unchanged
- `with_metadata_change()`: several saves made as one checked change.
  Retiring a logger, relocating a station, changing a station's status and
  deleting a row each pass through a state that is not valid halfway - a row
  ended with its ports still open - so their saves are checked once, at the
  end, and if the change would add a problem every table is put back as it was
- **Validation at session start and in the job.** `start.R` and the metadata
  manager launcher print one line - "Metadata valid (40/40 checks)" or the
  problems by name. The download job writes the same to the run log's
  message. Neither ever holds anything back

- **Explain unattributed readings**, a metadata manager entry on the main
  menu. It offers what is waiting to be explained - loggers VI-FLO has no row
  for, on the ZentraCloud account or only in the archive, and the unexplained
  periods the last builds found, their logger, ports and dates filled in -
  and records each in `known_unattributed.csv` with a reason, as a checked
  save. A build now saves what it left unexplained in `unexplained.csv` (a
  machine-written table) for this to offer. Whatever stays unexplained stays
  on the to-do list and in the report, so the file keeps up rather than
  drifting. `validate_metadata()` checks every row names a logger, gives a
  reason and covers a sound period
- **`known_unattributed.csv` gains `archive`**: for a whole logger, whether
  the download job keeps archiving it. A logger on the account that is not
  VI-FLO's, recorded with `archive` FALSE, is no longer downloaded.
  `tools/migrations/migrate_known_unattributed_v2.9.R` adds the column,
  TRUE on every existing whole-logger row
- **A device goes by one name everywhere.** Four helpers each chose a
  logger's name a little differently; `device_display_name()` now does it
  by one rule - its metadata name (its current row, or the row at the station
  asked about), else its ZentraCloud name, else its serial - and
  `device_label()` shows it as "Glynn weather (z6-12866)", leaving the serial
  off a name that already carries it. The metadata manager and HOBO archiving
  name devices this way in the fifty-odd places that printed a bare serial,
  maintenance-log text included; prompts about a serial being typed, and
  filenames, keep the serial alone. The to-do list's name column is wider
- **New devices take their ZentraCloud name.** Adding a ZL6, or the logger a
  relocation brings, offers the name ZentraCloud already has for it: Enter
  takes it. `tools/migrations/migrate_device_names_v2.9.R` fills blank names
  in existing rows the same way, and lists the rows it cannot name
- **The sync tool runs the Box orphan sweep.** `tools/orphan_sweep.R` gains
  two modes for VI-FLO Tools (v2.2.0) to call after an engine push: `--list`
  looks and deletes nothing, and `--delete <token>` deletes only if it finds
  exactly what `--list` found - a build or pull in between changes the token,
  and the delete refuses. Run by hand, it asks as before. Every check and
  deletion stays in this script
- **The README, ROADMAP and contributor guide describe v2.9.** The README no
  longer says Product 2 is unbuilt, and lists the packages the engine really
  uses (`zentraR`, `jsonlite`; not `dplyr` or `ggplot2`). The ROADMAP drops
  what v2.9 finished, points field work to the to-do list, and opens with
  what remains before the tag. The contributor guide, a generic git tutorial,
  is rewritten around how work here happens - VI-FLO Tools, `start.R`, the
  sandbox, the tests, migrations - and the rules the code depends on
- **The project timezone is written once.** `"America/Puerto_Rico"` was typed
  out 31 times across 12 files beside `PROJECT_TZ`; every one now uses the
  constant, and a test fails if the literal appears again in live code
- **Dead code removed**: `regularise()` and `find_gaps()` (superseded by
  Product 2's grid), `forget_file_hash()`, `get_unique_action_types()`,
  `set_record_confirmed()`, `set_named_path()`, `is_metadata_valid()`,
  `print_violations()`, and the retired station-keyed branches of
  `list_raw_files()` and `check_raw_overlap()` - nothing called any of them.
  Comments that described the old behavior - deployment ends derived from
  the next row, station-named Product 1 files - now describe the current one
- **An unknown maintenance action type is a validation problem.** It was a
  note in the long printout and counted for nothing. An action type not in
  `MAINTENANCE_ACTIONS` - a name a migration missed, a typo from editing the
  file by hand, a workflow writing a type nobody added - is now
  UNKNOWN_ACTION_TYPE
- **Savepoints retired.** `save_metadata_state()` and `revert_metadata_state()`,
  with `backup_restore_functions.R`, are gone, and with them the session
  line comparing the metadata to its savepoint. The sandbox
  (`tools/sandbox.R`) does what they were for - trying things on metadata
  without keeping the result - on a copy, where a revert could not roll
  back months of work. The per-table backups taken before every session's
  first save remain, and keep history a savepoint never did
- Two validation checks removed that could no longer fire: datetimes stored
  as an epoch, or not in ISO form. The data layer refuses both on reading
- **An elevation from the global fallback is offered for a second try.**
  When USGS cannot be reached, the coarse global model still answers, and is
  still kept if wanted - but the prompt now says so and offers to try USGS
  again, and the to-do list's METADATA REVIEW lists any current station
  whose elevation came from it until it is looked up again. No test can
  reach either elevation service
- **Paths relative to the data root are cut as text, in one place.**
  `path_relative_to()` replaces six copies that used the root folder as a
  pattern - which a name holding `(` or `+`, or a Windows backslash, could
  break, and one of which did not normalize slashes at all
- The unfinished-tasks list names each task's device as well as its
  station: a paired gauge can have two offloads in flight
- **A status change offers the working statuses only.** Ending a deployment -
  removal, replacement, relocation, decommissioning - is a workflow that
  dates the end, closes the ports and logs it; `update_device_status()` now
  refuses a terminal status rather than flipping one without any of that,
  and the prompt no longer offers typed-in statuses. `update_station_status()`
  is decommissioning only: its other branches rewrote a whole station's
  retired rows along with its current ones
- **Adding a device is one change**: the row and the sensor height measured
  as it went in, kept together or not at all
- **One "who is logging" prompt.** Six workflows carried their own copy;
  all use `ui_ask_whois_logging()`
- A field time can be typed without seconds: `2026-11-03 14:30`
- **Tests can no longer reach ZentraCloud.** Every call the engine makes to
  the API now goes through one function, `zc_call()`, and the test suite
  closes it for its whole run (`options(viflo.offline = TRUE)`), whatever
  key the machine holds. A test fails if a `zentraR::` call appears anywhere
  else in `code/` or `tools/`. Found when a new workflow test fetched the
  real device list on a machine with a key, offering real loggers in place
  of its own
- **Readings after retirement are recognized by rule.** A logger with no
  current deployment anywhere, reporting after its last one ended - in a
  shed, an office - is AFTER RETIREMENT in the build's report: one line,
  counting its readings and naming each logger, rather than UNEXPLAINED on
  every build

### Changed
- **Setting up a new site asks less and suggests more.** Areas are only
  those already used in the chosen watershed, and sites only those in the
  chosen area. A new site is asked for by its number, and offered its name -
  "St. George Mint 1" - and an abbreviation worked out from its neighbors'
  - sgm1, after sgm2 - each to accept or change. Models are only the chosen
  manufacturer's, with the depth range beside the HOBO models that look
  alike: U20-001-01 (30 ft), U20-001-04 (13 ft). The confirmation shows the
  device's name, model, role, interval and time zone
- **A new ZL6 with weather and soil sensors could not save its ports.**
  Each port is recorded against the station its sensor serves, and the
  second station was only offered after the ports were saved - so the save
  failed for want of it, and the station was never offered. It is now
  offered before the save, with the ports it explains named; the two are one
  change. Declined, those ports are left unrecorded, said so, and the rest
  saved. The companion is no longer asked whether the logger serves a second
  station, having just said so, and both stations are reviewed in one
  review. Third end-to-end test
- **A step that failed inside a change could skip putting the tables
  back.** `return()` inside a `with_metadata_change()` block returned from
  the whole workflow, not the block - so the change never finished, nothing
  was put back, and the caller got a bare value where it expected a result
  ("$ operator is invalid for atomic vectors" on adding a device). Those
  blocks now return from themselves
- **A device role is offered only where it means something.** A hydro
  station offers primary and secondary, a vwc or weather station primary,
  and a pond none; a role already held at the station is not offered again,
  and the role is always chosen from the list, even when one is left. The list had been
  every role ever recorded, which put rb2's tertiary - not an arrangement to
  repeat - in front of every new device. Second end-to-end test: a paired
  gauge, established and then given its secondary
- **A new device and its log entry are one change.** The installation note
  and who is logging are asked before the save rather than after, so a
  device is never recorded without the entry saying when and why it
  arrived. The entry names the device. First end-to-end test of
  establishing a station
- Correction entries name the device - "lat of bta2a (22357376): ..." - so
  two at a station of several loggers can be told apart; a rename's names
  it as it was. A corrected terminal status is chosen from the list, without
  the current one, rather than typed and then refused. Enter at a
  coordinate leaves it unchanged
- **Every correction is logged.** *Correct device details* logged only a
  rename and a corrected terminal status; a corrected deploy time, interval,
  coordinate or elevation changed the record with nothing to say it had. Each
  is now a `metadata_correction` entry reading "field: from → to", saved
  in the same change as the value, so a correction is never kept without its
  entry. Who is logging is asked once per session of corrections
- **A corrected deploy or end time takes its ports with it.** Port
  configurations that began when the device went in, or ended when it came
  out, move to the corrected time; left behind, the sensors would appear to
  start before the device existed. A retired device's end time can now be
  corrected, and a deploy time after its end is refused before anything is
  saved
- **A port change is logged at each station whose sensors changed, saying
  how** - "port 6: TEROS 10 @ 100cm → empty" - rather than once, at the
  first station on the logger, as "Port configuration updated". The new
  configuration and its entries are one change
- **Viewing ports lists deployments, by device name and station.** Picking a
  device is by name too, and a ZL6 serving two stations shows a block for
  each
- **Logging maintenance is one change.** The entry, the visit date, a status
  change and a relaunch's new name or interval are saved together or not at
  all; the relaunch questions come before the confirmation, which shows
  everything the entry will save
- **Reactivating a station and recording a paired survey are each one
  change.** A reactivation could add its device and fail to set its
  position, leaving a row at no location; a paired survey could assign roles
  and then fail to save the survey behind them. Either now keeps both or
  neither. A reactivation's log entry is part of the change too - who is
  logging is asked first - and names the device it came back with, where,
  and the one it last ran on. First end-to-end test of a reactivation
- **A station reactivated somewhere new is shown there.** The device step
  showed - and its confirmation summarized - the old position, inherited
  from the station, before the new one was written over it. It now shows the
  new position and elevation throughout. The new coordinates are checked
  against the Virgin Islands as elsewhere
- **A reactivated station on a shared ZL6 can take its old sensors back in
  one answer.** The sensors it had when it was retired are listed, and if
  they went back on the same ports - still free on the logger - they are
  recorded from the moment the station came back - and offered the same way
  when it comes back on a fresh logger. The shared-logger question
  names the station rather than asking about "a new station". End-to-end
  tests of all three reactivations
- **`validate_metadata()` refuses a swap that overlaps its successor**
  (`SWAP_OVERLAP`): a replaced or relocated row ending after the row that
  took its place - same station, same role - began. The migration below
  corrected the nine there were; this keeps a tenth from being saved. A
  paired gauge's two loggers, with two roles, overlap as they should.
  `SUCCEEDED_STATUSES` names the statuses that leave a successor
- **A reading stamped exactly at a swap is no longer reported as
  unexplained.** A deployment's window runs up to its end and not through
  it, while the report's "after retirement" began just after the end - so
  the old logger's reading at the moment it came out belonged to neither,
  and was listed on its own (Dorothea Weather and R2R Farm, one moment each,
  after the correction below). The category is now "out of the field": a
  logger's readings from the moment a deployment ends until its next one
  begins, or for good after its last - the shed, the office, the desk
  between stations, which the old rule left unexplained for any logger
  deployed again later
- `tools/migrations/migrate_day_end_placeholders_v2.9.R`: retired rows that
  were replaced or relocated and ended at 23:59:59 - "sometime that day", as
  those workflows recorded it before v2.9 - on the day their successor went
  in, end at the successor's deploy time instead. Until then the two
  overlapped for the rest of that day, the old logger reading as still
  deployed after it had come out: its readings were attributed to the
  station, or belonged to nothing (Dorothea Weather, 29 October, corrected by
  hand when the rebuild reported it). Ports that closed later that day -
  stamped when they were entered, not when the sensors came out - close then
  too. Removals are left alone: a logger going in elsewhere that day is not
  when the removed one came out. Each row is logged as a correction
- **A logger back in service keeps what it is.** Entering a serial whose
  every row has ended takes its manufacturer and model from its last row,
  and offers its last name on Enter, rather than asking for all three again
  - a reactivation on its old logger had left it unnamed. A station
  reactivated where it was, with no elevation on record, has one looked up
  then. The sandbox's change list names a device by its serial when it has
  no name, rather than "NA"
- **Who is logging is asked again on a slip.** Anything but 1, 2 or Enter
  was taken as DAH without a word, putting the wrong initials on the record;
  initials must be three letters
- **Replacing a device is one change**: the new device, the old one's
  retirement, the surveys carried over and the log entry are saved together,
  so a failure partway no longer leaves two devices active, or none, or a
  replacement nothing logged. The replacement takes the role of the logger
  it replaces - which, still current while the new one is entered, had been
  read as taken. The log entry says how many surveys were carried. First
  end-to-end test of a replacement
- **A shared ZL6 replaced at one station is replaced at both.** Replacing
  the logger at a weather station left its vwc station on the old box, with
  its ports closed - recorded as still running on a logger that had left.
  The new logger now takes over at every station the old one served, each
  getting its own row and its own log entry, all in the one change
- **Relocating a station is one change, and asks what changed at the new
  spot.** The move, the old row's visit date and the log entries are saved
  together - and every station that moved on the same logger gets its own
  entry, not only the one named. The time of the move is checked like a
  removal's: not in the future, not before the deployment it ends. The
  sensor height at the new spot is asked and recorded against the new
  deployment, since the old one's no longer holds. A replacement logger
  brought in on the move is offered only its manufacturer's models, with
  their ranges, and the summary shows the new elevation and height and no
  ports for a HOBO. First end-to-end tests of a relocation
- **A station left behind by a relocation is logged as removed**, at that
  station, saying its logger moved and its sensors came out. Its row was
  ended with nothing in the log to say why. Its sensors are listed as
  staying behind rather than asked about again, and only the sensors moving
  with the logger are in question
- A relocation of stations sharing a logger asks for one metadata review,
  which offers the others, rather than reviewing each twice
- `start.R` loads the sandbox, so `sandbox_start()` needs no `source()`
  first
- **Coordinates outside the Virgin Islands are questioned.** Entering a
  new station or a relocation, a latitude or longitude outside 17-19 N,
  64-66 W - a dropped minus sign, the two swapped - is shown and asked again
  unless confirmed, as corrections already did
- **A replacement ZL6 can take the old one's sensors in one answer.** The
  old logger's ports as they were when it came out are listed, and if the
  same sensors went into the new one on the same ports they are recorded
  without being typed again - after a replacement, and after a relocation
  that brought in a new logger
- A typed time zone for a new device is checked against the zones R knows,
  and a slip at the time zone menu asks again rather than abandoning the
  device
- Device metadata view shows each device's name, and reads its logging
  interval from `interval_min` by name rather than through R's partial
  matching of `$interval`
- Unfinished data tasks are listed with the logger's name
- The port setup offered after adding a device and after reactivating one
  is one shared step, `ui_setup_ports_after_add()`, where the two copies had
  drifted apart
- The download log's date filter reads `timestamp_utc` as a date in the
  project zone, and its branches for column names the log has not had since
  v2 are gone
- *Existing station work* prompts "Enter selection:" like every other menu
- **Product 2 rebuilds only when the code it runs changes.** A station-year
  was stale whenever anything in `code/functions` had been committed since it
  was built - so a change to the network status or the metadata manager
  rebuilt every station-year, for hours, to identical files. The manifest now
  records `code_fingerprint`: `build_p2()` and every function and value it
  reaches, followed through their bodies wherever they are defined, plus the
  variable registry, fingerprinted by meaning so that comments and layout do
  not count. `p2_code_changed_since()` and `P2_CODE_PATHS` are gone. The
  first check after this finds every station-year stale once, since none has
  a fingerprint yet
- **The build's unattributed report lists only what is unexplained.** Known
  periods - already explained in `known_unattributed.csv` - and readings
  around installations - a deployment settling in, set aside by design - are
  one line each, counted, rather than listed in full on every build. The
  report itself is left out of the code fingerprint (`P2_NOT_OUTPUT`): how it
  reads decides nothing a build writes
- **A station-year built and found empty is recorded.** One with no readings
  attributed to it - fb2_vwc1 in 2025 and 2026 - left no trace in the
  manifest, so it read as "not built yet" for ever. It now gets a manifest
  row, variable `(nothing)`, with the same fingerprints as any build: current
  until its inputs change. A gap stays a gap, and nobody has to declare it
- **The to-do list is the one list of what needs attention, field work then
  desk work**, each half in its own box. Field: not reporting, battery, HOBO
  memory, surveys outstanding, known broken. Desk: ports not configured,
  metadata review, and three sections new to it - VALIDATION, every problem
  `validate_metadata()` finds with the rows it is about; PRODUCT 2,
  station-years that would rebuild and files on disk the manifest does not
  list (`p2_unlisted_files()`); and NOT IN METADATA, loggers on the
  ZentraCloud account or in the archive that VI-FLO has no row for, shown by
  their ZentraCloud name with the serial after - except any recorded in
  `known_unattributed.csv` as wholly unattributed. Station-years stale only
  because the Product 2 code changed are counted in one line rather than
  listed one by one. SURVEYS OUTSTANDING now lists
  every survey a current deployment lacks, sensor heights included, not only
  a pair that cannot give a slope
- **A retired logger going quiet is no longer listed as not reporting.**
  Silence is what a retired logger should do
- **The HOBO memory note says what its fill date assumes.** A logger whose
  last file ran faster than recorded reads "fills 28 Dec 2026 - 36 days, if
  still at 10 min as in its last file (15 recorded)": the cautious date,
  without claiming the logger is still set that way
- **The network status keeps the cloud's date and the archive's apart.**
  "contact" is now "cloud contact" - the newest reading ZentraCloud holds -
  and "data to" is "archived to" - the newest reading downloaded into the
  archive - with the battery between them, so the two dates are never read
  as one. That confusion is how a station looked as if it thought it was
  still 20 November
- **The network status and the to-do list name devices** by the name each
  carries at that station, falling back to the serial only where there is
  none
- `orphan_sweep.R`'s header gave its own name as "oprhansweep.R"
- **The statuses are written once.** `ACTIVE_STATUSES`, `TERMINAL_STATUSES`
  and what each status means, `STATUS_MEANINGS`, live together in the data
  layer; the 21 copies of the terminal list spelled out across six files are
  gone, and the status menus print the meanings from the same place. A test
  now fails if a status list is written out anywhere else
- **A relocation no longer moves a station's retired loggers.** It treated
  every row that was not decommissioned or relocated as current - so a
  removed or replaced logger at the station would have been given a new row
  at the new position too. One of the hand-written status lists, and the
  reason the rest are gone
- **The metadata manager acts on the row chosen, not on a row found again by
  serial.** Removing a device removed "the first active row" of its serial -
  on a ZL6 serving two stations, whichever came first. A removal is the box
  coming out of the field, so `remove_device()` now ends every deployment the
  logger was serving at that moment, and the workflow says first which other
  station goes with it - and stops, pointing to decommissioning instead, if
  the logger actually stayed on site. *Correct device details* found its row
  by serial, station and status, which two `relocated` rows of one logger at
  one station would both match; it uses the row's `unique_id`. Replacement,
  removal, the paired survey's role assignment and the after-adding checks
  of a station's type likewise take the row chosen, or the station it was
  chosen at. Undoing a mistaken maintenance entry looks only at the
  logger's deployments at that station
- **A deployment's ports close by deployment, not by logger.** Retiring a row,
  relocating a station with a new logger, and decommissioning a station each
  close the ports of the deployments that ended - never every port on the
  logger, which on a shared ZL6 closed the other station's too. The
  decommission workflow no longer asks which loggers came out of the field
  or which sensors came off: a port row belongs to one deployment, so the
  answer follows. `close_deployment_ports()` replaces `close_device_ports()`
  and `close_specific_ports()`
- **The check for open ports on a retired device is per deployment.** It
  looked at loggers whose every row had ended, so a relocated logger's old
  deployment could keep open ports unnoticed while the logger ran on at the
  new one
- **Product 2's change detection is scoped by deployment.** A station-year's
  fingerprint covers its own deployments and their ports, plus another
  station's only where the same logger serves both at the same time. A
  logger's deployments elsewhere, before or after, no longer count - every
  ended deployment carries its own end - so a change at sgm2 no longer flags
  Reef Bay, where its logger once was. The first build after this rebuilds
  every station once, to identical files
- The HOBO ingest takes the device name and the logging interval from the
  deployment serving at the station on the day, not from the logger's first
  row
- `logging_interval()` is gone: nothing called it
- `sandbox_changes()` shows the device table's changes too, field by field,
  as well as the survey rows and log entries
- "Do something else?" on leaving a metadata manager task takes 'q' for no,
  as every other prompt does
- `start.R` no longer lists every function file as it loads - one line says
  how many loaded. `load_all_functions(each = TRUE)` lists them
- **Retiring a row sets its terminal status and its end in the same save.**
  They used to be two, and between them the row was ended but current, or the
  reverse. `retire_row()` takes the status; the replacement and removal
  workflows use it. `update_device_status()` given a terminal status now ends
  the deployment too
- **Deleting a row takes its ports and surveys with it, and logs the deletion
  in the same change.** The question about the ports is gone: left behind,
  they would point at nothing. Log entries about a deleted row stay - the log
  is never rewritten - and the checks accept them, since the deletion entry
  says the row is gone
- **Correcting an elevation in *Correct device details* corrects the whole
  pair** at a paired gauge, which carries one elevation
- **Every survey workflow writes `surveys.csv`, recording what was actually
  measured.** The paired-gauge survey records each logger's rebar top above
  its sensor and the upstream rebar top above the downstream one, from the
  rod readings, and the reach; a fall typed by hand asks which points it was
  measured between - rebar tops, sensors, or not recorded - and how. The
  sensor-to-sensor fall and the slope are shown chained from the rows, never
  stored. The single-device survey becomes two: a measured height between any
  two points, on this logger or another at the station - asked as which two
  points, which is higher, and by how much, so there is no direction to get
  backwards - and ground elevation by GNSS. A
  new device's sensor height, asked as it goes in, becomes a survey row; the
  standard 200 cm on a weather station is recorded as `nominal`
- **A replacement offers the old logger's surveys to the new one, one at a
  time.** A logger in the same housing with the rebar untouched sits where
  the old one sat; each measurement confirmed as still holding is copied with
  `carried_from`, and the chain treats a carried point as the same point - so
  a secondary surveyed against the old primary still chains to the new
- **A paired gauge carries one ground elevation, the primary's, on every
  logger.** A secondary's elevation is no longer the primary's plus a fall:
  the fall is in `surveys.csv`, where it was measured. The primary's value is
  copied rather than looked up again - a new logger at the station inherits
  it, a GNSS survey of any of them updates them all - so DEM noise can never
  put a few centimeters between rows describing one place. `validate_metadata()`
  checks they agree. `surveyed_relative` is gone from the elevation sources
- Relocating, replacing or removing a logger no longer clears the pair's
  survey values. Surveys belong to the deployment they were measured on, so a
  new deployment simply starts without them; `invalidate_pair_geometry()` is
  gone
- `sensor_height_cm` is no longer a field in *Correct device details*; a new
  measurement is entered as a survey
- **The orphaned-file check recognizes a duplicate whose dates are a day
  off.** The September 2026 full-history exports left three copies beside the
  logged files under names from when filename dates were taken in UTC - a
  late-evening reading rolled over to the next day - and the check only paired
  files with identical dates, so it reported them as unaccounted for. It now
  also pairs the same logger and fetch stamp with each date within a day, and
  compares the readings themselves where the bytes differ.
  `remove_duplicate_orphans()` can then clear them, locally and on Box
- **The network to-do's survey check reads `surveys.csv`.** A paired gauge is
  listed when its sensor cannot be chained to its primary's or it has no
  reach to it - the two things a slope needs - where before it looked for an
  elevation and a reach length on the device row
- **Every loader now reads through the data layer** - `load_zentra_metadata()`,
  `load_zentra_ports_data()`, `load_download_log()`, `load_maintenance_log()`,
  `load_record_confirmed()`, `load_pending_ingest()`,
  `load_known_unattributed()`, and the run log at session start. Each returns
  what it did before, value for value, checked against the live tables; the
  only type change is that measurements which can be fractional - sensor
  height, port depth - are numbers rather than integers. What is new is that a
  value a loader cannot read stops it with the table, column and row, where
  before it quietly became `NA`. A table edited by hand into an unreadable
  state now says so at the next session start rather than being read wrongly
- The ports, download log and maintenance log loaders each used to read the
  device table as well, only to take its time zone - and in doing so
  refreshed what the session remembered of `device_metadata.csv`, so a change
  made underneath a session could slip past the write guard. They no longer
  touch it

- **Every write of the device table goes through the data layer.**
  `save_device_metadata()`, which its 21 callers already shared, now hands
  the table to `write_table()`; the replacement workflow's one direct write,
  clearing an inherited elevation, now goes through it too. Run against a
  copy of the live table, seven of the workflows that write it - a visit, a
  download, a HOBO ingest, an approval, a status change, a retirement -
  leave values identical to what they left before. Two things are new. A
  value that is not its column's type - text in a number column, a date that
  will not read - stops the save with nothing written, where before it was
  written as it stood. And the table is backed up before the first save of
  each session, which it never was: what is kept is the table as it stood
  before the session touched it
- **Every log row goes through the data layer** - the job's download and run
  rows, the HOBO ingest's download row and every maintenance entry, through
  `append_rows()`; deleting the last maintenance entry, through
  `write_table()`. Checked against a copy of the live logs, they record the
  same values as before. A row is now refused, with nothing appended, when
  the log's own header is not its schema's - appended anyway, every value
  would sit under the wrong column, as the October 2026 HOBO rows did. The
  job's two loggers also lose the code that widened a log to fit a new
  column: a log's columns change only by migration, never by an append. And
  the job no longer reads the device table for each file it logs, only to
  learn the project's time zone
- **The rest of the writers go through the data layer** - every change to
  the port table (a new configuration, a port window closed, a retirement
  closing a logger's ports), `set_record_confirmed()`, and the pending-ingest
  table. Checked against copies of the live tables, they write the same
  values as before. Nothing in the engine now opens a metadata table but the
  layer, and a test holds it there: a table's file name may appear only in
  `TABLE_SCHEMA`, and only files that handle something other than metadata -
  the products, the datamap, logger and survey exports - may read or write
  CSV directly

- **The maintenance log moves to its v2.9 shape** - the first table to. Each
  entry names the deployment it concerns, by `unique_id`, rather than a
  logger's serial, which cannot say which of a logger's rows at a station is
  meant; `timestamp` becomes `logged_utc`, in UTC like every other record of
  when something was written; `station_type` and `ports_updated` go, the one
  repeating the station and the other used once in 178 entries; and
  `elevation_survey` becomes `survey`, since a survey now records more than
  elevations. `tools/migrations/migrate_maintenance_log_v2.9.R` converts the
  log. Product 2 never reads it, so nothing built changes
- A new entry still may be logged by serial: `create_maintenance_entry()`
  finds the deployment through the new `resolve_deployment()` - the logger's
  row at the station, and where it has several, the one serving on the day of
  the visit; on the day of a move, the new position. It reads the device table
  without refreshing what the write guard expects, so logging mid-workflow
  cannot mask a change made underneath. `station_type` and `ports_updated` are
  gone from its arguments and from its 16 callers
- The maintenance actions are listed once, in `table_functions.R`, split into
  those chosen by hand and those only a workflow writes. The validator reads
  that list rather than its own copy, and now checks that every entry names a
  deployment that exists, at the entry's own station

- **The download log and pending-ingest table move to their v2.9 shape.**
  The download log drops `station`, named on 26 rows of hundreds - a Product 1
  file is what a logger recorded, and which station a reading belongs to is
  Product 2's to decide - and gains `battery`, the logger's battery at the end
  of each file, which the job now records with each download. Rows before it
  are blank: the reading was never kept with the download, and is not
  guessed. A pending offload names its deployment by `unique_id`, and its
  `created` and `updated` become `created_utc` and `updated_utc`. The pending
  functions still take a station and a serial, and find the deployment as a
  maintenance entry does. `tools/migrations/migrate_logs_v2.9.R` converts
  both. The download log viewer finds a station's downloads through the
  loggers that served it, and the validator checks each logger the log names
  is in the metadata, where it checked a station column

- **The port table moves to its v2.9 shape.** Each row names the deployment
  its sensor serves, by `unique_id`, in place of a serial and a `type`: on a
  ZL6 shared between two stations, the ATMOS row names the weather station's
  deployment and the TEROS rows the vwc station's. The logger and the kind of
  station come from that deployment - `load_zentra_ports_data()` adds them
  back as `sn` and `type` for the callers that ask by logger, and
  `save_zentra_ports()` drops them again. The 71 placeholder rows for empty
  ports are gone: an empty port has no row. A port that spanned two
  deployments - Fish Bay Weather's ATMOS, through its 2024 move - is split
  where the second began. `tools/migrations/migrate_ports_v2.9.R` converts the
  table. Checked against the live table, every sensor Product 2 reads covers
  exactly the moments it covered before, so Product 2 builds the same files
- **A port can be `excluded`:** plugged in and recorded, never ingested. Its
  readings are set aside before attribution, neither placed on a station nor
  reported as unexplained. The seven ECRN-50 rain gauges on the early vwc
  loggers are the first, each attached to the deployment it was plugged into;
  a start date never known stays blank. Port statuses are listed once, in
  `PORT_STATUSES`
- **A move carries the logger's sensors with it.** Ports used to be left open
  on a relocation, being keyed by serial; now each open port closes at the
  move and opens again, unchanged, on the deployment the move created
  (`carry_ports_over()`). A new configuration writes each sensor against the
  logger's active deployment of its kind (`port_deployment()`)
- Deleting a metadata row deletes that row's own ports and no other's - the
  check added in v2.9's data layer, refusing to delete a shared logger's
  ports at all, is no longer needed
- The validator checks each port row names a deployment that exists, has a
  known status, and - unless excluded - a start

- **The device table moves to its v2.9 shape, and is written by a person
  alone.** It gains `end_datetime`, the moment each retired deployment ended.
  Until now that was worked out on every build - from the deployment that
  followed, or the end of the row's last-visit day - so a later visit could
  move it, and decommissioning set no date at all. Each retired row is given
  exactly the end Product 2 already used, except three the record shows
  otherwise: SR1 Hillside and SR2-HS v2, decommissioned on 4 September 2026
  but ending at the March visit before; and SR2 Hillside, replaced in January
  2024 but never ended. Retiring a row - removal, replacement, relocation,
  decommissioning - now writes the moment it happened. `battery`,
  `last_update`, `last_download_date`, `last_record_date` and `expiry_date`
  are dropped: the first four are worked out from the download log when
  needed (`deployment_activity()`), and the weekly job no longer writes the
  device table at all; the expiry date was typed by hand and had gone stale.
  `nonresponsive` is retired as a status - going quiet is something the
  network report already notices. `tools/migrations/migrate_device_metadata_v2.9.R`
  converts the table
- A visit no longer makes Product 2 stale: a deployment's end is its own
  column now, not its last visit
- `sgm2_hydro` no longer shows a last reading from 2025. What the archive
  holds for a deployment is now worked out from its own logger's files during
  that deployment, where it took every file with the logger's serial - its
  Reef Bay years included
- The network report names a retired logger still reporting by the station
  it last served, "(retired)", where it said "(not in metadata)"
- Statuses are listed once more: `ACTIVE_STATUSES`, beside the existing
  `TERMINAL_STATUSES`

### Fixed
- **Viewing every logger's ports stopped at a logger with none open.** A
  logger whose ports had all been closed - its sensors taken off at
  retirement - ended the listing with an error, as did a port with no sensor
  recorded. Both are now shown, or left out, as they should be
- **Maintenance at a paired gauge read the wrong logger's status.** The
  status offered for change was the primary's, whichever logger was chosen,
  so marking the secondary defunct compared against the wrong value
- **A relaunch stopped on a logger never named or never given an interval.**
  Comparing the new name with a missing one ended the workflow; a missing
  value is now read as different, and the rename is saved and logged
- **A maintenance action typed in was refused by validation.** The action
  menu accepted free text that `MAINTENANCE_ACTIONS` does not know, so the
  entry was refused at the save. Actions now come from the list only
- **A refused correction ended the workflow.** Since refused saves became
  errors, a correction validation refused left *Correct device details*
  entirely. It now says nothing was changed and returns to the field list
- **A coordinate correction's new elevation reached one logger of a pair.**
  The lookup offered after correcting a latitude or longitude set the
  elevation on the chosen row alone, which validation then refuses at a
  paired gauge. It now sets every logger that shares the elevation, and logs
  it - and is offered only for the primary, whose position the pair's
  elevation describes. A secondary's corrected coordinate leaves it alone
- **Removal accepted a time before the device went in**, or in the future.
  It now asks again, as decommissioning does
- **Replacement and reactivation were logged on the day they were entered**,
  not the day they happened. Both now take the date of the event
- A relocation that kept its ports could stop on a variable never set
- **A refused save could be reported as done.** `save_device_metadata()`
  returned FALSE when a save was refused - by validation, or because the
  file changed underneath - and eleven of its callers never looked: setting
  a location, a status, a visit or a review printed its check mark either
  way. A refused save is now an error, as it already was for the port table,
  and each caller reports it as a failure
- **A relocation that left a station's sensors behind could never succeed.**
  The station staying behind was marked `removed` but given no end, and its
  ports were left open - exactly what the save checks refuse, so the whole
  relocation was put back every time. It now ends at the move, its ports
  closing with it
- **A workflow that fails returns to the menu** rather than ending the
  metadata manager session, saying what stopped it. A test whose scripted answers run out still stops, rather than
  returning to the menu and asking again for ever
- **Year-old backups were deleted whenever a detail was corrected.** An older
  backup routine, `backup_metadata()`, still ran in *Correct device details*:
  it copied every table a second time and then removed every backup more
  than a year old from the shared folder, the data layer's own included. It
  is gone with its pruning; the data layer backs up before every session's
  first save, and nothing is pruned
- **A HOBO offload could overwrite an archived file.** A manual offload's name
  carries no fetch stamp, so the same span ingested twice - a re-export, a
  resumed task - was saved over the archived file and logged a second time.
  An identical file is now recognized as already archived and not logged
  again; a different one under the same name is refused, untouched
- **An offload archived but not logged counted as done.** If the download
  log could not be written, the ingest reported success and cleared its
  pending task, leaving an archived file nothing recorded. It now reports
  the failure and keeps the task open; resuming finds the file and logs it
- **HOBO exports are read in the zone they declare.** The ingest read an
  export's timestamps in the zone of the first metadata row, while Product
  2 read the same file in the zone its header declares (`Date Time,
  GMT-04:00`). Both now read the declared zone, through one helper, and the
  ingest says so when a file declares none. The archived file itself was
  never altered, and is not now
- **A change of several saves that failed partway kept its first half.**
  `with_metadata_change()` put the tables back only when the finished change
  would add a validation problem; a step that failed left the steps before
  it saved. Deleting a row could remove the row, its ports and surveys, fail
  to log it, and report "Row NOT deleted"; a relocation could retire the old
  rows and fail to create the new ones. A change is now all or nothing: any
  failure puts every table back as it was. A change after which the metadata
  cannot be checked at all is refused too, rather than let through
- **A Product 2 build that wrote nothing lost its report.** A station-year
  with nothing attributed - a retired station whose logger sat in a shed -
  returned no result at all, so `build_p2_stale()`'s end-of-run report
  silently left out its unattributed readings and skipped files. A build now
  always returns a table, empty when nothing was written, carrying both
- **A manifest row whose file had gone never cleared.** A rebuild pruned the
  manifest by the files it found on disk, so a row for a file already missing
  outlived it: listing a file that was not there, or - for a station-year no
  longer made - leaving it stale on every run. The manifest now holds exactly
  what each rebuild of a station-year made
- *Explain unattributed readings* hid an episode on several ports when a
  known period covered only one of them. A known row now explains only the
  ports it names
- **Decommissioning asks when the station was shut down.** It used the
  moment it was entered: its deployments ended then, its ports closed then,
  and its log entry was dated that day, however long before monitoring had
  actually stopped. It now asks, as removal and replacement do, refuses a
  moment in the future or before the station's current deployment began, and
  uses the answer for all three. First end-to-end test of the workflow
- The metadata manager's exit no longer asks about station photos after a
  session that logged no visit
- Explaining a logger that is only in the archive no longer says recording
  it unarchived "stops the job downloading it" - the job never did
- The test workflow uses actions/checkout v5, on the Node 24 runtime GitHub
  now requires
- `validate_metadata()` would have failed every run on loggers the download
  log names and the metadata does not - the colleague's loggers on the
  ZentraCloud account, and pre-VI-FLO loggers in the exports. They are now
  listed as a note, not a fault
- `start.R` stopped at its last step when a table could not be read - as
  `pending_ingest.csv` could not between installing v2.9's code and running
  its migration - and skipped the rest of the session's start. Listing
  unfinished offloads now reports the problem and lets the session finish
  starting, with the tools to repair it loaded
- `validate_metadata()` stopped with an error whenever it found a logged file
  missing, an unknown one, or an orphan. Listing them selected a `timestamp`
  column the download log has not had since it became `timestamp_utc` - it
  existed only through the loader's partial-matching accident, removed above
- **Deleting a metadata row could delete the ports of a logger's other
  rows.** Port rows are kept by serial, so "this device's ports" were every
  port the logger had ever had - an earlier deployment's, or a second
  station's on the same ZL6. While the logger has another row, the deletion
  now leaves its ports alone and says why
- **Deleting a metadata row's ports never reached the port table.** It was
  written to whatever folder R was working in, not the metadata folder, and
  the deletion reported success. It now goes through the data layer. A
  refused metadata save during a deletion also no longer reports the row as
  deleted
- `load_download_log()` returned an extra column, `timestamp`, four hours
  wrong. It parsed a column the log stopped having when it became
  `timestamp_utc`; R's partial matching of `$` quietly handed it
  `timestamp_utc` instead, read as local time. Nothing used it

---

## [v2.8.1] - 2026-11-19

### Changed
- **A new station on a logger that already has ports of its type is shown
  them and asked,** rather than told "Ports already configured" and moved on.
  Such a station usually means sensors were just plugged in - or, as at
  `dor1_vwc1`, configured a step earlier on the other station's workflow. The
  logger's ports are listed, and answering that they do not include this
  station's sensors opens the port update for that logger. On the new-station
  and reactivation paths alike

### Fixed
- **The HOBO ingest's download-log row landed in the wrong columns.** It was
  built without `run_id` and `device_serial` - added to the log after it was
  written - and appended by position, so every value after the station slid
  two columns left and `filepath` came out empty. The October 2026 trip was
  its first use since: all eight offloads were never seen as logged, and
  Product 2 skipped them, leaving dor2, tr1, rb2 and fb2 ending in March. The
  Product 1 files were never at risk. The row now carries both columns, and
  it and the maintenance log append through the new `append_log_row()`, which
  writes by column name and refuses a column the file does not have.
  `tools/migrations/migrate_hobo_log_rows.R` repairs the eight rows, each
  guarded on its exact shape, every other line left byte for byte
- The variable table drops *Unrecognized / Sensor Output*, the API's
  spelling of the full-history exports' *Unrecognized Sensor / Output* - reported once, at
  z6-30132's start in the Shadehouses in January 2025, and flagged as
  unrecognized on every Dorothea Weather file until now
- **Retired rows' dates were being moved, and with them their Product 2
  deployments,** which end at a retired row's `last_visit`. Three causes,
  found after the October 2026 St Thomas / St John trip:
  - a routine visit re-dated every row at its station except relocated and
    decommissioned ones - so removed and replaced rows took the visit's date.
    TR1's HOBOlink, destroyed 2024-08-14, came back into tr1_hydro, and five
    other long-removed HOBOs ran to October 2026. `update_last_visit()` now
    leaves every retired row alone
  - a replacement left the old row's `last_visit` at its previous visit, so
    Dorothea and Turpentine Weather ended at their March visits, losing seven
    months; and it closed the old logger's ports at `Sys.time()`, when the
    swap was typed in, days after it happened
  - removal relied on the first: it dated the removed row through the
    station-wide visit

  The new `retire_row()` dates a retired row and closes its ports at the
  moment its logger left - a removal's time, or its replacement's deployment -
  and removal and replacement both use it. `tools/migrations/migrate_retired_dates.R`
  repairs the 13 rows and 12 port windows affected, each guarded on the value
  it expects and edited in place, and records three known periods: z6-30132's
  Shadehouses 2025 record before Dorothea, the old Turpentine Weather logger
  still reporting, and the end of R2R Farm's storage-shed period
- **A maintenance note containing quotation marks wrote a broken row.**
  `write_maintenance_entry()` appended with `write.table()`'s default
  `qmethod = "escape"`, so a quote in `details` was written as a
  backslash-quote rather than doubled - not valid CSV, and the row then
  parsed wrongly. Every other log append already doubled its quotes; this one
  now does too. Found in two `ltt1` battery entries ("in \"device tools\"")
- The test that the build refuses uncommitted code assumed the engine would
  be uncommitted, and so failed on a machine fresh from a pull. It now sets
  the engine's state itself, and a companion test checks the other half: on a
  clean commit the build proceeds and the manifest names that commit
- **Removing a stale Product 2 file left its folder behind,** and the push
  carried the empty folder to Box - the `rh` folders after relative humidity
  was dropped. The build now removes any folder a stale file leaves empty
- **Logging a download failed for a logger that has served two stations.**
  `update_last_download_date()` matched every row with the logger's serial,
  so tr1slope (21652376), also TR2's decommissioned row, gave two time zones
  and R refused them: "invalid 'tz' value". Had it not, the download date
  would have been written onto the decommissioned row as well. It now writes
  only to the logger's active row at the station the download was logged
  against, and says so when there is none
- **Adding a station that shares a logger stopped before its confirmation.**
  On that path - a vwc station on a weather station's ZL6, `dor1_vwc1` on
  Dorothea Weather's - the device details are inherited and their questions
  skipped, and sensor height went with them: the summary then failed on
  "object 'sensor_height_cm' not found". Nothing was written, since the row is
  only added after confirming. Sensor height is now asked on that path as on
  the other - never inherited, and not asked for vwc
- **The catch-up prompt could not launch the job, again.** The fresh console
  that fixed `0xc0000142` in v2.5.1 stopped being enough on the desktop by
  November 2026: the prompt asked, and the job failed to start, though
  double-clicking the same batch file worked. The prompt now hands the batch
  file to Explorer, which starts it from the user's own session exactly as a
  double-click does, inheriting nothing from the hidden process that asked

---

## [v2.8.0] - 2026-10-19

Product 2 exists for the whole archive and keeps itself up to date. Every
station-year is attributed, deduplicated, on the network's 15-minute grid and
consistently named - 799 files built from 2021 on - and the weekly job
rebuilds exactly what has gone stale, unattended: its first run downloaded,
rebuilt the archive on one commit in eighteen minutes, and pushed. Building it
was also the first full audit of the metadata, and every reading it left
unattributed is now explained or listed for attention; along the way it
corrected SR1 Backup's deployment, found the plantain experiment's five
loggers, and separated ZL6 repeat records from download conflicts.

### Added
- **Product 2 in the weekly job.** After it downloads, the job runs
  `build_p2_stale()`, which rebuilds exactly the station-years out of date -
  never built; fed by a Product 1 file they were not built from, this week's
  or a HOBO offload ingested by hand; built from metadata or ports of their
  loggers that have since changed; built by Product 2 code that has since
  changed; or no longer made by the current inputs, in which case rebuilding
  removes them. A failure is reported and never stops the push to Box.
  `build_p2_stale(dry_run = TRUE)` says what it would do. A run prints its
  progress station by station and one report at the end - skipped files,
  unattributed readings, repeats, and what is worth a look - rather than a
  report per station
- **Products are only built from a commit.** `build_p2()` refuses while the
  engine repo has any uncommitted change, docs included, or cannot name its
  commit at all: a product must name the code that made it. The manifest's
  `engine` column is always a plain commit
- The manifest records every Product 1 file read for a station-year,
  `inputs`, beside `source_files`, the files its kept values came from - a
  download wholly superseded by a later one was read but not named
- `metadata_md5`, `ports_md5` and `registry_md5` become
  `metadata_fingerprint` and `ports_fingerprint`: fingerprints of only what
  decides Product 2 - which logger was where, from when to when - for the
  loggers deployed at that station that year. The weekly job writes battery
  and download dates to the metadata every run, and a whole-file hash would
  have rebuilt everything every week. The registry needs no fingerprint: it is
  in the repo, and the commit names it
- The backfill README records the plantain experiment's five loggers -
  confirmed from their records - and the dossier for SR1 records Backup's
  emergency placement of 2023-10-28 and its proper deployment on 2023-11-14,
  to which its metadata now dates it
- **`docs/backfill/LEVEL_CORRECTIONS.md`**: every level offset and sensor
  height in the prototype's import scripts - SR1's scour and reading
  corrections, SR2's backup offsets, the Fish Bay and Dorothea slope logger
  heights - for the day modern streambed-to-sensor heights are surveyed. The
  backfill README lists the unattributed readings explained so far and kept
  unattributed by decision
- **Unattributed readings, sorted three ways** in the build summary:
  UNEXPLAINED, KNOWN and AROUND INSTALLATIONS, each with the last 12 months
  first and newest first, one line per episode - a logger, a port where it
  matters, its variables merged and its moments counted once. Nothing is
  hidden; known periods and installation days are collapsed so only what is
  new asks for attention
  - KNOWN: periods in the new `metadata/internal/known_unattributed.csv` -
    logger, optional port, dates, reason - created by
    `tools/migrations/migrate_known_unattributed.R` with the eleven periods
    verified in October 2026. The port narrows a period, so UVI's retired
    port 2 cannot hide something new on its other ports
  - AROUND INSTALLATIONS: up to 7 days before one of a logger's
    deployments, or in its first 24 hours, before its sensors' port windows
    open - recognized without a row
  - One line per episode: a logger's ports merged (`ports 1-6, 8`), and an
    unexplained episode runs on until a week passes with nothing, so a logger
    reporting a few times a week from storage is one story, not four
  - SR2 Hillside's weeks in storage after its replacement in January 2024
    added to the known periods; the migration now adds any period the file
    does not hold and keeps the rest, including rows added by hand
- **`view_device()`**, in the new `inspect_functions.R`: everything a logger
  recorded over a period, one panel per variable and port, drawn in local
  time against its deployments and port windows - so whether unattributed
  readings were storage, testing or an unrecorded deployment is something to
  look at rather than guess. Drawn to a picture sized for its panels and
  opened, since eight stacked panels do not fit RStudio's plot pane and R
  refuses rather than shrinking them. `device_names_for()` gives every name and
  station a serial has had, and the build summary now groups unattributed
  readings under each logger with them
- **Product 2, piece 1: the variable registry and one reader for every
  Product 1 shape**, in `code/functions/product2_functions.R`
  - `data/variables.csv`: every measurement any logger in the network
    reports, keyed by source, SENSOR and measurement - an ATMOS 41 and an
    ECRN-50 both report "Precipitation", and they are not one series. Each
    row is kept or dropped, with its VI-FLO name, unit, and kind -
    instantaneous, accumulated, maximum or minimum, which decides how a finer
    interval reaches the 15-minute grid. Built from what the archive actually
    holds, checked across all 198 ZL6 files and the ports file. A plain CSV,
    to read and correct without R
  - Kept: the ATMOS 41 and 41 G2 measurements, the G2's interval maximum and
    minimum air temperature, TEROS 10 water content by depth, U20 absolute
    pressure and water temperature, the ZL6's own barometer as
    `logger_pressure` - a last-resort barometric source - and HOBOlink's
    pressure, temperature and barometer. HOBOlink's computed level becomes
    `hobolink_level`, never `level`
  - Dropped, and still in Product 1: diagnostics (battery, signal, logger
    temperature, tilt, RH sensor temperature), raw VWC, everything ZENTRA
    computes (VPD, dew point, reference ET, relative humidity - which the
    full-history exports do not even carry, so kept it would exist only from
    September 2026), the G2's drop counts, spoon tips
    and rain conductivity - noted as evidence for Product 3 rain QC - the
    ECRN-50s, deployed but their data judged unbelievable, and the TEROS 21,
    on no station's ports
  - `read_p1_long()` reads all four shapes - ZL6 in UTC, the full-history
    exports with their own column names and spelled-out sensors, U20 text
    with a declared offset, HOBOlink in local time - into one long form in
    UTC
  - `map_measurements()` names, converts and filters by the registry. Units
    arrive spelled several ways and are recognized; psi, degF and hPa are
    converted; an unknown unit stops the build rather than being guessed. A
    nonzero ZL6 error code empties the value but keeps the row. A
    measurement the registry has never heard of is reported, not silently
    lost
  - Pressure stays in kPa, the unit both the U20s and the ATMOS deliver
  - `variable_name()` in `attribution_functions.R` is gone. Its hard-coded
    translations - HOBOlink's level as `level` among them - were a second,
    contradicting answer to what a measurement is called, and nothing used
    it once the registry existed
- **Product 2, piece 2: deduplication across overlapping downloads**
  - Two downloads can hold the same moment - a re-run, a catch-up, an
    offload repeating the end of the last. `dedupe_readings()` keeps one
    reading per device, port, sensor, measurement and moment: the copy from
    the LATER FETCH. Where copies disagree on the value, the kept row is
    marked `conflict = TRUE` rather than resolved silently; a value against
    an empty copy is a disagreement, two empty copies are not
  - The fetch time comes from the download log's `timestamp_utc`, not
    `run_id`, because a manual HOBO offload has no run_id. A file the log
    does not know stops the build
  - `read_p1_set()` joins the first two pieces: read, map and deduplicate a
    set of Product 1 files, with one report of anything the registry did not
    know across all of them
  - A million-row station-year reads, maps and deduplicates in about six
    seconds: lookups run once per distinct sensor, unit and series rather
    than once per row, and the sort is on numbers rather than text
  - Tested on z6-38175's real duplicate pair from 1 October, which collapses
    to one copy with no conflict, and on a planted disagreement. Checked by
    making the earliest fetch win instead: four tests fail
- **Product 2, piece 3: attribution and the 15-minute grid**
  - `attribute_readings()` gives each reading its station, through the
    existing deployment and port windows, and names a depth sensor from its
    port at that moment: `vwc` on a 30 cm port is `vwc_30cm`. Readings that
    belong to no station - a logger before its deployment - are counted and
    reported, never forced onto one
  - A logger's own barometer, on an internal port no station lists, goes to
    the weather station where the logger serves one, so a co-located ZL6
    does not carry the same series twice, and otherwise to its one station
  - `align_to_grid()` brings each device's readings to the quarter hour by
    kind. Instantaneous: used as is on the quarter hour, otherwise
    interpolated between the readings either side if both are real and no
    more than 15 minutes apart - never across a gap, never from a series
    coarser than 15 minutes. Accumulated, maximum and minimum from a finer
    series: summed, highest or lowest over the 15 minutes ending at the
    quarter hour, only when every reading is present. Anything that cannot
    be aligned without inventing is reported
  - `p2_series()` lays each device's stint onto one continuous grid from the
    station's first reading to its last. A quarter hour nothing covers is a
    row flagged `missing` with no device; one the logger recorded without a
    usable value is `missing` with the device named
  - `assemble_p2()` splits by station, variable and the project-local year
  - Checked against the real loggers by hand: bta2b's 10:08:37 and 10:23:37
    readings give 101.6809 kPa at 10:15. Checked by mutation: interpolating
    across gaps fails four tests, allowing a partial rain sum fails one. A
    year of U20 or of 5-minute rain aligns in a fraction of a second
  - Fixture stations for the real loggers, and a fixture ports file
- **Product 2, piece 4: writing it**
  - `build_p2()` builds station-years from their devices' Product 1 files
    and writes every variable to
    `products/p2/<type>/<station>/<variable>/`, as plain local times,
    gzipped, written to a temporary name and moved into place
  - `products/p2/manifest.csv`: a row per file - observed and missing
    counts, conflicts, how each device was aligned, each device's declared
    interval against the one it actually logged, the Product 1 files that
    went in, the hashes of the metadata, ports and registry, the timezone,
    the unit, and the engine commit, marked `+uncommitted` when built from
    code that was never committed
  - A rebuild replaces a file and its manifest row. A file an earlier build
    made that the current inputs would not - a reading reattributed, a
    variable dropped - is removed with its row
  - The README now defines Product 2: attributed, deduplicated, on the
    15-minute grid, consistently named, neither judged nor invented
  - Checked by mutation: a build that keeps stale files fails two tests, a
    manifest that appends rather than replaces fails one
- Real Product 1 fixtures for the suite: bta2b's U20, the UVI ZL6 serving a
  weather and a vwc station at once, a vwc ZL6 fetched twice four minutes
  apart, a full-history export, and 400 rows of SR1's HOBOlink logger
- **A test suite**, in `tests/`, run by hand with `tests/run_tests.R` before a
  change is called good. The engine stays a folder of function files;
  `testthat` is the only new dependency
  - Every test builds a throwaway data root - its own datamap, fixture
    metadata and maintenance log - and points `VI_FLO_DATA_ROOT` at it, so
    tests save, back up and log freely without real metadata in reach
  - `with_inputs()` drives an interactive workflow with scripted answers, and
    fails if the workflow asks more questions than supplied or fewer
  - First tests aim at what has actually broken: metadata surviving a save
    and reload, datetimes never written as epochs, project-local dates in
    Product 1 filenames, writers touching one deployment rather than every
    row with a serial, the survey arithmetic against BTA2's real readings and
    TruPulse export, and both survey workflows end to end
  - Checked by reintroducing the per-serial write bug: two tests fail

### Changed
- **A paired gauge is no longer merged into one series.** The first full
  Product 2 build put both loggers of every hydro pair into one file, keeping
  only the later deployment's value wherever both had one - silently dropping
  half of dor2, fb2, rb2, sr1 and tr1. At hydro and pond stations each
  deployment is now its own series, named by its row in device_metadata:
  `abs_pressure_h-0021`. A logger moved within a station is two series, as it
  is two rows. Roles play no part - how deployments combine is decided
  later. The manifest names each file's deployments, serials and device names
- **Product files are filed by level, then station:**
  `products/p<n>/<type>/<station>/<variable>/<station>_<variable>_p<n>_<year>.csv.gz`.
  Each level has its own life - Product 2 rebuilt freely, Product 4 resting
  on human decisions, a release shipping one level - and within a level a
  station-year is what regenerates together. The name carries everything.
  Nothing had been written under the old variable-first layout.
  `variable_domain()` is gone: the station's type is the folder
- The test runner detaches `testthat` when it finishes, so it no longer
  masks functions such as `terra`'s `compare()` in the session

### Fixed
- **The suite could leave an R session pointed at a test's throwaway data
  root.** One test restored an option with a bare `on.exit()`, which replaces
  a test's other cleanup rather than adding to it - cancelling the step that
  restores `VI_FLO_DATA_ROOT`. The session then read fixture metadata until R
  was restarted; the real data root was never touched. The test now uses
  `withr::local_options()`, and `run_tests.R` guards behind every test: it
  refuses to start from a test's folder, and afterwards restores the data root
  and the suite's build option, saying so if a test left them changed
- **A replaced logger's barometer kept being attributed** to its station for
  days after its sensors had moved to the new logger, overlapping the new
  one's - at Cal1 and SR2 Hillside. A logger's own barometer now belongs to a
  station only while one of its ports is open there
- **Every conflict in the first full Product 2 build was a ZL6 writing two
  records with one timestamp,** not two downloads disagreeing. Three weather
  loggers - DiscoveryG, Fish Bay, R2R Farm - and the soil loggers write an
  extra record at 00:15 on scattered nights: consecutive record numbers in
  ZENTRA's own export, most likely the nightly clock sync measuring over a
  fragment of an interval. Deduplication kept the LAST record within a file,
  so it kept the extra one. It now keeps the first, the scheduled record, and
  counts repeats apart from conflicts: `conflict` again means only two
  downloads disagreeing. The manifest gains `repeats`, and `repeat_dropped`
  for any rain in a record set aside - 0.97 mm, once, at Fish Bay in five
  years
- **A logger removed and later redeployed was attributed through the months
  between.** `deployment_windows()` ended a row at its successor's start even
  when the row was removed long before - so 21179105, out of Fish Bay from
  October 2023 to February 2024, had its storage readings filed as Fish Bay
  data. A removed row now ends the day it came out, and the readings between
  are unattributed, listed in the build summary
- A manifest written before a column existed could not take a row carrying
  it, and the build stopped at once. Rows are now merged by column name, the
  missing columns left empty
- `build_p2()` flagged every logger whose actual interval differed from
  `interval_min` - five HOBOs logging at 10 minutes, among them. But
  `interval_min` is the target, not a claim about the logger, so the manifest
  now records the interval each logger kept without judging it, and the data
  dictionary says what `interval_min` is
- **A typed date and time without seconds lost its time.**
  `parse_datetime_flexible()` knew `2023-11-06 10:45:00` but not
  `2023-11-06 10:45`, which fell through to the date-only parser and came
  back as midnight, silently. Every metadata manager prompt that takes a
  datetime goes through it
- The first full Product 2 build stopped on a file the download log did not
  name: an old filename restored from Box beside its renamed, logged twin.
  `build_p2()` now builds only from files the log names - the archive of
  record - and lists any others it finds rather than stopping. Three such
  duplicates, byte-identical to logged files, were removed here and on Box
- `build_p2()` reads each Product 1 file once per run of station-years that
  need it, rather than once per year and once per station: a five-year
  export is read once per station, and a co-located logger's once for both
- Some HOBO Product 1 files carry the degree sign mangled by an encoding round
  trip, as "Â°C", which stopped the first real Product 2 build. It is now
  recognized, and an error mapping a file names the file
- `build_p2()` counted readings that belong to no station but never showed
  them. Its summary now lists them by device, port and variable with the
  dates they span, counting only each year's own readings and each reading
  once - a full-history export spanning five years, read for each, had been
  counted five times over. And a station is
  built only for years it was deployed in, not every year its logger has
  files from
- The reach arithmetic printed a stray space before a short first leg -
  `format()` pads every leg to the widest. Found by the new suite on its first
  run
- `README.md`'s Product 1 figure, "3.29 million readings across 282 files",
  was given as the size of the 2021-2025 import, which was 1.46 million on
  its own. It is gone rather than corrected: the archive grows every week, so
  any count in the README is stale by the next download.
  `validate_product1()` reports the current size

---

## [v2.7.0] - 2026-10-17

The network gains its first pond stations, Windsor (`srl1_pond`) and
Hermitage (`bt1_pond`), and the metadata gains what they needed: the height of
a sensor above the ground it is located by, a survey workflow that converts a
GNSS height to sea level, and the right model for every water-level logger.
Alongside, a gazetteer of VI-FLO's place names against everyone else's.

### Added
- **`docs/PLACE_NAMES.md`**, a gazetteer. It sets out the naming convention:
  a watershed is named for the gut at its mouth, its main stem carries that
  name to the headwaters, and tributaries become areas. It records why, and
  the three names that do not follow it. Then, watershed by watershed, it gives the
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
  - The two ponds: Windsor on Lebanon Gut, Lebanon becoming a Salt River
    area, and Hermitage in the headwaters of Bethlehem's main stem
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
- `README.md`: the gazetteer is listed in the repo layout, and the status
  is brought up to date.
- The three migrations below are applied, listed in
  `tools/migrations/README.md`, and their scripts deleted

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
