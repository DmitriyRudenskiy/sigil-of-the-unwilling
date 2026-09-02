---
description: "Requirements for terminal game conditions: a game state machine, defeat by unsuccessored death or total collapse, victory by Path completion (glory) or domination, an end screen with a run summary, and a post-game event."
---

## ADDED Requirements

### Requirement: The game has a terminal state
`GameSession` **MUST** track a game state (`RUNNING`, `VICTORY`, `DEFEAT`) with an end reason. A terminal state **MUST** be sticky: once set, world input is disabled and no further conditions can change it.

#### Scenario: State is sticky
- **Given** the game has ended in `DEFEAT`
- **When** a victory condition would otherwise trigger
- **Then** the state remains `DEFEAT`

### Requirement: Defeat by unsuccessored death
If the hero dies in battle and no eligible successor exists, the game **MUST** end in `DEFEAT`.

#### Scenario: Hero dies alone
- **Given** a hero with no eligible successor loses a battle
- **When** the battle resolves as a loss
- **Then** the game ends in `DEFEAT` with reason «unsuccessored death»

#### Scenario: Successor exists
- **Given** a hero with an eligible successor loses a battle
- **When** the battle resolves as a loss
- **Then** the game does not end (succession flow takes over per `succession-sigil`)

### Requirement: Defeat by total collapse
If the player owns no cities, the game **MUST** end in `DEFEAT`.

#### Scenario: Capital falls
- **Given** the player owns only the capital
- **When** the capital is lost
- **Then** the game ends in `DEFEAT` with reason «total collapse»

### Requirement: Victory by Path completion
If the player's glory reaches the configured threshold, the game **MUST** end in `VICTORY`.

#### Scenario: Glory threshold reached
- **Given** `ENDGAME_GlORY_VICTORY` is 100 and the player's glory is 95
- **When** glory increases to 100
- **Then** the game ends in `VICTORY` with reason «Path completed»

### Requirement: Victory by domination
If all hostile enemy factions on the shard are eliminated, the game **MUST** end in `VICTORY` (when domination is enabled).

#### Scenario: Last faction eliminated
- **Given** one hostile faction remains
- **When** it is eliminated
- **Then** the game ends in `VICTORY` with reason «domination»

### Requirement: An end screen with a run summary
On terminal state, an end screen **MUST** show the result, the reason, and a run summary (turns, cities, glory, battles, generations), and offer a return to the main menu.

#### Scenario: Player sees the ending
- **Given** the game has ended
- **When** the end screen opens
- **Then** it shows the result, reason, and summary, and «В главное меню» returns to the menu

### Requirement: A post-game event is emitted
On terminal state, the system **MUST** emit `GameEventBus.game_ended(result, reason, summary)` so other systems (e.g. `legend-chronicle`) can react.

#### Scenario: Chronicle can listen
- **Given** a subscribed listener on `game_ended`
- **When** the game ends
- **Then** the listener receives the result, reason, and summary
