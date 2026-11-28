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

- **v2.9.0** - current, released 2026-11-22: the structural work. One data
  layer for every table, saves that refuse new validation problems, surveys
  as their own table, deployments that close their ports, one device naming
  rule, the unattributed-readings workflow, every metadata manager workflow
  tested end to end, and the Box orphan sweep in the sync tool
- **v2.10** - in progress, in this order:
  1. Reading the products back and looking at them - `read_product()` and
     `browse_product()` (done)
  2. Metadata manager: local stations that reach the cloud on their own,
     a shared logger's downloads and status changes logged at both its
     stations, surveys in the view menu, a sensor below the bed counted as
     surveyed, a warning on opening when the data root differs from Box, the
     HOBO export saved under its own name, and station photos filed for you
     in a `photos/` folder of their own (see *Local stations* and *Station
     photos* below)
  3. The metadata in git, so every version is a commit and any product can
     be rebuilt exactly as it was. Every writer commits its own changes - the
     metadata manager on exit, the weekly job after each run, a migration
     when applied - and `start.R` catches anything left uncommitted. The
     metadata manager pulls when it opens, from the launcher as well as
     `start.R`, and commits and pushes on exit; offline, it says so, commits
     locally and pushes next time. The metadata leaves the Box sync. Before Product 3, whose decisions rest on
     the metadata (see *Metadata into git* below)
  4. The weekly job run from tagged releases (see below)
  5. Coordinates on every Product 2 row (see *Where each reading was taken*
     below), and `pressure` renamed `air_pressure`, then one rebuild, looked
     over with `browse_product()`
  6. An offline snapshot (see below)
- **v3** - Product 3 automatic and unattended: QC under declared parameters,
  gap filling by declared rules, and the first derived series, level, from
  Product 2 pressure and the barometric pairing table
- **After v3** - the computed variables beyond level (discharge, storage and
  the rest), and v4, Product 4: the workflow for human decisions. Discharge
  sits here, resting on rating curves that are partly experimental

**Local stations.** `local` means out of cellular service, with the data
reaching ZentraCloud only when it is offloaded on site. But a station with a
weak or failing connection can come back on its own, and nothing notices: its
status goes on saying local after it is reporting again. Nothing breaks - the
weekly job downloads every logger on the account whatever its status, and the
silence check reads ZentraCloud, not the status - but the record is wrong.
Two changes:

- The to-do list notices a local station whose latest reading on ZentraCloud
  is recent - "marked local but reached ZentraCloud 3 hours ago; consider
  setting it back to online" - and leaves the change to the person. A status
  is a person's account of the station, so it is never changed for them
- A manual download at a local station no longer asks "Have you uploaded this
  data to ZentraCloud?". An offload by Bluetooth to the phone uploads on its
  own once the phone has a signal, with nobody doing it. The download asks
  ZentraCloud instead whether readings up to the visit have arrived, and
  only if they have not does it record the visit as awaiting the cloud

In the same workflow: a ZL6 shared between a weather station and a soil
moisture station is one download, but it is logged at one station only, and
the other's record says nothing about the visit. When the logger downloaded
serves another station too, the manual download offers to log it there as
well, with the same date, details and person. A status change is the same
case: the status is the logger's - a ZL6 out of cellular service is out for
both its stations - but it is saved on one station's row, and the other goes
on saying online. When the logger serves another station too, a status
change offers to make the same change there, in the same save.

And the view menu, which shows devices, ports, the maintenance log and the
download log, gains the surveys: sensor heights, falls, reach and GNSS
elevations, filtered by station and by kind, the way the others are.

A survey is recorded as the higher point above the lower, so a sensor dug
in below the bed is saved as the bed above the sensor. The to-do list looks
only for the sensor above the bed, and goes on asking for a survey already
made - sr1_hydro since November 2026. It should ask `survey_height()`, which
follows the links both ways and through other points; the same for a
weather sensor and the ground. Anything else reading a sensor height is
checked for the same one-way reading at the same time.

The launcher opens the metadata manager without `start.R`, so nothing says
when this machine's data is behind Box - and on 28 November 2026 a session
changed `known_unattributed.csv` before a pull, which then kept the local
copy because it was newer. The launcher runs the same Box check `start.R`
does, and warns before the menu when the two differ, naming the files. A
dozen seconds, longer on a slow connection. Temporary: it goes when the
metadata is in git, which pulls on opening, and the archive is on Hugging
Face.

The HOBO export is saved as `<device name>.csv`, the name HOBOware offers
for a `.hobo` file of that name, so it can be saved without typing. The
temporary `<serial>_raw_temp.csv` name existed so an abandoned export could
never be taken for another logger's, but the ingest already reads the serial
inside the file and refuses a mismatch. If that name is not found, the
newest CSV saved in the folder since the instructions appeared is offered -
"Use this file?" - and used only on a yes, the serial still checked. A stray
space in a typed name stops mattering.

**Station photos.** One photo per station per visit, named
`station_id_YYYY-MM-DD` with the photo's own extension. They move out of
`metadata/internal/station_photos` into a top-level `photos/` folder, as
`photos/station_photos/`, by migration: photographs do not belong in the
metadata's git repository, where every clone would carry every one forever.
Like the archive they are never edited, only added to, so they sync with Box
for now and go to Hugging Face with the archive. The move comes before the
metadata goes into git, so no photo ever enters it.

Filing them is mostly typing today: emailed one at a time, downloaded, moved,
renamed by hand, filed. At the end of a session that logged a field visit,
the metadata manager offers to file a photo for each station visited:

- It looks in the Downloads folder and on the desktop, found wherever
  Windows keeps it, OneDrive included
- It ranks what is there rather than listing everything, since Downloads is
  full of old pictures. Strongest is a photo taken on the visit's date, where
  the file still carries the date it was taken; next, an image that arrived
  on this machine since the visit and is not already filed
- One clear candidate is offered on its own. Several are listed newest
  first, with when each was taken or arrived, to pick by number - or the
  digits of the phone's filename typed instead. None, and it says so and
  takes the digits
- The photo chosen opens in the computer's own photo viewer for a last look
  before anything is renamed - `shell.exec()` on Windows, one line
- "Rename to sr1_hydro_2026-11-25.jpg and file it?" On a yes the photo is
  moved into `photos/station_photos/`. An existing photo is never
  overwritten, and Enter skips a station
- A ZL6 shared by a weather station and a soil moisture station gets one
  photo, under the weather station's name. That convention is written in the
  data documentation, not in the filename
- The same steps are a menu item, for photos that arrive after the session;
  it lists recent visits with no photo yet
- Anyone whose photos arrive some other way gets the exact filename and the
  folder for each visit, to file by hand

**Where each reading was taken.** A station that moves keeps its name - fb1
is a site, and the network's history runs through it - but a reading taken
before a move and one taken after are from different places, and someone
downloading by location needs to tell them apart. Every Product 2 row will
carry `lat`, `lon` and `elev` from the deployment in place at that moment,
missing rows included, so a gap never reads as a move. A move is then visible
in the data itself, with no second naming scheme to keep in step; a future
downloader can offer a multi-location station's locations to choose from by
reading them there. A Product 2 format change, so every file is rebuilt once:
done in v2.10, alongside the metadata move, rather than as a rebuild of its
own.

The same rebuild renames the variable `pressure` to `air_pressure`: the
barometer's reading, from an ATMOS 41 or a HOBOlink MX2001's own sensor, sat
beside the water-level loggers' `abs_pressure` under a name that told the two
apart only by habit. Three rows of `data/variables.csv`, the data dictionary,
and whatever reads the barometric series for level.

**Subscription expiry from ZentraCloud.** Version 5 of the ZentraCloud API
reports each logger's subscription on `GET /v5/devices`: `subscription.status`
(`active`, `exempt`, or `inactive` - expired or never subscribed),
`expiration_date` (UTC epoch seconds, the date it is paid through) and
`auto_renew`. The device table's typed `expiry_date` was dropped in v2.9
because it went stale; fetched instead, an expiry can go on the to-do list a
month ahead - and an `inactive` logger flagged at once - with nothing to keep
up by hand. The same endpoint offers `expand=settings` (logging interval and
upload frequency, confirmed and pending) and `expand=location` (the cloud's
coordinates and elevation), both worth checking against the metadata. Not
yet scheduled.

**ZentraCloud keeps 914 days.** Measurements older than about two and a half
years cannot be fetched again: the archive here is the only copy of anything
earlier. One more reason for the offline snapshot below.

**An offline snapshot.** A copy no cloud mistake or sync can reach, made by
hand at a release and kept on an external drive. `save_snapshot()` writes one
new folder, named for the release and the date - the engine code at that
release, the metadata with its full history, the raw archive, and Product 2
for convenience - with a list of every file and its checksum, the release
tag and the metadata commit. It refuses an existing folder and never
overwrites anything, and checks the copy before calling it done;
`check_snapshot()` confirms an old one is still intact. Needs the metadata in
git and the releases, so it comes last in v2.10.

**Run the weekly job from a release.** Today it runs the newest engine code,
so a change to Product 2's code means the next run rebuilds the affected files
on its own. Run from a tagged release instead, rebuilds happen only when the
job is moved to the next release, and each file records which release built
it. Done in v2.10, now that ingest has settled.

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
device, decommissioning, deleting a row, every survey and explaining
unattributed readings are tested this way, end to end. Relocation, replacement, port changes and
corrections are tested underneath, at the functions that save them, but not
through their prompts. Establishing, relocating, replacing,
correcting details and reactivating still want end-to-end tests - listed
under v2.9 above.

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
- Remove the `backup` named path from `default_datamap.csv` and setup:
  nothing has used it since the savepoints were retired

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
