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

## 2021-10-21 → 2023-09-26 · both recording

Offloaded on every visit — for a stretch roughly monthly, which is unusual for
St John.

> **Inferred.** Fifteen offloads in two years, at a frequency that implies
> someone based on St Thomas rather than travelling from St Croix.

`FishBay2` never moved in four years.

> **Established.** Its dry-weather baseline holds at 101.2–101.5 kPa across the
> whole 2021–2025 record with no step change. A vertical move would shift it.

### Two of `FishBay1`'s exports are missing

Its archive has holes that `FishBay2`'s does not:

```
2023-03-31 14:17  ->  2023-06-15 14:27     76 days
2023-09-26 15:27  ->  2024-02-01 17:40    128 days
```

Both begin and end on visit days, which is the first sign that these are filing
losses rather than interruptions: a logger that fails stops at an arbitrary
moment, not at 14:17 on an afternoon somebody was standing over it.

**The logger was in the gut throughout the first gap.** Its temperature on
restarting tells us so:

```
                        day 1    day 2    day 3    day 4
FishBay1, 15 Jun 2023    10.1     11.3     14.8     12.0
FishBay2, same days      15.2     12.4     16.4     13.6
FishBay1, 1 Feb 2024      2.1      2.1      2.8      6.1
```

> **Established.** A logger in a dry streambed swings ten to sixteen degrees a
> day, reaching the mid-forties by afternoon. One sitting indoors swings two.
> On 15 June 2023 `FishBay1` behaves like its neighbour from the first reading;
> in February 2024, after four months in an office, it does not.

So it was read on 31 March, restarted the same afternoon, ran through the
spring, and was read again on 15 June. The export covering those weeks is not
in the archive.

> **Unknown** where it went. This logger's files are already scattered across
> two folders under three naming conventions — `RB-2021*` in one place,
> `RB_1.csv` in another, `fbslope_*` in a third. Two going astray is of a piece
> with that.

The second gap is the same story, and is addressed below.

---

## 2023-10-04 · Tropical Storm Philippe

Stage 1.465 m, peak discharge 3.78 m³/s at `FishBay2` — the second largest event
in four years.

> **Established** from the processed archive.

Eight days earlier, on 26 September, both loggers had been read. The readings
from that morning show them **sitting in air**, warming from 28.8 to 30.5 °C
through the morning: the gut was dry a week before the storm put a metre and a
half through it.

> **Established** from the raw record.

### What the storm did

> **Established**, from a message sent a week afterwards — the only
> contemporaneous account of the event:
>
> *"Even one of the water level loggers was destroyed. Well the instrument
> wasn't but the mounting stake was snapped in half and a boulder was on top of
> the pvc housing lol. Had to dig it out."*

The stake snapped, a boulder came to rest on the housing, and the logger itself
survived and was dug out. The visit was on 9 October, five days after the storm,
with water still flowing.

**`FishBay1` is the logger this describes.** `FishBay2` recorded continuously
through Philippe and every visit afterwards; only `FishBay1` goes silent.

> **Inferred**, but with no competing candidate.

### The second missing export

Nothing covering 26 September to 9 October exists anywhere — not as a CSV, not
in the shuttle readouts, not in the `.hobo` binaries.

> **Established** by searching every file of every type in the prototype
> archive for this serial. Eleven files carry it, and none covers that
> fortnight.

Whether the logger was recording when the boulder landed is therefore not
recoverable. It was read and presumably restarted on 26 September, as it had
been at every previous visit; the fortnight containing Philippe is lost either
way.

> That fortnight is the one period at Fish Bay where the upstream logger's
> behaviour during a major flood would have been recorded. It is gone.

## 2023-10-29 and 11-08 · two more

1.022 m on 29 October, the fourth largest in the record, then 0.682 m on
8 November. Both fall between the 9 October visit and the next on 15 November.

> **Established.**

By then `FishBay1` was out of the gut, so neither event was recorded upstream.

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
>
> **Both figures are metres.** Survey work of this period used metres
> horizontally and a rod read in feet, and Dorothea's equivalent carries the
> conversion inline — `(5.3 − 3.58) × 0.3048`. Fish Bay's `-0.253` is a bare
> number because the conversion was done before it was written down. This
> matters: `create.slope.model()` adds `height` to a water-level difference
> already in metres, so a foot reading entered raw would carry through to every
> discharge value the curve produced.

The reach itself was surveyed separately, before the pairs existed:

```
bed gradient    0.40%      slopedata.csv, 6 points over 55.0 m
roughness       0.15       roughness.csv
cross sections  3 reps     gutsurveys.csv
overbank        1.497 m
```
> **The prototype archive is clipped at this value**, as is Salt River 2's. The
> maximum stage in `fb.hydro.rda` equals the threshold exactly, so peaks above
> it were truncated when that archive was built.
>
> **The raw pressure is intact.** The 11 November 2024 event reads about 1.72 m
> from the absolute pressure record against a dry baseline — roughly 22 cm above
> the ceiling. Any peak lost to clipping is recoverable by rebuilding level from
> Product 1, which is the point of regenerating rather than editing.
>
> Whether to clip at all is a Product 3 decision with a declared threshold, not
> something baked into the archive.

> **Established.** Metres horizontally, rod readings in feet, with the 0.3048
> conversion applied. `discharge_debug.R` gives 43.749 m with a fall of 0.067 m
> — 0.15% — which does not reconcile; `slopedata.csv` is the primary survey
> record and is preferred.

That bed gradient is what the pre-2024 era has to rely on, since Manning takes
the friction slope and the bed slope is its conventional approximation.

The 2021–2023 pair has no surveyed geometry.

> **Unknown.** The entire codebase holds distance and height for Fish Bay's 2024
> pair and for Dorothea, and nothing else. Hydraulic slope for the earlier era
> would have to be reconstructed from an empirical stage relationship.

---

## The slope model

The 2024 pair produced a working hydraulic slope relationship, one of only two
in the network.

> **Established.** `slope_models.csv` holds fitted models for `fb` and `dor`
> alone, and `qcurves_meta.csv` records `qcurves8` as *"re-ran FB with slope
> model, includes FB GZF at 0.255m"*.

A **gauge zero-flow of 0.255 m** is recorded with it — the stage below which
there is no throughflow, so discharge is zero regardless of what the curve
would otherwise give.

Fish Bay has never been gauged, so its rating curve rests on geometry,
roughness and the measured slope, with no measured discharge to check it.

> **Established.** `qfits.csv` carries an empty row for FB.

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
these were written later, and the reconstruction span above says how far back
the record reaches.

```
2021-10-21   station_established   FishBay1 and FishBay2 deployed as a pair
2023-10-09   device_removal        FishBay1 recovered after Philippe; stake
                                   snapped, boulder on the housing, dug out
2024-02-05   device_added          21179105 redeployed downstream, pair inverted
```

The 2023-10-09 entry replaces an earlier reconstruction that had this logger
removed on 2023-03-31. That was wrong: it ran until 26 September and its
removal was a recovery, not a decision.

### Product 1

```
21179106   15 files   2021-10-21 → 2025-06-05
21179105    7 files   2021-10-21 → 2023-03-31    filed as RB-2021*, RB-2022*
21179105    1 file    2023-06-15 → 2023-09-26    filed as RB_1.csv, in
                                                 Raw-level/Older_versions
21179105    3 files   2024-02-01 → 2025-06-05    filed as fbslope_*
```

Eleven exports under three naming conventions across three folders, none of
which names the site correctly. The serial in each header is what identifies
them.

**Two exports are missing and are not recoverable**: 2023-03-31 to 2023-06-15,
and 2023-09-26 to 2023-10-09. The second contains Philippe.

### What this reconstruction covers

`fb2_hydro` is reconstructed from **2021-10-21** — the first pair's deployment
— to the present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- Where the two missing exports went. Both are bounded by visit days and the
  logger demonstrably ran across the first of them, so they were made and
  mislaid rather than never taken.
- The barometric correction changed when the weather station moved on
  2024-02-06, from essentially zero to about -210 m. VI-FLO computes it from
  station elevations in metadata rather than from the prototype's `elevs.csv`,
  so the only gap is the weather station's pre-2024 `elev`. See
  docs/backfill/fb1_weather.md.
