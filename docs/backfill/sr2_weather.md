# Salt River 2 weather — backfill reconstruction

`sr2_weather` · watershed Salt River, St Croix · reconstructed October 2026

**The oldest station in the network.** It began recording on 13 July 2021, four
months before the Salt River 2 stream gauge and three months before anything
else, under the name `Glynn Weather`.

It is also the only weather station to have been physically moved, in September
2026, which divides its record into two places.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2021-07-13 · `Glynn Weather`

**z6-12866** with an ATMOS 41, deployed at 13:15 AST at 17.75360, -64.77554,
elevation 26.14 m.

> **Established** from metadata. The processed archive's first reading is
> 2021-07-13 17:15 UTC — the same moment, which confirms the archive is kept in
> UTC and metadata in local time.

The name is a place rather than a station code: Glynn, the estate the site sits
in. Every other station in the prototype carried a site abbreviation.

---

## 2021-07-13 → 2025-06-30 · the cleanest weather record in the network

139,012 rows. Rainfall by year:

```
2021     646 mm   (from 13 July)
2022    1097 mm
2023     709 mm
2024    1468 mm
2025     493 mm   (to 30 June)
```

> **Established** from `sr2.weather.rda`.

**Only nine days of it were ever substituted.**

> **Established** from `splices.csv`: a single `neighbor.atmos` window from
> 2024-11-09 12:00 to 2024-11-18 18:00, covering pressure, radiation,
> temperature, humidity and wind.
>
> SR1's equivalent runs to roughly eighteen months. This station simply worked.

### Its rainfall was checked against satellite

Several suspicious periods in 2021 were verified rather than altered.

> **Established.** `splices.csv` records `type = check` entries with methods
> `NASA.GPM` and `no.change` across August and September 2021, and the import
> script describes them as *"checks of suspicious periods that do not agree with
> neighboring rain gauges"*.
>
> These are not substitutions. They record that a disagreement was noticed,
> investigated against GPM satellite rainfall, and in four cases resolved as
> `no.change` — the gauge was right.

That is a third kind of entry in the prototype's splice record, alongside
processing choices and evidence of physical history: evidence that someone
looked and judged.

---

## Access was lost, and the rain record degrades

At some point in the later part of the record the ZL6 became unreachable: the
private property it stood on was sold and there was no contact with the new
owners. The ATMOS went unmaintained for a long period as a result, and that is
ultimately why the station was moved.

> **Established** by the person who ran it. No document records the sale or the
> date.

**The rainfall record shows it plainly.** Interventions in the precipitation
series, by month:

```
2021-2023     2 to 9 per month, normal
2024-04      18
2024-08      18      onset
2024-09      28
2024-10      30
2024-11     140
2024-12     436
2025-01     126
```

> **Established** from `splices.csv`. The 2024 total is 705 against 32 in 2023
> — 489 interpolated gaps, 48 automatic zeroings and 147 periods flagged as
> disagreeing with neighbouring gauges.

The collapse coincides with the wettest months of the period, which is what a
clogged or failing gauge does: the more rain falls, the less of it is recorded.

**Treat the precipitation record from mid-2024 as suspect**, and increasingly so
through to the relocation. The other variables — temperature, humidity, wind,
radiation — have no moving parts and no intake to block, so they are less
affected.

> **Inferred.** The splice record intervenes almost entirely on precipitation in
> this period, which supports it, but nothing confirms the other variables are
> sound.

After January 2025 the interventions stop while the data continues.

> **Unknown** whether the gauge had ceased producing anything worth correcting
> or the final import simply stopped doing fine-grained QA.

---

## 2026-09-16 · relocated and re-equipped

Three things happened in one visit, ending roughly two years of no access:

```
station relocated    17.75360, -64.77554   ->   17.75424, -64.77215
device replaced      z6-12866              ->   z6-37440
SIM swapped          to AT&T
```

> **Established** from the maintenance log, which records all three separately.

The move is about **370 m** east and 7 m down — elevation 26.14 m to 19.19 m.

> **Established** by computing from the recorded coordinates.

**The record before and after this date is from two different places.** The
entire prototype archive, and everything through to September 2026, belongs to
the Glynn position. Anything that treats the series as continuous across that
date is treating two sites as one.

> That is a Product 2 concern: the station id is the same, the position is not,
> and the deployment windows in metadata are what separate them.

The new device is an **ATMOS 41 G2**, a later model than the original, and it
also carries four TEROS 10 sensors establishing `sr2_vwc3` — see `sr2_vwc.md`.

> **Established** from the port record.

---

## Barometric reference

The station sits at 26.14 m in its original position and 19.19 m in the new one,
against a gauge at 5.55 m.

The prototype used a fixed **-5 m** for this pair, which matches neither
elevation difference. That is its number, derived its own way, and VI-FLO does
not inherit it: the correction is computed from the two stations' recorded
elevations, which each deployment window carries.

> Worth knowing only because the prototype's processed pressure series for SR2
> was built on it, and will differ from anything VI-FLO derives.

---

## What follows

### Metadata

```
z6-12866   sr2_weather, Glynn position, 2021-07-13 13:15 -> 2026-09-16, relocated
z6-37440   sr2_weather, new position,   from 2026-09-16 12:00   ATMOS 41 G2
z6-37440   sr2_vwc3,                    from 2026-09-16 12:00   TEROS 10 x4
```

Both rows are correct and the relocation is properly recorded — this station is
the best-documented transition in the network, because it happened after the
metadata manager existed.

### Maintenance entries

The 2026 relocation is logged in full. Nothing earlier exists, and the reason is
not that the station needed nothing — it is that it could not be reached.

```
2024-??-??   access_lost   property sold; station unreachable until 2026-09-16
```

The date is unknown. The rainfall record suggests the consequences begin around
August 2024, but the loss of access may predate the first visible effect by
months.

### Product 1

Already complete for both devices.

### `record_confirmed`

**2021-07-13**, reason: *continuous record from deployment, minimal
substitution, relocation in 2026 fully logged; see docs/backfill/sr2_weather.md*.

The station's own measurements run nearly unbroken from the oldest deployment
VI-FLO holds. But `record_confirmed` is about whether the metadata is
contemporaneous, not whether the data is good — and the precipitation series
from mid-2024 is not good. That belongs in QA, flagged at Product 3, rather than
in this date.

---

## Open

- Whether the pre- and post-relocation series should carry the same station id
  at Product 2, or be separated. Metadata's deployment windows make either
  possible.
- `z6-12866` was relocated rather than retired. Where it went is not recorded in
  this station's history.
- The date access was lost. It governs how far back the precipitation record
  should be treated as suspect, and only the rainfall statistics suggest it.
