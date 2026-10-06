# Spec Delta

## REMOVED Requirements

### Requirement: Resolve как показатель благополучия
**Reason**: The former per-species Resolve-to-reputation loop defines a separate settlement victory system and conflicts with the campaign's city mood and Sign Prestige.
**Migration**: City well-being is represented by group needs/satisfaction and campaign mood; Sign Prestige and campaign victory remain owned by their canonical systems.

### Requirement: Потребности с числовыми бонусами
**Reason**: Fixed source-specific needs, item names, and Resolve bonuses cannot represent the unified resource/building catalog.
**Migration**: Need definitions and effects are data-driven by economic archetype and registered goods/services.

### Requirement: Голод и перерывы
**Reason**: Source-game hunger thresholds and break timers are not part of the campaign's one-day turn model.
**Migration**: Food consumption and any rest/work-cycle effects use campaign turn units and the canonical economy; no hidden real-time break clock is introduced.

### Requirement: Firekeeper
**Reason**: A source-specific Firekeeper role and species bonus would duplicate campaign roles and introduce an unsupported settlement authority.
**Migration**: Any adapted hearth/fire building effect is a normal building effect; no special species-based Firekeeper bonus is required.

## ADDED Requirements

### Requirement: Group needs are supplied by city goods and services
Each economic archetype SHALL define needs using registered Layer-1 resources, Layer-2 goods, housing, or building services. The city SHALL evaluate whether each need is supplied from current production and available capacity; satisfying a need SHALL affect the group's city satisfaction/mood only through explicit rules.

#### Scenario: Need is supplied
- **WHEN** the city provides a group's declared good or service at the required capacity
- **THEN** the need is recorded as satisfied for the turn
- **AND** its declared satisfaction effect is included in the group's explanation

#### Scenario: Need is not supplied
- **WHEN** the city lacks the good, service, housing, or capacity required by a group
- **THEN** the need is recorded as unmet
- **AND** consumption does not exceed available stock or capacity

#### Scenario: Need references unknown good
- **WHEN** archetype data references an unregistered good or service
- **THEN** content validation reports the archetype and invalid reference
- **AND** no hidden resource is created

### Requirement: Group combinations use explicit deterministic relations
The system SHALL represent synergies and tensions between archetypes as explicit pair rules. Pair rules MAY affect needs, satisfaction, or declared production modifiers; they SHALL NOT silently prohibit an ancestry, resident, or building. The result SHALL be deterministic and explainable.

#### Scenario: Compatible groups coexist
- **WHEN** two groups with a configured positive relation coexist in the city
- **THEN** the configured benefit applies once at its declared scope
- **AND** the player can inspect its source groups and effect

#### Scenario: Tense groups coexist
- **WHEN** two groups with a configured negative relation coexist
- **THEN** the configured cost applies without preventing either group from living or working in the city
- **AND** the player can inspect the cause and a valid mitigating service/building if one exists

#### Scenario: Relation is not configured
- **WHEN** two groups coexist without a pair rule
- **THEN** they receive no implicit synergy, penalty, or RNG-based interaction

### Requirement: City satisfaction does not become a victory currency
Group satisfaction SHALL be a city-state metric used only by declared population, production, or event rules. It SHALL NOT be converted into a separate reputation/score victory meter.

#### Scenario: Satisfaction changes
- **WHEN** a group's needs or configured relations change
- **THEN** its satisfaction is recalculated from current city state
- **AND** the change is recorded as a city effect, not a Sign Prestige transaction
