## Context

The project is a Godot 4.7 game. `CityArenaModel.gd` (~700 lines, `RefCounted`) is a monolith that models the arena grid, ring bonuses, cell features, cluster groups, storm, and the demo plan, and it is the single entry point consumed by `CityArenaView` and exercised by `test_city_arena.gd` / `test_city_arena_view.gd`. The numeric behavior is pinned by those tests, so any split must be a **verbatim port**, not a reimplementation. Building definitions live as hardcoded `static func`s in `BuildingDefs.gd`. `ServiceContainer.current` is a global mutable static read directly by ~11 consumers. Tests each redefine their own factory helpers. `SocketController` routes 22 commands from an unvalidated `Dictionary`.

## Goals / Non-Goals

**Goals:**
- Split `CityArenaModel` into focused systems behind a thin facade that preserves the exact public API and numeric behavior.
- Make building data-driven.
- Remove the global mutable `ServiceContainer.current` in favor of injection.
- Consolidate duplicated test factory helpers.
- Add argument validation to the socket command layer.

**Non-Goals:**
- Changing the save format or any externally observable game behavior.
- Re-tuning arena numbers (ring yields, cluster multipliers, storm cadence) — the audit's tuning suggestions are deferred.
- Rewriting the UI layer (`CityScreen`, `DeathSequence`) beyond what's needed for the above.
- Moving the other 12 autoloads or `WorldBootstrap` in this change.

## Decisions

### D1. Decompose by concern, keep a facade
Split into four systems plus a facade, mirroring the audit's SRP recommendation:
- `ArenaTurnRunner` — turn flow (seat workers → city phase → ring multipliers → economy → storm; `run_turn`, `demo_plan`, `run_demo_plan`, `score`, `hire_worker`, `place_building`, `make_city`).
- `ArenaRingSystem` — geometry and per-ring balance (`is_in_arena`, `cells_in_*`, `tile_yield`, `ring_bonus`, `cell_feature`, `building_mult`, `apply_ring_multipliers`).
- `ArenaClusterSystem` — connected-component grouping + version cache.
- `ArenaStorm` — storm turn detection and production/food effects.
- `CityArenaModel` — thin facade delegating every public method; constants (`ARENA_CENTER = Vector2i(5,4)`, `ARENA_RADIUS`) re-exported.

Rationale: a facade keeps `CityArenaView` and tests compiling unchanged, so the migration is mechanical and low-risk. Alternative (rewiring all consumers to the systems directly) was rejected as higher-risk for no near-term gain.

### D2. Verbatim port, tests as the oracle
Each original method body is moved word-for-word, substituting only the leaf helpers it calls (e.g. `city.build_building` stays; `tile_yield(cell)` → `ArenaRingSystem.tile_yield(cell)`). The first attempt reimplemented economy/score and diverged from test-dependent numbers, so the rule is: **port, never reimplement**. `run_turn`'s call order (`city.process_turn` → phase → `apply_ring_multipliers` → economy) and the exact `score` formula are preserved.

### D3. Cluster cache keyed on city version
`ArenaClusterSystem` caches clusters per `city.uid`, keyed on a cheap version (`buildings.size()` + uid hash). `place_building` calls `invalidate` after adding a building so the next read recomputes. This removes the O(N) recomputation on every `apply_ring_multipliers` without changing results. (Audit item 4.2.3.)

### D4. Building definitions as data
Move the 15 `static func` builders into a data file (`game/assets/data/buildings.json`) and load them lazily into a cache in `BuildingDefs`. `def_by_id` becomes a cache lookup. This satisfies OCP (audit 2.2): adding a building is a data edit. The `UniqueBuilding.Def` shape is unchanged, so `test_city_screen.gd` and `test_city_income_processor.gd` keep passing.

### D5. Injection over the global holder
`ServiceContainer.current` is read directly by many consumers. Migrate consumers to receive dependencies via `setup()`/constructor. `ServiceContainer` keeps any needed registry but drops the mutable `static var current`. This is the highest-risk task (12 files); it is sequenced last and validated by the full suite plus `grep -r "ServiceContainer.current" game/scripts/` → 0.

### D6. Shared test factories
Extract `_make_follower` / `_make_hero` / `_make_city` into `tests/helpers/test_factories.gd` (`class_name TestFactories`). Each test file switches to the shared helpers; behavior is unchanged (same seeded RNG, same starter state).

### D7. Socket argument validation
Add a `_validate_args(args, schema)` helper that checks required keys and types, returning an error string. `_route_command` (and JSON parsing) wrap dispatch in validation and return `{"error": "..."}` on failure. Malformed input (`{"action": 123}`, missing fields, wrong types) must never throw.

## Risks / Trade-offs

- **Verbatim port drift** → Mitigation: run `test_city_arena.gd` and `test_city_arena_view.gd` after the split; any divergence is caught immediately.
- **Service injection ripple** → 11+ consumers; Mitigation: do it last, keep `ServiceContainer`'s public methods stable, validate with the full suite.
- **JSON loading cost** → Mitigation: lazy cache in `BuildingDefs`, loaded once; negligible for a handful of buildings.
- **Russian/English mixed comments** → Out of scope for behavior; not touched.

## Migration Plan

Apply in dependency order, each validated by the full GUT run (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`):
1. `arena-model-decomposition` (lowest risk — tests exist and pin behavior).
2. `building-defs-as-data`.
3. `test-factory-helpers`.
4. `socket-command-validation`.
5. `service-injection:current` (highest risk — last).

Rollback: each step is a refactor with unchanged observable behavior; revert the touched files and rerun.

## Open Questions

- Building data format: `.json` vs `.tres`. Chosen `.json` (simpler diff, no Godot resource tooling). If the team prefers editor-facing editing, `.tres` is a follow-up.
- Whether `WorldBootstrap` manual wiring should also be addressed (audit flagged DIP). Deferred — out of scope for this change.
