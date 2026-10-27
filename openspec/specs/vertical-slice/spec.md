# vertical-slice Specification

## Purpose
Вертикальный срез MVP (MVP-scope, 01-core-loop): интеграция всех механик в играбельную 21-ходовую кампанию (proof-of-fun, серый прототип, ~3 сессии). Бит-скрипт 21 хода (1/7/14/17/21), арки (выживание → железо → районы → рейд-проверка), метрики валидации core loop, fail-states. Источник: GDD 01-core-loop, MVP-scope, K-канон (K-M9, K-M10, K-M11, K-R3), решения (Q-M26, Q-M68, Q-M70, Q-M75, Q-M56, D-189, D-190, D-198, Q-M82).
## Requirements
### Requirement: Playable 21-turn campaign
The MVP SHALL be a playable 21-turn campaign (proof-of-fun, graybox, ~3 sessions). The goal SHALL be to prove that the core loop "saw → moved → decided → built → supplied → survived the raid" is fun to play.

#### Scenario: Full campaign
- **WHEN** the player completes the pregame flow
- **THEN** the campaign runs for 21 turns
- **AND** the player can complete all arcs (survival, iron, districts, raid-check)

### Requirement: Bit-script for 21 turns
The MVP SHALL have a bit-script for 21 turns with a skeleton at turns 1/7/14/17/21. Turn 3 "rumor" SHALL be a line of the same bit-schema marked Post-MVP (K-M9). Threat lines SHALL be directives only (K-R3).

#### Scenario: Bit-script skeleton
- **WHEN** the campaign reaches turn 7
- **THEN** the bit-script triggers the first raid (tutorial tier)
- **AND** the threat line is a directive (K-R3)

#### Scenario: Turn 3 rumor is Post-MVP
- **WHEN** the campaign reaches turn 3
- **THEN** the "rumor" line is marked Post-MVP
- **AND** it does not trigger in MVP

### Requirement: Campaign arcs
The campaign SHALL have arcs: 1-6 survival → 7-13 iron (first raid at turn 7) → 14-20 districts and survivors (K-M10: "Veteran" is a status of a surviving fighter, not a unit or tier — Q-M56→(а), D-189) → turn 21 large raid-check.

#### Scenario: Veteran status
- **WHEN** a fighter survives a battle
- **THEN** the fighter gains the "Veteran" status
- **AND** the status is not a unit or tier (K-M10)

### Requirement: Core loop validation metrics
The MVP SHALL track core loop validation metrics (01-core-loop): TTFD <= 30s, action rate 8-15/5min, decision share >= 60%, loop closure >= 70%, aha-moment <= 10min, session 35-50min, D1 35%+, D7 15%+.

#### Scenario: TTFD metric
- **WHEN** the player starts the campaign
- **THEN** the time to first meaningful action is tracked
- **AND** the goal is <= 30 seconds

### Requirement: Core loop fail states
The MVP SHALL handle core loop fail states (01-core-loop): party starvation (1 food/character/move, capacity 10 food; Q-M70→(а), Q-M75→(б)); total party death SHALL be the only campaign end (Q-M68→(а), D-190).

#### Scenario: Party starvation
- **WHEN** the party is on an expedition without food
- **THEN** the party starves (1 food/character/move)
- **AND** hunger applies -2 to attacks and save steps (P-4, R7)

#### Scenario: Total party death
- **WHEN** all party members die
- **THEN** the campaign ends
- **AND** this is the only campaign end (Q-M68→(а), D-190)

### Requirement: Turn structure
One turn SHALL equal one season equal to 20 days (Q-M26). The campaign SHALL be 21 turns equal to 420 days. The tick SHALL be a subdivision of the day (1 day = 4 ticks [proposal Q6] => 80 ticks/turn), not visible to the player.

#### Scenario: Turn duration
- **WHEN** the campaign advances one turn
- **THEN** 20 days pass
- **AND** the season changes (season_index = (turn - 1) % 4)

