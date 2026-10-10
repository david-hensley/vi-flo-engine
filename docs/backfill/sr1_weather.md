# Salt River 1 weather — backfill reconstruction

`sr1_weather` · watershed Salt River, St Croix · reconstructed October 2026

A ZL6 with an ATMOS 41 on the ridge above Salt River 1, named `DiscoveryG
Weather` after Discovery Gut. In September 2026 a four-depth soil moisture
profile was added to the same box, establishing `sr1_vwc3` — see `sr1_vwc.md`
for that station and the others at this site.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## The deploy date is inherited, not observed

Metadata records **2021-11-24 14:30** for both the station and its ATMOS port.
That is the minute the Salt River 1 **stream gauge** began recording — the same
inherited timestamp that appears on `sr1_hydro`'s U20 and on `sr2_hydro`'s.

> **Established.** `sr1_hydro`'s HOBOlink starts at 2021-11-24 14:30 exactly.
> Three devices at two stations carry that timestamp, and only one of them was
> there.

**The weather station produced nothing until 13 September 2022.**

> **Established** from `splices.csv`. Every weather variable at SR1 —
> precipitation, radiation, temperature, humidity, wind and pressure — is marked
> `neighbor.atmos` from 2021-11-24 14:30 to 2022-09-13 12:45. The prototype
> filled ten months from another station because this one had nothing to give.
>
> The first reading the ATMOS itself produced is **2022-09-13 13:00**.

So the station's real deployment is somewhere on or before that date, and the
2021 timestamp is a filing artefact rather than a record of an installation.

> **Unknown** exactly when the ATMOS went up. The data begins mid-afternoon on a
> Tuesday, which reads like a deployment rather than a resumption, but nothing
> states it.

---

## 2022-09-13 → present · the station's own record

ATMOS 41 on port 1, the only sensor on the box for four years.

> **Established** from the port record.

Rainfall from the processed archive:

```
2022    1244 mm
2023    1123 mm
2024    1549 mm
2025     476 mm   (to 30 June)
```

> **Established** from `sr1.weather.rda`, which runs to 2025-06-30. Note that
> parts of this are not SR1's own measurements — see below.

### Barometric pressure was almost never its own

> **Established** from `splices.csv`. Pressure is marked `neighbor.atmos` from
> 2022-09-13 to 2024-09-23, and again from 2025-01-07 to 2025-06-30.
>
> Between the ten-month opening gap and those two periods, SR1's pressure series
> in the prototype archive is borrowed for nearly its whole length.

That matters because this station is the barometric reference for the Salt River
gauges. It sits at 122.18 m against a gauge at 69.04 m, so the correction is
substantial.

> The prototype used a fixed -47 m for this pair, which is not the difference
> between those two elevations. VI-FLO computes the correction from the recorded
> elevations instead, so the prototype's figure is noted here only because its
> processed pressure series rests on it.

### Two further substitution periods

```
2024-05-06 → 2024-07-10   all variables, neighbor.atmos
2025-01-08 → 2025-06-30   all variables, neighbor.atmos
```

> **Established** from `splices.csv`. The second is marked `splice` rather than
> `gap`, and the 2025 import script performs it explicitly from UVI's record.

**What this means for VI-FLO.** The prototype substituted freely because it was
serving immediate research. VI-FLO does not: a gap stays a gap through Product
2 and Product 3, and anyone who wants a filled series derives it from P4
themselves, with their own assumptions and their own documentation.

So the VI-FLO record for SR1 weather will be *shorter and emptier* than the
prototype archive, and that is the intended difference rather than a loss.

The substituted series itself is not lost either. The Salt River data as the
prototype assembled it is published with Hensley et al. (2025), *Runoff
generation mechanisms in ephemeral streams of the Virgin Islands*, so the
figures that rest on it remain reproducible from there. Nothing in the prototype
needs to be preserved in VI-FLO to keep that paper whole.

---

## 2026-03-02 · the ATMOS is degrading

*"SR1 weather needed unclogging, it was difficult to remove the cone from the
top, the ATMOS itself is degrading in the sun and maybe cracking. Seems time to
replace this one."*

> **Established** from the field notes.

The March 2026 St Thomas notes record the same of TR1's: *"ATMOS itself appears
to be degrading in the sun similarly to SR1."* Two of the oldest ATMOS units,
failing the same way.

## 2026-09-04 · soil moisture added

Four TEROS 10 at 10, 30, 50 and 100 cm on ports 2 to 5, establishing
`sr1_vwc3` on this box.

> **Established** from the port record, which marks ports 2–5 explicitly as
> `none` until that moment.

This is the colocated design that began at UVI, applied here five years later.

---

## What follows

### Metadata

```
z6-14635   sr1_weather, ATMOS 41 on port 1
           deploy_datetime 2021-11-24 14:30  -- inherited from the stream gauge
z6-14635   sr1_vwc3,    TEROS 10 on ports 2-5, from 2026-09-04 13:09:15
```

**The weather station's `deploy_datetime` should move to 2022-09-13 13:00**, the
first reading it produced. The current value asserts the station existed for ten
months when it did not, and attribution would assign a neighbour's weather to
this device.

The device is 3G and its subscription lapsed in May 2026.

### Maintenance entries

```
2022-09-13   station_established   ATMOS 41 deployed; first reading 13:00
```

Nothing else predates the metadata manager. The 2026 cleaning and the soil
moisture addition are already recorded.

### Product 1

Already complete. This logger is in the ZentraCloud export set.

### `record_confirmed`

**2022-09-13**, reason: *station's own record begins here; the prototype's
earlier weather for this site is borrowed from a neighbour and is not SR1's;
see docs/backfill/sr1_weather.md*.

---

## Open

- The exact deployment date. The record begins 2022-09-13 13:00 and nothing
  states whether the mast went up that day or earlier.
- The ATMOS was flagged for replacement in March 2026 and has not been replaced.
