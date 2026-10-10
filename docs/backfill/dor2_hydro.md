# Dorothea — backfill reconstruction

`dor2_hydro` · watershed Dorothea, St Thomas · reconstructed October 2026

What the station's history appears to have been, and what supports each part of
it. Reconstructed from the loggers' own records, the HOBOware launch titles, the
per-site R scripts, and the field notes.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable from what survives.

Dorothea is the steepest reach in the network — a bed gradient of 3.4%, large
boulders with water pooling among them, and 5.8% between the two loggers
themselves. That shapes everything here, including how they were lost.

---

## 2023-06-14 · a single gauge

**`Dorothea`** (21652381) deployed at 12:38, ten minute interval.

> **Established.** First file 2023-06-14 12:38.

Offloaded on 2023-10-09, 2023-11-15, 2024-02-04, 2024-06-04 and 2024-10-22.

> **Established** from the file boundaries.

---

## 2024-02-01 → 02-04 · a slope partner

**`Dorothea`** (21652372) launched at a desk on 1 February at **17:49** and
deployed on **4 February at 14:05**, upstream of and above the existing gauge.

> **Established.** The import script records the activation time, and the
> temperature trace confirms it:
>
> ```
> 1–3 Feb    daily swing 2.1–3.0 °C      indoors
> 4 Feb      swing 15.7 °C, peak 38.7    carried to the site in the sun
> 5 Feb on   swing 0.6–1.3 °C            settled in water
> ```
>
> The post-deployment swing of under 1 °C is the smallest of the three sites
> paired that week — consistent with a logger sitting in a pool rather than in
> moving shallow water.

One coordinated deployment across three sites, launched together on the bench:

```
17:40   21179105   Fish Bay
17:44   21652377   Reef Bay
17:49   21652372   Dorothea
```

Dorothea went into the water first, on 4 February; Reef Bay and Fish Bay the
following day at 09:30 and 12:05.

> **Established** from the launch timestamps and each site's import script.

### The survey

```
distance    9.083 m        partner upstream of the gauge
height      0.524 m        partner above it — recorded as (5.3 − 3.58) × 0.3048
                           so measured in feet and converted
gradient    5.8%           between the two loggers
```

> **Established** from `dor_2024-08-08.R`. Positive signs, which that code's
> convention defines as upstream and above — the opposite arrangement to Fish
> Bay, where the partner went in downstream.

### And it worked

Dorothea was the first site where a paired slope relationship was successfully
derived and used. Fish Bay followed.

> **Established.** The August 2024 script fits a piecewise linear model of
> level difference against stage, with breakpoints at 0.12 m and 0.4 m, and
> builds a new rating curve from it. Its own caution is recorded in the source:
> predictions above roughly 1 m of gauge height are extrapolations and
> unreliable.

> **Established.** `slope_models.csv` holds fitted models for `dor` and `fb`
> only, and `qcurves_meta.csv` records `qcurves7` as *"re-ran Dorothea with
> slope model"* and `qcurves8` as *"re-ran FB with slope model"*.

Reef Bay's pair saw no flow at all in the same period and never produced one.

---

## 2024-06-04 · the partner's last offload

`21652372` has no reading after 11:59 on 2024-06-04 and no later file.

> **Established.**

Whether it was still recording after that is unknown. The slope model had been
built from February–June data by August, so the partner's output was no longer
needed for processing and may simply not have been imported.

> **Unknown.**

## 2024-10-22 · the gauge's last offload

`21652381` last reads at 16:08. The October script notes nothing unusual —
*"nothing to note"* — and makes no mention of the partner.

> **Established.**

---

## 2024-11-11 · both lost

> **Inferred**, and firmly. The 2024-10-22 script is headed *"Water level
> loggers were lost sometime after 2024-10-22, so this is the last hydro data
> import till they are replaced."*
>
> 11 November 2024 was a major regional storm. Turpentine Run, on the same
> island, rose **2.03 m**; Reef Bay rose 1.2 m and Fish Bay about 1.72 m from
> its raw pressure record, the largest event in its four years. Dorothea
> recorded **78.1 mm** of rain that day, following 79 mm on 6 November.
>
> At Dorothea one logger is known to have been crushed beneath a shifted
> boulder and never recovered — a steep reach of large boulders and pooled
> water is precisely where that happens.

---

## 2025-11-05 · rebuilt

Two entirely new sensors installed, replacing both losses. **22373551** and
**22373554**.

> **Established** from the field notes: *"I proceeded to Dorothea, where both
> water level loggers have been destroyed previously and installed entirely new
> sensors, which were also not surveyed yet."*

Positions recorded in the notes: one *"at the base of the climb down in the
large pool just before the bridge"*, the other *"near the pool in the middle of
the run before the top near the man's house — not in the lowest point because of
rocky soil that prevented a rebar drive"*.

The notes also propose establishing gauge zero-flow from the height of the
concrete slab under the bridge, so that stage below it is not counted as
throughflow.

## 2026-03-23 · still unsurveyed

The installations are stable — *"New installations worked well, no apparent
problems with stability. A bit of biofouling on bottom sensor's hole in top of
cap."* But the pair has no survey.

> **Established.** The notes of that date: *"Still no opportunity to survey the
> GZF or relative elevations of TR1 and Dor stream gauges."* The November 2025
> notes list what is needed — a ranging laser, a tripod and a surveying stick.

Until then the new pair cannot give a hydraulic slope, and discharge rests on
the bed-slope assumption.

---

## Geometry

```
bed gradient    3.41%      slopedata.csv, 7 points over 20.2 m around the gauge
roughness       0.20       roughness.csv — one of only two non-default values
cross sections  3 reps     gutsurveys.csv, 12 points each
overbank        5.000 m
```
> A round 5.0 m, shared with Turpentine Run 1 and River, which reads as a
> placeholder rather than a surveyed bank height. Nothing in the record
> approaches it.

> **Established.** Roughness is 0.15 at nearly every site; Dorothea at 0.20 and
> TR2 at 0.017 are the only two that were considered individually, which fits a
> boulder-strewn steep channel.
>
> **Horizontal distances are metres and vertical readings are feet.** The
> gradient applies the 0.3048 conversion; taken raw the same points give 11.2%.
> The corrected figure sits consistently with the 5.8% measured directly between
> the two loggers in 2024, which was itself written as `(5.3 − 3.58) × 0.3048`.
>
> Dorothea remains the steepest reach in the network by some margin.

The 2024 pair's survey does **not** transfer to the new one. The positions
differ, and the notes say so directly.

---

## What follows

### Metadata

```
21652381   gauge,   2023-06-14 → 2024-10-22, lost
21652372   partner, 2024-02-04 → 2024-06-04 (last offload), lost
22373551   from 2025-11-05
22373554   from 2025-11-05
```

Neither lost logger has a row in current metadata. Without them their readings
attribute to no station.

The 2024 pair's `reach_length_m` of 9.083 and elevation difference of 0.524 m
belong to those two serials and that period — not to the current pair.

### Maintenance entries

```
2023-06-14   station_established   Dorothea gauge deployed
2024-02-04   device_deployed       slope partner added, 9.083 m upstream
2024-11-11   device_removed        both lost in the November storm
2025-11-05   device_deployed       two new sensors, positions unsurveyed
```

### Product 1

```
21652381    5 files   2023-06-14 → 2024-10-22
21652372    1 file    2024-02-01 → 2024-06-04
```

### `record_confirmed`

**2023-06-14**, reason: *device history reconstructed from launch titles, import
scripts and field notes; see docs/backfill/dor2_hydro.md*.

---

## Open

- Whether `21652372` recorded between 2024-06-04 and its loss. No file exists
  and the logger was never recovered.
- The exact date of the loss. The November storm is the strong candidate but
  nothing was in the water to record it, and the next visit was a year later.
- The current pair is unsurveyed. Until a ranging laser gets to the site, the
  only hydraulic slope Dorothea has ever had belongs to a pair that no longer
  exists.
- The barometric correction for this gauge comes from its weather station's
  elevation and its own, both in metadata. The prototype used a fixed -148 m,
  which VI-FLO does not inherit.
