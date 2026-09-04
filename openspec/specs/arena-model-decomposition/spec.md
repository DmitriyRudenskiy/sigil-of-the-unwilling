# arena-model-decomposition Specification

## Purpose

Provide a stable arena model to the rest of the game and its tests while splitting the former monolithic `CityArenaModel` into focused systems, without changing any externally observable behavior.

## Requirements

### Requirement: Arena facade exposes the same public API

The arena model SHALL keep its public static surface (`run_turn`, `def_by_id`, `all`, the geometry/balance/feature/cluster/storm/runner methods, and the `ARENA_CENTER` / `ARENA_RADIUS` constants) so that existing consumers and tests compile and behave identically.

#### Scenario: Consumer still resolves arena behavior through the facade
- **WHEN** `CityArenaView` calls `CityArenaModel.run_turn(city, turn)`
- **THEN** the returned dictionary has the same keys and values as before the split

#### Scenario: Geometry constants remain accessible
- **WHEN** a test reads `CityArenaModel.ARENA_CENTER`
- **THEN** it is `Vector2i(5, 4)` and `City.center` matches it

### Requirement: Arena turn produces the same result as before

`run_turn` SHALL seat workers, run the city phase, apply ring multipliers (including storm), run the economy, and return the same report so that `test_city_arena.gd` passes unchanged.

#### Scenario: Full turn result is unchanged
- **WHEN** `run_turn` is called on a city built in the arena
- **THEN** the turn report (food, industry, gold, level, prosperity, clusters, storm fields, etc.) is byte-for-byte identical to the pre-split behavior

### Requirement: Ring geometry and bonuses are preserved

The ring subsystem SHALL compute `is_in_arena`, `cells_in_arena`, `cells_in_ring`, `tile_yield`, `ring_bonus`, `building_mult`, and `apply_ring_multipliers` with the same results (center at `Vector2i(5,4)`, all ring cells, override parameters, storm multiplier applied after the city phase and before the economy).

#### Scenario: Center cell is inside the arena
- **WHEN** `is_in_arena` is called on the arena center
- **THEN** it returns true

#### Scenario: Ring bonus overrides apply
- **WHEN** `tile_yield` is called with an `overrides` dictionary
- **THEN** the override values win over the ring default

### Requirement: Cluster mechanic is preserved

The cluster subsystem SHALL group buildings of the same def into connected components (hex adjacency, size ≥ 4), return `clusters` in deterministic order, expose `cluster_uids` as a uid→multiplier map, and compute `cluster_worker_housing` as free worker housing plus CLUSTER_HOUSING per cluster.

#### Scenario: Cluster multiplier is applied to member buildings
- **WHEN** four farms form a connected component
- **THEN** each member's effective production is multiplied by CLUSTER_MULT

### Requirement: Storm mechanic is preserved

The storm subsystem SHALL report storm turns on the configured cadence, reduce production during storms, and reduce food on storm turns, with level-2 walls mitigating production loss.

#### Scenario: Storm reduces food on storm turns
- **WHEN** a storm turn occurs and walls are below level 2
- **THEN** `storm_food_penalty` returns a positive food loss

### Requirement: Version-based cluster cache is correct

The cluster cache SHALL be keyed on city state; placing a building invalidates the cached clusters so the next read recomputes from the current buildings.
Deserialization of a city (which repopulates its buildings) is a state change
too and MUST invalidate the cached clusters so a loaded city reports correct
clusters on first read.

#### Scenario: Placing a building refreshes the cache
- **WHEN** a building is added to the arena and clusters are read again
- **THEN** the result reflects the new building without a stale entry

#### Scenario: Loading a city refreshes the cache
- **WHEN** a City is deserialized (its buildings repopulated) and clusters are read
- **THEN** the result reflects the deserialized buildings without a stale entry
