# Reef Bay — backfill reconstruction

`rb2_hydro` · watershed Reef Bay, St John · reconstructed October 2026

What the station's history appears to have been, and what supports each part of
it. Reconstructed from the loggers' own records, the HOBOware launch titles, the
per-site R scripts, and the field notes.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable from what survives.

Reef Bay carries **hydro only**. Its weather comes from Fish Bay.

> **Established.** `site.correspondence.csv` pairs `rb` to `fb`, and the 2024
> import script opens "Importing Reef Bay (weather station is at Fish Bay)".

---

## 2023-09-25 · the record begins

A single gauge, **`Reef Bay`** (21652380), at ten minute interval.

> **Established.** First file 2023-09-25 10:00.

Nothing precedes this.

> **Established.** Seven files named `RB-2021*` and `RB-2022*` carry the plot
> title `FishBay1` and belong to Fish Bay — see `docs/backfill/fb.md`. Reef Bay
> has no record before September 2023.

---

## 2023-10-04 · Tropical Storm Philippe

Stage 0.931 m, peak discharge 17.3 m³/s — nine days into the record, and the
largest flow Reef Bay has produced.

> **Established** from the processed archive.

---

## 2024-02-01 → 02-05 · a slope partner

**`ReefBay_slope`** (21652377) launched at a desk on 1 February at **17:44** and
deployed on 5 February at **09:30**, upstream of the existing gauge.

> **Established.** The import script records the activation time. The
> temperature trace shows the same pattern as Fish Bay's — small indoor swings
> on 1–3 February, 7.5 °C on the 4th while being moved, settling from the 6th.
>
> **Inferred** that it sits upstream: the 2025 field notes describe recovering
> "one water level" at the old site and the survivor is this logger, and the
> position is remembered as the upstream one.

Part of one coordinated deployment. `21652377` was launched four minutes after
Fish Bay's `21179105` (17:40) and Dorothea's `21652372` on the same evening; all
three went into the water on 5 February.

> **Established.** The hydraulic-slope programme began that day across three
> sites.

The pair never produced a slope relationship.

> **Established.** The 2024 script: *"There was no flow during the observed
> slope period, so we stop here. We will have to calculate discharge without
> knowing the slope curve."*

---

## 2024-10-24 · the gauge's last reading

Both loggers offloaded that morning. `ReefBay_slope` was relaunched and switched
from ten to fifteen minutes. `21652380` has no reading after **11:10** and never
appears again — not in the November 2025 shuttle readout, not in VI-FLO.

> **Established** from the file boundaries and every subsequent archive.

It was relaunched and then lost, rather than removed that day.

> **Inferred**, from the field notes of 2025-11-06: *"At the old stream gauge
> site one water level still remains and was recovered."* One, not two. So the
> downstream gauge was already gone by then.
>
> A relaunch wipes what preceded it, and a logger never recovered is never read,
> so the two possibilities leave identical evidence. The notes decide it.

## 2024-11-11 · a flood, with one logger in the water

`ReefBay_slope` records a rise of 12.1 kPa — about 1.2 m — eighteen days after
the gauge's last reading. Forty-five centimetres again on 16 November, then a
week of elevated flow.

> **Established** from the raw pressure record.

The same date is Fish Bay's largest event in four years, so this was a regional
storm across St John. If a housing was going to fail, this was the water to do
it.

> **Inferred.** The field notes record that housings of that period were
> substandard.

---

## 2024-10-24 → 2025-06-05 · alone

`ReefBay_slope` runs on by itself for seven months, at fifteen minutes, with a
slope partner that no longer exists.

> **Established.**

---

## 2025-11-06 · rebuilt upstream

Two new loggers established **upstream of the trail intersection with the gut**,
which is upstream of the previous location: **RB A** (22373552) downstream and
**RB B** (22373557) upstream of each other.

> **Established** from the field notes of that date and from current metadata.

`21652377` was recovered from the old site and carried back to St Croix.

> **Established.** Field notes: *"I have downloaded the data to the logger and
> removed the logger itself to take back to St. Croix … it is in a precarious
> position and I cannot secure it."*

The notes propose returning in spring 2026 to install a logger at that exact
position for one year, so the old record can be correlated to the new upstream
site.

## 2026-03-23 · RB C, at the old site

**RB C** (22373555) launched at 08:46 at the **upstream** position of the
original pair — where `21652377` had sat. This is the correlation logger
proposed in November.

> **Established.** Field notes of that date; its `last_download_date` is blank,
> consistent with never yet offloaded.

`21652377` subsequently went to `sgm2_hydro`, deployed 2026-09-18.

> **Established** from current metadata and the maintenance log.

---

## Geometry and discharge

No survey of the separation between the 2024 pair exists.

> **Unknown.** The only logger-pair distances and heights in the codebase are
> Fish Bay's 2024 pair and Dorothea's. The Reef Bay script says plainly that
> discharge was computed without a slope curve.

What does exist is the reach itself:

```
bed gradient    0.60%      slopedata.csv, 7 points over 35.6 m around the gauge
roughness       0.15       roughness.csv, Manning's n
cross sections  3 reps     gutsurveys.csv, 12 points each, ~5 m wide, ~1.2 m relief
```

> **Established.** `slopedata.csv` holds streambed profiles up and down from each
> gauge, surveyed when there was one logger per site. It is a property of the
> reach, not a separation between loggers.
>
> **Horizontal distances are metres and vertical readings are feet** — a rod
> read in feet against a tape in metres. The gradient above applies the 0.3048
> conversion. Taken raw the same points give 1.97%, which does not match a reach
> described as flat.

**The 2023–2024 record is therefore usable.** Manning's equation takes the
friction slope, conventionally approximated by the bed slope under uniform flow
— which is the standard method, not a fallback, and is how every pre-2024 site
was processed. The `q` in `rb.hydro.rda` was produced that way.

A measured hydraulic slope is a refinement on that assumption, correcting for
non-uniform flow at high stage. Once RB C accumulates enough paired record with
the new upstream pair, a stage-dependent correction could be derived and applied
backwards.

**How far back it reaches differs by logger.** RB C occupies the position
`21652377` held, so that logger's record — February 2024 to November 2025 — can
take the correction directly, with no offset.

`21652380`'s record cannot. It sat downstream of that position, no logger
occupies it now, and the separation was never surveyed. That is the window
containing Philippe, 2023-09-25 to 2024-02-05, before the pair existed at all.
Its discharge rests on the bed-slope assumption and will continue to.

The correction will take time in any case: Reef Bay has seen little flow since,
and the 2023–24 period may not be matched for some years.

---

## What follows

### Metadata

```
21652380   Reef Bay gauge, 2023-09-25 → 2024-10-24, lost
21652377   upstream partner, 2024-02-05 → 2025-11-06, recovered, now sgm2_hydro
22373552   RB A, from 2025-11-06
22373557   RB B, from 2025-11-06
22373555   RB C, from 2026-03-23, at the old gauge position
```

`21652380` has no row in current metadata and needs one for its deployment and
loss. `21652377`'s Reef Bay period is likewise unrecorded — metadata holds only
its `sgm2_hydro` deployment, so its 2024–2025 readings would attribute to no
station.

The November 2025 position is **upstream of the previous one**, so RB A and RB B
describe a different reach from the 2023–24 record. RB C is the bridge, standing
where `21652377` stood.

### Maintenance entries

```
2023-09-25   station_established   Reef Bay gauge deployed
2024-02-05   device_deployed       upstream slope partner added
2024-10-24   device_removed        gauge last read; lost thereafter
2025-11-06   station_relocated     rebuilt upstream of the trail intersection
2025-11-06   device_removed        21652377 recovered from the old site
2026-03-23   device_deployed       RB C at the old gauge position
```

### Product 1

```
21652380    4 files   2023-09-25 → 2024-10-24
21652377    3 files   2024-02-01 → 2025-06-05
21652377              2025-06-05 → 2025-11-06   (November 2025 readout)
```

### `record_confirmed`

**2023-09-25**, reason: *device history reconstructed from launch titles, import
scripts and field notes; see docs/backfill/rb.md*.

---

## Open

- The separation between `21652380`'s position and the upstream one RB C now
  occupies was never surveyed, so the September 2023 to February 2024 window —
  Philippe included — cannot receive a back-applied slope correction.
- Reef Bay's entry in `elevs.csv` is **0** — no elevation correction between the
  Fish Bay weather station and the Reef Bay gauge, two watersheds apart. Either
  they sit at the same height or it was never surveyed.
- Roughness of 0.15 is the default across nearly every site. Only TR2 (0.017)
  and Dorothea (0.2) differ, which suggests those two were considered and the
  rest inherited a value.
