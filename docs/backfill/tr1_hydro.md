# Turpentine Run 1 — backfill reconstruction

`tr1_hydro` · watershed Turpentine Run, St Thomas · reconstructed October 2026

Two distinct eras: a HOBOlink telemetry station that died in a hurricane, and a
pair of U20s installed two months later at a different position. The change of
position is the central fact — it invalidates the rating curve across the join.

Reconstructed from the loggers' own records, the HOBOware launch titles, the
per-site R scripts, and the field notes. Each claim is graded. **Established** —
the data or the code says so directly. **Inferred** — the best reading of
circumstantial evidence. **Unknown** — not recoverable.

---

## 2023-06-13 · the HOBOlink era

A HOBOlink station — base unit 21769001 with water-pressure sensor 21751136 —
recording at **five minutes** from 16:35.

> **Established.** First reading 2023-06-13 16:35. The export carries its own
> barometric pressure, water pressure, differential, water temperature and a
> computed water level, so it needed no external barometric reference.

This is one of four HOBOlink sites, with SR1, SR2 and River.

> **Established** from the old import pipeline: *"Hobolink sites = SR1, SR2,
> River, TR1"*.

TR1 also carries the weather station that serves both Turpentine sites.

> **Established.** The import script: *"The TR1 weather station serves as the
> weather station for TR2 as well."*

---

## 2024-08-14 · Hurricane Ernesto

The station dies at **12:15**.

> **Established.** The August 2024 import script: *"logger dies in Ernesto,
> 2024-08-14 12:15:00"*, and it trims the record there. The comment on the
> plotted series reads *"Looks good till it died in the storm!"*
>
> The raw export continues to 2024-08-21 23:55 — a week of readings after the
> death, which the trim discards.

---

## 2024-10-22 · two U20s, at a new position

Installed on the same visit that closed Turpentine Run 2, both at fifteen
minutes:

```
13:16   21652376   'tr1slope'   downstream   — carried from TR2 six minutes earlier
13:20   21652374   'tr1'        upstream
```

> **Established** from the file boundaries. `21652376`'s TR2 record ends at
> 13:10 the same afternoon.
>
> **Established** that `21652376` is the downstream one: its dry-weather floor
> sits 0.44 kPa — about 4.5 cm — deeper than `21652374`'s throughout, and
> current metadata assigns it `primary`, which the dictionary defines as the
> downstream logger.

**The pair does not sit where the HOBOlink sat**, which breaks the rating curve
across the join.

> **Established.** The 2025 import script is headed: *"This import code produced
> an erroneous dataset because of a moved logger. We will require a survey of
> new TR1 and TR1_slope logger to get new qcurve."*

Both loggers are deeply and permanently submerged — dry-weather floors of 102.8
and 103.2 kPa against roughly 101.3 at atmospheric.

> **Established.** Turpentine Run carries water continuously, unlike the
> ephemeral guts elsewhere in the network. The field notes describe *"majorly
> polluted, blackish gray water entering the stream channel from a tributary
> originating in Tutu Plaza Mall"* and the smell of sewage.

---

## 2024-11-11 · the storm that took the others

A rise of **19.87 kPa — about 2.03 m**, the largest in the pair's record.

> **Established** from the raw pressure record.

The same day gave Fish Bay 1.497 m and Reef Bay 1.2 m, and is the likely end of
both the Reef Bay gauge and the Dorothea pair. The Turpentine loggers, installed
three weeks earlier, survived it.

---

## 2025-11-05 → 2026-03-23 · still there, still unsurveyed

Both intact, zip ties replaced with hose clamps.

> **Established** from the field notes of 2025-11-05: *"Turpentine Run had both
> water level loggers intact from the last visit with an unknown surveying
> slope, but two loggers intact and data was successfully downloaded."*

Still no survey as of March 2026, and a logjam has formed.

> **Established.** The March 2026 notes: *"Still no opportunity to survey the
> GZF or relative elevations of TR1 and Dor stream gauges"*, and *"Logjam just
> above upstream logger still present."*
>
> The November 2025 notes list what is needed — a ranging laser, a tripod and a
> surveying stick — for both Turpentine and Dorothea.

So the pair has recorded for two years without the measurement that would let it
produce a hydraulic slope.

---

## Geometry

```
bed gradient    0.33%      slopedata.csv, 7 points over 41.6 m
roughness       0.15       roughness.csv, the network default
cross sections  3 reps     gutsurveys.csv, 12 points each
```

> **Established.** Metres horizontally, rod readings in feet; the gradient
> applies the 0.3048 conversion.
>
> The survey points describe the **HOBOlink's** position, not the 2024 pair's.
> How far they transfer depends on how far the pair was moved, which is not
> recorded.

Discharge therefore rests on the bed-slope assumption for both eras, with the
added uncertainty that the geometry was surveyed around a position no logger now
occupies.

---

## What follows

### Metadata

```
21769001 / 21751136   HOBOlink, 2023-06-13 → 2024-08-14, destroyed in Ernesto
21652374              upstream,   from 2024-10-22 13:20
21652376              downstream, from 2024-10-22 13:16 — relocated from TR2
```

The HOBOlink has no row in current metadata and needs one, including its
destruction. It is the only non-HOBO, non-Meter device in the network and may
not fit the existing `mfger` and `model` conventions.

`21652376` arrives from `tr2_hydro` and must be recorded as a relocation, or its
TR2 readings will attribute here.

### Maintenance entries

```
2023-06-13   station_established   HOBOlink telemetry station deployed
2024-08-14   device_removed        destroyed in Hurricane Ernesto
2024-10-22   device_deployed       21652374 upstream
2024-10-22   device_deployed       21652376 downstream, relocated from TR2
2025-11-05   maintenance           zip ties replaced with hose clamps on both
```

### Product 1

```
21769001/21751136   1 file    2023-06-13 → 2024-08-21   (HOBOlink, 5 min)
21652374            1 file    2024-10-22 → 2025-06-03
21652376            1 file    2024-10-22 → 2025-06-03
21652374, 21652376            2025-06-03 → 2025-11-05   (November 2025 readout)
```

The HOBOlink export has a different shape again — seventeen columns including
its own barometric and a computed water level — and needs its own reader.

### `record_confirmed`

**2023-06-13**, reason: *device history reconstructed from import scripts, file
boundaries and field notes; see docs/backfill/tr1_hydro.md*.

---

## Open

- The HOBOlink export carries a **computed water level** alongside raw pressures.
  Whether to take that or recompute from the pressures is a decision the Product
  2 work will have to make, and it applies to SR1, SR2 and River as well.
- The 2024 pair's position relative to the HOBOlink's is unrecorded, so the
  surveyed geometry transfers by assumption rather than measurement.
- The pair is still unsurveyed. Until then Turpentine Run has never produced a
  measured hydraulic slope, despite having had two loggers for two years.
- Water quality at this site is poor enough that the field notes record
  minimising contact. Worth bearing on any plan requiring in-channel work.
