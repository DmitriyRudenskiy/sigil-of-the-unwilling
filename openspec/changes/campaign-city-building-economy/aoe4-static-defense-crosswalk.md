# AoE IV static-defense crosswalk (pinned data audit)

**Data snapshot:** `AOE4-DATA@b2cd38222deae40ba2db18171edf494f81410c69` (2026-05-04), parsed from game files. The source's [`buildings/all.json`](https://github.com/aoe4world/data/blob/b2cd38222deae40ba2db18171edf494f81410c69/buildings/all.json) contains 665 per-civilization records. The scope-limited Explorer candidates, civ variants, and post-pin coverage caveat are in [`aoe4-military-defense-candidates.md`](aoe4-military-defense-candidates.md) and [`aoe4-data-variant-crosscheck.md`](aoe4-data-variant-crosscheck.md).

This crosswalk maps source function only; it does **not** import source HP, damage, weapon count, age, landmark/wonder victory rules, garrison mechanics, or production rates. The campaign target is the existing deterministic city/pressure-raid defense input: a confirmed static defensive structure is tagged `static_defense`; only a campaign catalog entry with that role and a state-specific campaign value contributes via `CampaignDefenseResolver`. No campaign numeric values are inferred from AoE IV.

Disposition terms:
- **static_defense** — standalone wall, tower, outpost, keep/castle, or defensive landmark; eligible to contribute to the existing city defense input when adapted as a campaign building.
- **defense_support** — defensive access, terrain/control, or garrison-dependent effect; does not directly add static defense strength in the current campaign model.
- **not_defense** — source entry is economic infrastructure, unit support, or other non-static-defense function.

| Candidate | Source function / variant finding | Campaign disposition |
|---|---|---|
| AOE-C-015 Palisade | 21 civ-specific wall records; source class `defensive_structure`, wall segment. | `static_defense`; wall role only. |
| AOE-C-016 Palisade Gate | 21 civ-specific gate records; defensive wall gate. | `static_defense`; gate-segment role, no standalone attack implied. |
| AOE-C-017 Aqueduct | Byzantines record is water infrastructure linking Cisterns; Explorer's defensive label is not its function. | `not_defense`; exclude from defense input. |
| AOE-C-018 Fortified Palisade Gate | Rus defensive wall gate. | `static_defense`. |
| AOE-C-019 Fortified Palisade Wall | Rus defensive wall segment. | `static_defense`. |
| AOE-C-020 Stone Wall | 21 civ-specific defensive wall segments. | `static_defense`. |
| AOE-C-021 Stone Wall Gate | 21 civ-specific gates; must be placed on a Stone Wall segment. | `static_defense`; gate-segment role. |
| AOE-C-022 Outpost | 20 civ-specific outpost records; source describes a defensible position with upgrade/garrison behavior. | `static_defense`; use a role mapping, not AoE weapon/upgrade values. |
| AOE-C-023 Fortified Outpost | Golden Horde defensive outpost. | `static_defense`. |
| AOE-C-024 Toll Outpost | Malians outpost with trade-related extras and defensive weapons. | `static_defense`; only the defensive-structure role maps; trade effects are excluded. |
| AOE-C-025 Wooden Fortress | Rus defensive stronghold/outpost. | `static_defense`. |
| AOE-C-026 Stone Wall Tower | 21 civ-specific tower records; source describes a defensive wall emplacement. | `static_defense`. |
| AOE-C-027 Tughlaqabad Fort | Delhi Sultanate keep/fort; source describes defensive position and garrison attacks. | `static_defense`; no imported unit or attack values. |
| AOE-C-028 Keep | 17 civ-specific records, including the Jin Meng'an Mouke keep. | `static_defense`; civ-specific source variants remain separate until catalog behavior is compared. |
| AOE-C-029 Castle | Japanese and Sengoku variants; both are defensive structures. | `static_defense`; retain variant identities. |
| AOE-C-035 Lancaster Castle | Holy Roman landmark; source description explicitly calls it defensive, and pinned record has an arrow emplacement. It also performs a one-time unit muster. | `static_defense`; map fortification only; muster contents are excluded from training choices pending approved character mapping. |
| AOE-C-038 Golden Horn Tower | Two distinct variants: Byzantines (`by`) periodically produce mercenaries and have no defensive-structure role; Malians (`mac`) are explicitly a defensive Crossbow-emplacement building. | Split: `mac` → `static_defense`; `by` → `not_defense` for this crosswalk. Training action is resolved in the class crosswalk. Do not merge variants. | |
| AOE-C-054 Great Wall Bastion | Jin landmark; pinned data says it acts as a Keep and lists defensive emplacements. | `static_defense`; its technology, spawn, and damage effects are not imported. |
| AOE-C-056 Barbican of the Sun | Chinese defensive landmark; static emplacements, including garrison-dependent additions. | `static_defense`; no weapon numbers or garrison bonuses imported. |
| AOE-C-057 Saharan Trade Network | Malians landmark explicitly acts as a Toll Outpost. | `static_defense`; trade/bonus effects are excluded. |
| AOE-C-058 Kremlin | Rus landmark explicitly acts as a Wooden Fortress. | `static_defense`. |
| AOE-C-059 Compound of the Defender | Delhi/Tughlaq defensive landmark: enables/discounts fortification construction; no standalone weapon profile. | `defense_support`; no direct strength contribution. |
| AOE-C-060 The White Tower | English/Holy Roman variants explicitly act as Keeps; the English variant also produces units. | `static_defense` for the defensive building behavior; its unit-production role is resolved in the class crosswalk. | |
| AOE-C-061 Berkshire Palace | English/Holy Roman Keep variants with defensive emplacements. | `static_defense`; no source weapon values imported. |
| AOE-C-062 Red Palace | French/Jeanne d'Arc defensive Keep variants. | `static_defense`; Jeanne-specific unit production is a separate class-crosswalk disposition. | |
| AOE-C-063 Elzbach Palace | Holy Roman/Ottoman variants explicitly act as Keeps; source also describes nearby-building protection. | `static_defense`; source aura values are excluded. |
| AOE-C-064 Castle of the Crow | Japanese/Sengoku Castle variants; source adds variant-specific effects. | `static_defense`; treasure, caravan, and other source effects are excluded. |
| AOE-C-065 Great Wall Gatehouse | Chinese gatehouse built over Stone Walls with an emplacement. | `static_defense`; wall/gate role only. |
| AOE-C-066 Fort of the Huntress | Malians landmark explicitly acts as a Keep and shoots poison arrows. | `static_defense`; poison/stealth effects are excluded. |
| AOE-C-067 Sea Gate Castle | Order of the Dragon Keep variant. | `static_defense`. |
| AOE-C-068 Spasskaya Tower | Rus Keep variant with static emplacements. | `static_defense`. |
| AOE-C-069 Fortress | Knights Templar defensive landmark/fortification. | `static_defense`; pilgrim, aura, and landmark effects are excluded. |
| AOE-C-073 Capital Town Center | 23 per-civ records; attack description is explicitly garrison-dependent. The single weapon-bearing data variant is still described as adding attacks while garrisoned. | `defense_support`; exclude from standalone `static_defense`. |
| AOE-C-078 House | Two source variants have garrison weapon profiles only. | `defense_support`; not a standalone defensive building. |
| AOE-C-081 Manor | HRE source variant has a garrison weapon profile only. | `defense_support`; not a standalone defensive building. |
| AOE-C-092 Town Center | 23 per-civ records; source says attacks are added while garrisoned. | `defense_support`; exclude from standalone `static_defense`. |
| AOE-C-093 Village | Zhu Xi source variant has a garrison-dependent weapon profile. | `defense_support`; not a standalone defensive building. |
| AOE-C-077 Harbor | Knights Templar naval dock has ship-only weapon/production roles. | Explicit naval exclusion; no campaign defense or training action. |
| AOE-C-094 Pagoda Forest | Jin landmark has `defensive_structure` class, but its source function is wood-producing Pagoda Forests with area slow and Monk support; not a standalone fortification. | `defense_support` for area-control only; no direct raid strength mapping. |
| AOE-C-095 Temple of the Sun | Zhu Xi landmark carries `defensive_structure` class but provides active unit buffs and has no static weapon profile. | `not_defense`; exclude from static-defense strength. |

## Audit boundary

The pinned class/display screen found **35 distinct names**. A separate nonempty-weapon audit found 29 display names / 72 civ-specific records; it identified Lancaster Castle as one additional standalone defensive landmark outside the class/display set. Therefore the defense crosswalk accounts for 36 class-or-function candidates plus three garrison-only support false positives (House, Manor, Village); Harbor is naval and excluded. All 29 weapon-profile names have a disposition above. The class query alone is not treated as a completeness boundary.

This completes the defense-function mapping for the audited 2026-10-04 released-content boundary. The live data/news recheck found no released post-pin building identity; the source's general DLC warning remains a caveat. The shipped catalog includes confirmed static-defense and training records only, with campaign-authored values; AtS/TerraScape source completeness remains explicitly partial in their manifests.
