# Ancestry → campaign archetype crosswalk (task 2.3)

## Scope and authority

The selected simulation scope is the canonical MVP first tier of seven ancestries, one per economic group. The mapping authority is [`game/assets/data/mvp_catalog.json`](../../../game/assets/data/mvp_catalog.json), whose metadata points to `docs/02e3-races.md` §9.2/§9.4 and the K-M5 decision. The source inventory deliberately preserves two separate post-MVP artifacts: the repository's 54-entry ancestry catalog and the owner's A6-R table with 55 entries. This change does not reconcile, rewrite, truncate, or combine those catalogs.

| Selected ancestry ID | Display name | Canonical group ID | Canonical group | Simulation disposition |
|---|---|---|---|---|
| `gnomes` | Гномы | `engineers_builders` | Инженеры & Строители | Map exactly once |
| `halflings` | Полурослики | `farmers_brewers` | Земледельцы & Пивовары | Map exactly once |
| `tieflings` | Тифлинги | `alchemists_flame` | Алхимики & Хранители Пламени | Map exactly once |
| `elves` | Эльфы | `weavers_crafters` | Ткачи & Ремесленники | Map exactly once |
| `humans` | Люди | `merchants_diplomats` | Торговцы & Дипломаты | Map exactly once |
| `dwarves` | Дворфы | `metallurgists_technicians` | Металлурги & Техники | Map exactly once |
| `half_orcs` | Полуорки | `hunters_trackers` | Охотники & Следопыты | Map exactly once |

The canonical IDs above match both `mvp_catalog.json` and the archetype-profile data. A race's SRD ability modifiers remain character data; group needs/work behavior resolve through the archetype. No ancestry adds a separate economy, need, or job lock.

## Exclusions and validation contract

- The first-tier set contains exactly seven unique ancestry IDs and seven unique group IDs; every selected ancestry maps once, and every MVP group has one selected ancestry.
- Every ancestry outside this first-tier set is **explicitly out of the MVP population-simulation scope**, not mapped by guessing, flattened into another ancestry, or deleted from either catalog. Post-MVP catalog reconciliation remains a separate content task.
- The live pre-pivot `races_classes.json` / `RaceClassRegistry` Pathfinder layer is legacy and is not a source for these campaign mappings. This crosswalk does not alter that file or its consumers.
- Unknown ancestry behavior remains the settlement-species contract: use an explicitly configured neutral fallback or reject scenario data during validation. The MVP catalog currently resolves all seven selectable ancestries directly, so no fallback is exercised by this scope.

Validation against the checked-in MVP catalog found seven first-tier entries, unique ancestry IDs, unique group IDs, and exact agreement with the seven canonical group IDs. The 54-entry repository catalog and 55-entry owner A6-R table remain separate and were not used to infer mappings beyond the selected seven.
