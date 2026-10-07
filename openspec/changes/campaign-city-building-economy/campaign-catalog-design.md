# Campaign building catalog design (task 3.2)

## Admission and authority

The shipped runtime asset is [`game/assets/data/campaign_building_catalog.json`](../../../game/assets/data/campaign_building_catalog.json). It contains 98 definitions: five campaign-owned MVP baseline buildings and 93 source-backed adaptations covering 92 unique confirmed external rows (the Malian/Byzantine Golden Horn Tower split is two runtime variants). Another 25 confirmed external rows are carried only as reasoned exclusions. [`audit_campaign_catalog.py`](audit_campaign_catalog.py) verifies that every confirmed row in the public manifests is admitted or excluded exactly once and that no `candidate`/`unknown` row, null value, or out-of-mask resource is in the runtime asset.

The reference manifests establish identity and public-source provenance only. All costs, yields, upkeep, construction duration, service capacities, training costs, defense strength, and campaign merge recipes below are original campaign design values. No Against the Storm, TerraScape, or AoE IV price, score, timer, or balance number is imported. TerraScape guide recipes marked candidate/unknown are not copied; campaign merge inputs use only this catalog's canonical IDs.

Canonical constraints are the K-M3 five-building starting core and 52-cell city, K-R2's MVP transaction mask `{food, wood, iron}`, first-tier campaign classes/groups in `mvp_catalog.json`, a party cap of five, and the existing deterministic city raid/economy systems. Construction duration is data-ready for the separate construction-queue change; UI/playtest behavior is not claimed as headless-tested.

## Campaign-owned MVP baseline

| Definition | Build cost | Jobs and effect | Design reason |
|---|---:|---|---|
| `campaign_farm` | 4 wood | 2 jobs; 2 food per turn at full staffing | Matches the canonical MVP farm output. |
| `campaign_sawmill` | 5 wood | 2 jobs; 2 wood per turn; adjacent food-production buildings gain +15% output | Uses the documented farm/forest synergy; the bonus is applied by the economy phase with fixed-point remainders. |
| `campaign_iron_mine` | 6 wood | 2 jobs; 1 iron per turn | Matches the canonical MVP mine output. |
| `campaign_housing` | 6 wood | Capacity 10 | Matches the canonical MVP housing block. |
| `campaign_barracks` | 8 wood + 2 iron | Trains fighter/ranger; 1 active defense; brawling service capacity 3 | Makes the two-person party's training path available, covers the canonical Alchemists & Flame need with an original campaign-authored effect, and resolves defense on the existing integer strength scale. |

Farm, sawmill, and mine require their declared two workers to produce full output; partial staffing scales output deterministically. Baseline buildings have no recurring upkeep. This avoids creating a new fixed daily drain on top of population/party food consumption. All five take one campaign turn to build.

## Training and static defense

All admitted military building entries use only campaign classes supported by the pinned class crosswalk and the `hireable` set. AoE civilization variants are retained in `source_variants`; the Golden Horn Tower's documented variant split is represented by separate Malian defensive and Byzantine training definitions. Other source records share a campaign definition only when the campaign uses the same declared class/defense behavior; source civ IDs remain traceable in the reference manifest.

Campaign-created one-time training costs:

| Class | Cost |
|---|---|
| `fighter` | 20 food + 2 iron |
| `ranger` | 15 food + 15 wood |
| `cleric` | 18 food + 5 wood + 1 iron |
| `rogue` | 15 food + 8 wood |

Only fighter and ranger appear in the campaign baseline barracks; the other actions appear only where an admitted source role mapped to that class. Paladin and wizard remain approved campaign classes but receive no AoE-source training action in this snapshot.

Training structures cost 8 wood + 2 iron; combined training/defense structures cost 10 wood + 3 iron. Static defense costs are tiered by active strength: 1 → 3 wood + 1 iron, 2 → 4 wood + 1 iron, 3 → 6 wood + 2 iron. A two-turn construction has a +1 wood/+1 iron premium. `campaign_barracks` is the explicit day-one exception at 8 wood + 2 iron. One-time unit-training costs below are unchanged by construction-cost tuning.

Static defense is authored on the existing raid-strength scale: walls/gates = 1, outposts/towers/fortresses = 2, keeps/castles/defensive landmarks = 3. Only `active` instances contribute; `inactive` and `ruined` contribute zero. These values are newly selected campaign strengths, not AoE attack or armor values. The two-source Golden Horn Tower variant retains its split so the Byzantine training-only form does not inherit the Malian defensive role.

## TerraScape identity adaptations and campaign merges

Only 18 confirmed result/variant rows are admitted. Trade/caravan structures (`Caravansary`, `Harbor`) and rope/textile production (`Ropery`) are explicitly excluded from this MVP because trade and Layer-2 goods are outside the active campaign scope. All other admitted names receive simple campaign roles using existing food/wood/iron production or registered group services; no new currency or resource is introduced.

Campaign production yields at full declared staffing:

- `Fruit Farm`: 4 food / 4 jobs.
- `Ox Mill`: 2 food + 2 wood / 4 jobs.
- `Shieling`: 3 food / 2 jobs; capacity 10.
- `Pond Farm`: 2 food / 2 jobs; treatment capacity 1.
- `Greater Mill`: 4 food + 4 wood / 8 jobs.
- `Timber Mill`: 4 wood / 4 jobs.
- `Royal Forest Variant`: 3 wood / 2 jobs.

Registered service capacities use the seven campaign need IDs: `campaign_barracks` (brawling 3), `Sanctuary` (religion + mediation), `Herb Garden` (treatment 2), `Henge` (religion), `City Park` (mediation), `Lotus Basin`/`Nun Cistern` (treatment), `Kenbet` (education + market access), `Great Plaza` (mediation 2 + religion), `Hospital` (treatment 2), `University` (education 2), and `CityDistrict Variant` (housing capacity 10 + market access). These are campaign service assignments, not claims about source-game effects. Brawling 3 on the canonical barracks closes the only missing provider for the seven-group runtime need set.

Merge graph uses new campaign-authored inputs, all within the admitted/internal catalog:

- 2 `campaign_farm` → `Fruit Farm`.
- `campaign_farm` + `campaign_sawmill` → `Ox Mill`.
- `campaign_farm` + `campaign_housing` → `Shieling`.
- `campaign_farm` + `Herb Garden` → `Pond Farm`.
- 2 `campaign_sawmill` → `Timber Mill`.
- `Fruit Farm` + `Timber Mill` → `Greater Mill`.
- `Herb Garden` + `Henge` → `Sanctuary`.
- `City Park` + `Henge` → `Great Plaza`.
- `Herb Garden` + `Lotus Basin` → `Hospital`.
- `Kenbet` + `City Park` → `University`.

Each merge is limited to components within one hex and is atomic through `CampaignBuildingMerger`; it transfers workers, stocks, residents, and production remainders under the validated result capacity. No source-guide recipe component is treated as confirmed.

## Explicitly outside runtime

- AtS `Board Game Piece`: confirmed home décor, not a settlement building/service.
- AoE IV naval, siege-only, landmark-progression, bundled-unit, garrison-only defense, and source-aura/support-only rows: explicit exclusions where no campaign MVP training/static-defense behavior is declared.
- TerraScape trade/caravan and Layer-2 rope/textile rows: explicit MVP exclusions.
- All other rows whose target-version identity, deck membership, recipe inputs, or role is `candidate`/`unknown` remain solely in the reference manifests. `Amun-Ra` and `Temple of Luxor` are not present in runtime data.

## Balance verification boundary

The JSON schema/source audit and GdUnit4 catalog validation prove structural validity, provenance admission, deterministic transaction resource IDs, and absence of null/candidate rows. The campaign-city balance tuning is now recorded in [`campaign-city-balance-tuning`](../campaign-city-balance-tuning/selected_plan.json): the deterministic 21-day plan is affordable, covers all seven group needs, fits 17 of 52 cells, and ends at food 1.1, wood 5, iron 8. The earlier pre-tuning report is preserved separately in `campaign-city-balance-tuning/baseline.json`. These headless results do not prove that rates are fun in a human playtest; playtest/UI verification remains deferred.

## Selected 21-day campaign-city plan

The scenario starts with two free `campaign_housing` instances (capacity 20, counted as 2 of 17 cells); no housing cost is charged again. The party is the fixed fighter+ranger pair, starts at the capital with 0 carried food, refills to a capacity of 10, and consumes 2 carried food/day. All 20 residents are available workers, split across the seven canonical groups as 3/3/3/3/3/3/2. A single fixed unrepelled raid is injected on day 7 (strength 6 against defense 1, 30% food pillage); stochastic raid rolls are intentionally omitted.

| Building | Count | Build day(s) | Jobs per building | Cost per building | Campaign contribution |
|---|---:|---|---:|---|---|
| `campaign_farm` | 2 | 1, 6 | 2 | 4 wood | Food production |
| `campaign_barracks` | 1 | 1 | 0 | 8 wood + 2 iron | Fighter/ranger training, defense 1, brawling 3 |
| `campaign_sawmill` | 1 | 2 | 2 | 5 wood | Wood production |
| `campaign_iron_mine` | 1 | 4 | 2 | 6 wood | Iron production |
| `aoe4_palisade` | 1 | 9 | 0 | 6 wood + 2 iron | Defense 3; total city defense 4 |
| `terrascape_herb_garden` | 1 | 10 | 0 | 2 food + 3 wood + 2 iron | Treatment 2 |
| `terrascape_lotus_basin` | 1 | 11 | 0 | 1 food + 2 wood + 1 iron | Treatment 1 |
| `terrascape_kenbet` | 3 | 12, 13, 19 | 0 | 2 food + 3 wood + 2 iron | Education 1 + market access 1 each |
| `terrascape_university` | 1 | 15 | 0 | 2 food + 3 wood + 2 iron | Education 2 |
| `terrascape_sanctuary` | 1 | 16 | 0 | 2 food + 3 wood + 2 iron | Religion 1 + mediation 1 |
| `terrascape_henge` | 1 | 17 | 0 | 1 food + 2 wood + 1 iron | Religion 1 |
| `terrascape_great_plaza` | 1 | 20 | 0 | 3 food + 4 wood + 2 iron | Religion 1 + mediation 2 |

The 15 constructed instances spend 17 food, 59 wood, and 20 iron cumulatively. Eight workers are assigned to the two farms, sawmill, and iron mine. By day 21, active service capacity is brawling 3, education 5, market access 3, religion 3, and treatment 3; all seven groups report 100% coverage. Total footprint including the two starting houses is 17/52 cells. Every construction request succeeds through `CampaignBuildingConstructionService`; the selected plan has no unmet prerequisite or stock shortage.

| Day | Food | Wood | Iron |
|---:|---:|---:|---:|
| 1 | 20 | 8 | 8 |
| 2 | 18 | 5 | 8 |
| 3 | 16 | 7 | 8 |
| 4 | 14 | 3 | 9 |
| 5 | 13 | 5 | 10 |
| 6 | 13 | 4 | 11 |
| 7 | 9.1 | 6 | 12 |
| 8 | 10.1 | 8 | 13 |
| 9 | 11.1 | 4 | 12 |
| 10 | 9.1 | 3 | 11 |
| 11 | 9.1 | 4 | 11 |
| 12 | 8.1 | 3 | 10 |
| 13 | 6.1 | 2 | 9 |
| 14 | 6.1 | 4 | 10 |
| 15 | 6.1 | 3 | 9 |
| 16 | 4.1 | 3 | 8 |
| 17 | 3.1 | 3 | 8 |
| 18 | 4.1 | 5 | 9 |
| 19 | 3.1 | 4 | 8 |
| 20 | 0.1 | 2 | 7 |
| 21 | 1.1 | 5 | 8 |

## Campaign construction-cost rules

`../campaign-city-balance-tuning/tune_catalog_costs.py` applies the following deterministic rules to the full 98-entry catalog and writes explicit `costs` maps to the runtime JSON. All amounts are positive and all keys are in `{food, wood, iron}`. `../campaign-city-balance-tuning/selected_plan.json` contains the machine-readable 98-ID cost snapshot and the exact resulting 21-day ledger.

| Rule family | Construction price rule |
|---|---|
| Canonical MVP overrides | Farm 4 wood; sawmill 5 wood; iron mine 6 wood; housing 6 wood; day-one barracks 8 wood + 2 iron. |
| Training | 8 wood + 2 iron; training + static defense 10 wood + 3 iron. |
| Static defense | Active strength 1: 3 wood + 1 iron; strength 2: 4 wood + 1 iron; strength 3: 6 wood + 2 iron. Combined training/defense uses the training-plus-defense tier. |
| Production | `labor_tiers = max(1, ceil(jobs / 2))`; wood = 2 + 2 × labor tiers + 2 when recipes output more than one resource; add 1 iron when output-resource count is greater than one. |
| Production + service | Add 1 food and 1 wood per declared service-capacity unit. |
| Production + housing | Add 4 wood + 1 iron when resident capacity is positive; combined production/service/housing rules accumulate their declared effects. |
| Housing | Wood = 6 + max(0, floor((capacity − 10) / 5)); administration adds 2 wood + 1 iron; each service-capacity unit adds 1 food + 1 wood. |
| Service-only | Food and wood each equal the summed positive service-capacity units (minimum 1); add 1 iron at capacity 2 or higher. |
| Two-turn construction | Add 1 wood + 1 iron after the role/effect price is calculated. |

### Catalog IDs covered by the pricing rules

The entries below partition all 98 runtime IDs; the role/effect rule above determines each explicit price, and the two-turn premium applies to the marked groups.

| Pricing rule | Count | Runtime IDs |
|---|---:|---|
| `canonical_mvp_override` | 5 | `campaign_farm`, `campaign_sawmill`, `campaign_iron_mine`, `campaign_housing`, `campaign_barracks` |
| `training` | 29 | `aoe4_barracks`, `aoe4_stable`, `aoe4_varangian_stronghold`, `aoe4_varangian_warcamp`, `aoe4_military_school`, `aoe4_archery_range`, `aoe4_mercenary_house`, `aoe4_machine_workshop`, `aoe4_war_stable`, `aoe4_hojo_clan_daimyo_estate`, `aoe4_oda_clan_daimyo_estate`, `aoe4_takeda_clan_daimyo_estate`, `aoe4_siege_workshop`, `aoe4_abbey_of_kings`, `aoe4_abbey_of_the_trinity`, `aoe4_buddhist_temple`, `aoe4_dome_of_the_faith`, `aoe4_golden_tent`, `aoe4_grand_winery`, `aoe4_hunting_cabin`, `aoe4_monastery`, `aoe4_mosque`, `aoe4_mountain_hall`, `aoe4_pagoda`, `aoe4_prayer_tent`, `aoe4_regnitz_cathedral`, `aoe4_shaolin_monastery`, `aoe4_shinto_shrine`, `aoe4_temple_of_equality` |
| `defense_tier_3` | 1 | `aoe4_palisade` |
| `defense_tier_1` | 6 | `aoe4_palisade_gate`, `aoe4_fortified_palisade_gate`, `aoe4_fortified_palisade_wall`, `aoe4_stone_wall`, `aoe4_stone_wall_gate`, `aoe4_stone_wall_tower` |
| `defense_tier_2` | 4 | `aoe4_outpost`, `aoe4_fortified_outpost`, `aoe4_toll_outpost`, `aoe4_wooden_fortress` |
| `training_plus_defense` | 4 | `aoe4_tughlaqabad_fort`, `aoe4_keep`, `aoe4_capital_town_center`, `aoe4_town_center` |
| `defense_tier_3+two_turn_premium` | 9 | `aoe4_castle`, `aoe4_lancaster_castle`, `aoe4_barbican_of_the_sun`, `aoe4_saharan_trade_network`, `aoe4_kremlin`, `aoe4_red_palace`, `aoe4_elzbach_palace`, `aoe4_castle_of_the_crow`, `aoe4_fort_of_the_huntress` |
| `training+two_turn_premium` | 14 | `aoe4_imperial_hippodrome`, `aoe4_school_of_cavalry`, `aoe4_koka_township`, `aoe4_council_hall`, `aoe4_great_pasture`, `aoe4_golden_horn_tower_by`, `aoe4_burgrave_palace`, `aoe4_farimba_garrison`, `aoe4_palatine_school`, `aoe4_palace_of_the_sultan`, `aoe4_tanegashima_gunsmith`, `aoe4_khaganate_palace`, `aoe4_king_s_palace`, `aoe4_palace_of_swabia` |
| `training_plus_defense+two_turn_premium` | 3 | `aoe4_golden_horn_tower_mac`, `aoe4_the_white_tower`, `aoe4_berkshire_palace` |
| `defense_tier_1+two_turn_premium` | 3 | `aoe4_great_wall_bastion`, `aoe4_great_wall_gatehouse`, `aoe4_sea_gate_castle` |
| `defense_tier_2+two_turn_premium` | 2 | `aoe4_spasskaya_tower`, `aoe4_fortress` |
| `production_capacity_and_output_count+two_turn_premium` | 4 | `terrascape_fruit_farm`, `terrascape_ox_mill`, `terrascape_greater_mill`, `terrascape_timber_mill` |
| `production_capacity_and_output_count+housing_capacity+two_turn_premium` | 1 | `terrascape_shieling` |
| `service_capacity+two_turn_premium` | 10 | `terrascape_sanctuary`, `terrascape_herb_garden`, `terrascape_henge`, `terrascape_city_park`, `terrascape_lotus_basin`, `terrascape_nun_cistern`, `terrascape_kenbet`, `terrascape_great_plaza`, `terrascape_hospital`, `terrascape_university` |
| `production_capacity_and_output_count+service_capacity+two_turn_premium` | 1 | `terrascape_pond_farm` |
| `production_capacity_and_output_count` | 1 | `terrascape_royal_forest_variant` |
| `housing_capacity+service_capacity` | 1 | `terrascape_citydistrict_variant` |

The table covers 98/98 IDs. The runtime catalog remains the authority for exact integer cost maps; the rule script and JSON are kept together so a future role/effect edit either remains assigned to a documented tier or fails the script's unclassified-ID check.
