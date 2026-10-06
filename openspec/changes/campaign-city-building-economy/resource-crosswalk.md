# Source resource and training crosswalk (task 1.4 — audited for the pinned/observed source rows)

## Campaign boundary

Authority remains `docs/DECISIONS.md` K-R2 and `docs/MVP-scope.md`: canonical Layer-1 is `{food, wood, iron, mercury, sulfur, crystals}`, and the MVP transaction mask is `{food, wood, iron}`. A source label is not a campaign resource just because a source game trades it. This table is a disposition of observed source recipe/cost labels; it does not change the runtime registries or authorize importing the source recipe unchanged.

## Against the Storm recipe goods

Source: pinned [`FrankRuis/ats_cheatsheet` `data/Goods.csv`](https://github.com/FrankRuis/ats_cheatsheet/blob/cea861b4a6a3668685f1b727def6d7d66565a5f8/data/Goods.csv) and [`js/buildings.json`](https://github.com/FrankRuis/ats_cheatsheet/blob/cea861b4a6a3668685f1b727def6d7d66565a5f8/js/buildings.json), source ID `ATS-DB@cea861b4a6a3668685f1b727def6d7d66565a5f8`. The recipe subset has 95 records and 69 distinct ingredient/product labels. `Food` goods below are conceptual candidates for the one registered `food` resource; they are **not** 19 additional stock IDs. Source-specific recipes that transform one food SKU into another, or require omitted goods, are not imported verbatim: their building role is retained only if a later campaign adaptation uses registered inputs/outputs.

| AtS source label | Pinned source category | Campaign disposition | Reason |
|---|---|---|---|
| Ale | Consumable Items | Omit from MVP | Source-only good, not in `{food, wood, iron}`. |
| Algae | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Amber | Trade Goods | Omit | Source currency; campaign has no Amber currency. |
| Barrels | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Berries | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Biscuits | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Blight Fuel | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Boots | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Brawling | Service output | Service capacity, not a resource | Checked against an active provider; never stored or spent as stock. |
| Bricks | Building Materials | Omit from MVP | Not canonical stone or wood; no silent rename. |
| Clay | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Clearance Water | Crafting Resources | Omit from MVP | Source-only water type, not a registered resource. |
| Coal | Fuel & Exploration | Omit | Source fuel category is not in the MVP mask. |
| Coats | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Copper Bar | Not in pinned `Goods.csv` | Omit | Source-specific copper chain; do not silently rename to canonical iron. |
| Copper Ore | Crafting Resources | Omit | Source-specific copper chain; do not silently rename to canonical iron. |
| Crystalized Dew | Crafting Resources | Omit | Source-specific refined material; not equivalent to canonical crystals. |
| Drizzle Water | Crafting Resources | Omit from MVP | Source-only water type, not a registered resource. |
| Dye | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Education | Service output | Service capacity, not a resource | Checked against an active provider; Scrolls are not imported as stock. |
| Eggs | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Fabric | Building Materials | Omit from MVP | Not a registered Layer-2 good in the MVP transaction mask. |
| Fish | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Flour | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Grain | Crafting Resources | Omit from MVP | Unprocessed source ingredient; no campaign `grain` ID. |
| Hearth Parts | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Herbs | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Incense | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Insects | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Jerky | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Leather | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Leisure | Service output | Service capacity, not a resource | Checked against an active provider; Ale is not imported as stock. |
| Luxury | Service output | Service capacity, not a resource | Checked against an active provider; Wine is not imported as stock. |
| Meat | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Mushrooms | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Oil | Fuel & Exploration | Omit | Source fuel category is not in the MVP mask. |
| Pack of Building Materials | Trade Goods | Omit from MVP | Source-specific pack item and trade abstraction. |
| Pack of Crops | Trade Goods | Omit from MVP | Source-specific pack item and trade abstraction. |
| Pack of Luxury Goods | Trade Goods | Omit from MVP | Source-specific pack item and trade abstraction. |
| Pack of Provisions | Trade Goods | Omit from MVP | Source-specific pack item and trade abstraction. |
| Pack of Trade Goods | Trade Goods | Omit from MVP | Source-specific pack item and trade abstraction. |
| Parts | Building Materials | Omit from MVP | Not a registered MVP good. |
| Paste | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Pickled Goods | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Pie | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Pipe | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Planks | Building Materials | Omit from MVP | Processed wood is not the registered `wood` resource. |
| Plant Fibre | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Porridge | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Pottery | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Reeds | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Religion | Service output | Service capacity, not a resource | Checked against an active provider; Incense is not imported as stock. |
| Resin | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Roots | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Salt | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Scales | Crafting Resources | Omit from MVP | Source-only good, not in the active resource mask. |
| Scrolls | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Sea Marrow | Fuel & Exploration | Omit | Source fuel category is not in the MVP mask. |
| Simple Tools | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Skewers | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Stone | Crafting Resources | Omit | Stone is explicitly outside the campaign MVP registry. |
| Storm Water | Crafting Resources | Omit from MVP | Source-only water type, not a registered resource. |
| Tea | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Training Gear | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Treatment | Service output | Service capacity, not a resource | Checked against an active provider; Tea is not imported as stock. |
| Vegetables | Food | Abstract to `food` only as an adapted edible output | No separate AtS SKU is introduced. |
| Waterskin | Not in pinned `Goods.csv` | Omit from MVP | Source-only production label with no canonical counterpart. |
| Wine | Consumable Items | Omit from MVP | Source-only good, not in the active resource mask. |
| Wood | Fuel & Exploration | Map to `wood` | Exact canonical MVP input. |

## TerraScape and Age of Empires IV source costs

| Source | Observed label/type | Campaign disposition |
|---|---|---|
| TerraScape | Card score / building score | Omit; score is not a resource, transaction input, unlock gate, or victory condition. |
| TerraScape | Card/merge predecessor relationship | Keep as placement/merge identity only; it is not a spendable resource. Exact merge catalog remains unaudited. |
| TerraScape | No verified canonical natural-resource transaction labels in the cited card/merge sources | Do not invent costs; an adapted campaign building must declare its costs from registered resources. |
| AoE IV | `food` | Direct label match to registered `food`; use only if the adapted campaign action actually charges it. |
| AoE IV | `wood` | Direct label match to registered `wood`; use only if the adapted campaign action actually charges it. |
| AoE IV | `stone`, `gold`, `oliveoil`, `silver` | Omit from MVP; none is in the active `{food, wood, iron}` transaction mask. Do not silently rename gold/stone to iron. |
| AoE IV | `vizier` | Non-stock progression/capacity input; omit from resource transactions. |
| AoE IV | `popcap`, `time`, `total` | Population/time/derived-total metadata, not spendable resources. |

Campaign adaptations may rebalance construction/training costs, but every such recipe must be declared in the unified catalog using registered IDs. This crosswalk does not approve source-game recipes or introduce a transaction item.

## Audit result (2026-10-05)

- Against the Storm pinned recipe subset: **95 records / 69 distinct ingredient and product labels**. A direct comparison of those source labels with the table above found all 69 explicitly classified; zero observed recipe labels are missing and no row is pending. Food outputs can only be abstracted to the one registered `food` resource in an adapted recipe; source-only inputs/outputs and currencies are omitted, never introduced as new stock IDs.
- TerraScape's observed score/card/merge values are not transaction resources. No natural-resource cost is asserted by the available deck/merge evidence; score and unknown costs are excluded rather than converted to campaign spend. This is a resource disposition, not proof of complete Egyptian building/merge coverage.
- AoE IV pinned audit: 95/95 source-signal names dispositioned; 49 producer names span 186 per-civ rows, with approved campaign class targets or explicit support/exclusion. All source resource/progression labels are mapped or omitted in the table above; only campaign-registered IDs may be used in transactions.
- Runtime catalog/training validators and focused GdUnit4 tests reject unregistered transaction IDs and unsupported training classes. Task 1.4 closes for the pinned/observed source labels. All shipped building/train costs are campaign-authored, registry-validated, and restricted to the MVP resource mask; source prices/values are not imported. AtS/TerraScape roster gaps remain explicit `unknown` evidence only.
