# Fish Bay — backfill reconstruction

`fb2_hydro` · watershed Fish Bay, St John · reconstructed October 2026

What the station's history appears to have been, and what supports each part of
it. The VI-FLO metadata manager began in 2026; everything here predates it and
is reconstructed from the loggers' own records, the HOBOware launch titles, and
the per-site R scripts that processed the data at the time.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable from what survives.

---

## 2021-10-21 · a pair goes in

Two U20 loggers launched together at 11:11 and deployed the same day:
**`FishBay1`** (21179105) upstream, **`FishBay2`** (21179106) downstream. Ten
minute interval.

> **Established.** Both files begin at 10/21/2021 11:11 with the same cadence —
> launched side by side from one laptop. `FishBay2`'s pressure rises 1 kPa
> between 11:11 and 11:21, the moment it entered the water.

Both loggers are at Fish Bay, though seven of `FishBay1`'s files are named
`RB-*`.

> **Established**, on three grounds. The HOBOware plot title reads `FishBay1` —
> written from the logger's own launch configuration rather than assigned to the
> file afterwards. Mean water temperature agrees with `FishBay2` to **0.018 °C**
> across 10,934 paired readings, which two guts in separate watersheds would not
> do. And the two were launched in the same minute.
>
> Pressure correlation was tested and is *not* evidence: both series are
> absolute pressure, so barometric dominates and any two loggers on St John
> would agree.

---

## 2021-10-21 → 2023-03-31 · both recording

Offloaded on every visit — for a stretch roughly monthly, which is unusual for
St John.

> **Inferred.** Fifteen offloads in eighteen months, at a frequency that implies
> someone based on St Thomas rather than travelling from St Croix.

`FishBay2` never moved in four years.

> **Established.** Its dry-weather baseline holds at 101.2–101.5 kPa across the
> whole 2021–2025 record with no step change. A vertical move would shift it.

---

## 2023-03-31 · `FishBay1` is taken out

Removed deliberately at a scheduled visit, not lost.

> **Inferred, and the strongest reading available.** Its record ends cleanly on
> a visit day, the same day `FishBay2` was offloaded. A logger lost to a flood
> stops when the flood arrives or when its memory fills — not at a visit.
>
> This also accounts for the ten months of silence that follow, with no failure
> to download: a stopped logger records nothing.

---

## 2023-10-04 · Tropical Storm Philippe

Stage 1.465 m, peak discharge 3.78 m³/s at `FishBay2` — the second largest event
in four years. A visit followed five days later.

> **Established** from the processed archive and the file boundaries.

## 2023-10-29 and 11-08 · two more

1.022 m on 29 October, the fourth largest in the record, then 0.682 m on
8 November. Both fall between the 9 October visit and the next on 15 November.

> **Established.**

The upstream housing is thought to have survived Philippe and gone in one of
these, which would explain an intention to survey the original position that
became impossible.

> **Inferred.** Neither event leaves a trace in any logger's record, since
> `FishBay1` was already out of the water.

---

## 2024-02-01 → 02-05 · redeployed, and the pair inverts

`21179105` was relaunched at a desk on 1 February and carried to the site on the
5th, where it went in **downstream** of `FishBay2` — making the original
downstream logger the upstream one. Its title became `FishBay_slope`.

> **Established.** The temperature trace gives the sequence hour by hour:
>
> ```
> 1–3 Feb    daily swing 2.1–2.8 °C      indoors
> 4 Feb      swing 6.1 °C                being moved
> 5 Feb      swing 10.0 °C, peak 34.8    carried to the site in the sun
> 7 Feb on   swing 0.9–2.4 °C            settled in the stream
> ```
>
> The import script records the deployment as **2024-02-05 12:05:00**, the hour
> the temperature begins to spike. The survey written the same year gives
> negative distance and height, which that code's convention defines as
> downstream and below.

Part of a coordinated deployment across three sites.

> **Established.** `21179105` (Fish Bay), `21652372` (Dorothea) and `21652377`
> (Reef Bay) were all launched on 2024-02-01. The hydraulic-slope programme
> began that day.

---

## 2024-02-05 → present · continuous

`21179105` runs unbroken under the title `FishBay_slope` from redeployment to
now: prototype CSVs to 2025-06-05, the November 2025 shuttle readout, and VI-FLO
Product 1 from 2025-11-06.

> **Established.** The serial is written by the logger into every export.

---

## The survey

From `fb_2024-08-20.R`, describing the **current** pair:

```
reach length   50.687 m      FishBay2 (upstream) → FishBay_slope (downstream)
fall            0.253 m      a gradient of 0.5%
```

> **Established.** Declared immediately above `slope.sitename <- "fbslope"` and
> consumed by `create.slope.model()` with that logger's data. The negative signs
> fit only a downstream partner, so it cannot describe the earlier pair.

The 2021–2023 pair has no surveyed geometry.

> **Unknown.** The entire codebase holds distance and height for Fish Bay's 2024
> pair and for Dorothea, and nothing else. Hydraulic slope for the earlier era
> would have to be reconstructed from an empirical stage relationship.

---

## What follows

### Metadata

```
21179105  deploy_datetime    2024-02-05 12:05:00
21179105  reach_length_m     50.687
21179106  elev               primary's elev + 0.253
21179106  reach_length_m     50.687
```

`21179105`'s `elev` of 3.29 should be confirmed as describing its current
downstream position.

Roles as recorded are correct — `21179105` primary because it is downstream,
`21179106` secondary. They were the other way round before February 2024, which
metadata has no way to express.

### Maintenance entries

Structural events only. Routine visits are not recoverable and inventing them
would be dishonest. The lag between `field_visit_date` and `timestamp` shows
these were written later, and `record_confirmed.csv` records that the era was
kept differently.

```
2021-10-21   station_established   FishBay1 and FishBay2 deployed as a pair
2023-03-31   device_removed        FishBay1 removed from the upstream position
2024-02-05   device_deployed       21179105 redeployed downstream, pair inverted
```

### Product 1

```
21179106   15 files   2021-10-21 → 2025-06-05
21179105    3 files   2024-02-01 → 2025-06-05
21179105    7 files   2021-10-21 → 2023-03-31    (filed under RB-*)
```

### `record_confirmed`

**2021-10-21**, reason: *device history reconstructed from launch titles,
temperature correlation and the 2024 import scripts; see docs/backfill/fb.md*.

Defensible from the beginning of the record — but only because this document
exists.

---

## Open

- Whether the upstream housing went in Philippe or in the 29 October event.
  Both fall between visits; neither leaves a trace.
- Whether `FishBay1` recorded anything after 2023-03-31. If stopped at the
  visit, nothing. If it ran on, it filled around 28 August 2023 and the February
  2024 relaunch erased it. No evidence survives either way.
- Fish Bay's entry in `elevs.csv` is **0** — no elevation correction between the
  weather station and the gauge. Either they sit at the same height or it was
  never surveyed.
