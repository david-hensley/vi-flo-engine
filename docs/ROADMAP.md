# Roadmap

Open work, with where it came from and what it is waiting on.

This file exists because the list was living in session transcripts and in
recollection, which meant rediscovering it each time — and carrying at least
one item that had never existed. Anything genuinely finished is deleted rather
than struck through; `CHANGELOG.md` is the record of what was done.

Last reviewed: **2026-11-22**

---

## Versions ahead

Engine versions follow the product ladder. The dataset release that gets
cited - a DOI, its own station list - is numbered separately, on its own
clock.

- **v2.8.1** - current, released 2026-11-19
- **v2.9** - in progress: the structural work. One data layer for every
  table, saves that refuse new validation problems, surveys as their own
  table, deployments that close their ports, one device naming rule, the
  unattributed-readings workflow, and the Box orphan sweep in the sync tool.
  Tagged after one Product 2 rebuild and a manual check of it
- **v2.10** - the metadata in git, so every version is a commit and any
  product can be rebuilt exactly as it was. Before Product 3, whose decisions
  rest on the metadata (see *Metadata into git* below)
- **v3** - Product 3 automatic and unattended: QC under declared parameters,
  gap filling by declared rules, and the first derived series, level, from
  Product 2 pressure and the barometric pairing table
- **After v3** - the computed variables beyond level (discharge, storage and
  the rest), and v4, Product 4: the workflow for human decisions. Discharge
  sits here, resting on rating curves that are partly experimental

**Run the weekly job from a release.** Today it runs the newest engine code,
so a change to Product 2's code means the next run rebuilds the affected files
on its own. Run from a tagged release instead, rebuilds happen only when the
job is moved to the next release, and each file records which release built
it. Planned once Product 2 reaches a settled milestone, for stability. Less
pressing since v2.9, when unrelated code changes stopped triggering rebuilds.

### v2.9, before the tag

- **Decommissioning asks when.** Today its ports close at the moment it is
  entered, and its log entry is dated today. It should ask when the station
  was shut down and use that moment for the ports, the rows and the log, as
  removal and replacement already do
- End-to-end workflow tests for establishing, relocating, replacing,
  correcting details, decommissioning and reactivating - each walked through
  in the sandbox as its test is written
- The Product 2 rebuild, a manual check of it, and tests designed from that
  check

---

## Field work

What needs a visit - loggers not reporting, low batteries, memory filling,
surveys outstanding, known broken boxes - is on the to-do list
(`print_network_todo()`), worked out from the metadata each time rather than
written down here, where it would go stale.

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
the first two items. Their surveys are on the to-do list.

- **The ingest path.** Product 0 and 1 are keyed by device, so a pond logger
  should go through the HOBO import like any U20 - but nothing has ever sent
  a `pond` station or a U20-001-01 through it. Audit each place the code
  special-cases `hydro` before that download, not after
- **Barometric pairing.** Both ponds are on St Croix, so in the STX zone. They
  need declared sources like any gauge, and the pairing table has only ever
  held hydro stations
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
them. Barometric pairing has the same shape.

Survey geometry no longer has this problem: since v2.9 every survey is its
own dated row in `surveys.csv`, and nothing overwrites an earlier one.

### Barometric pairing

The scheme is designed and written up in the README: a declared pairing per
station, with validity periods and a priority order, so a fallback when a
weather station dies is deterministic rather than runtime cleverness.

What does not exist is the file itself, or a prompt in the metadata manager
asking for a pairing when a station is established. `site.correspondence.csv`
in the prototype archive recorded this; nothing in VI-FLO does yet.

### `decommissioned` and `removed` overlap in practice

Both describe a station or device that has stopped. Since v2.9 each status's
meaning is written once, in the data layer, and shown wherever a status is
chosen — `removed` is the logger taken out with the station continuing,
`decommissioned` the station itself shut down. Whether the older rows follow
those meanings has not been checked.

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

### Metadata into git - v2.10, before Product 3

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

### Email before a logger fills its memory

The memory check computes the date. Sending a reminder was blocked on GitHub
Actions not being able to see metadata in the data root, which may no longer
be the constraint now that the job runs on a desktop.

---

## Engineering

### Workflow tests

The suite drives workflows with scripted answers and checks what they leave
in the metadata and logs, and GitHub runs it on every push. Removing a
device, deleting a row, every survey and explaining unattributed readings are
tested this way, end to end. Relocation, replacement, port changes and
corrections are tested underneath, at the functions that save them, but not
through their prompts. Establishing, relocating, replacing, correcting
details, decommissioning and reactivating still want end-to-end tests -
listed under v2.9 above.

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

### Old sensor heights

When recording sensor heights, read `docs/backfill/LEVEL_CORRECTIONS.md`
first: the prototype's level offsets at SR1, SR2, Fish Bay and Dorothea, and
the only old sensor heights on record.

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
