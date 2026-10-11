# Proposal: Campaign city economy and unified building roster

## Why

The campaign city currently has several overlapping design layers: the canonical hex-city and resource-flow model, Against the Storm-derived settlement systems, TerraScape building adjacencies/merges, and an older Age-of-Empires-style military tech tree. They need one coherent set of population archetypes, buildings, production chains, and defenses so the player manages one campaign city rather than parallel or contradictory city systems.

## What Changes

- Make the **campaign city** the sole home for the integrated system. Reuse the canonical 52-hex city and natural-resource stock/flow economy; do not create a separate score-attack city mode.
- Represent the working population through the project's seven economic archetypes, using Against the Storm as the reference for differentiated needs, work preferences, satisfaction, and group-combination effects. Individual D&D ancestry remains identity/metadata, not a second competing economy simulation.
- Build one deduplicated, source-traceable building catalog from all Against the Storm and TerraScape buildings, plus Age of Empires IV buildings that train eligible campaign party roles or provide static defense. Include released source-game building variants in the inventory; exclude naval buildings/units and non-building units. Adapt names and effects to this game's setting and resource registry; do not add an AoE troop roster.
- Retain TerraScape-style placement synergies, penalties, and building merges as city rules; merge duplicate source concepts instead of creating parallel copies.
- Connect AoE IV-inspired military production and defense to the campaign's class-based character-training and raid systems. Keep all production and outcome resolution deterministic; no source game's score victory, RNG production rolls, generic troop roster, or separate settlement-win meter is imported.
- Replace obsolete city-level unlock assumptions with explicit building prerequisites/administrative capacity consistent with the campaign canon; keep the 52-cell layout and existing pressure-based raid model.
- Reconcile the in-flight `terrascape-hex-city-builder` plan: its standalone score-attack scope must not become a second campaign-city implementation. Reuse eligible source data/design only; do not implement its isolated mode as part of this change.

## Capabilities

### New Capabilities
- `campaign-city-economy`: one campaign-city economy contract for stock/flow transactions, deterministic building production, recipe inputs/outputs, upkeep, and integration with population and military systems.

### Modified Capabilities
- `settlement-buildings`: replace the narrow Against-the-Storm-only roster with the unified catalog, placement/synergy/merge rules, and unit-production/defense building behavior.
- `settlement-species`: simulate residents by the seven economic archetypes; retain ancestry as non-economic identity data.
- `settlement-resolve`: define archetype-based needs, work preferences, and city mood/satisfaction without importing a separate score or victory currency.
- `settlement-reputation`: prevent the reference game's reputation victory and forest-hostility model from conflicting with campaign Prestige and pressure-based raids.
- `city-tech-tree`: replace city levels 1–11 with prerequisite/admin-capacity gates for buildings and military production, consistent with campaign canon.

## Impact

- Design/specs: `docs/02g-city-hex.md`, `docs/02e2-city.md`, `docs/02e4-military.md`, `docs/06-economy.md`, `docs/DECISIONS.md`; matching OpenSpec settlement/city capabilities.
- Code/data: campaign city, settlement, economy, adjacency, worker assignment, raid/defense, and character-training systems; unified building/archetype/recipe data; save compatibility if city state or resident records change.
- Verification: GdUnit4 tests for catalog completeness and references, deterministic production, adjacency/merges, needs, class-based training, defense, raid integration, and save/load. UI/playtest checks remain deferred where headless cannot verify them.
