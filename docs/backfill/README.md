# Backfill reconstructions

VI-FLO's metadata manager began in 2026. Most stations in the network are older
than that, and for those years there is no contemporaneous record — no
maintenance log, no port history, no review dates. What exists instead is a
retired working archive of raw exports, per-site processing scripts, parameter
files and field notes, accumulated by one person over five years and never
documented at the time.

These dossiers are the reconstruction of each station's history from that
material, and they are the only part of it that carries forward.

---

## How to read a dossier

Each one is a dated sequence of what happened at a station, with the evidence
for each claim in a quoted block beneath it. Claims are graded:

- **Established** — the data or the code says so directly
- **Inferred** — the best reading of circumstantial evidence
- **Unknown** — not recoverable from what survives

Each ends with what follows: metadata rows to add or correct, maintenance
entries worth reconstructing, files to import as Product 1, and a statement of
how far back the reconstruction reaches.

**That span is not `record_confirmed`.** These documents establish what can be
known about a station's history; `record_confirmed` records a visit at which
someone checked a station against VI-FLO standards. A dossier reaching back to
2021 says the history is recoverable, not that anyone has vouched for it.

---

## The prototype archive

The evidence cited throughout comes from **`vi-flo-prototype`**, a retired
repository that is not part of VI-FLO and will not be released. It is badly
documented, internally inconsistent and was never meant to be read by anyone
else. It is preserved privately so the claims below remain checkable, and these
dossiers exist so that nobody has to read it.

**The raw logger exports feed VI-FLO as Product 1.** Beyond those, the archive
divides in two:

**Carried forward**, because there is no other source and the measurements were
made once — the streambed slope surveys, the channel cross sections, the
roughness values, the gaugings and the stage they were taken at. A dossier that
cites these is citing the only record of a field measurement, and the values
belong in VI-FLO's parameter files.

**Superseded**, because VI-FLO derives them differently — the processed series,
every gap fill and correction in `splices.csv`, the rating curves, and the
elevation differences in `elevs.csv`. VI-FLO computes a barometric correction
from the two stations' own recorded elevations, which each deployment window
carries; the prototype's fixed figures are noted in a dossier only where its
processed output rests on them.

What the cited files are:

| file | what it is |
|---|---|
| `slopedata.csv` | streambed profiles up and downstream of each gauge. Horizontal metres, vertical rod readings in **feet** |
| `gutsurveys.csv` | channel cross sections, three per site, for hydraulic radius |
| `roughness.csv` | Manning's *n* per site. 0.15 everywhere except TR2 (0.017, concrete) and Dorothea (0.20, boulders) |
| `elevs.csv` | elevation differences used for barometric correction. Two versions exist, bracketing a station relocation |
| `qfits.csv` | gaugings paired with the stage at the moment of measurement — rating curve calibration points |
| `measured_discharge.csv` | the same gaugings with date and time, without stage |
| `qcurves1-11.csv` | successive rating curve versions, as stage→discharge lookup tables |
| `qcurves_meta.csv` | what changed at each version. The most useful file in the archive |
| `slope_models.csv` | fitted hydraulic slope models. Dorothea and Fish Bay only |
| `site-ids.csv` | site names, coordinates, overbank thresholds, roughness |
| `site.coords.csv` | coordinates per site and station type. Written 2025, so its names reflect 2025 usage |
| `site.correspondence.csv` | which weather station serves which gauge |
| `splices.csv` | 13,046 records of every QA intervention: gaps filled, periods checked, corrections applied |
| `<site>.hydro.rda` etc. | processed outputs. Superseded entirely |
| `Archiving/<site>_<date>.R` | per-site import scripts. The closest thing to a lab notebook |

### On `splices.csv`

It holds three different kinds of entry and they should not be read alike:

- **Processing choices** — 12,265 linear interpolations and similar. These die
  with the prototype. VI-FLO leaves a gap as a gap through Product 3; filling it
  is something a user does to P4 with their own assumptions.
- **Evidence of physical history** — `neighbor.atmos` across all variables means
  a station was not there or not working. `stays.gap` means someone looked and
  declined to fill. This is metadata, and it has been mined for these dossiers.
- **Evidence that someone judged** — `type = check` entries, where a suspicious
  period was compared against neighbouring gauges or GPM satellite rainfall and
  either corrected or accepted.

Where a dossier cites a gap or a loss, it has been verified against the raw
Product 1 export wherever possible, not taken from this file.

---

## Stations

### Hydro

| station | dossier | span reconstructed |
|---|---|---|
| `fb2_hydro` | `fb2_hydro.md` | 2021-10 → |
| `rb2_hydro` | `rb2_hydro.md` | 2023-09 → |
| `dor2_hydro` | `dor2_hydro.md` | 2023-06 → |
| `tr1_hydro` | `tr1_hydro.md` | 2023-06 → |
| `tr2_hydro` | `tr2_hydro.md` | 2023-06 → 2024-10, decommissioned |
| `bta2_hydro` | `bta2_hydro.md` | 2024-11 → |
| `lg1_hydro` | `lg1_hydro.md` | 2023-08 → |
| `sr1_hydro` | `sr1_hydro.md` | 2021-11 → |
| `sr2_hydro` | `sr2_hydro.md` | 2021-11 → |

### Weather

| station | dossier | span reconstructed |
|---|---|---|
| `uvi_weather` | `uvi_weather.md` | 2021-10 → |
| `sr1_weather` | `sr1_weather.md` | 2022-09 → |
| `sr2_weather` | `sr2_weather.md` | 2021-07 → |
| `cal1_weather` | `cal1_weather.md` | 2021-11 → |
| `fb1_weather` | `fb1_weather.md` | 2021-10 → |
| `dor1_weather` | `dor1_weather.md` | 2023-06 → |
| `tr1_weather` | `tr1_weather.md` | 2023-06 → |

### Soil moisture

| station | dossier |
|---|---|
| `uvi_vwc1`, `uvi_vwc2`, `uvi_vwc3` | `uvi_vwc.md` |
| `sr1_vwc1`, `sr1_vwc2`, `sr1_vwc3` | `sr1_vwc.md` |
| `sr2_vwc1`, `sr2_vwc2`, `sr2_vwc3` | `sr2_vwc.md` |
| `fb2_vwc1` | `fb2_vwc.md` |
| `bta2_vwc1`, `bta2_vwc2` | `bta2_vwc.md` |

All soil moisture at a site is covered in one dossier, because the stations
share devices, pits and history. Weather and hydro are separate even where they
share a logger.

### Covered within another dossier

| station | where |
|---|---|
| `cal1_vwc1` | `cal1_weather.md` — shares `z6-37439` |
| `sgm2_hydro` | `rb2_hydro.md` — its logger `21652377` served Reef Bay first |

### No dossier needed

Established under the metadata manager, so their history is already
contemporaneous and complete:

`lg3_weather`, `lg3_vwc1`, `cal2_hydro`, `cq1_hydro`, `cq2_hydro`,
`ltt1_vwc1`, `ltt1_vwc2`, `ltt1_vwc3`

The absence is deliberate.

### Deferred

`uvi_vwc2`, `uvi_vwc3` and `bta2_vwc2` carry six TEROS 10 across all six ports,
a design that exists nowhere else. Their stations are named in the relevant
dossiers with what metadata holds, but their history is not reconstructed and
pending information still to be tracked down. Folding them in later touches nothing else — they share no devices
with the four-depth stations and appear in no prototype output.

---

## Findings that cross stations

**Ten-minute logging cost four HOBO loggers a month of data each**, sometimes
twice. A U20 holds about 21,600 readings — 150 days at ten minutes, 225 at
fifteen. Salt River 1, La Grange 1, Adventure and Reef Bay all filled and
stopped before anyone returned. All are now at fifteen minutes.

**The HOBOlink telemetry stations all failed within a year of each other.**
Turpentine Run in Hurricane Ernesto, Salt River 2 from a battery charging
failure, River in the flood of May 2024.

**11 November 2024 was a regional storm** that ended the Reef Bay gauge and the
Dorothea pair, and took Turpentine Run to 2.03 m and Fish Bay to about 1.72 m.

**Two inherited deploy dates.** `sr1_hydro`'s and `sr2_hydro`'s U20s both carry
the timestamp their HOBOlink started, years before those loggers existed.
`sr1_weather` carries the same. Left uncorrected, attribution assigns years of
one device's readings to another.

**A station unvisited for more than six months is suspect for QA purposes.** A
clean correction record can mean a well-behaved station or an unwatched one, and
the two are indistinguishable from the data.

**Two ATMOS units have lost their funnel spring** — UVI on 2 March 2026 and
Dorothea on 24 March. The effect on rainfall is unknown and would not show as a
gap, because a misreading gauge produces plausible numbers.

**Two more are degrading in the sun**, at Salt River 1 and Turpentine Run, both
noted in March 2026 and neither replaced.

**Eight soil moisture loggers died over fifteen months and were found
together.** The maintenance log records seven as nonresponsive on 2 March 2026
and one on St John three weeks later, but the raw shows they stopped
individually:

```
fb2_vwc1    2024-06-05        sr1_vwc2    2025-03-23
bta2_vwc2   2024-09-01        uvi_vwc3    2025-04-16
bta2_vwc1   2024-11-05        sr1_vwc1    2025-05-21
sr2_vwc2    2025-01-13        sr2_vwc1    2025-09-25
```

**The log records a discovery; the raw records the event.** That distinction
applies to every station found this way, and the dates above are the ones that
bound each record.

The field notes name the suspected cause — *"The common thread seems to be the
lithium batteries, though memory tells me putting fresh batteries does not
help"* — and the response was to switch the rebuilt stations from rechargeable
cells to alkaline in September 2026.

Four of the eight have been rebuilt. `uvi_vwc3`, `bta2_vwc1`, `bta2_vwc2` and
`fb2_vwc1` have not been visited since and remain dead.

**A device can keep transmitting after it is removed.** `z6-13388` was taken out
of the Salt River 2 hillside pit on 2024-01-22 and reported for another nineteen
days from wherever it went. Deployment windows are what stop those readings
being attributed to a station.

**All seven ECRN-50 rain gauges are defunct.** Every streambank and hillside
soil moisture station carried one on port 5, and not one survives. None has an
installation date and none has a failure date, so whether they failed
individually or were abandoned as a design is unknown.

**Neither Salt River site has a hillside pit any more.** Both were retired in
September 2026 and replaced by profiles on the weather stations' loggers, which
sit elsewhere. The hillside–streambank comparison the prototype's soil moisture
work was built on has no successor.
