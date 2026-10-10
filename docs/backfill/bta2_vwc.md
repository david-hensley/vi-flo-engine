# Bethlehem Adventure soil moisture — backfill reconstruction

`bta2_vwc1`, `bta2_vwc2` · watershed Bethlehem, area Adventure, St Croix ·
reconstructed October 2026

Two stations forty metres apart in forest beside a gut, in the central plains of
St Croix. Neither is a hillside site; both sit close to the channel.

`bta2_vwc1` is the **Reference pit** — a four-depth profile with its own rain
gauge, and the second four-depth pit installed in the network. `bta2_vwc2` is a
six-sensor replicate plot whose history is **deferred**, not reconstructed here.

**Both stations are dead**, and have been far longer than the record of them
suggests.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## `bta2_vwc2` — deferred

**z6-14640**, device name `R4 soil moisture`, deployed 2022-02-21 14:45 at
17.71708, -64.80281, elevation 20.75 m. Six TEROS 10 on ports 1 to 6.

Its last reading is **2024-09-01 16:30**.

> **Established** from metadata, the port record and the Product 1 export.

**Its history is not reconstructed here.** This station belongs to a
six-sensor design that exists at only three places in the network — here,
`uvi_vwc2` and `uvi_vwc3` — and information needed to interpret it has not yet
been tracked down. Reconstructing it now would mean recording guesses.

> Deferred deliberately. Nothing else in this dossier depends on it: it shares
> no device with `bta2_vwc1` and appears in no prototype output.

Its reconstruction waits until that is resolved.

---

## 2023-10-24 · `bta2_vwc1`, the Reference pit

**z6-13391**, device name `Reference pit`, at 13:00, at 17.71712, -64.80260,
elevation 21.20 m — forty metres from `bta2_vwc2`.

```
port 1   TEROS 10   10 cm
port 2   TEROS 10   30 cm
port 3   TEROS 10   50 cm
port 4   TEROS 10  100 cm
port 5   ECRN-50    rain gauge, defunct
```

> **Established** from the port record.

**This is the second four-depth pit in the network**, after `uvi_vwc1`'s
predecessor design. It stands alone with a tipping bucket rather than sharing a
logger with a weather station — so the colocated arrangement that began at UVI
did not come here.

> The pit design and the colocation are two separate lineages. This station took
> the first and not the second.

---

## The ECRN-50 rain gauges all failed

Port 5 carries an ECRN-50 tipping bucket at **seven** stations, and every one of
them is marked defunct.

```
z6-13391   bta2_vwc1 (Reference pit)
z6-13379   fb2_vwc1
z6-13366   sr1_vwc1      z6-12893   sr1_vwc2
z6-13388   sr2_vwc1      z6-12898   sr2_vwc1 v2
z6-13363   sr2_vwc2
```

> **Established** from the port record.

Seven of seven. None has a `valid_from`, so when they were installed is not
recorded, and none has a failure date.

> **Unknown** whether they failed individually or were abandoned as a design.
> The uniformity argues for the latter.

The consequence is that each of these stations was intended to measure its own
rainfall alongside soil moisture, and none of them does.

---

## When they actually stopped

```
bta2_vwc2   last reading 2024-09-01 16:30
bta2_vwc1   last reading 2024-11-05 19:15
```

> **Established** from the Product 1 export.

**Both were found nonresponsive on 2026-03-02** and logged that day — eighteen
months after `bta2_vwc2` stopped and sixteen after `bta2_vwc1` did.

> **Established** from the maintenance log, which records *"ZL6 box
> nonresponsive in field"* for each.

The log date is when they were found, not when they failed. That distinction
matters for every station in this class: the maintenance log records a
discovery, the raw record holds the event.

`bta2_vwc1`'s subscription lapsed in October 2025, eleven months after its last
reading — so by then there was nothing to transmit anyway.

**Neither has been visited since.** Both are on St Croix.

---

## Never processed

Neither station appears in the prototype's soil moisture work.

> **Established.** `vwc.meta.csv` lists Fish Bay and the two Salt River sites
> only. There is no `bta.vwc.rda` or equivalent.

`bta2_vwc2` has four years of unprocessed record, `bta2_vwc1` two and a half.

---

## What follows

### Metadata

```
z6-14640   bta2_vwc2, from 2022-02-21 14:45   deferred
z6-13391   bta2_vwc1, from 2023-10-24 13:00   TEROS 10 at 10/30/50/100 + ECRN-50
```

Both correct. Both 3G, both subscriptions lapsed.

**Both carry `status = nonresponsive` and a `last_visit` of 2026-03-02**, which
is accurate — but neither records when it stopped producing data. That is in the
raw and nowhere else.

### Maintenance entries

Nothing to reconstruct before 2026. The March 2026 failures are logged.

The ECRN-50 installations have no `valid_from` and their failures no date, but
neither is recoverable.

### Product 1

Complete to March 2026, where both records stop.

### What this reconstruction covers

`bta2_vwc1` is reconstructed from **2023-10-24** — its deployment — to the
present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- `bta2_vwc1` has been dead for two years and `bta2_vwc2` for two years and a
  month. Neither has been visited since they were found.
- The ECRN-50 rain gauges: seven installed, seven defunct, no dates for either
  event.
- `bta2_vwc2`'s reconstruction is deferred pending information about the
  six-sensor design.
- `bta2_vwc1` is the Reference pit, which implies a reference against something.
  What it was referencing is not recorded.
