# Dorothea weather — backfill reconstruction

`dor1_weather` · watershed Dorothea, St Thomas · reconstructed October 2026

The highest station in the network at 251 m, and the wettest — 2,024 mm in 2024.
One ZL6, one ATMOS 41, deployed June 2023 and complete until it stopped
reporting on 2 October 2026.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2023-06-14 · deployed

**z6-12885** with an ATMOS 41 on port 1, at 09:30 local, at 18.35750, -64.95965,
elevation **251.24 m** — the highest in the network.

> **Established** from metadata and the port record. The first reading in the
> processed archive is 13:30 UTC the same day.

Part of the trip that established the St Thomas network: the Turpentine Run 1
HOBOlink and weather station on the 13th, the Turpentine Run 2 gauge and this
station on the 14th, Dorothea's own gauge the same day at 12:38.

---

## The record

```
2023     685 mm   (from 14 June)
2024    2024 mm
2025     664 mm   (to 30 June, in the prototype archive)
```

> **Established** from `dor.weather.rda`.

2,024 mm makes 2024 the wettest station-year anywhere in the network, against
1,612 mm at Turpentine Run and 1,549 mm at Salt River 1 in the same year. The
elevation and the windward aspect both argue for it being real.

**Completeness is 100% in every full month** from July 2023 to August 2026.

> **Established** from `z6-12885`'s Product 1 export, counting distinct
> timestamps against a 15-minute grid.

The prototype's own record agrees: **71 splice entries in two years**, all
interpolation, with no substitution of any kind.

> **Established** from `splices.csv`. Only Turpentine Run's is cleaner, at 49.

---

## 2026-03-24 · the spring is missing

*"missing spring in funnel, algal growth present"*

> **Established** from the maintenance log, and from the field notes of that
> visit: *"visited Dor weather, sensor in good shape but MISSING SPRING. Small
> amount of algal growth in input hole, golden pins were clear."*

**The spring was also noted missing here in November 2025**, four months before
this visit, and at UVI on 2 March 2026 — *"UVI weather needed unclogging. Spring
is missing"*.

> **Established** from the field notes.

Two units losing the same component, and this one losing it twice, is a pattern
rather than coincidence. It bears on the rainfall measurement at both.

> **Unknown** what the consequence is. Nothing in the completeness record shows
> it, because a rain gauge misreading produces plausible numbers rather than
> gaps. Whether these records need a correction is a QA question with no
> evidence yet either way.

---

## 2026-10-02 · stopped reporting

Last reading **2026-10-02 11:30 UTC**. Nothing since.

> **Established** from the Product 1 downloads, and flagged in the network
> to-do list.

The station is on St Thomas, so a visit is not a short trip, and the next
scheduled one is not before the end of October.

> **Unknown** what stopped it. The subscription lapsed in August 2026, which is
> the first thing to check: a lapsed subscription stops data reaching
> ZentraCloud while the logger keeps recording.

---

## What follows

### Metadata

```
z6-12885   dor1_weather, ATMOS 41 on port 1, from 2023-06-14 09:30
```

Correct and complete. Nothing to add or change.

The device is 3G, one of six still deployed, and its subscription lapsed in
August 2026.

### Maintenance entries

```
2023-06-14   station_established   ATMOS 41 on z6-12885
```

The only reconstructed entry needed. The 2026 visit is already logged.

### Product 1

Already complete to 2026-10-02, where the record stops.

### What this reconstruction covers

`dor1_weather` is reconstructed from **2023-06-14** — its deployment — to the
present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- Why the station stopped on 2 October 2026. The lapsed subscription is the
  first candidate and the cheapest to rule out.
- The missing funnel spring, noted here in November 2025 and again in March
  2026, and at UVI in between. Its effect on the rainfall record is unknown and
  would not show as a gap.
- The 2024 total of 2,024 mm is the highest in the network. Worth sanity
  checking against the other St Thomas station, which recorded 1,612 mm in the
  same year — a difference that may be real given 175 m of elevation between
  them.
