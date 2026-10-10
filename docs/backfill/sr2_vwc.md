# Salt River 2 soil moisture — backfill reconstruction

`sr2_vwc1`, `sr2_vwc2`, `sr2_vwc3` · watershed Salt River, St Croix ·
reconstructed October 2026

The same hillside and streambank pair as Salt River 1, installed in the same
campaign — but the hillside station was replaced once in 2024 before being
retired in 2026, so it has two device eras where its neighbour has one.

Its record is also far more complete than Salt River 1's: **2,490 missing values
per depth against 25,000**.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## The design

```
sr2_vwc1   hillside     17.75872, -64.76882
sr2_vwc2   streambank   17.75897, -64.76483
```

> **Established** from `vwc.meta.csv` and the coordinates, which match metadata
> exactly.

About 420 m apart — much closer than Salt River 1's pair at 900 m.

`sr2.vwc.rda` holds 199,566 rows from 2022-05-17 to 2025-06-30, 106,718 hillside
and 92,848 streambank.

> **Established** from the processed archive.

---

## 2022-05-17 · `sr2_vwc2`, streambank

**z6-13363**, device name `SR2 Streambank`, at 16:15. The first soil moisture
station of the 2022 campaign.

```
port 1-4   TEROS 10 at 10, 30, 50, 100 cm
port 5     ECRN-50 rain gauge, defunct
```

## 2022-06-14 · `sr2_vwc1`, hillside

**z6-13388**, device name `SR2 Hillside`, at 14:15. The same configuration, and
the only one of the seven ECRN-50 installations with a recorded `valid_from`.

> **Established** from the port record.

The four stations of the campaign went in over four weeks: SR2 streambank on
17 May, SR1 hillside on the 26th, SR2 hillside on 14 June, SR1 streambank on the
15th.

---

## 2024-01-22 · the hillside box is replaced

**z6-12898**, device name `SR2-HS v2`, takes over at 13:15 — fifteen minutes
after `z6-13388`'s ports close at 13:00.

> **Established** from the port record, which captures the handover.

**`z6-13388` kept reporting for another nineteen days**, to 2024-02-10 16:00.

> **Established** from its Product 1 export.
>
> It was removed from the pit on 22 January and continued transmitting from
> wherever it was taken — so its last three weeks of readings are not from the
> hillside and should not be attributed there. Product 2 will handle that
> correctly, because the deployment window closes on the 22nd.

The `v2` in the name is the only indication of why. No maintenance entry
explains it.

> **Unknown** what failed. The replacement was planned enough to have a new box
> on site, so it was not a surprise discovered that day.

---

## When they actually stopped

```
sr2_vwc2   last reading 2025-01-13 20:30
sr2_vwc1   last reading 2025-09-25 18:15
```

> **Established** from the Product 1 exports.

**Both were found nonresponsive on 2026-03-02** — fourteen months after the
streambank station stopped and five after the hillside one.

> **Established** from the maintenance log.

The log date is the discovery. Across the network the eight affected boxes
stopped over fifteen months, individually, and were found together.

---

## 2026-09-04 → 09-16 · rebuilt, in three stages

```
2026-09-04 15:53:23   sr2_vwc1 decommissioned; z6-12898's ports close
2026-09-04 15:55:49   sr2_vwc2 re-equipped; z6-13363 replaced by z6-38175
2026-09-16 12:00:00   sr2_vwc3 established on the new weather logger z6-37440
```

> **Established** from the port record and the maintenance log.

The same pattern as Salt River 1: **the hillside station retired rather than
replaced**, the streambank station kept in place with a new box, and a third
profile put on the weather station's logger.

So neither Salt River site has a hillside pit any more, and the
hillside–streambank comparison the prototype was built on has no successor at
either.

### The new box was not logging

*"Online ZentraCloud, was not logging, started logging"* — 2026-09-16.

> **Established** from the maintenance log.

`z6-38175` was installed on 4 September and **twelve days passed before anyone
noticed it was connected but not recording**. The entry is the correction.

> That is the gap the network to-do list exists to close: a device reporting to
> ZentraCloud looks healthy from a distance even when it is producing nothing.

### 2026-09-16 and 09-18 · settling in

```
09-16   SIM swapped to AT&T, desiccant added, VI-FLO sign added
09-16   device renamed from '(blank)' to 'SR2 SB VWC'
09-18   "Switched rechargeable to alkaline"
```

> **Established** from the maintenance log.

The battery change is the response to the failures, done at this station,
`sr1_vwc2` and `ltt1_vwc3` on the same day.

---

## The 10 cm sensor works

`z6-38175`'s shallowest sensor rose **0.106** across the 30 mm of rain on
6–7 October 2026, spanning 0.206 to 0.313 across 50 distinct values.

> **Established** from the Product 1 record.

That is a working shallow sensor behaving as one should.

---

## What follows

### Metadata

```
z6-13363   sr2_vwc2, 2022-05-17 16:15 -> 2026-09-04, replaced
z6-13388   sr2_vwc1, 2022-06-14 14:15 -> 2024-01-22, replaced
z6-12898   sr2_vwc1, 2024-01-22 13:15 -> 2026-09-04, decommissioned
z6-38175   sr2_vwc2, from 2026-09-04 15:55, same position
z6-37440   sr2_vwc3, from 2026-09-16 12:00, on the new weather logger
```

All five correct, and the 2024 replacement is properly bracketed.

None of the retired rows records when its device stopped producing data. That is
in the raw and nowhere else.

**`z6-13388` has no `last_visit` at all** — the only active-era device in the
network with that field empty.

The three older boxes carry no `elev`.

### Maintenance entries

One event has none:

```
2024-01-22   device_replacement   z6-13388 replaced by z6-12898 at the hillside pit
```

The port record captures it; the log does not.

### Product 1

Complete for all five devices.

### `record_confirmed`

```
sr2_vwc2   2022-05-17
sr2_vwc1   2022-06-14
sr2_vwc3   2026-09-16
```

Reason: *port configuration as installed; the 2024 device replacement is in the
port record and the 2026 work is logged; see docs/backfill/sr2_vwc.md*.

---

## Open

- Why `z6-13388` was replaced in January 2024. The port record dates it to the
  minute and nothing says what failed.
- `z6-13388` has no `last_visit`, which is a gap rather than a fact.
- The hillside position is no longer monitored, as at Salt River 1.
- `z6-38175` was connected but not logging for twelve days after installation.
  Whether that is detectable from the data alone — a device reporting battery
  and signal but no measurements — is worth knowing, because the check would be
  cheap.
