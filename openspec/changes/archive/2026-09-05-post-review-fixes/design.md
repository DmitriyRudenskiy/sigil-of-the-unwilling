# Design: post-review-fixes

## Context

The audit's 25 items were spot-verified against the tree (all confirmed;
notable corrections: `mcp_interaction_server.gd` is 4864 lines / 107
`_cmd_*`, not ~2500/80; `BattleState` already clears `_reachable_cache` on
board version bump but the key itself carries no version;
`CityArenaModel.gd` — not `CityArenaView` — is the current caller of
`ArenaTurnRunner` demo/score). The repo has 113 GUT test files; suites
already exist for nearly every touched class
(`test_city_arena_view`, `test_save_roundtrip`, `test_city_events_relocation`,
`test_settings_guard/persist`, `test_zoom_levels`, `test_endgame`,
`test_enemy_world_ai`, `test_hex_utils`, `test_legend_chronicle`, battle
suites). `WorldBootstrap.gd`, `GameEventBus.gd`, `MapGenerator.gd` have
in-flight uncommitted changes from parallel work.

## Goals / Non-Goals

**Goals:** all 25 audit items fixed, each High/Medium/Low behavior change
backed by a GUT test (existing suite extended); full suite, `--fast` CI, and
`lint.sh` green at the end.

**Non-Goals:** audit items outside the 25-row summary table
(`SocketController._ARG_SCHEMAS` const-ification, `CityArenaView` business
logic extraction, `calibrate` warning, `ArtifactInventoryScreen._tex`,
chest-spawn pre-list, `ArenaClusterSystem` versioning, `MinHeap.pop` assert);
MCP protocol or transport changes; new dependencies; data migration.

## Decisions

1. **Phasing: High → Medium → Low → Architecture**, each phase ending with a
   full GUT run and its own commit(s). Rationale: High items are small,
   independent, and unlock acceptance criteria immediately; architecture
   items (server split, template extraction, HexUtils split) produce large
   diffs and get isolated commits with their own targeted tests.
   Alternative (interleaved by file) rejected: harder to review and roll back.

2. **R1 (arena clicks)**: re-signature `_on_cell_input` to
   `(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2, normal: Vector2)`
   (Godot 4 `Area2D.input_event` order) and fix the stale Godot-3 comment.
   Note: this *activates* previously dead click handling — verify no scenario
   or test relied on the no-op (scenarios interact via MCP, not clicks;
   `test_city_arena_view` is extended to assert selection changes on click).

3. **R2 (delete_save)**: `DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))`.
   Test writes a real save, deletes, asserts the file is gone from the
   globalized path.

4. **R3 (worker cell)**: in `City.can_build_building`, after the
   `cell_is_built` check, scan `pop` for a unit with `state == WORKER` and
   `tile == cell` → fail. Test extends a city suite: place a worker on the
   cell, assert build fails, worker unaffected.

5. **R4 + R25 (settings semantics)**: snapshot `master/music/sfx` volumes in
   `_ready`; `_on_cancel` restores via the `Settings` setters + `_apply_audio`
   and never saves; `_on_zoom_selected` drops its immediate `save()` —
   `_on_apply` is the single save point. Tests extend `test_settings_persist`
   / `test_settings_guard`.

6. **R6 (ZOOM_LEVELS)**: keep the literal in `GameSettings.ZOOM_LEVELS`;
   `Settings.ZOOM_LEVELS` becomes a const alias
   (`const ZOOM_LEVELS := GameSettings.ZOOM_LEVELS`). Zero consumer changes
   (SettingsScreen and tests read via `Settings`), one source of truth.
   Alternative (audit's "replace all references") rejected: same benefit,
   larger diff.

7. **R10 (enemy Dijkstra cache)**: per-turn `Dictionary` in
   `EnemyTurnProcessor.process` keyed by `(cell, budget)`; cleared each turn.
   No API change.

8. **R11 (board-versioned key)**: change `_reachable_cache` key to a string
   `"%d:%s:%s" % [_board_version, cell, speed]`. Cheap, removes the
   human-factor dependency on `invalidate_board_cache()`.

9. **R19 + R24 (mute)**: reorder `[autoload]` in `project.godot` so
   `Settings` precedes `SoundManager`; delete the `AudioServer` fallback in
   `SoundManager.toggle_mute` (autoload order guarantees `Settings`); add
   `save()` to `Settings.toggle_mute` and `Settings.reset_to_defaults`.
   Risk is the autoload reorder — mitigated by full GUT + a smoke run.

10. **R5 (mcp server split, final phase)**: extract command groups into
    `RefCounted` modules (suggested groups: network/input, game-state,
    physics/animation, UI, 3D/2D, audio, resources), mirroring the
    `SocketController` precedent (`BattleEmulator`, `CityStateSerializer`).
    The server file keeps transport + `_handle_command` delegation only.
    **No protocol change**: command names, args, and responses unchanged.
    Modules are constructed with injected deps so they are directly unit-test
    (the whole point — the monolith is untestable in place).

11. **R8 (templates, final phase)**: one `RefCounted` file per template in
    `scripts/data/templates/`, registered by name in `TemplateBootstrap`;
    `TemplateEngine` keeps dispatch only. Acceptance: every template executes
    via `TemplateEngine` with unchanged output (test iterates all registered
    names).

12. **R9 (HexUtils split, final phase)**: `MinHeap` → `scripts/core/MinHeap.gd`;
    `bfs_path` / `dijkstra` / `dijkstra_path` / `bfs_reachable` →
    `scripts/core/HexPathfinding.gd`; `HexUtils` keeps geometry + `calibrate`.
    All call sites updated (grep-driven); `test_hex_utils` split to match.

13. **R20 (demo scenario)**: `score` / `demo_plan` / `run_demo_plan` move to
    `scripts/city/ArenaDemoScenario.gd` as statics; caller
    (`CityArenaModel.gd`) and the tuner script updated. Behavior identical.

14. **R16 (GameSettings split, Low)**: move constants into domain configs
    (`BattleConfig`, `MapConfig`, `UIConfig`, `EndgameConfig`); `GameSettings`
    keeps only general constants (`INF`, `SAVE_MAGIC`). 143-line file, so the
    split is mechanical; references updated via grep.

15. **R23 (hero placement)**: `_place_in_hero_component` filters candidates
    against enemy stacks / resources / chests from `map_gen`. The file has
    in-flight changes — apply on top, run `test_worldcontroller_*` plus the
    new placement test.

16. **Testing strategy**: extend the existing suite for each class; a new
    test file is allowed only where none exists. No test duplication.

## Risks / Trade-offs

- [In-flight uncommitted changes in `WorldBootstrap.gd`, `GameEventBus.gd`,
  `MapGenerator.gd`] → implement on the current tree, never revert those
  hunks; run their suites (`test_worldcontroller_succession_wiring`,
  `test_hero_survival`, demographics tests) after the Low phase.
- [Autoload reorder (Settings before SoundManager) is a global behavior
  change] → full GUT + smoke run; rollback is a one-line revert.
- [R1 activates previously dead click code] → `test_city_arena_view` asserts
  the new behavior explicitly; scenarios (MCP-driven) unaffected.
- [R5/R8/R9 are large diffs] → isolated final phase, own commits, targeted
  unit tests per module; protocol/output parity is the acceptance bar.
- [R23 depends on in-flight `MapGenerator` state] → placement test uses the
  current `map_gen` API as-is; if the in-flight change renames fields, the
  test follows the tree.

## Migration Plan

1. Phase 1 (High) — one commit per fix + its test.
2. Phase 2 (Medium) — one commit per item.
3. Phase 3 (Low) — grouped commits (FX guards; mute; placement; cleanup).
4. Phase 4 (Architecture) — one commit per extraction (server, templates,
   HexUtils, GameSettings).
5. After each phase: full GUT. End of change: `--fast` CI + `lint.sh` green.

Rollback: per-commit `git revert`; no data or protocol migration involved.
