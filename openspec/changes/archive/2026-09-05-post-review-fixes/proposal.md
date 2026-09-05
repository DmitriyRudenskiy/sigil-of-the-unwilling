# Post-Review Fixes

## Why

A full-project code audit (2026-09) identified 25 issues: 4 High-priority bugs
(arena cell clicks silently unhandled, `delete_save()` not actually deleting
the file, buildings buildable on a worker's cell, settings "Cancel" not
rolling back volume), plus Medium/Low algorithmic, best-practice, and
architectural problems. All 25 claims were spot-verified against the current
tree. This change is a single disciplined fix cycle: every item is fixed and
covered by an existing or extended GUT test.

## What Changes

- **High**: fix `CityArenaView._on_cell_input` signal signature (clicks never
  fired — handler received the viewport as `event`); make
  `SaveManager.delete_save` delete the real file (`globalize_path`); reject
  building on a worker-occupied cell; make settings "Cancel" restore volumes
  and "Apply" the only save point.
- **Medium**: single source for `ZOOM_LEVELS`; rename
  `ENDGAME_GlORY_VICTORY` → `ENDGAME_GLORY_VICTORY`; per-turn Dijkstra cache
  in `EnemyTurnProcessor`; board-version-aware reachability cache in
  `BattleState`.
- **Low**: mute ownership/persistence in `Settings` (autoload order, no
  out-of-band `AudioServer` fallback, `save()` on mute/reset); headless and
  isolated-context safety guards (`BattleFX`, `ParticlePresets`,
  `Chronicle`, idempotent `EndgameController.setup`); `City.relocate` bounds
  and other-city checks; hero-component placement excludes occupied cells;
  `Input` singleton cleanup; remove `_instantiate` match factory; cache
  procedural sprites in `WorldSpawner`.
- **Architecture (final phase, separate commits)**: decompose
  `mcp_interaction_server.gd` (4864 lines, 107 `_cmd_*`) into per-command
  `RefCounted` modules with unchanged protocol; move `TemplateEngine`
  handlers to one file per template in `scripts/data/templates/`; extract
  `MinHeap` and pathfinding from `HexUtils`; split `GameSettings` into domain
  configs.
- **Tests**: extend existing GUT suites (no duplicate test files); new test
  files only where no suite exists for the touched class.

## Capabilities

### New Capabilities

- `post-review-fixes`: behavioral guarantees added by the fix cycle — arena
  input handling, settings save/rollback semantics, real save-file deletion,
  cache correctness, and headless/isolated-context safety.

### Modified Capabilities

(none — the fixes add previously unspecified guarantees; no existing main
spec requirement is altered)

## Impact

- **Code**: ~20 files across `scripts/{autoload,core,world,city,systems,data,ui}`.
  New files: `scripts/city/ArenaDemoScenario.gd`, `scripts/core/MinHeap.gd`,
  `scripts/core/HexPathfinding.gd`, `scripts/data/templates/*.gd`, and the
  `mcp_interaction_server` command modules.
- **project.godot**: autoload order — `Settings` before `SoundManager`.
- **Tests**: `test_city_arena_view`, `test_save_roundtrip`, `test_city_*`,
  `test_settings_guard`, `test_settings_persist`, `test_zoom_levels`,
  `test_endgame`, `test_enemy_world_ai`, `test_hex_utils`,
  `test_legend_chronicle`, battle suites.
- **Constraints**: no MCP protocol changes, no new dependencies, no data
  migration. `WorldBootstrap.gd`, `GameEventBus.gd`, and `MapGenerator.gd`
  carry in-flight uncommitted changes (remove-hunger-mechanic work) —
  implement on the current tree without reverting them.
