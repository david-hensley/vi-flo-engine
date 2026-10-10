# Salt River 1 soil moisture — backfill reconstruction

`sr1_vwc1`, `sr1_vwc2`, `sr1_vwc3` · watershed Salt River, St Croix ·
reconstructed October 2026

A **hillside and streambank pair** installed in 2022, the design the prototype's
soil moisture work was built on. The hillside station was decommissioned in
September 2026, the streambank station re-equipped the same day, and a third
profile added to the weather station's logger.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## The design

```
sr1_vwc1   hillside     17.75939, -64.79956
sr1_vwc2   streambank   17.75376, -64.79314
```

> **Established** from `vwc.meta.csv`, which classifies them `hs` and `sb`, and
> from the coordinates, which match metadata exactly.

The pair sits roughly 900 m apart — one on the slope, one beside the gut — and
the prototype's processed output carries both under a single `type` column.

> **Established.** `sr1.vwc.rda` holds 200,517 rows from 2022-05-26 to
> 2025-05-21, 103,428 hillside and 97,089 streambank.

Salt River 2 has the same arrangement. Fish Bay has only the streambank half.

---

## 2022-05-26 · `sr1_vwc1`, hillside

**z6-13366**, device name `SR1 Hillside`, at 16:30.

```
port 1-4   TEROS 10 at 10, 30, 50, 100 cm
port 5     ECRN-50 rain gauge, defunct
```

> **Established** from the port record.

## 2022-06-15 · `sr1_vwc2`, streambank

**z6-12893**, device name `SR1 Streambank`, at 13:45. The same configuration.

> **Established** from the port record.

Three weeks apart, which places both within the same campaign — Salt River 2's
pair went in on 17 May and 14 June, interleaved with these.

---

## The record is heavily gapped

`sr1.vwc.rda` carries roughly **25,000 missing values per depth** — about an
eighth of the record.

> **Established** from the processed archive: 25,040 at 10 cm, 24,692 at 30 cm,
> 23,784 at 50 cm, 24,133 at 100 cm.
>
> Salt River 2's equivalent has 2,490 per depth, ten times fewer.

The prototype's own record shows where they are, and notably declined to fill
most of them.

> **Established** from `splices.csv`. The hillside station has five gap entries
> and four of them are `stays.gap` — someone looked and decided not to
> interpolate:
>
> ```
> 2023-10-17 to 2023-11-03    17 days
> 2024-07-10 to 2024-08-12    33 days
> ```
>
> The streambank station has seven, including **2024-01-12 to 2024-05-06, near
> four months**, also left as a gap.

`stays.gap` is the prototype doing the right thing — recording an absence
rather than inventing a value — and those entries are evidence of physical
history rather than processing.

---

## When they actually stopped

```
sr1_vwc2   last reading 2025-03-23 01:45
sr1_vwc1   last reading 2025-05-21 18:30
```

> **Established** from the Product 1 exports.

**Both were found nonresponsive on 2026-03-02** and logged that day — eleven
months after the streambank station stopped, nine after the hillside one.

> **Established** from the maintenance log, which records *"ZL6 box
> nonresponsive in field"* for each.

The field notes of that visit name the suspected cause: *"The common thread
seems to be the lithium batteries, though memory tells me putting fresh
batteries does not help."*

**But the two did not fail together.** Two months apart here, and across the
network the eight affected boxes stopped over fifteen months between June 2024
and September 2025. The March 2026 visit is when they were found, not when they
failed.

---

## 2026-09-04 · the pair is broken up

Three things on one afternoon:

```
13:09:15   sr1_vwc3 established on the weather logger z6-14635
           TEROS 10 at 10, 30, 50, 100 cm
13:12:45   sr1_vwc1 decommissioned; z6-13366's ports closed
15:59:17   sr1_vwc2 re-equipped; z6-12893 replaced by z6-38174
```

> **Established** from the port record and the maintenance log.

**The hillside station was not replaced — it was retired**, and a new profile
went onto the weather station's logger instead. The streambank station kept its
position and got a new box.

> So the hillside and streambank pair is no longer a pair. `sr1_vwc3` sits at
> the weather station at 122 m, not at the old hillside position at 17.75939,
> -64.79956.

### 2026-09-16 and 09-18 · settling in

```
09-16   SIM swapped to AT&T, desiccant added, VI-FLO sign added
09-16   device renamed from '(blank)' to 'SR1 SB VWC'
09-18   "Switched rechargeable to akaline"
```

> **Established** from the maintenance log.

The battery change is the response to the failures: rechargeable cells out,
alkaline in, at this station and at `sr2_vwc2` and `ltt1_vwc3` the same day.

---

## What follows

### Metadata

```
z6-13366   sr1_vwc1, 2022-05-26 16:30 -> 2026-09-04, decommissioned
z6-12893   sr1_vwc2, 2022-06-15 13:45 -> 2026-09-04, replaced
z6-38174   sr1_vwc2, from 2026-09-04 15:59, same position
z6-14635   sr1_vwc3, from 2026-09-04 13:09:15, on the weather logger
```

All four correct. `z6-13366` and `z6-12893` carry no `elev`.

Neither of the retired rows records when its device stopped producing data —
March 2025 and May 2025. That is in the raw and nowhere else, and it is the
figure that matters for how far each station's record actually reaches.

**One leftover to clean:** the maintenance log holds a `station_established`
entry for `sr1_vwc3` dated **2021-11-24**, which is the stream gauge's
timestamp. The station's `deploy_datetime` was corrected to 2026-09-04 but the
log entry was not.

### Maintenance entries

The 2026 work is logged in full. Nothing earlier is recoverable: four years with
no entries between deployment and March 2026.

### Product 1

Complete for all four devices.

### `record_confirmed`

```
sr1_vwc1   2022-05-26
sr1_vwc2   2022-06-15
sr1_vwc3   2026-09-04
```

Reason: *port configuration as installed and unchanged; device replacement in
2026 logged contemporaneously; see docs/backfill/sr1_vwc.md*.

---

## Open

- The hillside position is no longer monitored. `sr1_vwc3` is at the weather
  station, not at the old pit, so the hillside–streambank comparison the
  prototype was built on has no successor here.
- Four months of streambank record from January to May 2024 are a genuine gap,
  left unfilled by the prototype and still unexplained.
- The ECRN-50 on port 5 at both original stations is defunct with no dates.
