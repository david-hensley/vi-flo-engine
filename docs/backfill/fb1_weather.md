# Fish Bay weather — backfill reconstruction

`fb1_weather` · watershed Fish Bay, St John · reconstructed October 2026

One ZL6 with an ATMOS 41, deployed October 2021 and running since. It was moved
over a kilometre in February 2024, and lost about twenty days of record in a
bounded episode that followed.

It also serves Reef Bay, which has no weather station of its own.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2021-10-21 · deployed

**z6-13375** with an ATMOS 41 on port 1, at 16:00 at 18.32603, -64.76368.

> **Established** from metadata and the port record. The first reading in the
> raw export is 2021-10-21 19:30 UTC — the same afternoon.

The same day the Fish Bay stream gauges went in, three and a half hours earlier.

### It serves Reef Bay too

> **Established.** `rb.weather.rda` is a copy of `fb.weather.rda`, identical at
> all 99,261 shared timestamps. Reef Bay has never had a weather station.

This station's barometric record matters to three gauges, and the correction it
needs changed completely when it moved — see below.

---

## 2024-02-06 · relocated 1.1 km

Moved at 10:15 from 18.32603, -64.76368 to 18.33096, -64.77339 — **1,164 m**
north-west, to 208.2 m elevation.

> **Established** from metadata, and confirmed independently: the prototype's
> `elev.formula` correction on barometric pressure runs from deployment to
> **exactly 2024-02-06 10:15**, the relocation minute.

It sat within a three-day trip: Dorothea's slope logger on the 4th, Reef Bay's
and Fish Bay's on the 5th, this move on the 6th.

### The two positions have measurably different climates

```
                 before Feb 2024      after
wind             0.52 - 0.87 m/s      1.12 - 1.72 m/s
radiation        43 - 230             158 - 259
summer temp      peak 29.3            peak 27.6
```

> **Established** from monthly means in the processed archive. The new site is
> higher, cooler, more exposed and far less shaded — wind roughly doubles and
> radiation becomes both higher and much less variable.

**Anything spanning February 2024 is spanning two different places.** That is
not a fault to correct; it is a discontinuity to respect, and the deployment
windows in metadata are what express it.

### The barometric correction changes with it

```
2023-12-01 elevs.csv     fb 0       rb 0
2024-10-01 elevs.csv     fb -210    rb -215
```

> **Established.** The old position was near sea level, within a few metres of
> the Fish Bay gauge at 3.3 m, so no correction was needed. The new one sits at
> 208.2 m and needs about 210.
>
> The two files bracket the relocation: the first predates it by ten weeks, the
> second postdates it by eight months. The zeros are not placeholders — they
> were right for the position the station then occupied.

**VI-FLO does not use these files.** `elevs.csv` is a prototype artefact, read
here to understand what that pipeline did. The correction VI-FLO applies is
computed from the two stations' own elevations in metadata, which is why the
relocation needs no special handling: each deployment window carries its own
position and its own elevation.

The only thing missing is the elevation of the first position. Its coordinates
are recorded; `elev` is not.

---

## 2024-03 → 2024-09 · a bounded loss of record

Monthly completeness, counted from the raw export rather than from any
processed product:

```
2021-10 to 2024-02    100%
2024-03                98%
2024-04                87%
2024-05                96%
2024-06                89%
2024-07                70%
2024-08                80%
2024-09                97%
2024-10 to 2026-09    100%
```

> **Established** from `z6-13375`'s Product 1 export, counting distinct
> timestamps against a 15-minute grid. Fifty-four months at 100% on either
> side of seven affected ones.

About **1,900 readings — roughly twenty days — are absent**, and they were never
backfilled. They do not exist in ZentraCloud now.

### What the gaps look like

The prototype's own record of patching this period describes the shape:

```
412   single missing readings
558   gaps up to an hour
 70   one to four hours
  1   twenty-two hours
```

> **Established** from `splices.csv`. All six variables drop together in
> near-identical counts — July 2024 shows 347 precipitation entries against 344
> each for radiation, temperature, humidity and pressure.
>
> The gaps are spread evenly across every hour of the day, with no clustering
> before dawn.

**That signature is not the rain gauge and not the battery.** All variables
failing together rules out a sensor; the absence of any time-of-day pattern
rules out a power or solar problem. Frequent brief dropouts affecting everything
equally is what losing transmission looks like.

> **Inferred.** The logger was almost certainly recording; the readings did not
> arrive and were never recovered.

### Why it started, and why it stopped

The relocation preceded the episode by three weeks, which makes a changed signal
environment the obvious suspect — though the new site is higher and more
exposed, which should improve reception rather than harm it.

> **Unknown.** Nothing in the record explains either the onset or the recovery
> in October 2024.

An ATMOS was replaced at some point during this period, in response to what
looked at the time like a rain gauge producing nothing — which is exactly how a
transmission fault presents on ZentraCloud.

> **Unknown** when. The export carries one configuration across all five years,
> because a like-for-like swap on the same port is the same configuration. The
> `sensor` field holds a model name and no serial. The port record does not
> distinguish one ATMOS 41 from another. Nothing we hold can date it.

The record has been complete since October 2024, so whatever was wrong stopped
being wrong. Whether that was the ATMOS, the carrier, or something else is not
recoverable.

---

## 2026-03-23 · cleaned

*"Fish Bay weather cleaned. Minimal residue build up. ZL6 in good order."*

> **Established** from the field notes, and the only maintenance entry this
> station has.

---

## What follows

### Metadata

```
z6-13375   fb1_weather, 18.32603 -64.76368, 2021-10-21 16:00 -> 2024-02-06, relocated
z6-13375   fb1_weather, 18.33096 -64.77339, from 2024-02-06 10:15, elev 208.2
```

Both rows exist and the relocation is correctly recorded.

**The earlier row carries no `elev`**, which is the one field needed to compute
a barometric correction for 2021–2024 from metadata alone. The coordinates are
there, so the elevation functions can fill it.

The device is 3G; its subscription lapsed in May 2026.

### Maintenance entries

```
2021-10-21   station_established   ATMOS 41 on z6-13375 at the first position
2024-02-06   station_relocated     moved 1.1 km; already in metadata, not in the log
2024-??-??   device_replacement    ATMOS 41 swapped; date not recoverable
```

The relocation is in metadata but has no maintenance entry, unlike SR2's, which
has both.

### Product 1

Already complete. The raw export runs 2021-10-21 to 2026-09-14 in one file, with
weekly downloads since.

### What this reconstruction covers

`fb1_weather` is reconstructed from **2021-10-21** — its deployment — to the
present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- The ATMOS replacement is undated and nothing we hold can date it. Recording a
  sensor serial at installation would make the next one datable; the port record
  has `sensor` as a model name only.
- The twenty days lost in 2024 are lost. Nothing recovers them.
- Why the dropouts began a month after the relocation and ended seven months
  later without a visit.
- The pre-2024 row has no `elev`. Filling it from its recorded coordinates
  would make the barometric correction for that era derivable from metadata,
  with no reference to the prototype's files.
