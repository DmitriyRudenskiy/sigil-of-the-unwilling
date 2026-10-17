# signs-prestige Specification (Delta)

## Purpose

Канон знаков и Престижа post-pivot (02-mechanics §3.7, 02c): 8 знаков, выбор из 8 на всю игру (Q18, D12), Престиж как единое число (ledger, K-M16, K-D5), ранги (пороги 0/200/500/1000/2000), SM знака, косметика (S2). Источник: GDD 02-mechanics §3.7, 02c (знаки), MVP-scope (Знак), K-канон (K-D5, K-M16, K-M9), решения (Q18, D12, Q-M32, S2, S3, R1, K-M11).

## ADDED Requirements

### Requirement: Eight signs, one per game
There SHALL be 8 signs (spark, time, balance, primal, shadow, harmony, cycle, basis). The player SHALL choose 1 sign from the 8 at the start, for the whole game (Q18, D12). All 8 signs SHALL be playable in MVP (Q-M32). The protagonist SHALL be the bearer (R1).

#### Scenario: Sign choice
- **WHEN** the player starts a new campaign
- **THEN** all 8 signs are selectable
- **AND** the chosen sign persists for the whole campaign

### Requirement: Prestige is a single ledger number
Prestige SHALL be a single number, managed as a ledger (K-M16, K-D5: no score). Universal grants/penalties and sign faction actions (<= 12 per campaign) SHALL modify the ledger. Style penalty SHALL apply only for repeats. Losses SHALL NOT be penalized. Tactical retreats SHALL NOT be penalized.

#### Scenario: Faction action limit
- **WHEN** the player performs the 13th faction action
- **THEN** no prestige is granted
- **AND** the UI shows "0 remaining"

#### Scenario: No penalty for loss
- **WHEN** the player loses a battle
- **THEN** no prestige is deducted
- **AND** the ledger is unchanged by the loss itself

### Requirement: Prestige ranks
Prestige ranks SHALL use thresholds 0/200/500/1000/2000 (5 ranks: "Nameless", "Known", "Honored", "Glorious", "Legendary"). The 6-rank scale (0/500/1500/3500/7000/12000) SHALL be deprecated (K-D5/K-M16). Dropping below a threshold SHALL demote the rank.

#### Scenario: Rank promotion
- **WHEN** prestige reaches 500
- **THEN** the rank becomes "Honored"
- **AND** the title is displayed in the UI

#### Scenario: Rank demotion
- **WHEN** prestige drops below 500
- **THEN** the rank reverts to "Known"
- **AND** the title is updated

### Requirement: Campaign prestige anchor
The campaign anchor SHALL be: turn 21 = "Honored" (500-999), upper bound touching "Glorious" (1000).

#### Scenario: Anchor at turn 21
- **WHEN** the campaign reaches turn 21 with balanced play
- **THEN** the player's prestige is in the 500-999 range
- **AND** the rank is "Honored"

### Requirement: Prestige is cosmetic
Prestige SHALL be purely cosmetic (S2): no population inflow. Rank rewards SHALL be titles and cosmetics only.

#### Scenario: No population inflow
- **WHEN** the player reaches the "Glorious" rank
- **THEN** no population is added to the city
- **AND** the only reward is the title/cosmetics

### Requirement: Sign state machine
A sign SHALL follow the state machine DORMANT → ACTIVE (choice) → SLEEPING (prestige <= 0) → ACTIVE (prestige > 0). TRIAL SHALL be Post-MVP (1.0: 8 trials, +250).

#### Scenario: Sign sleeps
- **WHEN** prestige drops to 0 or below
- **THEN** the sign enters SLEEPING
- **AND** the campaign does not end (not game over)

#### Scenario: Sign wakes
- **WHEN** prestige rises above 0 while the sign is SLEEPING
- **THEN** the sign returns to ACTIVE
- **AND** faction actions are available again

### Requirement: One sign per bearer
There SHALL be exactly one sign per bearer (invariant). Sign loss SHALL only occur by death. In MVP, there is no sign transfer; the bearer's death does not end the campaign (the party gains a "loss", -2 to saves, K-M11).

#### Scenario: Bearer death
- **WHEN** the sign bearer dies
- **THEN** the sign is lost (no transfer in MVP)
- **AND** the campaign continues with the "loss" penalty
