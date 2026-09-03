---
description: "Requirements for the macro level: the world as a shard, an astral-sea meta-map, travel between shards, shard completion, AI factions with goals and war/truce, and a legend that spans shards."
---

## ADDED Requirements

### Requirement: The world is a shard
The current world (map, cities, hero, enemy state) **MUST** be encapsulated as a shard instance; the existing game **MUST** behave identically as shard #1.

#### Scenario: No behavior change
- **Given** the current game as shard #1
- **When** it is bootstrapped through the shard layer
- **Then** gameplay is identical to the pre-abstraction game

#### Scenario: A second shard loads
- **Given** a defined shard #2 (different seed/biome mix)
- **When** it is loaded
- **Then** its world matches its seed and its cities/enemies are independent of shard #1

### Requirement: The astral sea maps the shards
A meta-screen **MUST** show shards as nodes and routes between them, with unlocked/locked state.

#### Scenario: Sea is visible
- **Given** at least one route exists
- **When** the player opens «Астральное море»
- **Then** the shards and routes are shown with their lock state

### Requirement: Travel between shards
The player **MUST** be able to travel along an unlocked route (paying cost and starting a cooldown), arriving at the destination shard's entry cell with existing forces.

#### Scenario: Travel preserves forces
- **Given** the player's hero and army on shard #1
- **When** the player travels to shard #2
- **Then** the hero and army appear at shard #2's entry cell

#### Scenario: Locked routes are unavailable
- **Given** a locked route
- **When** the player selects it
- **Then** travel is refused

### Requirement: Shards can be completed
A shard **MUST** be completed by its local victory condition; completion **MUST** unlock the shard's outbound routes without necessarily ending the run.

#### Scenario: Complete a shard
- **Given** shard #1's local victory condition is met
- **When** it resolves
- **Then** shard #1 is marked completed and its outbound routes unlock, while the run continues

### Requirement: Factions exist on shards
AI factions **MUST** exist on shards with a goal and a war/truce state, and their state **MUST** be visible in the UI.

#### Scenario: Factions differ
- **Given** two factions with different archetypes
- **When** they act over turns
- **Then** their behavior reflects their respective goals

#### Scenario: State is visible
- **Given** a faction at war
- **When** the player opens the faction panel
- **Then** its name, goal, and war/truce state are shown

### Requirement: The legend spans shards
Glory, the chronicle, and inherited state (sigil, path) **MUST** persist across shards and across succession.

#### Scenario: Cross-shard memory
- **Given** glory and chronicle entries accumulated on shard #1
- **When** the player travels to shard #2 (or succeeds)
- **Then** the glory and chronicle entries are still present
