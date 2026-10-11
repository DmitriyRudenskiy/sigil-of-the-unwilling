# Spec Delta

## REMOVED Requirements

### Requirement: Уровни города 1–11
**Reason**: Campaign canon explicitly has no city levels; administrative buildings determine limits. The 1–11 city-level track is a legacy model.
**Migration**: Remove city-level state and gates from campaign-city progression; existing saves/data are migrated or defaulted without inventing a level.

### Requirement: Расписание открытия зданий
**Reason**: Building availability cannot depend on the removed city-level track.
**Migration**: Use explicit building prerequisites and administrative capacity declared in the canonical catalog and campaign scenario.

### Requirement: Военные здания определяют типы найма
**Reason**: The old requirement binds recruitment to an obsolete city level and a legacy class/upgrade roster.
**Migration**: Military buildings expose only approved campaign class-training actions through explicit infrastructure prerequisites and existing party-capacity rules; no source-game or legacy generic troop is created.

### Requirement: Наём добавляет юнит в армию героя
**Reason**: The direct generic-stack transaction conflicts with the canonical class-based character/party model.
**Migration**: Replace it with approved class-based character training through the campaign party pipeline; do not create a parallel city/army pool.

### Requirement: Тиры оружия
**Reason**: City-level-derived wood/iron/magic tiers and percentage jumps are legacy progression, not part of the current campaign canon.
**Migration**: Equipment and character capabilities use registered goods, the approved campaign classes, and explicit building/technology data; do not infer tiers from city levels.

## ADDED Requirements

### Requirement: Building unlocks use explicit prerequisites, not city levels
A campaign building SHALL be available when all declared prerequisites are met: required registered resources, prerequisite buildings/roles, scenario flags, and administrative capacity where applicable. No building SHALL require a city level from 1 to 11.

#### Scenario: All prerequisites met
- **WHEN** the city satisfies every declared building prerequisite and has room/capacity
- **THEN** the building becomes available
- **AND** the UI lists the satisfied conditions

#### Scenario: Prerequisite missing
- **WHEN** one or more declared prerequisites are unmet
- **THEN** the building remains unavailable
- **AND** the player sees the exact unmet prerequisite without resource loss

### Requirement: Character training is capacity- and data-gated
A military building SHALL offer only training actions explicitly linked to an approved campaign character class. Training SHALL check registered costs, declared infrastructure, and existing party/capacity limits before any stock is deducted. It SHALL use the canonical character/party pipeline, not the legacy generic UnitRegistry roster.

#### Scenario: Valid training
- **WHEN** the class-training action is unlocked and all costs, prerequisites, and party-capacity requirements are met
- **THEN** the canonical campaign character/party pipeline completes the action and costs are committed atomically

#### Scenario: Training unavailable
- **WHEN** the class is not approved, its prerequisite is missing, or capacity is full
- **THEN** training is rejected with a specific reason
- **AND** city stocks and party members remain unchanged

### Requirement: Administrative buildings set city capacity
Where a limit is required, it SHALL come from the existing campaign party/capacity rules or an explicit administrative building/scenario rule, never from a city level. Capacity SHALL be visible; changes SHALL not delete existing buildings or characters.

#### Scenario: Capacity reached
- **WHEN** an action would exceed a declared capacity
- **THEN** the action is blocked before costs are deducted
- **AND** the UI identifies the capacity source and available limit

#### Scenario: Capacity source is disabled
- **WHEN** the administrative building granting capacity becomes inactive
- **THEN** existing entities remain intact
- **AND** new actions exceeding the reduced capacity are blocked
