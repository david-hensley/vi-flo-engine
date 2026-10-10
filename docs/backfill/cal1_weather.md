# Caledonia 1 weather — backfill reconstruction

`cal1_weather` · watershed Caledonia, St Croix · reconstructed October 2026

Known as **Ridge to Reef Farm** for its first five years. A remote station,
rarely visited, re-equipped in September 2026 in the same position with a new
logger and a soil moisture profile.

It is the clearest case in the network of a record that *looks* clean because
nobody was there to find fault with it.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2021-11-04 · `R2R Farm`

**z6-14637** with an ATMOS 41 on port 1, deployed at 15:30 at 17.75361,
-64.86687.

> **Established** from metadata and the port record.

It served as the weather station for Jolly Hill, which had none of its own.

> **Established.** `jh.weather.rda` is a copy of `r2r.weather.rda` — identical
> at all 111,460 shared timestamps. The prototype materialised a weather series
> per hydro site by duplicating from its paired station.

---

## 2021-11-04 → 2025-07-01 · the record

128,098 rows. Rainfall by year:

```
2021      83 mm   (from 4 November)
2022    1432 mm
2023     766 mm
2024    1396 mm
2025     458 mm   (to 1 July)
```

> **Established** from `r2r.weather.rda`.

### The splice record is clean, and that is not reassuring

173 entries in four years, with **no neighbour substitution at all** — 123
pluviograph checks and 43 linear interpolations.

> **Established** from `splices.csv`. SR1's equivalent runs to eighteen months
> of borrowed data; SR2's precipitation alone required 705 interventions in
> 2024.

**But this station was remote and went long stretches without a visit**, and the
splice record only shows interventions someone chose to make. A gauge producing
plausible but wrong readings, unvisited, generates no splices whatever.

> **Established** by the person who ran it: the station was not visited for a
> long period preceding its replacement.

So the absence of correction here is evidence of absence of *attention*, not of
absence of problems. The record should be treated with the same suspicion as
SR2's late period, and with less to go on.

### A rule for the VI-FLO era

**Any station unvisited for more than six months is suspect for QA purposes.**

> That is a standing rule rather than a finding about this site. It is what
> makes `last_visit` a QA input rather than a logistical note, and it would flag
> this station, SR2's late record, and the four St Thomas and St John gauges
> last read in March 2026.

---

## 2026-09-11 · re-equipped in place

```
13:45:54   z6-37439 begins, ATMOS 41 G2 on port 1
           TEROS 10 at 10, 30, 50 and 100 cm on ports 2-5
13:46:06   z6-14637's ATMOS port closes
```

> **Established** from the port record, which captures the handover to the
> second.

The position is unchanged — the same coordinates as 2021. This is a
re-equipping, not a relocation, unlike SR2.

The soil moisture profile establishes **`cal1_vwc1`** on the new box; see
`cal1_vwc.md`.

The visit left two things outstanding: *"still need bird spikes, and need AT&T
sim card"*.

## 2026-09-16 · the new ATMOS is replaced too

Five days later: *"SIM swap to AT&T, swapped ATMOS 41 G2 due to 3% RH error
reported by Meter, added desiccant, added sign, added bird spikes"*.

> **Established** from the maintenance log.

So the ATMOS installed on 11 September was itself faulty — a **3% relative
humidity error reported by the manufacturer** — and was exchanged on the 16th.
The outstanding items from the first visit were cleared at the same time.

**Five days of humidity readings carry a known 3% error**, from 2026-09-11 to
2026-09-16.

The maintenance log is where that lives, and it is recorded there. The port
record would not show it — it carries sensor type and depth, not a serial, so a
like-for-like swap of one ATMOS 41 G2 for another changes nothing in it.

> That makes the maintenance log the source a QA process should read to derive
> suspect windows: a `maintenance` entry naming a known instrument fault bounds
> a period that Product 3 should flag, and nothing else in metadata does.

---

## Elevation

The station sits at 172.05 m, against the Jolly Hill gauge at 48.59 m — the
largest station-to-gauge difference in the network, and the reason this station
matters to a gauge in another watershed.

**`z6-14637` has no elevation recorded at all.** Its successor has 172.05 m at
the same coordinates, so the value transfers, but the field is empty on the row
covering 2021 to 2026.

> The prototype used a fixed -107 m for this pair, which is its own figure and
> not inherited. VI-FLO computes the correction from recorded elevations.

---

## What follows

### Metadata

```
z6-14637   cal1_weather, R2R Farm,     2021-11-04 15:30 -> 2026-09-11, replaced
z6-37439   cal1_weather, Cal1 Weather, from 2026-09-11 13:45:54   ATMOS 41 G2
z6-37439   cal1_vwc1,                  from 2026-09-11 13:45:54   TEROS 10 x4
```

`z6-14637` carries no `elev`. Its successor has 172.05 m at the same
coordinates, so the value transfers.

Nothing else to change. The humidity fault is in the maintenance log, which is
where it belongs.

### Maintenance entries

```
2021-11-04   station_established   R2R Farm, ATMOS 41 on z6-14637
```

Nothing else predates the metadata manager. The 2026 work is logged in full,
including the fault and its correction.

The absence of entries between 2021 and 2026 reflects absence of visits, not
absence of need.

### Product 1

Already complete for both devices.

### What this reconstruction covers

`cal1_weather` is reconstructed from **2021-11-04** — its deployment as R2R
Farm — to the present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- When the visits stopped. The record gives no sign, because an unvisited
  station generates no splices — which is the point.
- The 3% humidity error from 2026-09-11 to 2026-09-16 needs checking in post.
  The maintenance log records it; whether Product 3 should read maintenance
  entries to derive QA flags automatically is a design question for that work.
- `z6-14637` was replaced rather than retired. It appears in the ZentraCloud
  device list as a 3G box with no current deployment, so it is in hand as a
  spare.
- `z6-14637` carries no `elev`, which is the one field needed to compute a
  barometric correction for 2021-2026 from metadata alone.
