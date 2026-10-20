# Design

## Context

See `proposal.md` and the two delta specs. The runtime catalog has 98 campaign-authored definitions, while existing economy code reads `assigned_workers`; the legacy worker allocator does not staff `campaign_buildings`. The world bootstrap also does not currently debit canonical resident food through the campaign ledger. `CityFactory`'s 4-worker/2-follower, food/gold/industry setup is a legacy village profile, so it must not be silently substituted for the documented 21-day MVP balance start.

## Goals / Non-Goals

**Goals:**
- Make the existing campaign-building and shared-resource path capable of producing a deterministic 21-day balance result.
- Provide a canonical, isolated start fixture and a selected city blueprint that can be replayed and audited.
- Tune all 98 catalog costs using only the MVP resource mask and the documented milestone sequence.

**Non-Goals:**
- Replace or rebalance the legacy `CityFactory` village kit.
- Place all 98 catalog alternatives in one city, import source-game prices, or introduce a score/currency.
- Add manual worker assignment UI or change unrelated classic-building production.

## Decisions

1. **Keep the canonical balance start separate from the legacy village factory.** The balance scenario is seeded from `MVP-scope.md` (20 residents, housing 20, food 30, wood 20, iron 10, fighter+ranger, 21 daily turns) and the existing canonical archetype profiles. Do not rewrite `CityFactory`, whose profile serves existing world/city tests. The scenario report must state any explicit fixture assumptions, including resident-group distribution and carried provisions.
   - Alternative rejected: change `CityFactory` to the campaign start. That would silently alter the classic world and still would not create a reliable 21-day campaign fixture.

2. **Extend the existing economy path instead of creating a parallel simulator.** Add a runtime-only `is_campaign` mode shared by `CityManager` and `TurnContext`; it defaults to legacy and is not serialized. In campaign mode, `CityManager` skips the legacy `CityGrowthService` food/growth pass and legacy capital inflow, while the existing scheduler applies campaign production, canonical resident/party food flows, and group-need reporting through the same `ResourceContext`. Legacy mode and `CityFactory` remain unchanged; no save-schema migration is introduced.
   - Preserve valid campaign worker assignments; assign remaining workers food → wood → iron with stable building-UID/recipe-ID ties and respect each recipe's worker limit.
   - Alternative rejected: add a second economy scheduler or a separate balance-only production implementation; it could diverge from the gameplay path.

3. **Treat party food as carried provisions with an explicit home-turn refill.** The MVP party is exactly two members and has a campaign provision capacity of 10 food, independent of the legacy backpack's 12-unit cap. At end turn, if the hero is within a city's 52-cell footprint, fill carried food up to 10 from that city's stock through an attributed transaction, before that day's party ration debit. Each party member then consumes one carried food per day; away from a city there is no refill. The canonical fixture starts with zero carried food at the capital, making its first-day refill visible in the ledger. Resident demand remains 0.1 food per resident per day.
   - Alternative rejected: debit party food from the city every day regardless of location; that would bypass the carried-provisions and refill rules in R7.

4. **Tune costs by campaign utility, then verify a chosen plan.** Preserve data-driven costs on every runtime definition. Use role families (basic production/housing, services, administration, training, static defense, and combined roles) as cost anchors; distinguish higher-capacity or multi-role records only when their declared campaign effect justifies it. The plan selects a subset from the 98 alternatives, accounts for footprints, prerequisites, worker demand, production, and service capacity, and is documented in `campaign-catalog-design.md` with counts, build days, costs, and 21-day stock results. The canonical `campaign_barracks` also provides 3 brawling-service capacity: that original campaign-authored training-hall effect fills a missing provider for the canonical Alchemists & Flame need; it is not imported from a source-game row.
   - Alternative rejected: assign a unique arbitrary cost to every row, or price every source-backed building identically; neither is auditable against function.

5. **Use a deterministic GdUnit4 run for the balance loop.** Fix the start, action/raid itinerary, archetype composition, and tie-break ordering. Record per-day resource ledger, stocks, staffing, and milestones. Keep tunable-target misses visible as warnings in balance reporting in line with the existing `balance-probe` contract; technical errors and nondeterministic output remain test failures.
   - Alternative rejected: treat a headless pass as proof of fun or depend on an MCP/GUI run for every numeric iteration.

## Risks / Trade-offs

- [Canon specifies population and party size but not every fixture detail] → Record the deterministic group split and carried-provision assumption in the report; the fixture starts with zero carried food in the capital so the first-turn resupply is auditable. Do not alter canonical city starting stocks.
- [Runtime has both a legacy growth pass and the campaign scheduler] → Gate the legacy pass with runtime-only `is_campaign`; keep legacy as the default and do not serialize the mode.
- [Auto-staffing priority can starve optional production] → Keep a food → wood → iron order with stable tie-breaks; report unfilled jobs so plans can be compared.
- [Raid/random world events can obscure price effects] → Use a fixed deterministic itinerary and raid inputs for calibration; separately report omitted stochastic content.
- [A balanced test plan may not represent every player strategy] → Treat it as a canonical baseline and keep all 98 definitions available; do not claim universal optimality.

## Migration Plan

1. Capture the current catalog costs and a baseline 21-day report before changing values.
2. Connect staffing and resident/party food flows to existing resource state with focused tests.
3. Add the deterministic canonical balance scenario and confirm its ledger is reproducible.
4. Compute the 52-cell plan, revise costs across all 98 records, and update the campaign catalog design note with the measured plan/results.
5. Run focused construction/economy tests, full `game/run_tests.sh`, OpenSpec validation, doc-link check, and diff check. No save schema or legacy city-start migration is expected; if testing disproves that, stop and revise the proposal rather than silently broadening rollout.

## Baseline capture (before cost tuning)

The pre-tuning `baseline.json` snapshots all 98 original catalog costs and the deterministic 21-day runtime report before any price edits or the later brawling-provider addition. Its fixture assumptions are explicit: all 20 residents are available workers; the seven canonical groups have counts 3/3/3/3/3/3/2 (gnomes/builders, halflings/farmers, tieflings/alchemists, elves/weavers, humans/merchants, half-orcs/hunters, dwarves/metallurgists); two free starting `campaign_housing` instances provide capacity 20; the two-person fighter+ranger party starts at the capital with 0 carried food and capacity 10.

That baseline uses farm+barracks on day 1, sawmill on day 2, iron mine on day 4, second farm on day 6, and palisade on day 9; its fixed unrepelled day-7 raid is strength 6 versus defense 1 and pillages 30% of then-current city food. All six requests fit the 52-cell city and are affordable under the original prices. It ends day 21 at food 18.1, wood 31, iron 24; food exceeds the 0–8 target, preserved as the `day21_food` warning in the snapshot.

The current tuned selected plan adds Herb Garden (day 10), Lotus Basin (11), three Kenbets (12, 13, 19), University (15), Sanctuary (16), Henge (17), and Great Plaza (20). Along with the six baseline builds and two free starting houses, it occupies 17/52 cells. All 15 construction requests are affordable; cumulative construction costs are 17 food, 59 wood, and 20 iron. At day 21, service capacities cover brawling 3, education 5, market access 3, religion 3, and treatment 3; all seven canonical groups report 100% need coverage. Eight workers staff the two farms, sawmill, and iron mine. Ending stocks are food 1.1, wood 5, iron 8; the day-7 raid leaves 9.1 food after that day's economy step.
