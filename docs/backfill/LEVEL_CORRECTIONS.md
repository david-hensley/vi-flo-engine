# Level corrections and sensor heights in the prototype

The prototype applied fixed offsets to water level wherever a logger had moved,
scoured or been redeployed badly. VI-FLO does not carry those corrections - it
derives level from pressure and each deployment's own geometry - but the
offsets are evidence of what changed under a logger, and often the only
record of it. They are gathered here for the day modern sensor elevations and
streambed-to-measuring-point heights are surveyed, and for the Product 3 and 4
decisions that will have to account for the same events.

Old sensor heights are mostly unknown. Where one is known, it is in these
scripts and is listed below. Every value is quoted from the prototype's
`Archiving/<site>_<date>.R` import scripts (see `README.md`, *The prototype
archive*). Signs are as the prototype applied them: added to level.

## Salt River 1 (`sr1_hydro`)

From `sr1_2024-09-23.R`.

| Logger | Period | Correction | Why |
|---|---|---|---|
| 21180078 HOBOlink | 2022-09-20 04:30 → 2023-08-02 13:00 | level recomputed with the weather station's pressure | the HOBOlink's own barometric input was replaced for this span |
| 21180078 HOBOlink | 2023-10-27 23:30 → 2023-11-14 11:15 | **+0.13 m** | streambed scour at the first peak of the Tropical Storm Nicole flood produced false zeroes; *"based on field measurements"* |
| 21180078 HOBOlink | 2022-11-17 01:00 → 2024-09-13 09:00 | **−0.0265 m** | *"erroneously high level reading"* from that date on |
| 21352826 Backup | until 2023-11-14 11:30 | not used | *"Did not actually deploy this logger in the intended position till 2023-11-14 11:30"*; it became the main record from 11:45 |

Its deployment row now starts at 2023-11-14 11:30 (corrected October 2026).
From 2023-10-28 it sat in an emergency position at the site, mostly out of the
water - see `sr1_hydro.md`.

## Salt River 2 (`sr2_hydro`)

From `sr2_2024-09-23.R`.

| Logger | Period | Correction | Why |
|---|---|---|---|
| 21652378 backup | from 2024-08-15 16:00 | **+0.035 m** | to match the HOBOlink it replaced; the HOBOlink's battery charging failed in August 2024 and it died 2024-08-17 05:15 |
| 21652378 backup | from 2024-08-23 15:15 | a further **+0.061 m** (+0.096 m in all) | *"related to a physical data purge redeployment error"* - the logger went back in at a different height |

## Fish Bay (`fb2_hydro`)

From `fb_2024-08-20.R`.

| What | Value | Note |
|---|---|---|
| Slope logger height relative to the main logger | **−0.253 m** | *"negative because below reference - downstream"*: 21179105 as `FishBay_slope`, downstream of 21179106, from 2024-02-05 |
| Weather station elevation change | pressure corrected 2021-10-21 16:00 → 2024-02-06 10:15 | the station *"was moved from the seacoast uphill"*; readings taken while it was carried up were replaced with the previous reading |

## Dorothea (`dor2_hydro`)

From `dor_2024-08-08.R`.

| What | Value | Note |
|---|---|---|
| Slope logger height relative to the main logger | **(5.3 − 3.58) ft = 0.524 m** | rod readings in feet; 21652372 upstream and above 21652381, 2024-02-04 → 2024-06-04 |

## Elsewhere

No level offsets in the Turpentine Run, Reef Bay, Jolly Hill (`lg1`) or River
Gut scripts. Two events there bear on Product 3 rather than geometry:

- **River Gut:** the logger was dislodged in the flood of early May 2024 and
  *"hung on for awhile after being dislodged and produced erroneous values"*
  (`river_2024-08-21.R`)
- **Turpentine Run 1:** the 2025 import *"produced an erroneous dataset because
  of a moved logger"*; a survey of the new pair was needed for a new rating
  curve (`tr1_2025-06-03.R`)
