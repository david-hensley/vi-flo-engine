# La Grange 1 — backfill reconstruction

`lg1_hydro` · watershed La Grange, St Croix · reconstructed October 2026

Known as **Jolly Hill** throughout the prototype era. One logger, one position,
no pair — and three separate occasions on which it filled its memory and
stopped.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## Jolly Hill and La Grange 1 are the same place

> **Established** by coordinates. `site.coords.csv` puts `jh` at 17.7313,
> -64.8622; current metadata puts `lg1_hydro` at the same point. The site was
> renamed under the modern scheme, not moved.

The device name followed later and awkwardly: `Jolly Hill` until August 2026,
then briefly `lg3`, then `lg1`.

Weather comes from Ridge to Reef Farm.

> **Established.** `site.correspondence.csv` pairs `jh` to `r2r` — the station
> that later became `cal1_weather`.

---

## 2023-08-01 · deployed

**`Jolly Hill`** (21652375) at 09:30, ten minute interval. A single gauge; the
site has never had a pair.

> **Established.** First file 2023-08-01 09:24; maintenance log entry *"New
> station established: La Grange 1"* dated 2023-08-01.

---

## 2023-12-30 · the memory fills

The first file ends with exactly **21,693 readings**.

> **Established**, and this is the capacity of a U20. At ten minutes it fills in
> 150 days; deployed on 1 August, it stopped on 30 December.

Not offloaded until 1 February 2024, so a month was lost.

> **Established.** The next file begins 2024-02-01 08:14, and the processed
> archive carries **3,199 consecutive NAs** across that window.

**This logger has filled its memory three times.**

```
2023-12-30   stopped, offloaded 2024-02-01      ~1 month lost
2025-08-01   stopped, offloaded 2025-09-03      ~1 month lost
2026-02-01   stopped, offloaded 2026-03-02      ~1 month lost
```

> **Established** from the file boundaries and reading counts in each case.
>
> All three at ten minutes, while metadata declared fifteen. The network status
> check could not see it: it computed the fill date from the declared interval
> and so expected 225 days rather than 150. That is why the memory check now
> takes its interval from the timestamps of the data itself.

---

## 2024-02-01 → 2025-03-03 · uninterrupted

Offloaded 2024-05-06, 2024-08-23, 2024-09-13, 2025-01-07 and 2025-03-03.

> **Established** from the file boundaries.

The processed archive runs to 2025-01-07.

> **Established.** `jh.hydro.rda` holds 50,424 rows from 2023-08-01 to
> 2025-01-07 with level and discharge. The final prototype file — January to
> March 2025 — was never imported.

---

## 2025-03-03 → present · the VI-FLO era

Offloaded 2025-09-03, 2026-03-02, 2026-08-28 and 2026-09-02, all recorded
contemporaneously in the maintenance log.

> **Established.**

### 2026-08-28 · the interval corrected, and a naming slip

Relaunched at **fifteen minutes**, ending the memory problem. Renamed from
`Jolly Hill` to `lg3` at the same relaunch.

> **Established** from the log: *"relaunched as lg3 at 15 minute interval from
> 10"*.

`lg3` was the wrong name — it belongs to a different La Grange station.

### 2026-09-02 · corrected

Returned to the site five days later purely to fix it: *"downloaded small amount
of data in field to PC due to relaunch"*, then *"relaunched as 'lg1' correcting
recent mistake"*.

> **Established.** The 2026-09-02 file holds 972 readings — five days of data,
> downloaded only so the relaunch would not lose them.

This is the clearest example in the archive of the log catching its own error.
A device name is embedded in every subsequent export, so without the correction
every future file would have claimed to be `lg3`.

---

## Gaugings

Jolly Hill has **five** measured discharges — the only site outside Salt River
that was ever gauged.

```
level 0.105    q 0.0026    undated
level 0.0678   q 0.003     2024-02-26 16:00
level 0.0736   q 0.003     2024-08-13 16:00
level 0.2480   q 0.191     2024-08-14 10:30   Tropical Storm Ernesto
level 0.2326   q 0.185     2024-08-14 11:15   Tropical Storm Ernesto
```

> **Established** from the October 2024 `qfits.csv`, and corroborated by
> `qcurves_meta.csv`: *"qcurves11 — Creating curve for Jolly Hill based on 5
> points"*.

The two Ernesto points are the only high-flow measurements here, and they are
what makes the rating curve usable above trickle. The same morning produced
gaugings at SR1 and SR2 — one storm, three sites.

## Geometry

```
bed gradient    0.71%      slopedata.csv, 9 points over 42.4 m
roughness       0.15       roughness.csv
cross sections  3 reps     gutsurveys.csv
elevation       48.59 m    highest gauge in the network
overbank        2.137 m
```
> The maximum observed stage sits below this, so nothing in the record has been
> clipped.

> **Established** that the survey exists; metres horizontally, rod readings in
> feet, with the 0.3048 conversion applied.

Two sources disagree about the reach, as they do at several sites.

> **Unknown.** `discharge_debug.R` gives 29.99 m with a fall of 0.9632 m —
> 3.21% — against `slopedata.csv`'s 0.71% over 42.4 m. The hand-entered values
> in that script convert feet to metres inline at some sites and not others,
> and cannot be reconciled site by site. `slopedata.csv` is the primary survey
> record and is preferred.
>
> `slopedata.csv`'s own readings are also non-monotonic at the farthest
> downstream point, which reads higher than the one before it.

---

## What follows

### Metadata

```
21652375   lg1_hydro, from 2023-08-01 09:30
           device_name: Jolly Hill -> lg3 -> lg1
           interval_min now 15, was 10 until 2026-08-28
```

`reach_length_m` is NA, which is correct for a single gauge — there is no pair
to measure between.

`elev` of 48.59 m is from a 3DEP lookup rather than a survey.

### Maintenance entries

The VI-FLO era is already recorded. Two structural events predate it:

```
2023-08-01   station_established   Jolly Hill gauge deployed at 10 minutes
2023-12-30   logger_memory_full    filled after 150 days; a month lost before
                                   the 2024-02-01 offload
```

The second is worth recording even though nothing was done about it at the
time, because the gap in the archive is otherwise unexplained.

### Product 1

```
21652375    6 files   2023-08-01 → 2025-03-03   (prototype)
21652375              2025-03-03 → present      (already in VI-FLO)
```

### `record_confirmed`

**2023-08-01**, reason: *single gauge, one position, device history complete
from deployment; see docs/backfill/lg1_hydro.md*.

A straightforward site. The only complications are self-inflicted and both are
documented — the memory fills and the brief misnaming.

---

## Open

- The undated gauging at level 0.105 has no date in any file, so it cannot be
  tied to a stage record for checking.
- Whether the January–March 2025 file should be reprocessed. It exists in raw
  form and was never imported, so the processed archive stops two months short
  of the prototype record.
- The reach geometry disagrees between `slopedata.csv` and `discharge_debug.R`
  by a factor of four. Since Jolly Hill has no pair, the bed slope is the only
  slope available and the discrepancy matters.
