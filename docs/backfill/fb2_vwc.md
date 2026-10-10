# Fish Bay soil moisture — backfill reconstruction

`fb2_vwc1` · watershed Fish Bay, St John · reconstructed October 2026

A single four-depth streambank pit, the only soil moisture station outside St
Croix, and the only one of the prototype's three soil moisture sites with no
hillside counterpart.

**Its record ends at a manual download on 5 June 2024**, and it was most likely
found dead on the next visit, 24 October. The logger kept recording in between
and that data is on a box that will not answer.

Each claim is graded. **Established** — the data or the code says so directly.
**Inferred** — the best reading of circumstantial evidence. **Unknown** — not
recoverable.

---

## 2022-09-22 · deployed

**z6-13379**, device name `Fish Bay VWC SB`, at 20:15, at 18.32660, -64.76415,
elevation 7.01 m.

```
port 1   TEROS 10   10 cm
port 2   TEROS 10   30 cm
port 3   TEROS 10   50 cm
port 4   TEROS 10  100 cm
port 5   ECRN-50    rain gauge, defunct
```

> **Established** from the port record.

The `SB` is streambank. The prototype's soil moisture design paired a streambank
pit with a hillside one at each site, and **Fish Bay only ever got the
streambank half**.

> **Established.** `vwc.meta.csv` lists `fb.vwc.sb` with no `fb.vwc.hs`, where
> both Salt River sites have both.

---

## The record, and when it ends

```
first reading   2022-09-22 20:15
last reading    2024-06-05 15:15
```

> **Established** from the Product 1 export, 57,869 readings.

The prototype processed 2022-09-23 to 2024-06-05 — 59,677 rows, all streambank.

> **Established** from `fb.vwc.rda`. It covers the station's whole working life:
> nothing was left unprocessed, because there was nothing after.

**That date is a download, not a failure.** It was offloaded by hand on the
St John trip of 5 June 2024, and the record ends at 15:15 because that is when
the reading stopped — not when the logger did.

> **Established** by the person who ran it. The station continued recording
> afterwards and was found unresponsive on the next visit, twenty-one months
> later.

So the station's working life extends past its record, and everything in that
margin is lost.

### How far past

**The next St John visit was 2024-10-24**, and the box is most likely to have
been found dead then.

> **Inferred**, and the strongest reading available.
>
> The visit dates come from the logger file boundaries: Reef Bay offloaded at
> 11:04-11:10, Fish Bay at 13:40-14:08 — about two hours on the Fish Bay site.
> The VWC pit sits roughly 100 m from the gauge, so it is on the way rather than
> a separate expedition.
>
> The later trips argue against a later discovery. The November 2025 notes are
> detailed about Fish Bay — rebar, hose clamps, housing caps, streambed sediment
> samples — and do not mention the soil moisture station at all. A box found
> newly dead that day would likely have been written down.

That visit was not logged: it predates the metadata manager, so nothing in
VI-FLO records it.

**The lost data is therefore at most four and a half months**, from 5 June to
24 October 2024, and possibly much less.

The export also carries a first reading of **2015-03-05**, which is a clock
default rather than a measurement and should be dropped at Product 2.

> **Established** from the raw. The device did not exist in 2015.

---

## 2026-03-23 · the condition recorded

*"physically in good order but ZL6 is non responsive to button press and
bluetooth. ants inside"*

> **Established** from the maintenance log, and the first entry this station
> has.

**This is not the discovery.** The box had been found dead on an earlier,
unlogged visit — most likely 2024-10-24 — and this entry is the first time its
condition was written into VI-FLO, seventeen months later.

**The sensors and the pit are fine; the logger is not.** The installation could
be revived by replacing the box alone — and that is also why the unread data
cannot be recovered. A logger that will not answer a button press or Bluetooth
will not give up what it holds.

> **Inferred** from the entry's wording, which distinguishes the physical
> installation from the logger explicitly.

Ants inside the box recur across the network — `uvi_vwc2` the same month,
`bta2_hydro`'s housing in August.

Seven St Croix boxes were found dead three weeks earlier, having stopped at
different times across 2024 and 2025. Those were cellular and their records end
where they died. **This one is different**: its record ends where it was last
read, and its death came somewhere in the following four and a half months.

---

## What follows

### Metadata

```
z6-13379   fb2_vwc1, from 2022-09-22 20:15   TEROS 10 at 10/30/50/100 + ECRN-50
```

Correct. Status is `defunct` rather than `nonresponsive`, which distinguishes it
from the St Croix boxes — the judgement there was that this one is not coming
back.

The device is 3G and its subscription lapsed in October 2025 — sixteen months
after the last reading, so the two are unrelated.

### Maintenance entries

One event is worth reconstructing:

```
2024-10-24   inspection   found unresponsive; last download 2024-06-05
```

The date is inferred from the St John visit chronology rather than recorded. The
2026 inspection is already logged.

### Product 1

Complete to the last manual download. Nothing after 2024-06-05 exists in any
form.

### What this reconstruction covers

`fb2_vwc1` is reconstructed from **2022-09-22** — its deployment — to the
present.

That is the span of this document, not a claim about the metadata. It says how
far back the history below could be established, not that anyone has stood at
the station and verified it.

**`record_confirmed` is a different thing** and is not set here. It records a
visit at which a station was checked against VI-FLO standards, and it is set
from the maintenance record rather than from reconstruction.

---

## Open

- The pit and sensors are in good order and only the logger failed. Replacing
  the box would revive a four-year installation.
- Exactly when it stopped. Bounded between 2024-06-05 and 2024-10-24, and the
  readings in that window are unrecoverable either way.
- The 2024-10-24 visit is not in the maintenance log. It predates the metadata
  manager and is reconstructed from logger file boundaries.
- Fish Bay never had a hillside pit. Whether one was intended and not installed,
  or the site was always streambank-only, is not recorded.
- The ECRN-50 on port 5 is defunct with no installation or failure date, as at
  the six other stations that carried one.
