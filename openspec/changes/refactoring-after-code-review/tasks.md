## 1. Decompose CityArenaModel into arena systems

- [ ] 1.1 Create `ArenaRingSystem.gd` (geometry + ring balance: `ARENA_CENTER`, `ring_of`, `is_in_arena`, `cells_in_arena`, `cells_in_ring`, `tile_yield`/`ring_bonus` with overrides, `cell_feature`, `feature_mult`, `feature_glyph`, `feature_name`, `building_mult`, `apply_ring_multipliers`). Port bodies verbatim.
- [ ] 1.2 Create `ArenaClusterSystem.gd` (`clusters`, `cluster_uids`, `cluster_worker_housing`) plus a version-keyed cache with `invalidate()`. Port bodies verbatim.
- [ ] 1.3 Create `ArenaStorm.gd` (`is_storm_turn`, `_has_walls_lvl2`, `storm_production_mult`, `storm_food_penalty`). Port body verbatim.
- [ ] 1.4 Create `ArenaTurnRunner.gd` (`run_turn`, `demo_plan`, `run_demo_plan`, `score`, `hire_worker`, `make_city`, `place_building`, `arena_tile_free`, `seat_workers`, and private helpers). Port bodies verbatim, substituting system calls for leaf helpers.
- [ ] 1.5 Reduce `CityArenaModel.gd` to a thin facade delegating all public methods to the four systems; re-export `ARENA_CENTER`/`ARENA_RADIUS`. Target < 200 lines.
- [ ] 1.6 Run `test_city_arena.gd` and `test_city_arena_view.gd`; assert unchanged pass counts and identical numeric outputs.

## 2. Building definitions as data

- [ ] 2.1 Create `game/assets/data/buildings.json` capturing all existing buildings (id, display_name, requires_site, levels, production_chain, followers).
- [ ] 2.2 Rewrite `BuildingDefs.gd` to load and cache definitions from the JSON, keeping `def_by_id`/`all` behavior identical.
- [ ] 2.3 Update any consumers (e.g. `test_city_screen.gd`, `test_city_income_processor.gd`) and confirm `game/assets/data/buildings.json` is committed.
- [ ] 2.4 Verify a new building is added by a data-only edit with no `.gd` change.

## 3. Shared test factory helpers

- [ ] 3.1 Create `game/tests/helpers/test_factories.gd` (`class_name TestFactories`) exposing `make_hero`, `make_follower`, `make_city`.
- [ ] 3.2 Migrate the ~15 test files that redefine `_make_follower`/`_make_hero`/`_make_city` to use the shared helpers.
- [ ] 3.3 Confirm `grep -r "func _make_follower" game/tests/` (and hero/city variants) resolves only to the shared module; full suite still passes.

## 4. Socket command validation

- [ ] 4.1 Add `_validate_args(args, schema)` to `SocketController.gd` (required keys + type checks) and use it in `_route_command`.
- [ ] 4.2 Guard JSON parsing in `_route_command` so malformed input returns `{"error": "..."}` instead of throwing.
- [ ] 4.3 Apply the same validation pattern to `BattleEmulator.gd` where it accepts external input.
- [ ] 4.4 Verify with `test_socket_routing.gd` (and the full suite): `{"action": 123}`, missing fields, and wrong types all return errors without crashing.

## 5. Migrate off ServiceContainer.current

- [ ] 5.1 Inventory all `ServiceContainer.current` reads and their dependency surface.
- [ ] 5.2 Introduce injection entry points (constructor / `setup()`) on the consumers and remove the mutable `static var current`.
- [ ] 5.3 Migrate all ~11 consumers; confirm `grep -r "ServiceContainer.current" game/scripts/` → 0.
- [ ] 5.4 Run the full GUT suite; confirm `All tests passed!` and no behavioral regressions.

## 6. Final verification

- [ ] 6.1 Run the full GUT suite (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`) and confirm all tests pass.
- [ ] 6.2 Confirm `CityArenaModel.gd` < 200 lines and each new system < 150 lines.
- [ ] 6.3 Commit the change; update task checkboxes in `tasks.md`.
