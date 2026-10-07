# Design

## Context

See `proposal.md` and the delta specs. `CityData.level` already persists and is clamped to 1–11. Campaign construction currently ignores that field; the campaign board's 52 unique cells are otherwise only limited by placement occupancy. Classic prosperity/population progression is a separate runtime and must remain unchanged.

## Goals / Non-Goals

**Goals:**
- Make campaign city level the single source for construction-cell capacity.
- Reuse the existing persisted city level and construction preflight; count a footprint once by its unique occupied cells.
- Keep the level progression reachable without legacy Gold/industry/prosperity requirements or new campaign currencies.
- Keep the balance runner deterministic and report the level reached by its chosen plan.

**Non-Goals:**
- Restore individual building unlock levels, weapon tiers, generic troop rosters, score, or city-size expansion.
- Change classic city level-up rules or the save schema.
- Automatically advance levels during gameplay; the player takes an explicit level-up action after filling the current allowance.

## Decisions

1. **Use one campaign-specific progression helper.** `CampaignCityProgression` owns the level-to-cell-cap table, occupied-cell counting, level-up validation, and increment. The classic `ProsperitySystem` remains unchanged. This keeps the same rule shared by construction preflight, the UI, and the balance runner; duplicating the table in callers was rejected.

2. **Count unique occupied city cells, not building objects.** Count the four always-occupied core cells and unique cells from boroughs, legacy buildings, and campaign building footprints that lie in the 52-cell city. Starting housing and construction-in-progress buildings count immediately; ruined buildings count while they still occupy cells. Deduplicate cell coordinates defensively. Units, workers, roads, and other non-building markers do not consume the allowance. Candidate multi-cell footprints consume their full unique-cell count. The fixed core baseline makes the 52-cell upper allowance attainable exactly when all 48 surrounding build sites are occupied; counting object instances would let a large-footprint building bypass the intended limit.

3. **Use the approved cap sequence exactly.** The per-level maxima are `[4, 9, 14, 19, 24, 29, 34, 39, 44, 48, 52]`. Level 1 begins with allowance 4; each successful level-up grants the next listed capacity. Level-up is allowed only when current occupied cells reach the current allowance; level 11 is terminal. No resource fee is invented: filling the allowance is the advancement cost. Alternative rejected: use legacy prosperity/population requirements, which are not driven by the campaign economy and can strand a campaign city below level 11.

4. **Reject over-cap construction before transaction.** `CampaignBuildingConstructionService.explain_request()` already validates placement and affordability without writes. After valid placement is computed, it compares current unique occupied city cells plus the proposed footprint to the current level cap. The returned reason includes level, used cells, and maximum; the existing request path therefore cannot spend or append on rejection.

5. **Advance explicitly; never silently auto-level.** The campaign HUD shows level and used/cap cells and offers the level-up action only when eligible. The deterministic balance itinerary records a level-up after filling a cap, as an explicit action, so its build sequence continues to replay the same campaign rule.

6. **Supersede only the campaign no-level decision.** The owner's direction restores a 1–11 capacity progression for campaign cities. The old campaign-specific prohibition is superseded; classic city rules and the campaign's rejection of score, source-game military rosters, and legacy currencies remain intact. The repository decision registry is append-only; its superseding registry entry is assigned at push/merge under D-139 rather than inventing a local D-number.

## Risks / Trade-offs

- [Existing saves may contain more buildings than a low-level allowance] → Preserve all saved buildings; block only future construction/level-up inconsistency. Never delete or deactivate existing content.
- [A malformed footprint could overcount capacity] → Count unique coordinates and use the same footprint expansion helper as placement.
- [The canonical 21-day plan reaches a different final level] → Replay explicit level-up actions in the balance scenario and regenerate only the tuned selected-plan report; keep the pre-tuning baseline immutable.
- [A campaign city with no `campaign_buildings` could be confused with a classic city in the shared screen] → Resolve campaign mode from the city's registered manager when available, with the existing campaign-building payload as a fallback for fixtures/saves.

## Migration Plan

No data migration is needed: `CityData.level` is already serialized. Old city levels remain valid. Construction of a saved city above its current allowance is not retroactively rejected; the cap applies to new requests and level-up validation. Rollback removes the new preflight and UI branch without changing serialized state.
