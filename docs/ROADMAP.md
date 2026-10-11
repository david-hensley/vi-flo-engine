# Roadmap

Open work, with where it came from and what it is waiting on.

This file exists because the list was living in session transcripts and in
recollection, which meant rediscovering it each time — and carrying at least
one item that had never existed. Anything genuinely finished is deleted rather
than struck through; `CHANGELOG.md` is the record of what was done.

Last reviewed: **2026-10-11**

---

## Before the next St Thomas trip

### The paired-logger survey

**The most time-critical item here, and it has been open since September.**

Four stations have a logger pair with no surveyed separation: Turpentine Run 1,
Dorothea, and Reef Bay's rebuilt pair. Without a reach length and an elevation
difference, a pair produces no hydraulic slope, which is the whole reason the
second logger is there.

The November 2025 field notes already say what is needed: *"return on the next
trip with the ranging laser... to get distance and altitude from both Dorothea
a and b and turpentine a and b."*

Three things want settling before the trip rather than after:

- **The laser reduction.** The instrument gives azimuth, inclination and slope
  distance; metadata wants along-channel distance and a height difference.
  Where does that arithmetic live, and is the raw observation kept?
- **What `elev` means** when a surveyed value and a DEM lookup share one
  column. `elev_source` distinguishes them, but a reader comparing two
  stations is comparing different things.
- **Pair geometry as time-varying.** A survey describes a pair at a moment. A
  logger that moves invalidates it, and metadata has no way to say a reach
  length applied between two dates.

The loggers at Turpentine Run and Fish Bay also fill their memory around
3 November, so the trip has its own deadline.

---

## Design questions, open

### Role is time-varying, and metadata cannot say so

`device_role` records what a logger is now. Fish Bay's pair inverted in
February 2024 — the upstream logger came out and went back in downstream — so
for 2021 to 2023 both rows read `secondary` with no primary.

Surfaced during the backfill and left alone deliberately: adding a second row
would assert a redeployment that did not happen. Barometric pairing and reach
length have the same shape. See `docs/backfill/fb2_hydro.md`.

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

### Deduplication on timestamp

Two downloads can cover the same window — a re-run, or a catch-up after a
failure — and Product 1 records both by design. Product 2 must therefore
decide: latest `run_id` wins, and a timestamp where two files disagree on the
VALUE is flagged rather than silently resolved.

There are eight such pairs in the archive, all from one afternoon of testing
on 1 October.

### HOBOlink level is recomputed, not carried

A HOBOlink export holds the station's own computed water level alongside the
raw pressures. Product 2 recomputes from pressure so every station derives the
same way, with the computed column kept as a check. Decided 2026-10-11; not
yet built.

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

### The metadata manager has not been tested since September

Raised on 7 October after a round of substantial changes — *"with this much
alteration we need to do comprehensive testing of MM again"* — and it has been
altered several times since: `expiry_date` added to the device details
workflow, the roster and to-do views wired in under option 3, device renaming,
and the propagation of per-device fields to co-located rows.

A workflow pass means walking each one: establish, relocate, replace, remove,
decommission, reactivate, correct details, port changes, and the co-located
cases that have caused the most trouble historically.

This is the same gap as the item below, seen from the other side. A test suite
would make it unnecessary; until there is one, somebody walks the menu.

### A testing strategy

Raised in two sessions and unresolved in both. The engine is not a package, so
`testthat` never landed.

This is the most consequential item on the list. The failures of 11 October
2026 were all in engine code — a POSIXct written as an epoch, three separate
timezone mistakes, device facts computed per serial rather than per
deployment — and every one was caught by running the code against real data
and reading the output. A test suite would have caught them in seconds.

The validators are a partial answer: `validate_metadata()` and
`validate_product1()` check the DATA. Nothing checks the FUNCTIONS.

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
