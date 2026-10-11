# Spec Delta

## Purpose

Defines campaign-specific city progression from level 1 through 11, using each level to unlock occupied building cells in the fixed 52-cell city. It does not restore the legacy military tech tree, source-game currencies, or city-size expansion.

## ADDED Requirements

### Requirement: Campaign city levels gate occupied city cells
A campaign city SHALL use its persisted city level from 1 through 11. The maximum occupied-cell allowance by level SHALL be `[4, 9, 14, 19, 24, 29, 34, 39, 44, 48, 52]`. The four cells of the city core count as occupied, as do all unique cells occupied by buildings, boroughs, free starting housing, and buildings under construction; a ruined structure continues to count while its footprint remains occupied. Units, workers, roads, and other non-building markers SHALL NOT consume the allowance. A multi-cell building SHALL consume one allowance slot per footprint cell. A construction request that would exceed the current allowance SHALL be rejected before resource deduction or state mutation. At levels 1–10, the city SHALL NOT occupy all 52 cells; level 11 permits at most 52 occupied cells, still subject to normal placement rules.

#### Scenario: Enforce the current-level building-cell allowance
- **WHEN** a construction request would occupy more cells than the current level's remaining allowance
- **THEN** the request is rejected with the current level, used cells, and limit
- **AND** no resources, ledger entries, building records, or occupied cells change

#### Scenario: Count starting and in-progress buildings
- **WHEN** the city has its four-cell core, free starting housing, and a building under construction
- **THEN** each unique occupied city cell counts toward the allowance exactly once
- **AND** construction progress does not temporarily free a slot

#### Scenario: Reach the full city only at level 11
- **WHEN** the city is below level 11
- **THEN** its level allowance is less than 52 cells
- **AND** only a level-11 city can use all 52 occupied city cells

### Requirement: Campaign level-up follows filled construction allowance
A campaign city SHALL advance by one level only when its occupied city cells equal or exceed its current-level allowance. Level 11 SHALL be the maximum. Leveling SHALL not spend a new resource or currency; the occupied-cell milestones are the progression cost. Campaign city levels SHALL gate construction capacity only, not unlock individual building definitions, character classes, weapon tiers, or legacy troop rosters. The existing legacy city-level rules SHALL remain unchanged.

#### Scenario: Advance after filling the allowance
- **WHEN** a campaign city below level 11 has occupied at least every cell allowed at its current level and requests a level-up
- **THEN** its level increases by exactly one
- **AND** its new occupied-cell allowance is displayed

#### Scenario: Level-up is blocked before the allowance is filled
- **WHEN** a campaign city has fewer occupied city cells than its current-level allowance
- **THEN** level-up is rejected with the missing cell count
- **AND** the city level and all other state remain unchanged

#### Scenario: Level 11 is the cap
- **WHEN** a campaign city is already level 11
- **THEN** level-up is rejected as maximum level
- **AND** the allowance remains 52 cells
