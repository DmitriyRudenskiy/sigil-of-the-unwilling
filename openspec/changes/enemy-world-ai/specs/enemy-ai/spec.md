---
description: "Requirements for a living world: enemies act on their own turn, pick weighted goals, move by pathfinding, capture villages, fight the hero on contact, regrow over time, and surface threat signals in the UI."
---

## Purpose

Делает картой мир: вражеские стеки ходят собственным ходом, выбирают цели по весам,
идут по пути, захватывают деревни игрока, атакуют героя при контакте, возрождаются
сезонно и сигнализируют об угрозе в UI, создавая постоянное напряжение 4X.

## ADDED Requirements

### Requirement: Enemies act on their own turn
After the player's end-of-turn, each alive hostile stack **MUST** take an enemy turn: select a goal and move (or attack) up to its movement points. Enemy turns **MUST** be deterministic for a given world seed.

#### Scenario: Stack moves toward a goal
- **Given** an alive enemy stack with a reachable goal in aggro range
- **When** the player ends the turn
- **Then** the stack has moved one or more cells toward the goal

#### Scenario: Determinism
- **Given** the same world seed and the same player turns
- **When** the enemy turn runs
- **Then** enemy positions are identical across runs

### Requirement: Enemies pick weighted goals
A stack **MUST** choose its goal from player villages, resource nodes, and the hero within its aggro radius, scored by goal weight over distance, modified by the stack's traits.

#### Scenario: Raider prefers the village
- **Given** a raider stack with a player village and the hero both in range
- **When** it selects a goal
- **Then** it prefers the village (per its weights)

### Requirement: Enemies can capture villages
An enemy stack that reaches a player village **MUST** be able to capture it, flipping ownership to `enemy` and holding position.

#### Scenario: Village falls
- **Given** a player village and an enemy stack that reaches it
- **When** the enemy turn resolves
- **Then** the village's owner is `enemy` and the stack is garrisoned

### Requirement: Combat on contact
An enemy moving onto the hero's cell **MUST** start a battle with the enemy as attacker, using the existing battle flow and result handling.

#### Scenario: Enemy attacks the hero
- **Given** an enemy stack adjacent to the hero that targets the hero
- **When** the enemy turn resolves
- **Then** a battle starts with the enemy as the attacker

### Requirement: Enemy population regrows
Defeated stacks **MUST** be able to respawn (weakened) after a delay, and new stacks **MUST** spawn up to the configured cap, on a seasonal schedule; growth state **MUST** persist through save/load.

#### Scenario: Respawn
- **Given** a defeated stack with a scheduled respawn
- **When** N turns pass
- **Then** a weakened stack appears at the respawn site (within the cap)

### Requirement: The player is informed of enemy movement
The UI **MUST** surface nearby enemy movement (a minimap/marker threat indicator and a status line) so the world feels alive before contact.

#### Scenario: Threat is visible
- **Given** an enemy stack within aggro radius of a player village
- **When** the enemy moves
- **Then** the minimap shows a threat marker and the status line indicates enemy movement
