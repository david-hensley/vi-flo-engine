# Roadmap

Open work, with where it came from and what it is waiting on.

This file exists because the list was living in session transcripts and in
recollection, which meant rediscovering it each time — and carrying at least
one item that had never existed. Anything genuinely finished is deleted rather
than struck through; `CHANGELOG.md` is the record of what was done.

Last reviewed: **2026-10-18**

---

## Versions ahead

Engine versions follow the product ladder. The dataset release that gets
cited - a DOI, its own station list - is numbered separately, on its own
clock.

- **v2.8** - Product 2 built for the whole archive and kept up to date by the
  weekly job
- **v2.9** - the metadata in git, so every version is a commit and any
  product can be rebuilt exactly as it was. Before Product 3, whose decisions
  rest on the metadata (see *Metadata into git* below)
- **v3** - Product 3 automatic and unattended: QC under declared parameters,
  gap filling by declared rules, and the first derived series, level, from
  Product 2 pressure and the barometric pairing table
- **After v3** - the computed variables beyond level (discharge, storage and
  the rest), and v4, Product 4: the workflow for human decisions. Discharge
  sits here, resting on rating curves that are partly experimental

**Pin the weekly job to a release** once the engine settles. Today the job
pulls the newest commit, so any change under `code/functions/` makes every
Product 2 file stale and the next run rebuilds the archive - about twenty
unattended minutes. Pinned to a tag, day-to-day engine work stops touching the
products, bumping the release is the deliberate rebuild, and the manifest's
`engine` names a release rather than a passing commit.

---

## Before the next St Thomas trip

### The paired-logger survey

**The most time-critical item here, and it has been open since September.**

Three stations have a logger pair with no surveyed separation: Turpentine Run 1,
Dorothea, and Reef Bay's rebuilt pair - where RB-c, the tertiary, also wants
surveying against the primary. Without a reach length and a fall, a pair
produces no hydraulic slope, which is the whole reason the second logger is
there.

The method and the workflow now exist (v2.6.0): a builder's level and rod for
the fall, at two or more independent setups agreeing within 10 mm, and the
TruPulse in horizontal-distance legs for the reach. Bethlehem Adventure 2 was
the first surveyed this way, on 14 October.

The loggers at Turpentine Run and Fish Bay also fill their memory around
3 November, so the trip has its own deadline.

### Turning points, if a reach ever needs them

The rod workflow assumes one instrument setup sees both rebars. A reach too
long or too bendy for that needs turning points, which breaks the pair
structure. Not built, deliberately: until such a reach exists, the fall is
measured some other way and typed in meters, with a note saying how. Build it
only when a real survey needs it.

---

## Ponds

Windsor (`srl1_pond`) and Hermitage (`bt1_pond`) were registered on 17
October 2026: U20-001-01 loggers, launched 13 May at 15 minutes, which fill
their memory around **Christmas Eve**. The first download is the deadline for
everything here except the last item.

- **The ingest path.** Product 0 and 1 are keyed by device, so a pond logger
  should go through the HOBO import like any U20 - but nothing has ever sent
  a `pond` station or a U20-001-01 through it. Audit each place the code
  special-cases `hydro` before that download, not after
- **Barometric pairing.** Both ponds are on St Croix, so in the STX zone. They
  need declared sources like any gauge, and the pairing table has only ever
  held hydro stations
- **Hermitage's survey.** Its elevation is a 3DEP lookup at coordinates taken
  before the RS4, and if the pond held water when the lidar was flown in late
  2018, it is the water surface rather than the bed. Survey it and record it
  through the single-device survey, as Windsor was
- **Stage to volume.** A water level becomes stored volume through a
  stage-volume curve from the bathymetry - a parameter set, as a rating curve
  is for discharge. Product 2 and beyond; the bathymetry is still being
  collected
- **Surface temperature loggers.** Many and short-lived, so not stations:
  their readings go to Product 0 and 1 like any logger's, and their positions,
  depths and in-water times to a campaign record beside `device_metadata.csv`,
  attributed through it at Product 2. Designed when the ponds hold water


### Role is time-varying, and metadata cannot say so

`device_role` records what a logger is now. Fish Bay's pair inverted in
February 2024 — the upstream logger came out and went back in downstream — so
for 2021 to 2023 both rows read `secondary` with no primary. SR1's HOBOlink
was primary until Backup went in, then secondary, with no new row.

Less pressing since October 2026: Product 2 keys a level logger's series by
deployment, not role, so roles only matter to whatever later combines
deployments into a station's level or discharge - and that work is still
experimental. A role history file was built and withdrawn the same day. If a
derived product needs past roles, the maintenance log and the dossiers hold
them. Barometric pairing and reach length have the same shape.

Survey geometry is the clearest case. A survey describes a pair at a moment,
and a re-survey overwrites the metadata. For now that is deliberate: the
maintenance log records every survey with its old and new values, and the raw
readings sit in Product 0, so the history is complete - it is just not
queryable from metadata. Decided 14 October 2026; revisit if a product ever
needs the geometry that applied on a past date.

### Barometric pairing

The scheme is designed and written up in the README: a declared pairing per
station, with validity periods and a priority order, so a fallback when a
weather station dies is deterministic rather than runtime cleverness.

What does not exist is the file itself, or a prompt in the metadata manager
asking for a pairing when a station is established. `site.correspondence.csv`
in the prototype archive recorded this; nothing in VI-FLO does yet.

### `decommissioned` and `removed` overlap in practice

Both describe a station or device that has stopped. The dictionary separates
them — `removed` is a device out of the field with the station standing,
`decommissioned` is the station itself ending — but the usage drifts. Worth
either tightening the definitions or collapsing them.

### `archive/` versus `device-data/`

The top-level split encodes immutable against regenerable, which is the most
consequential property in the system — it determines what is backed up
carefully, what is versioned, and what a migration has to preserve.
`device-data` names something true but secondary: that it is keyed by serial.

`archive/` + `products/` says what the distinction actually is. The cost is
that it is vaguer about what is inside, which `device-data` tells you at a
glance. Raised, not decided — and worth settling before the move to Hugging
Face rather than after, since the layout travels with it.

---

---

## Where the archive lives

Sketched on 7 October and never written down. Three things move, four
decisions remain.

### Three things move

**Metadata to a git repository.** Small CSVs, slow-changing, every change
meaningful. Git gives history, conflict detection instead of silent
overwrites, and a place a runner can both read and write.

**The archive to a Hugging Face dataset.** Product 0 and Product 1 — 441 MB
when measured, more now. Free, versioned, CDN-backed.

**The scheduled job to GitHub Actions.** All R; the workflow file is YAML.

### Four decisions

**Credentials.** The ZentraCloud key, a GitHub token for the metadata
repository, a Hugging Face token. All in repository secrets, which is
straightforward — but it is the first time secrets exist outside one machine.

**Write conflicts, which shapes the rest.** The runner writes metadata
weekly; the metadata manager writes it from a desk. If both happen between
syncs, git will say so, which is the point — but somebody resolves it. The
question underneath: does the runner write metadata at all, or only the
archive and its logs?

**Versioning cost.** Per-download files keep git-lfs storage linear rather
than quadratic, which was the reason for the current naming. Hugging Face's
free tier has limits worth checking before committing to it.

**The local copy.** A scheduled pull from Hugging Face and git, so the archive
exists on hardware under your control rather than only on someone's server.
This is the one job worth keeping once the cloud one works — and it is
insurance, not a download.

### What Box becomes

Box is currently the only off-machine copy, and `rclone` is the only thing
keeping it current. Whether it stays as a third copy, or retires once the
archive is on Hugging Face, has not been decided.

### The query tool is the seed of this

A function taking station, variable and period and returning the data is the
same function a web request calls. Written as a pure function with a thin
wrapper, it moves to a Cloudflare Worker unchanged — which is what makes
`.csv.gz` the right storage format, since nobody has to open one by hand.

---

## Product 2

### Metadata into git - v2.9, before Product 3

Product 2's manifest says whether a file was built from the current metadata
- each row holds fingerprints of what decided it - but cannot recover the
metadata of an older build, except by searching the backups. Moving
`metadata/internal/` into a git repository, as *Where the archive lives* has
it, makes every version a commit: the manifest gains one column, the metadata
commit, and any product can be rebuilt exactly as it was. Do this before
Product 3, whose human decisions will rest on the metadata.

### HOBOlink level is recomputed, not carried

A HOBOlink export holds the station's own computed water level alongside the
raw pressures. VI-FLO recomputes level from pressure so every station derives
the same way. Product 2 carries HOBOlink's own as `hobolink_level`, a check;
the derived `level` waits on the barometric pairing table.

### A query tool for `products/`

A function taking station, variable and period and returning the data. It
removes the objection to storing `.csv.gz`, and it is the same function a web
request would call later.

---

## Product 3, undesigned

Level to flow. Gauge zero flow. Flow measurement ingest. Rating curves as
time-varying calibrations. Water level as a terminal product in its own right.
QC decisions stored separately from the data they describe. Publish as
distinct from backup.

### QA reads the maintenance log

A `maintenance` entry naming a known fault bounds a window that Product 3
should flag — the maintenance log is the only place in metadata that can do
that. The six-month rule belongs here too: a station unvisited for more than
six months is suspect, because a clean correction record can mean a
well-behaved station or an unwatched one.

### Gauging data

The FlowTracker sets — `.dat`, `.dis`, `.sum`, `.ctl` quartets — have never
been ingested. Two questions: whether `discrete/hydro/flowtracker2/` becomes
`gaugings/` with an instrument column, since some early measurements were not
FlowTracker2; and what a gauging record actually needs to hold.

Deferred until Product 3, deliberately.

---

## Metadata manager

A wishlist from September, with the cheap items already folded in.

- **`port_note`** for experiment ports, where depth does not identify a
  sensor. Schema, migration and a prompt.
- **Relocate-and-replace as one event.** Relocation should ask whether the
  same device is going to the new position.
- **A path for co-located stations** on an existing logger.
- **Establishing an already-decommissioned station.** Turpentine Run 2 was
  entered by migration in October 2026 precisely because no such path exists.
- **Sensor serial in `zentra_ports.csv`**, from what the API already reports.
- **`last_visit` is set even when nobody visited.** A desk confirmation should
  not move it.

### The monthly review

`last_reviewed_utc` exists and nothing prompts a review. The only way to record
one is to log a maintenance entry, which means inventing a field visit.

A review tool would present each station with what is known about it and record
a judgement without fabricating history. Designed in September, never built.

---

## Operations

### Automatic status for an unreachable logger

A ZL6 that has not been contacted for some threshold should move to
`nonresponsive` on its own, and back to `online` when it reports. The
downloader already knows which devices it failed to reach, and
`print_network_todo()` already computes days since last reading. At present
this is noticed by eye and changed by hand.

### A download that finds nothing still writes a file

Raised in the September audit. Worth confirming whether it is still true.

### Subscription expiry is typed by hand

`expiry_date` is entered manually. Whether the ZentraCloud API exposes it was
never established — `exempt_reason` is a column that was never looked at and
might carry the free trial.

### Email before a logger fills its memory

The memory check computes the date. Sending a reminder was blocked on GitHub
Actions not being able to see metadata in the data root, which may no longer
be the constraint now that the job runs on a desktop.

---

## Engineering

### Workflow tests for the rest of the metadata manager

The suite (October 2026, `tests/`) drives workflows with scripted answers and
checks what they leave in the metadata and logs. So far it covers the paired
and single-device surveys. Still walked by hand, and so still the gap raised
on 7 October: establish, relocate, replace, remove, decommission, reactivate,
correct details, port changes, and the co-located cases that have caused the
most trouble historically. Each one becomes a test the next time it is
touched, rather than all at once.

### Multi-user

Shelved on 1 October — *"not forget it, but its not top of list anymore."*

The read-only flag, `last_modified` and `last_modified_by`, force pull before
write and push after, savepoint before pulling, Box versioning, row IDs and
origin on both logs.

Underneath it is a real question: a folder of CSVs has nothing arbitrating
concurrent writes, and whoever saves last wins. The answer is either a database
or a convention strict enough to stand in for one. It becomes urgent the day a
second person writes metadata.

### maint-logger to the GUI

Raised three times in September, parked each time.

### Smaller

- Zentra cable export instructions are still a placeholder
- A field-notes transcription helper, deferred and undesigned
- Rename the `backup` named path, which means two things at once

---

## Field and QA

### Streambed to measuring point at every gauge

When this is done, read `docs/backfill/LEVEL_CORRECTIONS.md` first: the
prototype's level offsets at SR1, SR2, Fish Bay and Dorothea, and the only old
sensor heights on record.

`sensor_height_cm` exists (October 2026) and is blank on every stream gauge.
`elev` is the ground, and a water level becomes a water-surface elevation only
once the height of the logger's measuring point above the bed is added. On a
gut that is a few centimeters and has been ignored - but measure it at each
gauge on its next visit and record it with 'Correct device details', so
Product 2 does not have to keep ignoring it.

### The flat 10 cm sensor at `sr1_vwc2`

`z6-38174`'s shallowest sensor has produced sixteen distinct values across
3,246 readings and did not move when 30 mm of rain fell on 6-7 October 2026.
Its counterpart at Salt River 2, the same depth and the same storm, rose
0.106.

A contact problem, a cable fault, or genuinely dry hydrophobic soil shedding
water past the sensor. Needs a visit.

### Drought and hydrophobicity

Whether dry soil at several sites is shedding water past the sensors rather
than wetting. Bears on how soil moisture is interpreted across the drought.

### Four soil moisture boxes are dead and unvisited

`uvi_vwc3`, `bta2_vwc1`, `bta2_vwc2` and `fb2_vwc1`. All stopped between June
2024 and April 2025 and were found nonresponsive in March 2026. All on St
Croix and reachable. `fb2_vwc1`'s pit and sensors were in good order — only
the logger failed — so a replacement box would revive a four-year
installation.
