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
| `campaign_barracks` | 8 wood + 2 iron | Trains fighter/ranger; 1 active defense | Makes training available through the approved party path and resolves defense on the current integer strength scale. |

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

Training structures cost 8 wood + 2 iron; static defenses cost 6 wood + 2 iron; a building with both roles costs 10 wood + 3 iron. Source landmarks/palaces/castles take two turns; other buildings take one. All construction footprints are one city hex and allow any legal city terrain because there is no source-backed or campaign-canonical multi-hex footprint rule in this slice.

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

Registered service capacities use the seven campaign need IDs: `Sanctuary` (religion + mediation), `Herb Garden` (treatment 2), `Henge` (religion), `City Park` (mediation), `Lotus Basin`/`Nun Cistern` (treatment), `Kenbet` (education + market access), `Great Plaza` (mediation 2 + religion), `Hospital` (treatment 2), `University` (education 2), and `CityDistrict Variant` (housing capacity 10 + market access). These are campaign service assignments, not claims about source-game effects.

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

The JSON schema/source audit and GdUnit4 catalog validation prove structural validity, provenance admission, deterministic transaction resource IDs, and absence of null/candidate rows. They do not prove that the selected rates are balanced in a human playtest. Balance tuning and visual/UI verification remain deferred; any later numeric change must stay campaign-owned and update this design note plus the catalog asset.
