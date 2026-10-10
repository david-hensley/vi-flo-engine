# UVI Campus soil moisture — backfill reconstruction

`uvi_vwc1`, `uvi_vwc2`, `uvi_vwc3` · domain UVI, St Croix · reconstructed
October 2026

Three stations of two quite different designs. `uvi_vwc1` is a **four-depth
profile** on the weather station's logger — the first of the colocated design
that is now standard. `uvi_vwc2` and `uvi_vwc3` are six-sensor plots at
Breadfruit whose history is **deferred**, not reconstructed here.

None of them was ever processed by the prototype.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## `uvi_vwc2` and `uvi_vwc3` — deferred

```
z6-14625   uvi_vwc2   from 2021-12-08 15:00   17.72097, -64.79715   34.25 m
z6-13376   uvi_vwc3   from 2022-09-09 16:45   17.72093, -64.79688   33.14 m
```

Both carry six TEROS 10 across all six ports, a design that exists at only one
other place in the network — `bta2_vwc2`.

> **Established** from metadata and the port record.

`uvi_vwc2` is still reporting. `uvi_vwc3`'s last reading is **2025-04-16
10:00**, eleven months before it was found nonresponsive.

> **Established** from the Product 1 exports.

**Their history is not reconstructed here.** Information needed to interpret
the six-sensor arrangement has not yet been tracked down, and writing it now
would mean recording guesses. Their reconstruction waits until that is
resolved.

> Deferred deliberately. `uvi_vwc1` is independent of them — a different device,
> a different design, forty metres away.

---

## 2023-11-06 · `uvi_vwc1`, the colocated profile

Four TEROS 10 on the weather station's logger, **z6-13368**, at 10, 30, 50 and
100 cm on ports 2 to 5.

> **Established** from the port record. See `uvi_weather.md` for the logger's
> own history.

**The depths and dates were reconstructed, not recorded.**

> **Established.** `migrate_fix_uvi_ports.R` corrected four depths and every
> installation date in September 2026. Its basis was the ZentraCloud export's
> configuration history, cross-checked against each sensor's response lag to
> **49 rainfall events** — a shallow sensor responds within minutes, a deep one
> over hours.
>
> This is the only station in the network whose sensor depths come from how the
> data behaves rather than from a record of the installation.

### The 10 cm sensor fails and moves

```
2024-02-16 12:30   port 2 marked defunct
2024-05-06 11:00   replacement at 10 cm on port 6; port 2 left empty
```

> **Established** from the port record.

A **three month gap in the shallowest and most responsive depth**, spanning the
wettest part of spring. Neither event has a maintenance entry; both are implied
by the port record alone.

---

## 2026-03-02 · the network is walked

`uvi_vwc3` found *"ZL6 box nonresponsive in field"*; `uvi_vwc2` found with
*"Ants inside box"* but working.

> **Established** from the maintenance log, and from the field notes: *"UVI VWC1
> and VWC2 still work, but all others are shut down."*

`uvi_vwc1` was unaffected — it runs on the weather station's logger, which has
never failed.

Eight soil moisture boxes across the network were found dead on this visit and
the St John trip three weeks later. They had stopped individually across the
previous fifteen months — see the cross-station note in `README.md`.

## 2026-09-11 · cable work at `uvi_vwc1`

*"Moved 10cm logger and retrenched cables from pit in PVC protective housing,
re-coiled cables. No port change, Port 2 still disconnected."*

> **Established.**

---

## Never processed

The prototype's soil moisture work covered Fish Bay and the two Salt River sites
only.

> **Established.** There is no `uvi.vwc.rda`, and `vwc.meta.csv` lists five
> stations, none of them UVI's. The campus plots sat outside that scheme
> entirely.

So all three stations have their full record unprocessed — nearly five years at
`uvi_vwc2`.

---

## What follows

### Metadata

```
z6-13368   uvi_vwc1, from 2023-11-06 11:45   TEROS 10 at 10/30/50/100
z6-14625   uvi_vwc2, from 2021-12-08 15:00   deferred
z6-13376   uvi_vwc3, from 2022-09-09 16:45   deferred
```

All three rows are correct. `uvi_vwc1`'s `deploy_datetime` is 11:45 while its
ports record 10:45 — an hour apart, both set during the 2026 reconstruction.

`uvi_vwc3` is marked nonresponsive but nothing records that it stopped in April
2025, eleven months before anyone saw it.

### Maintenance entries

Two events are implied by the port record and have none:

```
2024-02-16   device_maintenance   uvi_vwc1 10 cm sensor on port 2 failed
2024-05-06   port_change          replaced on port 6; port 2 left empty
```

### Product 1

Already complete for all three. All are in the ZentraCloud export set.

### What this reconstruction covers

`uvi_vwc1` is reconstructed from **2023-11-06** — its sensors' installation —
to the present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- `uvi_vwc3` stopped in April 2025 and has not been visited since it was found
  dead in March 2026.
- The hour between `uvi_vwc1`'s `deploy_datetime` and its ports' `valid_from`.
- Port 2 on `z6-13368` is recorded as defunct rather than removed. Whether a
  failed sensor left in place should read as defunct or empty is a convention
  worth settling.
- `uvi_vwc2` and `uvi_vwc3` are deferred pending information about the
  six-sensor design, which they share only with `bta2_vwc2`.
