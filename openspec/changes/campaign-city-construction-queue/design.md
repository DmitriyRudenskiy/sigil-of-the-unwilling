# Design

## Context

See `proposal.md` and `specs/campaign-city-construction/spec.md`. The current runtime already shares `CityData.campaign_buildings`, `CampaignBuildingPlacement`, `ResourceContext`, `CitySerializer`, and a priority-sorted `TurnScheduler`; construction duration exists in the catalog contract but has no live owner.

## Goals / Non-Goals

**Goals:** validate before payment, persist progress on the building instance, and make completion visible to existing economy/training/defense consumers.

**Non-Goals:** source catalog population, worker assignment or acceleration, construction cancellation/refunds, physical storage capacity, construction slots, city-level unlocks, and UI work.

## Decisions

- **Store progress on each building instance.** Add a non-negative `construction_turns_remaining` field. Existing buildings without it are treated as completed; this avoids another queue/save subsystem and makes simultaneous sites deterministic.
- **Spend costs once at accepted start.** Validate the catalog record, prerequisites, placement footprint/terrain, occupied cells, and resource availability first; commit costs in one `ResourceContext.transact`, then append one instance. Failed validation or payment changes neither buildings nor stock. Cancellation/refunds are not part of this smallest contract.
- **Reuse the existing `inactive` state during construction.** A positive remaining count suppresses production, upkeep, training, and defense even if an inactive-state definition has effects. When progress reaches zero, set the instance active once. Zero-turn buildings are active at creation. No catalog state enum or balance values need to change.
- **Advance in the existing scheduler.** Add one processor after the city/raid phase and before economy. Each turn decrements each in-progress instance once; newly completed buildings can participate in the later economy phase, while their defense starts at the next raid phase.
- **Reuse generic city serialization.** `CitySerializer` already serializes campaign-building dictionaries. Missing progress defaults to zero, so old buildings remain as-is; no migration should debit stock or infer construction.
- **Keep source evidence as a prerequisite, not an implementation shortcut.** Requests resolve only a validated catalog record. Until the source audit is complete, the catalog remains unpopulated; test fixtures cannot be promoted to game content.

## Risks / Trade-offs

- [An inactive building may normally provide defense or other effects] → all runtime consumers that can act on an in-progress instance must check the positive remaining count, not rely only on `state`.
- [Upfront costs with no cancellation refund can feel irreversible] → expose progress and site before accepting the transaction; defer cancellation policy rather than invent a refund percentage.
- [Construction processor ordering can affect same-turn benefits] → keep it after city raids and before economy, and pin that order with an integration test.
- [Unreviewed source rows could become buildable] → catalog validation and upstream manifest coverage remain prerequisites; never synthesize missing entries.
