# UVI Campus weather — backfill reconstruction

`uvi_weather` · domain UVI, St Croix · reconstructed October 2026

A ZL6 with an ATMOS 41, deployed October 2021 and running since. It also hosts
`uvi_vwc1`, a soil moisture profile added to the same box in November 2023 —
see `uvi_vwc.md` for that station and the others on campus.

**This is where the colocated design began.** A four-depth soil moisture profile
on the same ZL6 as an ATMOS 41 was tried here first. It stayed unique to UVI
until 2026, when it became the primary monitoring approach — Cal1, SR1, SR2 and
LG3 were all built that way, and St Thomas and St John are intended to follow.

Its port history was the most tangled in the network and was reconstructed in
September 2026 from the logger's own configuration record and from how the
sensors responded to rain.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## UVI is not a watershed

Every other first-level name in the network is a real catchment. **UVI is a
domain.** The St Croix campus sits inside the Bethlehem watershed, and the name
exists so that experiments and soil hydrology work across the campus can be
grouped by place rather than scattered under `bta`.

It is the one grouping where a station's name says where the work is rather than
where the water goes.

---

## 2021-10-08 · the weather station

**`UVI Campus Weather`** (z6-13368) deployed at 16:15 with an ATMOS 41 on port 1.

> **Established.** The port record gives `valid_from` 2021-10-08 16:15:00, and
> the processed archive begins the same day.

It is the barometric reference for the Bethlehem watershed gauges.

> **Established.** The 2024 import script: *"And can also be the reference
> pressure for any gauges in the Bethlehem watershed."*

The processed weather archive runs 2021-10-08 to 2025-06-30, 130,649 rows.

> **Established** from `uvi.weather.rda`.

---

## 2026-03-02 · maintenance

Rain gauge unclogged.

> **Established** from the maintenance log. The same visit logged soil moisture
> work under `uvi_vwc1`, recorded separately.

## 2026-09-11 · reviewed by proxy

Cable work at the soil moisture pit was logged under `uvi_vwc1` alone, which
left `uvi_weather` reading as unreviewed for six months despite sharing the box.
Both now carry the same review timestamp.

> **Established.** The companion prompt added to the metadata manager in October
> 2026 exists because of this case.

---

## What follows

### Metadata

```
z6-13368   uvi_weather, from 2021-10-08 16:15   ATMOS 41 on port 1
```

The row is correct and currently reviewed. One port, one sensor, no changes in
five years.

The device is a **3G box** and its subscription lapsed in April 2026. The 3G
module is one of six still deployed.

### Maintenance entries

Nothing to reconstruct. The ATMOS has been on port 1 since deployment and no
structural event is missing from the record.

### A note for the data dictionary

The `watershed` field is documented as the broad watershed area, named after the
largest downstream gut or the bay it reaches. `uvi` is the exception and the
dictionary should say so — a campus, within the Bethlehem watershed, grouped by
place of work rather than by drainage.

### Product 1

Already complete. This logger is in the ZentraCloud export set and downloads
weekly, so nothing needs importing.

### `record_confirmed`

**2021-10-08**, reason: *single ATMOS on one port throughout;
see docs/backfill/uvi_weather.md*.

---

## Open

- The ATMOS is one of several showing sun degradation. The March 2026 notes
  record it elsewhere as *"the ATMOS itself is degrading in the sun and maybe
  cracking"*, and this one had its spring missing at that visit.
- The box is 3G, and the module generation is being retired.
