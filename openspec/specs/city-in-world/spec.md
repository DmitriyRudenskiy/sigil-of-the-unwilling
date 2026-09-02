# city-in-world Specification

## Purpose
TBD — Update Purpose after archive.

## Requirements

### Requirement: Capturing a village creates a real city
When the hero captures a village, the system **MUST** create a level-1 `City` centered on the village cell with a stable (seed-determined) name and register it in `CityManager`.

#### Scenario: Village becomes a city
- **Given** the hero is adjacent to an unowned village
- **When** the hero captures the village
- **Then** a `City` object exists for that cell in `CityManager` and the cell renders as a city on the map

#### Scenario: No duplicate city
- **Given** a cell that is already a city
- **When** the hero "captures" it again
- **Then** no second city is created

### Requirement: The player can enter and manage a world city
While the hero is on a city cell, a city management screen **MUST** open bound to that world `City` (not a sandbox model); actions taken there **MUST** mutate the world city state and persist.

#### Scenario: Enter a city
- **Given** the hero moves onto a player-owned city cell
- **When** the move resolves
- **Then** the city screen opens showing that city's rings, buildings, and population

#### Scenario: Build in the world city
- **Given** the city screen is open on a world city with enough resources
- **When** the player assigns a building to a ring cell and confirms
- **Then** the world `City` contains the building and it is present after closing the screen and on the next turn

#### Scenario: CityArena sandbox unchanged
- **Given** the CityArena scene from the main menu
- **When** the player builds there
- **Then** only the sandbox model changes; world cities are unaffected

### Requirement: Tile yields are computed from terrain
The tile-yield provider **MUST** compute FIDSI yields from the actual terrain of each city ring cell (via a data table), not from constants.

#### Scenario: Terrain changes yields
- **Given** two identical level-1 cities on different terrains (e.g. grass vs rock)
- **When** the city phase runs
- **Then** their FIDSI outputs differ according to the yield table

### Requirement: City income flows to the player
At end-of-turn, each player-owned city **MUST** pay a deterministic royalty — a fixed fraction of its gold treasury (`resource_ctx` gold × `CityBalance.ROYALTY_FRACTION`) — to the player's strategic resources, and the change **MUST** be visible in the resources UI.

#### Scenario: Income accrues
- **Given** a player city holding 10 gold in its treasury
- **When** the turn ends
- **Then** the player's strategic gold increases by the royalty (2 gold at the default 0.25 fraction) and the city treasury is reduced accordingly

### Requirement: Followers are recruited as individuals
The player **MUST** be able to recruit a named follower — an individual with traits and the hero's path — from a city's population into the hero's party; the city **MUST** track a garrison that scales its defense.

#### Scenario: Recruit a follower
- **Given** a city with population
- **When** the player recruits
- **Then** a named `Follower` appears in the hero's party and the city population/garrison decreases

#### Scenario: Followers persist
- **Given** a recruited follower
- **When** the game is saved and reloaded
- **Then** the follower exists with the same name and traits

### Requirement: Cities have persisted ownership
Each city **MUST** have an owner (`player` / `enemy` / `none`) recorded in the world delta and the save file.

#### Scenario: Ownership survives save/load
- **Given** a captured city owned by the player
- **When** the game is saved and reloaded
- **Then** the city is still owned by the player
