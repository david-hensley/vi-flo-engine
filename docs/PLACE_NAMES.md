# Place names

A gut in the Virgin Islands rarely has one name. It changes name along its
length, usually taking the name of the estate it crosses. Federal, territorial
and historical sources disagree about which name belongs to which reach, and
sometimes about which branch is the main one. Anyone matching a VI-FLO station
to a USGS gauge, a DPNR plan or a historical map will meet a different name for
the same water.

This is where VI-FLO records which name it uses for each watershed and its
parts, what other sources call them, and why the choice was made.

---

## The convention

A **watershed** is named for the gut at its mouth, or for the bay it reaches.
Its **main stem carries that name all the way to its headwaters**, including
reaches that nobody would call by it in daily life. A **tributary** large
enough to need its own name becomes an **area** within the watershed. Site
names are built from the two, as set out under `watershed` and `area` in
`data/DATA_DICTIONARY.md`.

The reason is the instability described above. Upstream names are the least
settled: the same headwater can carry two or three names across sources, or a
name it shares with one of its own tributaries. The mouth is the one point
every source agrees on, so a name anchored there stays stable however the
names upstream are resolved. The entries below record the names VI-FLO does
not use, so they can still be matched.

**Three names do not follow it.** Bethlehem is not named for its mouth,
Limetree is not a single gut, and UVI is not a watershed at all, but a
campus within Bethlehem. Each is
explained in its entry.

### Spelling

VI-FLO writes **gut**. As Hensley (2025) puts it:

> In the Virgin Islands, these streams are usually called “guts” (occasionally also spelled “ghuts” or “ghauts,” mainly in neighboring islands such as St. Kitts, Saba, and Montserrat)

Older sources often use the Danish **bæk**, a brook, sometimes anglicized as
**beck**: Canaan Beck and St. George Beck survive in McGuire (1925).

---

## St Croix

### Bethlehem

`bt` · areas: Adventure (`bta`)

The largest watershed in the Virgin Islands. Two main branches, western and
eastern, join to form a short trunk to the sea.

| VI-FLO | Other names | Where used |
|---|---|---|
| **Bethlehem**: the eastern branch, as main stem | Bethlehem Gut; Bethlehem Bæk, Bethlehem Creek, Kingshill Gut | USGS, DPNR; McGuire (1925) |
| **Adventure** (area): the western branch | River Gut | USGS, DPNR (2022) |
| | Jealousy Gut, Jealousy Bæk | McGuire (1925) |
| | Adventure Gut | McGuire (1925), as an alias of Jealousy Gut |
| **Adventure West** (area, `btw`): the smaller western tributary of the western branch | Adventure Gut | McGuire (1925) |
| The trunk below the confluence | Fairplain Gut, Fairplain Creek, Fair Plain Gut | McGuire (1925); DPNR (2004), as cited in Lancellotti and Hensley (2024); local usage |
| | River Gut | USGS |

**Why Bethlehem, not Fairplain.** Under the convention this would be the
Fairplain watershed, after the trunk at its mouth. That name is heard less and
less, and recent DPNR documents call the watershed Bethlehem. Choosing
Bethlehem also meant deciding which of the two branches is the main stem: the
eastern one. USGS appears to have taken the opposite view. It carries the name
River Gut from its gauge at River down past the confluence to its airport
gauge, and numbers Bethlehem Gut between the two, as a tributary of River Gut.

**Why Adventure, not River Gut.** "River Gut" comes from River Estate, which
the western branch crosses, and the name is used for that branch by USGS and
by DPNR. VI-FLO does not use it in site names because it is ambiguous: USGS
applies it both to the western branch and to the trunk below the confluence,
which other sources call Fairplain Gut. So **Bethlehem Adventure**, `bta`,
is the western branch that other sources call River Gut, and the `bta2`
gauges sit on it.

**Adventure Gut is two different streams.** McGuire (1925) gives Adventure Gut
its own entry, as a tributary rising at Hardlabor that crosses Adventure
Estate and joins the western branch. It joins just downstream of the `bta2`
gauge. But McGuire's entry for the western branch, under its older name
Jealousy Gut, also lists Adventure Gut as an alias for the branch itself, and
that usage survives locally. In VI-FLO, **Adventure** is the western branch,
and the tributary, if it is ever gauged, will be **Bethlehem Adventure West**,
`btw`.

**Hermitage Pond** (`bt1_pond`) is in the headwaters of the main stem, the
eastern branch. McGuire (1925) places Hermitage Estate in an enclosed valley
near the sources of Bethlehem Gut.

**Smaller names.** DPNR's Fountain Gut is a headwater of the western branch,
on Fountain Estate near Carambola. McGuire's Love Gut is a western tributary
running through Upper and Lower Love.

USGS gauges, in their downstream order:

- 50332000, River Gut at River
- 50334500, Bethlehem Gut
- 50335000, River Gut at Alexander Hamilton Airport

### Caledonia

`cal`

**Caledonia Gut**, Caledonia Bæk in Danish, drains Caledonia Valley, a narrow
gorge along the south slope of Maroon Ridge to Ham Bay. McGuire (1925) gives
its source as Caledonia Spring, near the Springgarden estate house. As far as
is known, it has no other name.

### Creque

`cq`

**Creque Gut** is sometimes called **Creque Dam Gut**, after the dam on it.
McGuire (1925) spells it **Crequis Gut**, Crequis Bæk in Danish: a permanent
watercourse rising on the west slope of Oxford Hill, running the length of the
Crequis Valley, and reaching the west coast south of Sprat Hall.

### La Grange

`lg`

Far up in the rain forest, the main stem is often not called La Grange Gut.
McGuire (1925) names the whole of it **Mount Stewart Gut**, the largest of the
permanent watercourses running west from the northwest highland. It rises
near Annaly, passes the peak and estate it is named for, then turns southwest
through Montpellier, Orangegrove, Jolly Hill, Little Grange and La Grange,
reaching the sea at Fort Frederik. Olasee Davis also gives the upper
reaches as Mount Stewart Gut (Davis 2023), though a tributary also called
Mount Stewart joins the main stem upstream of `lg1_hydro`. Where the gut
crosses Jolly Hill, it is in some places called **Jolly Hill Gut**.

**Harden Gut** is a major tributary in the La Grange area. McGuire has it
rising on Concordia Estate in Westend Quarter, a different Concordia from the
one on Salt River, and flowing northwest through Wheel-of-Fortune and La
Grange.

In the La Grange area the gut was once called a river. The first Danish
governor of St Croix recorded a "river" at La Grange in 1734, reported to run
perennially (Hopkins 1987), and Oldendorp described Jolly Hill Gut as
perennial in the 1760s (Oldendorp 1777), both as cited in Lancellotti and
Hensley (2024).

### Limetree

`lt` · areas: Estate Thomas (`ltt`)

**Limetree** is not one gut. It stands for what other sources call the
**Hovensa** watershed: several separate guts on the south shore, all draining
southward toward what was once the **Krause Lagoon** mangrove swamp. McGuire
(1925) describes the lagoon as shallow pools, channels, mud banks and mangrove
islets, about a mile and a half long, behind Krause Peninsula and Anguilla
Point. It was filled and cleared, with extensive modification, to build St
Croix's south shore industrial complex.

So each of these guts may now reach the sea in a slightly different way, and
no single mouth gives the watershed its name. What unites them is that the
industrial area lies downstream of all of them and interrupts their natural
flow. VI-FLO treats the whole area as one watershed on that basis.

At least one of these guts had a name of its own: McGuire records **Merle
Run**, the French Rivière Merle, draining Slob, Barrenspot and Jerusalem
estates into Limetree Bay, which the French called Grandfond.

### Salt River

`sr` · areas: Lebanon (`srl`)

**Salt River**, or Salt River Gut, is the name at the mouth, and VI-FLO
carries it up the main stem. Historically the upstream reaches were not called
that: they are **Canaan Gut**, sometimes **Concordia**. McGuire (1925) calls
the main stem **Concordia Creek**, also Concordia Bæk or Concordia Gut, rising
on Canaan Estate northeast of Mount Eagle and taking the name Salt River where
it reaches the bay. Its head stream is **Canaan Beck**. The main stem also has
tributaries with names of their own, among them **Lebanon Gut**, also called
**Lebanon Hill Gut**.

**Lebanon** is a VI-FLO area: the basin of Lebanon Gut. Windsor Pond
(`srl1_pond`) is on Lebanon Gut, though the pond itself lies in Estate Lebanon
Hill rather than Windsor.

### St. George

`sg` · areas: Mint (`sgm`)

The **St. George** watershed is called the **Diamond** watershed in other
sources. Its main stem is McGuire's (1925) **St. George Beck**, St. Georges
Bæk in Danish, about 4 miles long, rising on Two-Friends Estate and running
south through Groveplace, Plessen, Diamond and Enfield Green to the south
coast.

**Mint Gut** is its west fork, named for an old mint building near the present
grounds of the St. George Village Botanical Garden. McGuire has it rising in
Beck Grove or Allandale and running south through Allandale, Hope, Mint, St.
George and Diamond to its confluence with St. George Beck. Both cross Diamond
Estate, and McGuire's Diamond entry runs the two names together as "St. George
Bek or Mint Gut".

### UVI

`uvi` · areas: Breadfruit

**UVI** is not a watershed. The stations are named for the institution: the
University of the Virgin Islands' Albert A. Sheen campus on St Croix, which
lies entirely within the Bethlehem watershed.

Its areas are not tributaries either. They are projects on the campus:
**Breadfruit** is the breadfruit orchard project.

---

## St Thomas

### Dorothea

`dor`

**Dorothea** is a modern name. Historically the gut was called **Bonne
Resolution Gut**, the name used for its USGS discharge record (Lancellotti and
Hensley 2024). McGuire (1925) places Bonne Resolution estate about a mile
west of Signal Hill, and gives Dorothea Bay's original name as Lammert Bay.

### Turpentine Run

`tr`

**Turpentine Run** is sometimes called **Nadir Gut**. McGuire (1925) has it
running alongside Turpentine Avenue throughout its length to Mangrove Lagoon.
Nadir estate and Nadir Ridge sit just above the lagoon.

---

## St John

### Fish Bay

`fb`

**Fish Bay Gut**. As far as is known, this is its only name.

### Reef Bay

`rb`

**Reef Bay Gut**. As far as is known, this is its only name.

---

## Sources

Davis, O. (2023, June 20). Open forum: The importance of guts in the Virgin
Islands, part 4. *St. Thomas Source*.
https://stthomassource.com/content/2023/06/20/open-forum-the-importance-of-guts-in-the-virgin-islands-part-4/

Hensley, D. A. (2025). *Soil hydrological studies for water resource
conservation and management in the Virgin Islands* [Doctoral dissertation,
Auburn University]. ProQuest.
https://search.proquest.com/openview/2e75065f15bd1a14f7dadc1f9382a60b/1?pq-origsite=gscholar&cbl=18750&diss=y

Hopkins, D. P. (1987). *The Danish cadastral survey of St. Croix, 1733–1734
(Virgin Islands)* [Doctoral dissertation, Louisiana State University].
https://doi.org/10.31390/gradschool_disstheses.4399

Lancellotti, B. V., & Hensley, D. A. (2024). The state of knowledge of
freshwater resources in the U.S. Virgin Islands: Data scarcity and
implications. *Journal of the American Water Resources Association*, 60(6),
1270–1292. https://doi.org/10.1111/1752-1688.13241

McGuire, J. W. (1925). *Geographic dictionary of the Virgin Islands of the
United States* (Special Publication No. 103). U.S. Coast and Geodetic Survey.
https://library.oarcloud.noaa.gov/docs.lib/htdocs/rescue/cgs_specpubs/QB275U35no1031925.pdf

Oldendorp, C. G. A. (1987). *History of the mission of the Evangelical
Brethren on the Caribbean islands of St. Thomas, St. Croix, and St. John*
(J. J. Bossard, Ed.; A. R. Highfield & V. Barac, Trans.). Karoma Publishers.
(Original work published 1777)

Virgin Islands Department of Planning and Natural Resources. (2022).
*Bethlehem watershed management plan*.
