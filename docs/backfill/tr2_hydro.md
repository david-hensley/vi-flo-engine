# Turpentine Run 2 — backfill reconstruction

`tr2_hydro` · watershed Turpentine Run, St Thomas · reconstructed October 2026

**Decommissioned 2024-10-22.** A short, clean record from the one site in the
network that is not a natural channel.

Reconstructed from the loggers' own records, the HOBOware launch titles, the
per-site R scripts, and the field notes. Each claim is graded. **Established** —
the data or the code says so directly. **Inferred** — the best reading of
circumstantial evidence. **Unknown** — not recoverable.

---

## The site

A square open concrete channel. That single fact separates it from every other
gauge here.

> **Established** by its roughness value. `roughness.csv` assigns 0.15 to nearly
> every site; only Dorothea (0.20, boulders) and **TR2 at 0.017** were
> considered individually. 0.017 is the textbook Manning's *n* for finished
> concrete.

```
bed gradient    0.24%      slopedata.csv, 62.7 m span, 0.152 m fall
roughness       0.017      finished concrete
cross sections  3 reps     gutsurveys.csv
overbank        3.588 m
```
> The maximum observed stage sits below this, so nothing in the record has been
> clipped.

> **Established.** Horizontal distances are metres and vertical rod readings are
> feet; the gradient applies the 0.3048 conversion.
>
> Only **two** survey points exist for TR2 — one 31.4 m upstream, one 31.3 m
> downstream — against seven or more at other sites. Enough for a gradient
> across the reach, not enough to describe its profile.

**A prismatic channel of known geometry and known roughness needs no paired
logger.** Manning's uniform-flow assumption, which elsewhere is an
approximation, is close to exact here: the bed slope *is* the friction slope in
a straight concrete rectangle. TR2 is the one site where discharge from a single
stage record stands on its own.

Weather comes from the TR1 station.

> **Established.** `site.correspondence.csv` pairs `tr2` to `tr1`, and the TR1
> import script notes "The TR1 weather station serves as the weather station for
> TR2 as well".

---

## 2023-06-14 · deployed

**`TR2`** (21652376) at 14:20, ten minute interval. A single gauge; the site
never had a pair.

> **Established.** First file 2023-06-14 14:20.

Offloaded on 2023-09-26, 2023-10-09, 2023-11-15, 2024-02-04, 2024-06-04 and
2024-10-22.

> **Established** from the file boundaries. The same trips that served Dorothea
> and, a day later, St John.

---

## 2024-10-22 · closed, and the logger moved to TR1

Last reading at **13:10**. Six minutes later the same serial begins recording at
Turpentine Run 1 as `tr1slope`, relaunched at fifteen minutes.

> **Established.** `21652376`'s TR2 record ends 2024-10-22 13:10; its TR1 record
> begins 13:16 the same day. `21652374` joins it at 13:20.

The housing had been compromised, and the logger was taken out and redeployed
rather than replaced.

> **Inferred.** The site was closed on the same visit that equipped TR1 with a
> pair, and the logger itself was not retired — it went straight into the new
> installation.

`site.status.csv` from the prototype era records `tr2, hydro, abandoned`.

> **Established.**

---

## What was not processed

The archive stops before the record does.

> **Established.** `tr2.hydro.rda` covers 2023-06-14 to 2024-06-04. The final
> file — 2024-06-04 to 2024-10-22, 20,153 readings — exists in raw form and was
> never imported. The site was closed at the visit that produced it.

That file is the last four and a half months of Turpentine Run 2 and has never
been through any pipeline.

---

## What follows

### Metadata

```
21652376   TR2, 2023-06-14 14:20 → 2024-10-22 13:10
           then tr1_hydro from 2024-10-22 13:16
```

The station needs a row for its deployment and a terminal row at
decommissioning. `21652376`'s move to `tr1_hydro` must be recorded as a
relocation of the device, not a new deployment, or its TR2 readings will
attribute to TR1.

Station type is `hydro`; the site is retired.

### Maintenance entries

```
2023-06-14   station_established     TR2 gauge deployed in the concrete channel
2024-10-22   station_decommissioned  housing compromised; logger moved to TR1
```

### Product 1

```
21652376    6 files   2023-06-14 → 2024-10-22
```

The sixth has never been processed.

### What this reconstruction covers

`tr2_hydro` is reconstructed from **2023-06-14** — its deployment — to the
present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- Only two survey points exist, so the gradient is a straight line between them
  rather than a fitted profile. For a concrete channel that is probably enough.
- Whether the housing failure was observed at the 2024-10-22 visit or earlier.
  The record shows no disturbance, so the logger was still reading correctly
  when it came out.
