# Tasks

## 1. Make campaign-city daily economy executable

- [x] 1.1 Extend campaign worker allocation with a stable food-first, then wood/iron policy, preserve valid assignments, and respect each recipe's job limit; verify capacity, partial-staffing, construction/inactive exclusions, and deterministic tie-breaking with focused GdUnit4 tests.
- [ ] 1.2 Apply canonical resident food demand (0.1 per resident/day) to the shared city ledger and connect away-party ration use/resupply (1 food/member/day, carried capacity from canon) without double charging; verify exact ledger flows, shortage handling, and repeatability.
- [ ] 1.3 Wire these flows into the existing daily scheduler in an order where production, consumption, construction, and group-need reporting use one consistent day's state; verify a focused end-to-end turn test.

## 2. Build the deterministic 21-day balance run

- [ ] 2.1 Add a canonical fixture for 20 residents, housing 20, food/wood/iron 30/20/10, fighter+ranger party, 52-cell geometry, archetype distribution, and explicit carried-ration assumptions; verify the fixture matches the MVP source data and does not alter legacy `CityFactory` starts.
- [ ] 2.2 Capture a reproducible baseline and implement the selected construction/resupply/raid itinerary; verify two runs produce identical ordered ledgers, stocks, staff assignments, and building states for all 21 days.
- [ ] 2.3 Extend balance-probe output with building counts/build days, affordability, workers, daily resource flows/stocks, raid and day-21 milestones; verify target misses are reported as warnings distinct from technical failures.

## 3. Derive and tune the city plan

- [ ] 3.1 Calculate a feasible build order and counts from the 98-entry catalog for food, wood, iron, housing, seven-group services, training, and defense; verify footprint fits the 52-cell city and every planned prerequisite, worker slot, and cumulative payment is supported by the 21-day run.
- [ ] 3.2 Retune construction costs for all 98 runtime entries using only food/wood/iron and campaign role/effect tiers; verify every entry has valid explicit costs, day-one farm+barracks are affordable, and the selected plan never spends unavailable stock.
- [ ] 3.3 Update `campaign-catalog-design.md` with the selected counts/build days, all cost groups/overrides, documented assumptions, and per-day resulting stocks; verify every catalog ID is either listed directly or covered by an auditable cost rule.

## 4. Verify integration

- [ ] 4.1 Run the focused campaign economy, construction, worker-assignment, resource, and balance-probe GdUnit4 tests; fix failures.
- [ ] 4.2 Run `game/run_tests.sh`, strict validation for `campaign-city-balance-tuning`, `python3 scripts/check_docs_links.py`, and `git diff --check`; resolve failures before completion.
