## 1. Decompose CityArenaModel into arena systems

- [x] 1.1 Create `ArenaRingSystem.gd` (geometry + ring balance: `ARENA_CENTER`, `ring_of`, `is_in_arena`, `cells_in_arena`, `cells_in_ring`, `tile_yield`/`ring_bonus` with overrides, `cell_feature`, `feature_mult`, `feature_glyph`, `feature_name`, `building_mult`, `apply_ring_multipliers`). Port bodies verbatim.
- [x] 1.2 Create `ArenaClusterSystem.gd` (`clusters`, `cluster_uids`, `cluster_worker_housing`) plus a version-keyed cache with `invalidate()`. Port bodies verbatim.
- [x] 1.3 Create `ArenaStorm.gd` (`is_storm_turn`, `_has_walls_lvl2`, `storm_production_mult`, `storm_food_penalty`). Port body verbatim.
- [x] 1.4 Create `ArenaTurnRunner.gd` (`run_turn`, `demo_plan`, `run_demo_plan`, `score`, `hire_worker`, `make_city`, `place_building`, `arena_tile_free`, `seat_workers`, and private helpers). Port bodies verbatim, substituting system calls for leaf helpers.
- [x] 1.5 Reduce `CityArenaModel.gd` to a thin facade delegating all public methods to the four systems; re-export `ARENA_CENTER`/`ARENA_RADIUS`. Target < 200 lines.
- [x] 1.6 Run `test_city_arena.gd` and `test_city_arena_view.gd`; assert unchanged pass counts and identical numeric outputs.

## 2. Building definitions as data

- [x] 2.1 Create `game/assets/data/buildings.json` capturing all existing buildings (id, display_name, requires_site, levels, production_chain, followers).
- [x] 2.2 Rewrite `BuildingDefs.gd` to load and cache definitions from the JSON, keeping `def_by_id`/`all` behavior identical.
- [x] 2.3 Update any consumers (e.g. `test_city_screen.gd`, `test_city_income_processor.gd`) and confirm `game/assets/data/buildings.json` is committed.
- [x] 2.4 Verify a new building is added by a data-only edit with no `.gd` change. with no `.gd` change.

## 3. Shared test factory helpers

- [x] 3.1 Create `game/tests/helpers/test_factories.gd` (`class_name TestFactories`) exposing `make_hero`, `make_follower`, `make_city`. (Fixed broken `Follower` preload path that left `class_name` unregistered and broke 34 tests.)
- [x] 3.2 Migrate the real-type factories that are drop-ins for the shared helper: `test_city_systems`, `test_economic_processor`, `test_city_processor`, `test_city_chains` (`make_city(uid=1, stronghold=2)`) and `test_save_v3` (`make_city(0/1)`). The remaining `_make_*` redefinitions build local stub doppelgangers (`_City`/`_Hero`/`_Follower`/`_HeroStub`/`_HeroController`) for isolated internal-system testing -- excluded from migration per design D6, their signatures/behavior differ from the shared helper. `test_city_reputation` keeps `_make_city(stronghold=1)` (first param is stronghold, returns RefCounted) -- incompatible with the shared signature.
- [x] 3.3 Full GUT suite passes (1136 tests, 0 failing). Real-type factories resolve to `TestFactories`; stub factories remain by design D6.

## 4. Socket command validation

- [x] 4.1 Add `_validate_args(args, schema)` to `SocketController.gd` (required keys + type checks) and use it in `_route_command`. Schema stored as `{field: [type_name,...]}` (type-name strings; GDScript can't use type refs in a dict literal or `is`-with-variable). `_value_has_type` maps type names to literal `is` checks. Full suite passes.
- [x] 4.2 Guard JSON parsing in `_route_command` (malformed → `{"error": "Invalid JSON"}`, no throw). Already present; verified by `test_socket_routing.gd`.
- [x] 4.3 `BattleEmulator.gd` external-input methods (`cast_spell`/`emulate_battle`/`cast_in_battle`/`sequence_battle`/`battle_spell`) already return `{"error": ...}` on missing/wrong-typed fields. No change needed.
- [x] 4.4 Verified with `test_socket_routing.gd` + full suite (1136 pass, 0 fail): `{"action": 123}`, missing action, empty action, oversized line, invalid JSON all return structured errors without crashing.

## 5. Migrate off ServiceContainer.current

- [x] 5.1 Inventory: 13 `ServiceContainer.current` reads in `game/scripts/` (ServiceLocator, MapGenerator, WorldBattleCoordinator, BattleController, HeroController) + doc comments + `setup_global` calls in WorldBootstrap/gut_base.
- [x] 5.2 Injection entry points: MapGenerator.setup_services(), HeroController.setup(map, services=). Removed mutable `static var current` + `setup_global` from ServiceContainer; dropped `.current` fallback from ServiceLocator (autoload fallback is equivalent).
- [x] 5.3 All consumers migrated; `grep -r "ServiceContainer.current" game/scripts/` → 0 (also reworded 2 doc comments that named the string).
- [x] 5.4 Full suite: 1136 pass, 0 fail, no regressions. Updated gut_base + test_battle_coordinator (they set `.current`; services now injected via setup).

## 6. Final verification

- [x] 6.1 Full GUT suite: 1136 pass, 0 fail.
- [x] 6.2 `CityArenaModel.gd` = 126 lines (< 200). Decomposed systems ported verbatim per design (faithfulness over line count): ArenaClusterSystem 112, ArenaStorm 40, ArenaRingSystem 196 and ArenaTurnRunner 390 exceed the aspirational 150-line target by design choice.
- [x] 6.3 Commit the change; update task checkboxes in `tasks.md`.
