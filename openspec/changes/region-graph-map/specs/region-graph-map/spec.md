# region-graph-map Specification (Delta)

## Purpose

Канон карты кампании: граф регионов (K-T7) вместо hex-мира, узлы как атрибуты регионов, туман, движение по переходам (K-M4), SM героя, инвариант доходимости якорей. Источник: GDD 02-mechanics §3.1, 00-overview (K-T7, K-R4, K-M4), MVP-scope (Карта), решения (Q-M54, D-191, Y4, Y10, C3).

## ADDED Requirements

### Requirement: Region graph is the campaign map
The campaign map SHALL be a graph G(V,E) of regions (K-T7). The base campaign map SHALL be a fixed graph of 40-48 regions (MAP-1). The MVP SHALL use a connected subgraph of 5-8 regions (K-R4) selected by an explicit MVP mask that is the single source of truth.

#### Scenario: MVP mask selection
- **WHEN** a new campaign starts in MVP
- **THEN** only the regions in the MVP mask are playable
- **AND** the subgraph is connected and contains the starting region

### Requirement: Region biomes
Each region SHALL have exactly one biome. The MVP SHALL have 2 regular biomes (plain, forest) plus 1 boss biome (special content, out of count); mountains are 1.0 (K-M2). `terrain_preference` SHALL be a hard generation constraint for nodes in MVP.

#### Scenario: Biome constraint on node
- **WHEN** a node with `terrain_preference = forest` is placed
- **THEN** it is placed only in a forest region
- **AND** the constraint is enforced by the generator, not by post-hoc filtering

### Requirement: Campaign nodes
The MVP SHALL contain 5 nodes (2 ruins, 1 ore, 2 camps CR 1/2) plus 1 player city plus 2-3 neutral settlements (post-MVP). A node SHALL be an attribute of a region (K-T7 Ф5а), not a separate map layer. Node loot SHALL be one-time (Y4): ruins give 10 wood + 5 iron + 300-500 XP; ore gives 20 iron + 300 XP; camps give 5 food + 10 iron + 400-600 XP.

#### Scenario: One-time node loot
- **WHEN** the hero clears a ruin for the second time
- **THEN** no loot and no XP are granted
- **AND** the node is marked visited in the save

### Requirement: Fog of war
Unexplored regions SHALL NOT be visible (fog). The exploration radius in MVP SHALL be the constant 1 (Q-M54→(а)). The player's own city SHALL always be visible regardless of fog.

#### Scenario: Fog reveals on visit
- **WHEN** the hero enters a region
- **THEN** that region and all regions within radius 1 become visible
- **AND** previously unexplored regions beyond radius 1 remain hidden

### Requirement: Movement by transitions
Hero movement SHALL be measured in transitions (edge traversals), not hex steps (D-191). Transition speed SHALL be computed as `biome + DEX − weight` (K-M4, ratified). Food SHALL be consumed per transition: 1 food per character per transition (R7, Q-M75→(б)); carried capacity is 10 food. Reachability of anchors at turns 7/14/21 SHALL be guaranteed by an auto-balancer (K-M4).

#### Scenario: Food consumed per transition
- **WHEN** a party of 2 makes 5 transitions
- **THEN** 10 food are consumed (1 per character per transition)
- **AND** the party's carried food drops from full (10) to 0

#### Scenario: Reachability invariant
- **WHEN** the auto-balancer validates the MVP mask
- **THEN** the anchor regions for turns 7, 14, 21 are reachable within the player's movement budget
- **AND** if not, the balancer adjusts node placement, not the player's speed

### Requirement: Hero state machine
The hero SHALL follow the state machine EXPLORE → ENGAGE → BATTLE → VICTORY/DEFEAT → RETREAT. If the player makes no choice for 2 days, auto mode SHALL take over. Retreat SHALL be an automatic return to the city in 1 day with no new battles en route (Y10).

#### Scenario: Auto mode after inaction
- **WHEN** the hero is in EXPLORE and the player takes no action for 2 days
- **THEN** auto mode selects the next move deterministically
- **AND** the player can re-assert control at any point

#### Scenario: Retreat is safe
- **WHEN** the hero retreats from a battle
- **THEN** the hero returns to the city in 1 day
- **AND** no new battles trigger during the return

### Requirement: Fail states and edge cases
If transition speed is ≤ 0, the turn SHALL end at the current cell. If the hero is surrounded, ENGAGE SHALL be mandatory. If a raid targets the hero's current cell, a battle SHALL occur instead of auto-resolve, with −50% consequences on victory.

#### Scenario: Speed zero
- **WHEN** the hero's transition speed computes to ≤ 0
- **THEN** the turn ends at the current cell
- **AND** the hero cannot move further that turn

#### Scenario: Raid on hero cell
- **WHEN** a raid targets the cell the hero currently occupies
- **THEN** a battle occurs instead of auto-resolve
- **AND** if the hero wins, raid consequences are reduced by 50%
