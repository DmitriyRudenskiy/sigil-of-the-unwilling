# raid-pressure-system Specification

## Purpose

Канон рейдов post-pivot (02-mechanics §3.8): функция давления (K-T5/K-R3) вместо календаря, тиры, SM рейда, директивы (первый ≈ ход 7, финальный к ходу 21), per-ресурсные капы (Q-M58→(в)), цель (видимость/уязвимость), сезоны (Q-M27/Q-M29). Источник: GDD 02-mechanics §3.8, 02e4 §13.2, MVP-scope (Рейды), K-канон (K-T5, K-R3, K-M9, K-M4), решения (R5, R6, Q-M54, Q-M58, D-189, D-190, T-127).

## Requirements

### Requirement: Raids are pressure-driven, not calendar-based
Raids SHALL NOT use a calendar (K-T5). A raid SHALL trigger when the pressure accumulator crosses a tier threshold.

#### Scenario: Pressure crosses threshold
- **WHEN** the pressure accumulator reaches 30 (light tier)
- **THEN** a light raid is triggered
- **AND** no calendar date is involved

### Requirement: Pressure function
The pressure function (02e4 §13.2, K-R3) SHALL be: `Base(city) = 4.0`; `Wealth = clamp(1 + 0.005 * stock, 0.5, 2.0)`; anomaly (hook, MVP = 1.0); region growth after cooldown `1 + 0.05 * turns`; global phases {1: 1.0, 2: 1.25, 3: 1.5, 21: 2.0}.

#### Scenario: Wealth factor
- **WHEN** the city's total stock is 200
- **THEN** the wealth factor is clamp(1 + 0.005 * 200, 0.5, 2.0) = 2.0
- **AND** pressure grows faster

### Requirement: Raid tiers
There SHALL be 3 tiers (K-T5) with thresholds 30/100/250 and power 15/30/60 (R6). Defense SHALL be 0.2 with a built barracks, otherwise 0 (R6). Loss SHALL be `power * (1 - defense)`.

#### Scenario: Light raid loss
- **WHEN** a light raid (power 15) hits a city without barracks
- **THEN** the loss is 15 * (1 - 0) = 15 units of the target resource
- **AND** the target resource is reduced

#### Scenario: Barracks defense
- **WHEN** a light raid (power 15) hits a city with barracks
- **THEN** the loss is 15 * (1 - 0.2) = 12 units
- **AND** the defense is applied

### Requirement: Raid state machine
A raid SHALL follow the state machine IDLE → CHARGING → INBOUND (arrival in N turns) → STRIKE → RESOLVED → COOLDOWN (3 turns) → IDLE.

#### Scenario: Cooldown
- **WHEN** a raid is resolved
- **THEN** the raid enters COOLDOWN for 3 turns
- **AND** no new raid can trigger during cooldown

### Requirement: Raid directives
The first raid SHALL occur at approximately turn 7 (floor, tutorial tier). The final raid SHALL occur by turn 21 (floor, tier 3). Floor directives SHALL NOT be broken by "all districts destroyed" (cooldown x2 instead) (K-R3).

#### Scenario: First raid at turn 7
- **WHEN** the campaign reaches turn 7
- **THEN** the first raid is triggered (floor directive)
- **AND** the raid is tutorial-tier (light)

#### Scenario: Final raid at turn 21
- **WHEN** the campaign reaches turn 21
- **THEN** the final raid is triggered (floor directive, tier 3)
- **AND** the raid is the boss raid (CR 6-8) if the hero is in the city

### Requirement: Per-resource caps per raid
Raid losses SHALL be capped per resource per raid within a turn: food <= 40%, iron/weapons <= 30% (Q-M58→(в), D-189). [Code divergence: unified 0.3 — T-127.]

#### Scenario: Food cap
- **WHEN** a raid targets food and the computed loss exceeds 40% of the food stock
- **THEN** the loss is capped at 40% of the food stock
- **AND** the cap is applied per raid, not per turn

### Requirement: Raid target selection
The raid target SHALL be selected by `score = 0.5 * visibility + 0.3 * vulnerability`. Visibility in MVP SHALL be the constant 1 (Q-M54→(в)). Tiebreak SHALL be by lower id (determinism). In MVP, the target SHALL be a random choice from 3 resources (weights 0.5/0.3/0.2).

#### Scenario: Target tiebreak
- **WHEN** two resources have the same score
- **THEN** the one with the lower id is selected
- **AND** the selection is deterministic

### Requirement: Seasons affect raids
There SHALL be 4 seasons with `season_index = (turn - 1) % 4` and turn 1 = spring (Q-M27/Q-M29). Winter SHALL be every 4th turn (4/8/12/16/20). `production_mult` SHALL be {spring 1.0, summer 1.2, autumn 1.0, winter 0.4}. `enemy_mult` in winter SHALL be 1.25.

#### Scenario: Winter enemy boost
- **WHEN** a raid occurs in winter (turn 4, 8, 12, 16, 20)
- **THEN** the enemy multiplier is 1.25
- **AND** the raid is stronger

### Requirement: Hero in city triggers battle
If the hero is in the city when a raid strikes, a battle SHALL occur (CR 1/2/6). If the hero is on an expedition, an auto-raid SHALL occur (defense = buildings 13.3).

#### Scenario: Hero in city
- **WHEN** a raid strikes and the hero is in the city
- **THEN** a battle occurs (CR based on tier)
- **AND** the raid is not auto-resolved

#### Scenario: Hero away
- **WHEN** a raid strikes and the hero is on an expedition
- **THEN** an auto-raid occurs
- **AND** defense is computed from buildings (13.3)

### Requirement: Fail states and edge cases
AFK cascade SHALL be prevented by per-raid caps (no chain collapse). If all districts are destroyed, the city SHALL survive: production -50%, raid frequency -50% (cooldown x2). A raid on a building under repair SHALL apply x0.5 to the RUINED district. A raid on the hero's cell SHALL trigger a battle; victory reduces consequences by 50%.

#### Scenario: All districts destroyed
- **WHEN** all districts are destroyed by raids
- **THEN** the city survives
- **AND** production is reduced by 50% and raid frequency by 50% (cooldown x2)

#### Scenario: Raid on hero cell
- **WHEN** a raid targets the cell the hero occupies
- **THEN** a battle occurs
- **AND** if the hero wins, raid consequences are reduced by 50%
