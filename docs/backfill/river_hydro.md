# River — backfill reconstruction

Fair Plain Gut, St Croix · no station id · reconstructed October 2026

A HOBOlink telemetry station on the largest watershed in the Virgin Islands,
run for thirteen months until it was destroyed. Its record is in Product 1 and
goes no further: **this station has no metadata row and no station id, by
decision rather than oversight.**

It is the only dossier here for a site that does not carry forward.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## The site

**Fair Plain Gut**, at 17.70598, -64.78712 — sometimes called River Gut, and
spelled Fair Plane in some older literature.

It drains most of the middle of St Croix, and the valley is deeply incised in
proportion to that catchment. By area it is the largest watershed in the
territory.

> **Established** by the person who ran it.

---

## 2023-08-01 · deployed

A HOBOlink station: base **21748926** on the bank, pressure sensor
**21751137** in the water. First reading 14:15 local, at five minutes.

> **Established** from the export's own header, which names both serials in
> each column:
>
> ```
> Water Pressure (M-WP04 21748926:21751137-1), kPa
> ```

The base is one digit from Salt River 1's replacement base, `21748925`,
installed the day after. The two were evidently bought and commissioned
together.

> **Inferred** from the serials and the dates.

---

## The record

```
2023-08-01 14:15  to  2024-08-21 23:55
106,146 readings at five minutes
barometric pressure, water pressure, differential, water temperature,
and the station's own computed level
```

> **Established** from `river_hydro_20230801-20240821.csv`.

Thirteen months, unbroken. It ends on the same day as Salt River 1's and
Turpentine Run 1's HOBOlink records, which is when that telemetry era closed.

---

## Destroyed

The station was physically destroyed.

> **Established** by the person who ran it. No date is recorded and the record
> simply stops.

---

## Why there is no discharge, and never will be

Stage alone is not discharge. The usual answer is a rating curve built from
gaugings — but **this reach cannot be gauged at any stage that matters.**

> **Established.** Two constraints, both permanent:
>
> Anything anchored in the channel is swept away by the floods that make the
> site interesting in the first place.
>
> And there is no stage worth measuring at which it is safe to enter the
> water. A gauging requires someone standing in the flow; here that is not a
> question of care or equipment.

So the problem is not a rating curve that was never finished. It is that the
method VI-FLO uses everywhere else does not apply to this reach, and no amount
of returning to the site would change that.

### What would work

A non-contact sensor beneath one of the bridges — reading stage and surface
velocity without entering the water — would gauge the whole catchment.

> **Established** as the intention. Not practical yet.

That is why this record is kept rather than discarded. If such an instrument
is ever installed, thirteen months of stage from the same reach becomes
something to calibrate against.

---

## What follows

### Metadata

**None, deliberately.** There is no row for `21751137` or `21748926`, and no
`river_hydro` station.

A metadata row exists so readings can be attributed to a station, and
attribution exists so Product 2 can derive something. Neither applies here.
Creating a row would assert a station VI-FLO monitors, which it does not, and
would put a site in the network listing that no longer exists.

> The archive holds the data; metadata describes the network. This is data
> without a network entry, which is a coherent state rather than a gap.

### Maintenance entries

None. There is no station to log against.

### Product 1

```
21751137   1 file   2023-08-01 → 2024-08-21   106,146 readings
```

Imported alongside the other HOBOlink exports, keyed by its sensor serial like
any other device. `station` is blank in its `download_log` row, as it is for
every Product 1 row.

### Product 2

**It stops here.** With no metadata row the attribution step has nothing to
match, which is the intended outcome rather than a failure to be fixed.

Anyone auditing the archive will find a serial with data and no station. That
is this file's main purpose: to say the absence is deliberate.

### What this reconstruction covers

River is reconstructed from **2023-08-01** — its deployment — to the end of
its record.

`record_confirmed` does not apply: it marks the date a station came under
VI-FLO's standards, and this one never did.

---

## Open

- The date it was destroyed. The record ends 2024-08-21 along with the other
  HOBOlink stations, so the loss may have come later and simply never been
  recorded.
- Whether the base, `21748926`, was recovered. Salt River 1's equivalent was.
