# Salt River 1 — backfill reconstruction

`sr1_hydro` · watershed Salt River, St Croix · reconstructed October 2026

The longest continuous record in the network — November 2021 to the present —
and the most layered. A HOBOlink telemetry station whose base unit was replaced
mid-life, then two U20s running alongside it, then one of those alone.

Salt River carries more measured discharge than anywhere else in the network,
which makes it the best place a rating curve has been checked against reality.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2021-11-24 · the HOBOlink era begins

A HOBOlink station — base unit **21171527** with water pressure sensor
**21180078** — recording at **five minutes** from 14:30.

> **Established.** `sr1_hydro_20211124-20230802.csv`, 177,121 rows. It carries
> its own barometric pressure, water pressure, differential and water
> temperature, so it needed no external reference.

One of four HOBOlink sites, with SR2, River and TR1.

## 2023-08-02 · the base unit is replaced

Base **21171527** gives its last reading at 11:20, with barometric pressure
reading **0.000**. Base **21748925** takes over at 13:05 the same day, carrying
the **same water pressure sensor 21180078**.

> **Established** from the column headers of the two files, which name base and
> sensor separately.
>
> The zero barometric reading on the final row is the old base failing rather
> than a plausible measurement.

Because the sensor was retained, the water level record continues across the
join. The barometric reference does not — it comes from a different instrument
after that date.

## 2024-08-21 · the HOBOlink ends

Last reading 23:55.

> **Established.** By then the U20 had been running alongside it for eleven
> months, so nothing was lost.

---

## 2023-09-13 → 09-19 · a test, with the clock wrong

`21352827` records for six days at **one minute**, 9,043 readings, declaring
**GMT-05:00** where every other file in the archive says GMT-04:00.

> **Established** from the file's own header.
>
> A deployment test, not data. The interval and the timezone are both wrong,
> and the timezone error means these timestamps are an hour out from everything
> else unless taken at face value.

This is the single strongest argument for reading the offset from the file
rather than assuming the project timezone.

## 2023-09-19 · `SR1_low` goes in

**`SR1_low`** (21352827) at 15:48, ten minute interval, alongside the still
running HOBOlink.

> **Established.**

## 2023-10-28 · `Backup` joins it

**`Backup`** (21352826) at 08:22, ten minutes. For four months SR1 carried
**three** loggers: the HOBOlink, `SR1_low` and `Backup`.

> **Established** from the three records' overlapping spans.

> **Inferred** that the two U20s were a deliberate redundancy against the
> HOBOlink, whose counterparts at TR1, SR2 and River all failed within the
> following year. The naming — `Backup` — says as much.

## 2024-02-23 · `SR1_low` is removed

`21352827` gives its last reading at 14:58 and never appears again — not in any
later file, not in VI-FLO, not in current metadata.

> **Established** that the record ends there.

It was taken out deliberately: `Backup` sat in the better position of the two,
and keeping one logger in a good spot was preferable to two in indifferent ones.

> **Inferred** from the circumstances and consistent with a clean end at a
> visit rather than mid-record.

The removal coincides with the hardening of the stream gauge housings across
the network — deeply driven rebar and hose clamps replacing the earlier
arrangements. The substandard housings of the preceding period are what cost
Reef Bay its gauge and Fish Bay its upstream logger.

---

## A corrupted file

**`sr1backup_hydro_20230919-20231128.csv` holds two loggers' readings under one
header and must not be imported.**

```
8,039 rows   21352827   2023-09-19 → 2023-11-14 11:28
2,023 rows   21352826   2023-11-14 11:42 → 2023-11-28 12:42
```

> **Established.** The header declares only 21352827. The line numbering
> restarts mid-file and the timestamp offset shifts from :x8 to :x2 at the
> join. 2,019 of the later rows match `21352826`'s own export exactly.

Device-keyed naming cannot catch this, because the header lies. Ingesting it
would attribute two thousand of `Backup`'s readings to `SR1_low`.

**Nothing is lost by discarding it.** Every reading it holds exists in
`sr1low_hydro_20230919-20231128.csv` or `sr1backup_hydro_20231028-20231128.csv`.

> **Established** — zero of its readings are unique to it.

---

## 2024-02-23 → present · `Backup` alone

Offloaded 2024-05-06, 2024-08-23, 2024-09-13, 2025-01-07, 2025-03-03, then into
the VI-FLO era.

### It filled its memory twice

```
2025-08-01   21,694 readings, offloaded 2025-09-03    ~1 month lost
2026-02-01   21,695 readings, offloaded 2026-03-02    ~1 month lost
```

> **Established** from the reading counts, which sit at the U20's capacity in
> both cases. Ten minute logging fills in 150 days; metadata declared fifteen,
> which would have been 225.

### 2026-08-28 · corrected

Relaunched at **fifteen minutes** and renamed from `Backup` to `sr1`.

> **Established** from the maintenance log: *"relaunched as sr1 and corrected
> interval to 15 minutes from 10"*.

---

## Gaugings

Salt River has ten measured discharges, more than any other site. Jolly Hill is
the only other gauged location, with five.

```
SR1   level 0.3478   q 0.2352    undated
SR1   level 0.1822   q 0.2152    undated
SR1   level 0.1063   q 0.0265    undated
SR1   level 0.1256   q 0.0169    undated
SR1   level 0.2023   q 0.1774    undated
SR1   level 0.1913   q 0.1750    undated
SR1   level 0.01     q 0.0021    undated
SR1   level 0.01     q 0.0034    undated
SR1   level 0.1185   q 0.0610    2024-08-14 14:15   TS Ernesto
SR1   level 0.1115   q 0.0530    2024-08-14 14:45   TS Ernesto
```

> **Established** from the October 2024 `qfits.csv`, which pairs each gauging
> with the stage at the moment of measurement — the rating curve's calibration
> points. `qcurves_meta.csv` records the Ernesto additions as `qcurves10`.

**The curve is still unconstrained at storm stages.** The largest SR1 gauging
is 0.235 m³/s at 0.348 m, against an overbank threshold of 2.335 m. Even the
Ernesto measurements were taken on a modest limb.

That is a safety constraint rather than an oversight: wading a gut at high flow
is not something to do, and how the upper curve gets constrained is a question
for later.

**The gauging record is being handled separately from these site
reconstructions.** Much of the raw FlowTracker output is lost, and some of the
earlier measurements were made with a different instrument altogether — so the
instrument is a property of each measurement rather than of the collection.
That is a question for the discrete data work, not for this dossier.

## Geometry

```
bed gradient    1.63%      slopedata.csv, 14 points over 24.3 m - the densest
                           survey in the network
roughness       0.15       roughness.csv
cross sections  3 reps     gutsurveys.csv
elevation       69.04 m    3DEP lookup
overbank        2.335 m
```
> The maximum stage in the prototype archive sits below this, so nothing was
> clipped at SR1. Salt River 2 and Fish Bay were.

> **Established.** Metres horizontally, rod readings in feet, with the 0.3048
> conversion applied.
>
> Fourteen survey points, more than any other site, and the rod readings fall
> monotonically downstream throughout — unlike Adventure, Jolly
> Hill or Reef Bay. This is the most trustworthy slope survey in the archive.

`discharge_debug.R` gives 21.361 m with a fall of 0.9388 m, or 4.39%, which does
not reconcile.

> **Unknown**, as at the other sites. `slopedata.csv` is preferred.

`elevs.csv` records **no** elevation difference for SR1 — it was a HOBOlink site
with its own barometer — but **-65 m** for `SR1_backup`, the U20 that needed an
external reference.

---

## What follows

### Metadata — the deploy date is wrong

```
21352826   sr1_hydro, deploy_datetime 2021-11-24 14:30
```

**That is the HOBOlink's first reading, not this logger's.** `21352826` did not
record at SR1 until 2023-10-28 08:22.

> **Established** by comparing the metadata row against the file boundaries.

As it stands, attribution would assign two years of HOBOlink readings to a U20
that was not there. Three rows are needed where there is one:

```
21171527 / 21180078   HOBOlink base 1,  2021-11-24 → 2023-08-02
21748925 / 21180078   HOBOlink base 2,  2023-08-02 → 2024-08-21
21352827              SR1_low,          2023-09-19 → 2024-02-23
21352826              Backup / sr1,     2023-10-28 → present
```

The HOBOlink is the only non-HOBO, non-Meter device in the network and may not
fit the existing `mfger` and `model` conventions. The same applies at SR2, TR1
and River.

### Maintenance entries

The VI-FLO era is recorded. These predate it:

```
2021-11-24   station_established   HOBOlink deployed, base 21171527
2023-08-02   device_replaced       base replaced by 21748925, sensor retained
2023-09-19   device_deployed       SR1_low (21352827) added at 10 minutes
2023-10-28   device_deployed       Backup (21352826) added at 10 minutes
2024-02-23   device_removed        SR1_low last reading; fate unrecorded
2024-08-21   device_removed        HOBOlink last reading
2025-08-01   logger_memory_full    Backup filled after 150 days; ~1 month lost
2026-02-01   logger_memory_full    filled again; ~1 month lost
```

### Product 1

```
21171527/21180078   1 file    2021-11-24 → 2023-08-02   (HOBOlink, 5 min)
21748925/21180078   1 file    2023-08-02 → 2024-08-21   (HOBOlink, 5 min)
21352827            3 files   2023-09-13 → 2024-02-23   (one is a 1-minute test)
21352826            7 files   2023-10-28 → 2025-03-03
21352826                      2025-03-03 → present      (already in VI-FLO)
```

**Do not import** `sr1backup_hydro_20230919-20231128.csv`.

`SR1_level.csv` in the older downloads folder duplicates the first HOBOlink file
at five minutes and can be left.

### `record_confirmed`

**2021-11-24**, reason: *device history reconstructed from file headers, base
unit serials and import scripts; see docs/backfill/sr1_hydro.md*.

---

## Open

- `21352827`'s removal is inferred rather than logged. The record ends cleanly
  at a visit, which supports it, but nothing states it.
- Whether the HOBOlink's **computed water level** or its raw pressures should
  feed Product 2. The export carries both, and the decision applies to SR2, TR1
  and River as well.
- The barometric reference changes instrument on 2023-08-02 while the water
  sensor does not, so any correction derived from one base does not carry to
  the other.
- The 1-minute test file declares GMT-05:00. Either it is an hour out or the
  clock was simply set wrong; nothing distinguishes the two.
