# AoE IV candidate civ-variant cross-check

**Data source ID:** `AOE4-DATA@b2cd38222deae40ba2db18171edf494f81410c69`, commit dated 2026-05-04, message “Added Jin Dynasty and Season 13 patch 16.1.9737 data.” The [AoE4 World Data README](https://github.com/aoe4world/data/blob/b2cd38222deae40ba2db18171edf494f81410c69/README.md) says its data is parsed from game files and reflects in-game tooltips. Candidate matching used [`buildings/all.json`](https://github.com/aoe4world/data/blob/b2cd38222deae40ba2db18171edf494f81410c69/buildings/all.json); civ-code/expansion mapping is in [`civilizations/civs-index.json`](https://github.com/aoe4world/data/blob/b2cd38222deae40ba2db18171edf494f81410c69/civilizations/civs-index.json). Production screening additionally joins [`units/all.json`](https://github.com/aoe4world/data/blob/b2cd38222deae40ba2db18171edf494f81410c69/units/all.json) producer IDs and unit classes.

The pinned dataset has **665 per-civ building records**, **165 distinct display names**, and **23 civ IDs**. All 69 Explorer candidates in [`aoe4-military-defense-candidates.md`](aoe4-military-defense-candidates.md) match a data display name after case/punctuation normalization (**69/69; no unmatched candidate**). Per-row role/disposition text in this discovery cross-check is historical; final training and defense decisions are in [`aoe4-training-class-crosswalk.md`](aoe4-training-class-crosswalk.md) and [`aoe4-static-defense-crosswalk.md`](aoe4-static-defense-crosswalk.md). The 2026-10-05 source audit confirms all 95 candidate names occur in the latest 665-record data snapshot and all candidate signals have dispositions. Source-roster caveats are reported in the public manifests; task completion covers observed rows and explicit unknown gaps only.

The reviewed post-pin official news entries are patch 16.1.10056 (2026-05-12), 16.2.10604 (2026-06-01), and 16.2.10884 (2026-06-18); the live Steam news feed recheck on 2026-10-05 found no subsequent released building-content update. The patches may change existing building balance; they do not add building identities to the manifest. The dataset's current live `buildings/all.json` has the same SHA-256 as the pin, so use the pin only for source roles/identity—not final balance. Civ abbreviations resolve through the pinned `civs-index.json` link above.

| Candidate ID | Explorer name | Data variant records | Civ IDs | Game-data display class | Disposition |
|---|---|---:|---|---|---|
| AOE-C-001 | Barracks | 22 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,jin,kt,ma,mo,od,ot,ru,sen,tug,zx | Military Building | Name match; role/action review pending |
| AOE-C-002 | Stable | 22 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,kt,ma,mac,mo,od,ot,ru,sen,tug,zx | Military Building | Name match; role/action review pending |
| AOE-C-003 | Varangian Stronghold | 1 | mac | Military Building | Name match; role/action review pending |
| AOE-C-004 | Varangian Warcamp | 1 | mac | Military Building | Name match; role/action review pending |
| AOE-C-005 | Military School | 1 | ot | Military Building | Name match; role/action review pending |
| AOE-C-006 | Archery Range | 22 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,kt,ma,mac,mo,od,ot,ru,sen,tug,zx | Military Building | Name match; role/action review pending |
| AOE-C-007 | Mercenary House | 1 | by | Military Building | Name match; role/action review pending |
| AOE-C-008 | Grassland | 1 | jin | Military Building | Name match; verify whether output is an eligible human class |
| AOE-C-009 | Machine Workshop | 1 | jin | Military Building | Name match; separate human-unit and siege outputs |
| AOE-C-010 | War Stable | 1 | jin | Military Building | Name match; role/action review pending |
| AOE-C-011 | Hojo Clan Daimyo Estate | 1 | sen | Military Building | Name match; role/action review pending |
| AOE-C-012 | Oda Clan Daimyo Estate | 1 | sen | Military Building | Name match; role/action review pending |
| AOE-C-013 | Takeda Clan Daimyo Estate | 1 | sen | Military Building | Name match; role/action review pending |
| AOE-C-014 | Siege Workshop | 22 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,kt,ma,mac,mo,od,ot,ru,sen,tug,zx | Military Building | Name match; siege-only outputs need separate disposition |
| AOE-C-015 | Palisade | 21 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,jin,kt,ma,mac,od,ot,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-016 | Palisade Gate | 21 | ab,ay,by,ch,de,en,fr,gol,hl,hr,ja,je,jin,kt,ma,mac,od,ot,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-017 | Aqueduct | 1 | by | Defensive Building | Name match; verify defensive function vs infrastructure |
| AOE-C-018 | Fortified Palisade Gate | 1 | ru | Defensive Building | Name match; defensive-role review pending |
| AOE-C-019 | Fortified Palisade Wall | 1 | ru | Defensive Building | Name match; defensive-role review pending |
| AOE-C-020 | Stone Wall | 21 | ab,ay,by,ch,de,en,fr,hl,hr,ja,je,jin,kt,ma,mac,od,ot,ru,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-021 | Stone Wall Gate | 21 | ab,ay,by,ch,de,en,fr,hl,hr,ja,je,jin,kt,ma,mac,od,ot,ru,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-022 | Outpost | 20 | ab,ay,by,ch,de,en,fr,hl,hr,ja,je,jin,kt,mac,mo,od,ot,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-023 | Fortified Outpost | 1 | gol | Defensive Building | Name match; defensive-role review pending |
| AOE-C-024 | Toll Outpost | 1 | ma | Defensive Building | Name match; defensive-role review pending |
| AOE-C-025 | Wooden Fortress | 1 | ru | Defensive Building | Name match; defensive-role review pending |
| AOE-C-026 | Stone Wall Tower | 21 | ab,ay,by,ch,de,en,fr,hl,hr,ja,je,jin,kt,ma,mac,od,ot,ru,sen,tug,zx | Defensive Building | Name match; defensive-role review pending |
| AOE-C-027 | Tughlaqabad Fort | 1 | tug | Defensive Building | Name match; defensive-role review pending |
| AOE-C-028 | Keep | 17 | ab,ay,by,ch,de,en,fr,hl,hr,je,jin,ma,mac,od,ot,ru,zx | Defensive Building | Name match; `jin` variant cross-checks against official Meng'an Mouke keep reference; confirm exact defensive data before disposition |
| AOE-C-029 | Castle | 2 | ja,sen | Defensive Building | Name match; defensive-role review pending |
| AOE-C-030 | Imperial Hippodrome | 2 | by,mac | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-031 | Tower of Victory | 2 | de,tug | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-032 | School of Cavalry | 2 | fr,je | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-033 | Koka Township | 2 | ja,sen | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-034 | Council Hall | 1 | en | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-035 | Lancaster Castle | 1 | hl | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-036 | Great Pasture | 1 | jin | Age II - Military Landmark | Name match; verify output role and human eligibility |
| AOE-C-037 | Jiangnan Tower | 1 | zx | Age II - Military Landmark | Name match; landmark action review pending |
| AOE-C-038 | Golden Horn Tower | 2 | by,mac | Age III - Military Landmark | Name match; landmark action review pending |
| AOE-C-039 | Burgrave Palace | 2 | hr,od | Age III - Military Landmark | Name match; landmark action review pending |
| AOE-C-040 | Astronomical Clocktower | 1 | ch | Age III - Military Landmark | Name match; separate siege production from human production |
| AOE-C-041 | Farimba Garrison | 1 | ma | Age III - Military Landmark | Name match; landmark action review pending |
| AOE-C-042 | Kurultai | 1 | mo | Age III - Military Landmark | Name match; verify whether support-only or production |
| AOE-C-043 | Istanbul Imperial Palace | 1 | ot | Age III - Military Landmark | Name match; landmark action review pending |
| AOE-C-044 | Mehmed Imperial Armory | 1 | ot | Age III - Military Landmark | Name match; siege-support role needs separate disposition |
| AOE-C-045 | Foreign Engineering Company | 2 | by,mac | Age IV - Military Landmark | Name match; siege-production role needs separate disposition |
| AOE-C-046 | Palatine School | 2 | by,mac | Age IV - Military Landmark | Name match; landmark action review pending |
| AOE-C-047 | Palace of the Sultan | 2 | de,tug | Age IV - Landmark; Age IV - Military Landmark | Name match; landmark action review pending |
| AOE-C-048 | Wynguard Palace | 2 | en,hl | Age IV - Military Landmark | Name match; separate human and siege retinue outputs |
| AOE-C-049 | College of Artillery | 2 | fr,je | Age IV - Military Landmark | Name match; siege-only outputs need separate disposition |
| AOE-C-050 | Tanegashima Gunsmith | 1 | ja | Age IV - Military Landmark | Name match; landmark action review pending |
| AOE-C-051 | Khaganate Palace | 1 | mo | Age IV - Military Landmark | Name match; separate human and siege outputs |
| AOE-C-052 | Sword Hunt Statue | 1 | sen | Age IV - Military Landmark | Name match; official 16.1.10056 changes its attack speed; role as static defense vs military support still requires disposition |
| AOE-C-053 | Spirit Way | 1 | ch | Age IV - Military & Technology Landmark | Name match; verify production vs technology role |
| AOE-C-054 | Great Wall Bastion | 1 | jin | Age IV - Military & Technology Landmark | Name match; official 16.1.10056 mentions its Bed Crossbow weapon; distinguish defense from production/technology role |
| AOE-C-055 | Zhu Xi's Library | 1 | zx | Age IV - Military & Technology Landmark | Name match; verify production vs technology role |
| AOE-C-056 | Barbican of the Sun | 1 | ch | Age II - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-057 | Saharan Trade Network | 1 | ma | Age II - Defensive Landmark | Name match; verify defensive function vs trade role |
| AOE-C-058 | Kremlin | 1 | ru | Age II - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-059 | Compound of the Defender | 2 | de,tug | Age III - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-060 | The White Tower | 2 | en,hl | Age III - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-061 | Berkshire Palace | 2 | en,hl | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-062 | Red Palace | 2 | fr,je | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-063 | Elzbach Palace | 2 | hr,od | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-064 | Castle of the Crow | 2 | ja,sen | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-065 | Great Wall Gatehouse | 1 | ch | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-066 | Fort of the Huntress | 1 | ma | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-067 | Sea Gate Castle | 1 | ot | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-068 | Spasskaya Tower | 1 | ru | Age IV - Defensive Landmark | Name match; defensive-role review pending |
| AOE-C-069 | Fortress | 1 | kt | Defensive Landmark | Name match; verify function within Knights Templar variant |

## Full-dataset discovery screen beyond Explorer role tags

A second discovery pass screened all 665 per-civ building records rather than only the 69 Explorer role-tagged names. It joined unit `producedBy` IDs to building `id`/`baseId`, required matching civ IDs, and selected unit records carrying both `human` and `land_military`; independently, it recorded every nonempty building weapon profile. The producer join yields 49 distinct building display names across 186 matching per-civ building records; the weapon-profile screen yields 29 names across 72 per-civ records. Their union has 71 names. Compared with the 69 Explorer candidates, **24 names were absent** (one, Harbor, is already an explicit naval exclusion), enumerated as AOE-C-070–093 in [`aoe4-military-defense-candidates.md`](aoe4-military-defense-candidates.md).

These are discovery signals, not final inclusion rules. Human land-military producer links include Scouts, religious units, and unique/special units that may not map to approved campaign character classes. Weapon profiles include garrison-only arrows on Houses/Manors/Villages and naval-only Harbor weapons. Those records must receive explicit support/exclusion dispositions; do not infer standalone defense from a nonempty weapon array. The screen does not prove current post-pin roster completeness, because the data commit remains 2026-05-04 and later content parity has not been independently established. Static-defense role decisions from a separate all-record class screen are in [`aoe4-static-defense-crosswalk.md`](aoe4-static-defense-crosswalk.md); they supersede any older pending defense wording for the overlapping rows, but do not resolve the remaining training/candidate audit.

## Defensive-class discoveries added after the producer/weapon screen

A direct all-665-record filter for `defensive_structure` or a display class containing `Defensive` found 35 display names. Two were absent from the earlier Explorer role and producer/weapon lists; they are AOE-C-094–095 in the candidate ledger and are classified in the static-defense crosswalk.

| Candidate ID | Data name | Records / civ | Display class | Relevant data role | Disposition |
|---|---|---|---|---|---|
| AOE-C-094 | Pagoda Forest | 1 / jin | Age IV - Economic Landmark | `defensive_structure`; periodically spawns slow-area wood-producing structures | Area-control support only; no standalone static-defense input |
| AOE-C-095 | Temple of the Sun | 1 / zx | Age IV - Active Landmark | `defensive_structure`; grants activated unit combat buffs | Not static defense; excluded from raid-strength role |

These two names raise the discovery ledger to 95 rows. This is a pinned-dataset cross-check only and does not establish completeness of post-pin/DLC game content.

## Function-screen evidence from the pinned game data (not final disposition)

For each candidate, the screen joined its per-civ building `id`/`baseId` against unit `producedBy` entries and required civ-ID overlap. “Human land production” means the unit has both `human` and `land_military` classes; `land_military` without `human` is reported separately because it includes siege engines. “Weapon-bearing” means at least one matching building record has a nonempty weapon profile; absence of a weapon profile does not prove absence of defense (for example, upgradeable structures may gain weaponry later).

| Explorer group | Candidate rows | With human land-unit production | With any land-military output (incl. siege) | With weapon profile |
|---|---:|---:|---:|---:|
| Military Building | 14 | 13 | 13 | 1 |
| Defensive Building | 15 | 2 | 2 | 8 |
| Military / military-technology landmark | 26 | 12 | 16 | 3 |
| Defensive landmark | 14 | 2 | 2 | 12 |
| **Total** | **69** | **29** | **33** | **24** |

- `Grassland` (AOE-C-008) has no `producedBy` human land-unit link in this data; it spawns horses. Its non-character support effect is explicitly excluded from class training in [`aoe4-training-class-crosswalk.md`](aoe4-training-class-crosswalk.md).
- Four landmarks link to siege outputs but no eligible human-class output: Astronomical Clocktower, Mehmed Imperial Armory, Foreign Engineering Company, and College of Artillery. All four are explicitly excluded from campaign class training.
- Siege Workshop has both a human-class output (mapped to `fighter`) and siege outputs. Only the approved class role is mapped; siege templates remain excluded.
- The pinned producer rows now have per-civ campaign role mappings in [`aoe4-training-class-crosswalk.md`](aoe4-training-class-crosswalk.md); static defense, false-positive labels, garrison-only profiles, and Lancaster Castle are in [`aoe4-static-defense-crosswalk.md`](aoe4-static-defense-crosswalk.md). No source troop roster or stats are imported.

- Official [Yue Fei's Legacy release notes](https://steamcommunity.com/games/1466860/announcements/detail/1832065502812877) name Jin-specific units (Iron Pagoda, Mounted Grenadiers, Eruptors, Bed Crossbows, Mounted Villagers, Emissaries) and describe Meng'an Mouke keeps as part of the civ's automated defense. These unit names are not building candidates and do not authorize a generic AoE roster; the `Keep` row's Jin data variant is a lead for validating the defensive-building crosswalk.

## Coverage note

The AoE IV source crosswalk is fully dispositioned for the declared snapshot. Tasks 1.2–1.3 cover observed public rows and explicit unknown gaps; AtS/TerraScape manifest coverage is partial, while the runtime catalog includes only confirmed/admitted roles and documented exclusions.
