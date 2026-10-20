# TerraScape source candidates (partial audit)

**Retrieval snapshot:** 2026-10-06. This is a source-evidence ledger, not a catalog design decision. Rows marked `candidate / unresolved` are intentionally not counted as mapped or covered. Do not import TerraScape score, card-draw, trading-value, biome-conversion, or victory rules into the campaign city.

## Public reference manifest and scope gap (2026-10-06)

The row-level JSON is [`terrascape-reference-manifest.json`](terrascape-reference-manifest.json); it preserves card/deck fields, merge inputs where publicly listed, monument candidates/stages, source URLs, exact source-version fit, and `confirmed` / `candidate` / `unknown` confidence. It includes 86 named deck-card references, 12 separate building/object leads, 46 merge-result candidates, and six monument candidates. These counts are **observed source rows**, not a claim that the 2.2.0.5 + Ancient Egypt universe is complete.

A live Miraheze API census on 2026-10-06 again returned 138 mainspace pages, 19 Deck-category pages, six Egypt deck pages, 47 Building-category pages, and no Ra deck page. The seven-deck scenario checklist and in-game video confirm Ra is used but do not establish its cards. Current web searches found no full Ra list. Preserve `Template` and `Temple (Ra)` as separate unresolved labels, keep `Treasurer` and `Embalmer` as building leads without confirmed Ra-deck membership, and leave the rest of the Ra roster `unknown`. `Temple of Luxor` stays a candidate monument; it is not a building/card or a Ra card. `Amun-Ra` is absent from the manifest.

The public [Steam merge guide, ID 3292704537](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) was fetched on 2026-10-06. Steam's public `GetPublishedFileDetails` API reports creation 2024-07-19 and last edit 2026-08-12; the guide still does not declare an exact game patch. It visibly enumerates 30 medieval merge recipes; its inputs remain `candidate` despite the recent edit date. The JSON records those inputs, guide dates, and source references for the corresponding 30 rows. Egyptian merge-result leads have no complete public recipe set in the sources checked; their `inputs` remain `null` with `input_confidence: unknown`, not guessed.


## Building-card candidates

The official [TerraScape 1.0 launch announcement](https://steamcommunity.com/games/2290000/announcements/detail/5842939267354480431), published 2024-07-09 UTC, gives the **launch-only** totals: 52 cards and 21 merged structures. The official [DAWN 1.1 changelog](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) later added the Wetlands deck's four named buildings and five merged buildings. The current community [Deck page](https://terrascape.fandom.com/wiki/Deck?oldid=472), pinned to Fandom revision 472 (2026-02-22 via API), lists 52 entries across thirteen four-card decks plus two Special Card entries. The current [Merged Buildings page](https://terrascape.fandom.com/wiki/Merged_Buildings?oldid=499), revision 499 (2026-03-02), lists 14 results. Both snapshots predate the Ancient Egypt DLC release on 2026-03-09, so they are base/medieval evidence only and cannot establish the DLC roster. Their counts also do not reconcile later additions and are not proof of complete current coverage.

The current Wiki rows are retained alongside release-era poster names, official 1.0 labels, and later Steam-guide evidence; the resulting 62 source-name candidates are **not** asserted to be 62 distinct/current in-game cards. The community [Card Decks guide for Game Version 1.1.1.2](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386), posted 2024-12-26, depicts 13 four-card decks (52 cards, including Wetlands) plus six extra/special cards: Hop Field, Beekeeper, Church, Monastery, Granary, and Boat Builder. Its Community/Trade deck uses Chapel/Hospital and Harbor, whereas the Fandom Deck revision 472 lists Temple/Surgeon and Trading Post; Fandom also places Chapel under Special Card. The current page's February 2026 revision still predates Ancient Egypt release and cannot resolve later scope. Retain these cross-snapshot names and slot differences until resolved; do not merge or drop them silently. The earlier [Game Version 1.0.0.4 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3292908489) depicts 48 cards in twelve four-card decks. The four Wetlands names are independently confirmed by the official 1.1 announcement. Where the page has an individual article, it is linked. No card count here is treated as a complete current source roster.

`Disposition` for every row: **candidate / unresolved** — retain as a distinct source entry pending canonical role/duplicate/exclusion review in task 1.3. `Deck-page link` is the community roster source; official update links are added where they verify names.

| ID | Source entry | Deck / source class | Source | Disposition |
|---|---|---|---|---|
| TS-B-001 | Gatherer Hut | Basic Food | [article](https://terrascape.fandom.com/wiki/Gatherer_Hut) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Basic_Food) | Candidate / unresolved |
| TS-B-002 | Hunting Cabin | Basic Food | [article](https://terrascape.fandom.com/wiki/Hunting_Cabin) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Basic_Food) | Candidate / unresolved |
| TS-B-003 | Wheat Field | Basic Food | [article](https://terrascape.fandom.com/wiki/Wheat_Field) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Basic_Food) | Candidate / unresolved |
| TS-B-004 | Cattle Pasture | Basic Food | [article](https://terrascape.fandom.com/wiki/Cattle_Pasture) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Basic_Food) | Candidate / unresolved |
| TS-B-005 | Cottages | Settlement | [article](https://terrascape.fandom.com/wiki/Cottages) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Settlement) | Candidate / unresolved |
| TS-B-006 | Well | Settlement | [article](https://terrascape.fandom.com/wiki/Well) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Settlement) | Candidate / unresolved |
| TS-B-007 | Houses | Settlement | [article](https://terrascape.fandom.com/wiki/Houses) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Settlement) | Candidate / unresolved |
| TS-B-008 | Market | Settlement | [article](https://terrascape.fandom.com/wiki/Market) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Settlement) | Candidate / unresolved |
| TS-B-009 | Herbalist | Wetlands | [article](https://terrascape.fandom.com/wiki/Herbalist) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Wetlands) · [official DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-B-010 | Reed Cutter | Wetlands | [article](https://terrascape.fandom.com/wiki/Reed_Cutter) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Wetlands) · [official DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-B-011 | Peat Digger | Wetlands | [article](https://terrascape.fandom.com/wiki/Peat_Digger) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Wetlands) · [official DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-B-012 | Rush Weaver | Wetlands | [article](https://terrascape.fandom.com/wiki/Rush_Weaver) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Wetlands) · [official DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-B-013 | Lumberjack | Forestry | [article](https://terrascape.fandom.com/wiki/Lumberjack) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Forestry) | Candidate / unresolved |
| TS-B-014 | Forester | Forestry | [article](https://terrascape.fandom.com/wiki/Forester) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Forestry) | Candidate / unresolved |
| TS-B-015 | Saw Mill | Forestry | [article](https://terrascape.fandom.com/wiki/Saw_Mill) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Forestry) | Candidate / unresolved |
| TS-B-016 | Charcoal Burner | Forestry | [article](https://terrascape.fandom.com/wiki/Charcoal_Burner) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Forestry) | Candidate / unresolved |
| TS-B-017 | Wind Mill | Foodstuff | [article](https://terrascape.fandom.com/wiki/Wind_Mill) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Foodstuff) | Candidate / unresolved |
| TS-B-018 | Brewery | Foodstuff | [article](https://terrascape.fandom.com/wiki/Brewery) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Foodstuff) | Candidate / unresolved |
| TS-B-019 | Butcher | Foodstuff | [article](https://terrascape.fandom.com/wiki/Butcher) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Foodstuff) | Candidate / unresolved |
| TS-B-020 | Bakery | Foodstuff | [article](https://terrascape.fandom.com/wiki/Bakery) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Foodstuff) | Candidate / unresolved |
| TS-B-021 | Flax Field | Textiles | [article](https://terrascape.fandom.com/wiki/Flax_Field) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Textiles) | Candidate / unresolved |
| TS-B-022 | Tanner | Textiles | [article](https://terrascape.fandom.com/wiki/Tanner) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Textiles) | Candidate / unresolved |
| TS-B-023 | Sheep Pasture | Textiles | [article](https://terrascape.fandom.com/wiki/Sheep_Pasture) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Textiles) | Candidate / unresolved |
| TS-B-024 | Tailor | Textiles | [article](https://terrascape.fandom.com/wiki/Tailor) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Textiles) | Candidate / unresolved |
| TS-B-025 | Fish Trap | Fishing | [article](https://terrascape.fandom.com/wiki/Fish_Trap) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Fishing) | Candidate / unresolved |
| TS-B-026 | Fishing Boat | Fishing | [article](https://terrascape.fandom.com/wiki/Fishing_Boat) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Fishing) | Candidate / unresolved |
| TS-B-027 | Shell Farm | Fishing | [article](https://terrascape.fandom.com/wiki/Shell_Farm) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Fishing) | Candidate / unresolved |
| TS-B-028 | Fishery | Fishing | [article](https://terrascape.fandom.com/wiki/Fishery) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Fishing) | Candidate / unresolved |
| TS-B-029 | Quarry | Mining | [article](https://terrascape.fandom.com/wiki/Quarry) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Mining) | Candidate / unresolved |
| TS-B-030 | Iron Mine | Mining | [article](https://terrascape.fandom.com/wiki/Iron_Mine) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Mining) | Candidate / unresolved |
| TS-B-031 | Stonemason | Mining | [article](https://terrascape.fandom.com/wiki/Stonemason) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Mining) | Candidate / unresolved |
| TS-B-032 | Iron Smelter | Mining | [article](https://terrascape.fandom.com/wiki/Iron_Smelter) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Mining) | Candidate / unresolved |
| TS-B-033 | Tavern | Community | [article](https://terrascape.fandom.com/wiki/Tavern) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Community) | Candidate / unresolved |
| TS-B-034 | Bath House | Community | [article](https://terrascape.fandom.com/wiki/Bath_House) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Community) | Candidate / unresolved |
| TS-B-035 | Temple | Community | [article](https://terrascape.fandom.com/wiki/Temple) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Community) (current Wiki; Steam 1.1.1.2 poster has `Chapel`; official TIDE 1.2 adds Temple but does not identify replacement mapping) | Candidate / unresolved |
| TS-B-036 | Surgeon | Community | [article](https://terrascape.fandom.com/wiki/Surgeon) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Community) (current Wiki; release-era poster has `Hospital`) | Candidate / unresolved |
| TS-B-037 | Haulier | Trade | [article](https://terrascape.fandom.com/wiki/Haulier) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Trade) | Candidate / unresolved |
| TS-B-038 | Storehouse | Trade | [article](https://terrascape.fandom.com/wiki/Storehouse) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Trade) | Candidate / unresolved |
| TS-B-039 | Lighthouse | Trade | [article](https://terrascape.fandom.com/wiki/Lighthouse) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Trade) | Candidate / unresolved |
| TS-B-040 | Trading Post | Trade | [article](https://terrascape.fandom.com/wiki/Trading_Post) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Trade) (current Wiki; release-era poster has `Harbor`) | Candidate / unresolved |
| TS-B-041 | Carpenter | Workmanship | [article](https://terrascape.fandom.com/wiki/Carpenter) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Workmanship) | Candidate / unresolved |
| TS-B-042 | Pottery | Workmanship | [article](https://terrascape.fandom.com/wiki/Pottery) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Workmanship) | Candidate / unresolved |
| TS-B-043 | Builders Guild | Workmanship | [article](https://terrascape.fandom.com/wiki/Builders_Guild) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Workmanship) | Candidate / unresolved |
| TS-B-044 | Blacksmith | Workmanship | [article](https://terrascape.fandom.com/wiki/Blacksmith) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Workmanship) | Candidate / unresolved |
| TS-B-045 | Park | Culture | [article](https://terrascape.fandom.com/wiki/Park) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Culture) | Candidate / unresolved |
| TS-B-046 | Town Hall | Culture | [article](https://terrascape.fandom.com/wiki/Town_Hall) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Culture) | Candidate / unresolved |
| TS-B-047 | Theater | Culture | [article](https://terrascape.fandom.com/wiki/Theater) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Culture) | Candidate / unresolved |
| TS-B-048 | Treasury | Culture | [article](https://terrascape.fandom.com/wiki/Treasury) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Culture) | Candidate / unresolved |
| TS-B-049 | School | Knowledge | [article](https://terrascape.fandom.com/wiki/School) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Knowledge) | Candidate / unresolved |
| TS-B-050 | Alchemist | Knowledge | [article](https://terrascape.fandom.com/wiki/Alchemist) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Knowledge) | Candidate / unresolved |
| TS-B-051 | Library | Knowledge | [article](https://terrascape.fandom.com/wiki/Library) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Knowledge) | Candidate / unresolved |
| TS-B-052 | Engineer | Knowledge | [article](https://terrascape.fandom.com/wiki/Engineer) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Knowledge) | Candidate / unresolved |
| TS-B-053 | Chapel | Community (Steam deck posters) / Special card (current Wiki) | [Steam 1.0.0.4 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3292908489) · [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) · [current Wiki special-card roster](https://terrascape.fandom.com/wiki/Deck#Special_Card) | Candidate / unresolved; conflicting slot assignment |
| TS-B-054 | Granary | Special card (current Wiki and Steam 1.1.1.2 poster) | [article](https://terrascape.fandom.com/wiki/Granary) · [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) · [deck roster](https://terrascape.fandom.com/wiki/Deck#Special_Card) | Candidate / unresolved |
| TS-B-055 | Hospital | Community (Steam 1.0.0.4 / 1.1.1.2 posters) | [Steam 1.0.0.4 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3292908489) · [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved; Wiki currently lists Surgeon instead |
| TS-B-056 | Harbor | Trade (Steam 1.0.0.4 / 1.1.1.2 posters) | [Steam 1.0.0.4 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3292908489) · [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved; Wiki currently lists Trading Post instead |
| TS-B-057 | Hop Field | Special/extra card (Steam 1.1.1.2 poster) | [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved |
| TS-B-058 | Beekeeper | Special/extra card (Steam 1.1.1.2 poster) | [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved |
| TS-B-059 | Church | Special/extra card (Steam 1.1.1.2 poster) | [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved |
| TS-B-060 | Monastery | Special/extra card (Steam 1.1.1.2 poster) | [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved |
| TS-B-061 | Boat Builder | Special/extra card (Steam 1.1.1.2 poster) | [Steam 1.1.1.2 deck poster](https://steamcommunity.com/sharedfiles/filedetails/?id=3392870386) | Candidate / unresolved |
| TS-B-062 | Weaver | Deck/category not established (official 1.0 release changelog only) | [official 1.0 release changelog](https://steamcommunity.com/games/2290000/announcements/detail/5969041959961134618) | Candidate / unresolved; not represented by this name in the 1.0.0.4 poster or current Wiki roster |

### Official 1.0 building-label cross-check

The official [1.0 release changelog](https://steamcommunity.com/games/2290000/announcements/detail/5969041959961134618) names twelve individual new buildings, while the preceding [launch announcement](https://steamcommunity.com/games/2290000/announcements/detail/5842939267354480431) says thirteen. This is a name-level crosswalk only: where labels differ from the candidate roster, do not assume they are aliases or distinct cards until source-version evidence confirms it. `Weaver` is retained as its own unresolved candidate because no exact-name match appears in the 1.0.0.4 poster or current Wiki rows.

| Official 1.0 label | Candidate row | Crosswalk status |
|---|---|---|
| Cattlefarm | TS-B-004 | Possible label variant of Cattle Pasture; unresolved |
| Flax | TS-B-021 | Possible label variant of Flax Field; unresolved |
| Sheep | TS-B-023 | Possible label variant of Sheep Pasture; unresolved |
| Weaver | TS-B-062 | Official 1.0 label; no exact roster match |
| Tanner | TS-B-022 | Exact label match |
| Bathhouse | TS-B-034 | Spacing-only label difference from Bath House |
| Lighthouse | TS-B-039 | Exact label match |
| Harbor | TS-B-056 | Exact label match in the 1.0.0.4 poster; current Wiki lists Trading Post |
| Carpenter | TS-B-041 | Exact label match |
| Potter | TS-B-042 | Possible label variant of Pottery; unresolved |
| Townhall | TS-B-046 | Spacing-only label difference from Town Hall |
| Theater | TS-B-047 | Exact label match |

## Base-game merged-building candidates (partial community union)

The official [1.0 launch announcement](https://steamcommunity.com/games/2290000/announcements/detail/5842939267354480431) reports 21 merged structures at release. Its [1.0 release changelog](https://steamcommunity.com/games/2290000/announcements/detail/5969041959961134618) names four new results, including `Greater Mill`; the 1.0.0.4 poster depicts 20 results and labels one `Ox Mill`, so `Greater Mill` is a plausible missing 21st but must not be silently merged with or separated from `Ox Mill` without recipe/identity evidence. The official [DAWN 1.1 changelog](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) adds five named results: Ropery, Sanctuary, Henge, City Park, and Pond Farm. The official [TIDE 1.2 changelog](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446), released 2025-05-29, names five more merged-building additions (University, Timber Mill, Harbor, Herb Garden, Hospital) and two merged-building variants (Royal Forest Variant, CityDistrict Variant). The [TheGamer guide](https://www.thegamer.com/terrascape-every-merged-building-and-how-to-make-them/), published 2024-07-29, lists 20 results; the current [TerraScape Wiki merged-building page](https://terrascape.fandom.com/wiki/Merged_Buildings), retrieved 2026-10-04, lists 14. Their union has 23 names, but these snapshots do not establish complete chronology or coverage. A separate [Steam Community guide, “All merged buildings (Release Version)”](https://steamcommunity.com/sharedfiles/filedetails/?id=3144186455), identifies its poster as Game Version **1.0.0.4** and depicts 20 results; its 2025 comment calls it outdated. The later [DamRiele Steam guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) enumerates 30 names with recipes, crosswalked below. The 1.0 poster's 20 results plus five DAWN additions and five TIDE additions imply 31 named results, while the later guide enumerates 30; one launch-era result or later chronology remains unresolved, and the two explicit TIDE variants require separate review. `TG`, `Wiki`, Steam guides, and official update names identify evidence; no row is a final canonical disposition.

| ID | Merge result | Source | Disposition |
|---|---|---|---|
| TS-M-001 | Fruit Farm | TG; Wiki | Candidate / unresolved |
| TS-M-002 | Farmstead | TG; Wiki | Candidate / unresolved |
| TS-M-003 | Vineyard | TG | Candidate / unresolved |
| TS-M-004 | Ox Mill | TG | Candidate / unresolved |
| TS-M-005 | Manor Farm | TG | Candidate / unresolved |
| TS-M-006 | Smock Mill | TG | Candidate / unresolved |
| TS-M-007 | Shieling | TG | Candidate / unresolved |
| TS-M-008 | Forest Settlement | TG; Wiki | Candidate / unresolved |
| TS-M-009 | Royal Forest | TG; Wiki | Candidate / unresolved |
| TS-M-010 | Fishing Outpost | TG | Candidate / unresolved |
| TS-M-011 | Fish Farm | TG | Candidate / unresolved |
| TS-M-012 | Mining Enclave | TG | Candidate / unresolved |
| TS-M-013 | Iron Mining Camp | TG | Candidate / unresolved |
| TS-M-014 | Liquor Distillery | TG | Candidate / unresolved |
| TS-M-015 | Construction Yard | TG | Candidate / unresolved |
| TS-M-016 | Longhouse | TG; Wiki | Candidate / unresolved |
| TS-M-017 | City District | TG; Wiki | Candidate / unresolved |
| TS-M-018 | Trade District | TG | Candidate / unresolved |
| TS-M-019 | Cathedral | TG | Candidate / unresolved |
| TS-M-020 | Citadel of Wisdom | TG | Candidate / unresolved |
| TS-M-021 | Sanctuary | Wiki; [DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-M-022 | Herb Garden | Wiki; [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446) | Candidate / unresolved |
| TS-M-023 | Pond Farm | Wiki; [DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-M-024 | Ropery | [DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-M-025 | Henge | [DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-M-026 | City Park | [DAWN 1.1](https://steamcommunity.com/games/2290000/announcements/detail/1784506359022523) | Candidate / unresolved |
| TS-M-038 | Greater Mill | [official 1.0 release changelog](https://steamcommunity.com/games/2290000/announcements/detail/5969041959961134618) | Candidate / unresolved; plausible missing 21st launch result; do not merge with TS-M-004 Ox Mill without source identity/recipe evidence |

### Official 1.0 release merge-name cross-check

The 1.0 release changelog's four named merged-building outputs crosswalk to three established candidate names and the unresolved `Greater Mill` row. These are release-note names, not a full list of all 21 launch merges.

| Official 1.0 result | Candidate row | Crosswalk status |
|---|---|---|
| Fruit Farm | TS-M-001 | Exact label match |
| Ox Mill | TS-M-004 | Exact label match |
| Greater Mill | TS-M-038 | Separate official label; relation to Ox Mill unresolved |
| Shieling | TS-M-007 | Exact label match |

## Ancient Egypt DLC additions (named, still partial)

The DLC released on 2026-03-09. Its official [release announcement](https://steamcommunity.com/games/2290000/announcements/detail/1826362059930705) describes monuments and merge mechanics but does not enumerate the full source roster. The official [RISE update 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686), dated 2026-07-21, explicitly names five merged buildings and three monuments. Official patch notes 2.0.0.2 and 2.1.0.1 expose additional Egyptian building/card and merge-name leads. The community [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158), posted 2026-05-08, explicitly labels additional in-game objectives as buildings, merged buildings, and monument stages; it is a partial scenario checklist, not a complete catalog. These are source candidates only: recipes, predecessor buildings, item types, and full DLC coverage remain unaudited.

| ID | Egypt merge result | Source version | Disposition |
|---|---|---|---|
| TS-M-027 | Lotus Basin | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-M-028 | Nun Cistern | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-M-029 | Kenbet | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-M-030 | Caravansary | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-M-031 | Great Plaza | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-M-039 | Limestone Quarry | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / explicitly called a merged building by RISE and scenario guide; recipe/introduction version unresolved |
| TS-M-040 | Gods Plaza | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario guide explicitly labels the result a Merged Building; service/layout and recipe details remain unresolved |
| TS-M-041 | Clay Pit | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario guide explicitly labels Clay Pit a Merged Building result; recipe/predecessors unresolved |
| TS-M-042 | Dromos | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario guide explicitly labels it a Merged Building; patch links its service-gap role to Kenbet; recipe unresolved |
| TS-M-043 | Indigo Farm | [official Bugfix 2.0.0.8 notes](https://steamcommunity.com/games/2290000/announcements/detail/1833334318569149); [Miraheze Version History rev 476](https://terrascape.miraheze.org/w/index.php?title=Version_History&oldid=476) | Candidate / notes identify undoing a merge of Indigo Farm (Ancient Egypt) on Kemet; exact recipe and predecessor state unverified |
| TS-M-044 | Greater Noria | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario checklist explicitly labels it a Merged Building; recipe and relation to the Noria card are unverified |
| TS-M-045 | Gold Mine | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario checklist explicitly labels it a Merged Building; recipe and source-card relationship unverified |
| TS-M-046 | Basalt Quarry | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario checklist explicitly labels it a Merged Building; recipe and source-card relationship unverified |

## Medieval post-release merged-building additions and variants

Official TIDE 1.2 additions are listed separately from Ancient Egypt. TIDE names five merged buildings and two variants; the guide's recipe wording is retained where available.

| ID | Merge result / variant | Source version | Disposition |
| TS-M-032 | Hospital | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446); [Steam guide `3292704537`](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) | Candidate / unresolved; recipe: Surgeon + Bath House + Chapel |
| TS-M-033 | University | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446); [Steam guide `3292704537`](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) | Candidate / unresolved; recipe: 2 Schools + Library + Alchemist |
| TS-M-034 | Harbor (guide label: Port) | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446); [Steam guide `3292704537`](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) | Candidate / unresolved; guide recipe: 3 Traders + Haulier + Lighthouse + Storehouse; same-name card entry remains a separate source row |
| TS-M-035 | Timber Mill (guide label: Lumber-mill) | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446); [Steam guide `3292704537`](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) | Candidate / unresolved; guide recipe: Sawmill + Carpenter + 2 Rivers |
| TS-M-036 | Royal Forest Variant | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446) | Candidate / unresolved; TIDE explicitly names it as a merged-building variant; compare player-visible behavior with TS-M-009 before canonical deduplication |
| TS-M-037 | CityDistrict Variant | [official TIDE 1.2](https://steamcommunity.com/games/2290000/announcements/detail/1800991756324446) | Candidate / unresolved; TIDE explicitly names it as a merged-building variant; compare player-visible behavior with TS-M-017 before canonical deduplication |


### Steam guide cross-check: 30 medieval results

The community guide [All Merged Buildings in release version](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537) was posted 2024-07-19 and updated Aug 12 (Steam omits the year in the captured page). Its index and recipe text enumerate 30 results. The table records a name/recipe crosswalk to the candidate ledger; guide wording is retained as evidence, not promoted to official game names. This is useful additional coverage evidence but does not establish the frozen 2026 source roster or canonical dispositions.

| Steam guide label | Candidate row | Crosswalk note |
|---|---|---|
| Long house | TS-M-016 | Longhouse |
| City block | TS-M-017 | City District |
| Royal Forest | TS-M-009 | Same label |
| Forest settlement | TS-M-008 | Same label |
| Fruit farm | TS-M-001 | Same label |
| Farm | TS-M-002 | Farmstead; guide recipe names wheat fields and a hut |
| Animal mill | TS-M-004 | Ox Mill; guide recipe names cattle pasture and a mill |
| Manor | TS-M-005 | Manor Farm |
| Windmill | TS-M-006 | Smock Mill |
| Fishing camp | TS-M-010 | Fishing Outpost |
| Fishing farm | TS-M-011 | Fish Farm |
| Vineyard | TS-M-003 | Same label |
| Mining camp | TS-M-013 | Iron Mining Camp |
| Mining community | TS-M-012 | Mining Enclave |
| Hut | TS-M-007 | Shieling; recipe is three sheep pastures |
| Building Yard | TS-M-015 | Construction Yard |
| Distillery | TS-M-014 | Liquor Distillery |
| Cathedral | TS-M-019 | Same label |
| Citadel of Wisdom | TS-M-020 | Same label |
| Shopping district | TS-M-018 | Trade District |
| Sanctuary | TS-M-021 | Same label |
| Henge | TS-M-025 | Same label |
| Pond farming | TS-M-023 | Pond Farm |
| Rope Guy | TS-M-024 | Ropery |
| City Park | TS-M-026 | Same label |
| Herb garden | TS-M-022 | Same label |
| Hospital | TS-M-032 | New candidate; recipe names Surgeon, Bath House, Chapel |
| University | TS-M-033 | New candidate; recipe names two Schools, Library, Alchemist |
| Port | TS-M-034 | New candidate; recipe names Traders, Haulier, Lighthouse, Storehouse |
| Lumber-mill | TS-M-035 | New candidate; recipe names Sawmill, Carpenter, two Rivers |

### Ancient Egypt monuments

| ID | Egypt monument result | Source version | Disposition |
|---|---|---|---|
| TS-MON-001 | Aswan Obelisk | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-MON-002 | Step Pyramid | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-MON-003 | Temple of Luxor | [RISE 2.1.0.0](https://steamcommunity.com/games/2290000/announcements/detail/1838407329269686) | Candidate / unresolved |
| TS-MON-004 | Pyramid | [Patch 2.0.0.2 construction-visual notes](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / official notes identify staged construction; scenario checklist references upgrades through VIII; exact relation to other pyramids unresolved |
| TS-MON-005 | Bent Pyramid | [Patch 2.0.0.2 construction-visual notes](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964) | Candidate / construction-stage visuals named; monument identity/stage rules pending |
| TS-MON-006 | Sphinx | [Patch 2.0.0.2 construction-visual notes](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964); [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Candidate / scenario checklist names construction, raising, and finalization stages; exact stage/variant identity pending |

### Ancient Egypt gameplay cross-check (Ra chapter; secondary video evidence)

The public [Scales of Fate gameplay video, Part 3](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1150s), sampled at 19:10 (chapter 6, objective 6/11), shows the in-game German objective `Platziere Tempel (Ra)` (“Place Temple (Ra)”) and the following objective `Platziere Schatzmeister mit Diamant-Wertung` (“Place Treasurer with Diamond rating”). At 19:50 ([same video](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1190s)), an in-game toast says `Einbalsamierer ist jetzt verfügbar` (“Embalmer is now available”), while a story overlay names `Die Hohepriesterin` (“the High Priestess”). At 20:40 ([same video](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1240s)), the `Einbalsamierer` card and its building-detail panel are visible. This directly supports an in-scenario Temple associated with Ra, a Treasurer objective, and an Embalmer building/card; the High Priestess is only evidenced as a story character, not as a building/card. It conflicts at the name level with the Steam scenario checklist's English `Template`; treat `Template` vs. `Temple (Ra)` as an unresolved source/transcription/localization discrepancy, not an approved alias or distinct pair. It does not provide the four-card Ra deck list or establish whether `Temple (Ra)` is distinct from the base-game/TIDE `Temple` card. The video is secondary gameplay evidence; no card identity or catalog row is inferred from its objective alone.

| Candidate ID | Observed UI label | Evidence | Status |
|---|---|---|---|
| TS-E-V-001 | `Temple (Ra)` / German `Tempel (Ra)` | [Part 3 at 19:10](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1150s), Scales of Fate, objective 6/11 | In-game scenario objective; Ra association visible. Identity/canonical card membership unresolved. |
| TS-E-B-009 (corroboration) | `Treasurer` / German `Schatzmeister` | Same frame; subsequent objective specifies Diamond rating | Building objective confirmed in this scenario; deck/card membership unresolved. |
| TS-E-B-011 (corroboration) | `Embalmer` / German `Einbalsamierer` | [Part 3 at 19:50](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1190s) availability toast; [20:40](https://www.youtube.com/watch?v=YmYqInSd4Zc&t=1240s) card/tooltip panel | In-game availability and a build-card detail panel corroborate the building; Ra-deck membership/canonical identity unresolved. |
| — (role exclusion) | `High Priestess` / German `Die Hohepriesterin` | Same 19:50 scene, narrative dialogue overlay | Story character/dialogue only in this evidence; do not count as a building/card. |

### Official Ancient Egypt Steam screenshots (partial card cross-check)

The publisher's [Steam store gallery for the Ancient Egypt DLC](https://store.steampowered.com/app/3868750/TerraScape_Ancient_Egypt/), retrieved 2026-10-05 via Steam app-details, exposes 19 official screenshots. Screenshot [02](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/3868750/96bc7a0521e9d9257b011eee380e2b9831b3fb0f/ss_96bc7a0521e9d9257b011eee380e2b9831b3fb0f.1920x1080.jpg) visibly labels `Shadoof`, `Well`, `Housing`, `Nile Workshop`, and `Clay Hut`; screenshot [03](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/3868750/37f1d1333f553185a6a3a99cbc668cf628ebbe3e/ss_37f1d1333f553185a6a3a99cbc668cf628ebbe3e.1920x1080.jpg) labels `Worker Camp`, `Geologist`, `Stone Mason`, and `Architect`, and displays `Sphinx`/`Pyramid` selection/details. These publisher images corroborate a subset of the six indexed Egypt decks and monument candidates, but do not show the full Egypt roster or Ra deck contents.

### Ancient Egypt deck-card candidates (Miraheze Wiki snapshot)

The [Miraheze MediaWiki API](https://terrascape.miraheze.org/w/api.php) is accessible with a TLS 1.2 client. Retrieved 2026-10-04, the [`Category:Deck` index](https://terrascape.miraheze.org/wiki/Category:Deck) contains six Ancient Egypt deck pages, each with four card names (24 references total). A fresh API census on 2026-10-05 returned 138 mainspace pages, 19 Deck-category pages, eight `Category:Ancient Egypt` members (six deck pages plus `Shadoof` and `Worker Camp`), and 47 Building-category pages. The captured full all-pages listing and direct API `allpages`/`search` queries for `Ra` / `Ra deck` still return no mainspace Ra page. The six deck-page revisions are dated 2026-03-12, three days after DLC release: Pharaoh 462, Geb 463, Osiris 464, Bastet 465, Ptah 466, and Isis 467. These are community-wiki card-name references, not a game-data export; card/building type and post-release completeness remain unverified. Isis and Ptah pages reference unlocking a `Ra` deck, but no Ra page occurs in the captured all-pages or Deck-category listing. Direct review of the [Egypt Scenarios Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) (posted 2026-05-08; page retrieved 2026-10-05) adds the missing confirmation: in its `The Scales of Fate` scenario it lists Pharaoh, Geb, Bastet, Osiris, Ptah, Isis, and Ra; objective 6 unlocks Ra, objective 7 places `Template`, objective 8 earns Ra points, objective 9 creates `Gods Plaza`, and objective 10 places `Embalmer`. The page now displays a removed/incompatible banner, although its text remains visible. The gameplay cross-check above independently shows the in-game objective `Temple (Ra)` at 19:10, rather than `Template`; preserve the discrepancy rather than silently normalizing it. Together these sources establish the Ra deck's in-scenario use and provide scenario/objective leads, not the four-card Ra roster or complete DLC catalog.

| ID | Deck | Card label | Source revision | Disposition |
|---|---|---|---|---|
| TS-E-C-001 | Pharaoh | Shadoof | [rev 462](https://terrascape.miraheze.org/w/index.php?title=Pharaoh&oldid=462) | Deck card confirmed; buildable-building vs special-card role pending |
| TS-E-C-002 | Pharaoh | Worker Camp | [rev 462](https://terrascape.miraheze.org/w/index.php?title=Pharaoh&oldid=462) | Deck card confirmed; buildable-building vs special-card role pending |
| TS-E-C-003 | Pharaoh | Scout | [rev 462](https://terrascape.miraheze.org/w/index.php?title=Pharaoh&oldid=462) | Deck card confirmed; exact role pending |
| TS-E-C-004 | Pharaoh | Geologist | [rev 462](https://terrascape.miraheze.org/w/index.php?title=Pharaoh&oldid=462) | Deck card confirmed; exact role pending |
| TS-E-C-005 | Bastet | Housing | [rev 465](https://terrascape.miraheze.org/w/index.php?title=Bastet&oldid=465) | Deck card confirmed; exact building/card behavior pending |
| TS-E-C-006 | Bastet | Well | [rev 465](https://terrascape.miraheze.org/w/index.php?title=Bastet&oldid=465) | Deck card confirmed; link target is `Well (Ancient Egypt)`, retain this variant separately from base-game Well pending identity check |
| TS-E-C-007 | Bastet | Bazaar | [rev 465](https://terrascape.miraheze.org/w/index.php?title=Bastet&oldid=465) | Deck card confirmed; exact behavior pending |
| TS-E-C-008 | Bastet | Shrine | [rev 465](https://terrascape.miraheze.org/w/index.php?title=Bastet&oldid=465) | Deck card confirmed; exact behavior pending |
| TS-E-C-009 | Geb | Field | [rev 463](https://terrascape.miraheze.org/w/index.php?title=Geb&oldid=463) | Deck card confirmed; exact behavior pending |
| TS-E-C-010 | Geb | Farmhand Camp | [rev 463](https://terrascape.miraheze.org/w/index.php?title=Geb&oldid=463) | Deck card confirmed; exact behavior pending |
| TS-E-C-011 | Geb | Noria | [rev 463](https://terrascape.miraheze.org/w/index.php?title=Geb&oldid=463) | Deck card confirmed; exact behavior pending |
| TS-E-C-012 | Geb | Stable | [rev 463](https://terrascape.miraheze.org/w/index.php?title=Geb&oldid=463) | Deck card confirmed; exact behavior pending |
| TS-E-C-013 | Isis | Scribe | [rev 467](https://terrascape.miraheze.org/w/index.php?title=Isis&oldid=467) | Deck card confirmed; exact behavior pending |
| TS-E-C-014 | Isis | Per Ankh | [rev 467](https://terrascape.miraheze.org/w/index.php?title=Isis&oldid=467) | Deck card confirmed; exact behavior pending |
| TS-E-C-015 | Isis | Granary | [rev 467](https://terrascape.miraheze.org/w/index.php?title=Isis&oldid=467) | Deck card confirmed; link target is `Granary (Ancient Egypt)`, retain this variant separately from base-game Granary pending identity check |
| TS-E-C-016 | Isis | Seed House | [rev 467](https://terrascape.miraheze.org/w/index.php?title=Isis&oldid=467) | Deck card confirmed; exact behavior pending |
| TS-E-C-017 | Osiris | Fishing Boat | [rev 464](https://terrascape.miraheze.org/w/index.php?title=Osiris&oldid=464) | Deck card confirmed; determine whether it is a buildable structure or special card |
| TS-E-C-018 | Osiris | Alluvial Field | [rev 464](https://terrascape.miraheze.org/w/index.php?title=Osiris&oldid=464) | Deck card confirmed; exact behavior pending |
| TS-E-C-019 | Osiris | Clay Hut | [rev 464](https://terrascape.miraheze.org/w/index.php?title=Osiris&oldid=464) | Deck card confirmed; exact behavior pending |
| TS-E-C-020 | Osiris | Nile Workshop | [rev 464](https://terrascape.miraheze.org/w/index.php?title=Osiris&oldid=464) | Deck card confirmed; exact behavior pending |
| TS-E-C-021 | Ptah | Stone Mason | [rev 466](https://terrascape.miraheze.org/w/index.php?title=Ptah&oldid=466) | Deck card confirmed; exact behavior pending |
| TS-E-C-022 | Ptah | Woodshop | [rev 466](https://terrascape.miraheze.org/w/index.php?title=Ptah&oldid=466) | Deck card confirmed; exact behavior pending |
| TS-E-C-023 | Ptah | Overseer | [rev 466](https://terrascape.miraheze.org/w/index.php?title=Ptah&oldid=466) | Deck card confirmed; exact role pending |
| TS-E-C-024 | Ptah | Architect | [rev 466](https://terrascape.miraheze.org/w/index.php?title=Ptah&oldid=466) | Deck card confirmed; exact role pending |

### Ancient Egypt patch-only building/card-name leads

These names are mentioned in official post-release patch notes. Crosswalk known matches to the community deck index, but do not infer exact buildable/merge role beyond each cited source.

| ID | Official name | Evidence | Evidence-based classification | Deck-card crosswalk | Disposition |
|---|---|---|---|---|---|
| TS-E-B-001 | Nile Workshop | [Patch 2.0.0.2](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964) | Named item in alluvial-field foliage fix | TS-E-C-020 | Deck card independently listed; exact building behavior pending |
| TS-E-B-002 | Clay Hut | [Patch 2.0.0.2](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964) | Named item in alluvial-field foliage fix | TS-E-C-019 | Deck card independently listed; exact building behavior pending |
| TS-E-B-003 | Scout | [Patch 2.0.0.2](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964) | Named item in alluvial-field foliage fix | TS-E-C-003 | Deck card independently listed; whether it represents a building remains unresolved |
| TS-E-B-004 | Sandstone Quarry | [Patch 2.0.0.2](https://steamcommunity.com/games/2290000/announcements/detail/1826992588592964) | Named building with ground-biome behavior | — | Candidate / no match in the six indexed Egypt decks; card or merge-result identity unresolved |
| TS-E-B-005 | Bazaar | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543) | Named buildable item with Nile-side placement behavior | TS-E-C-007 | Deck card independently listed; exact behavior pending |
| TS-E-B-006 | Farmhand Camp | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543) | Named buildable item with Nile-side placement behavior | TS-E-C-010 | Deck card independently listed; exact behavior pending |
| TS-E-B-007 | Shrine | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543) | Named in Gods Plaza layout; replaced by Plaza in that layout | TS-E-C-008 | Deck card independently listed; layout/merge role pending |
| TS-E-B-008 | Plaza | [RISE Patch 2.1.0.1](https://steamcommunity.com/games/2290000/announcements/detail/1839676055885543) | Named as replacement for Shrine in Gods Plaza layout | — | Candidate / layout component; not listed in the six indexed Egypt decks |
| TS-E-B-009 | Treasurer | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Explicitly named as a Building objective | — | Candidate / scenario-only building lead; deck/card and behavior unresolved |
| TS-E-B-010 | Template | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Explicitly named as a Building objective immediately after objective 6 unlocks Ra in `The Scales of Fate` | — | Candidate / objective sequence verifies in-scenario availability only; Ra-card membership and behavior unresolved |
| TS-E-B-011 | Embalmer | [Egypt Scenarios Guide, posted 2026-05-08](https://steamcommunity.com/sharedfiles/filedetails/?id=3718691158) | Explicitly named as a Building objective at objective 10 after Ra is unlocked | — | Candidate / objective sequence verifies in-scenario availability only; Ra-card membership and behavior unresolved |


## Coverage disposition

- Card entries: 62 source-name candidates (54 current Wiki entries plus cross-snapshot labels, five extra-card candidates, and official-only `Weaver`) remain unreconciled. The 1.1.1.2 poster identifies 52 cards in thirteen decks plus six extras; TIDE 1.2 later adds Temple and states that some buildings were replaced while old versions became deckless, but it does not identify all Community/Trade replacement mappings. The official 1.0 launch statement says 13 new buildings, but its release changelog names 12; resolve the missing entry and roster aliases before claiming coverage.
- Medieval merge results: official sources report 21 at 1.0, five additions in DAWN 1.1, and five additions plus two variants in TIDE 1.2. The 1.0.0.4 poster enumerates 20 release-era results; the official 1.0 changelog separately names `Greater Mill`, a plausible missing 21st. The later Steam guide enumerates 30 results; its omission of `Greater Mill` leaves a likely one-name gap in the 31-name 20+1+5+5 sequence, but the relationship between `Greater Mill` and `Ox Mill` remains unverified. Review the two TIDE variants and verify any post-TIDE changes.
- Ancient Egypt card references: the pinned Miraheze revisions list 24 cards across six indexed decks (four per deck). The Steam scenario checklist independently confirms the Ra deck is used in-game and names `Treasurer`, `Template`, and `Embalmer`; a Scales of Fate gameplay video confirms the in-game objective label `Temple (Ra)` and corroborates Treasurer. Treat the `Template`/`Temple (Ra)` discrepancy as unresolved. The sources still do not provide the four-card Ra list. Eight additional names from official post-release patches are row-captured, six crosswalked to these deck cards; the scenario/video-only leads are kept separate. Full deck/card/building coverage remains open.
- Ancient Egypt merges: RISE 2.1.0.0 names five merged-building candidates and three monuments. Other official notes and the scenario guide identify eight additional merge/result leads (Limestone Quarry, Gods Plaza, Clay Pit, Dromos, Indigo Farm, Greater Noria, Gold Mine, Basalt Quarry); recipes and their relation to the full DLC merge roster remain unresolved. Three earlier monument leads (Pyramid, Bent Pyramid, Sphinx) supplement the three RISE monuments. The initial DLC card/building catalog, other merge results, and recipes remain missing.
- The manifest/audit complete tasks 1.2–1.3 for observed public rows, not the exhaustive 2.2.0.5 + Ancient Egypt roster. The runtime catalog admits only confirmed identities with campaign-authored behavior; Ra membership and unobserved card/merge coverage remain unknown and are never runtime entries.

### Publicly visible medieval merge inputs (candidate, guide version unpinned)

Source: [Steam guide 3292704537](https://steamcommunity.com/sharedfiles/filedetails/?id=3292704537), fetched 2026-10-06. The displayed English recipe wording is retained as component labels; this table does not validate 2.2.0.5 availability or silently normalize labels to current cards.

| ID | Result | Guide inputs | Confidence |
|---|---|---|---|
| TS-M-001 | Fruit Farm | 3 × gatherer huts | candidate; guide version unpinned |
| TS-M-002 | Farmstead | 3 × wheat fields, 1 × hut | candidate; guide version unpinned |
| TS-M-003 | Vineyard | 3 × gatherer huts, 1 × brewery | candidate; guide version unpinned |
| TS-M-004 | Ox Mill | 1 × wheat field, 1 × cattle pasture, 1 × mill | candidate; guide version unpinned |
| TS-M-005 | Manor Farm | 2 × houses, 4 × wheat fields, 1 × well | candidate; guide version unpinned |
| TS-M-006 | Smock Mill | 1 × wheat field, 1 × mill, 1 × bakery | candidate; guide version unpinned |
| TS-M-007 | Shieling | 3 × sheep pastures | candidate; guide version unpinned |
| TS-M-008 | Forest Settlement | 3 × huts, 1 × lumberjack house, 2 × foresters, 1 × well | candidate; guide version unpinned |
| TS-M-009 | Royal Forest | 4 × foresters | candidate; guide version unpinned |
| TS-M-010 | Fishing Outpost | 1 × fishing boat, 1 × clam farm, 1 × fish trap | candidate; guide version unpinned |
| TS-M-011 | Fish Farm | 1 × fishing boat, 2 × fish traps, 1 × fisherman's house | candidate; guide version unpinned |
| TS-M-012 | Mining Enclave | 2 × huts, 2 × quarries, 1 × mason's house | candidate; guide version unpinned |
| TS-M-013 | Iron Mining Camp | 2 × iron mines, 1 × smelter, 1 × mountain | candidate; guide version unpinned |
| TS-M-014 | Liquor Distillery | 1 × herbalist, 2 × breweries, 1 × gathering hut | candidate; guide version unpinned |
| TS-M-015 | Construction Yard | 2 × lumberjack houses, 1 × sawmill, 1 × forge | candidate; guide version unpinned |
| TS-M-016 | Longhouse | 4 × huts | candidate; guide version unpinned |
| TS-M-017 | City District | 4 × houses | candidate; guide version unpinned |
| TS-M-018 | Trade District | 2 × houses, 1 × market, 1 × storage, 1 × carrier | candidate; guide version unpinned |
| TS-M-019 | Cathedral | 1 × treasury, 2 × parks, 2 × chapels | candidate; guide version unpinned |
| TS-M-020 | Citadel of Wisdom | 3 × parks, 1 × school, 1 × tavern, 1 × library | candidate; guide version unpinned |
| TS-M-021 | Sanctuary | 1 × well, 1 × hut, 1 × megalith | candidate; guide version unpinned |
| TS-M-022 | Herb Garden | 3 × herbalists | candidate; guide version unpinned |
| TS-M-023 | Pond Farm | 1 × Pond, 1 × herbalist, 1 × reed gatherer, 1 × weaver | candidate; guide version unpinned |
| TS-M-024 | Ropery | 1 × tailor, 2 × linen field, 1 × weaver | candidate; guide version unpinned |
| TS-M-025 | Henge | 1 × temple, 6 × megaliths | candidate; guide version unpinned |
| TS-M-026 | City Park | 3 × parks | candidate; guide version unpinned |
| TS-M-032 | Hospital | 1 × surgeon, 1 × bathhouse, 1 × chapel | candidate; guide version unpinned |
| TS-M-033 | University | 2 × schools, 1 × library, 1 × alchemist | candidate; guide version unpinned |
| TS-M-034 | Harbor (guide label: Port) | 3 × traders, 1 × carrier, 1 × lighthouse, 1 × warehouse | candidate; guide version unpinned |
| TS-M-035 | Timber Mill (guide label: Lumber-mill) | 1 × sawmill, 1 × carpenter, 2 × rivers | candidate; guide version unpinned |
