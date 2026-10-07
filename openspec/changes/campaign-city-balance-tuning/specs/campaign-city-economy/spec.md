# Spec Delta

## Purpose

Defines the reproducible MVP campaign-city economy: how residents and the party consume food, how available workers staff production, and which resource costs and build plan sustain the 21-day city. The 98 catalog records remain choices for one 52-cell city, not a requirement to place every variant.

## ADDED Requirements

### Requirement: Canonical MVP city balance uses the documented start and shared ledger
The campaign-city balance scenario SHALL use the MVP start from project canon: 20 residents with housing for 20, 30 food, 20 wood, 10 iron, and the two-person fighter/ranger party. One turn SHALL represent one day and the scenario SHALL run for 21 turns. Resident food demand SHALL use the ratified 0.1 food per resident per day. The party SHALL have a campaign provision capacity of 10 food, independent of the legacy backpack cap; each of its two members consumes 1 carried food per day. At end turn, if the hero is within a city footprint, the runtime SHALL transfer available city food into carried provisions up to capacity through an attributed city-ledger transaction before the day's ration debit. Resident food demand SHALL be debited from the city ledger once. All city-side resource changes SHALL be traceable in the shared ledger; only `food`, `wood`, and `iron` are construction/economy resources for this MVP. The canonical fixture SHALL record any other assumptions, including group distribution and starting carried provisions.

#### Scenario: Resolve one MVP day
- **WHEN** a day resolves for the canonical city and party
- **THEN** resident food use, party resupply/ration use, building production, and construction costs are applied once in the declared scheduler order
- **AND** every city stock change has an attributable ledger flow
- **AND** no resource outside the MVP mask is used as a campaign price or balance

#### Scenario: Repeat the canonical start
- **WHEN** the same canonical city state and actions are simulated twice
- **THEN** daily resource stocks, party provisions, building state, and ordered ledger flows are identical

#### Scenario: Refill in the city before ration use
- **WHEN** the two-person party starts a turn in a city with 0 carried food and the city has at least 10 food
- **THEN** the scheduler transfers 10 food from city stock to the party through one attributed ledger flow before ration use
- **AND** the party ends that day's ration step with 8 carried food
- **AND** resident demand is debited once from the city separately

#### Scenario: Consume carried rations while away
- **WHEN** the two-person party resolves a day outside every city footprint
- **THEN** it consumes up to 2 food from carried provisions and reports any shortfall
- **AND** no city ledger flow is created for party ration use
- **AND** carried food and city food never become negative

### Requirement: Campaign mode isolates legacy city economy
The runtime SHALL expose a non-persisted campaign-mode switch shared by `CityManager` and `TurnScheduler`, defaulting to legacy mode. In campaign mode, `CityManager` SHALL skip legacy `CityGrowthService` food consumption, growth, and legacy capital inflow; canonical food use SHALL be resolved by the scheduler through the shared `ResourceContext`. Campaign mode SHALL not apply legacy automatic resource yields outside the MVP resource mask. Legacy mode SHALL retain its existing behavior. The mode SHALL NOT change the save schema or serialized city state.

#### Scenario: Resolve a campaign day without legacy double charging
- **WHEN** a campaign-mode turn resolves a city with 20 residents and 30 food
- **THEN** legacy worker food consumption, capital inflow, and legacy automatic yields are skipped
- **AND** the scheduler records canonical resident demand of 2 food once

#### Scenario: Preserve legacy city turns
- **WHEN** a legacy-mode turn resolves
- **THEN** the existing `CityGrowthService` behavior and legacy resource yields remain unchanged

### Requirement: Campaign production is staffed deterministically
Available residents SHALL be assigned to active campaign production recipes without exceeding the city's available workforce or each recipe's worker requirement. Allocation SHALL be deterministic and SHALL prioritize food production needed to meet current demand before wood and iron production; the UI SHALL NOT require a manual worker-assignment action for MVP production. Buildings under construction, inactive, ruined, or without a recipe SHALL receive no production workers.

#### Scenario: Staff a newly completed farm
- **WHEN** available workers exist and a campaign farm is active
- **THEN** workers are assigned up to the recipe requirement and its output is recorded in the shared ledger
- **AND** assigned workers are not simultaneously assigned to another production recipe

#### Scenario: Workforce is insufficient
- **WHEN** active recipes require more workers than the city has available
- **THEN** staffing follows the declared deterministic priority and stable tie-break order
- **AND** partial staffing produces only the catalog-defined proportional output

### Requirement: All catalog costs support a feasible 52-cell MVP plan
Every one of the 98 runtime building definitions SHALL have an explicit campaign-authored construction cost using only registered MVP resources. The balance plan SHALL select, count, and order the buildings needed for the canonical city's food, wood, iron, housing, group services, training, and defense goals; catalog variants not selected for that plan remain buildable options and SHALL NOT be counted as simultaneous requirements. The selected plan SHALL fit within the 52-cell geometry, state cumulative costs and expected outputs, and remain affordable from the canonical start plus its simulated production and explicitly modeled campaign rewards.

#### Scenario: Review the selected build plan
- **WHEN** the balance report is generated
- **THEN** it identifies each selected building, its count, planned construction day, cumulative cost, worker demand, and expected output or service
- **AND** the total footprint does not exceed 52 cells
- **AND** the report distinguishes selected buildings from unselected catalog alternatives

#### Scenario: Construct the plan
- **WHEN** the plan is replayed from the canonical start
- **THEN** no construction is rejected for an unmodeled resource shortage or invalid prerequisite
- **AND** no resource stock becomes negative
- **AND** the day-one farm and barracks milestone remains affordable

### Requirement: Selected MVP plan covers the seven canonical group needs
The selected day-21 city plan SHALL provide 100% runtime coverage for each need represented by the canonical 20-resident group split: brawling 3, education 5, market access 3, religion 3, and treatment 3; food coverage SHALL use the existing resident food-flow result without consuming the stock a second time. The campaign barracks SHALL provide brawling service capacity 3 as an original campaign-authored training-hall effect, because the current runtime catalog otherwise has no brawling provider. The report SHALL include per-group coverage and aggregate service capacities.

#### Scenario: Verify day-21 group services
- **WHEN** the selected 21-day plan is replayed
- **THEN** each canonical group reports 100% coverage for its signature need
- **AND** the brawling capacity comes from the active campaign barracks
- **AND** food coverage reuses the day's resident food result

### Requirement: Price tuning is validated against campaign milestones
Costs SHALL be calibrated against the documented MVP pacing rather than source-game prices: the city begins with 20 residents and the stated stocks, builds its first farm and barracks on day one, encounters the first raid around day seven, and can reach its required city-economy and defense milestones by day 21. The fixed balance itinerary SHALL leave no negative resource stock; after the first raid food SHALL be at or below half of its starting 30 units, and day-21 food SHALL be between zero and two days of forecast demand. For this stationary-home benchmark, forecast demand is 2 food/day for 20 residents plus 2 food/day to replenish the two-person party, making the day-21 ceiling 8 food. The balance report SHALL include daily ending stocks and disclose any existing canon target that the measured runtime cannot satisfy; it SHALL NOT conceal a failed target by changing the starting state or introducing unregistered resources.

#### Scenario: Compare a tuned 21-day run
- **WHEN** a deterministic 21-day run uses the selected plan and tuned costs
- **THEN** the report shows daily food, wood, and iron stock, production, consumption, construction spending, staffing, and raid losses
- **AND** no resource stock is negative; post-raid food is at most 15 units and day-21 food is no more than two days of forecast demand
- **AND** the city reaches the declared build-plan milestones
- **AND** repeating the run produces the same report
