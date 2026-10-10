# Bethlehem Adventure 2 — backfill reconstruction

`bta2_hydro` · watershed Bethlehem, area Adventure, St Croix · reconstructed
October 2026

The youngest of the backfill sites and the only one where the paired deployment
was made deliberately rather than retrofitted. Its purpose is methodological:
to compare a flow-meter rating curve against the paired-logger Manning method,
and to get calibration insight on the roughness coefficient.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## Not to be confused with the old Adventure

The Bethlehem watershed — the largest in the Virgin Islands — carried three
gauges in the prototype era, all now defunct:

```
River        HOBOlink, below the confluence      "River Gut aka Fair Plain"
Bethlehem    mouth of the eastern tributary
Adventure    mouth of the western tributary
```

`bta2_hydro` is a **different, newer site further up the Adventure gut**, named
under the modern scheme. The `bta` prefix postdates all three.

**The name `adv` was reused**, which is the trap here.

> **Established** by file dates. The Adventure survey, cross sections, slope
> and rating curve were all written in autumn 2023 — `gutsurveys.csv` on
> 2023-09-03, `qcurves1.csv` on 2023-09-04, `slopedata.csv` and
> `roughness.csv` on 2023-10-13. `bta2_hydro` was not deployed until
> 2024-11-05, over a year later. So "Adventure" in every parameter file is the
> OLD site.
>
> `site.coords.csv` and `site.status.csv` were written in mid-2025, after the
> new site existed, which is why their `adv` entry points at 17.716903,
> -64.803571 — the modern `bta2_hydro` position. Matching coordinates prove
> only what the name meant in 2025, not continuity of site.

### What became of them

River was destroyed in the flood of **3–4 May 2024**.

> **Established.** Its record peaks at **3.657 m and 135.5 m³/s** at 23:15 on
> 3 May — forty times the largest event Fish Bay has seen in four years — and
> ends at 05:15 the following morning, still at 1.4 m on the falling limb. The
> 2024 import script records it: *"this gauge was destroyed in May 2024"* and
> *"logger died in the flood of early May 2024"*.
>
> The discharge on that limb is visibly erratic — 36.8, 44.5, 52.7, 54.2 m³/s
> while stage falls steadily — the rating curve failing well beyond anything it
> was built for.

That flood settled the question of the reach. The confluence and the gut below
it are too hydrologically active for the methods used elsewhere in the network,
and the two tributary-mouth loggers were either lost with it or taken out
afterwards.

> **Inferred.** Neither logger's fate is recorded.

**Neither old Adventure nor Bethlehem has any data in the prototype archive.**

> **Established.** Both appear in `gutsurveys.csv`, `slopedata.csv`,
> `roughness.csv`, `qcurves1-6` and `qfits.csv` — and in none of
> `all_discharge1-8`, nor `splices.csv`, nor the processed `.rda` files.
> Bethlehem has no entry in `site.coords.csv` at all.
>
> A rating curve needs only geometry, roughness and slope, so its existence
> says both sites were *prepared* for gauging, not that either recorded
> anything.

> **Unknown** whether either logger ever produced data. If it did, the files are
> not in any archive sent for this reconstruction.

Old Adventure was formally dropped in 2024.

> **Established.** `qcurves_meta.csv` records `qcurves7` as *"deleted Adventure
> site and re-ran Dorothea with slope model"*, and the 2025 `site-ids.csv`
> carries `adv` with no overbank threshold and no roughness where every live
> site has both.

---

## 2024-11-05 · a single gauge

**`Adventure`** (21652379) deployed at 10:00, fifteen minute interval.

> **Established.** First file 2024-11-05 10:02; maintenance log entry *"New
> station established: Bethlehem Adventure 2"* on the same date.

Offloaded 2025-01-07 and 2025-03-03, then into the VI-FLO era — its September
2025 and later offloads are recorded in the maintenance log.

> **Established** from the file boundaries and the log.

### It was never processed

Despite having a rating curve, Adventure's data never went through the
prototype pipeline.

> **Established.** Rating curves exist in `qcurves1-6` and `qfits.csv`. But
> Adventure appears in none of `all_discharge1-8`, and `adv` is the only site
> absent from `splices.csv` — so no gap was ever filled, no correction made and
> no discharge computed. Jolly Hill and Bethlehem are in the same position.

---

## 2026-08-28 · renamed

Relaunched as `bta2` at 10:08 AST, device name changed from `Adventure`.

> **Established** from the maintenance log, which records the relaunch and the
> rename as separate entries on consecutive days.

Cleaning that visit: ants and debris cleared from the housing, silt from the
transducer, residue from the logger surface.

---

## 2026-09-02 · the pair, and why

A second logger, **`bta2a`** (22357376), added downstream. `21652379` became
**`bta2b`**, now the upstream member.

```
bta2a   22357376   primary     downstream
bta2b   21652379   secondary   upstream
```

> **Established.** The log records `device_added` for 22357376 and a relaunch of
> 21652379 the same day: *"relaunched to rename bta2b, logger is now upstream of
> paired logger bta2a"*.

**The deployment is methodological.** The pair exists to compare a flow-meter
rating curve against the paired-logger Manning method at the same reach, and to
calibrate the roughness coefficient against a measured hydraulic slope.

> That makes this the one site where Manning's *n* can be checked rather than
> assumed — which matters beyond Adventure, since `roughness.csv` assigns 0.15
> to nearly every site in the network without evidence.

### The survey, half done

An elevation survey the same day:

```
primary   (bta2a, downstream)   22.160 m
secondary (bta2b, upstream)     22.383 m
difference                      +0.223 m
```

> **Established** from the maintenance log entry of 2026-09-02.

**The distance between them was not measured.** `reach_length_m` is NA for both
rows, which is why the network to-do list flags this station as having no
survey.

> **Established** from current metadata.

Without it there is no slope, and without a slope the comparison this pair was
installed to make cannot be done. A tape between the two loggers is all that is
needed, and the site is on St Croix.

---

## The prototype geometry does not reconcile

Three sources disagree about the reach:

```
slopedata.csv        6 points over 23.3 m, rod range 0.341 ft    0.45%
discharge_debug.R    18.085 m, fall 0.4389 m                     2.43%
```

> **Unknown.** Neither span matches the other, and `slopedata.csv`'s rod
> readings do not fall monotonically downstream — the point 14.17 m below the
> gauge reads higher than the one at 9.47 m. One of these is mismeasured or
> mistranscribed and there is no way to tell which.

It matters less here than elsewhere, because the 2026 pair supersedes it: a
measured elevation difference exists, and only the distance is missing.

Roughness across the network is **0.15**, with Dorothea at 0.20 and TR2 at
0.017. The 0.07 seen in `discharge_debug.R` was a first attempt: `qcurves_meta.csv`
records `qcurves1` as "0.07" and `qcurves2` as "0.15", and every later curve uses
0.15.

> **Established** from `qcurves_meta.csv` and the 2024 `roughness.csv`.

That 0.15 is assumed rather than measured at every site but TR2, which is why
this pair exists.

---

## What follows

### Metadata

```
21652379   bta2b, secondary, upstream,   from 2024-11-05 10:00
22357376   bta2a, primary,   downstream, from 2026-09-02 15:45
```

`reach_length_m` is missing on both and is the one field that would complete
the survey. The elevation difference of 0.223 m is in the maintenance log but
not in `elev` — 22357376 carries 17.54 from a 3DEP lookup and 21652379 carries
nothing, so neither reflects the surveyed values of 22.160 and 22.383.

Worth deciding whether `elev` should hold the surveyed figures or the looked-up
ones, since the pair's difference is what feeds the slope.

### Maintenance entries

Already recorded contemporaneously. Nothing to reconstruct — this station
postdates the metadata manager and its history is complete.

### Product 1

```
21652379    2 files   2024-11-05 → 2025-03-03    (prototype)
21652379              2025-03-03 → present       (already in VI-FLO)
22357376              from 2026-09-02, not yet offloaded
```

Only the two prototype CSVs need importing. Everything after 2025-03-03 is
already Product 1.

Those two files are `bta2_hydro`'s own — they postdate its deployment and carry
serial 21652379. They are not the old Adventure's, whatever that site may have
recorded.

### `record_confirmed`

**2024-11-05**, reason: *station established under the metadata manager era;
device history complete from deployment; see docs/backfill/bta2_hydro.md*.

Adventure is the one backfill site whose record needs no reconstruction — it
was established late enough that the log was kept properly from the first day.

---

## Open

- `reach_length_m` between `bta2a` and `bta2b`. One tape measure, on St Croix.
- Whether `elev` should hold surveyed or looked-up elevations when a pair has
  been surveyed directly.
- The prototype reach geometry is irreconcilable between two sources, and since
  Adventure's data was never processed, nothing downstream depends on it.
- Roughness: 0.15 or 0.07. This pair is the means to settle it empirically.
