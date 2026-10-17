# dnd-battle-ladder Specification (Delta)

## Purpose

Канон боевой системы post-pivot: D&D без кубиков, лестничное разрешение (K-T6), Удача как 7-я характеристика, death saves, SM боя, лимит 20 раундов (D-128), авто-режим, AI врага (Y3), состояния (prone/высотный, K-M7), blink (K-M7), местность 3 типа (C3), бином «Фланг», мораль аннулирована (K-M11), детерминизм (K2). Источник: GDD 02-mechanics §3.4, 02b (биномы/местность), 02d (лестница, Удача), MVP-scope (Бой).

## ADDED Requirements

### Requirement: Ladder resolution without dice
Combat SHALL be resolved by a ladder, not dice (K2, K-T6). Result SHALL be `mod(effective attribute) + rank bonus + situational`. Margin SHALL be `Result - DC`. The "10 + proficiency" formula SHALL NOT be used (K-T6). Ladder zones SHALL be: Triumph (>= 4 - modLuck, min +1), Success (>= 0), Partial (>= -(3 + modLuck)), Failure, Critical Failure (<= -(8 + modLuck)). In battle: Triumph = damage x2, Partial = half damage, Failure = miss, Critical Failure = fumble.

#### Scenario: Triumph doubles damage
- **WHEN** the margin is >= 4 - modLuck
- **THEN** the zone is Triumph
- **AND** damage is doubled

#### Scenario: No proficiency bonus
- **WHEN** a level 5 character attacks
- **THEN** the result does not include a proficiency bonus
- **AND** the result is mod(effective attribute) + rank bonus + situational

### Requirement: Luck as the 7th attribute
Luck SHALL be the 7th attribute with a pool of OU = 1 + modLuck. Fate Shift (1 OU) SHALL shift the result one zone up. Save (2 OU) SHALL convert a Critical Failure to Failure. The debt of fate (K-R1) SHALL apply when the pool is exhausted.

#### Scenario: Fate Shift
- **WHEN** a player spends 1 OU on Fate Shift
- **AND** the current zone is Success
- **THEN** the zone becomes Triumph
- **AND** the OU pool decreases by 1

#### Scenario: Debt of fate
- **WHEN** the OU pool is exhausted and the player requests a Fate Shift
- **THEN** the request is denied
- **AND** a debt of fate is recorded (K-R1)

### Requirement: Damage and AC
Damage SHALL be the die average plus the relevant modifier. AC SHALL be `10 + armor + mod(DEX)`.

#### Scenario: Damage calculation
- **WHEN** a fighter with STR mod +3 hits with a longsword (average 7)
- **THEN** the damage is 10
- **AND** the target's HP decreases by 10

### Requirement: Death saves
Death saves SHALL use `margin_N = mod(effective CON) + (supply, only N=1) - (N-1)` (Q-M57→(а)). Three failures SHALL mean death; three successes SHALL mean WOUNDED.

#### Scenario: Death save failure
- **WHEN** a fallen character fails 3 death saves
- **THEN** the character dies
- **AND** the death is final for the campaign

### Requirement: Battle state machine
A battle SHALL follow the state machine SETUP → ROUND → VICTORY/DEFEAT/RETREAT → REPORT. Initiative SHALL be `mod(DEX)`, tiebreak by CON, then id.

#### Scenario: Initiative tiebreak
- **WHEN** two combatants have the same DEX modifier
- **THEN** the one with higher CON acts first
- **AND** if CON is also equal, the lower id acts first

### Requirement: Battle round cap
A battle SHALL end in a draw after 20 rounds (D-128). Losses SHALL be recorded; no XP or prestige SHALL be granted for a draw.

#### Scenario: Round cap reached
- **WHEN** the battle reaches round 20 without a winner
- **THEN** the battle ends in a draw
- **AND** no XP or prestige is granted

### Requirement: Auto mode
Auto mode SHALL use the same engine as manual mode with a deterministic AI (minimum HP in radius). Auto mode SHALL retreat when "frightened". Both modes SHALL produce a single report.

#### Scenario: Auto mode retreat
- **WHEN** the auto-mode character is "frightened"
- **THEN** the character retreats
- **AND** the battle ends with a DEFEAT or RETREAT outcome

### Requirement: Enemy AI
Enemy AI SHALL be greedy (minimum HP in radius, tiebreak by lower id). The turn-21 boss SHALL be greedy plus a special ability when the party's HP is below 50%.

#### Scenario: Boss special ability
- **WHEN** the turn-21 boss detects the party's HP below 50%
- **THEN** the boss uses its special ability
- **AND** the ability is deterministic (no RNG)

### Requirement: Enemy stats visible
Enemy stats (AC, HP, luck, abilities) SHALL be visible to the player at all times (M1).

#### Scenario: Enemy card
- **WHEN** the player opens the enemy card
- **THEN** AC, HP, luck, and abilities are displayed
- **AND** the card is always accessible during battle

### Requirement: States and terrain
States SHALL include prone (-2/+2) and elevation status (flight, K-M7). Blink (K-M7, wizard spell from cells) SHALL be available in MVP. Terrain SHALL have 3 types (swamp, spikes, height, C3). The binom "Flank" (fighter + ranger) SHALL be active from turn 1 and is the only MVP binom.

#### Scenario: Prone penalty
- **WHEN** a character is prone
- **THEN** the character gets -2 to attacks and +2 to attacks against it
- **AND** the state is visible in the UI

#### Scenario: Flank binom
- **WHEN** a fighter and a ranger are adjacent to the same enemy
- **THEN** the "Flank" binom is active
- **AND** the binom grants its bonus

### Requirement: Morale is deprecated
The morale scale (0-100) SHALL NOT exist (K-M11). Losses SHALL grant -2 steps to saves until the end of the battle. Forced retreat SHALL occur at 0 hit dice.

#### Scenario: Loss penalty
- **WHEN** a party member dies in battle
- **THEN** the remaining party gets -2 steps to saves
- **AND** the penalty lasts until the end of the battle

### Requirement: Deterministic combat
Combat resolution SHALL be deterministic (K2): no RNG in resolution. Replays SHALL be byte-identical.

#### Scenario: Replay equivalence
- **WHEN** the same battle inputs are replayed 100 times
- **THEN** all 100 runs produce identical outcomes
- **AND** no run diverges at any round
