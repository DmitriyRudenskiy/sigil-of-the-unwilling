# Design: campaign city economy and unified buildings

## Context

See `proposal.md` for motivation and scope; the normative behavior is in the six delta specs. The campaign canon already provides a 52-hex city, seven economic archetypes, natural Layer-1/Layer-2 stock and flow, pressure-based raids, and no city levels. Existing OpenSpec and code also contain an older Against the Storm settlement model, a legacy 1–11 city tech tree, and an in-flight TerraScape score-attack plan. Those are competing inputs, not additional campaign modes to run in parallel.

## Goals / Non-Goals

**Goals:**
- One campaign-city catalog, production ledger, population simulation, building-placement model, party-training path, and raid defense path.
- Complete, auditable source coverage for each source game's selected scope.
- Preserve deterministic simulation and explainable economic/building effects.

**Non-Goals:**
- A separate TerraScape score-attack product or victory-by-score loop.
- A second resident species system, source-game DLC gates, Amber currency, Resolve-to-reputation win meter, or Forest Hostility raid clock.
- New battle rules or an AoE IV troop roster in this change; military buildings support only campaign-approved class-based character training. Naval content is excluded.
- Exact source names/artwork copied into shipped game content; source mechanics are adapted to the game's setting.

## Decisions

1. **Host system: canonical campaign city.** Integrate into the campaign's hex city and turn pipeline; do not create new city/world/autoload boundaries. The 52-cell layout remains authoritative. Before implementation, reconcile the existing `terrascape-hex-city-builder` change so its standalone score-attack scope cannot be mistaken for or shipped as this campaign system. Reuse its data only after audit.

2. **Source inventory before balance.** Freeze dated source-version/DLC boundaries and publish public-reference manifests with per-entry provenance, confidence (`confirmed` / `candidate` / `unknown`), and coverage gaps. For every full public index or enumerated source we can access, capture every named row; where only a partial roster is available, preserve all observed candidates and register the unobserved portion as `unknown` rather than inventing pseudo-entries. The manifests retain the requested distinctions:
   - Against the Storm: settlement-buildable objects, decorations, event objects, non-building cosmetics, and named variants.
   - TerraScape: card names/deck memberships, merge results and input components, monuments/stages, and unresolved card/variant identities.
   - Age of Empires IV: source buildings that train eligible human land roles or provide static defense, plus relevant support/exclusion false positives and civ variants.

   A confidence label applies to the specific fact supported by its cited public source; a source snapshot is not relabelled as the target version. Coverage audits SHALL report zero **observed** rows without a source, confidence, and disposition, while reporting unknown roster gaps separately. Candidate/unknown rows are evidence records only and SHALL NOT be promoted to canonical game content. Fandom/official pages blocked in this environment may be cross-checked via accessible public sources; no internal game files, saves, code, or assets are required or used.

3. **Population model: existing seven campaign archetypes.** The archetypes are the seven economic groups already in the campaign canon, not literal Against the Storm species. Against the Storm contributes the design pattern—distinct needs, work affinities, satisfaction, and group relations. D&D ancestry remains optional identity metadata and keeps its separate character-creation/stat role; it does not create another city-economy population. Task 2.1's seven data profiles and deterministic needs/work/response rules are recorded in [`archetype-profiles.md`](archetype-profiles.md); task 2.2's symmetric, bounded pair matrix and mitigation contract are in [`archetype-relations.md`](archetype-relations.md); the seven selected ancestry mappings and explicit post-MVP exclusion are in [`ancestry-archetype-crosswalk.md`](ancestry-archetype-crosswalk.md). Source goods and Resolve values are not imported. Resolve the existing 54-vs-55 ancestry registry mismatch only if the actual ancestry-to-archetype mapping needs those entries; it does not block archetype mechanics.

4. **One declarative building record.** Normalize building behavior into data with at least: stable ID; source references; role tags; footprint and legal placement; costs and upkeep; jobs/capacity; production recipes and service capacity; group affinities; explicit neighbor rules; merge recipe/result; prerequisites/admin capacity; approved character-class training links; defense effects; active/disabled/ruined behavior. Use the repository's established data validation conventions. Source-game values are starting evidence, not final balance values.

   **Record contract v1** is enforced by `CampaignBuildingCatalog.validate_catalog()` and GdUnit4. The shipped [`campaign_building_catalog.json`](../../../game/assets/data/campaign_building_catalog.json) contains only canonical campaign records and confirmed source refs; all numbers and campaign recipes are designed for this game's resource mask and rules, never copied from source games. Candidate/unknown references remain only in the evidence manifests.


5. **Natural resource ledger; no score economy.** Use the canonical resource registry and its MVP mask. Convert source currencies to explicit registered-goods exchanges or omit them; do not introduce Amber, building score, Resolve, or Prestige as spendable resources. Every stock change flows through one transaction/ledger contract. Building score, if useful for analysis, is derived only and never gates construction or training. The registry exposes the six Layer-1 IDs, five Layer-2 goods, and the `{food, wood, iron}` MVP mask; `ResourceContext` supports strict registry mode, atomic input/output transactions, capacity preflight, and source-attributed flow rows. `ProductionChain` and `EconomicTurnProcessor` use atomic commits for production and upkeep. Legacy campaign-city stock migration and switching old callers to strict mode remain task 5.1/5.2 work.

6. **Deterministic turn resolution.** Resolve production, consumption, needs, group modifiers, upkeep, and defense inputs in the established campaign settlement phase. Use fixed ordering and arithmetic from current state; replace chance-based double yields/critical production with deterministic declared modifiers. The threat phase continues to use the existing pressure accumulator. Synergy/merge calculations must report causes and must not duplicate resources or resident capacity.

7. **Military adaptation boundary.** AoE IV buildings map to the campaign's approved class-based party-training roles and existing party limits; they do not add generic `UnitRegistry` stacks or source-game troop stats. Static walls/towers/keeps/outposts become data-driven modifiers to existing city defense and raid resolution. Source buildings whose unit roles cannot be represented by an approved campaign class remain support-only or are explicitly excluded from training.

8. **Unlocks and capacity.** No city level 1–11. Building availability comes from explicit prerequisite buildings, registered resources, scenario flags, and administrative capacity. Administrative capacity is visible; losing its provider blocks new excess actions but never deletes existing content.

9. **Migration and rollout.** Treat the new catalog/ledger as a versioned campaign data contract. Add explicit save migration for existing city buildings, resource stock, resident ancestry/group, and campaign character/party training state before switching runtime reads. Roll out in slices: source inventory and validator; archetypes/economy; general buildings and merges; military/defense; final campaign integration. Keep old state readable until round-trip and migration tests pass; rollback disables new content through the campaign data mask rather than dropping saved data.

## Risks / Trade-offs

- [The source inventories are large and some wiki pages are blocked] → Freeze source versions; use verified alternate data sources; keep an auditable coverage manifest; do not invent a "complete" count.
- [Flattening seven archetypes could erase ancestry flavor] → Keep ancestry metadata and character effects separate; use archetype only for city simulation.
- [Combining several source adjacency/recipe systems can create runaway bonuses or cycles] → Normalize rules into named, bounded deterministic modifiers; test merge graphs for cycles and production chains for resource closure before tuning.
- [Military buildings may point to unsupported units] → Validate every training link against the approved campaign class/party model; unmapped roles remain support-only or are explicitly excluded.
- [Legacy docs/specs and the active standalone TerraScape plan disagree with campaign canon] → Apply this change's explicit removals, keep `DECISIONS.md` and origin/main as authority, and reconcile the old in-flight plan before implementation.
- [Changing resident/economy state can break saves] → Version the city payload and test old-save migration plus serialize/deserialize round trips.

## Migration Plan

1. Freeze the source-game versions and publish source inventories with per-entry provenance.
2. Validate archetype, building, recipe, adjacency, merge, character-training link, defense, and prerequisite references without changing runtime behavior.
3. Add new campaign data and pure deterministic resolution paths; test them independently.
4. Add and test save migration, then route campaign city resolution through the new data.
5. Remove old settlement/tech-tree behavior only after parity/migration checks pass; retain an explicit rollback mask until campaign tests succeed.

## Open Questions

None block the architecture. Exact building counts, balance values, and source variants are outputs of the source-inventory and balance tasks, not decisions to guess in advance.
