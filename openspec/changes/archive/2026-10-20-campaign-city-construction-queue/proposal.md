# Proposal

## Why

The unified campaign-building contract already declares construction duration and placement rules, but new buildings are not yet activated through the live campaign turn. A small construction queue will let players build catalog-backed structures in the existing 52-hex city without bypassing the shared resource ledger or inventing a second city progression system.

## What Changes

- Add a deterministic construction action and queue for a campaign building instance, driven by the existing catalog's explicit cost and construction-turn fields.
- Validate placement with the existing 52-hex placement service and spend registered resources atomically through the city's existing `ResourceContext`.
- Advance construction in the established turn order; activate the building only when its declared duration completes, and preserve queued/in-progress state across saves.
- Reject missing/invalid catalog records and unregistered costs; do not add guessed building data or source-game numeric values.

## Capabilities

### New Capabilities
- `campaign-city-construction`: campaign building placement, payment, deterministic progress, completion, and persistence.

### Modified Capabilities
- None.

## Impact

- Reuses `CampaignBuildingCatalog`, `CampaignBuildingPlacement`, `ResourceContext`, `CityData`/`CitySerializer`, and the existing `TurnScheduler`.
- Does not alter the 52-hex city boundary, city-level progression, canonical resource registry, class-training path, or raid system.
- Canonical source rows remain gated by `campaign-city-building-economy` tasks 1.2–1.4 and 3.2; this change must operate only on audited catalog entries and must not populate the catalog with placeholders.
