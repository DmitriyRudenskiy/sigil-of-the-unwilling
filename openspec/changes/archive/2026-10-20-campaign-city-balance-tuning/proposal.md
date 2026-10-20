# Proposal

## Why

The campaign building catalog's 98 authored costs have not been validated against a canonical playthrough, and the city cannot currently realize the intended economy: campaign production buildings receive no workers from the legacy-only allocator, while canonical food demand is not charged through the campaign ledger. Tune prices only after making the MVP city simulation executable and measuring a deterministic 21-day plan.

## What Changes

- Connect deterministic worker assignment for campaign buildings and canonical resident/party food use to the shared resource ledger.
- Simulate the documented MVP start (20 residents, housing 20, food/wood/iron 30/20/10, two-person starting party) for 21 days in a reproducible scenario.
- Calculate a feasible 52-cell construction plan and build order from the runtime catalog; the 98 definitions are alternatives, not a demand to place them all.
- Retune campaign-authored construction costs for all 98 runtime definitions against the campaign resource mask and target milestones; document counts, costs, assumptions, and resulting day-by-day stocks.
- Extend balance-probe reporting with city-economy metrics and repeatability checks.

## Capabilities

### New Capabilities
- `campaign-city-economy`: deterministic staffing, food flows, and a measured 21-day construction/economy plan for the canonical campaign city.

### Modified Capabilities
- `balance-probe`: include city-building counts, affordability/build milestones, and resource-stock metrics in reproducible balance runs.

## Impact

- `game/assets/data/campaign_building_catalog.json` and its balance documentation.
- Campaign economy, worker-assignment, city/party food provisioning, and turn-scheduler integration.
- Deterministic GdUnit4 campaign scenario and balance-probe reporting.
- OpenSpec specs for `campaign-city-economy` and `balance-probe`; no new dependency or alternate resource/economy mode.
