# Salt River 2 — backfill reconstruction

`sr2_hydro` · watershed Salt River, St Croix · reconstructed October 2026

Simpler than its neighbour: one HOBOlink that ran for nearly three years without
a base replacement, then one U20 that took over cleanly. No pair, no losses.

It is also the site whose rating curve is not a Manning curve at all.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2021-11-22 · the HOBOlink era

A HOBOlink station — base **21171528** with water pressure sensor **21180079** —
recording at **five minutes** from 17:55.

> **Established.** `sr2_hydro_20211122-20231231.csv`, 200,060 rows.

The base was never replaced. SR1's was swapped mid-life; this one ran the whole
period on one unit.

> **Established** from the column headers of both files, which name the same
> base and sensor throughout.

## 2024-05-03 · the largest event

Stage **2.067 m**. The same night River — a few kilometres east in the Bethlehem
watershed — reached 3.657 m and 135 m³/s and was destroyed.

> **Established** from the processed archive.

**That stage is the clipping ceiling, not a measurement.** SR2's maximum in
`sr2.hydro.rda` equals its overbank threshold exactly.

> **Established.** The raw pressure record is intact, so the true peak is
> recoverable by rebuilding level from Product 1. Fish Bay is the only other
> site clipped this way.

## 2024-08-14 · Tropical Storm Ernesto

Peak stage 1.151 m, discharge 2.839 m³/s at 04:15. Two gaugings were taken on
the falling limb that afternoon.

> **Established** from the archive and the October 2024 `qfits.csv`.

## 2024-08-17 · the HOBOlink dies

Last reading at **05:15**, with water pressure steady at 106.096 kPa against
101.582 barometric — about 46 cm of water. It stopped with the sensor submerged
and reading normally.

> **Established.** The 2024 import script: *"The hobolink logger battery
> charging failed in Aug 2024; backup must be engaged"* and *"Hobolink died at
> 2024-08-17 05:15:00"*.

A battery charging failure, not a flood. Ernesto had passed three days earlier
and the gauge survived it.

---

## 2024-08-15 · the U20 takes over

**`SR2_backup`** (21652378) at 11:43, **fifteen minute** interval — the only
backup U20 in the network launched at fifteen rather than ten.

> **Established.** First file 2024-08-15 11:43.

It went in **two days before** the HOBOlink died, overlapping it.

> **Inferred** that the installation was a response to the failing battery
> rather than a coincidence. The script's wording — *"backup must be engaged"* —
> reads as a planned handover.

Its early record carried spurious negative levels.

> **Established.** The 2024 script: *"This removed the fake negatives from
> hoboware backup but still needs a small correction."*

## 2024-08-15 → present

Offloaded 2024-08-23, 2024-09-13, 2025-01-07, 2025-03-03, then into the VI-FLO
era.

**It never filled its memory**, unlike every other St Croix gauge. Fifteen
minute logging gives 225 days, and no interval exceeded that.

> **Established** from the file boundaries. SR1, Jolly Hill and Adventure all
> ran at ten minutes and all lost data to it.

### 2026-08-28 · renamed

Relaunched as `sr2`, renamed from `SR2_backup`. The visit noted *"rebar
beginning to rust out"* — the housing, not the logger.

> **Established** from the maintenance log.

---

## The rating curve is not a Manning curve

SR2 alone is fitted with a **straight line and a gauge-height offset** rather
than computed from channel geometry.

> **Established.** `qcurves_meta.csv` records `qcurves4` as *"empirical rating
> curve in SR1, straight-line curve with gauge-height offset in SR2, and
> empirical hydraulic slope curve from secondary FB sensor"*.

The offset is a **gauge zero-flow of 0.27 m** — the stage below which there is
no throughflow, so discharge is zero whatever the curve would otherwise give.

> **Established.** `qcurves5` set it at 25 cm; `qcurves6` revised it to *"a more
> accurate GZF at SR2 of 27cm based on field measurements"*.

A gauging at stage 0.27 reading exactly zero discharge appears in `qfits.csv`,
which is that threshold measured rather than assumed.

> **Established.**

---

## Gaugings

Six, the second most of any site.

```
level 0.7321   q 0.3930   undated
level 0.3700   q 0.0070   undated
level 0.3399   q 0.0027   undated
level 0.2700   q 0.0000   undated          the gauge zero-flow point
level 0.6451   q 0.3020   2024-08-14 15:45  TS Ernesto
level 0.6282   q 0.2690   2024-08-14 16:15  TS Ernesto
```

> **Established** from the October 2024 `qfits.csv`. `qcurves_meta.csv` records
> the Ernesto additions as `qcurves9`.

Better distributed than SR1's — three points above 0.6 m against an overbank
threshold of 2.067 m, where SR1's largest is 0.348 m against 2.335 m. Still
nothing near the top of the range.

---

## Geometry

```
bed gradient    0.28%      slopedata.csv, 6 points over 28.9 m
roughness       0.15       roughness.csv
cross sections  3 reps     gutsurveys.csv
gauge zero-flow 0.27 m     measured, qcurves6
overbank        2.067 m
elevation       5.55 m     3DEP lookup - the lowest gauge in the network
```

> **Established.** Metres horizontally, rod readings in feet, with the 0.3048
> conversion applied.

The HOBOlink needed no barometric reference, carrying its own barometer. The U20
that replaced it does, and takes it from the SR2 weather station.

> The correction is computed from the two stations' recorded elevations. The
> prototype used a fixed -5 m, which VI-FLO does not inherit.

---

## What follows

### Metadata — the deploy date is wrong

```
21652378   sr2_hydro, deploy_datetime 2021-11-22 18:00
```

**That is the HOBOlink's first reading, not this logger's.** `21652378` did not
record until 2024-08-15 11:43 — nearly three years later. The same error exists
at SR1.

> **Established** by comparing the metadata row against the file boundaries.

Two rows are needed where there is one:

```
21171528 / 21180079   HOBOlink,  2021-11-22 → 2024-08-17
21652378              SR2_backup / sr2, from 2024-08-15
```

### Maintenance entries

```
2021-11-22   station_established   HOBOlink deployed, base 21171528
2024-08-15   device_deployed       SR2_backup (21652378) added at 15 minutes
2024-08-17   device_removed        HOBOlink died, battery charging failure
```

### Product 1

```
21171528/21180079   2 files   2021-11-22 → 2024-08-17   (HOBOlink, 5 min)
21652378            4 files   2024-08-15 → 2025-03-03
21652378                      2025-03-03 → present      (already in VI-FLO)
```

`SR2_level.csv` in the older downloads folder duplicates the first HOBOlink file
at five minutes and can be left.

### What this reconstruction covers

`sr2_hydro` is reconstructed from **2021-11-22** — the HOBOlink's deployment —
to the present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- Whether the HOBOlink's **computed water level** or its raw pressures should
  feed Product 2. The same question applies at SR1, TR1 and River.
- The negative levels in the U20's early record were corrected in the prototype
  pipeline but the correction is not recorded as a parameter. Rebuilding from
  raw will need to address them again.
- SR2's rating curve is a fitted straight line rather than a Manning curve, so
  it does not transfer to the method used elsewhere. Whether to keep it, or
  rebuild SR2 on geometry like the rest, is a processing decision.
