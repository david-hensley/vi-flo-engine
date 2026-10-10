# Turpentine Run weather — backfill reconstruction

`tr1_weather` · watershed Turpentine Run, St Thomas · reconstructed October 2026

The simplest station in the network and the most complete. One ZL6, one ATMOS 41
on one port, deployed June 2023 and never touched since except for a cleaning.
Its record is **100% complete in every full month** of its three and a quarter
years.

It serves both Turpentine Run gauges.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2023-06-13 · deployed

**z6-12874** with an ATMOS 41 on port 1, at 14:45 local, at 18.34092, -64.88910,
elevation 75.87 m.

> **Established** from metadata and the port record. The first reading in the
> raw export is 18:45 UTC — the same moment, four hours apart, which confirms
> the archive is UTC and metadata local.

It went in during the trip that established the St Thomas network: the
Turpentine Run 1 HOBOlink the same day, the Turpentine Run 2 gauge the next,
Dorothea's gauge the day after that.

### It serves both Turpentine gauges

> **Established.** The TR1 import script: *"The TR1 weather station serves as the
> weather station for TR2 as well."* `tr2.weather.rda` is a copy of
> `tr1.weather.rda`.

---

## The record

```
2023     656 mm   (from 13 June)
2024    1612 mm
2025     576 mm   (to 30 June, in the prototype archive)
```

> **Established** from `tr1.weather.rda`.

**Completeness, counted from the raw export:**

```
2023-06      96%   (part month, deployed on the 13th)
2023-07 to 2026-08   100% in every full month
2024-10      100%, one reading short
2026-09       99%   (part month)
```

> **Established** from `z6-12874`'s Product 1 export, counting distinct
> timestamps against a 15-minute grid. One missing reading in three and a
> quarter years.

The prototype's own record agrees: **49 splice entries in two years**, four of
them on rainfall, against 6,877 at Fish Bay.

> **Established** from `splices.csv`. No neighbour substitution of any kind.

This is what an undisturbed station looks like, and it is the only one in the
network that managed it.

---

## 2026-03-23 · the ATMOS is degrading

*"not much cleaning needed, ATMOS itself degrading in sun"*

> **Established** from the maintenance log, and corroborated by the field notes
> of that visit: *"TR1 weather cleaned but did not need much cleaning. ATMOS
> itself appears to be degrading in the sun similarly to SR1."*

Two of the oldest ATMOS units in the network, failing the same way at the same
time. Neither has been replaced.

**The data gives no sign of it.** Completeness is unaffected and the prototype
found nothing worth correcting, so whatever is degrading has not yet reached the
measurements — or has not reached them in a way that shows as a gap.

> **Inferred.** Sun degradation of the housing would not necessarily affect
> readings before it affects the seal, and nothing here tests the readings
> themselves.

---

## The site

Turpentine Run is the most polluted water in the network, which bears on access
rather than on this station.

> **Established** from the field notes of 2025-11-05: *"majorly polluted,
> blackish gray water entering the stream channel from a tributary originating
> in Tutu Plaza Mall. The water smell of sewage as usual from Turpentine Run."*
> And March 2026: *"cannot address it because of the need to minimize hands in
> the contaminated water"*, with a note to watch for hookworms.

The weather station is on the bank and unaffected. The gauges are not — see
`tr1_hydro.md`.

---

## What follows

### Metadata

```
z6-12874   tr1_weather, ATMOS 41 on port 1, from 2023-06-13 14:45
```

Correct and complete. Nothing to add or change.

The device is 3G, and its subscription lapsed in August 2026.

### Maintenance entries

```
2023-06-13   station_established   ATMOS 41 on z6-12874
```

The only reconstructed entry this station needs. The 2026 cleaning is already
logged.

### Product 1

Already complete. The raw export covers deployment to 2026-09-14 in one file,
with weekly downloads since.

### `record_confirmed`

**2023-06-13**, reason: *one device on one port throughout, no relocation, no
replacement, complete record; see docs/backfill/tr1_weather.md*.

The most straightforward confirmation in the network.

---

## Open

- The ATMOS was flagged as degrading in March 2026 and has not been replaced.
  Nothing in the data shows it yet, which means either it has not affected the
  readings or it has affected them in a way that does not show as a gap.
- It is 3G, one of six still deployed, and its subscription has lapsed.
