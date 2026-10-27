# dnd-battle-ladder Specification (Delta)

## Purpose

Канон боевой системы post-pivot: D&D без кубиков, лестничное разрешение (K-T6), Удача как 7-я характеристика, death saves, SM боя, лимит 20 раундов (D-128), авто-режим, AI врага (Y3), состояния (prone/высотный, K-M7), blink (K-M7 — **отложен вне MVP, D-222: позиционных зон/клеток/координат нет**), местность 3 типа (C3), бином «Фланг» (по цели, не по позиции), мораль аннулирована (K-M11), детерминизм (K2). Источник: GDD 02-mechanics §3.4, 02b (биномы/местность), 02d (лестница, Удача), MVP-scope (Бой).

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
Enemy AI SHALL be greedy (minimum HP in radius, tiebreak by lower id), and the turn-21 boss SHALL add exactly two abilities to that policy (D-218, owner verdict 2026-10-20; no positional zones, D-222). All ability parameters SHALL be data-driven (balance config), no RNG.

#### Scenario: Greedy target selection
- **WHEN** the enemy AI picks a target
- **THEN** it attacks the lowest-HP character within its radius
- **AND** ties are broken by the lower id
- **AND** no positional zone or coordinate is consulted (D-222)

#### Scenario: Ability parameters come from the balance config
- **WHEN** the balance config changes a boss damage multiplier or cooldown
- **THEN** the boss behavior follows the config without a code change

#### Scenario: Boss powerful strike
- **WHEN** the boss acts and its powerful-strike cooldown is 0
- **THEN** the strike deals base damage × 1.5 to its deterministic target
- **AND** the cooldown is set to 2 turns
- **AND** the strike is telegraphed in the battle trace (`boss_powerful`)

#### Scenario: Boss rage phase
- **WHEN** the boss's HP drops to ≤ 50% of its max HP
- **THEN** the rage phase activates once
- **AND** the boss's damage is multiplied by 1.25 for the rest of the battle
- **AND** the activation is recorded in the battle trace (`boss_rage`)

### Requirement: Enemy stats visible
Enemy stats (AC, HP, luck, abilities) SHALL be visible to the player at all times (M1).

#### Scenario: Enemy card
- **WHEN** the player opens the enemy card
- **THEN** AC, HP, luck, and abilities are displayed
- **AND** the card is always accessible during battle

### Requirement: States and terrain
States SHALL include prone (-2/+2) and elevation (flight, K-M7). Terrain SHALL provide 3 types (swamp, spikes, height, C3) as abstract modifiers, without a hex grid. The "Flank" binom (fighter + ranger) SHALL be active from turn 1, SHALL be keyed by shared target, and SHALL remain the only MVP binom (D-222).

#### Scenario: Prone penalty
- **WHEN** a character is prone
- **THEN** the character gets -2 to attacks and +2 to attacks against it
- **AND** the state is visible in the UI

#### Scenario: Terrain is an abstract modifier
- **WHEN** a combatant is affected by swamp, spikes or height terrain
- **THEN** the ±2 margin modifiers apply to the attack resolution
- **AND** no hex coordinates, cells or zones are read (D-222)

#### Scenario: Blink is out of MVP
- **WHEN** the ladder runs a battle
- **THEN** no Blink ability is available to any combatant
- **AND** the battle state exposes no grid, cells or coordinates (D-222)
- **AND** reintroducing Blink requires a separate change with a positioning system

#### Scenario: Flank binom
- **WHEN** a fighter and a ranger attack the same enemy in the same round (position-free, D-222)
- **THEN** the "Flank" binom is active
- **AND** the second attack against that target gets its +2 margin bonus

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
