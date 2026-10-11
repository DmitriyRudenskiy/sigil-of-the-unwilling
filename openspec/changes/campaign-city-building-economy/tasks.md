# Tasks

## 1. Scope and source inventory

- [x] 1.1 Reconcile `terrascape-hex-city-builder` against this campaign-city scope; record whether it is superseded, split, or reduced to a source reference, and verify no second campaign city/score mode is scheduled.
- [x] 1.2 Freeze source-game versions and released-DLC scope; create versioned public-reference manifests for every row in each accessible full enumeration and every individually sourced candidate in partial enumerations. Every row carries source/version, evidence confidence, and a disposition; each unobserved roster portion is listed as an explicit `unknown` coverage gap rather than guessed or represented by a pseudo-entry.
- [x] 1.3 Normalize confirmed observed source rows into canonical roles/variants or explicit exclusions; retain `candidate`/`unknown` rows as non-admitted evidence with reasons. Verify the audit reports zero **observed** entries missing provenance/confidence/disposition and separately reports each unresolved source-coverage gap; do not claim the target-version roster is exhaustive where evidence does not support that claim.
- [x] 1.4 Audit campaign resource and character-training registries against the proposed sources; map source recipes/currencies to registered resources or explicitly omit them; verify there are no unregistered transaction items or unsupported training targets.

## 2. Population archetypes and social economy

- [x] 2.1 Define the seven campaign archetypes' needs, preferred work roles, satisfaction inputs, and temperament/behavior parameters using researched Against the Storm patterns; verify each parameter has a gameplay explanation and deterministic resolution rule.
- [x] 2.2 Define the archetype-pair synergy/tension matrix and mitigation building/service links; verify all pairs are explicit (including neutral pairs), bounded, and contain no implicit hard race/job exclusion.
- [x] 2.3 Reconcile playable ancestry-to-archetype mappings without collapsing the separate 54-entry repository catalog and 55-entry owner A6-R table; verify every ancestry in the selected simulation scope maps once or carries an explicit fallback/exclusion.
- [x] 2.4 Implement group needs and work modifiers as data; add GdUnit4 tests for supplied/unmet needs, compatible/tense/neutral group pairs, and identical results across repeated runs.

## 3. Unified building and production data

- [x] 3.1 Define and validate the unified building record (source refs, role, footprint, placement, costs, upkeep, workers, recipes/services, group affinities, adjacency, merge, prerequisites, approved character-class training links, defense, active states); verify all references resolve and invalid entries fail clearly.
- [x] 3.2 Populate the canonical catalog only from source rows confirmed for the frozen boundary and approved for a campaign role; preserve confirmed variants and deduplicate only equivalent campaign behavior. Map every admitted confirmed item to a catalog entry or reasoned exclusion; keep candidate/unknown rows explicitly outside runtime content with their uncertainty reason. Verify all catalog references resolve and no source-only value is silently imported.
- [x] 3.3 Implement resource-flow transactions and deterministic recipe processing against the canonical Layer-1/Layer-2 registry; add GdUnit4 tests for exact inputs/outputs, shortage, atomic failure, upkeep, and ledger conservation.
- [x] 3.4 Implement TerraScape-inspired adjacency and placement explanations using the campaign 52-hex layout; add tests for radius/footprint/terrain constraints, stacking/bounds, neighbor recomputation, and visible cause breakdowns.
- [x] 3.5 Implement declared building merges as atomic data-driven operations; add tests for valid/invalid recipes, state transfer, no duplicate stock/capacity, and merge-graph cycle detection.

## 4. Military production and city defense

- [x] 4.1 Map each in-scope AoE IV military building to an approved campaign class-training target or an explicit training-support role; verify naval and unsupported generic troop templates never appear in training choices.
- [x] 4.2 Implement class-based training through the canonical campaign character/party path with registered costs and existing party-capacity rules; add tests for success, missing prerequisite/resource, full capacity, and atomic rollback.
- [x] 4.3 Map static defense buildings to existing city defense/pressure-raid inputs; add tests that active defense changes raid resolution deterministically and inactive/ruined defense does not grant active protection.
- [x] 4.4 Replace 1–11 city-level unlocks with explicit building prerequisites and administrative capacity; verify no city-level field is read by unlock/training paths and no capacity loss deletes existing entities.

## 5. Campaign integration, saves, and documentation

- [x] 5.1 Integrate production, needs, group modifiers, upkeep, and defense inputs into the established settlement/player/threat turn order; verify an end-to-end deterministic campaign turn produces a complete ledger.
- [x] 5.2 Add versioned save migration for existing buildings, stocks, resident ancestry/archetype, and campaign character/party training state; verify old-save load, new-save round trip, and repeated migration are safe.
- [x] 5.3 Update affected tests and add a deterministic campaign scenario covering a production chain, at least two archetypes, a merge/synergy, class-based training, and a pressure raid; verify the scenario is reproducible.
- [x] 5.4 Reconcile canonical GDD/docs and relevant OpenSpec capabilities with the implemented behavior, preserving `DECISIONS.md`/`origin/main` as authority; run docs-link checks and `openspec validate campaign-city-building-economy`.
- [x] 5.5 Run the project's required verification (`game/run_tests.sh`) and report any UI/playtest checks as deferred rather than claiming headless coverage.

- 5.1–5.3 runtime scenarios use explicit test fixtures. The shipped campaign catalog is `game/assets/data/campaign_building_catalog.json`; its source admission and numeric campaign-authored values are audited by `audit_campaign_catalog.py` and the runtime GdUnit4 test. Main-spec sync/archive remains intentionally deferred until final source/version review.

## 6. Follow-on mechanics after the core city is stable

- [x] 6.1 Audit remaining adjacent systems (construction timing, storage/logistics, trade, district upkeep/repair, population growth/migration, and seasonal/environment effects) against the unified catalog; produce a short dependency map and identify duplicate rules before expanding scope.
- [x] 6.2 Propose the next smallest OpenSpec change for the highest-impact uncovered adjacent mechanic; verify it reuses this catalog/economy and does not reintroduce city levels, parallel currencies, or source-game victory systems.
- [x] 6.3 After each follow-on mechanic is integrated, run its focused GdUnit4 tests and the project test entrypoint, then update the balance/source ledger before expanding again.

Task 6.3 is a release gate, not authorization to implement the follow-on now. This change only proposes `campaign-city-construction-queue`; no follow-on mechanic is integrated here. Its proposal tasks require focused and full test runs, and its content remains gated on the source-backed catalog.
