# pregame-flow Specification (Delta)

## Purpose

Канон предыгрового потока post-pivot (00-overview «Предыгровой поток (Q18) [КАНОН, автор 2026-10-02]»): 6 шагов до хода 1 — конструктор → знак → земной шар → города → партия → тренировка. Источник: GDD 00-overview, 01-core-loop, 02-mechanics §3.1–3.3, 02c (знаки), 02d (классы), MVP-scope (Расы, Предыгра), K-канон (K-T7, K-M5, K-A6), решения (Q18, D12, Q-M32, C-14, C-15).

## ADDED Requirements

### Requirement: Pregame flow before turn 1
The pregame flow SHALL occur before turn 1 and SHALL consist of 6 steps: constructor → sign → globe → cities → party → training (Q18, author 2026-10-02).

#### Scenario: Pregame sequence
- **WHEN** the player starts a new campaign
- **THEN** the steps are presented in order: constructor, sign, globe, cities, party, training
- **AND** turn 1 does not start until all steps are complete

### Requirement: Step 1 - Constructor
The constructor SHALL let the player create the protagonist: class, race, appearance (02d-classes-skills). The playable slice SHALL be 3 cultures (humans, half-orcs, elves) per K-M5 revision and owner decision 2026-10-04 (C-15).

#### Scenario: Constructor race selection
- **WHEN** the player opens the constructor
- **THEN** only humans, half-orcs, and elves are selectable
- **AND** the other catalog races are hidden or marked 1.0

### Requirement: Step 2 - Sign
The protagonist SHALL become the Bearer (the Unwilling). The sign SHALL be chosen from 8 for the whole game (not per campaign) (02c, §3.7).

#### Scenario: Sign choice for whole game
- **WHEN** the player chooses a sign
- **THEN** the sign persists for the whole game
- **AND** the protagonist is marked as the Bearer

### Requirement: Step 3 - Globe
The globe SHALL show an open world with regions and cities (region graph, K-T7 — region-graph-map).

#### Scenario: Globe display
- **WHEN** the player reaches the globe step
- **THEN** the region graph is displayed
- **AND** the player can see regions and cities

### Requirement: Step 4 - Cities
The player SHALL be able to select any number of cities. For each city after the second, an increasing occupation penalty SHALL apply (curve — TBD, 02-mechanics §3.1).

#### Scenario: Occupation penalty
- **WHEN** the player selects a third city
- **THEN** an occupation penalty is applied
- **AND** the penalty increases with each additional city

### Requirement: Step 5 - Party
The party SHALL have up to 5 companions. Each companion SHALL have their own class, race, and appearance (§3.2).

#### Scenario: Companion creation
- **WHEN** the player creates a companion
- **THEN** the companion has a class, race, and appearance
- **AND** the party size does not exceed 5

### Requirement: Step 6 - Training
The city SHALL be a training base for the team. Sources SHALL be: people from the city, companions, NPCs from events. Companions SHALL be trained, not hired (the hiring model 02 §3.3 is displaced, Q18).

#### Scenario: Training not hiring
- **WHEN** the player adds a companion to the party
- **THEN** the companion is trained (not hired)
- **AND** the hiring market is not used
