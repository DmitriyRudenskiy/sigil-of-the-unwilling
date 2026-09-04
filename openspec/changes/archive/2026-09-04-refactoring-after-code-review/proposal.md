## Why

The code audit of `sigil-of-the-unwilling` (Godot 4.7) found several single-responsibility violations and rigidities that make future changes costly and error-prone — most notably a ~700-line `CityArenaModel` that models arena grid, clusters, features, storm and demo-plan at once, plus hardcoded building data and a global mutable `ServiceContainer.current`. This change makes those areas safe, fast, and open to extension.

## What Changes

- Split `CityArenaModel` into focused systems (`ArenaTurnRunner`, `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaStorm`) with a thin facade, preserving its public API and all numeric behavior.
- Move building definitions out of `BuildingDefs.gd` (`match` over 15 `static func`s) into a data file so adding a building needs no code edit.
- Migrate consumers off `ServiceContainer.current` to explicit injection, removing the global mutable static.
- Consolidate duplicated per-test factory helpers (`_make_follower`, `_make_hero`, `_make_city`) into shared `test_factories.gd`.
- Add input validation to `SocketController` (and related autoloads) so malformed commands return an error dict instead of crashing.
- Cache `clusters()` on city-state version to avoid O(N) recomputation on every `apply_ring_multipliers`.

## Capabilities

### New Capabilities

- `arena-model-decomposition`: decompose `CityArenaModel` into focused, testable systems behind a stable facade.
- `building-defs-as-data`: load building definitions from a data file instead of hardcoded `static func`s.
- `service-injection:current`: replace the global `ServiceContainer.current` with injected dependencies.
- `test-factory-helpers`: shared deterministic factory helpers for tests.
- `socket-command-validation`: validate incoming socket command arguments before dispatch.

### Modified Capabilities

<!-- none -->

## Impact

- `game/scripts/city/CityArenaModel.gd` → thin facade; new `ArenaTurnRunner`, `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaStorm`.
- `game/scripts/data/BuildingDefs.gd` + new building data file.
- `game/scripts/core/ServiceContainer.gd` and ~11 consumer files.
- `game/tests/` — shared helpers + ~15 updated test files.
- `game/scripts/autoload/SocketController.gd`, `BattleEmulator.gd`.
- Public API of `CityArenaModel` (`run_turn`, `def_by_id`, `all()`, geometry/balance methods) and the save format are unchanged. Tests drive the numeric contract, so porting must be verbatim.
