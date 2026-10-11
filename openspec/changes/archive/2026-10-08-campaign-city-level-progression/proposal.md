# Proposal

## Why

The campaign-city design deliberately removed the legacy 1–11 city-level track, but the project owner has now directed that the track return. Without a per-level construction allowance, the 52-cell city can be filled at its starting level, so the level progression has no build-space pacing role.

## What Changes

- Restore campaign-city levels 1–11 while leaving legacy city progression unchanged.
- Cap occupied building cells by level: 4, 9, 14, 19, 24, 29, 34, 39, 44, 48, and 52.
- Count the four-cell city core, starting buildings, completed buildings, and construction in progress toward the allowance; count unique occupied cells, not building instances.
- Allow a campaign city to level up only after it fills its current allowance. Level 11 is the cap; no new currency or level-up fee is introduced.
- Show level, occupied city cells, limit, and the blocker/level-up action in the city UI; reject over-limit construction before charging resources.
- Keep all 52 building cells unavailable until level 11. Preserve city level through the existing city save field.

## Capabilities

### New Capabilities

- `campaign-city-level-progression`: campaign city level 1–11 gates occupied construction cells and advances only when the current allowance is filled.

### Modified Capabilities

- `campaign-city-management-ui`: display campaign city level/allowance and explain level-up/build-limit states.

## Impact

- `CampaignCityProgression`, `CampaignBuildingConstructionService`, and `CityScreen`.
- GdUnit4 construction, level-progression, UI, and 21-day balance tests.
- A new `campaign-city-level-progression` contract and the campaign management-UI spec. No new dependencies or save-schema fields are required; the existing city level is persisted.
- This change supersedes the campaign-specific no-city-level requirement from `campaign-city-building-economy`; it does not restore that change's obsolete source-game unit, score, or currency mechanics.

The capacity track is deliberately the progression gate: no independent resource fee is added, so the 52-cell limit—not an invented currency—sets the pacing.